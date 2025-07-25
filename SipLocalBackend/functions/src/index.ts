import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {v4 as uuidv4} from "uuid";
import {SquareClient, SquareEnvironment, Square} from "square";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Initialize Firebase Admin
admin.initializeApp();

// Square client will be initialized inside the function

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
