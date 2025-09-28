// models/branch_comment.dart

class BranchComment {
  final String id;
  final String branchId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String comment;
  final int rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  BranchComment({
    required this.id,
    required this.branchId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.comment,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchComment.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] is int) ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '0') ?? 0;
    
    return BranchComment(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      branchId: json['branchId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Anonymous',
      userAvatar: json['userAvatar']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      rating: rating,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branchId': branchId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'comment': comment,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Format date to MM/dd format
  String getFormattedDate() {
    return '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
  }
}

class BranchRating {
  final double averageRating;
  final int totalComments;
  final Map<String, int> ratingDistribution; // e.g., {"1": 2, "2": 1, "3": 5, "4": 8, "5": 12}

  BranchRating({
    required this.averageRating,
    required this.totalComments,
    required this.ratingDistribution,
  });

  factory BranchRating.fromJson(Map<String, dynamic> json) {
    return BranchRating(
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      totalComments: json['totalComments'] ?? 0,
      ratingDistribution: Map<String, int>.from(json['ratingDistribution'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'totalComments': totalComments,
      'ratingDistribution': ratingDistribution,
    };
  }
}
