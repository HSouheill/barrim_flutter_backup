class Voucher {
  final String id;
  final String title;
  final String description;
  final int points;
  final String type;
  final String? discount;
  final String? imageUrl;
  final bool isActive;
  final String targetUserType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.type,
    this.discount,
    this.imageUrl,
    required this.isActive,
    required this.targetUserType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    // API returns 'image' field, not 'imageUrl'
    String? imageUrl = json['image'] ?? json['imageUrl'];
    
    // Debug: Print original image URL
    print('Original image field from API: ${json['image']}');
    print('Original imageUrl field from API: ${json['imageUrl']}');
    
    // Fix image URL path - remove extra 'vouchers/' from the path
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Convert from /uploads/vouchers/filename to /uploads/filename
      imageUrl = imageUrl.replaceAll('/uploads/vouchers/', '/uploads/');
      print('Processed imageUrl: $imageUrl');
    }
    
    return Voucher(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? '', // API uses 'name' field
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      type: json['type'] ?? '',
      discount: json['discount'],
      imageUrl: imageUrl,
      isActive: json['isActive'] ?? false,
      targetUserType: json['targetUserType'] ?? 'user',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'points': points,
      'type': type,
      'discount': discount,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'targetUserType': targetUserType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class UserVoucher {
  final Voucher voucher;
  final bool canPurchase;
  final int userPoints;
  final bool isPurchased;
  final VoucherPurchase? purchase;

  UserVoucher({
    required this.voucher,
    required this.canPurchase,
    required this.userPoints,
    this.isPurchased = false,
    this.purchase,
  });

  factory UserVoucher.fromJson(Map<String, dynamic> json) {
    // Debug: Print the json structure
    print('UserVoucher JSON: $json');
    
    return UserVoucher(
      voucher: Voucher.fromJson(json['voucher'] ?? {}),
      canPurchase: json['canPurchase'] ?? false,
      userPoints: json['userPoints'] ?? 0,
      isPurchased: json['isPurchased'] ?? false,
      purchase: json['purchase'] != null ? VoucherPurchase.fromJson(json['purchase']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voucher': voucher.toJson(),
      'canPurchase': canPurchase,
      'userPoints': userPoints,
      'isPurchased': isPurchased,
      'purchase': purchase?.toJson(),
    };
  }
}

class VoucherPurchaseRequest {
  final String voucherId;

  VoucherPurchaseRequest({
    required this.voucherId,
  });

  Map<String, dynamic> toJson() {
    return {
      'voucherId': voucherId,
    };
  }
}

class VoucherPurchase {
  final String id;
  final String userId;
  final String voucherId;
  final int pointsUsed;
  final DateTime purchasedAt;
  final bool isUsed;
  final DateTime? usedAt;

  VoucherPurchase({
    required this.id,
    required this.userId,
    required this.voucherId,
    required this.pointsUsed,
    required this.purchasedAt,
    required this.isUsed,
    this.usedAt,
  });

  factory VoucherPurchase.fromJson(Map<String, dynamic> json) {
    return VoucherPurchase(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      voucherId: json['voucherId'] ?? '',
      pointsUsed: json['pointsUsed'] ?? 0,
      purchasedAt: json['purchasedAt'] != null 
          ? DateTime.parse(json['purchasedAt']) 
          : DateTime.now(),
      isUsed: json['isUsed'] ?? false,
      usedAt: json['usedAt'] != null 
          ? DateTime.parse(json['usedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'voucherId': voucherId,
      'pointsUsed': pointsUsed,
      'purchasedAt': purchasedAt.toIso8601String(),
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
    };
  }
}
