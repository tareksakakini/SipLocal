import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {v4 as uuidv4} from "uuid";
import {SquareClient, SquareEnvironment, Square} from "square";
import * as dotenv from "dotenv";
// import * as crypto from "crypto";

// Load environment variables
dotenv.config();

// Initialize Firebase Admin
admin.initializeApp();

// Square client will be initialized inside the function

// Webhook signature verification
/*
async function verifyWebhookSignature(
  body: string,
  signature: string,
  webhookUrl: string
): Promise<boolean> {
  try {
    // Get the webhook signature key from Firebase secrets
    const webhookSignatureKey = process.env.SQUARE_WEBHOOK_SIGNATURE_KEY;
    if (!webhookSignatureKey) {
      functions.logger.error("SQUARE_WEBHOOK_SIGNATURE_KEY not configured in secrets");
      return false;
    }

    // Square uses HMAC-SHA256 with the signature key
    // The signature is calculated over the webhook URL + request body
    const expectedSignature = crypto
      .createHmac('sha256', webhookSignatureKey)
      .update(webhookUrl + body)
      .digest('base64');

    functions.logger.info("Signature verification:", {
      received: signature,
      expected: expectedSignature,
      matches: signature === expectedSignature
    });

    return signature === expectedSignature;
  } catch (error) {
    functions.logger.error("Error verifying webhook signature:", error);
    return false;
  }
}
*/

// Map Square order states to our order statuses
function mapSquareOrderStateToStatus(squareState: string): string {
  switch (squareState) {
    case "OPEN":
      return "SUBMITTED";
    case "COMPLETED":
      return "COMPLETED";
    case "CANCELED":
      return "CANCELLED";
    case "DRAFT":
      return "DRAFT";
    default:
      return "SUBMITTED";
  }
}

// Map Square fulfillment states to our order statuses
function mapSquareFulfillmentStateToStatus(fulfillmentState: string): string {
  switch (fulfillmentState) {
    case "PROPOSED":
      return "SUBMITTED";
    case "RESERVED":
      return "IN_PROGRESS";
    case "PREPARED":
      return "READY";
    case "FULFILLED":
      return "COMPLETED";
    case "CANCELED":
      return "CANCELLED";
    default:
      return "SUBMITTED";
  }
}

// Define the expected data structure
interface PaymentData {
  nonce: string;
  amount: number;
  merchantId: string;
  oauth_token: string;
  items?: Array<{ name: string; quantity: number; price: number; customizations?: string }>;
  customerName?: string;
  customerEmail?: string;
  pickupTime?: string; // ISO string for pickup time
  userId?: string; // Add user ID for user-specific orders
  coffeeShopData?: { // Add coffee shop data for order display
    id: string;
    name: string;
    address: string;
    latitude: number;
    longitude: number;
    phone: string;
    website: string;
    description: string;
    imageName: string;
    stampName: string;
  };
}


// Function to get merchant tokens from Firestore (HTTP trigger)
export const getMerchantTokens = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  functions.logger.info("getMerchantTokens called with body:", req.body);
  functions.logger.info("getMerchantTokens called with query:", req.query);
  
  const merchantId = req.body?.merchantId || req.query?.merchantId;
  
  if (!merchantId) {
    functions.logger.error("merchantId is missing from request");
    res.status(400).json({ error: "merchantId is required" });
    return;
  }
  
  functions.logger.info("Looking up tokens for merchantId:", merchantId);

  try {
    const doc = await admin.firestore()
      .collection("merchant_tokens")
      .doc(merchantId)
      .get();
    
    if (!doc.exists) {
      functions.logger.error("Document not found for merchantId:", merchantId);
      res.status(404).json({ error: "Merchant tokens not found" });
      return;
    }
    
    const tokenData = doc.data();
    functions.logger.info("Successfully retrieved tokens for merchantId:", merchantId);
    functions.logger.info("Token data keys:", Object.keys(tokenData || {}));
    
    res.status(200).json({ tokens: tokenData });
  } catch (error: any) {
    functions.logger.error("Failed to get merchant tokens:", error);
    res.status(500).json({ error: "Failed to retrieve merchant tokens" });
  }
});

export const processPayment = functions.https.onCall(async (data, context) => {
  // Log the raw data first
  functions.logger.info("Raw data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  
  // Extract payment data from Firebase callable structure  
  const requestData = data.data as PaymentData;
  const paymentData: PaymentData = {
    nonce: requestData.nonce,
    merchantId: requestData.merchantId, 
    amount: requestData.amount,
    oauth_token: requestData.oauth_token,
    items: requestData.items || [],
    customerName: requestData.customerName,
    customerEmail: requestData.customerEmail,
    pickupTime: requestData.pickupTime,
    userId: requestData.userId, // Add userId to paymentData
    coffeeShopData: requestData.coffeeShopData, // Add coffeeShopData to paymentData
  };
  
  // 1. Log the request for debugging
  functions.logger.info("Payment request received:", {
    amount: paymentData.amount,
    merchantId: paymentData.merchantId,
    nonce: "PRESENT",
    oauth_token: "PRESENT",
  });

  // 2. Validate the request data
  functions.logger.info("Validation check:", {
    hasNonce: !!paymentData.nonce,
    hasAmount: !!paymentData.amount,
    hasMerchantId: !!paymentData.merchantId,
    hasOauthToken: !!paymentData.oauth_token,
    nonceValue: paymentData.nonce,
    amountValue: paymentData.amount,
    merchantIdValue: paymentData.merchantId,
    oauthTokenValue: paymentData.oauth_token ? paymentData.oauth_token.substring(0, 10) + "..." : "MISSING"
  });
  
  if (!paymentData.nonce || !paymentData.amount || !paymentData.merchantId || !paymentData.oauth_token) {
    functions.logger.error("Request validation failed", paymentData);
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'nonce', 'amount', 'merchantId', and 'oauth_token' arguments.",
    );
  }

  const {nonce, amount, merchantId, oauth_token, items} = paymentData;
  const idempotencyKey = uuidv4();

  // Initialize Square client with coffee shop's oauth token
  const accessToken = oauth_token;
  const environment = process.env.SQUARE_ENVIRONMENT || "sandbox";
  
  if (!accessToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Square access token not provided"
    );
  }

  const squareClient = new SquareClient({
    token: accessToken,
    environment: environment === "production" ? 
      SquareEnvironment.Production : SquareEnvironment.Sandbox,
  });

  // Fetch locationId from Firestore or Square API
  let locationId = "";
  try {
    const doc = await admin.firestore()
      .collection("merchant_tokens")
      .doc(merchantId)
      .get();
    if (!doc.exists) {
      throw new functions.https.HttpsError("not-found", "Merchant tokens not found");
    }
    const tokenData = doc.data();
    locationId = tokenData?.locationId || "";
    if (!locationId) {
      // Fetch locations from Square API
      const locationsResponse = await squareClient.locations.list();
      if (!locationsResponse.locations || locationsResponse.locations.length === 0) {
        throw new functions.https.HttpsError("not-found", "No locations found for merchant");
      }
      // Use the first location (or add logic to select the right one)
      locationId = locationsResponse.locations[0].id || "";
      // Cache it in Firestore for next time
      await admin.firestore()
        .collection("merchant_tokens")
        .doc(merchantId)
        .update({ locationId });
    }
    if (!locationId) {
      throw new functions.https.HttpsError("internal", "locationId could not be determined");
    }
  } catch (locError) {
    functions.logger.error("Failed to fetch locationId:", locError);
    throw new functions.https.HttpsError("internal", "Failed to fetch locationId");
  }

  let customerId: string | undefined = undefined;
  if (paymentData.customerEmail && paymentData.customerName) {
    try {
      const customersApi = squareClient.customers;
      const searchResp = await customersApi.search({
        query: {
          filter: {
            emailAddress: {
              exact: paymentData.customerEmail
            }
          }
        }
      });
      if (searchResp.customers && searchResp.customers.length > 0) {
        customerId = searchResp.customers[0].id;
        functions.logger.info('Found existing Square customer', { customerId });
      } else {
        // Create new customer
        const createResp = await customersApi.create({
          givenName: paymentData.customerName,
          emailAddress: paymentData.customerEmail
        });
        customerId = createResp.customer?.id;
        functions.logger.info('Created new Square customer', { customerId });
      }
    } catch (customerError) {
      functions.logger.error('Failed to look up or create Square customer:', customerError);
      // Continue without customerId
    }
  }

  try {
    // 3. Process payment with Square API
    functions.logger.info("Processing payment with Square API...", {
      nonce: nonce.substring(0, 10) + "...",
      amount: amount,
      merchantId: merchantId
    });
    
    let orderId: string | undefined = undefined;
    if (items && items.length > 0) {
      // Build line items for Square order
      const lineItems = items.map(item => ({
        name: item.name,
        quantity: item.quantity.toString(),
        basePriceMoney: {
          amount: BigInt(item.price), // price in cents
          currency: "USD" as any,
        },
        note: item.customizations || undefined,
      }));
      // Create the order
      const orderRequest: any = {
        order: {
          locationId: locationId,
          lineItems,
          state: "OPEN", // Explicitly set order to OPEN (active) state
          fulfillments: [
            {
              type: "PICKUP",
              state: "PROPOSED",
              pickupDetails: {
                recipient: {
                  displayName: paymentData.customerName || "Customer"
                },
                pickupAt: paymentData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(), // Use provided time or default to 5 minutes from now
                note: "Order placed via mobile app - awaiting preparation"
              }
            }
          ]
        },
        idempotencyKey: uuidv4(),
      };
      if (customerId) {
        orderRequest.order.customerId = customerId;
      }
      try {
        const orderResponse = await squareClient.orders.create(orderRequest);
        orderId = orderResponse.order?.id;
        functions.logger.info('Square order created', { orderId });
      } catch (orderError: any) {
        functions.logger.error('Failed to create Square order:', orderError);
        // Surface the error to the client for debugging
        if (orderError.errors && Array.isArray(orderError.errors)) {
          throw new functions.https.HttpsError(
            "internal",
            "Failed to create Square order: " + orderError.errors.map((e: any) => e.detail || e.message).join("; ")
          );
        }
        throw new functions.https.HttpsError(
          "internal",
          "Failed to create Square order: " + (orderError.message || JSON.stringify(orderError))
        );
      }
    }

    const request: any = {
      sourceId: nonce,
      idempotencyKey: idempotencyKey,
      amountMoney: {
        amount: BigInt(amount), // Amount in cents
        currency: "USD" as Square.Currency,
      },
      orderId: orderId,
      autocomplete: true,
    };
    if (customerId) {
      request.customerId = customerId;
    }

    const response = await squareClient.payments.create(request);
    
    if (response.payment) {
      const payment = response.payment;
      
      functions.logger.info("Payment successful", {
        transactionId: payment.id,
        status: payment.status,
        amount: payment.amountMoney?.amount?.toString(),
      });

      // 4. Save order to Firestore
      const orderData = {
        transactionId: payment.id,
        paymentStatus: payment.status,
        amount: payment.amountMoney?.amount?.toString(),
        currency: payment.amountMoney?.currency,
        merchantId: merchantId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentMethod: "card",
        receiptNumber: payment.receiptNumber || null,
        receiptUrl: payment.receiptUrl || null,
        userId: paymentData.userId, // Add userId to orderData
        coffeeShopData: paymentData.coffeeShopData, // Add coffeeShopData to orderData
        items: paymentData.items || [], // Store order items
        customerName: paymentData.customerName,
        customerEmail: paymentData.customerEmail,
        pickupTime: paymentData.pickupTime,
        orderId: orderId, // Store Square order ID for status tracking
        status: "SUBMITTED", // Initial order status
      };

      try {
        const paymentId = payment.id;
        if (!paymentId) {
          throw new Error("Payment ID is missing");
        }
        
        await admin.firestore()
          .collection("orders")
          .doc(paymentId)
          .set(orderData);
        
        functions.logger.info("Order saved to Firestore", {
          transactionId: payment.id,
        });
      } catch (firestoreError) {
        functions.logger.error("Failed to save order to Firestore:", firestoreError);
        // Don't fail the payment if Firestore save fails
      }

      // 5. Return the transaction ID on success
      return {
        success: true,
        transactionId: payment.id,
        orderId: orderId, // Include Square order ID for status fetching
        status: payment.status,
        amount: payment.amountMoney?.amount?.toString(),
        currency: payment.amountMoney?.currency,
        receiptNumber: payment.receiptNumber || null,
        receiptUrl: payment.receiptUrl || null,
      };
    } else {
      throw new Error("No payment object in response");
    }
  } catch (error: any) {
    functions.logger.error("Payment failed:", error);

    // Handle specific Square API errors
    if (error.errors) {
      const squareError = error.errors[0];
      functions.logger.error("Square API Error:", {
        category: squareError.category,
        code: squareError.code,
        detail: squareError.detail,
      });
      
      // Map Square error codes to user-friendly messages
      let userMessage = "Payment failed. Please try again.";
      
      if (squareError.code === "CARD_DECLINED") {
        userMessage = "Card was declined. Please try a different payment method.";
      } else if (squareError.code === "INSUFFICIENT_FUNDS") {
        userMessage = "Insufficient funds. Please try a different payment method.";
      } else if (squareError.code === "CVV_FAILURE") {
        userMessage = "CVV verification failed. Please check your card details.";
      } else if (squareError.code === "ADDRESS_VERIFICATION_FAILURE") {
        userMessage = "Address verification failed. Please check your billing address.";
      }
      
      throw new functions.https.HttpsError(
        "failed-precondition",
        userMessage,
        squareError.detail,
      );
    }

    // 5. Throw an HTTPS error to send a structured error back to the client
    throw new functions.https.HttpsError(
      "internal",
      "Payment failed. Please try again.",
      error.message,
    );
  }
});

// Export migration function
export { migrateTokens } from './migrate';

// Square webhook endpoint for order status updates
export const squareWebhook = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Square-Signature');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  try {
    functions.logger.info("Square webhook received:", {
      headers: req.headers,
      body: req.body
    });

    // Verify webhook signature
    const signature = req.headers['x-square-hmacsha256-signature'] as string;
    const webhookUrl = req.url;
    const body = JSON.stringify(req.body);

    if (!signature) {
      functions.logger.error("Missing Square webhook signature");
      res.status(401).send('Unauthorized');
      return;
    }

    functions.logger.info("Webhook signature verification:", {
      hasSignature: !!signature,
      signatureLength: signature.length,
      webhookUrl: webhookUrl,
      bodyLength: body.length,
      secretConfigured: !!process.env.SQUARE_WEBHOOK_SIGNATURE_KEY
    });

    // Temporarily disable signature verification for testing
    functions.logger.info("Skipping signature verification for testing");
    /*
    if (!await verifyWebhookSignature(body, signature, webhookUrl)) {
      functions.logger.error("Invalid webhook signature");
      res.status(401).send('Unauthorized');
      return;
    }
    */

    // Process the webhook
    const webhookData = req.body;
    
    if (!webhookData || !webhookData.type) {
      functions.logger.error("Invalid webhook data");
      res.status(400).send('Invalid webhook data');
      return;
    }

    functions.logger.info("Processing webhook type:", webhookData.type);

    // Handle different webhook types
    switch (webhookData.type) {
      case 'order.updated':
        await handleOrderUpdated(webhookData);
        break;
      case 'order.created':
        await handleOrderCreated(webhookData);
        break;
      case 'order.fulfillment.updated':
        await handleOrderFulfillmentUpdated(webhookData);
        break;
      default:
        functions.logger.info("Unhandled webhook type:", webhookData.type);
    }

    res.status(200).send('OK');
  } catch (error) {
    functions.logger.error("Webhook processing error:", error);
    res.status(500).send('Internal server error');
  }
});

// Handle order.updated webhook
async function handleOrderUpdated(webhookData: any) {
  try {
    // The actual structure is: webhookData.data.object.order_updated
    const order = webhookData.data?.object?.order_updated;
    if (!order) {
      functions.logger.error("No order data in webhook");
      functions.logger.error("Webhook data structure:", JSON.stringify(webhookData, null, 2));
      return;
    }

    const orderId = order.order_id;
    const orderState = order.state;

    functions.logger.info("Order updated:", {
      orderId,
      state: orderState
    });

    // Find the order in our database by Square order ID
    const ordersSnapshot = await admin.firestore()
      .collection("orders")
      .where("orderId", "==", orderId)
      .get();

    if (ordersSnapshot.empty) {
      functions.logger.warn("Order not found in database:", orderId);
      return;
    }

    // Get the current order data to check if we should override it
    const orderDoc = ordersSnapshot.docs[0];
    const currentOrderData = orderDoc.data();
    const currentStatus = currentOrderData.status;

    // Only update if the new status is more specific than the current one
    // This prevents order state "OPEN" from overriding more specific fulfillment states
    const newStatus = mapSquareOrderStateToStatus(orderState);
    
    functions.logger.info("Order state mapping check:", {
      orderId,
      currentStatus,
      newStatus,
      orderState
    });

    // Don't override more specific statuses with general ones
    // "SUBMITTED" (from OPEN) should not override "READY", "IN_PROGRESS", etc.
    // Also prevent any status from overriding final statuses ("COMPLETED" or "CANCELLED") to avoid flickering
    if ((newStatus === "SUBMITTED" && currentStatus !== "SUBMITTED") || 
        (currentStatus === "COMPLETED" && newStatus !== "COMPLETED") ||
        (currentStatus === "CANCELLED" && newStatus !== "CANCELLED")) {
      functions.logger.info("Skipping order state update - current status is more specific or final:", {
        currentStatus,
        newStatus
      });
      return;
    }

    // Update the order
    const batch = admin.firestore().batch();
    const orderRef = orderDoc.ref;
    
    batch.update(orderRef, {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    functions.logger.info("Updated order status:", {
      documentId: orderDoc.id,
      orderId,
      oldStatus: currentStatus,
      newStatus
    });

    await batch.commit();
    functions.logger.info("Successfully updated order status in database");

  } catch (error) {
    functions.logger.error("Error handling order.updated webhook:", error);
  }
}

// Handle order.created webhook
async function handleOrderCreated(webhookData: any) {
  try {
    const order = webhookData.data?.id?.order;
    if (!order) {
      functions.logger.error("No order data in webhook");
      return;
    }

    functions.logger.info("Order created:", {
      orderId: order.id,
      state: order.state
    });

    // We don't need to do anything special for order creation
    // since orders are created through our payment process

  } catch (error) {
    functions.logger.error("Error handling order.created webhook:", error);
  }
}

// Handle order.fulfillment.updated webhook
async function handleOrderFulfillmentUpdated(webhookData: any) {
  try {
    functions.logger.info("Starting fulfillment webhook processing");
    
    // The actual structure is: webhookData.data.object.order_fulfillment_updated
    const fulfillment = webhookData.data?.object?.order_fulfillment_updated;
    if (!fulfillment) {
      functions.logger.error("No fulfillment data in webhook");
      functions.logger.error("Webhook data structure:", JSON.stringify(webhookData, null, 2));
      return;
    }

    const orderId = fulfillment.order_id;
    const fulfillmentState = fulfillment.state;
    const fulfillmentUpdates = fulfillment.fulfillment_update;

    functions.logger.info("Order fulfillment updated:", {
      orderId,
      fulfillmentState,
      fulfillmentUpdates: fulfillmentUpdates
    });

    // Check if there are fulfillment updates that indicate state changes
    if (fulfillmentUpdates && fulfillmentUpdates.length > 0) {
      const latestUpdate = fulfillmentUpdates[fulfillmentUpdates.length - 1];
      const newFulfillmentState = latestUpdate.new_state;
      
      functions.logger.info("Fulfillment state change detected:", {
        oldState: latestUpdate.old_state,
        newState: newFulfillmentState
      });

      // Find the order in our database by Square order ID
      const ordersSnapshot = await admin.firestore()
        .collection("orders")
        .where("orderId", "==", orderId)
        .get();

      if (ordersSnapshot.empty) {
        functions.logger.warn("Order not found in database:", orderId);
        return;
      }

      // Update all matching orders (should be only one)
      const batch = admin.firestore().batch();
      const newStatus = mapSquareFulfillmentStateToStatus(newFulfillmentState);

      functions.logger.info("Mapping fulfillment state:", {
        squareState: newFulfillmentState,
        mappedStatus: newStatus
      });

      ordersSnapshot.docs.forEach(doc => {
        const currentOrderData = doc.data();
        const currentStatus = currentOrderData.status;
        
        // Prevent overriding final statuses ("COMPLETED" or "CANCELLED") to avoid flickering
        if ((currentStatus === "COMPLETED" && newStatus !== "COMPLETED") ||
            (currentStatus === "CANCELLED" && newStatus !== "CANCELLED")) {
          functions.logger.info("Skipping fulfillment update - order already in final state:", {
            documentId: doc.id,
            orderId,
            currentStatus,
            newStatus
          });
          return;
        }
        
        const orderRef = doc.ref;
        batch.update(orderRef, {
          status: newStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        functions.logger.info("Updated order fulfillment status:", {
          documentId: doc.id,
          orderId,
          oldStatus: currentStatus,
          newStatus
        });
      });

      await batch.commit();
      functions.logger.info("Successfully updated order fulfillment status in database");
    } else {
      functions.logger.info("No fulfillment state changes detected");
    }

  } catch (error) {
    functions.logger.error("Error handling order.fulfillment.updated webhook:", error);
  }
}
