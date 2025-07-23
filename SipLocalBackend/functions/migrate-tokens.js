const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin with default credentials
admin.initializeApp({
  projectId: 'coffee-55670'
});

// Read the CoffeeShops.json file with tokens for migration
const coffeeShopsPath = path.join(__dirname, '../../SipLocal/SipLocal/CoffeeShops-with-tokens.json');
const coffeeShops = JSON.parse(fs.readFileSync(coffeeShopsPath, 'utf8'));

async function migrateTokens() {
  const db = admin.firestore();
  const batch = db.batch();

  console.log('Starting token migration...');
  
  for (const shop of coffeeShops) {
    if (shop.menu && shop.menu.oauth_token) {
      const tokenData = {
        oauth_token: shop.menu.oauth_token,
        merchantId: shop.menu.merchantId,
        refreshToken: shop.menu.refreshToken,
        shopId: shop.id,
        shopName: shop.name,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const docRef = db.collection('merchant_tokens').doc(shop.menu.merchantId);
      batch.set(docRef, tokenData);
      
      console.log(`Added tokens for ${shop.name} (merchantId: ${shop.menu.merchantId})`);
    }
  }

  try {
    await batch.commit();
    console.log('Token migration completed successfully!');
  } catch (error) {
    console.error('Error during migration:', error);
    throw error;
  }
}

// Run migration
migrateTokens()
  .then(() => {
    console.log('Migration finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  });