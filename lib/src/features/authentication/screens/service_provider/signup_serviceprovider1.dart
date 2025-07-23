import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import 'signup_serviceprovider2.dart';
import '../responsive_utils.dart';
import '../../../../services/api_service.dart';
import '../countrycode_dropdown.dart';

class SignupServiceprovider1 extends StatefulWidget {
  const SignupServiceprovider1({super.key});

  @override
  State<SignupServiceprovider1> createState() => _SignupServiceprovider1State();
}

class _SignupServiceprovider1State extends State<SignupServiceprovider1> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
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
                borderSide: BorderSide(color: Colors.white, width: 2.0),
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
                        subtitle: 'Service Provider',
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
                                obscureText: _isPasswordVisible,
                                controller: _fullNameController,
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

                              SizedBox(height: constraints.maxHeight * 0.02),
                              _buildReferralField(),



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
                                        // Add print statements to check phone number
                                        print('Phone number being sent: $_countryCode ${_phoneController.text}');
                                        // print('Full user data being sent:');
                                        // print('Full Name: ${_fullNameController.text}');
                                        // print('Email: ${_emailController.text}');
                                        // print('Phone: $_countryCode ${_phoneController.text}');
                                        // print('Password: ${_passwordController.text}');
                                        // print('Referral Code: ${_referralController.text}');

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SignupServiceprovider2(
                                              userData: {
                                                'fullName': _fullNameController.text,
                                                'email': _emailController.text,
                                                'password': _passwordController.text,
                                                'phone': _countryCode + _phoneController.text,
                                                'referralCode': _referralController.text,
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
    _referralController.dispose();
    _fullNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }
}