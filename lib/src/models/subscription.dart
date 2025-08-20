// lib/models/subscription_model.dart
class SubscriptionPlan {
  final String? id;
  final String? title;
  final double? price;
  final int? duration;
  final String? type;
  final dynamic benefits;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isActive;

  SubscriptionPlan({
    this.id,
    this.title,
    this.price,
    this.duration,
    this.type,
    this.benefits,
    this.createdAt,
    this.updatedAt,
    this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    dynamic benefitsValue;
    if (json['benefits'] != null) {
      if (json['benefits'] is Map && json['benefits']['value'] != null) {
        benefitsValue = json['benefits']['value'];
      } else {
        benefitsValue = json['benefits'];
      }
    }

    // Handle isActive field conversion from various types
    bool? isActiveValue;
    if (json['isActive'] != null) {
      if (json['isActive'] is bool) {
        isActiveValue = json['isActive'] as bool;
      } else if (json['isActive'] is String) {
        final isActiveStr = json['isActive'].toString().toLowerCase();
        isActiveValue = isActiveStr == 'true' || isActiveStr == '1' || isActiveStr == 'yes';
      } else if (json['isActive'] is num) {
        isActiveValue = (json['isActive'] as num) != 0;
      } else {
        isActiveValue = false;
      }
    }

    return SubscriptionPlan(
      id: json['id'],
      title: json['title'],
      price: json['price']?.toDouble(),
      duration: json['duration'],
      type: json['type'],
      benefits: benefitsValue,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isActive: isActiveValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'duration': duration,
      'type': type,
      'benefits': benefits,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  String get benefitsText {
    if (benefits == null) return '';
    if (benefits is String) return benefits as String;
    if (benefits is List) {
      try {
        final List<dynamic> items = benefits as List;
        if (items.isNotEmpty && items[0] is List) {
          final List<dynamic> firstItem = items[0] as List;
          return firstItem.map((item) {
            if (item is Map && item['Key'] != null && item['Value'] != null) {
              // Only include items with non-empty values
              if (item['Value'].toString().isNotEmpty) {
                return '${item['Key']}: ${item['Value']}';
              }
              return item['Key'].toString();
            }
            return item.toString();
          }).where((text) => text.isNotEmpty).join('\n');
        }
      } catch (e) {
        print('Error formatting benefits: $e');
      }
    }
    return benefits.toString();
  }
}

class CompanySubscription {
  final String? id;
  final String? companyId;
  final String? planId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final bool? autoRenew;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CompanySubscription({
    this.id,
    this.companyId,
    this.planId,
    this.startDate,
    this.endDate,
    this.status,
    this.autoRenew,
    this.createdAt,
    this.updatedAt,
  });

  factory CompanySubscription.fromJson(Map<String, dynamic> json) {
    // Handle autoRenew field conversion from various types
    bool? autoRenewValue;
    if (json['autoRenew'] != null) {
      if (json['autoRenew'] is bool) {
        autoRenewValue = json['autoRenew'] as bool;
      } else if (json['autoRenew'] is String) {
        final autoRenewStr = json['autoRenew'].toString().toLowerCase();
        autoRenewValue = autoRenewStr == 'true' || autoRenewStr == '1' || autoRenewStr == 'yes';
      } else if (json['autoRenew'] is num) {
        autoRenewValue = (json['autoRenew'] as num) != 0;
      } else {
        autoRenewValue = false;
      }
    }

    return CompanySubscription(
      id: json['id'],
      companyId: json['companyId'],
      planId: json['planId'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      status: json['status'],
      autoRenew: autoRenewValue,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'planId': planId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'autoRenew': autoRenew,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class SubscriptionRequest {
  final String? id;
  final String? companyId;
  final String? planId;
  final String? status;
  final String? adminId;
  final String? adminNote;
  final DateTime? requestedAt;
  final DateTime? processedAt;
  final String? imagePath;

  SubscriptionRequest({
    this.id,
    this.companyId,
    this.planId,
    this.status,
    this.adminId,
    this.adminNote,
    this.requestedAt,
    this.processedAt,
    this.imagePath,
  });

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) {
    return SubscriptionRequest(
      id: json['id'],
      companyId: json['companyId'],
      planId: json['planId'],
      status: json['status'],
      adminId: json['adminId'],
      adminNote: json['adminNote'],
      requestedAt: json['requestedAt'] != null ? DateTime.parse(json['requestedAt']) : null,
      processedAt: json['processedAt'] != null ? DateTime.parse(json['processedAt']) : null,
      imagePath: json['imagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'planId': planId,
      'status': status,
      'adminId': adminId,
      'adminNote': adminNote,
      'requestedAt': requestedAt?.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'imagePath': imagePath,
    };
  }
}

/// Model for wholesaler branch subscription requests
class WholesalerBranchSubscriptionRequest {
  final String? id;
  final String? branchId;
  final String? planId;
  final String? status;
  final DateTime? requestedAt;
  final String? imagePath;

  WholesalerBranchSubscriptionRequest({
    this.id,
    this.branchId,
    this.planId,
    this.status,
    this.requestedAt,
    this.imagePath,
  });

  factory WholesalerBranchSubscriptionRequest.fromJson(Map<String, dynamic> json) {
    // Safe parsing with type checking
    String? safeId;
    try {
      final idValue = json['requestId'] ?? json['id'];
      safeId = idValue?.toString();
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing id: $e');
      safeId = null;
    }

    String? safeBranchId;
    try {
      final branchIdValue = json['branchId'];
      safeBranchId = branchIdValue?.toString();
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing branchId: $e');
      safeBranchId = null;
    }

    String? safePlanId;
    try {
      final planIdValue = json['planId'];
      safePlanId = planIdValue?.toString();
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing planId: $e');
      safePlanId = null;
    }

    String? safeStatus;
    try {
      final statusValue = json['status'];
      safeStatus = statusValue?.toString();
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing status: $e');
      safeStatus = null;
    }

    DateTime? safeRequestedAt;
    try {
      final requestedAtValue = json['submittedAt'] ?? json['requestedAt'];
      if (requestedAtValue != null) {
        if (requestedAtValue is DateTime) {
          safeRequestedAt = requestedAtValue;
        } else if (requestedAtValue is String) {
          safeRequestedAt = DateTime.parse(requestedAtValue);
        } else if (requestedAtValue is int) {
          // Handle timestamp
          safeRequestedAt = DateTime.fromMillisecondsSinceEpoch(requestedAtValue);
        }
      }
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing requestedAt: $e');
      safeRequestedAt = null;
    }

    String? safeImagePath;
    try {
      final imagePathValue = json['imagePath'];
      safeImagePath = imagePathValue?.toString();
    } catch (e) {
      print('WholesalerBranchSubscriptionRequest - Error parsing imagePath: $e');
      safeImagePath = null;
    }

    return WholesalerBranchSubscriptionRequest(
      id: safeId,
      branchId: safeBranchId,
      planId: safePlanId,
      status: safeStatus,
      requestedAt: safeRequestedAt,
      imagePath: safeImagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branchId': branchId,
      'planId': planId,
      'status': status,
      'requestedAt': requestedAt?.toIso8601String(),
      'imagePath': imagePath,
    };
  }
}

class SubscriptionRemainingTime {
  final int? days;
  final int? hours;
  final int? minutes;
  final String? formatted;
  final String? percentageUsed;
  final DateTime? endDate;

  SubscriptionRemainingTime({
    this.days,
    this.hours,
    this.minutes,
    this.formatted,
    this.percentageUsed,
    this.endDate,
  });

  factory SubscriptionRemainingTime.fromJson(Map<String, dynamic> json) {
    return SubscriptionRemainingTime(
      days: json['days'],
      hours: json['hours'],
      minutes: json['minutes'],
      formatted: json['formatted'],
      percentageUsed: json['percentageUsed'],
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'formatted': formatted,
      'percentageUsed': percentageUsed,
      'endDate': endDate?.toIso8601String(),
    };
  }
}

class CurrentSubscriptionData {
  final CompanySubscription? subscription;
  final SubscriptionPlan? plan;

  CurrentSubscriptionData({
    this.subscription,
    this.plan,
  });

  factory CurrentSubscriptionData.fromJson(Map<String, dynamic> json) {
    return CurrentSubscriptionData(
      subscription: json['subscription'] != null
          ? CompanySubscription.fromJson(json['subscription'])
          : null,
      plan: json['plan'] != null
          ? SubscriptionPlan.fromJson(json['plan'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscription': subscription?.toJson(),
      'plan': plan?.toJson(),
    };
  }
}

class SubscriptionRemainingTimeData {
  final bool? hasActiveSubscription;
  final SubscriptionRemainingTime? remainingTime;

  SubscriptionRemainingTimeData({
    this.hasActiveSubscription,
    this.remainingTime,
  });

  factory SubscriptionRemainingTimeData.fromJson(Map<String, dynamic> json) {
    // Handle hasActiveSubscription field conversion from various types
    bool? hasActiveSubscriptionValue;
    if (json['hasActiveSubscription'] != null) {
      if (json['hasActiveSubscription'] is bool) {
        hasActiveSubscriptionValue = json['hasActiveSubscription'] as bool;
      } else if (json['hasActiveSubscription'] is String) {
        final hasActiveStr = json['hasActiveSubscription'].toString().toLowerCase();
        hasActiveSubscriptionValue = hasActiveStr == 'true' || hasActiveStr == '1' || hasActiveStr == 'yes';
      } else if (json['hasActiveSubscription'] is num) {
        hasActiveSubscriptionValue = (json['hasActiveSubscription'] as num) != 0;
      } else {
        hasActiveSubscriptionValue = false;
      }
    }

    return SubscriptionRemainingTimeData(
      hasActiveSubscription: hasActiveSubscriptionValue,
      remainingTime: json['remainingTime'] != null
          ? SubscriptionRemainingTime.fromJson(json['remainingTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasActiveSubscription': hasActiveSubscription,
      'remainingTime': remainingTime?.toJson(),
    };
  }
}