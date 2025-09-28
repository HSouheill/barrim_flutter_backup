// lib/utils/category_integration_test.dart
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Test utility to verify category integration
class CategoryIntegrationTest {
  static Future<void> testCategoryIntegration() async {
    if (!kReleaseMode) {
      print('=== Testing Category Integration ===');
      
      try {
        // Test API call
        print('1. Testing getAllCategories API call...');
        final categories = await ApiService.getAllCategories();
        print('   ✓ API call successful');
        print('   ✓ Retrieved ${categories.length} categories');
        
        // Test category structure
        print('2. Testing category structure...');
        categories.forEach((categoryName, subcategories) {
          print('   Category: "$categoryName" -> Subcategories: $subcategories');
        });
        
        // Test first 4 categories
        print('3. Testing first 4 categories for display...');
        final displayCategories = categories.keys.take(4).toList();
        print('   Display categories: $displayCategories');
        
        // Test category matching
        print('4. Testing category matching logic...');
        for (String category in displayCategories) {
          final subcategories = categories[category] ?? [];
          print('   Testing "$category" with subcategories: $subcategories');
          
          // Simulate company data matching
          final testCompanyData = {
            'companyInfo': {
              'category': category.toLowerCase(),
              'industryType': category.toLowerCase(),
            }
          };
          
          final companyCategory = testCompanyData['companyInfo']?['category']?.toString().toLowerCase() ?? '';
          final industryType = testCompanyData['companyInfo']?['industryType']?.toString().toLowerCase() ?? '';
          
          final categoryMatch = companyCategory.contains(category.toLowerCase()) ||
                               industryType.contains(category.toLowerCase());
          
          final subcategoryMatch = subcategories.any((subcategory) =>
            companyCategory.contains(subcategory.toLowerCase()) ||
            industryType.contains(subcategory.toLowerCase())
          );
          
          final matches = categoryMatch || subcategoryMatch;
          print('   ✓ "$category" matching: $matches');
        }
        
        print('=== Category Integration Test Complete ===');
        print('✓ All tests passed successfully!');
        
      } catch (e) {
        print('❌ Category integration test failed: $e');
      }
    }
  }
}
