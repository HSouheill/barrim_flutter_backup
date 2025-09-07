import 'dart:convert';
import 'package:barrim/src/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../utils/token_manager.dart';

class BookingService {
  final String baseUrl = ApiService.baseUrl;
  final String token;
  final TokenManager tokenManager = TokenManager();

  // Define valid status constants to ensure consistency
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_ACCEPTED = 'accepted';
  static const String STATUS_REJECTED = 'rejected';
  static const String STATUS_CONFIRMED = 'confirmed';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';

  // --- Custom HTTP client with proper SSL handling ---
  static http.Client? _customClient;
  static Future<http.Client> _getCustomClient() async {
    if (_customClient != null) return _customClient!;
    
    // In production, use standard HTTP client for proper SSL validation
    // Let's Encrypt certificates are automatically trusted
    _customClient = http.Client();
    return _customClient!;
  }
  
  static Future<http.Response> _makeRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = await _getCustomClient();
    switch (method.toUpperCase()) {
      case 'GET':
        return await client.get(uri, headers: headers);
      case 'POST':
        return await client.post(uri, headers: headers, body: body);
      case 'PUT':
        return await client.put(uri, headers: headers, body: body);
      case 'DELETE':
        return await client.delete(uri, headers: headers, body: body);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  BookingService({required this.token});

  // Get available time slots for a specific service provider on a specific date
  Future<List<String>> getAvailableTimeSlots(String providerId, DateTime date) async {
    try {
      // Format date as YYYY-MM-DD for API query
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      // Fetching time slots for provider

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/bookings/available-slots/$providerId?date=$formattedDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          // Convert the data to List<String>
          final slots = List<String>.from(data['data']);
          return slots;
        } else {
          // Return empty list if no slots available
          return [];
        }
      } else {
        if (kDebugMode) {
          throw Exception('Failed to load time slots: ${response.statusCode}');
        } else {
          throw Exception('Failed to load time slots. Please try again.');
        }
      }
    } catch (e) {
      print('Error fetching available time slots: $e');
      if (kDebugMode) {
        throw Exception('Failed to load time slots: $e');
      } else {
        throw Exception('Failed to load time slots. Please try again.');
      }
    }
  }

  // Create a new booking
  Future<bool> createBooking(Booking booking, {String? mediaBase64, String? mediaFileName, String? mediaType}) async {
    try {
      // Input validation
      if (booking.serviceProviderId.trim().isEmpty) {
        throw Exception('Service provider ID is required');
      }
      
      if (booking.timeSlot.trim().isEmpty) {
        throw Exception('Time slot is required');
      }
      
      if (booking.phoneNumber.trim().isEmpty) {
        throw Exception('Phone number is required');
      }
      
      // Phone number format validation
      if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(booking.phoneNumber.replaceAll(RegExp(r'[\s-]'), ''))) {
        throw Exception('Invalid phone number format');
      }
      
      // Date validation
      if (booking.bookingDate.isBefore(DateTime.now())) {
        throw Exception('Booking date cannot be in the past');
      }
      
      final formattedDate = booking.bookingDate.toUtc().toIso8601String();

      final requestBody = {
        'serviceProviderId': booking.serviceProviderId,
        'bookingDate': formattedDate,
        'timeSlot': booking.timeSlot,
        'phoneNumber': booking.phoneNumber,
        'details': booking.details,
        'isEmergency': booking.isEmergency,
      };

      // Add media data if exists
      if (mediaBase64 != null && mediaFileName != null) {
        requestBody['mediaFile'] = mediaBase64;
        requestBody['mediaFileName'] = mediaFileName;
        requestBody['mediaType'] = mediaType ?? 'image'; // Use provided mediaType or default to image
      }

      final response = await _makeRequest(
        'POST',
        Uri.parse('$baseUrl/api/bookings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        final errorData = json.decode(response.body);
        if (kDebugMode) {
          throw Exception(errorData['message'] ?? 'Failed to create booking. Status: ${response.statusCode}');
        } else {
          throw Exception(errorData['message'] ?? 'Failed to create booking. Please try again.');
        }
      }
    } catch (e) {
      print('Error creating booking: $e');
      if (kDebugMode) {
        throw Exception('Failed to create booking: $e');
      } else {
        throw Exception('Failed to create booking. Please try again.');
      }
    }
  }

  // Get user bookings
  Future<List<Booking>> getUserBookings() async {
    try {
      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/bookings/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => Booking.fromJson(item))
              .toList();
        } else {
          return [];
        }
      } else {
        if (kDebugMode) {
          throw Exception('Failed to load bookings: ${response.statusCode}');
        } else {
          throw Exception('Failed to load bookings. Please try again.');
        }
      }
    } catch (e) {
      print('Error fetching user bookings: $e');
      if (kDebugMode) {
        throw Exception('Failed to load bookings: $e');
      } else {
        throw Exception('Failed to load bookings. Please try again.');
      }
    }
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/bookings/$bookingId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to cancel booking');
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      // Input validation
      if (bookingId.trim().isEmpty) {
        throw Exception('Booking ID is required');
      }
      
      if (status.trim().isEmpty) {
        throw Exception('Status is required');
      }
      
      // Validate status before sending to server
      final validStatus = status.trim().toLowerCase();

      if (![STATUS_CONFIRMED, STATUS_COMPLETED, STATUS_CANCELLED].contains(validStatus)) {
        throw Exception('Invalid status. Use \'confirmed\', \'completed\', or \'cancelled\'');
      }

      // Use the correct API endpoint for service providers
      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/bookings/$bookingId/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': validStatus}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update booking status');
      }
    } catch (e) {
      print('Error updating booking status: $e');
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Get all bookings for the logged-in service provider
  Future<List<Booking>> getProviderBookings() async {
    try {
      final token = await tokenManager.getToken();
      // Token logging removed for security

      final response = await _makeRequest(
        'GET',
        Uri.parse('$baseUrl/api/service-provider/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Response logged without sensitive data

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          final List<dynamic> enrichedBookingsJson = data['data'];
          print('BookingService: Found ${enrichedBookingsJson.length} enriched bookings');
          
          final bookings = enrichedBookingsJson.map((enrichedBooking) {
            // Extract the booking data from the enriched structure
            final bookingData = enrichedBooking['booking'];
            final userData = enrichedBooking['user'];
            
            // Merge user data into booking data for the Booking.fromJson method
            final mergedData = Map<String, dynamic>.from(bookingData);
            if (userData != null) {
              mergedData['userFullName'] = userData['fullName'];
              mergedData['userEmail'] = userData['email'];
              mergedData['userPhone'] = userData['phone'];
              mergedData['userProfilePic'] = userData['profilePic'];
            }
            
            // Create booking from the merged data
            final booking = Booking.fromJson(mergedData);
            
            return booking;
          }).toList();
          
          print('BookingService: Successfully parsed ${bookings.length} bookings');
          return bookings;
        } else {
          print('BookingService: No bookings found or invalid response structure');
          return [];
        }
      } else {
        print('BookingService: API error - Status: ${response.statusCode}, Body: ${response.body}');
        if (kDebugMode) {
          throw Exception('Failed to load bookings: ${response.statusCode}');
        } else {
          throw Exception('Failed to load bookings. Please try again.');
        }
      }
    } catch (e) {
      print('BookingService: Exception in getProviderBookings: $e');
      if (kDebugMode) {
        throw Exception('Failed to load bookings: $e');
      } else {
        throw Exception('Failed to load bookings. Please try again.');
      }
    }
  }

  // Respond to a booking (accept or reject)
  Future<bool> respondToBooking(String bookingId, String status) async {
    try {
      // Validate status
      if (status != STATUS_ACCEPTED && status != STATUS_REJECTED) {
        throw Exception('Invalid status. Use "accepted" or "rejected"');
      }

      final response = await _makeRequest(
        'PUT',
        Uri.parse('$baseUrl/api/service-provider/bookings/$bookingId/respond'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to respond to booking');
      }
    } catch (e) {
      print('Error responding to booking: $e');
      throw Exception('Failed to respond to booking: $e');
    }
  }
}