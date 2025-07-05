import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/company_model.dart'; // Assuming you have an auth model

class CompanyService {
  final String baseUrl;
  final http.Client client;

  CompanyService({required this.baseUrl, required this.client});

  Future<Map<String, dynamic>> signUpCompany({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required CompanySignupData companyData,
    String? dateOfBirth,
    String? gender,
    String? referralCode,
    List<String>? interestedDeals,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/signup');

      final request = SignupRequest(
        email: email,
        password: password,
        fullName: fullName,
        userType: 'company',
        phone: phone,
        dateOfBirth: dateOfBirth,
        gender: gender,
        referralCode: referralCode,
        interestedDeals: interestedDeals,
        companyData: companyData,
      );

      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to sign up: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

}

class SignupRequest {
  final String email;
  final String password;
  final String fullName;
  final String userType;
  final String? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? referralCode;
  final List<String>? interestedDeals;
  final CompanySignupData? companyData;

  SignupRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.userType,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.referralCode,
    this.interestedDeals,
    this.companyData,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'fullName': fullName,
      'userType': userType,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phone': phone,
      'referralCode': referralCode,
      'interestedDeals': interestedDeals,
      'companyData': companyData?.toJson(),
    };
  }
}