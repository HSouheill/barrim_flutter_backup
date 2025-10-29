import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiTestHelper {
  static const String baseUrl = 'https://barrim.online';
  
  /// Test the notification API endpoint
  static Future<Map<String, dynamic>> testNotificationAPI({
    required String serviceProviderId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('Testing notification API...');
      print('URL: $baseUrl/api/notifications/send-to-service-provider');
      print('Service Provider ID: $serviceProviderId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/send-to-service-provider'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'serviceProviderId': serviceProviderId,
          'title': title,
          'message': message,
          'data': data ?? {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );
      
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'statusCode': response.statusCode,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      print('Error testing notification API: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test if the API endpoint is reachable
  static Future<bool> testApiReachability() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('Health check status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('API not reachable: $e');
      return false;
    }
  }
  
  /// Test with different service provider IDs
  static Future<void> testMultipleProviders() async {
    final testProviders = [
      '68f8991743d7e235e1646a79',
      'test-service-provider-id',
      '652a6111c111111111111111',
    ];
    
    for (final providerId in testProviders) {
      print('\n=== Testing with Provider ID: $providerId ===');
      final result = await testNotificationAPI(
        serviceProviderId: providerId,
        title: 'Test Notification',
        message: 'Testing with provider $providerId',
      );
      print('Result: $result');
    }
  }
}
