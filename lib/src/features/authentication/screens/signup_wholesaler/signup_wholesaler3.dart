import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../services/api_service.dart';
import '../custom_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../login_page.dart';
import '../welcome_page.dart';
import '../../../../data/lebanon_locations.dart';
import '../verification_code.dart';
import 'package:barrim/src/features/authentication/screens/white_headr.dart';


class SignupWholesaler3 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupWholesaler3({super.key, required this.userData});

  @override
  State<SignupWholesaler3> createState() => _SignupWholesaler3State();
}

class _SignupWholesaler3State extends State<SignupWholesaler3> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  List<String> _availableCities = [];

  void _submitWholesaler(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Please agree to the Terms of Service")),
      // );
      return;
    }

    // Validate all required wholesaler fields
    if (widget.userData['business_name'] == null || widget.userData['business_name'].isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Business name is required")),
      // );
      return;
    }

    if (widget.userData['category'] == null || widget.userData['category'].isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Category is required")),
      // );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Format phone number if needed
      String phone = widget.userData['phone'].toString();
      if (!phone.startsWith('+')) {
        phone = '+961${phone.startsWith('0') ? phone.substring(1) : phone}';
      }

      // Prepare phones array - include main phone and any additional phones
      List<String> phones = [phone];
      if (widget.userData['additionalPhones'] != null) {
        List<String> additionalPhones = List<String>.from(widget.userData['additionalPhones']);
        // Format additional phones
        additionalPhones = additionalPhones.map((p) {
          if (!p.startsWith('+')) {
            return '+961${p.startsWith('0') ? p.substring(1) : p}';
          }
          return p;
        }).toList();
        phones.addAll(additionalPhones);
      }

      // Prepare emails array - include main email and any additional emails
      List<String> emails = [widget.userData['email']];
      if (widget.userData['additionalEmails'] != null) {
        List<String> additionalEmails = List<String>.from(widget.userData['additionalEmails']);
        emails.addAll(additionalEmails);
      }

      final Map<String, dynamic> requestData = {
        "email": widget.userData['email'],
        "password": widget.userData['password'],
        "fullName": widget.userData['fullName'],
        "userType": "wholesaler",
        "phone": phone,
        "location": {
          "country": _countryController.text.isNotEmpty ? _countryController.text : "Unknown",
          "district": _districtController.text.isNotEmpty ? _districtController.text : "Unknown",
          "city": _cityController.text.isNotEmpty ? _cityController.text : "Unknown",
          "street": _streetController.text.isNotEmpty ? _streetController.text : "Unknown",
          "postalCode": _postalCodeController.text.isNotEmpty ? _postalCodeController.text : "00000",
          "coordinates": {
            "lat": _latitude ?? 0.0,
            "lng": _longitude ?? 0.0
          },
          "allowed": true
        },
        "wholesalerInfo": {
          "businessName": widget.userData['business_name'],
          "category": widget.userData['category'],
          "subCategory": widget.userData['sub_category'] ?? '',
          "phones": phones,
          "emails": emails,
          "address": {
            "country": _countryController.text.isNotEmpty ? _countryController.text : "Unknown",
            "district": _districtController.text.isNotEmpty ? _districtController.text : "Unknown",
            "city": _cityController.text.isNotEmpty ? _cityController.text : "Unknown",
            "street": _streetController.text.isNotEmpty ? _streetController.text : "Unknown",
            "postalCode": _postalCodeController.text.isNotEmpty ? _postalCodeController.text : "00000",
            "lat": _latitude ?? 0.0,
            "lng": _longitude ?? 0.0
          },
          "referralCode": widget.userData['referralCode'] ?? '',
          "socialMedia": widget.userData['socialMedia'] != null ? {
            "facebook": widget.userData['socialMedia']['facebook'] ?? '',
            "instagram": widget.userData['socialMedia']['instagram'] ?? '',
          } : null,
          "contactInfo": widget.userData['contactInfo'] != null ? {
            "whatsapp": widget.userData['contactInfo']['whatsapp'] ?? '',
            "website": widget.userData['contactInfo']['website'] ?? '',
            "facebook": widget.userData['contactInfo']['facebook'] ?? '',
          } : null,
        }
      };

      // Detailed logging of the request data
      print("\n========== WHOLESALER SIGNUP REQUEST DATA ==========");
      print("Basic Info:");
      print("Email: ${requestData['email']}");
      print("Full Name: ${requestData['fullName']}");
      print("Phone: ${requestData['phone']}");
      print("User Type: ${requestData['userType']}");
      
      print("\nLocation Info:");
      print("Country: ${requestData['location']['country']}");
      print("District: ${requestData['location']['district']}");
      print("City: ${requestData['location']['city']}");
      print("Street: ${requestData['location']['street']}");
      print("Postal Code: ${requestData['location']['postalCode']}");
      print("Coordinates: ${requestData['location']['coordinates']}");
      
      print("\nWholesaler Info:");
      print("Business Name: ${requestData['wholesalerInfo']['businessName']}");
      print("Category: ${requestData['wholesalerInfo']['category']}");
      print("Sub Category: ${requestData['wholesalerInfo']['subCategory']}");
      print("Phones: ${requestData['wholesalerInfo']['phones']}");
      print("Emails: ${requestData['wholesalerInfo']['emails']}");
      
      print("\nWholesaler Address:");
      print("Country: ${requestData['wholesalerInfo']['address']['country']}");
      print("District: ${requestData['wholesalerInfo']['address']['district']}");
      print("City: ${requestData['wholesalerInfo']['address']['city']}");
      print("Street: ${requestData['wholesalerInfo']['address']['street']}");
      print("Postal Code: ${requestData['wholesalerInfo']['address']['postalCode']}");
      print("Coordinates: lat=${requestData['wholesalerInfo']['address']['lat']}, lng=${requestData['wholesalerInfo']['address']['lng']}");
      
      if (requestData['wholesalerInfo']['socialMedia'] != null) {
        print("\nSocial Media:");
        print("Facebook: ${requestData['wholesalerInfo']['socialMedia']['facebook']}");
        print("Instagram: ${requestData['wholesalerInfo']['socialMedia']['instagram']}");
      }
      
      if (requestData['wholesalerInfo']['contactInfo'] != null) {
        print("\nContact Info:");
        print("WhatsApp: ${requestData['wholesalerInfo']['contactInfo']['whatsapp']}");
        print("Website: ${requestData['wholesalerInfo']['contactInfo']['website']}");
        print("Facebook: ${requestData['wholesalerInfo']['contactInfo']['facebook']}");
      }
      
      print("\nRaw JSON Request:");
      print(jsonEncode(requestData));
      print("===============================================\n");

      final response = await ApiService.signupWholesaler(requestData);
      print("API Response: $response"); // Debug the API response

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Check for success in various possible response formats
      bool isSuccess = false;
      String? phoneNumber;
      bool needsVerification = false;

      if (response is Map<String, dynamic>) {
        // Check different possible success indicators
        isSuccess = response['success'] == true || 
                   response['status'] == 200 || 
                   response['status'] == 201 ||
                   response['message']?.toString().contains('success') == true;
        
        phoneNumber = response['phone'] ?? phone;
        needsVerification = response['needsVerification'] == true || 
                          response['message']?.toString().contains('OTP') == true;
      }

      if (isSuccess) {
        // Navigate to OTP verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              phoneNumber: phoneNumber ?? phone,
              onVerificationSuccess: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomePage()),
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        // Show error message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response['message'] ?? 'Signup Failed'),
        //     backgroundColor: Colors.red,
        //     duration: const Duration(seconds: 5),
        //   ),
        // );
      }
    } catch (e) {
      // Close loading dialog if it's still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print("Signup Error: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text("Signup Failed: ${e.toString().replaceAll('Exception: ', '')}"),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 5),
      //   ),
      // );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Location permissions are denied')),
          // );
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Location permissions are permanently denied, please enable them in settings'),
        //   ),
        // );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _countryController.text = place.country ?? '';
          _districtController.text = place.administrativeArea ?? '';
          _cityController.text = place.locality ?? '';
          _streetController.text = place.street ?? '';
          _postalCodeController.text = place.postalCode ?? '';
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error getting location: $e')),
      // );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _handleFieldTap(String field) {
    // If fields are empty, auto-fill location when user taps on them
    if (_countryController.text.isEmpty &&
        _districtController.text.isEmpty &&
        _cityController.text.isEmpty &&
        _streetController.text.isEmpty &&
        _postalCodeController.text.isEmpty) {
      _getCurrentLocation();
    }
  }

  void _showCountryPicker() {
    final constraints = MediaQuery.of(context).size;
    final fontSize = constraints.width < 360.0 ? 16.0 : (constraints.width >= 360.0 && constraints.width < 600.0 ? 22.0 : 26.0);
    
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(8.0),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          labelStyle: GoogleFonts.nunito(
            color: Colors.white70,
            fontSize: fontSize,
          ),
          hintStyle: GoogleFonts.nunito(
            color: Colors.white54,
            fontSize: fontSize,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF05054F),
        ),
        backgroundColor: const Color(0xFF05054F),
        textStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: fontSize,
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _countryController.text = country.name;
          // Reset district and city when country changes
          _districtController.clear();
          _cityController.clear();
          _availableCities = [];
        });
      },
    );
  }

  void _showDistrictPicker() {
    final constraints = MediaQuery.of(context).size;
    final fontSize = constraints.width < 360.0 ? 16.0 : (constraints.width >= 360.0 && constraints.width < 600.0 ? 22.0 : 26.0);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select Government',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: fontSize,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lebanonDistricts.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    lebanonDistricts[index].name,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: fontSize * 0.9,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _districtController.text = lebanonDistricts[index].name;
                      _availableCities = lebanonDistricts[index].cities;
                      _cityController.clear();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCityPicker() {
    if (_availableCities.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Please select a district first'),
      //   ),
      // );
      return;
    }

    final constraints = MediaQuery.of(context).size;
    final fontSize = constraints.width < 360.0 ? 16.0 : (constraints.width >= 360.0 && constraints.width < 600.0 ? 22.0 : 26.0);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select City',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: fontSize,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableCities.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _availableCities[index],
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: fontSize * 0.9,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _cityController.text = _availableCities[index];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Screen size breakpoints
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;

        // Responsive font sizes
        double getTitleFontSize() {
          if (isSmallScreen) return 28;
          if (isMediumScreen) return 40;
          return 38;
        }

        double getInputFontSize(Size size) {
          if (size.width < 360) return 16;
          if (size.width >= 360 && size.width < 600) return 22;
          return 26;
        }

        double getButtonFontSize() {
          if (isSmallScreen) return 18;
          if (isMediumScreen) return 22;
          return 26;
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/background.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Dark Overlay
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
                    ),
                  ),

                  // White Top Area with Sign Up header
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 180,
                      child: WhiteHeader(
                        title: 'Sign Up',
                        onBackPressed: () => Navigator.of(context).pop(),
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

                  // Custom Header with Progress Bar
                  Positioned(
                    top: constraints.maxHeight * 0.20,
                    left: 0,
                    right: 0,
                    child: CustomHeader(
                      currentPageIndex: 2, // Assuming this is page 2 of 4
                      totalPages: 4,
                      subtitle: 'Wholesaler',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Address Form
                  Positioned(
                    left: 24,
                    right: 24,
                    top: constraints.maxHeight * 0.25,
                    bottom: 0,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: GestureDetector(
                              onTap: _getCurrentLocation,
                              child: Container(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: getInputFontSize(MediaQuery.of(context).size) * 0.8,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Auto-pin location',
                                      style: GoogleFonts.nunito(
                                        fontSize: getInputFontSize(MediaQuery.of(context).size) * 0.7,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Country Dropdown
                          GestureDetector(
                            onTap: () => _handleFieldTap('country'),
                            child: buildDropdownField(
                              labelText: 'Country',
                              controller: _countryController,
                              fontSize: getInputFontSize(MediaQuery.of(context).size),
                              readOnly: _isLoadingLocation,
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // District Dropdown
                          GestureDetector(
                            onTap: () => _handleFieldTap('district'),
                            child: buildDropdownField(
                              labelText: 'Government',
                              controller: _districtController,
                              fontSize: getInputFontSize(MediaQuery.of(context).size),
                              readOnly: _isLoadingLocation,
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // City Dropdown
                          GestureDetector(
                            onTap: () => _handleFieldTap('city'),
                            child: buildDropdownField(
                              labelText: 'City',
                              controller: _cityController,
                              fontSize: getInputFontSize(MediaQuery.of(context).size),
                              readOnly: _isLoadingLocation,
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Street and Postal Code (Row)
                          Row(
                            children: [
                              // Street Field
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: () => _handleFieldTap('street'),
                                  child: buildTextField(
                                    labelText: 'Street',
                                    controller: _streetController,
                                    fontSize: getInputFontSize(MediaQuery.of(context).size),
                                    readOnly: _isLoadingLocation,
                                  ),
                                ),
                              ),
                              SizedBox(width: constraints.maxWidth * 0.04),
                              // Postal Code Field
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: () => _handleFieldTap('postalCode'),
                                  child: buildTextField(
                                    labelText: 'Postal Code',
                                    controller: _postalCodeController,
                                    fontSize: getInputFontSize(MediaQuery.of(context).size),
                                    readOnly: _isLoadingLocation,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Terms and Conditions Checkbox
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreeToTerms,
                                  onChanged: (value) {
                                    setState(() {
                                      _agreeToTerms = value ?? false;
                                    });
                                  },
                                  fillColor: MaterialStateProperty.resolveWith((states) => Colors.white),
                                  checkColor: const Color(0xFF05054F),
                                  side: const BorderSide(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.nunito(
                                      fontSize: getInputFontSize(MediaQuery.of(context).size) * 0.7,
                                      color: Colors.white,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  backgroundColor: const Color(0xFF05054F),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Text(
                                                    'Terms of Service & Privacy Policy',
                                                    style: GoogleFonts.nunito(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  content: SingleChildScrollView(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Terms of Service',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '1. You must provide accurate and complete information during registration.\n'
                                                          '2. You are responsible for maintaining the confidentiality of your account.\n'
                                                          '3. You agree not to use the app for any unlawful or prohibited activities.\n'
                                                          '4. We reserve the right to suspend or terminate accounts that violate our terms.\n'
                                                          '5. The app and its content are provided as-is without warranties of any kind.',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white70,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Text(
                                                          'Privacy Policy',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '1. We collect personal information to provide and improve our services.\n'
                                                          '2. Your data will not be shared with third parties except as required by law.\n'
                                                          '3. We use industry-standard security measures to protect your information.\n'
                                                          '4. You may request to access, update, or delete your personal data at any time.\n'
                                                          '5. By using this app, you consent to our data practices as described.',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white70,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(),
                                                      child: Text(
                                                        'Close',
                                                        style: GoogleFonts.nunito(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Text(
                                            'Terms of Service',
                                            style: GoogleFonts.nunito(
                                              fontSize: getInputFontSize(MediaQuery.of(context).size) * 0.7,
                                              color: Colors.blue[200],
                                              decoration: TextDecoration.underline,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' and ',
                                        style: TextStyle(
                                          decoration: TextDecoration.none,
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  backgroundColor: const Color(0xFF05054F),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Text(
                                                    'Terms of Service & Privacy Policy',
                                                    style: GoogleFonts.nunito(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  content: SingleChildScrollView(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Terms of Service',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '1. You must provide accurate and complete information during registration.\n'
                                                          '2. You are responsible for maintaining the confidentiality of your account.\n'
                                                          '3. You agree not to use the app for any unlawful or prohibited activities.\n'
                                                          '4. We reserve the right to suspend or terminate accounts that violate our terms.\n'
                                                          '5. The app and its content are provided as-is without warranties of any kind.',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white70,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Text(
                                                          'Privacy Policy',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '1. We collect personal information to provide and improve our services.\n'
                                                          '2. Your data will not be shared with third parties except as required by law.\n'
                                                          '3. We use industry-standard security measures to protect your information.\n'
                                                          '4. You may request to access, update, or delete your personal data at any time.\n'
                                                          '5. By using this app, you consent to our data practices as described.',
                                                          style: GoogleFonts.nunito(
                                                            color: Colors.white70,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(),
                                                      child: Text(
                                                        'Close',
                                                        style: GoogleFonts.nunito(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Text(
                                            'Privacy Policy',
                                            style: GoogleFonts.nunito(
                                              fontSize: getInputFontSize(MediaQuery.of(context).size) * 0.7,
                                              color: Colors.blue[200],
                                              decoration: TextDecoration.underline,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: constraints.maxHeight * 0.05),

                          // Sign Up Button
                          Center(
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
                                onPressed: () => _submitWholesaler(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'Sign Up',
                                  style: GoogleFonts.nunito(
                                    fontSize: getButtonFontSize(),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isLoadingLocation)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildTextField({
    required String labelText,
    required TextEditingController controller,
    required double fontSize,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: fontSize,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white,
            width: 1.0,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white,
            width: 1.0,
          ),
        ),
        contentPadding: const EdgeInsets.only(bottom: 2),
      ),
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: fontSize * 0.8,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $labelText';
        }
        return null;
      },
    );
  }

  Widget buildDropdownField({
    required String labelText,
    required TextEditingController controller,
    required double fontSize,
    bool readOnly = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (labelText == 'Country') {
          _showCountryPicker();
        } else if (labelText == 'Government') {
          _showDistrictPicker();
        } else if (labelText == 'City') {
          _showCityPicker();
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: fontSize,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white,
                width: 1.0,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white,
                width: 1.0,
              ),
            ),
            contentPadding: const EdgeInsets.only(bottom: 2),
            suffixIcon: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: fontSize,
            ),
          ),
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: fontSize * 0.8,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select $labelText';
            }
            return null;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countryController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }
}