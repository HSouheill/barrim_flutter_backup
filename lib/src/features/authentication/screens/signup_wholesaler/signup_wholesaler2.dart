import 'dart:convert';

import 'package:barrim/src/features/authentication/screens/signup_wholesaler/signup_wholesaler3.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import '../../../../services/api_service.dart';

class SignupWholesaler2 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupWholesaler2({super.key, required this.userData});

  @override
  _SignupWholesaler2State createState() => _SignupWholesaler2State();
}

class _SignupWholesaler2State extends State<SignupWholesaler2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _referralController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  String? _selectedIndustry;
  String? _selectedSubCategory;
  bool _isLoadingCategories = true;
  String? _categoriesError;

  // Dynamic categories map that will be populated from backend
  Map<String, List<String>> _subCategoriesMap = {};

  String _countryCode = '+961';

  // Avatar controller
  String _avatarText = "";
  Color _avatarBgColor = const Color(0xFFE84949);
  Color _avatarTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Set initial avatar text based on user's name
    if (widget.userData.containsKey('name') && widget.userData['name'].toString().isNotEmpty) {
      final nameParts = widget.userData['name'].toString().split(' ');
      if (nameParts.length > 1) {
        _avatarText = "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
      } else if (nameParts.length == 1) {
        _avatarText = nameParts[0][0].toUpperCase();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });

      print('SignupWholesaler2: Loading wholesaler categories from backend...');
      print('SignupWholesaler2: About to call ApiService.getAllWholesalerCategories()');
      print('=== SIGNUP WHOLESALER2 CALLING WHOLESALER CATEGORIES ===');
      print('SignupWholesaler2: Method signature check - ApiService.getAllWholesalerCategories exists: ${ApiService.getAllWholesalerCategories != null}');
      print('SignupWholesaler2: Method type: ${ApiService.getAllWholesalerCategories.runtimeType}');
      print('SignupWholesaler2: Method name: ${ApiService.getAllWholesalerCategories.toString()}');
      print('SignupWholesaler2: Method signature: ${ApiService.getAllWholesalerCategories.runtimeType.toString()}');
      print('SignupWholesaler2: Method hash code: ${ApiService.getAllWholesalerCategories.hashCode}');
      print('SignupWholesaler2: Method toString: ${ApiService.getAllWholesalerCategories.toString()}');
      print('SignupWholesaler2: Method runtimeType: ${ApiService.getAllWholesalerCategories.runtimeType}');
      print('SignupWholesaler2: Method toString: ${ApiService.getAllWholesalerCategories.toString()}');
      final categories = await ApiService.getAllWholesalerCategories();
      print('=== SIGNUP WHOLESALER2 RECEIVED WHOLESALER CATEGORIES ===');
      print('SignupWholesaler2: Received wholesaler categories: $categories');
      print('SignupWholesaler2: Categories count: ${categories.length}');
      print('SignupWholesaler2: Categories type: ${categories.runtimeType}');
      
      if (mounted) {
        // Check if we received valid categories
        if (categories.isEmpty) {
          setState(() {
            _isLoadingCategories = false;
            _categoriesError = 'No categories available from the server. Please try again later.';
            _subCategoriesMap = {};
          });
          return;
        }
        
        // Validate that categories have the expected structure
        bool hasValidStructure = true;
        for (var entry in categories.entries) {
          if (entry.key.isEmpty || entry.value == null) {
            hasValidStructure = false;
            break;
          }
        }
        
        if (!hasValidStructure) {
          setState(() {
            _isLoadingCategories = false;
            _categoriesError = 'Invalid category data received from server. Please try again later.';
            _subCategoriesMap = {};
          });
          return;
        }
        
        setState(() {
          _subCategoriesMap = categories;
          _isLoadingCategories = false;
          
          // Reset selected industry if it's no longer in the loaded categories
          if (_selectedIndustry != null && !categories.containsKey(_selectedIndustry)) {
            _selectedIndustry = null;
            _selectedSubCategory = null;
          }
        });
        
        print('SignupWholesaler2: Categories loaded successfully. Count: ${categories.length}');
        categories.forEach((category, subcategories) {
          print('SignupWholesaler2: Category "$category" has ${subcategories.length} subcategories: $subcategories');
        });
      }
    } catch (e) {
      print('SignupWholesaler2: Error loading wholesaler categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          
          // Provide more user-friendly error messages
          String errorMessage;
          if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
            errorMessage = 'Network error. Please check your internet connection and try again.';
          } else if (e.toString().contains('TimeoutException')) {
            errorMessage = 'Request timed out. Please try again.';
          } else if (e.toString().contains('HandshakeException')) {
            errorMessage = 'Connection failed. Please check your internet connection and try again.';
          } else if (e.toString().contains('FormatException')) {
            errorMessage = 'Invalid response from server. Please try again.';
          } else {
            errorMessage = 'Failed to load categories: $e';
          }
          
          _categoriesError = errorMessage;
          // No fallback categories - let the UI handle empty state
          _subCategoriesMap = {};
        });
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _referralController.dispose();
    super.dispose();
  }


  // Method to get font sizes based on screen size
  double getTitleFontSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width < 360) return 28; // Small screen
    if (width >= 360 && width < 600) return 40; // Medium screen
    return 38; // Large screen
  }

  double getInputFontSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width < 360) return 16; // Small screen
    if (width >= 360 && width < 600) return 24; // Medium screen
    return 26; // Large screen
  }

  double getButtonFontSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width < 360) return 18; // Small screen
    if (width >= 360 && width < 600) return 22; // Medium screen
    return 26; // Large screen
  }

  double getInputTextFontSize(BoxConstraints constraints) {
    // Input text is 80% of label size in signup_user1
    return getInputFontSize(constraints) * 0.8;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents UI shift when keyboard appears
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Screen size breakpoints
            final isSmallScreen = constraints.maxWidth < 360;
            final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;
            final isLargeScreen = constraints.maxWidth >= 600;

            // Get responsive sizes
            final labelFontSize = getInputFontSize(constraints);
            final inputTextFontSize = getInputTextFontSize(constraints);
            final buttonFontSize = getButtonFontSize(constraints);

            // Adjust padding based on screen size
            final horizontalPadding = constraints.maxWidth * 0.06; // 6% of screen width
            final verticalSpacing = constraints.maxHeight * 0.03; // 3% of screen height

            return Stack(
              children: [
                // Overlay Color
                Container(
                  color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
                ),

                // WhiteHeader
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 180,
                    child: WhiteHeader(
                      title: 'Sign Up',
                      onBackPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Add fixed space between WhiteHeader and progress bar
                Positioned(
                  top: 180,
                  left: 0,
                  right: 0,
                  child: SizedBox(height: 16),
                ),

                // Main Content
                SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.15), // Responsive spacing

                          // Custom Header
                          CustomHeader(
                            currentPageIndex: 2,
                            totalPages: 3,
                            subtitle: 'Wholesaler',
                            onBackPressed: () => Navigator.pop(context),
                          ),

                          // Form
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: verticalSpacing,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    _buildBusinessNameField(labelFontSize, inputTextFontSize),
                                    SizedBox(height: verticalSpacing),

                                    // Category (Industry Type)
                                    _buildIndustryTypeField(labelFontSize, inputTextFontSize),
                                    SizedBox(height: verticalSpacing),

                                    // Show loading indicator for sub-category if categories are loading
                                    if (_isLoadingCategories && _selectedIndustry != null)
                                      _buildSubCategoryLoadingField(labelFontSize, inputTextFontSize),

                                    // Sub-Category (Show only when category is selected and not loading)
                                    if (_selectedIndustry != null && !_isLoadingCategories)
                                      _buildSubCategoryField(labelFontSize, inputTextFontSize),

                                    if (_selectedIndustry != null && !_isLoadingCategories)
                                      SizedBox(height: verticalSpacing),



                                    // Referral Code
                                    _buildReferralField(labelFontSize, inputTextFontSize),

                                    // Spacer that takes remaining space
                                    SizedBox(height: verticalSpacing * 6),

                                    // Next Button - always at bottom
                                    _buildNextButton(constraints, buttonFontSize),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIndustryTypeField(double labelFontSize, double textFontSize) {
    if (_isLoadingCategories) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: GoogleFonts.nunito(
              color: const Color(0xFFDBD5D5),
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading categories...',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: textFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_subCategoriesMap.isEmpty) {
      return DropdownButtonFormField<String>(
        value: _selectedIndustry,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: textFontSize,
        ),
        dropdownColor: const Color(0xFF05054F),
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: GoogleFonts.nunito(
            color: const Color(0xFFDBD5D5),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.0),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.0),
          ),
          contentPadding: const EdgeInsets.only(bottom: 2),
        ),
        items: [], // Empty items list
        onChanged: (String? newValue) {
          setState(() {
            _selectedIndustry = newValue;
            _selectedSubCategory = null;
          });
        },
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 38),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select your business category';
          }
          return null;
        },
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedIndustry,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      dropdownColor: const Color(0xFF05054F),
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFFDBD5D5),
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        contentPadding: const EdgeInsets.only(bottom: 2),
      ),
      items: _subCategoriesMap.keys
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: textFontSize,
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedIndustry = newValue;
          // Reset sub-category when industry changes
          _selectedSubCategory = null;
          
          // Show warning if selected category has no subcategories
          if (newValue != null) {
            final subCategories = _subCategoriesMap[newValue] ?? [];
            if (subCategories.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This category has no sub-categories available.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        });
      },
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 38),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your business category';
        }
        return null;
      },
    );
  }

  Widget _buildSubCategoryField(double labelFontSize, double textFontSize) {
    // Get the list of subcategories for the selected industry
    final subCategories = _subCategoriesMap[_selectedIndustry] ?? [];

    if (subCategories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sub-Category',
            style: GoogleFonts.nunito(
              color: const Color(0xFFDBD5D5),
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No sub-categories available for this category',
              style: GoogleFonts.nunito(
                color: Colors.orange,
                fontSize: textFontSize * 0.9,
              ),
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedSubCategory,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      dropdownColor: const Color(0xFF05054F),
      decoration: InputDecoration(
        labelText: 'Sub-Category',
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFFDBD5D5),
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        contentPadding: const EdgeInsets.only(bottom: 2),
      ),
      items: subCategories.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: textFontSize,
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSubCategory = newValue;
        });
      },
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 38),
      validator: (value) {
        if (value == null || value.isEmpty) {
          // Only require sub-category if subcategories are available
          if (subCategories.isNotEmpty) {
            return 'Please select a sub-category';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSubCategoryLoadingField(double labelFontSize, double textFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sub-Category',
          style: GoogleFonts.nunito(
            color: const Color(0xFFDBD5D5),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Loading sub-categories...',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: textFontSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferralField(double labelFontSize, double textFontSize) {
    return TextFormField(
      controller: _referralController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      decoration: InputDecoration(
        labelText: 'Referral Code',
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFFDBD5D5),
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        contentPadding: const EdgeInsets.only(bottom: 2),
      ),
      // Optional field, no validator
    );
  }

  Widget _buildBusinessNameField(double labelFontSize, double textFontSize) {
    return TextFormField(
      controller: _businessNameController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      decoration: InputDecoration(
        labelText: 'Business Name',
        labelStyle: GoogleFonts.nunito(
          color: const Color(0xFFDBD5D5),
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.0),
        ),
        contentPadding: const EdgeInsets.only(bottom: 2),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your business name';
        }
        return null;
      },
    );
  }



  Widget _buildNextButton(BoxConstraints constraints, double fontSize) {
    return Center(
      child: Container(
        width: constraints.maxWidth * 0.7,
        height: constraints.maxHeight * 0.07,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0094FF),
              Color(0xFF05055A),
              Color(0xFF0094FF),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(64),
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoadingCategories ? null : () {
            // Don't proceed if categories are still loading
            if (_isLoadingCategories) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please wait while categories are loading...'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // Don't proceed if no categories are available
            if (_subCategoriesMap.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No categories available. Please try again later.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Don't proceed if no category is selected
            if (_selectedIndustry == null || _selectedIndustry!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select a business category.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Don't proceed if business name is empty
            if (_businessNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter your business name.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Don't proceed if business name is too short
            if (_businessNameController.text.trim().length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Business name must be at least 2 characters long.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Don't proceed if business name contains only special characters
            final businessName = _businessNameController.text.trim();
            if (businessName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Business name must contain letters or numbers.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Don't proceed if business name is too long
            if (businessName.length > 100) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Business name must be less than 100 characters long.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Validate referral code format if provided
            final referralCode = _referralController.text.trim();
            if (referralCode.isNotEmpty) {
              if (referralCode.length < 3 || referralCode.length > 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Referral code must be between 3 and 20 characters long.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(referralCode)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Referral code can only contain letters, numbers, hyphens, and underscores.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            }

            if (_formKey.currentState!.validate()) {
              // Additional validation for sub-category if subcategories exist
              if (_selectedIndustry != null) {
                final subCategories = _subCategoriesMap[_selectedIndustry] ?? [];
                if (subCategories.isNotEmpty && (_selectedSubCategory == null || _selectedSubCategory!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please select a sub-category'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                  }
              }

              final updatedUserData = {...widget.userData};
              
              // Add business information
              updatedUserData['business_name'] = _businessNameController.text.trim();
              updatedUserData['category'] = _selectedIndustry ?? "Wholesale";
              updatedUserData['sub_category'] = _selectedSubCategory;
              updatedUserData['referralCode'] = _referralController.text.trim();

              // Add contact information
              updatedUserData['additionalEmails'] = widget.userData['additionalEmails'] ?? [];
              updatedUserData['additionalPhones'] = widget.userData['additionalPhones'] ?? [];

              // Add contact info object
              updatedUserData['contactInfo'] = {
                'whatsapp': widget.userData['phone'] ?? '',
                'website': '',
                'facebook': '',
              };

              // Add social media object
              updatedUserData['socialMedia'] = {
                'facebook': '',
                'instagram': '',
              };

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignupWholesaler3(userData: updatedUserData)),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            _isLoadingCategories ? 'Loading...' : 'Next',
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}