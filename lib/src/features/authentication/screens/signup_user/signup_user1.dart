import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../login_page.dart';
import '../signup_user/signup_user2.dart';
import '../responsive_utils.dart';
import '../../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../../services/google_auth_service.dart';
import '../apple_signin.dart';
import '../../../../services/user_provider.dart';
import '../../../../services/apple_auth_service.dart';
import '../user_dashboard/home.dart';
import '../company_dashboard/company_dashboard.dart';
import '../serviceProvider_dashboard/serviceprovider_dashboard.dart';
import '../white_headr.dart';
import '../wholesaler_dashboard/wholesaler_dashboard.dart';

class SignupUserPage1 extends StatefulWidget {
  const SignupUserPage1({super.key});

  @override
  State<SignupUserPage1> createState() => _SignupUserPage1State();
}

class _SignupUserPage1State extends State<SignupUserPage1> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _hasLoginError = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  // Email validation state
  bool _isEmailValidating = false;
  bool _isEmailValid = true;
  String? _emailValidationMessage;

  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  final AppleSignin _appleSignin = AppleSignin();

  @override
  void initState() {
    super.initState();
    // Add listener to email controller for real-time validation
    _emailController.addListener(_onEmailChanged);
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

  /// Handles Google Sign-In using the integrated googleAuthEndpoint
  /// This method uses the GoogleSignInProvider which communicates with
  /// the backend endpoint: /api/auth/google-auth-without-firebase
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });
    
    try {
      print('Starting Google sign-in process...');
      final provider = Provider.of<GoogleSignInProvider>(context, listen: false);
      final result = await provider.googleLogin();
      
      setState(() {
        _isGoogleLoading = false;
      });
      
      if (result != null) {
        print('Google sign-in successful, processing user data...');
        
        // Update UserProvider with user data and token
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(result['user']);
        userProvider.setToken(result['token']);
        
        final userData = result['user'] ?? {};
        final userType = userData['userType'] ?? 'user';
        
        print('User type detected: $userType');
        print('User data: ${userData['email']} - ${userData['fullName']}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Google sign-in successful!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Add a small delay to ensure Google Maps services are ready
        // This prevents crashes when navigating immediately after Google Sign-In
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to appropriate dashboard
        _navigateAfterLogin(userType, result);
      } else {
        print('Google sign-in was canceled or failed');
        // Don't show error message if user canceled
        if (provider.error != null && !provider.error!.contains('canceled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Google sign-in failed: ${provider.error}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error during Google sign-in: $e');
      setState(() {
        _isGoogleLoading = false;
      });
      
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Google sign-in error: ${e.toString().contains('Exception:') ? e.toString().split('Exception: ')[1] : e.toString()}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isAppleLoading = true;
    });
    try {
      final credential = await _appleSignin.getAppleCredential();
      setState(() {
        _isAppleLoading = false;
      });
      if (credential != null && credential['identityToken'] != null) {
        // Send the idToken to your backend
        final backendResponse = await AppleAuthService.appleLogin(credential['identityToken']!);
        if (backendResponse != null && backendResponse['status'] == 200) {
          final data = backendResponse['data'];
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(data['user']);
          userProvider.setToken(data['token']);
          final userType = data['user']['userType'] ?? 'user';
          _navigateAfterLogin(userType, data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(backendResponse?['message'] ?? 'Apple sign-in failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple sign-in failed: No ID token received'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAppleLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apple sign-in error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateAfterLogin(String userType, Map<String, dynamic> userData) {
    switch (userType) {
      case 'user':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: userData),
          ),
        );
        break;
      case 'company':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyDashboard(userData: userData),
          ),
        );
        break;
      case 'serviceProvider':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceproviderDashboard(userData: userData),
          ),
        );
        break;
      case 'wholesaler':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WholesalerDashboard(userData: userData),
          ),
        );
        break;
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserDashboard(userData: userData),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Screen size breakpoints
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth >= 360 && constraints.maxWidth < 600;
        final isLargeScreen = constraints.maxWidth >= 600;

        // Responsive font sizes
        double getTitleFontSize() {
          if (isSmallScreen) return 28;
          if (isMediumScreen) return 40;
          return 38;
        }

        // Using ResponsiveUtils for font sizes
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
                      height: whiteHeaderHeight,
                      child: WhiteHeader(
                        title: 'Sign Up',
                        onBackPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  // Custom Header with Progress Bar - fixed gap below white header
                  Positioned(
                    top: whiteHeaderHeight + headerGap,
                    left: 0,
                    right: 0,
                    child: CustomHeader(
                      currentPageIndex: 1,
                      totalPages: 4,
                      subtitle: 'User',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Sign Up Form
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

                          SizedBox(height: constraints.maxHeight * 0.01),

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
                              errorBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1.0,
                                ),
                              ),
                              focusedErrorBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1.0,
                                ),
                              ),
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

                          SizedBox(height: constraints.maxHeight * 0.01),

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

                          SizedBox(height: constraints.maxHeight * 0.01),

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
                                  width: 1.0,
                                ),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 1.0,
                                ),
                              ),
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

                          // Next Button
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SignupUserPage2(
                                          userData: {
                                            'fullName': _fullNameController.text,
                                            'email': _emailController.text,
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
                                    fontSize: ResponsiveUtils.getButtonFontSize(context),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.02),

                          // Login Instead Button
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LoginPage()),
                                );                              },
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.nunito(
                                    fontSize: ResponsiveUtils.getButtonFontSize(context) * 0.9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Log in',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                        decorationThickness: 2.0,
                                      ),
                                    ),
                                    TextSpan(text: ' instead'),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.01),

                          // Divider with "or"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(76),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getButtonFontSize(context) * 0.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withAlpha(76),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: constraints.maxHeight * 0.02),

                          // Social Login Buttons
                          // Google Sign-In uses the integrated googleAuthEndpoint: /api/auth/google-auth-without-firebase
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isGoogleLoading
                                  ? Container(
                                      width: constraints.maxWidth * 0.12,
                                      height: constraints.maxWidth * 0.12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: constraints.maxWidth * 0.06,
                                          height: constraints.maxWidth * 0.06,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05055A)),
                                          ),
                                        ),
                                      ),
                                    )
                                  : _buildSocialLoginButton(
                                      context,
                                      'assets/icons/google.png',
                                      constraints.maxWidth * 0.12,
                                      onPressed: _handleGoogleSignIn,
                                    ),
                              SizedBox(width: constraints.maxWidth * 0.05),
                              _isAppleLoading
                                  ? Container(
                                      width: constraints.maxWidth * 0.12,
                                      height: constraints.maxWidth * 0.12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: constraints.maxWidth * 0.06,
                                          height: constraints.maxWidth * 0.06,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05055A)),
                                          ),
                                        ),
                                      ),
                                    )
                                  : _buildSocialLoginButton(
                                      context,
                                      'assets/icons/apple.png',
                                      constraints.maxWidth * 0.12,
                                      onPressed: _handleAppleSignIn,
                                    ),
                            ],
                          ),
                        ],
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

  Widget _buildSocialLoginButton(BuildContext context, String iconPath, double size, {Function()? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
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
  _fullNameFocus.dispose();
  _emailFocus.dispose();
  super.dispose();
}
}