# SecureNetworkImage Widget

## Overview

The `SecureNetworkImage` widget is a custom Flutter widget designed to handle image loading from servers with self-signed SSL certificates. It uses the same custom HTTP client as the `ApiService` to accept self-signed certificates.

## Usage

Replace `Image.network()` or `NetworkImage()` with `SecureNetworkImage` in your widgets:

```dart
// Before (causes certificate errors with self-signed certs)
Image.network(
  'https://104.131.188.174/uploads/profiles/image.jpg',
  width: 100,
  height: 100,
  fit: BoxFit.cover,
)

// After (handles self-signed certificates)
SecureNetworkImage(
  imageUrl: 'https://104.131.188.174/uploads/profiles/image.jpg',
  width: 100,
  height: 100,
  fit: BoxFit.cover,
  placeholder: const Center(child: CircularProgressIndicator()),
  errorWidget: (context, url, error) {
    return const Icon(Icons.error_outline, color: Colors.red);
  },
)
```

## Features

- **Self-signed Certificate Support**: Automatically accepts self-signed certificates from your server
- **Loading States**: Shows a placeholder while loading
- **Error Handling**: Custom error widgets for failed loads
- **Fade-in Animation**: Smooth fade-in effect when image loads
- **Memory Efficient**: Uses `Image.memory()` for better performance

## Parameters

- `imageUrl` (required): The URL of the image to load
- `width` / `height`: Dimensions of the image
- `fit`: How the image should be fitted (BoxFit.cover, BoxFit.contain, etc.)
- `placeholder`: Widget to show while loading
- `errorWidget`: Function that returns a widget to show on error
- `fadeInDuration`: Duration of the fade-in animation
- `fadeInCurve`: Animation curve for the fade-in effect

## Implementation Details

The widget uses the same custom HTTP client as `ApiService.getCustomClient()` which:

1. Creates an `HttpClient` with custom certificate handling
2. Sets `badCertificateCallback` to accept certificates from your server domain
3. Wraps it in an `IOClient` for use with the `http` package
4. Downloads the image as bytes and displays it using `Image.memory()`

## Files Updated

The following files have been updated to use `SecureNetworkImage`:

- `lib/src/features/authentication/headers/service_provider_header.dart`
- `lib/src/features/authentication/screens/workers/worker_home.dart`
- `lib/src/features/authentication/screens/settings/profile_settings.dart`
- `lib/src/features/authentication/screens/referrals/user_referral.dart`

## Migration Guide

To migrate existing `Image.network()` calls:

1. Import the widget: `import 'package:barrim/src/components/secure_network_image.dart';`
2. Replace `Image.network()` with `SecureNetworkImage()`
3. Update parameters:
   - `src` becomes `imageUrl`
   - `errorBuilder` becomes `errorWidget`
   - `loadingBuilder` becomes `placeholder`
4. Remove `const` from the widget constructor if you have custom error/loading widgets 