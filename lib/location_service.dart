import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocationService {
  static Future<Map<String, dynamic>> loadCountriesData() async {
    // Load the JSON file as a string
    String jsonString = await rootBundle.loadString('assets/countries_districts_cities.json');

    // Decode the JSON string into a Dart Map
    Map<String, dynamic> jsonData = json.decode(jsonString);

    return jsonData;
  }
}
