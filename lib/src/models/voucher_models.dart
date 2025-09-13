class Voucher {
  final String id;
  final String title;
  final String description;
  final int points;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final String targetUserType; // 'company' or 'user'
  final bool isActive;
  final DateTime? expiryDate;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.discountType,
    required this.discountValue,
    required this.targetUserType,
    required this.isActive,
    this.expiryDate,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? json['name'] ?? '', // Handle both 'title' and 'name'
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      discountType: json['discountType'] ?? 'percentage',
      discountValue: (json['discountValue'] ?? 0).toDouble(),
      targetUserType: json['targetUserType'] ?? 'company',
      isActive: json['isActive'] ?? false,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate']) 
          : null,
      imageUrl: json['imageUrl'] ?? json['image'], // Handle both 'imageUrl' and 'image'
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'points': points,
      'discountType': discountType,
      'discountValue': discountValue,
      'targetUserType': targetUserType,
      'isActive': isActive,
      'expiryDate': expiryDate?.toIso8601String(),
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CompanyVoucher {
  final Voucher voucher;
  final bool canPurchase;
  final int companyPoints;
  final CompanyVoucherPurchase? purchase; // For purchased vouchers

  CompanyVoucher({
    required this.voucher,
    required this.canPurchase,
    required this.companyPoints,
    this.purchase,
  });

  factory CompanyVoucher.fromJson(Map<String, dynamic> json) {
    return CompanyVoucher(
      voucher: Voucher.fromJson(json['voucher'] ?? {}),
      canPurchase: json['canPurchase'] ?? false,
      companyPoints: json['companyPoints'] ?? 0,
      purchase: json['purchase'] != null 
          ? CompanyVoucherPurchase.fromJson(json['purchase'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voucher': voucher.toJson(),
      'canPurchase': canPurchase,
      'companyPoints': companyPoints,
      if (purchase != null) 'purchase': purchase!.toJson(),
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

class CompanyVoucherPurchase {
  final String id;
  final String companyId;
  final String voucherId;
  final int pointsUsed;
  final DateTime purchasedAt;
  final bool isUsed;
  final DateTime? usedAt;

  CompanyVoucherPurchase({
    required this.id,
    required this.companyId,
    required this.voucherId,
    required this.pointsUsed,
    required this.purchasedAt,
    required this.isUsed,
    this.usedAt,
  });

  factory CompanyVoucherPurchase.fromJson(Map<String, dynamic> json) {
    return CompanyVoucherPurchase(
      id: json['_id'] ?? json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      voucherId: json['voucherId'] ?? '',
      pointsUsed: json['pointsUsed'] ?? 0,
      purchasedAt: DateTime.parse(json['purchasedAt'] ?? DateTime.now().toIso8601String()),
      isUsed: json['isUsed'] ?? false,
      usedAt: json['usedAt'] != null 
          ? DateTime.parse(json['usedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'voucherId': voucherId,
      'pointsUsed': pointsUsed,
      'purchasedAt': purchasedAt.toIso8601String(),
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
    };
  }
}
