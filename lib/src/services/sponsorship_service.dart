import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sponsorship.dart';
import 'api_service.dart';

class SponsorshipService {
  static const String baseUrl = 'https://barrim.online/api';

  // Get service provider sponsorships
  static Future<Map<String, dynamic>> getServiceProviderSponsorships({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sponsorships/service-provider?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch service provider sponsorships',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  // Get company/wholesaler sponsorships
  static Future<Map<String, dynamic>> getCompanyWholesalerSponsorships({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sponsorships/company-wholesaler?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch company/wholesaler sponsorships',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  // Parse sponsorships from API response
  static List<Sponsorship> parseSponsorships(Map<String, dynamic> response) {
    print('SponsorshipService.parseSponsorships called with: $response');
    
    if (response['success'] != true || response['data'] == null) {
      print('SponsorshipService: Response not successful or no data');
      return [];
    }

    final data = response['data'];
    print('SponsorshipService: Data extracted: $data');
    
    if (data['sponsorships'] == null) {
      print('SponsorshipService: No sponsorships field in data');
      return [];
    }

    final sponsorshipsList = data['sponsorships'] as List;
    print('SponsorshipService: Sponsorships list length: ${sponsorshipsList.length}');
    print('SponsorshipService: First sponsorship raw data: ${sponsorshipsList.isNotEmpty ? sponsorshipsList.first : 'empty'}');
    
    final parsedSponsorships = sponsorshipsList
        .map((json) {
          print('SponsorshipService: Parsing sponsorship JSON: $json');
          final sponsorship = Sponsorship.fromJson(json);
          print('SponsorshipService: Parsed sponsorship: ${sponsorship.toJson()}');
          return sponsorship;
        })
        .toList();
    
    print('SponsorshipService: Final parsed sponsorships: ${parsedSponsorships.map((s) => s.toJson()).toList()}');
    return parsedSponsorships;
  }

  // Parse pagination from API response
  static SponsorshipPagination? parsePagination(Map<String, dynamic> response) {
    if (response['success'] != true || response['data'] == null) {
      return null;
    }

    final data = response['data'];
    if (data['pagination'] == null) {
      return null;
    }

    return SponsorshipPagination.fromJson(data['pagination']);
  }

  // Get entity type from API response
  static String? getEntityType(Map<String, dynamic> response) {
    if (response['success'] != true || response['data'] == null) {
      return null;
    }

    final data = response['data'];
    return data['entityType'];
  }

  // Create sponsorship subscription request
  static Future<Map<String, dynamic>> createSponsorshipSubscriptionRequest({
    required String sponsorshipId,
    required String entityId,
    required String entityType,
    required String entityName,
  }) async {
    try {
      final requestBody = {
        'sponsorshipId': sponsorshipId,
        'entityType': entityType,
        'entityId': entityId,
        'entityName': entityName,
        'status': 'pending', // Add status field
      };
      
      // Get authentication headers
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      print('SponsorshipService: Sending request to $baseUrl/sponsorships-subscriptions/request');
      print('SponsorshipService: Request body: $requestBody');
      print('SponsorshipService: Headers: $headers');
      
      final response = await http.post(
        Uri.parse('$baseUrl/sponsorship-subscriptions/request'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('Service: Response status: ${response.statusCode}');
      print('SponsorshipService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        print('SponsorshipService: Error response: $errorData');
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create sponsorship subscription request',
          'error': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      print('SponsorshipService: Exception: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }
}
