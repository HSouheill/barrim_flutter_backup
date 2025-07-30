import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/api_service.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import './signup_company3.dart';
import '../responsive_utils.dart'; // Import the responsive utils

class SignupCompany2 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupCompany2({super.key, required this.userData});

  @override
  _SignupCompany2State createState() => _SignupCompany2State();
}

class _SignupCompany2State extends State<SignupCompany2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();

  String? _selectedIndustryType;
  String? _selectedSubCategory;
  File? _selectedImage;

  // Map of industry types to their subcategories
  final Map<String, List<String>> _industrySubcategories = {
    'Hotels': ['Luxury', 'Budget', 'Resort', 'Boutique', 'Business'],
    'Restaurant': ['Fast Food', 'Fine Dining', 'Casual Dining', 'Café', 'Bistro'],
    'Technology': ['Software', 'Hardware', 'IT Services', 'Telecommunications', 'E-commerce'],
    'Shops': ['Retail', 'Department Store', 'Specialty', 'Convenience', 'Online'],
    'Stations': ['Gas', 'Train', 'Bus', 'Electric Charging', 'Metro'],
    'Finance': ['Banking', 'Insurance', 'Investment', 'Accounting', 'Fintech'],
    'Food & Beverage': ['Bakery', 'Beverage', 'Catering', 'Grocery', 'Specialty Food'],
    'Real Estate': ['Residential', 'Commercial', 'Industrial', 'Property Management', 'Development'],
    'Other': ['Education', 'Healthcare', 'Entertainment', 'Transportation', 'Miscellaneous'],
  };

  Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();

  try {
    // Show options for camera or gallery
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 600,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  } catch (e) {
                    print('Error picking image from gallery: $e');
                    if (mounted) {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('Error accessing photo library')),
                      // );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 600,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  } catch (e) {
                    print('Error taking photo: $e');
                    if (mounted) {
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('Error accessing camera')),
                      // );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    print('Error showing image picker: $e');
    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error opening image picker')),
      // );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF05054F).withOpacity(0.77),
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
                SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.20),
                        CustomHeader(currentPageIndex: 2, totalPages: 3, subtitle: 'Company', onBackPressed: () => Navigator.pop(context)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.06),
                          child: Form(  // Add this Form widget
                            key: _formKey,
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                _buildUploadLogo(),
                                SizedBox(height: 20),
                                _buildBusinessNameField(),
                                SizedBox(height: 20),
                                _buildIndustryTypeField(),
                                SizedBox(height: 20),
                                if (_selectedIndustryType != null && _selectedIndustryType != 'Other')
                                  _buildSubCategoryField(),
                                if (_selectedIndustryType != null && _selectedIndustryType != 'Other')
                                  SizedBox(height: 20),
                                if (_selectedIndustryType == 'Other')
                                  _buildCustomCategoryField(),
                                if (_selectedIndustryType == 'Other')
                                  SizedBox(height: 20),
                                _buildReferralField(),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.09),
                                _buildNextButton(constraints),
                                SizedBox(height: 30), // Add bottom padding for scrolling
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadLogo() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: MediaQuery.of(context).size.width * 0.125, // Responsive radius
            backgroundColor: Colors.white,
            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
            child: _selectedImage == null
                ? Icon(Icons.add_a_photo, size: MediaQuery.of(context).size.width * 0.1, color: Colors.grey)
                : null,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Add Logo',
          style: GoogleFonts.nunito(
              fontSize: ResponsiveUtils.getSubtitleFontSize(context),
              color: Colors.white,
              fontWeight: FontWeight.w600
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessNameField() {
    return TextFormField(
      controller: _businessNameController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      decoration: InputDecoration(
        labelText: 'Business Name',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter Business Name';
        }
        return null;
      },
    );
  }

  Widget _buildIndustryTypeField() {
    final industryTypes = _industrySubcategories.keys.toList();

    return DropdownButtonFormField<String>(
      value: _selectedIndustryType,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      dropdownColor: Color(0xFF05054F),
      decoration: InputDecoration(
        labelText: 'Industry Type',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      items: industryTypes
          .map((value) => DropdownMenuItem(
        value: value,
        child: Text(value, style: GoogleFonts.nunito(
          fontSize: ResponsiveUtils.getInputTextFontSize(context),
        )),
      ))
          .toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedIndustryType = newValue;
          // Reset sub-category and custom category when industry type changes
          _selectedSubCategory = null;
          _customCategoryController.clear();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select Industry Type';
        }
        return null;
      },
    );
  }

  Widget _buildSubCategoryField() {
    // Get subcategories based on selected industry type
    final subcategories = _industrySubcategories[_selectedIndustryType] ?? [];

    return DropdownButtonFormField<String>(
      value: _selectedSubCategory,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      dropdownColor: Color(0xFF05054F),
      decoration: InputDecoration(
        labelText: 'Sub Category',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      items: subcategories
          .map((value) => DropdownMenuItem(
        value: value,
        child: Text(value, style: GoogleFonts.nunito(
          fontSize: ResponsiveUtils.getInputTextFontSize(context),
        )),
      ))
          .toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedSubCategory = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select Sub Category';
        }
        return null;
      },
    );
  }

  Widget _buildCustomCategoryField() {
    return TextFormField(
      controller: _customCategoryController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      decoration: InputDecoration(
        labelText: 'Specify Category',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please specify your category';
        }
        return null;
      },
    );
  }

  Widget _buildReferralField() {
    return TextFormField(
      controller: _referralController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      decoration: InputDecoration(
        labelText: 'Referral Code',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }

  Widget _buildNextButton(BoxConstraints constraints) {
    // Calculate responsive button size
    final buttonWidth = constraints.maxWidth * 0.7;
    final buttonHeight = MediaQuery.of(context).size.height * 0.07;

    return Center(
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
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
          borderRadius: BorderRadius.circular(buttonHeight / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(64),
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: ElevatedButton(
          // In signup_company2.dart, modify the onPressed handler for the Next button:
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Create updated user data with the correct nested structure
              final updatedUserData = {
                ...widget.userData,
                'companyInfo': { // Add this nested structure
                  'name': _businessNameController.text,
                  'category': _selectedIndustryType == 'Other'
                      ? _customCategoryController.text
                      : _selectedIndustryType,
                  'subCategory': _selectedIndustryType == 'Other'
                      ? null
                      : _selectedSubCategory,
                  'referralCode': _referralController.text,
                },
                'logo': _selectedImage,
              };

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SignupCompany3(userData: updatedUserData),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonHeight / 2),
            ),
          ),
          child: Text(
            'Next',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: ResponsiveUtils.getButtonFontSize(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _referralController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
}