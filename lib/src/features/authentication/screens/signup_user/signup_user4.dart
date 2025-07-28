import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../white_headr.dart';
import 'signup_user5.dart';
import '../responsive_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../data/lebanon_locations.dart';

class SignupUserPage4 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupUserPage4({super.key, required this.userData});

  @override
  State<SignupUserPage4> createState() => _SignupUserPage4State();
}

class _SignupUserPage4State extends State<SignupUserPage4> {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, please enable them in settings'),
          ),
        );
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF05054F),
          title: Text(
            'Select Government',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
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
                      fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a district first'),
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
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;

        double getpolicyFontSize() {
          if (isSmallScreen) return 12;
          if (isMediumScreen) return 14;
          return 16;
        }

        final labelFontSize = ResponsiveUtils.getInputLabelFontSize(context);
        final inputTextFontSize = ResponsiveUtils.getInputTextFontSize(context);
        final buttonFontSize = ResponsiveUtils.getButtonFontSize(context);

        // Fixed heights for header and gap
        final double whiteHeaderHeight = 180;
        final double headerGap = 16;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/background.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: whiteHeaderHeight,
                      child: WhiteHeader(
                        title: 'Sign Up',
                        onBackPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: whiteHeaderHeight + headerGap,
                    left: 0,
                    right: 0,
                    child: CustomHeader(
                      currentPageIndex: 4,
                      totalPages: 4,
                      subtitle: 'User',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  Positioned(
                    left: 24,
                    right: 24,
                    top: whiteHeaderHeight + headerGap + 50, // 50 is an estimated height for CustomHeader, adjust if needed
                    bottom: 0,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: GestureDetector(
                              onTap: _getCurrentLocation,
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
                                    'Auto-pin location',
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _handleFieldTap('country'),
                            child: buildDropdownField(
                              labelText: 'Country',
                              controller: _countryController,
                              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                              readOnly: _isLoadingLocation,
                              onTap: _showCountryPicker,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),
                          GestureDetector(
                            onTap: () => _handleFieldTap('district'),
                            child: buildDropdownField(
                              labelText: 'Government',
                              controller: _districtController,
                              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                              readOnly: _isLoadingLocation,
                              onTap: _showDistrictPicker,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),
                          GestureDetector(
                            onTap: () => _handleFieldTap('city'),
                            child: buildDropdownField(
                              labelText: 'City',
                              controller: _cityController,
                              fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                              readOnly: _isLoadingLocation,
                              onTap: _showCityPicker,
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: () => _handleFieldTap('street'),
                                  child: buildTextField(
                                    labelText: 'Street',
                                    controller: _streetController,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                    readOnly: _isLoadingLocation,
                                  ),
                                ),
                              ),
                              SizedBox(width: constraints.maxWidth * 0.04),
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: () => _handleFieldTap('postalCode'),
                                  child: buildTextField(
                                    labelText: 'Postal Code',
                                    controller: _postalCodeController,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                    readOnly: _isLoadingLocation,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: constraints.maxHeight * 0.03),
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
                                      fontSize: getpolicyFontSize(),
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
                                              fontSize: getpolicyFontSize(),
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
                                              fontSize: getpolicyFontSize(),
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
                                onPressed: () {
                                  if (_formKey.currentState!.validate() && _agreeToTerms) {
                                    final addressData = {
                                      'country': _countryController.text,
                                      'district': _districtController.text,
                                      'city': _cityController.text,
                                      'street': _streetController.text,
                                      'postalCode': _postalCodeController.text,
                                      'lat': _latitude ?? 0.0,
                                      'lng': _longitude ?? 0.0,
                                    };

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignupUserPage5(
                                          userData: {...widget.userData, 'address': addressData},
                                        ),
                                      ),
                                    );
                                  } else if (!_agreeToTerms) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Please agree to the Terms of Service and Privacy Policy"),
                                      ),
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
                                    fontSize: ResponsiveUtils.getButtonFontSize(context),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          TextFormField(
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
          Positioned(
            right: 0,
            top: 15,
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: fontSize,
            ),
          ),
        ],
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