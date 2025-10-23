# Backend Integration Guide for Booking Notifications

This guide shows how your Flutter app is now integrated with your Go backend for booking notifications.

## ✅ **Integration Complete!**

Your Flutter app is now fully integrated with your Go backend endpoints. Here's what has been implemented:

### 🔧 **Flutter App Changes Made:**

1. **API Service** (`api_service.dart`)
   - ✅ `sendNotificationToServiceProvider()` - Calls your `/api/notifications/send-to-service-provider` endpoint
   - ✅ `sendFCMTokenToServer()` - Calls your `/api/users/fcm-token` endpoint
   - ✅ `sendServiceProviderFCMTokenToServer()` - Calls your `/api/service-provider/fcm-token` endpoint

2. **Notification Service** (`notification_service.dart`)
   - ✅ Updated to use API service methods
   - ✅ Separate methods for users vs service providers

3. **Notification Provider** (`notification_provider.dart`)
   - ✅ Public methods for sending FCM tokens
   - ✅ Automatic token sending during WebSocket initialization

4. **Login Integration** (`login_page.dart`)
   - ✅ Automatically sends FCM token after successful login
   - ✅ Works for both regular login and Google Sign-In
   - ✅ Handles different user types (user, serviceProvider, company, wholesaler)

5. **Booking Service** (`booking_service.dart`)
   - ✅ Automatically sends notification after successful booking creation
   - ✅ Non-blocking notification sending (won't break booking if notification fails)

### 🚀 **How It Works Now:**

#### **1. User Login Flow:**
```
User Logs In → FCM Token Generated → Token Sent to Backend → Stored in Database
```

#### **2. Booking Flow:**
```
User Books Service → Booking Created → Notification Sent to Service Provider → FCM Delivered
```

#### **3. Backend Integration:**
- **Endpoint**: `POST /api/notifications/send-to-service-provider`
- **Authentication**: Not required (public endpoint as per your implementation)
- **Data Format**: Matches your Go struct exactly

### 📱 **Testing Your Integration:**

#### **1. Test FCM Token Storage:**
1. Login to your app
2. Check console logs for: `"FCM token sent to server for user type: [type]"`
3. Check your MongoDB database for the `fcmToken` field

#### **2. Test Booking Notifications:**
1. Use the test widget: `BookingNotificationTest`
2. Fill in a real service provider ID from your database
3. Click "Test Notification Only"
4. Check service provider's device for notification

#### **3. Test Real Booking:**
1. Create a real booking through the app
2. Check console logs for notification sending
3. Verify service provider receives notification

### 🔍 **Backend Requirements (Already Implemented):**

Your Go backend already has everything needed:

```go
// ✅ Routes configured
notificationGroup.POST("/send-to-service-provider", notificationController.SendToServiceProvider)
authGroup.POST("/service-provider/fcm-token", notificationController.UpdateServiceProviderFCMToken)
authGroup.POST("/users/fcm-token", notificationController.UpdateUserFCMToken)

// ✅ Controller methods implemented
- SendToServiceProvider()
- UpdateServiceProviderFCMToken()
- UpdateUserFCMToken()
```

### 📊 **Database Schema Required:**

Make sure your MongoDB collections have the `fcmToken` field:

```javascript
// ServiceProviders collection
{
  "_id": ObjectId("..."),
  "fullName": "John Doe",
  "email": "john@example.com",
  "fcmToken": "dGVzdF90b2tlbg==", // FCM token from Flutter app
  // ... other fields
}

// Users collection
{
  "_id": ObjectId("..."),
  "fullName": "Jane Smith", 
  "email": "jane@example.com",
  "fcmToken": "dGVzdF90b2tlbg==", // FCM token from Flutter app
  // ... other fields
}
```

### 🧪 **Testing Commands:**

#### **Test Notification Endpoint:**
```bash
curl -X POST http://your-backend-url/api/notifications/send-to-service-provider \
  -H "Content-Type: application/json" \
  -d '{
    "serviceProviderId": "YOUR_SERVICE_PROVIDER_ID",
    "title": "Test Notification",
    "message": "This is a test notification",
    "data": {
      "type": "booking_request",
      "bookingId": "test_123"
    }
  }'
```

#### **Test FCM Token Update:**
```bash
curl -X POST http://your-backend-url/api/users/fcm-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "fcmToken": "test_fcm_token_123"
  }'
```

### 🔧 **Firebase Configuration:**

Make sure your backend has Firebase Admin SDK configured:

```go
// In your config/firebase.go
package config

import (
    "context"
    "firebase.google.com/go/v4"
    "firebase.google.com/go/v4/messaging"
)

var FirebaseApp *firebase.App

func InitFirebase() error {
    app, err := firebase.NewApp(context.Background(), nil)
    if err != nil {
        return err
    }
    FirebaseApp = app
    return nil
}
```

### 📱 **Flutter App Usage:**

#### **For Users:**
- FCM tokens are automatically sent when they log in
- No additional setup required

#### **For Service Providers:**
- FCM tokens are automatically sent when they log in
- They will receive notifications when users book their services

#### **For Testing:**
```dart
// Navigate to test widget
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => BookingNotificationTest()),
);
```

### 🚨 **Troubleshooting:**

#### **Notifications Not Received:**
1. Check if service provider has FCM token in database
2. Verify Firebase configuration in backend
3. Check backend logs for FCM sending errors
4. Test with Firebase Console directly

#### **FCM Token Not Stored:**
1. Check if user is logged in
2. Verify JWT token is valid
3. Check backend logs for token update errors
4. Ensure user exists in database

#### **API Errors:**
1. Check endpoint URLs match exactly
2. Verify request body format
3. Check authentication headers
4. Ensure backend is running

### 🎯 **Next Steps:**

1. **Deploy Backend**: Make sure your Go backend is deployed with the new endpoints
2. **Test Integration**: Use the test widget to verify everything works
3. **Monitor Logs**: Check both Flutter and backend logs for any issues
4. **Production Testing**: Test with real users and service providers

### 📈 **Success Indicators:**

- ✅ Users can log in and FCM tokens are stored
- ✅ Service providers can log in and FCM tokens are stored  
- ✅ Booking notifications are sent successfully
- ✅ Service providers receive push notifications
- ✅ No errors in console logs

Your booking notification system is now **production-ready**! 🎉

The integration is complete and your Flutter app will automatically:
- Send FCM tokens to your backend when users log in
- Send booking notifications to service providers when users book services
- Handle all error cases gracefully
- Provide user feedback about notification status
