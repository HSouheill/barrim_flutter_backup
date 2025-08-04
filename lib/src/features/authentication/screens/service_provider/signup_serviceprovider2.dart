import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';
import '../custom_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../responsive_utils.dart';
import 'signup_serviceprovider3.dart';
import '../../../../data/global_locations.dart';
import '../white_headr.dart';

class SignupServiceprovider2 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupServiceprovider2({super.key, required this.userData});

  @override
  State<SignupServiceprovider2> createState() => _SignupServiceprovider2State();
}

class _SignupServiceprovider2State extends State<SignupServiceprovider2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _agreeToTerms = false;
  String? _selectedGender;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  List<String> _availableCities = [];

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 30), // Increase timeout to 30 seconds
    );

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Optionally prompt user to enable location services
        bool enabled = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Services Disabled'),
            content: Text('Please enable location services to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Enable'),
              ),
            ],
          ),
        );

        if (enabled ?? false) {
          await Geolocator.openLocationSettings();
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        setState(() {
          _countryController.text = place.country ?? '';
          _districtController.text = place.administrativeArea ?? '';
          _cityController.text = place.locality ?? '';
          _streetController.text = place.street ?? '';
          _postalCodeController.text = place.postalCode ?? '';
        });
      }
    } on PlatformException catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to get location: ${e.message}')),
      // );
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
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
          // Reset district and city when country changes
          _districtController.clear();
          _cityController.clear();
          _availableCities = [];
        });
      },
    );
  }

  void _showDistrictPicker() {
    // Get governments for the selected country
    final governments = getGovernmentsForCountry(_countryController.text);
    
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
                      _districtController.text = governments[index].name;
                      _availableCities = governments[index].cities.map((city) => city.name).toList();
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
          content: Text('Please select a Government first'),
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
        // Screen size breakpoints
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;
        final isLargeScreen = constraints.maxWidth >= 600;

        // Using ResponsiveUtils for font sizes
        final labelFontSize = ResponsiveUtils.getInputLabelFontSize(context);
        final inputTextFontSize = ResponsiveUtils.getInputTextFontSize(context);
        final buttonFontSize = ResponsiveUtils.getButtonFontSize(context);

        // Adjust padding based on screen size
        final horizontalPadding = constraints.maxWidth * 0.06; // 6% of screen width
        final verticalSpacing = constraints.maxHeight * 0.01; // 3% of screen height

        // Responsive font sizes
        double getTitleFontSize() {
          if (isSmallScreen) return 28;
          if (isMediumScreen) return 40;
          return 38;
        }

        double getpolicyFontSize() {
          if (isSmallScreen) return 14;
          if (isMediumScreen) return 16;
          return 18;
        }

        double getInputFontSize() {
          if (isSmallScreen) return 16;
          if (isMediumScreen) return 22;
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
                    top: constraints.maxHeight * 0.23,
                    left: 0,
                    right: 0,
                    child: CustomHeader(
                      currentPageIndex: 2, // Assuming this is page 2 of 4
                      totalPages: 4,
                      subtitle: 'Service Provider',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Address Form
                  Positioned(
                    left: 24,
                    right: 24,
                    top: constraints.maxHeight * 0.30,
                    bottom: 0,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: _fetchCurrentLocation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: getpolicyFontSize() * 1.2,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Auto-pin location',
                                      style: GoogleFonts.nunito(
                                        fontSize: getpolicyFontSize() * 1.1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Date of Birth
                          _buildDateField(labelFontSize, inputTextFontSize),
                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Gender
                          _buildGenderField(labelFontSize, inputTextFontSize),
                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Country Dropdown
                          buildDropdownField(
                            labelText: 'Country',
                            controller: _countryController,
                            fontSize: getInputFontSize(),
                            readOnly: _isLoadingLocation,
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // District Dropdown
                          buildDropdownField(
                            labelText: 'Government',
                            controller: _districtController,
                            fontSize: getInputFontSize(),
                            readOnly: _isLoadingLocation,
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // City Dropdown
                          buildDropdownField(
                            labelText: 'City',
                            controller: _cityController,
                            fontSize: getInputFontSize(),
                            readOnly: _isLoadingLocation,
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Street and Postal Code (Row)
                          Row(
                            children: [
                              // Street Field
                              Expanded(
                                flex: 1,
                                child: buildTextField(
                                  labelText: 'Street',
                                  controller: _streetController,
                                  fontSize: getInputFontSize(),
                                  readOnly: _isLoadingLocation,
                                ),
                              ),
                              SizedBox(width: constraints.maxWidth * 0.04),
                              // Postal Code Field
                              Expanded(
                                flex: 1,
                                child: buildTextField(
                                  labelText: 'Postal Code',
                                  controller: _postalCodeController,
                                  fontSize: getInputFontSize(),
                                  readOnly: _isLoadingLocation,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: constraints.maxHeight * 0.04),

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
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    // In SignupServiceprovider2
                                    print("Phone Number in Screen 2: ${widget.userData['phone']}");

                                    // Save all form data
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignupServiceprovider3(
                                          userData: {
                                            ...widget.userData, // Spread the existing data
                                            'location': {
                                              'country': _countryController.text,
                                              'district': _districtController.text,
                                              'city': _cityController.text,
                                              'street': _streetController.text,
                                              'postalCode': _postalCodeController.text,
                                              'lat': _latitude ?? 0.0,
                                              'lng': _longitude ?? 0.0,
                                              'allowed': true,
                                            },
                                          },
                                        ),
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

                  // Full-screen loading overlay
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
        isDense: true, // Makes the field more compact
        contentPadding: const EdgeInsets.only(bottom: 4),
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
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 4),
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

  Widget _buildDateField(double labelFontSize, double textFontSize) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      decoration: InputDecoration(
        labelText: 'Date of Birth',
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
        contentPadding: const EdgeInsets.only(bottom: 4),

        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, color: Colors.white, size: 28),
          onPressed: () => _selectDate(context),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your date of birth';
        }
        return null;
      },
      onTap: () => _selectDate(context),
    );
  }

  Widget _buildGenderField(double labelFontSize, double textFontSize) {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      dropdownColor: const Color(0xFF05054F),
      decoration: InputDecoration(
        labelText: 'Gender',
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
      items: <String>['Male', 'Female']
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
          _selectedGender = newValue;
        });
      },
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your gender';
        }
        return null;
      },
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
