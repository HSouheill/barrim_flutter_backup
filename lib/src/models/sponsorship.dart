class Sponsorship {
  final String? id;
  final String? title;
  final double? price;
  final int? duration;
  final double? discount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Sponsorship({
    this.id,
    this.title,
    this.price,
    this.duration,
    this.discount,
    this.startDate,
    this.endDate,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Sponsorship.fromJson(Map<String, dynamic> json) {
    return Sponsorship(
      id: json['id'] ?? json['_id'], // Handle both 'id' and '_id' fields
      title: json['title'],
      price: json['price']?.toDouble(),
      duration: json['duration'],
      discount: json['discount']?.toDouble(),
      startDate: json['startDate'] != null 
        ? DateTime.parse(json['startDate'])
        : null,
      endDate: json['endDate'] != null 
        ? DateTime.parse(json['endDate'])
        : null,
      createdBy: json['createdBy'],
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'])
        : null,
      updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'price': price,
      'duration': duration,
      'discount': discount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class SponsorshipResponse {
  final bool success;
  final Map<String, dynamic>? data;
  final String? message;

  SponsorshipResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory SponsorshipResponse.fromJson(Map<String, dynamic> json) {
    return SponsorshipResponse(
      success: json['success'] ?? false,
      data: json['data'],
      message: json['message'],
    );
  }
}

class SponsorshipPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  SponsorshipPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory SponsorshipPagination.fromJson(Map<String, dynamic> json) {
    return SponsorshipPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'pages': pages,
    };
  }
}

// New models for sponsorship subscription time remaining
class SponsorshipSubscriptionTimeRemaining {
  final int? seconds;
  final int? minutes;
  final int? hours;
  final int? days;
  final String? formatted;
  final String? percentageUsed;
  final DateTime? startDate;
  final DateTime? endDate;

  SponsorshipSubscriptionTimeRemaining({
    this.seconds,
    this.minutes,
    this.hours,
    this.days,
    this.formatted,
    this.percentageUsed,
    this.startDate,
    this.endDate,
  });

  factory SponsorshipSubscriptionTimeRemaining.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscriptionTimeRemaining(
      seconds: json['seconds'],
      minutes: json['minutes'],
      hours: json['hours'],
      days: json['days'],
      formatted: json['formatted'],
      percentageUsed: json['percentageUsed'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seconds': seconds,
      'minutes': minutes,
      'hours': hours,
      'days': days,
      'formatted': formatted,
      'percentageUsed': percentageUsed,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}

class SponsorshipSubscriptionEntityInfo {
  final String? branchName;
  final String? wholesalerName;

  SponsorshipSubscriptionEntityInfo({
    this.branchName,
    this.wholesalerName,
  });

  factory SponsorshipSubscriptionEntityInfo.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscriptionEntityInfo(
      branchName: json['branchName'],
      wholesalerName: json['wholesalerName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branchName': branchName,
      'wholesalerName': wholesalerName,
    };
  }
}

class SponsorshipSubscriptionTimeRemainingData {
  final bool hasActiveSubscription;
  final SponsorshipSubscriptionTimeRemaining? timeRemaining;
  final SponsorshipSubscription? subscription;
  final Sponsorship? sponsorship;
  final SponsorshipSubscriptionEntityInfo? entityInfo;
  final String? message;

  SponsorshipSubscriptionTimeRemainingData({
    required this.hasActiveSubscription,
    this.timeRemaining,
    this.subscription,
    this.sponsorship,
    this.entityInfo,
    this.message,
  });

  factory SponsorshipSubscriptionTimeRemainingData.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscriptionTimeRemainingData(
      hasActiveSubscription: json['hasActiveSubscription'] ?? false,
      timeRemaining: json['timeRemaining'] != null 
          ? SponsorshipSubscriptionTimeRemaining.fromJson(json['timeRemaining'])
          : null,
      subscription: json['subscription'] != null 
          ? SponsorshipSubscription.fromJson(json['subscription'])
          : null,
      sponsorship: json['sponsorship'] != null 
          ? Sponsorship.fromJson(json['sponsorship'])
          : null,
      entityInfo: json['entityInfo'] != null 
          ? SponsorshipSubscriptionEntityInfo.fromJson(json['entityInfo'])
          : null,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasActiveSubscription': hasActiveSubscription,
      'timeRemaining': timeRemaining?.toJson(),
      'subscription': subscription?.toJson(),
      'sponsorship': sponsorship?.toJson(),
      'entityInfo': entityInfo?.toJson(),
      'message': message,
    };
  }
}

class SponsorshipSubscription {
  final String? id;
  final String? sponsorshipId;
  final String? entityType;
  final String? entityId;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SponsorshipSubscription({
    this.id,
    this.sponsorshipId,
    this.entityType,
    this.entityId,
    this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  factory SponsorshipSubscription.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscription(
      id: json['id'] ?? json['_id'],
      sponsorshipId: json['sponsorshipId'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      status: json['status'],
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'])
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sponsorshipId': sponsorshipId,
      'entityType': entityType,
      'entityId': entityId,
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class SponsorshipSubscriptionRequest {
  final String? id;
  final String sponsorshipId;
  final String entityType;
  final String entityId;
  final String entityName;
  final String status;
  final DateTime requestedAt;
  final bool? adminApproved;
  final bool? managerApproved;

  SponsorshipSubscriptionRequest({
    this.id,
    required this.sponsorshipId,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.status,
    required this.requestedAt,
    this.adminApproved,
    this.managerApproved,
  });

  factory SponsorshipSubscriptionRequest.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscriptionRequest(
      id: json['_id'],
      sponsorshipId: json['sponsorshipId'] ?? '',
      entityType: json['entityType'] ?? '',
      entityId: json['entityId'] ?? '',
      entityName: json['entityName'] ?? '',
      status: json['status'] ?? '',
      requestedAt: json['requestedAt'] != null
        ? DateTime.parse(json['requestedAt'])
        : DateTime.now(),
      adminApproved: json['adminApproved'],
      managerApproved: json['managerApproved'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sponsorshipId': sponsorshipId,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'adminApproved': adminApproved,
      'managerApproved': managerApproved,
    };
  }
}

class SponsorshipSubscriptionRequestResponse {
  final bool success;
  final String? message;
  final SponsorshipSubscriptionRequest? request;

  SponsorshipSubscriptionRequestResponse({
    required this.success,
    this.message,
    this.request,
  });

  factory SponsorshipSubscriptionRequestResponse.fromJson(Map<String, dynamic> json) {
    return SponsorshipSubscriptionRequestResponse(
      success: json['success'] ?? false,
      message: json['message'],
      request: json['request'] != null
        ? SponsorshipSubscriptionRequest.fromJson(json['request'])
        : null,
    );
  }
}
