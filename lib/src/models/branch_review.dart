// models/branch_review.dart
import 'review.dart';

class BranchReview {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String comment;
  final int rating;
  final DateTime date;
  final List<CommentReply> replies;
  final String? mediaUrl;
  final String? mediaType;
  final String? thumbnailUrl;
  final ReviewReply? reply;

  BranchReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.comment,
    required this.rating,
    required this.date,
    required this.replies,
    this.mediaUrl,
    this.mediaType,
    this.thumbnailUrl,
    this.reply,
  });

  factory BranchReview.fromJson(Map<String, dynamic> json) {
    List<CommentReply> parsedReplies = [];
    if (json['replies'] != null) {
      // Make sure it's a list before trying to parse it
      if (json['replies'] is List) {
        parsedReplies = (json['replies'] as List)
            .map((replyJson) => CommentReply.fromJson(replyJson))
            .toList();
      }
    }

    return BranchReview(
      id: json['_id']?['\$oid'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? 'Anonymous',
      userImage: json['userProfilePic'] ?? json['userAvatar'] ?? '',
      comment: json['comment'] ?? '',
      rating: json['rating'] ?? 0,
      date: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      replies: parsedReplies,
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      thumbnailUrl: json['thumbnailUrl'],
      reply: json['reply'] != null ? ReviewReply.fromJson(json['reply']) : null,
    );
  }
}

class CommentReply {
  final String id;
  final String companyId;
  final String reply;
  final DateTime date;

  CommentReply({
    required this.id,
    required this.companyId,
    required this.reply,
    required this.date,
  });

  factory CommentReply.fromJson(Map<String, dynamic> json) {
    return CommentReply(
      id: json['_id']?['\$oid'] ?? json['id'] ?? '',
      companyId: json['companyID'] ?? json['companyId'] ?? '',
      reply: json['reply'] ?? '',
      date: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}