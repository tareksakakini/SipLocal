// Migration script to create Firestore data using Firebase CLI
const fs = require('fs');
const path = require('path');

// Read the CoffeeShops.json file with tokens for migration
const coffeeShopsPath = path.join(__dirname, '../SipLocal/SipLocal/CoffeeShops-with-tokens.json');
const coffeeShops = JSON.parse(fs.readFileSync(coffeeShopsPath, 'utf8'));

console.log('Generating Firestore import data...');

const firestoreData = {};

for (const shop of coffeeShops) {
  if (shop.menu && shop.menu.oauth_token) {
    const tokenData = {
      oauth_token: shop.menu.oauth_token,
      merchantId: shop.menu.merchantId,
      refreshToken: shop.menu.refreshToken,
      shopId: shop.id,
      shopName: shop.name,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Use the collection structure for Firestore import
    if (!firestoreData.merchant_tokens) {
      firestoreData.merchant_tokens = {};
    }
    
    firestoreData.merchant_tokens[shop.menu.merchantId] = tokenData;
    
    console.log(`Added tokens for ${shop.name} (merchantId: ${shop.menu.merchantId})`);
  }
}

// Write the data to a JSON file for Firebase import
const outputPath = path.join(__dirname, 'firestore-import.json');
fs.writeFileSync(outputPath, JSON.stringify(firestoreData, null, 2));

console.log(`Migration data written to: ${outputPath}`);
console.log('\nTo import this data to Firestore, run:');
console.log(`cd ${path.dirname(outputPath)}`);
console.log('firebase firestore:delete --all-collections --force');
console.log('firebase firestore:import firestore-import.json');