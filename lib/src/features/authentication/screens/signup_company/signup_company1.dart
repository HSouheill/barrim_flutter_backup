import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../login_page.dart';
import '../white_headr.dart';
import '../countrycode_dropdown.dart';
import 'signup_company2.dart';
import '../responsive_utils.dart';
import '../../../../services/api_service.dart';

class SignupCompany1 extends StatefulWidget {
  const SignupCompany1({super.key});

  @override
  State<SignupCompany1> createState() => _SignupCompany1State();
}

class _SignupCompany1State extends State<SignupCompany1> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  String _countryCode = '+961';
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  // Email validation state
  bool _isEmailValidating = false;
  bool _isEmailValid = true;
  String? _emailValidationMessage;

  // Phone validation state
  bool _isPhoneValidating = false;
  bool _isPhoneValid = true;
  String? _phoneValidationMessage;

  // Add new state variables for multiple emails and phones
  List<TextEditingController> _additionalEmailControllers = [];
  List<TextEditingController> _additionalPhoneControllers = [];
  List<String> _additionalCountryCodes = [];
  List<FocusNode> _additionalEmailFocusNodes = [];
  List<FocusNode> _additionalPhoneFocusNodes = [];

  @override
  void initState() {
    super.initState();
    // Add listener to email controller for real-time validation
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && _isValidEmailFormat(email)) {
      _validateEmail(email);
    } else {
      setState(() {
        _isEmailValidating = false;
        _isEmailValid = true;
        _emailValidationMessage = null;
      });
    }
  }

  bool _isValidEmailFormat(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _validateEmail(String email) async {
    setState(() {
      _isEmailValidating = true;
      _isEmailValid = true;
      _emailValidationMessage = null;
    });

    try {
      final result = await ApiService.checkEmailOrPhoneExists(email: email);
      
      if (result['success']) {
        final data = result['data'];
        final exists = data['exists'] ?? false;
        
        setState(() {
          _isEmailValidating = false;
          _isEmailValid = !exists;
          _emailValidationMessage = exists 
              ? 'This email is already registered' 
              : null;
        });
      } else {
        setState(() {
          _isEmailValidating = false;
          _isEmailValid = true; // Assume valid if check fails
          _emailValidationMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isEmailValidating = false;
        _isEmailValid = true; // Assume valid if check fails
        _emailValidationMessage = null;
      });
    }
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
          _phoneValidationMessage = exists ? 'This phone number is already registered' : null;
        });
      } else {
        setState(() {
          _isPhoneValidating = false;
          _isPhoneValid = true;
          _phoneValidationMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isPhoneValidating = false;
        _isPhoneValid = true;
        _phoneValidationMessage = null;
      });
    }
  }

  Widget _buildPhoneField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CountryCodeDropdown(
          initialValue: _countryCode,
          onChanged: (String value) {
            setState(() {
              _countryCode = value;
            });
          },
          textFontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.9,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputTextFontSize(context),
            ),
            decoration: InputDecoration(
              labelText: 'Phone',
              labelStyle: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: ResponsiveUtils.getInputLabelFontSize(context),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2.0),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              contentPadding: const EdgeInsets.only(bottom: 2),
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
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (!_isValidPhoneFormat(value)) {
                return 'Please enter a valid phone number';
              }
              if (!_isPhoneValid && _phoneValidationMessage != null) {
                return _phoneValidationMessage;
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // Add new functions for handling additional fields
  void _addEmailField() {
    setState(() {
      _additionalEmailControllers.add(TextEditingController());
      _additionalEmailFocusNodes.add(FocusNode());
    });
  }

  void _removeEmailField(int index) {
    setState(() {
      _additionalEmailControllers[index].dispose();
      _additionalEmailFocusNodes[index].dispose();
      _additionalEmailControllers.removeAt(index);
      _additionalEmailFocusNodes.removeAt(index);
    });
  }

  void _addPhoneField() {
    setState(() {
      _additionalPhoneControllers.add(TextEditingController());
      _additionalPhoneFocusNodes.add(FocusNode());
      _additionalCountryCodes.add('+961'); // Default country code
    });
  }

  void _removePhoneField(int index) {
    setState(() {
      _additionalPhoneControllers[index].dispose();
      _additionalPhoneFocusNodes[index].dispose();
      _additionalPhoneControllers.removeAt(index);
      _additionalPhoneFocusNodes.removeAt(index);
      _additionalCountryCodes.removeAt(index);
    });
  }

  Widget _buildAdditionalEmailField(int index) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _additionalEmailControllers[index],
            focusNode: _additionalEmailFocusNodes[index],
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputTextFontSize(context),
            ),
            decoration: InputDecoration(
              labelText: 'Additional Email ${index + 1}',
              labelStyle: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: ResponsiveUtils.getInputLabelFontSize(context),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2.0),
              ),
              contentPadding: const EdgeInsets.only(bottom: 2),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.white),
          onPressed: () => _removeEmailField(index),
        ),
      ],
    );
  }

  Widget _buildAdditionalPhoneField(int index) {
    return Row(
      children: [
        CountryCodeDropdown(
          initialValue: _additionalCountryCodes[index],
          onChanged: (String value) {
            setState(() {
              _additionalCountryCodes[index] = value;
            });
          },
          textFontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.9,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _additionalPhoneControllers[index],
            focusNode: _additionalPhoneFocusNodes[index],
            keyboardType: TextInputType.phone,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: ResponsiveUtils.getInputTextFontSize(context),
            ),
            decoration: InputDecoration(
              labelText: 'Additional Phone ${index + 1}',
              labelStyle: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: ResponsiveUtils.getInputLabelFontSize(context),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2.0),
              ),
              contentPadding: const EdgeInsets.only(bottom: 2),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter phone number';
              }
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.white),
          onPressed: () => _removePhoneField(index),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;
            final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;
            final isLargeScreen = constraints.maxWidth >= 600;

            return Stack(
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
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.15),
                      CustomHeader(
                        currentPageIndex: 1,
                        totalPages: 3,
                        subtitle: 'Company',
                        onBackPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: constraints.maxHeight * 0.03,
                            ),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // Full Name Input
                              TextFormField(
                                focusNode: _fullNameFocus,
                                keyboardType: TextInputType.name,
                                controller: _fullNameController, // FIXED: Removed obscureText property
                                onTap: () {
                                  FocusScope.of(context).requestFocus(_fullNameFocus);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white, // White color
                                      width: 2.0, // Increased thickness for more opacity
                                      style: BorderStyle.solid, // Ensures the line is solid
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white, // White color
                                      width: 2.0, // Even thicker when focused for better visibility
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  isDense: true, // Makes the field more compact
                                  contentPadding: const EdgeInsets.only(bottom: 4), // Reduced padding
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: constraints.maxHeight * 0.02),

                              // Email Input
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email address',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white, // White color
                                      width: 2.0, // Increased thickness for more opacity
                                      style: BorderStyle.solid, // Ensures the line is solid
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white, // White color
                                      width: 2.0, // Even thicker when focused for better visibility
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  errorBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2.0,
                                    ),
                                  ),
                                  focusedErrorBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 2.0,
                                    ),
                                  ),
                                  isDense: true, // This makes the field more compact
                                  contentPadding: const EdgeInsets.only(bottom: 4), // Reduced padding
                                  suffixIcon: _isEmailValidating
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
                                      : _emailController.text.isNotEmpty
                                          ? Icon(
                                              _isEmailValid ? Icons.check_circle : Icons.error,
                                              color: _isEmailValid ? Colors.green : Colors.red,
                                            )
                                          : null,
                                  errorText: _emailValidationMessage,
                                  errorStyle: GoogleFonts.nunito(
                                    color: Colors.red.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!_isValidEmailFormat(value)) {
                                    return 'Please enter a valid email address';
                                  }
                                  if (!_isEmailValid && _emailValidationMessage != null) {
                                    return _emailValidationMessage;
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: constraints.maxHeight * 0.02),

                              // Phone Input
                              _buildPhoneField(),

                              SizedBox(height: constraints.maxHeight * 0.02),

                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
                                  ),
                                  helperText: 'Password must contain capital and small letters, symbols, and numbers',
                                  helperStyle: GoogleFonts.nunito(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.only(bottom: 4),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  // Password validation rules
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters long';
                                  }
                                  if (!value.contains(RegExp(r'[A-Z]'))) {
                                    return 'Password must contain at least one uppercase letter';
                                  }
                                  if (!value.contains(RegExp(r'[a-z]'))) {
                                    return 'Password must contain at least one lowercase letter';
                                  }
                                  if (!value.contains(RegExp(r'[0-9]'))) {
                                    return 'Password must contain at least one number';
                                  }
                                  if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                                    return 'Password must contain at least one special character';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: constraints.maxHeight * 0.02),

                              // Confirm Password Input
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 2.0,

                                    ),
                                  ),
                                  isDense: true, // This makes the field more compact
                                  contentPadding: const EdgeInsets.only(bottom: 4), // Reduced padding

                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: constraints.maxHeight * 0.03),

                              // Add Phone/Email buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Add Phone Number Button
                                  TextButton.icon(
                                    onPressed: _addPhoneField,
                                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                    label: Text(
                                      'Phone Number',
                                      style: GoogleFonts.nunito(
                                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                  SizedBox(width: constraints.maxWidth * 0.03),
                                  // Add Email Address Button
                                  TextButton.icon(
                                    onPressed: _addEmailField,
                                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                    label: Text(
                                      'Email Address',
                                      style: GoogleFonts.nunito(
                                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ],
                              ),

                              // Show additional email fields
                              ...List.generate(_additionalEmailControllers.length, (index) {
                                return Column(
                                  children: [
                                    SizedBox(height: constraints.maxHeight * 0.02),
                                    _buildAdditionalEmailField(index),
                                  ],
                                );
                              }),

                              // Show additional phone fields
                              ...List.generate(_additionalPhoneControllers.length, (index) {
                                return Column(
                                  children: [
                                    SizedBox(height: constraints.maxHeight * 0.02),
                                    _buildAdditionalPhoneField(index),
                                  ],
                                );
                              }),

                              SizedBox(height: constraints.maxHeight * 0.07),

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
                                        // Clean the phone number by removing any non-digit characters
                                        String cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

                                        // Combine country code and phone number
                                        String fullPhoneNumber = _countryCode + cleanPhone;

                                        // Collect all additional emails
                                        List<String> additionalEmails = _additionalEmailControllers
                                            .map((controller) => controller.text)
                                            .where((email) => email.isNotEmpty)
                                            .toList();

                                        // Collect all additional phones
                                        List<Map<String, String>> additionalPhones = [];
                                        for (int i = 0; i < _additionalPhoneControllers.length; i++) {
                                          String cleanAdditionalPhone = _additionalPhoneControllers[i].text
                                              .replaceAll(RegExp(r'[^0-9]'), '');
                                          if (cleanAdditionalPhone.isNotEmpty) {
                                            additionalPhones.add({
                                              'countryCode': _additionalCountryCodes[i],
                                              'phone': cleanAdditionalPhone,
                                              'fullPhone': _additionalCountryCodes[i] + cleanAdditionalPhone,
                                            });
                                          }
                                        }

                                        // Prepare the updated user data
                                        final updatedUserData = {
                                          'fullName': _fullNameController.text,
                                          'email': _emailController.text,
                                          'additionalEmails': additionalEmails,
                                          'countryCode': _countryCode,
                                          'phone': cleanPhone,
                                          'fullPhone': fullPhoneNumber,
                                          'additionalPhones': additionalPhones,
                                          'password': _passwordController.text,
                                          'userType': 'company',
                                        };

                                        // Debug: print updated user data before moving to next page
                                        print("DEBUG: Updated user data: $updatedUserData");

                                        // Navigate to the next screen with updated data
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SignupCompany2(userData: updatedUserData),
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
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _phoneFocus.dispose();
    
    // Dispose additional controllers and focus nodes
    for (var controller in _additionalEmailControllers) {
      controller.dispose();
    }
    for (var controller in _additionalPhoneControllers) {
      controller.dispose();
    }
    for (var focusNode in _additionalEmailFocusNodes) {
      focusNode.dispose();
    }
    for (var focusNode in _additionalPhoneFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}