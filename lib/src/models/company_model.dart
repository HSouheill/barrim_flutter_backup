// lib/models/company_model.dart
class Company {
  final String id;
  final String userId;
  final String businessName;
  final String category;
  final String? subCategory;
  final String? referralCode;
  final List<String>? referrals;
  final int points;
  final ContactInfo contactInfo;
  final SocialMedia? socialMedia;
  final String? logo;
  final double balance;
  final List<Branch>? branches;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.category,
    this.subCategory,
    this.referralCode,
    this.referrals,
    required this.points,
    required this.contactInfo,
    this.socialMedia,
    this.logo,
    required this.balance,
    this.branches,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    // Extract companyInfo if it exists
    final companyInfo = json['companyInfo'] ?? json;
    
    return Company(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      businessName: companyInfo['name'] ?? '',  // Changed from businessName to name
      category: companyInfo['category'] ?? '',
      subCategory: companyInfo['subCategory'],
      referralCode: json['referralCode'],
      referrals: json['referrals'] != null
          ? List<String>.from(json['referrals'])
          : null,
      points: json['points'] ?? 0,
      contactInfo: ContactInfo.fromJson(companyInfo['contactInfo'] ?? {}),
      socialMedia: companyInfo['socialMedia'] != null
          ? SocialMedia.fromJson(companyInfo['socialMedia'])
          : null,
      logo: companyInfo['logo'],  // Get logo from companyInfo
      balance: (json['balance'] ?? 0).toDouble(),
      branches: json['branches'] != null
          ? (json['branches'] as List).map((b) => Branch.fromJson(b)).toList()
          : null,
      createdBy: json['createdBy'] ?? '',
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
      'userId': userId,
      'businessName': businessName,
      'category': category,
      'subCategory': subCategory,
      'referralCode': referralCode,
      'referrals': referrals,
      'points': points,
      'contactInfo': contactInfo.toJson(),
      'socialMedia': socialMedia?.toJson(),
      'logo': logo,
      'balance': balance,
      'branches': branches?.map((b) => b.toJson()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ContactInfo {
  final String phone;
  final String? whatsApp;
  final String? website;
  final Address address;

  ContactInfo({
    required this.phone,
    this.whatsApp,
    this.website,
    required this.address,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: json['phone'] ?? '',
      whatsApp: json['whatsapp'],
      website: json['website'],
      address: Address.fromJson(json['address'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'whatsapp': whatsApp,
      'website': website,
      'address': address.toJson(),
    };
  }
}

class SocialMedia {
  final String? facebook;
  final String? instagram;

  SocialMedia({
    this.facebook,
    this.instagram,
  });

  factory SocialMedia.fromJson(Map<String, dynamic> json) {
    return SocialMedia(
      facebook: json['facebook'],
      instagram: json['instagram'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facebook': facebook,
      'instagram': instagram,
    };
  }
}

class Address {
  final String country;
  final String district;
  final String city;
  final String street;
  final String postalCode;
  final double lat;
  final double lng;

  Address({
    required this.country,
    required this.district,
    required this.city,
    required this.street,
    required this.postalCode,
    required this.lat,
    required this.lng,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      country: json['country'] ?? '',
      district: json['district'] ?? '',
      city: json['city'] ?? '',
      street: json['street'] ?? '',
      postalCode: json['postalCode'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'district': district,
      'city': city,
      'street': street,
      'postalCode': postalCode,
      'lat': lat,
      'lng': lng,
    };
  }
}

class Branch {
  final String id;
  final String name;
  final Address location;
  final String phone;
  final String category;
  final String? subCategory;
  final String? description;
  final List<String> images;
  final List<String>? videos;
  final double? costPerCustomer;
  final DateTime createdAt;
  final DateTime updatedAt;

  Branch({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.category,
    this.subCategory,
    this.description,
    required this.images,
    this.videos,
    this.costPerCustomer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      location: Address.fromJson(json['location'] ?? {}),
      phone: json['phone'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'],
      description: json['description'],
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : [],
      videos: json['videos'] != null
          ? List<String>.from(json['videos'])
          : null,
      costPerCustomer: json['costPerCustomer'] != null
          ? (json['costPerCustomer']).toDouble()
          : null,
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
      'name': name,
      'location': location.toJson(),
      'phone': phone,
      'category': category,
      'subCategory': subCategory,
      'description': description,
      'images': images,
      'videos': videos,
      'costPerCustomer': costPerCustomer,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Additional models to match Go backend

class BranchComment {
  final String id;
  final String branchId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String comment;
  final int? rating;
  final List<CommentReply>? replies;
  final DateTime createdAt;
  final DateTime updatedAt;

  BranchComment({
    required this.id,
    required this.branchId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.comment,
    this.rating,
    this.replies,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchComment.fromJson(Map<String, dynamic> json) {
    return BranchComment(
      id: json['id'] ?? '',
      branchId: json['branchId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatar: json['userAvatar'],
      comment: json['comment'] ?? '',
      rating: json['rating'],
      replies: json['replies'] != null
          ? (json['replies'] as List).map((r) => CommentReply.fromJson(r)).toList()
          : null,
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
      'branchId': branchId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'comment': comment,
      'rating': rating,
      'replies': replies?.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CommentReply {
  final String id;
  final String companyId;
  final String reply;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommentReply({
    required this.id,
    required this.companyId,
    required this.reply,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentReply.fromJson(Map<String, dynamic> json) {
    return CommentReply(
      id: json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      reply: json['reply'] ?? '',
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
      'companyId': companyId,
      'reply': reply,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Request/Response classes
class CommentReplyRequest {
  final String reply;

  CommentReplyRequest({required this.reply});

  Map<String, dynamic> toJson() {
    return {
      'reply': reply,
    };
  }
}

class CompanyReferralRequest {
  final String referralCode;

  CompanyReferralRequest({required this.referralCode});

  Map<String, dynamic> toJson() {
    return {
      'referralCode': referralCode,
    };
  }
}

class CompanyReferralResponse {
  final String referrerId;
  final Company referrer;
  final Company newCompany;
  final int pointsAdded;
  final String newReferralCode;

  CompanyReferralResponse({
    required this.referrerId,
    required this.referrer,
    required this.newCompany,
    required this.pointsAdded,
    required this.newReferralCode,
  });

  factory CompanyReferralResponse.fromJson(Map<String, dynamic> json) {
    return CompanyReferralResponse(
      referrerId: json['referrerId'] ?? '',
      referrer: Company.fromJson(json['referrer'] ?? {}),
      newCompany: Company.fromJson(json['newCompany'] ?? {}),
      pointsAdded: json['pointsAdded'] ?? 0,
      newReferralCode: json['newReferralCode'] ?? '',
    );
  }
}

class CompanyReferralData {
  final String referralCode;
  final int referralCount;
  final int points;
  final String referralLink;

  CompanyReferralData({
    required this.referralCode,
    required this.referralCount,
    required this.points,
    required this.referralLink,
  });

  factory CompanyReferralData.fromJson(Map<String, dynamic> json) {
    return CompanyReferralData(
      referralCode: json['referralCode'] ?? '',
      referralCount: json['referralCount'] ?? 0,
      points: json['points'] ?? 0,
      referralLink: json['referralLink'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referralCode': referralCode,
      'referralCount': referralCount,
      'points': points,
      'referralLink': referralLink,
    };
  }
}

// Add this to lib/models/company_model.dart

class CompanySignupData {
  final String businessName;
  final String category;
  final String? subCategory;
  final List<String> phones;
  final List<String> emails;
  final Address address;
  final String? logo;
  final String? referralCode;

  CompanySignupData({
    required this.businessName,
    required this.category,
    this.subCategory,
    required this.phones,
    required this.emails,
    required this.address,
    this.logo,
    this.referralCode,
  });

  factory CompanySignupData.fromJson(Map<String, dynamic> json) {
    return CompanySignupData(
      businessName: json['businessName'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'],
      phones: json['phones'] != null ? List<String>.from(json['phones']) : [],
      emails: json['emails'] != null ? List<String>.from(json['emails']) : [],
      address: Address.fromJson(json['address'] ?? {}),
      logo: json['logo'],
      referralCode: json['referralCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'category': category,
      'subCategory': subCategory,
      'phones': phones,
      'emails': emails,
      'address': address.toJson(),
      'logo': logo,
      'referralCode': referralCode,
    };
  }
}