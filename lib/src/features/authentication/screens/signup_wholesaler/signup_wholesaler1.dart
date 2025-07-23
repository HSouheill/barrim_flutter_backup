import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../login_page.dart';
import '../signup_wholesaler/signup_wholesaler2.dart';
import '../white_headr.dart';
import '../../../../services/api_service.dart';
import '../countrycode_dropdown.dart';
import '../responsive_utils.dart';

class SignupWholesalerPage1 extends StatefulWidget {
  const SignupWholesalerPage1({super.key});

  @override
  State<SignupWholesalerPage1> createState() => _SignupWholesalerPage1State();
}

class _SignupWholesalerPage1State extends State<SignupWholesalerPage1> {
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

  // Add lists to store additional controllers and focus nodes
  final List<TextEditingController> _additionalEmailControllers = [];
  final List<TextEditingController> _additionalPhoneControllers = [];
  final List<FocusNode> _additionalEmailFocusNodes = [];
  final List<FocusNode> _additionalPhoneFocusNodes = [];
  final List<String> _additionalCountryCodes = [];

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

  // Add methods to handle adding/removing fields
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
      _additionalCountryCodes.add('+961');
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

  // Add method to build additional email fields
  Widget _buildAdditionalEmailField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _additionalEmailControllers[index],
              focusNode: _additionalEmailFocusNodes[index],
              decoration: InputDecoration(
                labelText: 'Additional Email ${index + 1}',
                labelStyle: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: getInputFontSize(),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 1.0),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 1.0),
                ),
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: getInputFontSize() * 0.8,
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
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: () => _removeEmailField(index),
          ),
        ],
      ),
    );
  }

  // Add method to build additional phone fields
  Widget _buildAdditionalPhoneField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
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
                  borderSide: BorderSide(color: Colors.white, width: 1.0),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 1.0),
                ),
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Phone number should contain only digits';
                }
                return null;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
            onPressed: () => _removePhoneField(index),
          ),
        ],
      ),
    );
  }

  // Helper method to get input font size
  double getInputFontSize() {
    final constraints = MediaQuery.of(context).size;
    if (constraints.width < 360) return 18;
    if (constraints.width >= 360 && constraints.width < 600) return 24;
    return 26;
  }

  Widget _buildPhoneField(double inputFontSize) {
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
                borderSide: BorderSide(color: Colors.white, width: 1.5),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2.0),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              errorStyle: GoogleFonts.nunito(
                color: Colors.red.shade300,  // More visible error color
                fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.6,
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
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (!_isValidPhoneFormat(value)) {
                return 'Phone number should contain only digits';
              }
              if (!_isPhoneValid && _phoneValidationMessage != null) {
                return _phoneValidationMessage;
              }
              // Check minimum length based on country code
              int minLength = 0;
              switch (_countryCode) {
                case '+1':
                  minLength = 10;  // US/Canada
                  break;
                case '+44':
                  minLength = 10;  // UK
                  break;
                case '+961':
                  minLength = 8;   // Lebanon
                  break;
                case '+971':
                  minLength = 9;   // UAE
                  break;
                default:
                  minLength = 8;
              }
              if (value.length < minLength) {
                return 'Phone number must be at least $minLength digits';
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
            final double inputFontSize = constraints.maxWidth < 360 ? 18 : 24;
            final double buttonFontSize = constraints.maxWidth < 360 ? 18 : 22;
            final isSmallScreen = constraints.maxWidth < 360;
            final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;
            final isLargeScreen = constraints.maxWidth >= 600;

            // Responsive font sizes
            double getTitleFontSize() {
              if (isSmallScreen) return 28;
              if (isMediumScreen) return 40;
              return 38;
            }

            double getInputFontSize() {
              if (isSmallScreen) return 18;
              if (isMediumScreen) return 24;
              return 26;
            }

            double getButtonFontSize() {
              if (isSmallScreen) return 18;
              if (isMediumScreen) return 22;
              return 26;
            }
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
                        subtitle: 'Wholesaler',
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
                                controller: _fullNameController,
                                onTap: () {
                                  FocusScope.of(context).requestFocus(_fullNameFocus);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: getInputFontSize(),
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
                                      width: 3.0, // Even thicker when focused for better visibility
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  isDense: true, // Makes the field more compact
                                  contentPadding: const EdgeInsets.only(bottom: 4), // Reduced padding
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: getInputFontSize() * 0.8,
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
                                    fontSize: getInputFontSize(),
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
                                      width: 3.0, // Even thicker when focused for better visibility
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
                                  fontSize: getInputFontSize() * 0.8,
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
                              _buildPhoneField(getInputFontSize()),



                              SizedBox(height: constraints.maxHeight * 0.02),

                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: getInputFontSize(),
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
                                  fontSize: getInputFontSize() * 0.8,
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
                                    fontSize: getInputFontSize(),
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
                                  fontSize: getInputFontSize() * 0.8,
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
                                        fontSize: getButtonFontSize() * 0.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                        fontSize: getButtonFontSize() * 0.6,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                    ),
                                  ),
                                ],
                              ),

                              // Display additional email fields
                              ...List.generate(_additionalEmailControllers.length, (index) {
                                return _buildAdditionalEmailField(index);
                              }),

                              // Display additional phone fields
                              ...List.generate(_additionalPhoneControllers.length, (index) {
                                return _buildAdditionalPhoneField(index);
                              }),

                              SizedBox(height: constraints.maxHeight * 0.02),


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
                                        // Collect all email addresses
                                        List<String> allEmails = [_emailController.text];
                                        allEmails.addAll(_additionalEmailControllers
                                            .map((controller) => controller.text)
                                            .where((email) => email.isNotEmpty));

                                        // Collect all phone numbers with country codes
                                        List<String> allPhones = ['$_countryCode${_phoneController.text}'];
                                        for (int i = 0; i < _additionalPhoneControllers.length; i++) {
                                          if (_additionalPhoneControllers[i].text.isNotEmpty) {
                                            allPhones.add('${_additionalCountryCodes[i]}${_additionalPhoneControllers[i].text}');
                                          }
                                        }

                                        // Only proceed if the form is valid
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SignupWholesaler2(
                                              userData: {
                                                'fullName': _fullNameController.text,
                                                'email': _emailController.text,
                                                'additionalEmails': allEmails,
                                                'countryCode': _countryCode,
                                                'phone': _phoneController.text,
                                                'additionalPhones': allPhones,
                                                'password': _passwordController.text,
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
                                        fontSize: getButtonFontSize(),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

// Don't forget to update the dispose method




                              // Social Login Buttons

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
