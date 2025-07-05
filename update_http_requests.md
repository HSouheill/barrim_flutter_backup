# Guide: Update HTTP Requests for Self-Signed Certificates

## What I've Done

1. **Added custom HTTP client** that handles self-signed certificates
2. **Created `_makeRequest` helper method** to centralize HTTP requests
3. **Updated login and getUserProfile methods** as examples

## How to Update Remaining Methods

Replace all `http.get`, `http.post`, `http.put`, `http.delete` calls with `_makeRequest`:

### Before:
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/endpoint'),
  headers: await _getHeaders(),
);
```

### After:
```dart
final response = await _makeRequest(
  'GET',
  Uri.parse('$baseUrl/api/endpoint'),
  headers: await _getHeaders(),
);
```

### For POST requests:
```dart
final response = await _makeRequest(
  'POST',
  Uri.parse('$baseUrl/api/endpoint'),
  headers: await _getHeaders(),
  body: jsonEncode(data),
);
```

## Methods to Update

Here are the methods in your `api_service.dart` that need updating:

1. `signupUser` - line ~200
2. `saveUserLocation` - line ~250
3. `signupBusiness` - line ~280
4. `signupServiceProviderWithLogo` - line ~350
5. `signupServiceProvider` - line ~400
6. `getCurrentUser` - line ~420
7. `forgotPassword` - line ~440
8. `resetPassword` - line ~460
9. `getCompaniesWithLocations` - line ~480
10. `verifyOtp` - line ~500
11. `getCompanyData` - line ~520
12. `uploadBranchData` - line ~600
13. `getCompanyBranches` - line ~700
14. `deleteBranch` - line ~750
15. `updateBranch` - line ~800
16. `updateCompanyData` - line ~900
17. `getAllBranches` - line ~950
18. `updateProfile` - line ~1100
19. `uploadProfilePhoto` - line ~1150
20. `changePassword` - line ~1200
21. `getUserData` - line ~1250
22. `updatePersonalInformation` - line ~1350
23. `getReferralData` - line ~1400
24. `submitReferralCode` - line ~1420
25. `getAvailableRewards` - line ~1440
26. `redeemPoints` - line ~1460
27. `getServiceProviderDetails` - line ~1550
28. `getServiceProviderById` - line ~1650
29. `updateServiceProviderDescription` - line ~1750
30. `getAllServiceProviders` - line ~1850
31. `getReviewsForProvider` - line ~1950
32. `createReview` - line ~1970
33. `addToFavorites` - line ~2000
34. `removeFromFavorites` - line ~2030
35. `getFavoriteBranches` - line ~2060
36. `getBranchComments` - line ~2150
37. `createBranchComment` - line ~2200
38. `replyToBranchComment` - line ~2250
39. `updateServiceProviderSocialLinks` - line ~2300
40. `signupWholesaler` - line ~2350
41. `getWholesalersWithLocations` - line ~2450
42. `fetchNotifications` - line ~2500
43. `smsverifyOtp` - line ~2520
44. `resendOtp` - line ~2580
45. `checkEmailOrPhoneExists` - line ~2650
46. `deleteUserAccount` - line ~2700

## Important Notes

1. **Security Warning**: This approach trusts self-signed certificates for your specific domain/IP only
2. **Production Recommendation**: Use Let's Encrypt or Cloudflare for free SSL certificates
3. **Testing**: Test thoroughly after making these changes

## Alternative: Use a Valid SSL Certificate

For production, consider using Let's Encrypt:

```bash
# Install Certbot
sudo apt update
sudo apt install certbot

# Get certificate
sudo certbot certonly --standalone -d yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

Then update your `baseUrl` to use your domain instead of IP address. 