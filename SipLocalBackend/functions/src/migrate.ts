import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Migration function to add token data to Firestore
export const migrateTokens = functions.https.onRequest(async (req, res) => {
  // Only allow this function in development
  if (process.env.NODE_ENV === 'production') {
    res.status(403).send('Migration not allowed in production');
    return;
  }

  const tokenData = [
    {
      merchantId: "MLST6XP96ZD5Q",
      oauth_token: "EAAAl5TL7NLTWTbHDXEGnJhw2ghjE_McWbS9nvWSLPpD9TsBUQ9VhffJC9YF2cBC",
      refreshToken: "EQAAl0Jk8F3xrGBWCz0OnBCNC5cENngOHDCUwGuyAx3lnTMKokq-rogPxjStUGlt",
      shopId: "1",
      shopName: "Qisa Coffee"
    },
    {
      merchantId: "BX68JJS39WN4Y", 
      oauth_token: "EAAAlxL6R_kaQKyrSPSggx5Z8KmoOlYiaBe8cCEg8vth5vXqV8_dC33f-z1c9gPN",
      refreshToken: "EQAAl7u3vqMAppFPoO2c95KqccivqN0sSVO3H7DLR6RzrAaKWfihJJlp7v1P3XWw",
      shopId: "5",
      shopName: "The Mill"
    }
  ];

  try {
    const db = admin.firestore();
    const batch = db.batch();

    for (const token of tokenData) {
      const docRef = db.collection('merchant_tokens').doc(token.merchantId);
      const data = {
        ...token,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      batch.set(docRef, data);
    }

    await batch.commit();
    
    functions.logger.info('Token migration completed successfully');
    res.status(200).json({ 
      success: true, 
      message: 'Tokens migrated successfully',
      migrated: tokenData.length 
    });
  } catch (error) {
    functions.logger.error('Migration failed:', error);
    res.status(500).json({ 
      success: false, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    });
  }
});