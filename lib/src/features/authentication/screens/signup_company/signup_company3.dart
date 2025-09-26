import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:country_picker/country_picker.dart';
import '../custom_header.dart';
import '../responsive_utils.dart';
import '../verification_code.dart';
import '../white_headr.dart';
import '../welcome_page.dart';
import '../../../../services/api_service.dart';
import '../../../../data/global_locations.dart';

class SignupCompany3 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupCompany3({super.key, required this.userData});

  @override
  _SignupCompany3State createState() => _SignupCompany3State();
}

class _SignupCompany3State extends State<SignupCompany3> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _governorateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  List<String> _availableCities = [];

  Future<void> _autoFillLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied")),
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _countryController.text = place.country ?? '';
          _governorateController.text = place.administrativeArea ?? '';
          _districtController.text = place.subAdministrativeArea ?? '';
          _cityController.text = place.locality ?? '';
        });
      }
    } catch (e) {
      print("Error getting location: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error getting location: $e"), backgroundColor: Colors.red),
      // );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showCountryPicker() {
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
            fontSize: ResponsiveUtils.getInputLabelFontSize(context),
          ),
          hintStyle: GoogleFonts.nunito(
            color: Colors.white54,
            fontSize: ResponsiveUtils.getInputLabelFontSize(context),
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
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        searchTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _countryController.text = country.name;
          // Reset governorate, district and city when country changes
          _governorateController.clear();
          _districtController.clear();
          _cityController.clear();
          _availableCities = [];
        });
      },
    );
  }

  void _showGovernoratePicker() {
    // Get governments for the selected country
    final governments = getGovernmentsForCountry(_countryController.text);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select Governorate',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: governments.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    governments[index].name,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _governorateController.text = governments[index].name;
                      _availableCities = governments[index].cities.map((city) => city.name).toList();
                      _districtController.clear();
                      _cityController.clear();
                    });
                    Navigator.pop(context);
                    // Get coordinates if all fields are now filled
                    _getCoordinatesFromAddress();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDistrictPicker() {
    if (_availableCities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a governorate first'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select District',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
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
                      fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _districtController.text = _availableCities[index];
                      _cityController.clear();
                    });
                    Navigator.pop(context);
                    // Get coordinates if all fields are now filled
                    _getCoordinatesFromAddress();
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
    if (_districtController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a district first'),
        ),
      );
      return;
    }

    // Get cities for the selected district
    final cities = getCitiesForGovernment(_countryController.text, _governorateController.text);
    final selectedDistrict = cities.firstWhere(
      (city) => city.name.toLowerCase() == _districtController.text.toLowerCase(),
      orElse: () => cities.first,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select City',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: selectedDistrict.streets.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    selectedDistrict.streets[index],
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _cityController.text = selectedDistrict.streets[index];
                    });
                    Navigator.pop(context);
                    // Get coordinates when city is selected (all fields are now filled)
                    _getCoordinatesFromAddress();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Modified _submitCompanySignup method with debugging and improved navigation
  void _submitCompanySignup(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the Terms of Service and Privacy Policy")),
      );
      return;
    }

    // Ensure we have coordinates before submitting
    if (_latitude == null || _longitude == null) {
      await _getCoordinatesFromAddress();
    }

    // Get the logo file if it exists
    File? logoFile = widget.userData['logo'] is File ? widget.userData['logo'] as File : null;

    // Print all user data before proceeding (keeping your debug logs)
    print("========== USER DATA ==========");
    print("Basic Info:");
    print("Email: ${widget.userData['email']}");
    print("Password: [hidden]");
    print("Full Name: ${widget.userData['fullName']}");
    print("Phone: ${widget.userData['phone'] ?? ''}");

    // Access company info through the nested structure
    final companyInfo = widget.userData['companyInfo'] ?? {};
    print("\nCompany Info:");
    print("Name: ${companyInfo['name']}");
    print("Category: ${companyInfo['category']}");
    print("SubCategory: ${companyInfo['subCategory']}");
    print("Referral Code: ${companyInfo['referralCode'] ?? ''}");
    print("Logo: ${logoFile != null ? logoFile.path : 'Not provided'}");

    print("\nLocation Info:");
    print("Country: ${_countryController.text}");
    print("Governorate: ${_governorateController.text}");
    print("District: ${_districtController.text}");
    print("City: ${_cityController.text}");
    print("Latitude: $_latitude");
    print("Longitude: $_longitude");
    print("==============================");

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

    final phone = widget.userData['fullPhone'] ?? widget.userData['phone'] ?? '';
    try {
      // Location data is now included directly in updatedUserData below

      // Create the complete user data object - ensuring all companyInfo keys are consistent
      final updatedUserData = {
        ...widget.userData,
        "country": _countryController.text,
        "governorate": _governorateController.text,
        "district": _districtController.text,
        "city": _cityController.text,
        "lat": _latitude ?? 0.0,
        "lng": _longitude ?? 0.0,
        "userType": "company",
      };

      final response = await ApiService.signupBusiness(updatedUserData, logoFile);
      print("API Response: $response"); // Debug the API response

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Check if OTP was sent successfully
      if (response['success'] == true ||
          (response['message']?.toString().contains('OTP sent successfully') == true)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              phoneNumber: phone,
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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response['message'] ?? 'Signup Failed'),
        //     backgroundColor: Colors.red,
        //     duration: const Duration(seconds: 5),
        //   ),
        // );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text("Error during signup: ${e.toString()}"),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 5),
      //   ),
      // );
    }
  }

  Future<void> _getCoordinatesFromAddress() async {
    if (_countryController.text.isNotEmpty &&
        _governorateController.text.isNotEmpty &&
        _districtController.text.isNotEmpty &&
        _cityController.text.isNotEmpty) {
      
      try {
        // Build address string from selected fields
        final addressString = '${_cityController.text}, ${_districtController.text}, ${_governorateController.text}, ${_countryController.text}';
        
        // Get coordinates from address
        List<Location> locations = await locationFromAddress(addressString);
        
        if (locations.isNotEmpty) {
          setState(() {
            _latitude = locations[0].latitude;
            _longitude = locations[0].longitude;
          });
          
          print('=== MANUAL LOCATION COORDINATES ===');
          print('Address: $addressString');
          print('Latitude: $_latitude');
          print('Longitude: $_longitude');
          print('===================================');
        }
      } catch (e) {
        print('Error getting coordinates from address: $e');
        // If geocoding fails, set default coordinates (center of Lebanon)
        setState(() {
          _latitude = 33.8;
          _longitude = 35.8;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: const Color(0xFF05054F).withOpacity(0.77),
            ),
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
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(height: 160),
                    CustomHeader(
                      currentPageIndex: 3,
                      totalPages: 3,
                      subtitle: 'Company',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            children: [
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _autoFillLocation,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _isLoadingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.location_on,
                                            color: Colors.white, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Auto-pin locations',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _showCountryPicker,
                                child: AbsorbPointer(
                                  child: buildTextField(
                                    labelText: 'Country',
                                    controller: _countryController,
                                    readOnly: true,
                                    suffixIcon: Icons.keyboard_arrow_down,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _showGovernoratePicker,
                                child: AbsorbPointer(
                                  child: buildTextField(
                                    labelText: 'Governorate',
                                    controller: _governorateController,
                                    readOnly: true,
                                    suffixIcon: Icons.keyboard_arrow_down,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _showDistrictPicker,
                                child: AbsorbPointer(
                                  child: buildTextField(
                                    labelText: 'District',
                                    controller: _districtController,
                                    readOnly: true,
                                    suffixIcon: Icons.keyboard_arrow_down,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _showCityPicker,
                                child: AbsorbPointer(
                                  child: buildTextField(
                                    labelText: 'City',
                                    controller: _cityController,
                                    readOnly: true,
                                    suffixIcon: Icons.keyboard_arrow_down,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreeToTerms = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.nunito(
                                          fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
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
                                                  fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
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
                                                  fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
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
                              const SizedBox(height: 30),
                              SizedBox(
                                height: 66,
                                child: ElevatedButton(
                                  onPressed: () => _submitCompanySignup(context),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ).copyWith(
                                    backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                    elevation: MaterialStateProperty.all(0),
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF0094FF),
                                          Color(0xFF05055A),
                                          Color(0xFF0094FF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Sign Up',
                                        style: GoogleFonts.nunito(
                                          fontSize: ResponsiveUtils.getButtonFontSize(context),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField({
    required String labelText,
    required TextEditingController controller,
    bool readOnly = false,
    IconData? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
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
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.white, size: 20)
            : null,
      ),
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select $labelText';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _countryController.dispose();
    _governorateController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}