import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import '../responsive_utils.dart';  // Import the responsive utils
import 'signup_user3.dart';
import '../countrycode_dropdown.dart';
import '../../../../services/api_service.dart';

class SignupUserPage2 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupUserPage2({super.key, required this.userData});

  @override
  _SignupUserPage2State createState() => _SignupUserPage2State();
}

class _SignupUserPage2State extends State<SignupUserPage2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  String? _selectedGender;
  String _countryCode = '+961';

  // Phone validation state
  bool _isPhoneValidating = false;
  bool _isPhoneValid = true;
  String? _phoneValidationMessage;

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
    
    // Add listener to phone controller for real-time validation
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && _isValidPhoneFormat(phone)) {
      _validatePhone(phone);
    } else {
      setState(() {
        _isPhoneValidating = false;
        _isPhoneValid = true;
        _phoneValidationMessage = null;
      });
    }
  }

  bool _isValidPhoneFormat(String phone) {
    // Remove any non-digit characters for validation
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanPhone.length >= 8;
  }

  Future<void> _validatePhone(String phone) async {
    setState(() {
      _isPhoneValidating = true;
      _isPhoneValid = true;
      _phoneValidationMessage = null;
    });

    try {
      final fullPhone = '$_countryCode$phone';
      final result = await ApiService.checkEmailOrPhoneExists(phone: fullPhone);
      
      if (result['success']) {
        final data = result['data'];
        final exists = data['exists'] ?? false;
        
        setState(() {
          _isPhoneValidating = false;
          _isPhoneValid = !exists;
          _phoneValidationMessage = exists 
              ? 'This phone number is already registered' 
              : null;
        });
      } else {
        setState(() {
          _isPhoneValidating = false;
          _isPhoneValid = true; // Assume valid if check fails
          _phoneValidationMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isPhoneValidating = false;
        _isPhoneValid = true; // Assume valid if check fails
        _phoneValidationMessage = null;
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

            // Using ResponsiveUtils for font sizes
            final labelFontSize = ResponsiveUtils.getInputLabelFontSize(context);
            final inputTextFontSize = ResponsiveUtils.getInputTextFontSize(context);
            final buttonFontSize = ResponsiveUtils.getButtonFontSize(context);

            // Fixed heights for header and gap
            final double whiteHeaderHeight = 180;
            final double headerGap = 16;

            // Adjust padding based on screen size
            final horizontalPadding = constraints.maxWidth * 0.06; // 6% of screen width
            final verticalSpacing = constraints.maxHeight * 0.02; // 3% of screen height

            return Stack(
              children: [
                // Overlay Color
                Container(
                  color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
                ),

                // White Header
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

                // Custom Header
                Positioned(
                  top: whiteHeaderHeight + headerGap,
                  left: 0,
                  right: 0,
                  child: CustomHeader(
                    currentPageIndex: 2,
                    totalPages: 4,
                    subtitle: 'User',
                    onBackPressed: () => Navigator.pop(context),
                  ),
                ),

                // Main Content
                Positioned(
                  top: whiteHeaderHeight + headerGap + 50, // 50 is an estimated height for CustomHeader, adjust if needed
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (whiteHeaderHeight + headerGap + 50),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
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
                                      // Date of Birth
                                      _buildDateField(labelFontSize, inputTextFontSize),
                                      SizedBox(height: verticalSpacing),

                                      // Gender
                                      _buildGenderField(labelFontSize, inputTextFontSize),
                                      SizedBox(height: verticalSpacing),

                                      // Phone with country code in same row
                                      _buildPhoneField(labelFontSize, inputTextFontSize*1.2),
                                      SizedBox(height: verticalSpacing),

                                      // Referral Code
                                      _buildReferralField(labelFontSize, inputTextFontSize),

                                      // Spacer that takes remaining space
                                      const Spacer(),

                                      // Next Button - always at bottom
                                      _buildNextButton(constraints),
                                      SizedBox(height: verticalSpacing),
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
                ),
              ],
            );
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
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 38),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your gender';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField(double labelFontSize, double textFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone Label
        Text(
          'Phone (Optional)',
          style: GoogleFonts.nunito(
            color: const Color(0xFFDBD5D5),
            fontSize: labelFontSize * 0.8,
            fontWeight: FontWeight.w400,
          ),
        ),


        // Country code and phone input in same row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Country code dropdown - fixed width
            CountryCodeDropdown(
              initialValue: _countryCode,
              textFontSize: textFontSize,
              onChanged: (value) {
                setState(() {
                  _countryCode = value;
                });
              },
            ),

            const SizedBox(width: 8),

            // Phone number input with explicit Expanded
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: textFontSize,
                ),
                decoration: InputDecoration(
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1.0),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 1.0),
                  ),
                  errorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1.0),
                  ),
                  focusedErrorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 1.0),
                  ),
                  suffixIcon: _isPhoneValidating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : _phoneController.text.isNotEmpty
                          ? Icon(
                              _isPhoneValid ? Icons.check_circle : Icons.error,
                              color: _isPhoneValid ? Colors.green : Colors.red,
                            )
                          : null,
                  errorText: _phoneValidationMessage,
                  errorStyle: GoogleFonts.nunito(
                    color: Colors.red.shade300,
                    fontSize: 12,
                  ),
                ),
                validator: (value) {
                  // Phone number is now optional
                  if (value != null && value.isNotEmpty) {
                    if (!_isValidPhoneFormat(value)) {
                      return 'Please enter a valid phone number';
                    }
                    if (!_isPhoneValid && _phoneValidationMessage != null) {
                      return _phoneValidationMessage;
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
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
      ),
      // Optional field, no validator
    );
  }

  Widget _buildNextButton(BoxConstraints constraints) {
    // Using ResponsiveUtils for button font size
    final fontSize = ResponsiveUtils.getButtonFontSize(context);

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
              // Update user data
              final updatedUserData = {...widget.userData};
              updatedUserData['dateOfBirth'] = _dateController.text;
              updatedUserData['gender'] = _selectedGender;
              // Only add phone if provided
              if (_phoneController.text.isNotEmpty) {
                updatedUserData['phone'] = '$_countryCode${_phoneController.text}';
              }
              updatedUserData['referralCode'] = _referralController.text;

              // Navigate to next page with updated data
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignupUserPage3(userData: updatedUserData)),
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

  @override
  void dispose() {
    _dateController.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _referralController.dispose();
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