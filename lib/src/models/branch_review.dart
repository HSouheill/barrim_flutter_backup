// models/branch_review.dart
import 'package:intl/intl.dart';

class BranchReview {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String comment;
  final int rating;
  final DateTime date;
  final List<CommentReply> replies;

  BranchReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.comment,
    required this.rating,
    required this.date,
    required this.replies,
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
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',
      userImage: json['userAvatar'] ?? '',
      comment: json['comment'] ?? '',
      rating: json['rating'] ?? 0,
      date: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      replies: parsedReplies,
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
      id: json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      reply: json['reply'] ?? '',
      date: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}