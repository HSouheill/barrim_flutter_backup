class Voucher {
  final String id;
  final String title;
  final String description;
  final int points;
  final String discountType;
  final double discountValue;
  final bool isActive;
  final String targetUserType;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? imageUrl;

  Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.discountType,
    required this.discountValue,
    required this.isActive,
    required this.targetUserType,
    required this.createdAt,
    this.expiresAt,
    this.imageUrl,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['_id'] ?? json['id'] ?? '',
      // Backend uses `name` for service provider vouchers
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      points: json['points'] ?? 0,
      // Some SP vouchers might not include discount fields; default safely
      discountType: json['discountType'] ?? '',
      discountValue: (json['discountValue'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? false,
      targetUserType: json['targetUserType'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
      // Backend returns `image` filename - check multiple possible field names
      imageUrl: json['imageUrl'] ?? json['image'] ?? json['imagePath'] ?? json['image_url'],
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
      'isActive': isActive,
      'targetUserType': targetUserType,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }
}

class ServiceProviderVoucher {
  final Voucher voucher;
  final bool canPurchase;
  final int serviceProviderPoints;

  ServiceProviderVoucher({
    required this.voucher,
    required this.canPurchase,
    required this.serviceProviderPoints,
  });

  factory ServiceProviderVoucher.fromJson(Map<String, dynamic> json) {
    return ServiceProviderVoucher(
      voucher: Voucher.fromJson(json['voucher'] ?? {}),
      canPurchase: json['canPurchase'] ?? false,
      serviceProviderPoints: json['serviceProviderPoints'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voucher': voucher.toJson(),
      'canPurchase': canPurchase,
      'serviceProviderPoints': serviceProviderPoints,
    };
  }
}

class ServiceProviderVoucherPurchase {
  final String id;
  final String serviceProviderId;
  final String voucherId;
  final int pointsUsed;
  final DateTime purchasedAt;
  final bool isUsed;
  final DateTime? usedAt;

  ServiceProviderVoucherPurchase({
    required this.id,
    required this.serviceProviderId,
    required this.voucherId,
    required this.pointsUsed,
    required this.purchasedAt,
    required this.isUsed,
    this.usedAt,
  });

  factory ServiceProviderVoucherPurchase.fromJson(Map<String, dynamic> json) {
    return ServiceProviderVoucherPurchase(
      id: json['_id'] ?? json['id'] ?? '',
      serviceProviderId: json['serviceProviderId'] ?? '',
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
      'serviceProviderId': serviceProviderId,
      'voucherId': voucherId,
      'pointsUsed': pointsUsed,
      'purchasedAt': purchasedAt.toIso8601String(),
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
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

class VoucherResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  VoucherResult.success(this.data)
      : errorMessage = null,
        isSuccess = true;

  VoucherResult.error(this.errorMessage)
      : data = null,
        isSuccess = false;
}

class CompanyVoucher {
  final Voucher voucher;
  final bool canPurchase;

  CompanyVoucher({required this.voucher, required this.canPurchase});

  factory CompanyVoucher.fromJson(Map<String, dynamic> json) {
    return CompanyVoucher(
      voucher: Voucher.fromJson(json['voucher']),
      canPurchase: json['canPurchase'] ?? false,
    );
  }
}

class WholesalerVoucher {
  final Voucher voucher;
  final bool canPurchase;
  final int wholesalerPoints;

  WholesalerVoucher({
    required this.voucher,
    required this.canPurchase,
    required this.wholesalerPoints,
  });

  factory WholesalerVoucher.fromJson(Map<String, dynamic> json) {
    return WholesalerVoucher(
      voucher: Voucher.fromJson(json['voucher'] ?? {}),
      canPurchase: json['canPurchase'] ?? false,
      wholesalerPoints: json['wholesalerPoints'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voucher': voucher.toJson(),
      'canPurchase': canPurchase,
      'wholesalerPoints': wholesalerPoints,
    };
  }
}

class WholesalerVoucherPurchase {
  final String id;
  final String wholesalerId;
  final String voucherId;
  final int pointsUsed;
  final DateTime purchasedAt;
  final bool isUsed;
  final DateTime? usedAt;

  WholesalerVoucherPurchase({
    required this.id,
    required this.wholesalerId,
    required this.voucherId,
    required this.pointsUsed,
    required this.purchasedAt,
    required this.isUsed,
    this.usedAt,
  });

  factory WholesalerVoucherPurchase.fromJson(Map<String, dynamic> json) {
    return WholesalerVoucherPurchase(
      id: json['_id'] ?? json['id'] ?? '',
      wholesalerId: json['wholesalerId'] ?? '',
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
      'wholesalerId': wholesalerId,
      'voucherId': voucherId,
      'pointsUsed': pointsUsed,
      'purchasedAt': purchasedAt.toIso8601String(),
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
    };
  }
}