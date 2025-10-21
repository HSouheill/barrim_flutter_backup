import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';
import '../custom_header.dart';
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
  final TextEditingController _governorateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String? _selectedGender;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;
  List<String> _availableCities = [];

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });


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

        if (enabled == true) {
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
          _governorateController.text = place.administrativeArea ?? '';
          _districtController.text = place.subAdministrativeArea ?? '';
          _cityController.text = place.locality ?? '';
        });
      }
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
        _dateController.text = DateFormat('yyyy/MM/dd').format(picked);
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
                    top: constraints.maxHeight * 0.27,
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

                          // Governorate Dropdown
                          buildDropdownField(
                            labelText: 'Governorate',
                            controller: _governorateController,
                            fontSize: getInputFontSize(),
                            readOnly: _isLoadingLocation,
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // District Dropdown
                          buildDropdownField(
                            labelText: 'District',
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
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    // Ensure we have coordinates before proceeding
                                    if (_latitude == null || _longitude == null) {
                                      await _getCoordinatesFromAddress();
                                    }

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
                                              'governorate': _governorateController.text,
                                              'district': _districtController.text,
                                              'city': _cityController.text,
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
        } else if (labelText == 'Governorate') {
          _showGovernoratePicker();
        } else if (labelText == 'District') {
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
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(10),
        _DateTextFormatter(),
      ],
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: textFontSize,
      ),
      decoration: InputDecoration(
        labelText: 'Date of Birth (YYYY/MM/DD)',
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
          return 'Please enter your date of birth';
        }
        // Validate date format YYYY/MM/DD
        final dateRegex = RegExp(r'^\d{4}/\d{2}/\d{2}$');
        if (!dateRegex.hasMatch(value)) {
          return 'Please enter a valid date (YYYY/MM/DD)';
        }
        // Validate actual date
        try {
          final parts = value.split('/');
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final date = DateTime(year, month, day);
          if (date.isAfter(DateTime.now())) {
            return 'Date cannot be in the future';
          }
          if (year < 1900) {
            return 'Please enter a valid year';
          }
        } catch (e) {
          return 'Please enter a valid date';
        }
        return null;
      },
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
    _governorateController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}

// Custom TextInputFormatter for date with protected slashes
class _DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // If user is trying to delete a slash, prevent it
    if (oldValue.text.length > newValue.text.length) {
      // Check if deleted character was a slash
      final deletedIndex = newValue.selection.baseOffset;
      if (deletedIndex < oldValue.text.length && 
          (oldValue.text[deletedIndex] == '/' || 
           (deletedIndex > 0 && oldValue.text[deletedIndex - 1] == '/'))) {
        return oldValue;
      }
    }
    
    // Remove all non-digit characters except slashes
    String digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Build formatted string
    String formatted = '';
    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      if (i == 4 || i == 6) {
        formatted += '/';
      }
      formatted += digitsOnly[i];
    }
    
    // Calculate new cursor position
    int offset = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
