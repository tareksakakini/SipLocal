import * as functions from "firebase-functions";
import {logger} from "./utils";
import * as admin from "firebase-admin";
import {v4 as uuidv4} from "uuid";
import {SquareClient, SquareEnvironment, Square} from "square";
import * as OneSignal from "onesignal-node";
import Stripe from "stripe";
import axios from "axios";
import {appConfig} from "./config";
// import * as crypto from "crypto";

// Initialize Firebase Admin
admin.initializeApp();

// Square client will be initialized inside the function
const squareEnvironmentSetting =
  appConfig.square.environment === "production"
    ? SquareEnvironment.Production
    : SquareEnvironment.Sandbox;

// Webhook signature verification
/*
async function verifyWebhookSignature(
  body: string,
  signature: string,
  webhookUrl: string
): Promise<boolean> {
  try {
    // Get the webhook signature key from Firebase secrets
    const webhookSignatureKey = appConfig.square.webhookSignatureKey;
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
  items?: Array<{
    id?: string;
    name: string;
    quantity: number;
    price: number;
    customizations?: string;
    selectedSizeId?: string | null;
    selectedModifierIdsByList?: Record<string, string[]> | null;
  }>;
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
    posType?: string;
  };
  paymentMethod?: string; // Add payment method
  tokenId?: string; // Add token ID for Apple Pay
  posType?: string; // Add POS type
}

// Define the expected data structure for external payment orders
interface ExternalPaymentData {
  amount: number;
  merchantId: string;
  oauth_token: string;
  items?: Array<{
    id?: string;
    name: string;
    quantity: number;
    price: number;
    customizations?: string;
    selectedSizeId?: string | null;
    selectedModifierIdsByList?: Record<string, string[]> | null;
  }>;
  customerName?: string;
  customerEmail?: string;
  pickupTime?: string; // ISO string for pickup time
  userId?: string;
  coffeeShopData?: {
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
  externalPayment?: boolean; // Flag to indicate external payment
  posType?: string; // POS type: "square" or "clover"
}

// Clover credentials interface
interface CloverCredentials {
  accessToken: string;
  merchantId: string;
}

// Clover order interfaces
interface CloverOrderRequest {
  items: Array<{
    item: { id: string };
    name: string;
    price: number;
    unitQty?: number;
    note?: string;
    printed: boolean;
    exchanged: boolean;
    refunded: boolean;
    isRevenue: boolean;
  }>;
  state: string;
  note?: string;
  manualTransaction: boolean;
  groupLineItems: boolean;
  testMode: boolean;
}

interface CloverOrderResponse {
  id: string;
  currency?: string;
  total?: number;
  paymentState?: string;
  title?: string;
  note?: string;
  state?: string;
  manualTransaction?: boolean;
  groupLineItems?: boolean;
  testMode?: boolean;
  createdTime?: number;
  clientCreatedTime?: number;
  modifiedTime?: number;
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

  logger.info({ message: "getMerchantTokens called", context: { handler: "getMerchantTokens" }, data: { body: req.body } });
  logger.debug({ message: "getMerchantTokens query", context: { handler: "getMerchantTokens" }, data: { query: req.query } });
  
  const merchantId = req.body?.merchantId || req.query?.merchantId;
  
  if (!merchantId) {
    logger.error({ message: "merchantId missing", context: { handler: "getCloverCredentials" } });
    res.status(400).json({ error: "merchantId is required" });
    return;
  }
  
  logger.info({ message: "Fetching merchant tokens", context: { handler: "getMerchantTokens", merchantId } });

  try {
    const doc = await admin.firestore()
      .collection("merchant_tokens")
      .doc(merchantId)
      .get();
    
    if (!doc.exists) {
      logger.warn({ message: "Merchant tokens not found", context: { handler: "getMerchantTokens", merchantId } });
      res.status(404).json({ error: "Merchant tokens not found" });
      return;
    }
    
    const tokenData = doc.data();
    logger.info({ message: "Merchant tokens retrieved", context: { handler: "getMerchantTokens", merchantId } });
    logger.debug({ message: "Merchant token keys", context: { handler: "getMerchantTokens", merchantId }, data: { keys: Object.keys(tokenData || {}) } });
    
    res.status(200).json({ tokens: tokenData });
  } catch (error: any) {
    logger.error({ message: "Failed to load merchant tokens", context: { handler: "getMerchantTokens", merchantId } }, error);
    res.status(500).json({ error: "Failed to retrieve merchant tokens" });
  }
});

// Function to get Clover credentials from Firestore (HTTP trigger)
export const getCloverCredentials = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  logger.info({ message: "getCloverCredentials called", context: { handler: "getCloverCredentials" }, data: { body: req.body } });
  logger.debug({ message: "getCloverCredentials query", context: { handler: "getCloverCredentials" }, data: { query: req.query } });
  
  const merchantId = req.body?.merchantId || req.query?.merchantId;
  
  if (!merchantId) {
    logger.error({ message: "merchantId missing", context: { handler: "getMerchantTokens" } });
    res.status(400).json({ error: "merchantId is required" });
    return;
  }
  
  logger.info({ message: "Fetching Clover credentials", context: { handler: "getCloverCredentials", merchantId } });

  try {
    const doc = await admin.firestore()
      .collection("clover_credentials")
      .doc(merchantId)
      .get();
    
    if (!doc.exists) {
      logger.warn({ message: "Clover credentials not found", context: { handler: "getCloverCredentials", merchantId } });
      res.status(404).json({ error: "Clover credentials not found" });
      return;
    }
    
    const credentialData = doc.data() as CloverCredentials;
    logger.info({ message: "Clover credentials retrieved", context: { handler: "getCloverCredentials", merchantId } });
    logger.debug({ message: "Clover credential keys", context: { handler: "getCloverCredentials", merchantId }, data: { keys: Object.keys(credentialData || {}) } });
    
    res.status(200).json({ credentials: credentialData });
  } catch (error: any) {
    logger.error({ message: "Failed to load Clover credentials", context: { handler: "getCloverCredentials", merchantId } }, error);
    res.status(500).json({ error: "Failed to retrieve Clover credentials" });
  }
});

export const processPayment = functions.https.onCall(async (data, context) => {
  // Log the raw data first
  functions.logger.info("Raw data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  
  // Extract payment data - check if data is nested in data property
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    // Data is nested (some clients send it this way)
    requestData = data.data;
    functions.logger.info("Using nested data.data structure");
  } else {
    // Data is direct (most clients send it this way)
    requestData = data;
    functions.logger.info("Using direct data structure");
  }
  
  functions.logger.info("Extracted requestData for payment:", {
    hasNonce: !!requestData?.nonce,
    hasAmount: !!requestData?.amount,
    hasMerchantId: !!requestData?.merchantId,
    hasOauthToken: !!requestData?.oauth_token
  });
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
  if (!accessToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Square access token not provided"
    );
  }

  const squareClient = new SquareClient({
    token: accessToken,
    environment: squareEnvironmentSetting,
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
        functions.logger.info('Creating Square order with request:', {
          hasLineItems: !!orderRequest.order.lineItems?.length,
          locationId: orderRequest.order.locationId,
          customerPresent: !!orderRequest.order.customerId
        });
        const orderResponse = await squareClient.orders.create(orderRequest);
        orderId = orderResponse.order?.id;
        functions.logger.info('Square order created successfully', { 
          orderId,
          orderExists: !!orderResponse.order,
          orderState: orderResponse.order?.state
        });
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
      autocomplete: false, // Only authorize, don't complete payment yet
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
         items: paymentData.items || [], // Store order items (now include ids and selection metadata)
        customerName: paymentData.customerName,
        customerEmail: paymentData.customerEmail,
        pickupTime: paymentData.pickupTime,
        orderId: orderId, // Store Square order ID for status tracking
        status: "AUTHORIZED", // Payment authorized, awaiting confirmation
        oauthToken: paymentData.oauth_token, // Store for completion later
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

        // Schedule order completion after 30 seconds using Cloud Tasks
        const completionTime = new Date(Date.now() + 30000); // 30 seconds from now
        
        // Store the completion task info in Firestore for tracking
        await admin.firestore()
          .collection("completion_tasks")
          .doc(paymentId)
          .set({
            paymentId: paymentId,
            scheduledFor: completionTime,
            status: "SCHEDULED",
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });

        // For now, use setTimeout as fallback but add better error handling
        setTimeout(async () => {
          try {
            functions.logger.info("Attempting to complete authorized order:", paymentId);
            await completeAuthorizedOrder(paymentId);
            
            // Mark completion task as completed
            await admin.firestore()
              .collection("completion_tasks")
              .doc(paymentId)
              .update({
                status: "COMPLETED",
                completedAt: admin.firestore.FieldValue.serverTimestamp()
              });
              
          } catch (error) {
            functions.logger.error("Failed to complete authorized order:", error);
            
            // Mark completion task as failed
            await admin.firestore()
              .collection("completion_tasks")
              .doc(paymentId)
              .update({
                status: "FAILED",
                error: (error as Error).message,
                failedAt: admin.firestore.FieldValue.serverTimestamp()
              });
          }
        }, 30000);
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

// Function to process Stripe payment and create Square order
export const processStripePayment = functions.https.onCall(async (data, context) => {
  functions.logger.info("=== STRIPE PAYMENT PROCESSING FUNCTION ===");
  functions.logger.info("Raw Stripe payment data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  
  // Extract payment data - check if data is nested in data property
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    requestData = data.data;
    functions.logger.info("Using nested data.data structure");
  } else {
    requestData = data;
    functions.logger.info("Using direct data structure");
  }
  
  functions.logger.info("Extracted requestData:", {
    hasAmount: !!requestData?.amount,
    hasMerchantId: !!requestData?.merchantId,
    hasOauthToken: !!requestData?.oauth_token,
    hasPaymentMethod: !!requestData?.paymentMethod,
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    paymentMethod: requestData?.paymentMethod
  });
  
  const paymentData = {
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token,
    items: requestData?.items || [],
    customerName: requestData?.customerName,
    customerEmail: requestData?.customerEmail,
    pickupTime: requestData?.pickupTime,
    userId: requestData?.userId,
    coffeeShopData: requestData?.coffeeShopData,
    paymentMethod: requestData?.paymentMethod || "stripe"
  };

  functions.logger.info("Stripe payment request received:", {
    amount: paymentData.amount,
    merchantId: paymentData.merchantId,
    hasOauthToken: !!paymentData.oauth_token,
    paymentMethod: paymentData.paymentMethod
  });

  // Validate the request data
  if (!paymentData.amount || !paymentData.merchantId || !paymentData.oauth_token) {
    functions.logger.error("Request validation failed", {
      paymentData,
      hasAmount: !!paymentData.amount,
      hasMerchantId: !!paymentData.merchantId,
      hasOauthToken: !!paymentData.oauth_token
    });
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'amount', 'merchantId', and 'oauth_token' arguments."
    );
  }

  const {amount, merchantId, oauth_token} = paymentData;
  const transactionId = uuidv4(); // Generate unique transaction ID

  // Initialize Stripe client
  const stripeSecretKey = appConfig.stripe.secretKey;
  if (!stripeSecretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe secret key not configured"
    );
  }

  const stripe = new Stripe(stripeSecretKey);

  // Initialize Square client for order creation
  const squareClient = new SquareClient({
    token: oauth_token,
    environment: squareEnvironmentSetting,
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
      const locationsResponse = await squareClient.locations.list();
      if (!locationsResponse.locations || locationsResponse.locations.length === 0) {
        throw new functions.https.HttpsError("not-found", "No locations found for merchant");
      }
      locationId = locationsResponse.locations[0].id || "";
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

  try {
    // 1. Process payment with Stripe
    functions.logger.info("Processing payment with Stripe...", {
      amount: amount,
      merchantId: merchantId
    });

    // Create Stripe PaymentIntent with manual capture (authorize now, capture later)
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // amount in cents
      currency: 'usd',
      capture_method: 'manual', // This allows us to authorize now and capture later
      description: `Order from ${paymentData.coffeeShopData?.name || 'Coffee Shop'}`,
      receipt_email: paymentData.customerEmail, // Use receipt_email instead of customer_email
      metadata: {
        merchantId: merchantId,
        transactionId: transactionId,
        userId: paymentData.userId || '',
        coffeeShop: paymentData.coffeeShopData?.name || '',
        customerEmail: paymentData.customerEmail || '', // Store email in metadata
        customerName: paymentData.customerName || ''
      },
      automatic_payment_methods: {
        enabled: true,
      },
      // Client will collect payment method and confirm, but payment will only be authorized
    });

    functions.logger.info("Stripe PaymentIntent created:", {
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount,
      clientSecret: paymentIntent.client_secret ? "present" : "missing"
    });

    // Note: We will create the Square order later during payment capture phase
    // This ensures the merchant only sees the order after payment is confirmed
    functions.logger.info('Skipping Square order creation during authorization phase');

    // 3. Save order to Firestore
    const firestoreOrderData = {
      transactionId: transactionId,
      stripePaymentIntentId: paymentIntent.id,
      paymentStatus: paymentIntent.status.toUpperCase(),
      amount: amount.toString(),
      currency: "USD",
      merchantId: merchantId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: "stripe",
      receiptNumber: null,
      receiptUrl: null, // Could add Stripe receipt URL if needed
      userId: paymentData.userId,
      coffeeShopData: paymentData.coffeeShopData,
      items: paymentData.items || [],
      customerName: paymentData.customerName,
      customerEmail: paymentData.customerEmail,
      pickupTime: paymentData.pickupTime,
      orderId: null, // Square order will be created during capture phase
      status: "AUTHORIZED", // Order authorized, awaiting payment completion
    };

    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .set(firestoreOrderData);
      
      functions.logger.info("Stripe payment order saved to Firestore", {
        transactionId: transactionId,
      });
    } catch (firestoreError) {
      functions.logger.error("Failed to save Stripe payment order to Firestore:", firestoreError);
      // Continue anyway since payment was successful
    }

    // 4. Return success response with client secret for payment completion
    return {
      success: true,
      transactionId: transactionId,
      orderId: null, // Square order will be created during capture phase
      status: "AUTHORIZED", // Payment authorized, awaiting capture
      amount: amount.toString(),
      currency: "USD",
      stripePaymentIntentId: paymentIntent.id,
      stripeClientSecret: paymentIntent.client_secret, // Include client secret for iOS app
      receiptNumber: null,
      receiptUrl: null,
    };

  } catch (error: any) {
    functions.logger.error("Stripe payment failed:", error);

    // Handle Stripe specific errors
    if (error.type && error.type.startsWith('Stripe')) {
      functions.logger.error("Stripe API Error:", {
        type: error.type,
        code: error.code,
        message: error.message,
      });
      
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment failed: " + error.message,
        error.message,
      );
    }

    throw new functions.https.HttpsError(
      "internal",
      "Failed to process Stripe payment.",
      error.message,
    );
  }
});

// Function to process Apple Pay payment through Stripe
// Helper function to capture Apple Pay payment after 30 seconds
async function captureApplePayPayment(transactionId: string) {
  functions.logger.info("=== CAPTURING APPLE PAY PAYMENT ===", { transactionId });

  try {
    // Get order from Firestore
    const orderDoc = await admin.firestore()
      .collection("orders")
      .doc(transactionId)
      .get();

    if (!orderDoc.exists) {
      throw new Error(`Order not found: ${transactionId}`);
    }

    const orderData = orderDoc.data();
    if (!orderData) {
      throw new Error(`Order data is empty: ${transactionId}`);
    }

    // Check if already captured
    if (orderData.paymentStatus === "CAPTURED" || orderData.status === "SUBMITTED") {
      functions.logger.info("Payment already captured", { transactionId });
      return;
    }

    const stripeChargeId = orderData.stripeChargeId;
    const oauth_token = orderData.oauthToken;
    const locationId = orderData.locationId;
    const merchantId = orderData.merchantId;

    if (!stripeChargeId) {
      throw new Error("Stripe charge ID not found in order");
    }

    // Initialize Stripe
    const stripeSecretKey = appConfig.stripe.secretKey;
    if (!stripeSecretKey) {
      throw new Error("Stripe secret key not configured");
    }
    const stripe = new Stripe(stripeSecretKey);

    // Capture the charge
    functions.logger.info("Capturing Stripe charge:", { chargeId: stripeChargeId });
    const capturedCharge = await stripe.charges.capture(stripeChargeId);
    
    functions.logger.info("Charge captured successfully:", {
      chargeId: capturedCharge.id,
      status: capturedCharge.status,
      captured: capturedCharge.captured
    });

    // Create Square order now that payment is captured
    let squareOrderId: string | undefined = undefined;
    
    if (orderData.items && orderData.items.length > 0 && oauth_token) {
      try {
        // Initialize Square client
        const squareClient = new SquareClient({
          token: oauth_token,
          environment: squareEnvironmentSetting,
        });

        const lineItems = orderData.items.map((item: any) => ({
          name: item.name,
          quantity: item.quantity.toString(),
          basePriceMoney: {
            amount: BigInt(item.price),
            currency: "USD" as any,
          },
          note: item.customizations || undefined,
        }));

        const orderRequest: any = {
          order: {
            locationId: locationId,
            lineItems,
            state: "OPEN",
            source: {
              name: "SipLocal App - Apple Pay (Captured)"
            },
            fulfillments: [
              {
                type: "PICKUP",
                state: "PROPOSED",
                pickupDetails: {
                  recipient: {
                    displayName: orderData.customerName || "Customer",
                    emailAddress: orderData.customerEmail || undefined
                  },
                  pickupAt: orderData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(),
                  note: "Order placed via mobile app - Paid with Apple Pay (Payment Captured)"
                }
              }
            ]
          },
          idempotencyKey: uuidv4(),
        };

        functions.logger.info('Creating Square order after Apple Pay capture...');
        const orderResponse = await squareClient.orders.create(orderRequest);
        squareOrderId = orderResponse.order?.id;
        
        functions.logger.info('Square order created after capture:', {
          orderId: squareOrderId,
          merchantId: merchantId
        });

        // Create external payment record in Square
        if (squareOrderId) {
          try {
            await squareClient.payments.create({
              idempotencyKey: uuidv4(),
              sourceId: 'EXTERNAL',
              externalDetails: {
                type: 'CARD',
                source: 'Stripe Apple Pay'
              },
              amountMoney: {
                amount: BigInt(orderData.amount),
                currency: 'USD'
              },
              orderId: squareOrderId,
              locationId: locationId
            });
            functions.logger.info('External payment record created in Square');
          } catch (paymentError) {
            functions.logger.error('Failed to create external payment record:', paymentError);
          }
        }
      } catch (squareError) {
        functions.logger.error('Failed to create Square order during capture:', squareError);
      }
    }

    // Update order in Firestore
    await admin.firestore()
      .collection("orders")
      .doc(transactionId)
      .update({
        paymentStatus: "CAPTURED",
        status: "SUBMITTED",
        orderId: squareOrderId,
        receiptUrl: capturedCharge.receipt_url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    functions.logger.info("Apple Pay payment captured and order updated", {
      transactionId,
      squareOrderId,
      status: "SUBMITTED"
    });

  } catch (error) {
    functions.logger.error("Error capturing Apple Pay payment:", error);
    
    // Update order status to failed
    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .update({
          paymentStatus: "CAPTURE_FAILED",
          error: (error as Error).message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (updateError) {
      functions.logger.error("Failed to update order status:", updateError);
    }
    
    throw error;
  }
}

// Function to cancel an Apple Pay authorization
export const cancelApplePayPayment = functions.https.onCall(async (data, context) => {
  // Extract data - check if data is nested
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    requestData = (data as any).data;
  } else {
    requestData = data;
  }
  
  const transactionId = requestData?.transactionId;
  
  if (!transactionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Transaction ID is required"
    );
  }
  
  functions.logger.info("Apple Pay cancellation requested:", { transactionId });
  
  try {
    // Get order from Firestore
    const orderDoc = await admin.firestore()
      .collection("orders")
      .doc(transactionId)
      .get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found");
    }

    const orderData = orderDoc.data();
    if (!orderData) {
      throw new functions.https.HttpsError("not-found", "Order data is empty");
    }

    // Check if already captured
    if (orderData.paymentStatus === "CAPTURED" || orderData.status === "SUBMITTED") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment already captured and cannot be cancelled"
      );
    }

    const stripeChargeId = orderData.stripeChargeId;
    if (!stripeChargeId) {
      throw new functions.https.HttpsError("not-found", "Stripe charge ID not found");
    }

    // Initialize Stripe
    const stripeSecretKey = appConfig.stripe.secretKey;
    if (!stripeSecretKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Stripe secret key not configured"
      );
    }
    const stripe = new Stripe(stripeSecretKey);

    // Refund the uncaptured charge (this cancels the authorization)
    functions.logger.info("Refunding uncaptured charge:", { chargeId: stripeChargeId });
    const refund = await stripe.refunds.create({
      charge: stripeChargeId,
    });
    
    functions.logger.info("Charge refunded/cancelled successfully:", {
      refundId: refund.id,
      status: refund.status
    });

    // Update order in Firestore
    await admin.firestore()
      .collection("orders")
      .doc(transactionId)
      .update({
        paymentStatus: "CANCELLED",
        status: "CANCELLED",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    functions.logger.info("Apple Pay payment cancelled", { transactionId });
    
    return { 
      success: true, 
      message: "Payment cancelled successfully",
      refundId: refund.id 
    };
    
  } catch (error) {
    functions.logger.error("Apple Pay cancellation failed:", error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      "internal",
      `Failed to cancel payment: ${(error as Error).message}`
    );
  }
});

// Callable function to capture Apple Pay payment manually (for cancellation support)
export const captureApplePayPaymentManual = functions.https.onCall(async (data, context) => {
  // Extract data - check if data is nested
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    requestData = (data as any).data;
  } else {
    requestData = data;
  }
  
  const transactionId = requestData?.transactionId;
  
  if (!transactionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Transaction ID is required"
    );
  }
  
  functions.logger.info("Manual Apple Pay capture requested:", { transactionId });
  
  try {
    await captureApplePayPayment(transactionId);
    return { success: true, message: "Payment captured successfully" };
  } catch (error) {
    functions.logger.error("Manual Apple Pay capture failed:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to capture payment: ${(error as Error).message}`
    );
  }
});

export const processApplePayPayment = functions.https.onCall(async (data, context) => {
  functions.logger.info("=== APPLE PAY PAYMENT PROCESSING FUNCTION ===");
  functions.logger.info("Raw Apple Pay payment data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  
  // Extract payment data - check if data is nested in data property
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    requestData = data.data;
    functions.logger.info("Using nested data.data structure");
  } else {
    requestData = data;
    functions.logger.info("Using direct data structure");
  }
  
  functions.logger.info("Extracted requestData:", {
    hasAmount: !!requestData?.amount,
    hasMerchantId: !!requestData?.merchantId,
    hasOauthToken: !!requestData?.oauth_token,
    hasPaymentMethod: !!requestData?.paymentMethod,
    hasApplePayData: !!requestData?.applePayData,
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    paymentMethod: requestData?.paymentMethod
  });
  
  const paymentData = {
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token,
    items: requestData?.items || [],
    customerName: requestData?.customerName,
    customerEmail: requestData?.customerEmail,
    pickupTime: requestData?.pickupTime,
    userId: requestData?.userId,
    coffeeShopData: requestData?.coffeeShopData,
    paymentMethod: requestData?.paymentMethod || "apple_pay",
    tokenId: requestData?.tokenId,
    posType: requestData?.posType
  };

  // Determine POS type and route to appropriate handler
  const posType = paymentData.posType || paymentData.coffeeShopData?.posType || "square";
  functions.logger.info("Apple Pay processing with POS type:", posType);

  // Route to Clover Apple Pay handler if needed
  if (posType === "clover") {
    return processApplePayPaymentClover(paymentData, context);
  }

  functions.logger.info("Apple Pay payment request received:", {
    amount: paymentData.amount,
    merchantId: paymentData.merchantId,
    hasOauthToken: !!paymentData.oauth_token,
    paymentMethod: paymentData.paymentMethod,
    posType: posType,
    tokenId: paymentData.tokenId
  });

  // Validate the request data
  if (!paymentData.amount || !paymentData.merchantId || !paymentData.oauth_token || !paymentData.tokenId) {
    functions.logger.error("Request validation failed", {
      paymentData,
      hasAmount: !!paymentData.amount,
      hasMerchantId: !!paymentData.merchantId,
      hasOauthToken: !!paymentData.oauth_token,
      hasTokenId: !!paymentData.tokenId
    });
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'amount', 'merchantId', 'oauth_token', and 'tokenId' arguments."
    );
  }

  const {amount, merchantId, oauth_token} = paymentData;
  const transactionId = uuidv4(); // Generate unique transaction ID

  // Initialize Stripe client
  const stripeSecretKey = appConfig.stripe.secretKey;
  if (!stripeSecretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe secret key not configured"
    );
  }

  const stripe = new Stripe(stripeSecretKey);

  // Initialize Square client for order creation
  const squareClient = new SquareClient({
    token: oauth_token,
    environment: squareEnvironmentSetting,
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
      const locationsResponse = await squareClient.locations.list();
      if (!locationsResponse.locations || locationsResponse.locations.length === 0) {
        throw new functions.https.HttpsError("not-found", "No locations found for merchant");
      }
      locationId = locationsResponse.locations[0].id || "";
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

  try {
    // 1. Process Apple Pay payment with Stripe
    functions.logger.info("Processing Apple Pay payment with Stripe...", {
      amount: amount,
      merchantId: merchantId
    });

    // Use the Stripe Token created on the client side (legacy Charges API approach)
    functions.logger.info("Using Stripe Token created on client:", {
      tokenId: paymentData.tokenId
    });

    // Create charge using the token with capture=false for authorization only
    functions.logger.info("Creating Stripe charge with capture=false for Apple Pay authorization", {
      amount: amount,
      tokenId: paymentData.tokenId,
      capture: false
    });
    
    const charge = await stripe.charges.create({
      amount: amount, // amount in cents
      currency: 'usd',
      source: paymentData.tokenId, // Use the token ID
      capture: false, // IMPORTANT: Authorize only, don't capture yet
      description: `Apple Pay order from ${paymentData.coffeeShopData?.name || 'Coffee Shop'}`,
      receipt_email: paymentData.customerEmail,
      metadata: {
        merchantId: merchantId,
        transactionId: transactionId,
        userId: paymentData.userId || '',
        coffeeShop: paymentData.coffeeShopData?.name || '',
        customerEmail: paymentData.customerEmail || '',
        customerName: paymentData.customerName || '',
        paymentMethod: 'apple_pay'
      },
    });
    
    functions.logger.info("Raw Stripe charge response:", {
      id: charge.id,
      status: charge.status,
      captured: charge.captured,
      amount: charge.amount,
      amount_captured: charge.amount_captured,
      amount_refunded: charge.amount_refunded,
      source: {
        id: charge.source?.id,
        type: (charge.source as any)?.type
      }
    });

    functions.logger.info("Stripe Charge created (AUTHORIZED ONLY):", {
      chargeId: charge.id,
      status: charge.status,
      captured: charge.captured,
      amount: charge.amount,
      captureMethod: "manual (capture=false)"
    });

    // Check if payment was successfully authorized (status should be 'succeeded' but not captured)
    if (charge.status !== 'succeeded') {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Apple Pay payment authorization failed with status: ${charge.status}`
      );
    }
    
    // Verify that the charge is authorized but not captured
    if (charge.captured === true) {
      functions.logger.error("CRITICAL: Charge was unexpectedly captured immediately! This breaks the authorize-then-capture flow:", {
        chargeId: charge.id,
        captured: charge.captured,
        amount_captured: charge.amount_captured,
        tokenType: (charge.source as any)?.type
      });
      
      // If charge was captured immediately, we need to handle it differently
      // The order should go straight to SUBMITTED status since payment is complete
      const firestoreOrderDataCaptured = {
        transactionId: transactionId,
        stripeChargeId: charge.id,
        paymentStatus: "CAPTURED", // Payment was captured immediately
        amount: amount.toString(),
        currency: "USD",
        merchantId: merchantId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentMethod: "apple_pay",
        receiptNumber: null,
        receiptUrl: charge.receipt_url,
        userId: paymentData.userId,
        coffeeShopData: paymentData.coffeeShopData,
        items: paymentData.items || [],
        customerName: paymentData.customerName,
        customerEmail: paymentData.customerEmail,
        pickupTime: paymentData.pickupTime,
        orderId: null, // Square order will be created immediately
        status: "SUBMITTED", // Order is submitted since payment is complete
        oauthToken: oauth_token,
        locationId: locationId,
        immediateCapture: true // Flag to indicate this was captured immediately
      };
      
      // Create Square order immediately since payment is complete
      let squareOrderIdImmediate: string | undefined = undefined;
      if (paymentData.items && paymentData.items.length > 0) {
        try {
          const lineItems = paymentData.items.map((item: any) => ({
            name: item.name,
            quantity: item.quantity.toString(),
            basePriceMoney: {
              amount: BigInt(item.price),
              currency: "USD" as any,
            },
            note: item.customizations || undefined,
          }));

          const orderRequest: any = {
            order: {
              locationId: locationId,
              lineItems,
              state: "OPEN",
              source: {
                name: "SipLocal App - Apple Pay (Immediate Capture)"
              },
              fulfillments: [
                {
                  type: "PICKUP",
                  state: "PROPOSED",
                  pickupDetails: {
                    recipient: {
                      displayName: paymentData.customerName || "Customer",
                      emailAddress: paymentData.customerEmail || undefined
                    },
                    pickupAt: paymentData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(),
                    note: "Order placed via mobile app - Apple Pay (Immediate Capture)"
                  }
                }
              ]
            },
            idempotencyKey: uuidv4(),
          };

          const orderResponse = await squareClient.orders.create(orderRequest);
          squareOrderIdImmediate = orderResponse.order?.id;
          (firestoreOrderDataCaptured as any).orderId = squareOrderIdImmediate;
          
          functions.logger.info('Square order created immediately due to immediate capture:', {
            orderId: squareOrderIdImmediate
          });
        } catch (squareError) {
          functions.logger.error('Failed to create Square order for immediate capture:', squareError);
        }
      }
      
      // Save order with SUBMITTED status
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .set(firestoreOrderDataCaptured);
      
      return {
        success: true,
        transactionId: transactionId,
        orderId: squareOrderIdImmediate,
        status: "SUBMITTED", // Immediate capture means submitted
        amount: amount.toString(),
        currency: "USD",
        stripeChargeId: charge.id,
        receiptNumber: null,
        receiptUrl: charge.receipt_url,
        immediateCapture: true
      };
    }

    // Receipt URL will be available after capture
    const receiptUrl = null; // Will be set during capture

    // 2. Skip Square order creation during authorization phase
    // Square order will be created after payment capture (30 seconds later)
    let squareOrderId: string | undefined = undefined;
    
    functions.logger.info('Skipping Square order creation during Apple Pay authorization phase');
    functions.logger.info('Square order will be created after payment capture in 30 seconds');
    
    // Comment out Square order creation for now
    if (false && paymentData.items && paymentData.items.length > 0) {
      try {
        const lineItems = paymentData.items.map((item: any) => ({
          name: item.name,
          quantity: item.quantity.toString(),
          basePriceMoney: {
            amount: BigInt(item.price),
            currency: "USD" as any,
          },
          note: item.customizations || undefined,
        }));

        const orderRequest: any = {
          order: {
            locationId: locationId,
            lineItems,
            state: "OPEN",
            source: {
              name: "SipLocal App - Apple Pay (Completed)"
            },
            fulfillments: [
              {
                type: "PICKUP",
                state: "PROPOSED",
                pickupDetails: {
                  recipient: {
                    displayName: paymentData.customerName || "Customer",
                    emailAddress: paymentData.customerEmail || undefined
                  },
                  pickupAt: paymentData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(),
                  note: "Order placed via mobile app - Paid with Apple Pay (Payment Completed)"
                }
              }
            ]
          },
          idempotencyKey: uuidv4(),
        };

        functions.logger.info('Creating Square order after Apple Pay payment...');
        const orderResponse = await squareClient.orders.create(orderRequest);
        squareOrderId = orderResponse.order?.id;
        functions.logger.info('Square order created successfully after Apple Pay payment', { 
          orderId: squareOrderId,
          orderState: orderResponse.order?.state,
          transactionId: transactionId
        });

        // Create external payment record in Square to link with order
        if (squareOrderId) {
          try {
            await squareClient.payments.create({
              idempotencyKey: uuidv4(),
              sourceId: 'EXTERNAL',
              externalDetails: {
                type: 'OTHER',
                source: 'Apple Pay via Stripe (Completed)'
              },
              amountMoney: {
                amount: BigInt(amount),
                currency: 'USD'
              },
              orderId: squareOrderId,
              locationId: locationId
            });
            functions.logger.info('External payment record created in Square for Apple Pay');
          } catch (paymentError: any) {
            functions.logger.error('Failed to create external payment record for Apple Pay (order still created):', paymentError);
          }
        }
      } catch (orderError: any) {
        functions.logger.error('Failed to create Square order after Apple Pay payment:', orderError);
        // Don't fail the entire operation - payment was successful
      }
    }

    // 3. Save order to Firestore with AUTHORIZED status
    const firestoreOrderData = {
      transactionId: transactionId,
      stripeChargeId: charge.id,
      paymentStatus: "AUTHORIZED", // Payment authorized but not captured yet
      amount: amount.toString(),
      currency: "USD",
      merchantId: merchantId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: "apple_pay",
      receiptNumber: null,
      receiptUrl: receiptUrl || null, // Will be null until capture
      userId: paymentData.userId,
      coffeeShopData: paymentData.coffeeShopData,
      items: paymentData.items || [],
      customerName: paymentData.customerName,
      customerEmail: paymentData.customerEmail,
      pickupTime: paymentData.pickupTime,
      orderId: squareOrderId || null, // Will be null until capture
      status: "AUTHORIZED", // Order authorized but not submitted yet
      oauthToken: oauth_token, // Store for completion later
      locationId: locationId, // Store for Square order creation later
    };

    functions.logger.info("Saving Apple Pay order to Firestore with AUTHORIZED status:", {
      transactionId: transactionId,
      paymentStatus: "AUTHORIZED",
      status: "AUTHORIZED",
      stripeChargeId: charge.id,
      captured: charge.captured
    });

    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .set(firestoreOrderData);
      
      functions.logger.info("Apple Pay payment order saved to Firestore", {
        transactionId: transactionId,
      });
    } catch (firestoreError) {
      functions.logger.error("Failed to save Apple Pay payment order to Firestore:", firestoreError);
      // Continue anyway since payment was successful
    }

    // 4. Schedule payment capture after 30 seconds (backup mechanism)
    // Note: The iOS app will also trigger capture after 30 seconds as the primary mechanism
    setTimeout(async () => {
      try {
        functions.logger.info("Server timeout: Attempting to capture Apple Pay payment:", transactionId);
        
        // Check if payment is still in AUTHORIZED state before capturing
        const orderDoc = await admin.firestore()
          .collection("orders")
          .doc(transactionId)
          .get();
          
        if (orderDoc.exists) {
          const orderData = orderDoc.data();
          if (orderData?.paymentStatus === "AUTHORIZED") {
            functions.logger.info("Payment still authorized, proceeding with server-side capture");
            await captureApplePayPayment(transactionId);
          } else {
            functions.logger.info("Payment already processed, skipping server-side capture", {
              currentStatus: orderData?.paymentStatus
            });
          }
        }
      } catch (error) {
        functions.logger.error("Failed to capture Apple Pay payment via server timeout:", error);
      }
    }, 32000); // Slightly longer than iOS timer to serve as backup

    // 5. Return success response with AUTHORIZED status
    return {
      success: true,
      transactionId: transactionId,
      orderId: squareOrderId || null, // Will be null for now
      status: "AUTHORIZED", // Payment authorized, will be captured in 30 seconds
      amount: amount.toString(),
      currency: "USD",
      stripeChargeId: charge.id,
      receiptNumber: null,
      receiptUrl: receiptUrl || null, // Will be null until capture
    };

  } catch (error: any) {
    functions.logger.error("Apple Pay payment failed:", error);

    // Handle Stripe specific errors
    if (error.type && error.type.startsWith('Stripe')) {
      functions.logger.error("Stripe API Error:", {
        type: error.type,
        code: error.code,
        message: error.message,
      });
      
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Apple Pay payment failed: " + error.message,
        error.message,
      );
    }

    throw new functions.https.HttpsError(
      "internal",
      "Failed to process Apple Pay payment.",
      error.message,
    );
  }
});

// Function to complete Stripe payment after 30-second delay
export const completeStripePayment = functions.https.onCall(async (data, context) => {
  functions.logger.info("=== COMPLETE STRIPE PAYMENT FUNCTION ===");
  functions.logger.info("Complete payment data received:", data);
  
  // Extract data - handle nested structure
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    requestData = data.data;
  } else {
    requestData = data;
  }
  
  const clientSecret = requestData.clientSecret;
  const transactionId = requestData.transactionId;
  
  if (!clientSecret || !transactionId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "clientSecret and transactionId are required"
    );
  }
  
  // Initialize Stripe client
  const stripeSecretKey = appConfig.stripe.secretKey;
  if (!stripeSecretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe secret key not configured"
    );
  }
  
  const stripe = new Stripe(stripeSecretKey);
  
  try {
    // Extract PaymentIntent ID from client secret
    const paymentIntentId = clientSecret.split('_secret_')[0];
    
    // Retrieve the PaymentIntent to check its status
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    
    functions.logger.info("PaymentIntent status:", {
      id: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount
    });
    
    // Check if the payment is ready to be captured
    if (paymentIntent.status === 'requires_capture') {
      // Capture the authorized payment
      functions.logger.info("Capturing authorized payment:", {
        id: paymentIntent.id,
        amount: paymentIntent.amount
      });
      
      const capturedPaymentIntent = await stripe.paymentIntents.capture(paymentIntent.id);
      functions.logger.info("Payment captured successfully:", {
        id: capturedPaymentIntent.id,
        status: capturedPaymentIntent.status
      });
    } else if (paymentIntent.status === 'succeeded') {
      // Payment was already captured (shouldn't happen in our flow, but handle gracefully)
      functions.logger.info("Payment was already captured:", {
        id: paymentIntent.id,
        status: paymentIntent.status
      });
    } else {
      // Payment is in an unexpected state
      functions.logger.error("PaymentIntent is not ready for capture:", {
        id: paymentIntent.id,
        status: paymentIntent.status
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Payment is in unexpected state: ${paymentIntent.status}. Expected 'requires_capture' or 'succeeded'.`
      );
    }
    
    // Get the order data from Firestore to create Square order
    let orderData: any = null;
    let squareOrderId: string | undefined = undefined;
    
    try {
      const orderDoc = await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .get();
        
      if (!orderDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Order not found in Firestore"
        );
      }
      
      orderData = orderDoc.data();
      functions.logger.info("Retrieved order data for Square order creation:", {
        transactionId: transactionId,
        hasItems: !!(orderData?.items && orderData.items.length > 0),
        merchantId: orderData?.merchantId
      });
    } catch (firestoreError) {
      functions.logger.error("Failed to retrieve order data:", firestoreError);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to retrieve order data"
      );
    }
    
    // Now create the Square order since payment is being captured
    if (orderData && orderData.items && orderData.items.length > 0) {
      try {
        // Get merchant tokens for Square client
        let oauthToken = "";
        let locationId = "";
        if (orderData.merchantId) {
          const merchantDoc = await admin.firestore()
            .collection("merchant_tokens")
            .doc(orderData.merchantId)
            .get();
          if (merchantDoc.exists) {
            const merchantData = merchantDoc.data();
            oauthToken = merchantData?.oauth_token || "";
            locationId = merchantData?.locationId || "";
          }
        }
        
        if (!oauthToken) {
          throw new Error("No oauth token available for Square order creation");
        }
        
        // Initialize Square client
        const squareClient = new SquareClient({
          token: oauthToken,
          environment: squareEnvironmentSetting,
        });
        
        // Fetch location ID if not available
        if (!locationId) {
          const locationsResponse = await squareClient.locations.list();
          if (locationsResponse.locations && locationsResponse.locations.length > 0) {
            locationId = locationsResponse.locations[0].id || "";
          }
        }
        
        if (!locationId) {
          throw new Error("No location ID available for Square order creation");
        }
        
        const lineItems = orderData.items.map((item: any) => ({
          name: item.name,
          quantity: item.quantity.toString(),
          basePriceMoney: {
            amount: BigInt(item.price),
            currency: "USD" as any,
          },
          note: item.customizations || undefined,
        }));

        const orderRequest: any = {
          order: {
            locationId: locationId,
            lineItems,
            state: "OPEN",
            source: {
              name: "SipLocal App - Stripe Payment (Captured)"
            },
            fulfillments: [
              {
                type: "PICKUP",
                state: "PROPOSED",
                pickupDetails: {
                  recipient: {
                    displayName: orderData.customerName || "Customer",
                    emailAddress: orderData.customerEmail || undefined
                  },
                  pickupAt: orderData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(),
                  note: "Order placed via mobile app - Paid with Stripe (Payment Captured)"
                }
              }
            ]
          },
          idempotencyKey: uuidv4(),
        };

        functions.logger.info('Creating Square order after payment capture...');
        const orderResponse = await squareClient.orders.create(orderRequest);
        squareOrderId = orderResponse.order?.id;
        functions.logger.info('Square order created successfully after payment capture', { 
          orderId: squareOrderId,
          orderState: orderResponse.order?.state,
          transactionId: transactionId
        });

        // Create external payment record in Square to link with order
        if (squareOrderId) {
          try {
            await squareClient.payments.create({
              idempotencyKey: uuidv4(),
              sourceId: 'EXTERNAL',
              externalDetails: {
                type: 'OTHER',
                source: 'Stripe Payment (Captured)'
              },
              amountMoney: {
                amount: BigInt(orderData.amount || 0),
                currency: 'USD'
              },
              orderId: squareOrderId,
              locationId: locationId
            });
            functions.logger.info('External payment record created in Square after capture');
          } catch (paymentError: any) {
            functions.logger.error('Failed to create external payment record (order still created):', paymentError);
          }
        }
      } catch (orderError: any) {
        functions.logger.error('Failed to create Square order after payment capture:', orderError);
        // Don't fail the entire operation - payment was captured successfully
      }
    }
    
    // Update order status in Firestore to SUBMITTED
    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .update({
          status: "SUBMITTED",
          paymentStatus: paymentIntent.status.toUpperCase(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          stripePaymentCompleted: true,
          stripePaymentCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          orderId: squareOrderId || null // Add Square order ID if created
        });
        
      functions.logger.info("Order status updated to SUBMITTED", {
        transactionId: transactionId
      });
    } catch (firestoreError) {
      functions.logger.error("Failed to update order status:", firestoreError);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update order status"
      );
    }
    
    return {
      success: true,
      transactionId: transactionId,
      orderId: squareOrderId,
      paymentStatus: paymentIntent.status,
      message: "Payment completed successfully"
    };
    
  } catch (error: any) {
    functions.logger.error("Failed to complete Stripe payment:", error);
    
    if (error.type && error.type.startsWith('Stripe')) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment completion failed: " + error.message
      );
    }
    
    throw new functions.https.HttpsError(
      "internal",
      "Failed to complete payment: " + error.message
    );
  }
});

// Function to submit orders to Square without payment processing
export const submitOrderWithExternalPayment = functions.https.onCall(async (data, context) => {
  functions.logger.info("=== EXTERNAL PAYMENT ORDER FUNCTION v2 - UPDATED VERSION ===");
  functions.logger.info("Raw external payment data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  functions.logger.info("Context:", context);
  
  // Extract order data - check if data is nested in data property
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    // Data is nested (some clients send it this way)
    requestData = data.data;
    functions.logger.info("Using nested data.data structure");
  } else {
    // Data is direct (most clients send it this way)
    requestData = data;
    functions.logger.info("Using direct data structure");
  }
  
  functions.logger.info("Extracted requestData:", {
    hasAmount: !!requestData?.amount,
    hasMerchantId: !!requestData?.merchantId,
    hasOauthToken: !!requestData?.oauth_token,
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token ? requestData.oauth_token.substring(0, 10) + "..." : "MISSING"
  });
  
  const orderData: ExternalPaymentData = {
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token,
    items: requestData?.items || [],
    customerName: requestData?.customerName,
    customerEmail: requestData?.customerEmail,
    pickupTime: requestData?.pickupTime,
    userId: requestData?.userId,
    coffeeShopData: requestData?.coffeeShopData,
    externalPayment: true
  };

  functions.logger.info("External payment order request received:", {
    amount: orderData.amount,
    merchantId: orderData.merchantId,
    hasOauthToken: !!orderData.oauth_token,
    externalPayment: orderData.externalPayment
  });

  // Validate the request data
  if (!orderData.amount || !orderData.merchantId || !orderData.oauth_token) {
    functions.logger.error("Request validation failed", {
      orderData,
      hasAmount: !!orderData.amount,
      hasMerchantId: !!orderData.merchantId,
      hasOauthToken: !!orderData.oauth_token
    });
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'amount', 'merchantId', and 'oauth_token' arguments."
    );
  }

  const {amount, merchantId, oauth_token, items} = orderData;
  const transactionId = uuidv4(); // Generate a unique transaction ID for external payment order

  // Initialize Square client with coffee shop's oauth token
  const accessToken = oauth_token;

  if (!accessToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Square access token not provided"
    );
  }

  const squareClient = new SquareClient({
    token: accessToken,
    environment: squareEnvironmentSetting,
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
      // Use the first location
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
  if (orderData.customerEmail && orderData.customerName) {
    try {
      const customersApi = squareClient.customers;
      const searchResp = await customersApi.search({
        query: {
          filter: {
            emailAddress: {
              exact: orderData.customerEmail
            }
          }
        }
      });
      if (searchResp.customers && searchResp.customers.length > 0) {
        customerId = searchResp.customers[0].id;
        functions.logger.info('Found existing Square customer for external order', { customerId });
      } else {
        // Create new customer
        const createResp = await customersApi.create({
          givenName: orderData.customerName,
          emailAddress: orderData.customerEmail
        });
        customerId = createResp.customer?.id;
        functions.logger.info('Created new Square customer for external order', { customerId });
      }
    } catch (customerError) {
      functions.logger.error('Failed to look up or create Square customer for external order:', customerError);
      // Continue without customerId
    }
  }

  try {
    // Create Square order without payment processing
    functions.logger.info("Creating external payment order in Square...", {
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

      // Create the order with external payment details
      const orderRequest: any = {
        order: {
          locationId: locationId,
          lineItems,
          state: "OPEN", // Set order to OPEN (active) state
          source: {
            name: "SipLocal App - External Payment"
          },
          fulfillments: [
            {
              type: "PICKUP",
              state: "PROPOSED",
              pickupDetails: {
                recipient: {
                  displayName: orderData.customerName || "Customer",
                  emailAddress: orderData.customerEmail || undefined
                },
                pickupAt: orderData.pickupTime || new Date(Date.now() + 5 * 60 * 1000).toISOString(),
                note: "Order placed via mobile app - Payment handled externally"
              }
            }
          ]
          // Note: We'll create an external payment separately to link with this order
        },
        idempotencyKey: uuidv4(),
      };

      if (customerId) {
        orderRequest.order.customerId = customerId;
      }

      try {
        functions.logger.info('Creating Square order with external payment:', {
          hasLineItems: !!orderRequest.order.lineItems?.length,
          locationId: orderRequest.order.locationId,
          customerPresent: !!orderRequest.order.customerId,
          hasTenders: !!orderRequest.order.tenders?.length,
          orderRequestStructure: JSON.stringify(orderRequest, (key, value) => 
            typeof value === 'bigint' ? value.toString() : value, 2)
        });
        
        // First verify locationId is correct for this merchant
        try {
          const locationsResponse = await squareClient.locations.list();
          functions.logger.info('Available locations for merchant:', {
            locations: locationsResponse.locations?.map(loc => ({
              id: loc.id,
              name: loc.name,
              status: loc.status
            }))
          });
        } catch (locError) {
          functions.logger.error('Failed to list locations:', locError);
        }
        
        // Call createOrder (not calculateOrder) - this is the key difference
        const orderResponse = await squareClient.orders.create(orderRequest);
        
        functions.logger.info('Square createOrder API response:', {
          hasOrder: !!orderResponse.order,
          orderId: orderResponse.order?.id,
          orderState: orderResponse.order?.state,
          fullResponse: JSON.stringify(orderResponse, (key, value) => 
            typeof value === 'bigint' ? value.toString() : value, 2)
        });
        
        // Check for errors in the response
        if (orderResponse.errors) {
          functions.logger.error("Square returned errors:", orderResponse.errors);
          throw new Error("Square API errors: " + JSON.stringify(orderResponse.errors, (key, value) => 
            typeof value === 'bigint' ? value.toString() : value));
        }
        
        orderId = orderResponse.order?.id;
        functions.logger.info('Square order created successfully for external payment', { 
          orderId,
          orderExists: !!orderResponse.order,
          orderState: orderResponse.order?.state
        });

        // Create external payment to make order visible in Square dashboard
        if (orderId) {
          functions.logger.info('Creating external payment to link with order...');
          try {
            const paymentResponse = await squareClient.payments.create({
              idempotencyKey: uuidv4(),
              sourceId: 'EXTERNAL',
              externalDetails: {
                type: 'OTHER',
                source: 'SipLocal App'
              },
              amountMoney: {
                amount: BigInt(amount), // in cents
                currency: 'USD'
              },
              orderId: orderId,
              locationId: locationId
            });

            functions.logger.info('External payment recorded successfully:', {
              paymentId: paymentResponse.payment?.id,
              status: paymentResponse.payment?.status,
              orderId: orderId,
              amount: amount
            });
          } catch (paymentError: any) {
            functions.logger.error('Failed to create external payment (order still created):', paymentError);
            // Don't throw here - the order was created successfully, just the payment link failed
            // The order may not show in dashboard but at least it exists
          }
        }
      } catch (orderError: any) {
        functions.logger.error('Failed to create Square order for external payment:', orderError);
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

    functions.logger.info("External payment order created successfully", {
      transactionId: transactionId,
      orderId: orderId
    });

    // Save order to Firestore with external payment flag
    const firestoreOrderData = {
      transactionId: transactionId,
      paymentStatus: "EXTERNAL", // Mark as external payment
      amount: amount.toString(), // Store amount in cents as string
      currency: "USD",
      merchantId: merchantId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: "external",
      receiptNumber: null,
      receiptUrl: null,
      userId: orderData.userId,
      coffeeShopData: orderData.coffeeShopData,
      items: orderData.items || [],
      customerName: orderData.customerName,
      customerEmail: orderData.customerEmail,
      pickupTime: orderData.pickupTime,
      orderId: orderId, // Store Square order ID for status tracking
      status: "SUBMITTED", // Order submitted, awaiting preparation
      externalPayment: true, // Flag for external payment
    };

    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .set(firestoreOrderData);
      
      functions.logger.info("External payment order saved to Firestore", {
        transactionId: transactionId,
      });
    } catch (firestoreError) {
      functions.logger.error("Failed to save external payment order to Firestore:", firestoreError);
      // Continue anyway since the Square order was created
    }

    // Return success response
    return {
      success: true,
      transactionId: transactionId,
      orderId: orderId,
      status: "SUBMITTED",
      amount: amount.toString(),
      currency: "USD",
      receiptNumber: null,
      receiptUrl: null,
    };

  } catch (error: any) {
    functions.logger.error("External payment order failed:", error);

    // Handle specific Square API errors
    if (error.errors) {
      const squareError = error.errors[0];
      functions.logger.error("Square API Error:", {
        category: squareError.category,
        code: squareError.code,
        detail: squareError.detail,
      });
      
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Failed to create order in Square: " + squareError.detail,
        squareError.detail,
      );
    }

    throw new functions.https.HttpsError(
      "internal",
      "Failed to create external payment order.",
      error.message,
    );
  }
});

// Function to complete an authorized order
async function completeAuthorizedOrder(paymentId: string) {
  functions.logger.info("completeAuthorizedOrder called for:", paymentId);
  
  try {
    const orderDoc = await admin.firestore()
      .collection("orders")
      .doc(paymentId)
      .get();

    if (!orderDoc.exists) {
      functions.logger.error("Order not found for completion:", paymentId);
      return;
    }

    const orderData = orderDoc.data();
    functions.logger.info("Order data for completion:", {
      paymentId,
      status: orderData?.status,
      hasOauthToken: !!orderData?.oauthToken,
      hasOrderId: !!orderData?.orderId,
      merchantId: orderData?.merchantId
    });

    if (!orderData || orderData.status !== "AUTHORIZED") {
      functions.logger.info("Order not in AUTHORIZED state, skipping completion:", {
        paymentId,
        status: orderData?.status,
        expectedStatus: "AUTHORIZED"
      });
      return;
    }

    // Initialize Square client
    const squareClient = new SquareClient({
      token: orderData.oauthToken,
      environment: squareEnvironmentSetting,
    });

    // Complete the payment
    functions.logger.info("Attempting to complete Square payment:", paymentId);
    try {
      await squareClient.payments.complete({
        paymentId: paymentId
      });
      functions.logger.info("Successfully completed Square payment:", paymentId);
    } catch (paymentError) {
      functions.logger.error("Failed to complete Square payment:", {
        paymentId,
        error: paymentError,
        errorMessage: (paymentError as Error).message
      });
      throw new Error(`Payment completion failed: ${(paymentError as Error).message}`);
    }

    // Skip Square order update - just complete the payment and update status
    functions.logger.info("Skipping Square order update - using simplified completion flow");

    // Update order status
    functions.logger.info("Updating order status to SUBMITTED:", paymentId);
    try {
      await admin.firestore()
        .collection("orders")
        .doc(paymentId)
        .update({
          status: "SUBMITTED",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          completedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      functions.logger.info("Successfully updated Firestore order status:", paymentId);
    } catch (firestoreError) {
      functions.logger.error("Failed to update Firestore order status:", {
        paymentId,
        error: firestoreError,
        errorMessage: (firestoreError as Error).message
      });
      throw new Error(`Firestore update failed: ${(firestoreError as Error).message}`);
    }

    functions.logger.info("Successfully completed authorized order and updated Firestore:", paymentId);
  } catch (error) {
    functions.logger.error("Failed to complete authorized order:", error);
    
    // Mark order as failed
    try {
      await admin.firestore()
        .collection("orders")
        .doc(paymentId)
        .update({
          status: "FAILED",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: (error as Error).message || "Unknown error during completion"
        });
    } catch (updateError) {
      functions.logger.error("Failed to update order status to FAILED:", updateError);
    }
  }
}

// Function to cancel an order
export const cancelOrder = functions.https.onCall(async (data, context) => {
  functions.logger.info("cancelOrder called with data:", data);
  
  const { paymentId } = data.data;
  
  if (!paymentId) {
    functions.logger.error("Missing paymentId in request");
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Payment ID is required"
    );
  }

  functions.logger.info("Starting cancellation for paymentId:", paymentId);

  try {
    // Get order from Firestore
    const orderDoc = await admin.firestore()
      .collection("orders")
      .doc(paymentId)
      .get();

    if (!orderDoc.exists) {
      functions.logger.error("Order not found in Firestore:", paymentId);
      throw new functions.https.HttpsError(
        "not-found",
        "Order not found"
      );
    }

    const orderData = orderDoc.data();
    functions.logger.info("Order data retrieved:", {
      paymentId,
      status: orderData?.status,
      hasOauthToken: !!orderData?.oauthToken,
      hasOrderId: !!orderData?.orderId,
      merchantId: orderData?.merchantId
    });

    if (!orderData || orderData.status !== "AUTHORIZED") {
      functions.logger.error("Order cannot be cancelled:", {
        paymentId,
        status: orderData?.status,
        expectedStatus: "AUTHORIZED"
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Order cannot be cancelled. Current status: ${orderData?.status || 'unknown'}`
      );
    }

    // For Stripe payments, we need to cancel the PaymentIntent instead of Square payment
    if (orderData.stripePaymentIntentId) {
      functions.logger.info("Cancelling Stripe PaymentIntent:", orderData.stripePaymentIntentId);
      
      try {
        // Initialize Stripe client
        const stripeSecretKey = appConfig.stripe.secretKey;
        if (!stripeSecretKey) {
          functions.logger.error("Stripe secret key not configured");
        } else {
          const stripe = new Stripe(stripeSecretKey);
          await stripe.paymentIntents.cancel(orderData.stripePaymentIntentId);
          functions.logger.info("Successfully cancelled Stripe PaymentIntent:", orderData.stripePaymentIntentId);
        }
      } catch (stripeError) {
        functions.logger.error("Failed to cancel Stripe PaymentIntent:", {
          paymentIntentId: orderData.stripePaymentIntentId,
          error: stripeError
        });
        // Continue with order cancellation even if payment cancellation fails
      }
    } else if (orderData.oauthToken) {
      // Legacy Square payment cancellation
      functions.logger.info("Cancelling Square payment (legacy):", paymentId);
      
      try {
        const squareClient = new SquareClient({
          token: orderData.oauthToken,
          environment: squareEnvironmentSetting,
        });
        
        await squareClient.payments.cancel({
          paymentId: paymentId
        });
        functions.logger.info("Successfully cancelled Square payment:", paymentId);
      } catch (paymentError) {
        functions.logger.error("Failed to cancel Square payment:", {
          paymentId,
          error: paymentError
        });
        // Continue with order cancellation even if payment cancellation fails
      }
    }

    // Cancel the order if it exists
    if (orderData.orderId) {
      functions.logger.info("Cancelling Square order:", orderData.orderId);
      
      try {
        // Get the merchant's location ID
        const merchantDoc = await admin.firestore()
          .collection("merchant_tokens")
          .doc(orderData.merchantId)
          .get();
        
        if (!merchantDoc.exists) {
          functions.logger.error("Merchant tokens not found:", orderData.merchantId);
        } else {
          const merchantData = merchantDoc.data();
          const locationId = merchantData?.locationId;
          
          const oauthToken = merchantData?.oauth_token;
          
          if (locationId && oauthToken) {
            const squareClient = new SquareClient({
              token: oauthToken,
              environment: squareEnvironmentSetting,
            });
            
            await squareClient.orders.update({
              orderId: orderData.orderId,
              order: {
                locationId: locationId,
                version: 1,
                state: "CANCELED"
              },
              idempotencyKey: uuidv4()
            });
            functions.logger.info("Successfully cancelled Square order:", orderData.orderId);
          } else {
            functions.logger.error("Missing locationId or oauth_token for merchant:", orderData.merchantId);
          }
        }
      } catch (orderError) {
        functions.logger.error("Failed to cancel Square order:", {
          orderId: orderData.orderId,
          error: orderError
        });
        // Continue with Firestore update even if Square order cancellation fails
      }
    } else {
      functions.logger.info("No Square order to cancel (order was in AUTHORIZED state)");
    }

    // Update order status in Firestore
    functions.logger.info("Updating order status to CANCELLED:", paymentId);
    await admin.firestore()
      .collection("orders")
      .doc(paymentId)
      .update({
        status: "CANCELLED",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledAt: admin.firestore.FieldValue.serverTimestamp()
      });

    functions.logger.info("Successfully cancelled order:", paymentId);
    
    return {
      success: true,
      message: "Order cancelled successfully"
    };
  } catch (error) {
    const errorObj = error as Error;
    functions.logger.error("Failed to cancel order - detailed error:", {
      paymentId,
      error: error,
      errorMessage: errorObj.message,
      errorStack: errorObj.stack
    });
    
    // Re-throw HttpsError as-is, wrap others
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      "internal",
      `Failed to cancel order: ${errorObj.message || 'Unknown error'}`
    );
  }
});

// HTTP function to manually complete authorized orders (for testing and backup)
export const completeAuthorizedOrderHttp = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const { paymentId } = req.body;
  
  if (!paymentId) {
    res.status(400).json({ error: 'paymentId is required' });
    return;
  }

  try {
    functions.logger.info("Manual completion requested for:", paymentId);
    await completeAuthorizedOrder(paymentId);
    res.status(200).json({ success: true, message: 'Order completed successfully' });
  } catch (error) {
    functions.logger.error("Manual completion failed:", error);
    res.status(500).json({ error: 'Failed to complete order' });
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
      secretConfigured: !!appConfig.square.webhookSignatureKey
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
    functions.logger.info("DEBUG: Webhook data overview:", {
      type: webhookData.type,
      hasData: !!webhookData.data,
      dataKeys: webhookData.data ? Object.keys(webhookData.data) : [],
      fullWebhook: JSON.stringify(webhookData, null, 2)
    });

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
    // IMPORTANT: Protect "AUTHORIZED" status from being overridden during the 30-second cancellation window
    if ((newStatus === "SUBMITTED" && currentStatus !== "SUBMITTED") || 
        (currentStatus === "COMPLETED" && newStatus !== "COMPLETED") ||
        (currentStatus === "CANCELLED" && newStatus !== "CANCELLED") ||
        (currentStatus === "AUTHORIZED" && newStatus !== "AUTHORIZED")) {
      functions.logger.info("Skipping order state update - current status is more specific or final:", {
        currentStatus,
        newStatus,
        reason: currentStatus === "AUTHORIZED" ? "Protecting AUTHORIZED status during cancellation window" : "Status protection"
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
    functions.logger.info("DEBUG: Full webhook data structure for order.created:", {
      webhookData: JSON.stringify(webhookData, null, 2),
      dataKeys: Object.keys(webhookData.data || {}),
      hasId: !!webhookData.data?.id,
      hasObject: !!webhookData.data?.object,
      idKeys: webhookData.data?.id ? Object.keys(webhookData.data.id) : null,
      objectKeys: webhookData.data?.object ? Object.keys(webhookData.data.object) : null
    });

    const order = webhookData.data?.id?.order;
    if (!order) {
      functions.logger.error("No order data in webhook - trying alternative paths");
      // Try alternative data paths
      const altOrder = webhookData.data?.object?.order || webhookData.data?.object?.order_created;
      if (altOrder) {
        functions.logger.info("Found order data at alternative path:", altOrder);
        return;
      }
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

// Function to send OneSignal notification
async function sendOrderReadyNotification(userId: string, orderData: any) {
  try {
    // Get OneSignal App ID from environment variables
    const oneSignalAppId = appConfig.onesignal.appId;
    const oneSignalApiKey = appConfig.onesignal.apiKey;
    
    functions.logger.info("OneSignal configuration check:", {
      hasAppId: !!oneSignalAppId,
      hasApiKey: !!oneSignalApiKey,
      appIdLength: oneSignalAppId?.length || 0,
      apiKeyLength: oneSignalApiKey?.length || 0
    });
    
    if (!oneSignalAppId || !oneSignalApiKey) {
      functions.logger.error("OneSignal configuration missing");
      return;
    }

    // Initialize OneSignal client
    const oneSignalClient = new OneSignal.Client(oneSignalAppId, oneSignalApiKey);

    // Get user data to find device IDs
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      functions.logger.warn("User not found for notification:", userId);
      return;
    }

    const userData = userDoc.data();
    
    // Extract device IDs from the devices object
    // The devices are stored as an object where keys are device IDs
    const devices = userData?.devices || {};
    const deviceIds = Object.keys(devices);

    if (deviceIds.length === 0) {
      functions.logger.warn("No device IDs found for user:", userId);
      return;
    }

    // Prepare notification content
    const coffeeShopName = orderData.coffeeShopData?.name || "Coffee Shop";

    // Use include_player_ids instead of include_external_user_ids
    // The device IDs from your database should be OneSignal player IDs
    const notification = {
      include_player_ids: deviceIds,
      headings: { en: "Order Ready for Pickup! ☕" },
      contents: { en: `Your order from ${coffeeShopName} is ready for pickup!` },
      data: {
        orderId: orderData.transactionId,
        status: "READY",
        coffeeShopName: coffeeShopName
      }
    };

    // Send notification
    functions.logger.info("Sending OneSignal notification:", {
      userId,
      deviceIds,
      notification: notification
    });
    
    try {
      const response = await oneSignalClient.createNotification(notification);
      
      functions.logger.info("OneSignal API response:", {
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers
      });
      
      functions.logger.info("Notification sent successfully:", {
        userId,
        deviceCount: deviceIds.length,
        notificationId: response.body?.id || "No ID returned"
      });
    } catch (error) {
      functions.logger.error("OneSignal API error:", {
        error: error,
        errorMessage: (error as Error).message,
        errorStack: (error as Error).stack
      });
      throw error;
    }

  } catch (error) {
    functions.logger.error("Failed to send notification:", error);
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
        // IMPORTANT: Also protect "AUTHORIZED" status from being overridden during the 30-second cancellation window
        if ((currentStatus === "COMPLETED" && newStatus !== "COMPLETED") ||
            (currentStatus === "CANCELLED" && newStatus !== "CANCELLED") ||
            (currentStatus === "AUTHORIZED" && newStatus !== "AUTHORIZED")) {
          functions.logger.info("Skipping fulfillment update - order already in final state:", {
            documentId: doc.id,
            orderId,
            currentStatus,
            newStatus,
            reason: currentStatus === "AUTHORIZED" ? "Protecting AUTHORIZED status during cancellation window" : "Final status protection"
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

        // Send notification if status changed to READY
        if (newStatus === "READY" && currentStatus !== "READY" && currentOrderData.userId) {
          functions.logger.info("Order is ready for pickup, sending notification");
          // Send notification asynchronously (don't wait for it)
          sendOrderReadyNotification(currentOrderData.userId, currentOrderData).catch(error => {
            functions.logger.error("Failed to send ready notification:", error);
          });
        }
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

// Function to submit orders to Clover without payment processing
export const submitCloverOrderWithExternalPayment = functions.https.onCall(async (data, context) => {
  functions.logger.info("=== CLOVER ORDER SUBMISSION FUNCTION ===");
  functions.logger.info("Raw external payment data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  functions.logger.info("Context:", context);
  
  // Extract order data - check if data is nested in data property
  let requestData: any;
  if (data && typeof data === 'object' && 'data' in data) {
    // Data is nested (some clients send it this way)
    requestData = data.data;
    functions.logger.info("Using nested data.data structure");
  } else {
    // Data is direct (most clients send it this way)
    requestData = data;
    functions.logger.info("Using direct data structure");
  }
  
  functions.logger.info("Extracted requestData:", {
    hasAmount: !!requestData?.amount,
    hasMerchantId: !!requestData?.merchantId,
    hasOauthToken: !!requestData?.oauth_token,
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token ? requestData.oauth_token.substring(0, 10) + "..." : "MISSING"
  });
  
  const orderData: ExternalPaymentData = {
    amount: requestData?.amount,
    merchantId: requestData?.merchantId,
    oauth_token: requestData?.oauth_token,
    items: requestData?.items || [],
    customerName: requestData?.customerName,
    customerEmail: requestData?.customerEmail,
    pickupTime: requestData?.pickupTime,
    userId: requestData?.userId,
    coffeeShopData: requestData?.coffeeShopData,
    externalPayment: true,
    posType: "clover"
  };

  functions.logger.info("Clover external payment order request received:", {
    amount: orderData.amount,
    merchantId: orderData.merchantId,
    hasOauthToken: !!orderData.oauth_token,
    externalPayment: orderData.externalPayment,
    posType: orderData.posType
  });

  // Validate the request data
  if (!orderData.amount || !orderData.merchantId || !orderData.oauth_token) {
    functions.logger.error("Request validation failed", {
      orderData,
      hasAmount: !!orderData.amount,
      hasMerchantId: !!orderData.merchantId,
      hasOauthToken: !!orderData.oauth_token
    });
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'amount', 'merchantId', and 'oauth_token' arguments."
    );
  }

  const {amount, merchantId, oauth_token, items} = orderData;
  const transactionId = uuidv4(); // Generate a unique transaction ID for external payment order

  // Use the oauth_token as the Clover access token
  const accessToken = oauth_token;
  
  if (!accessToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Clover access token not provided"
    );
  }

  functions.logger.info("Creating Clover order with external payment:", {
    merchantId,
    hasAccessToken: !!accessToken,
    amount,
    itemCount: items?.length || 0
  });

  let orderId: string | undefined = undefined;
  
  try {
    if (items && items.length > 0) {
      // Build line items for Clover order
      const cloverItems = items.map(item => ({
        item: { id: item.id || "default-item-id" },
        name: item.name,
        price: item.price, // Price already in cents
        unitQty: item.quantity,
        note: item.customizations || undefined,
        printed: false,
        exchanged: false,
        refunded: false,
        isRevenue: true
      }));

      // Create the Clover order
      const cloverOrderRequest: CloverOrderRequest = {
        items: cloverItems,
        state: "open", // Order is open and ready for processing
        note: `Order placed via mobile app - Customer: ${orderData.customerName || "Customer"}`,
        manualTransaction: true, // External payment
        groupLineItems: true,
        testMode: false
      };

      functions.logger.info("Clover order request:", {
        hasItems: !!cloverOrderRequest.items?.length,
        itemCount: cloverOrderRequest.items?.length,
        state: cloverOrderRequest.state,
        manualTransaction: cloverOrderRequest.manualTransaction
      });

      // Make API call to Clover
      const cloverApiUrl = `https://api.clover.com/v3/merchants/${merchantId}/orders`;
      
      try {
        const response = await axios.post<CloverOrderResponse>(cloverApiUrl, cloverOrderRequest, {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
          }
        });

        functions.logger.info('Clover createOrder API response:', {
          status: response.status,
          hasData: !!response.data,
          orderId: response.data?.id,
          orderState: response.data?.state
        });

        if (response.status === 200 || response.status === 201) {
          orderId = response.data?.id;
          functions.logger.info('Clover order created successfully for external payment:', orderId);
        } else {
          functions.logger.error("Clover API returned unexpected status:", response.status);
          throw new Error(`Clover API returned status ${response.status}`);
        }

      } catch (cloverError: any) {
        functions.logger.error("Failed to create Clover order:", {
          error: cloverError.message,
          response: cloverError.response?.data,
          status: cloverError.response?.status
        });
        throw new Error(`Failed to create Clover order: ${cloverError.message}`);
      }
    }

    // Save order to Firestore
    const orderDoc = {
      transactionId,
      orderId,
      merchantId,
      amount,
      items: items || [],
      customerName: orderData.customerName,
      customerEmail: orderData.customerEmail,
      userId: orderData.userId,
      coffeeShopData: orderData.coffeeShopData,
      status: "SUBMITTED",
      externalPayment: true,
      posType: "clover",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      pickupTime: orderData.pickupTime
    };

    await admin.firestore().collection("orders").doc(transactionId).set(orderDoc);
    functions.logger.info("Order saved to Firestore with transactionId:", transactionId);

    return {
      success: true,
      transactionId,
      orderId,
      message: "Clover order submitted successfully with external payment",
      status: "SUBMITTED"
    };

  } catch (error: any) {
    functions.logger.error("Error in submitCloverOrderWithExternalPayment:", {
      error: error.message,
      stack: error.stack,
      transactionId
    });

    throw new functions.https.HttpsError(
      "internal",
      error.message
    );
  }
});

// Apple Pay payment processing for Clover merchants
async function processApplePayPaymentClover(paymentData: any, context: any) {
  functions.logger.info("=== APPLE PAY PAYMENT PROCESSING FOR CLOVER ===");
  
  const { amount, merchantId, oauth_token, items, customerName, customerEmail, pickupTime, userId, coffeeShopData, tokenId } = paymentData;

  // Validate the request data
  if (!amount || !merchantId || !oauth_token || !tokenId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required payment data: amount, merchantId, oauth_token, or tokenId"
    );
  }

  const transactionId = `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  functions.logger.info("Generated transaction ID:", transactionId);

  // Initialize Stripe
  const stripeSecretKey = appConfig.stripe.secretKey;
  if (!stripeSecretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Stripe secret key not configured"
    );
  }

  const stripe = new Stripe(stripeSecretKey);

  try {
    // 1. Process Apple Pay payment with Stripe
    functions.logger.info("Processing Apple Pay payment with Stripe for Clover merchant...", {
      amount: amount,
      merchantId: merchantId
    });

    // Create charge using the token with capture=false for authorization only
    const charge = await stripe.charges.create({
      amount: amount, // amount in cents
      currency: 'usd',
      source: tokenId, // Use the token ID from client
      capture: false, // IMPORTANT: Authorize only, don't capture yet
      description: `Apple Pay order from ${coffeeShopData?.name || 'Coffee Shop'} (Clover)`,
      receipt_email: customerEmail,
      metadata: {
        merchantId: merchantId,
        transactionId: transactionId,
        userId: userId || '',
        coffeeShop: coffeeShopData?.name || '',
        customerEmail: customerEmail || '',
        customerName: customerName || '',
        paymentMethod: 'apple_pay',
        posType: 'clover'
      },
    });
    
    functions.logger.info("Stripe Charge created (AUTHORIZED ONLY) for Clover:", {
      chargeId: charge.id,
      status: charge.status,
      captured: charge.captured,
      amount: charge.amount
    });

    // Check if payment was successfully authorized
    if (charge.status !== 'succeeded') {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Apple Pay payment authorization failed with status: ${charge.status}`
      );
    }

    // 2. Store order in Firestore with AUTHORIZED status
    const firestoreOrderData = {
      transactionId: transactionId,
      stripeChargeId: charge.id,
      paymentStatus: "AUTHORIZED", // Payment is authorized but not captured
      amount: amount.toString(),
      currency: "USD",
      merchantId: merchantId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: "apple_pay",
      receiptNumber: null,
      receiptUrl: charge.receipt_url,
      userId: userId,
      coffeeShopData: coffeeShopData,
      items: items || [],
      customerName: customerName,
      customerEmail: customerEmail,
      pickupTime: pickupTime,
      orderId: null, // Will be set when order is submitted to Clover
      status: "AUTHORIZED", // Order is authorized but not yet submitted
      oauthToken: oauth_token,
      posType: "clover"
    };

    await admin.firestore()
      .collection("orders")
      .doc(transactionId)
      .set(firestoreOrderData);

    functions.logger.info("Order stored in Firestore with AUTHORIZED status");

    // 3. Submit order to Clover
    functions.logger.info("Submitting order to Clover...");
    
    try {
      // Submit to Clover using proper API approach
      functions.logger.info("Creating Clover order with line items...");
      
      // Step 1: Create the base order
      const baseOrderPayload = {
        currency: "USD",
        note: `Apple Pay order - ${customerName || 'Customer'}`,
        testMode: true // Explicitly set test mode for sandbox
      };

      functions.logger.info("Creating base Clover order:", baseOrderPayload);

      const cloverResponse = await axios.post<CloverOrderResponse>(
        `https://sandbox.dev.clover.com/v3/merchants/${merchantId}/orders`,
        baseOrderPayload,
        {
          headers: {
            'Authorization': `Bearer ${oauth_token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      functions.logger.info("Base order created:", cloverResponse.data);
      const orderId = cloverResponse.data.id;

      // Step 2: Add line items to the order
      for (const item of items || []) {
        const lineItemPayload = {
          name: item.name,
          price: item.price, // Price in cents
          unitQty: item.quantity || 1,
          note: item.customizations || ""
        };

        functions.logger.info(`Adding line item to order ${orderId}:`, lineItemPayload);

        try {
          const lineItemResponse = await axios.post(
            `https://sandbox.dev.clover.com/v3/merchants/${merchantId}/orders/${orderId}/line_items`,
            lineItemPayload,
            {
              headers: {
                'Authorization': `Bearer ${oauth_token}`,
                'Content-Type': 'application/json'
              }
            }
          );
          functions.logger.info("Line item added:", lineItemResponse.data);
        } catch (lineItemError) {
          functions.logger.error("Failed to add line item:", lineItemError);
          // Continue with other items even if one fails
        }
      }

      functions.logger.info("Full Clover API response:", {
        status: cloverResponse.status,
        statusText: cloverResponse.statusText,
        data: cloverResponse.data,
        headers: cloverResponse.headers
      });

      const cloverResult = {
        orderId: orderId,
        status: "SUBMITTED", 
        message: "Clover order created successfully with line items"
      };
      
      functions.logger.info("Clover order submission result:", cloverResult);

      // 4. Capture the Stripe payment since Clover order was successful
      functions.logger.info("Capturing Stripe payment...");
      const capturedCharge = await stripe.charges.capture(charge.id);
      
      functions.logger.info("Stripe payment captured:", {
        chargeId: capturedCharge.id,
        captured: capturedCharge.captured,
        amount_captured: capturedCharge.amount_captured
      });

      // 5. Update order status to SUBMITTED
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .update({
          paymentStatus: "CAPTURED",
          status: "SUBMITTED",
          orderId: cloverResult.orderId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      functions.logger.info("Apple Pay + Clover order completed successfully");

      return {
        transactionId: transactionId,
        orderId: cloverResult.orderId,
        stripeChargeId: charge.id,
        status: "SUBMITTED",
        message: "Apple Pay payment and Clover order completed successfully"
      };

    } catch (cloverError) {
      functions.logger.error("Failed to submit order to Clover:", cloverError);
      
      // Update order status to failed
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .update({
          status: "CLOVER_SUBMISSION_FAILED",
          error: (cloverError as Error).message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      throw new functions.https.HttpsError(
        "internal",
        `Failed to submit order to Clover: ${(cloverError as Error).message}`
      );
    }

  } catch (error) {
    functions.logger.error("Error processing Apple Pay payment for Clover:", error);
    
    // Update order status to failed if it exists
    try {
      await admin.firestore()
        .collection("orders")
        .doc(transactionId)
        .update({
          paymentStatus: "FAILED",
          error: (error as Error).message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (updateError) {
      functions.logger.error("Failed to update order status:", updateError);
    }
    
    throw error;
  }
}
