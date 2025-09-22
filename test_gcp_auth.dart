/// Test script for GCP OAuth implementation
/// 
/// This script can be used to test the GCP OAuth implementation
/// Run with: dart test_gcp_auth.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/src/services/gcp_google_auth_service.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GCPGoogleSignInProvider(),
      child: MaterialApp(
        title: 'GCP OAuth Test',
        home: TestScreen(),
      ),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GCP OAuth Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GCP OAuth Implementation Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Before testing, make sure to:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            Text('1. Configure GCP OAuth credentials in gcp_config.dart'),
            Text('2. Update iOS Info.plist with correct URL scheme'),
            Text('3. Verify Android SHA-1 fingerprint in GCP Console'),
            SizedBox(height: 30),
            Consumer<GCPGoogleSignInProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    if (provider.isLoading)
                      CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: () async {
                          final result = await provider.googleLogin();
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Login successful!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (provider.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${provider.error}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Text('Test Google Sign-In'),
                      ),
                    if (provider.error != null)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Error: ${provider.error}',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
