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
}

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
    amount: requestData.amount
  };
  
  // 1. Log the request for debugging
  functions.logger.info("Payment request received:", {
    amount: paymentData.amount,
    merchantId: paymentData.merchantId,
    nonce: "PRESENT",
  });

  // 2. Validate the request data
  functions.logger.info("Validation check:", {
    hasNonce: !!paymentData.nonce,
    hasAmount: !!paymentData.amount,
    hasMerchantId: !!paymentData.merchantId,
    nonceValue: paymentData.nonce,
    amountValue: paymentData.amount,
    merchantIdValue: paymentData.merchantId
  });
  
  if (!paymentData.nonce || !paymentData.amount || !paymentData.merchantId) {
    functions.logger.error("Request validation failed", paymentData);
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'nonce', 'amount', and 'merchantId' arguments.",
    );
  }

  const {nonce, amount, merchantId} = paymentData;
  const idempotencyKey = uuidv4();

  // Initialize Square client with environment variables
  const accessToken = process.env.SQUARE_ACCESS_TOKEN;
  const environment = process.env.SQUARE_ENVIRONMENT || "sandbox";
  
  if (!accessToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Square access token not configured"
    );
  }

  const squareClient = new SquareClient({
    token: accessToken,
    environment: environment === "production" ? 
      SquareEnvironment.Production : SquareEnvironment.Sandbox,
  });

  functions.logger.info("Square client initialized", {
    environment: environment,
    tokenPrefix: accessToken.substring(0, 10) + "..."
  });

  try {
    // 3. Process payment with Square API
    functions.logger.info("Processing payment with Square API...", {
      nonce: nonce.substring(0, 10) + "...",
      amount: amount,
      merchantId: merchantId
    });
    
    const request = {
      sourceId: nonce,
      idempotencyKey: idempotencyKey,
      amountMoney: {
        amount: BigInt(amount), // Amount in cents
        currency: "USD" as Square.Currency,
      },
      // Note: For production, Square uses applicationId instead of locationId
      // applicationId: merchantId, // Commented out - depends on Square API requirements
      autocomplete: true,
    };

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
