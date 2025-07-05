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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? mediaUrl; // URL of the uploaded media
  final String? mediaType; // 'image' or 'video'

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
    this.createdAt,
    this.updatedAt,
    this.mediaUrl,
    this.mediaType,
  });

  // Factory method to create a Booking from API JSON response
  factory Booking.fromJson(Map<String, dynamic> json) {
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
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
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
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaType != null) 'mediaType': mediaType,
    };
  }
}