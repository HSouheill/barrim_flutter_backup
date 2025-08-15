import 'dart:convert';
import 'package:http/http.dart' as http;
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
    if (response['success'] != true || response['data'] == null) {
      return [];
    }

    final data = response['data'];
    if (data['sponsorships'] == null) {
      return [];
    }

    final sponsorshipsList = data['sponsorships'] as List;
    return sponsorshipsList
        .map((json) => Sponsorship.fromJson(json))
        .toList();
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
    required String entityType,
    required String entityId,
    required String entityName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sponsorship-subscriptions/request'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sponsorshipId': sponsorshipId,
          'entityType': entityType,
          'entityId': entityId,
          'entityName': entityName,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create sponsorship subscription request',
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
}
