# Square Webhook Setup Guide

This guide will help you set up Square webhooks to enable real-time order status synchronization between the Square Dashboard and your SipLocal app.

## 🎯 Overview

The webhook system creates a complete real-time pipeline:
1. **Merchant updates order** in Square Dashboard
2. **Square sends webhook** to our Firebase function
3. **Firebase updates** the order status in Firestore
4. **iOS app receives** real-time update via Firestore listener

## 📋 Prerequisites

1. **Square Developer Account** with API access
2. **Firebase project** deployed with functions
3. **Square access token** for your merchant account

## 🚀 Setup Steps

### 1. Deploy Firebase Functions

First, deploy the webhook function to Firebase:

```bash
cd SipLocalBackend/functions
npm run deploy
```

After deployment, note your function URL:
```
https://your-project-id.cloudfunctions.net/squareWebhook
```

### 2. Configure Environment Variables

Add these environment variables to your Firebase functions:

```bash
firebase functions:config:set square.webhook_signature_key="YOUR_WEBHOOK_SIGNATURE_KEY"
firebase functions:config:set square.environment="sandbox"  # or "production"
```

### 3. Set Up Square Webhook (Manual Method)

Since the automated setup script has API compatibility issues, we'll set up the webhook manually:

#### A. Go to Square Developer Dashboard
1. Visit [Square Developer Dashboard](https://developer.squareup.com/apps)
2. Select your application
3. Go to **Webhooks** section

#### B. Create Webhook Subscription
1. Click **Add Webhook**
2. Set **Event Types** to:
   - `order.updated`
   - `order.created`
   - `order.fulfillment.updated`
3. Set **Notification URL** to your Firebase function URL:
   ```
   https://your-project-id.cloudfunctions.net/squareWebhook
   ```
4. Set **API Version** to `2024-02-15`
5. Click **Save**

#### C. Get Webhook Signature Key
1. After creating the webhook, copy the **Signature Key**
2. Add it to your Firebase functions config:
   ```bash
   firebase functions:config:set square.webhook_signature_key="YOUR_SIGNATURE_KEY"
   ```

### 4. Test the Webhook

1. **Deploy the updated functions:**
   ```bash
   npm run deploy
   ```

2. **Test with a real order:**
   - Place an order through your app
   - Update the order status in Square Dashboard
   - Check Firebase logs to see webhook processing
   - Verify the order status updates in your iOS app

## 🔧 Configuration Details

### Webhook Events Handled

| Square Event | Description | Status Mapping |
|--------------|-------------|----------------|
| `order.updated` | Order state changed | OPEN → SUBMITTED, COMPLETED → COMPLETED, etc. |
| `order.fulfillment.updated` | Fulfillment state changed | PROPOSED → SUBMITTED, PREPARED → READY, etc. |
| `order.created` | New order created | Logged but no action needed |

### Status Mapping

**Order States:**
- `OPEN` → `SUBMITTED`
- `COMPLETED` → `COMPLETED`
- `CANCELED` → `CANCELLED`
- `DRAFT` → `DRAFT`

**Fulfillment States:**
- `PROPOSED` → `SUBMITTED`
- `RESERVED` → `IN_PROGRESS`
- `PREPARED` → `READY`
- `FULFILLED` → `COMPLETED`
- `CANCELED` → `CANCELLED`

## 🐛 Troubleshooting

### Common Issues

1. **Webhook not receiving events:**
   - Check Square Developer Dashboard webhook status
   - Verify notification URL is correct
   - Check Firebase function logs

2. **Signature verification failing:**
   - Ensure `SQUARE_WEBHOOK_SIGNATURE_KEY` is set correctly
   - Verify the signature key matches Square Dashboard

3. **Orders not updating in app:**
   - Check Firestore logs for webhook processing
   - Verify real-time listener is active in iOS app
   - Check order ID matching between Square and Firestore

### Debug Commands

```bash
# View Firebase function logs
firebase functions:log

# Check webhook configuration
firebase functions:config:get
```

## 🔒 Security

- Webhook signature verification ensures requests come from Square
- CORS headers allow Square to send webhooks
- Environment variables keep sensitive data secure

## 📱 iOS App Integration

The iOS app automatically receives updates via the existing Firestore real-time listener. No additional changes needed!

## 🎉 Success Indicators

You'll know the webhook is working when:
1. ✅ Orders update in real-time when changed in Square Dashboard
2. ✅ Firebase logs show webhook processing
3. ✅ iOS app displays updated statuses immediately
4. ✅ No manual refresh needed in the app

---

**Need help?** Check the Firebase function logs for detailed error messages and webhook processing information. 