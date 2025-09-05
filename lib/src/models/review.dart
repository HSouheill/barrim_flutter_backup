// models/review.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReviewReply {
  final String serviceProviderId;
  final String replyText;
  final DateTime createdAt;

  ReviewReply({
    required this.serviceProviderId,
    required this.replyText,
    required this.createdAt,
  });

  factory ReviewReply.fromJson(Map<String, dynamic> json) {
    return ReviewReply(
      serviceProviderId: json['serviceProviderId'] ?? '',
      replyText: json['replyText'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceProviderId': serviceProviderId,
      'replyText': replyText,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class Review {
  final String id;
  final String serviceProviderId;
  final String userId;
  final String username;
  final String userProfilePic;
  final int rating;
  final String comment;
  final bool isVerified;
  final String? mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final File? mediaFile;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ReviewReply? reply;

  Review({
    required this.id,
    required this.serviceProviderId,
    required this.userId,
    required this.username,
    required this.userProfilePic,
    required this.rating,
    required this.comment,
    required this.isVerified,
    required this.createdAt,
    this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaFile,
    this.updatedAt,
    this.reply,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      serviceProviderId: json['serviceProviderId'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? 'Anonymous',
      userProfilePic: json['userProfilePic'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      isVerified: json['isVerified'] ?? false,
      mediaType: json['mediaType'],
      mediaUrl: json['mediaUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      reply: json['reply'] != null ? ReviewReply.fromJson(json['reply']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'serviceProviderId': serviceProviderId,
      'rating': rating,
      'comment': comment,
      if (mediaType != null) 'mediaType': mediaType,
    };
    if (reply != null) data['reply'] = reply!.toJson();
    return data;
  }

  // Format date to MM/dd format
  String getFormattedDate() {
    return '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
  }
}