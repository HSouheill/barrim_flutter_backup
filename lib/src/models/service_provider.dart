// models/service_provider.dart
import 'package:flutter/material.dart';

class ServiceProvider {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final ServiceProviderInfo? serviceProviderInfo;
  final String? logoPath;
  final Location? location;
  final double? rating;
  final int? reviewCount;
  final List<String>? availableWeekdays;
  final List<String>? availableDays;
  final String? category; // Add category field


  ServiceProvider({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.serviceProviderInfo,
    this.logoPath,
    this.location,
    this.rating,
    this.reviewCount,
    this.availableWeekdays,
    this.availableDays,
    this.category, // Add category parameter
  });


  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    try {
      return ServiceProvider(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        serviceProviderInfo: json['serviceProviderInfo'] != null
            ? ServiceProviderInfo.fromJson(json['serviceProviderInfo'])
            : null,
        logoPath: json['logoPath']?.toString(),
        location: json['location'] != null
            ? Location.fromJson(json['location'])
            : null,
        rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : null,
        reviewCount: json['reviewCount'] != null ? int.tryParse(json['reviewCount'].toString()) : null,
        availableWeekdays: json['availableWeekdays'] != null
            ? List<String>.from(json['availableWeekdays'])
            : null,
        availableDays: json['availableDays'] != null
            ? List<String>.from(json['availableDays'])
            : null,
        category: json['category']?.toString(), // Parse category field
      );
    } catch (e) {
      debugPrint('Error parsing ServiceProvider from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'serviceProviderInfo': serviceProviderInfo?.toJson(),
      'logoPath': logoPath,
      'location': location?.toJson(),
      'rating': rating,
      'reviewCount': reviewCount,
      'availableWeekdays': availableWeekdays,
      'availableDays': availableDays,
      'category': category, // Include category field
    };
  }
}

class ServiceProviderInfo {
  final String serviceType;
  final String? customServiceType;
  final int yearsExperience;
  final List<String>? availableHours;
  final List<String>? availableDays;
  final String? profilePhoto;
  final String? description;
  final String? certificateImage;
  final String? status;
  final Map<String, String>? socialLinks;


  ServiceProviderInfo({
    required this.serviceType,
    this.customServiceType,
    required this.yearsExperience,
    this.availableHours,
    this.availableDays,
    this.profilePhoto,
    this.description,
    this.certificateImage,
    this.status,
    this.socialLinks,
  });

  factory ServiceProviderInfo.fromJson(Map<String, dynamic> json) {
    try {
      // Handle yearsExperience which could be int or String
      int years = 0;
      if (json['yearsExperience'] is int) {
        years = json['yearsExperience'];
      } else if (json['yearsExperience'] is String) {
        years = int.tryParse(json['yearsExperience']) ?? 0;
      }

      // Handle description which could be null
      String? description = json['description'] ?? '';
      // Handle availableHours and availableDays which could be lists of strings
      List<String> hours = [];
      if (json['availableHours'] != null) {
        hours = List<String>.from(json['availableHours']);
      }

      List<String> days = [];
      if (json['availableDays'] != null) {
        days = List<String>.from(json['availableDays']);
      }

      // Parse socialLinks if present
      Map<String, String>? socialLinks;
      if (json['socialLinks'] != null && json['socialLinks'] is Map) {
        socialLinks = Map<String, String>.from(json['socialLinks']);
      }

      return ServiceProviderInfo(
        serviceType: json['serviceType']?.toString() ?? '',
        customServiceType: json['customServiceType']?.toString(),
        yearsExperience: years,
        availableHours: hours,
        availableDays: days,
        profilePhoto: json['profilePhoto']?.toString(),
        description: description,
        certificateImage: json['certificateImage']?.toString(),
        status: json['status']?.toString(),
        socialLinks: socialLinks,
      );
    } catch (e) {
      debugPrint('Error parsing ServiceProviderInfo from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceType': serviceType,
      'customServiceType': customServiceType,
      'yearsExperience': yearsExperience,
      'availableHours': availableHours,
      'availableDays': availableDays,
      'profilePhoto': profilePhoto,
      'description': description,
      'certificateImage': certificateImage,
      'status': status,
      if (socialLinks != null) 'socialLinks': socialLinks,
    };
  }
}

class Location {
  final String? city;
  final String? country;
  final String? district;
  final String? street;
  final String? postalCode;
  final double? lat;
  final double? lng;
  final bool? allowed;

  Location({
    this.city,
    this.country,
    this.district,
    this.street,
    this.postalCode,
    this.lat,
    this.lng,
    this.allowed,
  });



  factory Location.fromJson(Map<String, dynamic> json) {
    try {
      return Location(
        city: json['city']?.toString(),
        country: json['country']?.toString(),
        district: json['district']?.toString(),
        street: json['street']?.toString(),
        postalCode: json['postalCode']?.toString(),
        lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
        lng: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
        allowed: json['allowed'] as bool?,
      );
    } catch (e) {
      debugPrint('Error parsing Location from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'country': country,
      'district': district,
      'street': street,
      'postalCode': postalCode,
      'lat': lat,
      'lng': lng,
      'allowed': allowed,
    };
  }
}