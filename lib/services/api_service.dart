import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ad_model.dart';

class ApiService {
  static String baseUrl = 'https://your.backend.api.url'; // TODO: Set your actual API base URL
  static Future<List<Ad>> fetchAds() async {
    final url = Uri.parse('$baseUrl/api/ads');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final adsResponse = AdsResponse.fromJson(data);
      return adsResponse.data;
    } else {
      throw Exception('Failed to load ads');
    }
  }
}
