const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'coffee-55670'
});

const tokenData = [
  {
    merchantId: "MLST6XP96ZD5Q",
    oauth_token: "EAAAl5TL7NLTWTbHDXEGnJhw2ghjE_McWbS9nvWSLPpD9TsBUQ9VhffJC9YF2cBC",
    refreshToken: "EQAAl0Jk8F3xrGBWCz0OnBCNC5cENngOHDCUwGuyAx3lnTMKokq-rogPxjStUGlt",
    shopId: "1",
    shopName: "Multiple Shops (Shared Token)"
  },
  {
    merchantId: "BX68JJS39WN4Y", 
    oauth_token: "EAAAlxL6R_kaQKyrSPSggx5Z8KmoOlYiaBe8cCEg8vth5vXqV8_dC33f-z1c9gPN",
    refreshToken: "EQAAl7u3vqMAppFPoO2c95KqccivqN0sSVO3H7DLR6RzrAaKWfihJJlp7v1P3XWw",
    shopId: "5",
    shopName: "The Mill"
  }
];

async function migrate() {
  try {
    console.log('Starting token migration to Firestore...');
    
    // Use the firebase-functions-test approach
    process.env.FIREBASE_CONFIG = JSON.stringify({
      projectId: 'coffee-55670'
    });
    
    process.env.GOOGLE_APPLICATION_CREDENTIALS = process.env.HOME + '/.config/gcloud/application_default_credentials.json';
    
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
      console.log(`Prepared: ${token.shopName} (${token.merchantId})`);
    }

    await batch.commit();
    console.log('✅ Migration completed successfully!');
    console.log(`✅ Migrated ${tokenData.length} merchant token records to Firestore`);
    
    // Verify the data was written
    const snapshot = await db.collection('merchant_tokens').get();
    console.log(`✅ Verification: Found ${snapshot.size} documents in merchant_tokens collection`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    console.error('Error details:', error.message);
    process.exit(1);
  }
}

migrate();