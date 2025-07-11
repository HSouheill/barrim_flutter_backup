import '../services/api_service.dart';

class Booking {
  final String? id; // Optional because it might not exist for new bookings
  final String userId;
  final String serviceProviderId;
  final DateTime bookingDate;
  final String timeSlot;
  final String phoneNumber;
  final String details;
  final bool isEmergency;
  final String status; // "pending", "confirmed", "completed", "cancelled"
  final String? providerResponse; // Optional message from service provider
  final List<String> mediaTypes; // Array of "image" or "video"
  final List<String> mediaUrls; // Array of URLs to the uploaded media
  final List<String> thumbnailUrls; // Array of URLs to the thumbnails (for videos)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Booking({
    this.id,
    required this.userId,
    required this.serviceProviderId,
    required this.bookingDate,
    required this.timeSlot,
    required this.phoneNumber,
    required this.details,
    this.isEmergency = false,
    this.status = 'pending',
    this.providerResponse,
    this.mediaTypes = const [],
    this.mediaUrls = const [],
    this.thumbnailUrls = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Factory method to create a Booking from API JSON response
  factory Booking.fromJson(Map<String, dynamic> json) {
    // Debug: Print the raw JSON data for media fields
    print('Booking JSON - mediaTypes: ${json['mediaTypes']}');
    print('Booking JSON - mediaUrls: ${json['mediaUrls']}');
    print('Booking JSON - thumbnailUrls: ${json['thumbnailUrls']}');
    print('Full booking JSON: $json');

    // Construct full URLs for media files
    List<String> mediaUrls = [];
    List<String> thumbnailUrls = [];
    
    print('Checking mediaUrls: ${json['mediaUrls']} (type: ${json['mediaUrls'].runtimeType})');
    if (json['mediaUrls'] != null && json['mediaUrls'] is List) {
      print('mediaUrls is a List with ${json['mediaUrls'].length} items');
      for (var url in json['mediaUrls']) {
        print('Processing URL: $url (type: ${url.runtimeType})');
        if (url != null && url.toString().isNotEmpty) {
          String fullUrl;
          if (url.toString().startsWith('http')) {
            fullUrl = url.toString();
          } else {
            // Construct full URL with /uploads/bookings/ path
            fullUrl = '${ApiService.baseUrl}/uploads/bookings/${url.toString()}';
          }
          print('Constructed media URL: $fullUrl');
          mediaUrls.add(fullUrl);
        }
      }
    } else {
      print('mediaUrls is null or not a List');
    }
    
    print('Checking thumbnailUrls: ${json['thumbnailUrls']} (type: ${json['thumbnailUrls'].runtimeType})');
    if (json['thumbnailUrls'] != null && json['thumbnailUrls'] is List) {
      print('thumbnailUrls is a List with ${json['thumbnailUrls'].length} items');
      for (var url in json['thumbnailUrls']) {
        print('Processing thumbnail URL: $url (type: ${url.runtimeType})');
        if (url != null && url.toString().isNotEmpty) {
          String fullUrl;
          if (url.toString().startsWith('http')) {
            fullUrl = url.toString();
          } else {
            // Construct full URL with /uploads/bookings/ path
            fullUrl = '${ApiService.baseUrl}/uploads/bookings/${url.toString()}';
          }
          print('Constructed thumbnail URL: $fullUrl');
          thumbnailUrls.add(fullUrl);
        }
      }
    } else {
      print('thumbnailUrls is null or not a List');
    }

    return Booking(
      id: json['id'],
      userId: json['userId'],
      serviceProviderId: json['serviceProviderId'],
      bookingDate: DateTime.parse(json['bookingDate']),
      timeSlot: json['timeSlot'],
      phoneNumber: json['phoneNumber'],
      details: json['details'],
      isEmergency: json['isEmergency'] ?? false,
      status: json['status'] ?? 'pending',
      providerResponse: json['providerResponse'],
      mediaTypes: List<String>.from(json['mediaTypes'] ?? []),
      mediaUrls: mediaUrls,
      thumbnailUrls: thumbnailUrls,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // Convert Booking to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'serviceProviderId': serviceProviderId,
      'bookingDate': bookingDate.toIso8601String(),
      'timeSlot': timeSlot,
      'phoneNumber': phoneNumber,
      'details': details,
      'isEmergency': isEmergency,
      'status': status,
      if (providerResponse != null) 'providerResponse': providerResponse,
      'mediaTypes': mediaTypes,
      'mediaUrls': mediaUrls,
      'thumbnailUrls': thumbnailUrls,
    };
  }
}