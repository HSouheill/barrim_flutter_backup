// lib/models/api_response.dart
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;
  final String? error;
  final int? status;  // Add status field for backward compatibility

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
    this.error,
    this.status,
  });

  // Add method to get appropriate message for empty data
  String getEmptyDataMessage(String entityType) {
    if ((success || status == 200) && data == null) {
      return 'No $entityType found';
    }
    return message;
  }

  // Add method to check if response is successful but has no data
  bool get isSuccessfulButEmpty => (success || status == 200) && data == null;

  factory ApiResponse.fromJson(Map<String, dynamic> json, [T Function(Map<String, dynamic>)? fromJson]) {
    // Handle both old and new response formats
    final bool isSuccess = json['success'] ?? (json['status'] == 200);
    final String message = json['message'] ?? '';
    final T? data = json['data'] != null 
        ? (fromJson != null ? fromJson(json['data']) : json['data'] as T)
        : null;
    final int? statusCode = json['statusCode'];
    final String? error = json['error'];
    final int? status = json['status'];

    return ApiResponse<T>(
      success: isSuccess,
      message: message,
      data: data,
      statusCode: statusCode,
      error: error,
      status: status,
    );
  }

  Map<String, dynamic> toJson([Map<String, dynamic> Function(T)? toJson]) {
    return {
      'success': success,
      'message': message,
      'data': data != null ? (toJson != null ? toJson(data as T) : data) : null,
      'statusCode': statusCode,
      'error': error,
      'status': status,
    };
  }
} 