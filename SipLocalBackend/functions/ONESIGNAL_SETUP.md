# OneSignal Setup for Order Notifications

This document explains how to set up OneSignal for sending push notifications when orders are ready for pickup.

## Environment Variables Required

You need to set the following environment variables in your Firebase Functions configuration:

### 1. ONESIGNAL_APP_ID
Your OneSignal App ID. You can find this in your OneSignal dashboard under Settings > Keys & IDs.

### 2. ONESIGNAL_API_KEY
Your OneSignal REST API Key. You can find this in your OneSignal dashboard under Settings > Keys & IDs.

## Setting Environment Variables

### For Local Development
Create a `.env` file in the `functions` directory:
```
ONESIGNAL_APP_ID=your-app-id-here
ONESIGNAL_API_KEY=your-api-key-here
```

### For Production
Set the environment variables in Firebase:
```bash
firebase functions:config:set onesignal.app_id="your-app-id-here"
firebase functions:config:set onesignal.api_key="your-api-key-here"
```

## How It Works

1. When a Square webhook updates an order's fulfillment status to "PREPARED", it maps to our "READY" status
2. The webhook handler detects this status change and triggers a notification
3. The notification is sent to all devices registered for the user who placed the order
4. Users receive a push notification even if the app is not running

## Notification Content

The notification includes:
- Title: "Order Ready for Pickup! ☕"
- Message: "Your order from [Coffee Shop Name] is ready for pickup!"
- Additional data: orderId, status, and coffeeShopName for app handling

## User Device Management

The system expects users to have a `deviceIds` field in their Firestore document containing an array of OneSignal device IDs. This is managed by your existing device management system. 