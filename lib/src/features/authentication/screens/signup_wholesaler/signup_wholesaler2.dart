import 'dart:convert';

import 'package:barrim/src/features/authentication/screens/signup_wholesaler/signup_wholesaler3.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../custom_header.dart';
import '../white_headr.dart';

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

  // Map to store subcategories for each industry type
  final Map<String, List<String>> _subCategoriesMap = {
    'Food & Beverage': [
      'Fresh Produce',
      'Dairy Products',
      'Meat & Poultry',
      'Seafood',
      'Bakery Items',
      'Beverages',
      'Frozen Foods',
      'Canned Goods',
      'Spices & Condiments',
      'Snacks & Confectionery'
    ],
    'Electronics': [
      'Consumer Electronics',
      'Computer Hardware',
      'Mobile Devices',
      'Audio Equipment',
      'TV & Video',
      'Gaming Consoles',
      'Accessories',
      'Office Equipment'
    ],
    'Textiles & Clothing': [
      'Men\'s Apparel',
      'Women\'s Apparel',
      'Children\'s Clothing',
      'Footwear',
      'Accessories',
      'Fabrics',
      'Home Textiles',
      'Sportswear'
    ],
    'Construction & Building': [
      'Building Materials',
      'Plumbing Supplies',
      'Electrical Equipment',
      'Tools & Hardware',
      'Paint & Coatings',
      'Flooring Materials',
      'Roofing Materials',
      'Safety Equipment'
    ],
    'Automotive': [
      'Auto Parts',
      'Tires & Wheels',
      'Lubricants',
      'Tools & Equipment',
      'Accessories',
      'Batteries',
      'Filters',
      'Body Parts'
    ],
    'Health & Beauty': [
      'Cosmetics',
      'Personal Care',
      'Hair Products',
      'Skin Care',
      'Fragrances',
      'Health Supplements',
      'Medical Supplies',
      'Beauty Tools'
    ],
    'Home & Garden': [
      'Furniture',
      'Home Decor',
      'Kitchenware',
      'Garden Supplies',
      'Lighting',
      'Cleaning Supplies',
      'Storage Solutions',
      'Outdoor Living'
    ],
    'Industrial & Manufacturing': [
      'Raw Materials',
      'Industrial Tools',
      'Machinery Parts',
      'Safety Equipment',
      'Packaging Materials',
      'Chemical Supplies',
      'Industrial Electronics',
      'Maintenance Supplies'
    ],
    'Office & Stationery': [
      'Paper Products',
      'Writing Instruments',
      'Office Furniture',
      'Filing Systems',
      'Art Supplies',
      'School Supplies',
      'Desk Accessories',
      'Presentation Materials'
    ],
    'Sports & Recreation': [
      'Sports Equipment',
      'Fitness Gear',
      'Outdoor Recreation',
      'Team Sports',
      'Exercise Equipment',
      'Sports Apparel',
      'Camping Gear',
      'Water Sports'
    ]
  };

  String _countryCode = '+961';

  // Avatar controller
  String _avatarText = "";
  Color _avatarBgColor = const Color(0xFFE84949);
  Color _avatarTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
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

                                    // Sub-Category (Show only when category is selected)
                                    if (_selectedIndustry != null)
                                      _buildSubCategoryField(labelFontSize, inputTextFontSize),

                                    if (_selectedIndustry != null)
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
          return 'Please select a sub-category';
        }
        return null;
      },
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
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
            'Next',
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