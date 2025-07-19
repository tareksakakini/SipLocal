import * as functions from "firebase-functions";
import {v4 as uuidv4} from "uuid";

// Define the expected data structure
interface PaymentData {
  nonce: string;
  amount: number;
  locationId: string;
}

export const processPayment = functions.https.onCall(async (data, context) => {
  // Log the raw data first
  functions.logger.info("Raw data received:", data);
  functions.logger.info("Data type:", typeof data);
  functions.logger.info("Data keys:", Object.keys(data || {}));
  
  // The actual payment data is nested under data.data
  const paymentData = (data as any).data as PaymentData;
  
  // 1. Log the request for debugging
  functions.logger.info("Payment request received:", {
    amount: paymentData.amount,
    locationId: paymentData.locationId,
    nonce: "PRESENT",
  });

  // 2. Validate the request data
  if (!paymentData.nonce || !paymentData.amount || !paymentData.locationId) {
    functions.logger.error("Request validation failed", paymentData);
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'nonce', 'amount', and 'locationId' arguments.",
    );
  }

  const {nonce, amount, locationId} = paymentData;
  const idempotencyKey = uuidv4();

  try {
    // 3. For now, simulate a successful payment
    // TODO: Replace with actual Square API call
    functions.logger.info("Simulating payment processing...", {
      nonce: nonce.substring(0, 10) + "...",
      amount: amount,
      locationId: locationId
    });
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const transactionId = `fake_${idempotencyKey}`;
    
    functions.logger.info("Payment successful", {
      transactionId: transactionId,
    });

    // 4. Return the transaction ID on success
    return {
      success: true,
      transactionId: transactionId,
    };
  } catch (error: any) {
    functions.logger.error("Payment failed:", error);

    // 5. Throw an HTTPS error to send a structured error back to the client
    throw new functions.https.HttpsError(
      "internal",
      "Payment failed. Please try again.",
      error.message,
    );
  }
});
