// models/wholesaler_model.dart
import 'dart:convert';

class Wholesaler {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String businessName;
  final String phone;
  final List<String> additionalPhones;
  final List<String> additionalEmails;
  final String category;
  final String? subCategory;
  final String? referralCode;
  final List<String> referrals;
  final int points;
  final ContactInfo contactInfo;
  final SocialMedia socialMedia;
  final String? logoUrl;
  final double balance;
  final List<Branch> branches;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Address? address;

  Wholesaler({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.businessName,
    required this.phone,
    this.additionalPhones = const [],
    this.additionalEmails = const [],
    required this.category,
    this.subCategory,
    this.referralCode,
    this.referrals = const [],
    this.points = 0,
    required this.contactInfo,
    required this.socialMedia,
    this.logoUrl,
    this.balance = 0.0,
    this.branches = const [],
    required this.createdAt,
    required this.updatedAt,
    this.address,
  });

  factory Wholesaler.fromJson(Map<String, dynamic> json) {
    // Extract address from contactInfo if it exists
    Address? address;
    if (json['contactInfo'] != null && json['contactInfo']['address'] != null) {
      address = Address.fromJson(json['contactInfo']['address']);
    }

    return Wholesaler(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      businessName: json['businessName'] ?? '',
      phone: json['phone'] ?? '',
      additionalPhones: json['additionalPhones'] != null
          ? List<String>.from(json['additionalPhones'])
          : [],
      additionalEmails: json['additionalEmails'] != null
          ? List<String>.from(json['additionalEmails'])
          : [],
      category: json['category'] ?? '',
      subCategory: json['subCategory'],
      referralCode: json['referralCode'],
      referrals: json['referrals'] != null
          ? List<String>.from(json['referrals'])
          : [],
      points: json['points'] ?? 0,
      contactInfo: json['contactInfo'] != null
          ? ContactInfo.fromJson(json['contactInfo'])
          : ContactInfo(whatsApp: '', website: '', facebook: ''),
      socialMedia: json['socialMedia'] != null
          ? SocialMedia.fromJson(json['socialMedia'])
          : SocialMedia(),
      logoUrl: json['logoUrl'],
      balance: json['balance']?.toDouble() ?? 0.0,
      branches: json['branches'] != null
          ? List<Branch>.from(json['branches'].map((x) => Branch.fromJson(x)))
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      address: address,
    );
  }

  // For simplified wholesaler info from GetWholesalerData response
  factory Wholesaler.fromInfoJson(Map<String, dynamic> json) {
    return Wholesaler(
      id: '', // Not provided in the simplified info
      userId: '', // Not provided in the simplified info
      name: '', // Not provided in the simplified info
      email: '', // Not provided in the simplified info
      businessName: json['name'] ?? '',
      phone: '', // Not provided in the simplified info
      category: json['category'] ?? '',
      subCategory: json['subCategory'],
      logoUrl: json['logo'],
      contactInfo: json['contactInfo'] != null
          ? ContactInfo.fromJson(json['contactInfo'])
          : ContactInfo(whatsApp: '', website: '', facebook: ''),
      socialMedia: json['socialMedia'] != null
          ? SocialMedia.fromJson(json['socialMedia'])
          : SocialMedia(),
      createdAt: DateTime.now(), // Not provided in the simplified info
      updatedAt: DateTime.now(), // Not provided in the simplified info
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'businessName': businessName,
      'phone': phone,
      'additionalPhones': additionalPhones,
      'additionalEmails': additionalEmails,
      'category': category,
      'subCategory': subCategory,
      'referralCode': referralCode,
      'referrals': referrals,
      'points': points,
      'contactInfo': contactInfo.toJson(),
      'socialMedia': socialMedia.toJson(),
      'logoUrl': logoUrl,
      'balance': balance,
      'branches': branches.map((branch) => branch.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'address': address?.toJson(),
    };
  }
}

class ContactInfo {
  final String whatsApp;
  final String website;
  final String? facebook;

  ContactInfo({
    required this.whatsApp,
    required this.website,
    required this.facebook,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      whatsApp: json['whatsapp'] ?? '',
      website: json['website'] ?? '',
      facebook: json['facebook'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'whatsapp': whatsApp,
      'website': website,
      'facebook': facebook,
    };
  }
}

class SocialMedia {
  final String facebook;
  final String instagram;

  SocialMedia({
    this.facebook = '',
    this.instagram = '',
  });

  factory SocialMedia.fromJson(Map<String, dynamic> json) {
    return SocialMedia(
      facebook: json['facebook'] ?? '',
      instagram: json['instagram'] ?? '',
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
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      country: json['country'] ?? '',
      district: json['district'] ?? '',
      city: json['city'] ?? '',
      street: json['street'] ?? '',
      postalCode: json['postalCode'] ?? '',
      lat: json['lat']?.toDouble() ?? 0.0,
      lng: json['lng']?.toDouble() ?? 0.0,
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
  final String description;
  final List<String> images;
  final List<String> videos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  Branch({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.category,
    this.subCategory,
    required this.description,
    this.images = const [],
    this.videos = const [],
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] != null
          ? Address.fromJson(json['location'])
          : Address(
        country: '',
        district: '',
        city: '',
        street: '',
        postalCode: '',
        lat: json['lat']?.toDouble() ?? 0.0,
        lng: json['lng']?.toDouble() ?? 0.0,
      ),
      phone: json['phone'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'],
      description: json['description'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      videos: json['videos'] != null ? List<String>.from(json['videos']) : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      status: json['status'] ?? 'active',
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
    };
  }
}

class WholesalerSignupData {
  final String businessName;
  final String category;
  final String? subCategory;
  final List<String> phones;
  final List<String> emails;
  final Address address;
  final String? referralCode;
  final SocialMedia? socialMedia;
  final ContactInfo? contactInfo;

  WholesalerSignupData({
    required this.businessName,
    required this.category,
    this.subCategory,
    required this.phones,
    required this.emails,
    required this.address,
    this.referralCode,
    this.socialMedia,
    this.contactInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'category': category,
      'subCategory': subCategory,
      'phones': phones,
      'emails': emails,
      'address': address.toJson(),
      'referralCode': referralCode,
      'socialMedia': socialMedia?.toJson(),
      'contactInfo': contactInfo?.toJson(),
    };
  }
}

class WholesalerReferralData {
  final String referralCode;
  final int referralCount;
  final int points;
  final String referralLink;
  final String? qrCode;

  WholesalerReferralData({
    required this.referralCode,
    required this.referralCount,
    required this.points,
    required this.referralLink,
    required this.qrCode,
  });

  factory WholesalerReferralData.fromJson(Map<String, dynamic> json) {
    return WholesalerReferralData(
      referralCode: json['referralCode'] ?? '',
      referralCount: json['referralCount'] ?? 0,
      points: json['points'] ?? 0,
      referralLink: json['referralLink'] ?? '',
      qrCode: json['qrCode'],
    );
  }
}

class ApiResponse {
  final int status;
  final String message;
  final dynamic data;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}