// Updated login_page.dart implementation for Google sign-in

import 'package:barrim/src/features/authentication/screens/serviceProvider_dashboard/serviceProvider_dashboard.dart';
import 'package:barrim/src/features/authentication/screens/user_dashboard/home.dart';
import 'package:barrim/src/features/authentication/screens/wholesaler_dashboard/wholesaler_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/signup.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/services/apple_auth_service.dart';
import './forgot_password/forgot_password.dart';
import 'package:barrim/src/services/google_auth_service.dart';
import 'package:provider/provider.dart';
import 'package:barrim/src/features/authentication/screens/company_dashboard/company_dashboard.dart';
import 'package:barrim/src/services/user_provider.dart'; // Import UserProvider
import 'package:barrim/src/features/authentication/screens/apple_signin.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import './countrycode_dropdown.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _hasLoginError = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false; // Track Google loading state separately
  String _errorMessage = 'Incorrect credentials or password!';
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _countryCode = '+961'; // Default country code
  bool _isPhoneNumber = false; // Track if user is entering phone number

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _hasLoginError = false;
      });

      try {
        String loginIdentifier = _emailOrPhoneController.text.trim();
        
        // If it's a phone number, prepend the country code
        if (_isPhoneNumber) {
          loginIdentifier = _countryCode + loginIdentifier;
        }

        final response = await ApiService.login(
          loginIdentifier,
          _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        // Debug print to see the actual response structure
        print("Login response: $response");

        // Check for successful response
        if (response['message'] == 'Login successful') {
          // Get the userType from the correct path in the response
          final userData = response['data'] ?? {};
          final user = userData['user'] ?? {};
          final userType = user['userType'] ?? 'user';

          // Update UserProvider
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(user);
          userProvider.setToken(userData['token']);

          print("User type detected: $userType");
          _navigateAfterLogin(userType, userData);
        }
      } catch (e) {
        print("Login error: $e");
        setState(() {
          _isLoading = false;
          _hasLoginError = true;
          String errorMsg = e.toString();
          if (errorMsg.contains('Exception:')) {
            errorMsg = errorMsg.split('Exception: ')[1];
          }
          // If the error is an HTML response or contains 502, show a friendly message
          if (errorMsg.trim().startsWith('<html>') || errorMsg.contains('502 Bad Gateway')) {
            _errorMessage = 'Server error, please try again later.';
          } else {
            _errorMessage = errorMsg;
          }
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(_errorMessage),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    }
  }

  void _onEmailOrPhoneChanged() {
    final value = _emailOrPhoneController.text.trim();
    final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
    final isPhone = RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''));
    
    setState(() {
      _isPhoneNumber = !isEmail && isPhone;
    });
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isGoogleLoading = true;
      });

      final provider = Provider.of<GoogleSignInProvider>(context, listen: false);
      final result = await provider.googleLogin();

      setState(() {
        _isGoogleLoading = false;
      });

      if (result != null) {
        print("Google sign-in successful, navigating to dashboard");

        // Update UserProvider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(result['user']);
        userProvider.setToken(result['token']);

        final userData = result['user'] ?? {};
        final userType = userData['userType'] ?? 'user';

        // Show success message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Google sign-in successful!'),
        //     backgroundColor: Colors.green,
        //   ),
        // );

        // Navigate based on user type
        _navigateAfterLogin(userType, result);
      } else if (provider.error != null) {
        print("Google sign-in error: ${provider.error}");

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Google sign-in failed: ${provider.error}'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } catch (e) {
      setState(() {
        _isGoogleLoading = false;
      });

      print("Unexpected error during Google sign-in: $e");

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('An unexpected error occurred: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  void _navigateAfterLogin(String userType, Map<String, dynamic> userData) {
    // Navigate based on user type
    print("Navigating to dashboard for user type: $userType");

    switch (userType) {
      case 'user':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Home(userData: userData),
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
            builder: (context) => Home(userData: userData),
          ),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _emailOrPhoneController.addListener(_onEmailOrPhoneChanged);
  }

  @override
  Widget build(BuildContext context){
    final applesignin = AppleSignin();
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

                  // White Top Area
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: constraints.maxHeight * 0.19,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(63),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Back Button
                          Positioned(
                            top: 40,
                            left: 20,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                                size: isSmallScreen ? 30 : 40,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),

                          // Login Text
                          Positioned(
                            top: 103,
                            left: 33,
                            right: 0,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                'Login',
                                style: GoogleFonts.nunito(
                                  fontSize: getTitleFontSize(),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF05054F),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Login Form
                  Positioned(
                    left: 24,
                    right: 24,
                    top: constraints.maxHeight * 0.25,
                    bottom: 0,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Email/Phone Input
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _emailOrPhoneController,
                                decoration: InputDecoration(
                                  labelText: 'Email or Phone Number',
                                  labelStyle: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: getInputFontSize(),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _hasLoginError ? Colors.red : Colors.white.withAlpha(128),
                                      width: _hasLoginError ? 2.0 : 1.0,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _hasLoginError ? Colors.red : Colors.white.withAlpha(204),
                                      width: _hasLoginError ? 2.0 : 1.0,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: getInputFontSize() * 0.8,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email or phone number';
                                  }
                                  // Check if input is email or phone number
                                  final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
                                  // Updated phone regex to be more lenient
                                  final isPhone = RegExp(r'^(\+?[0-9]{8,15}|[0-9]{8,15})$').hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''));
                                  if (!isEmail && !isPhone) {
                                    return 'Please enter a valid email or phone number (e.g., +96170123456 or 70123456)';
                                  }
                                  return null;
                                },
                              ),
                              // Show country code dropdown when phone number is detected
                              if (_isPhoneNumber)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Country Code: ',
                                        style: GoogleFonts.nunito(
                                          color: Colors.white,
                                          fontSize: getInputFontSize() * 0.7,
                                        ),
                                      ),
                                      CountryCodeDropdown(
                                        initialValue: _countryCode,
                                        textFontSize: getInputFontSize() * 0.8,
                                        onChanged: (value) {
                                          setState(() {
                                            _countryCode = value;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: constraints.maxHeight * 0.02),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: getInputFontSize(),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _hasLoginError ? Colors.red : Colors.white.withAlpha(128),
                                  width: _hasLoginError ? 2.0 : 1.0,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _hasLoginError ? Colors.red : Colors.white.withAlpha(204),
                                  width: _hasLoginError ? 2.0 : 1.0,
                                ),
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
                              fontSize: getInputFontSize() * 0.8,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          // Add Forgot Password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ForgotPasswordPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: getInputFontSize() * 0.8,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),

                          // Error Text
                          if (_hasLoginError)
                            Padding(
                              padding: const EdgeInsets.only(top: 0),
                              child: Text(
                                _errorMessage,
                                style: GoogleFonts.nunito(
                                  color: Colors.red,
                                  fontSize: getInputFontSize() * 0.7,
                                ),
                              ),
                            ),

                          SizedBox(height: constraints.maxHeight * 0.05),

                          // Login Button
                          Center(
                            child: Container(
                              width: constraints.maxWidth * 0.7,
                              height: constraints.maxHeight * 0.07,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0094FF),
                                    const Color(0xFF05055A),
                                    const Color(0xFF0094FF),
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
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                  'Log in',
                                  style: GoogleFonts.nunito(
                                    fontSize: getButtonFontSize(),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Sign Up Instead
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignUp()),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.nunito(
                                    fontSize: getButtonFontSize(),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Sign Up',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                        decorationThickness: 2.5,
                                      ),
                                    ),
                                    TextSpan(text: ' instead'),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Divider
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
                                    fontSize: getButtonFontSize() * 1,
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

                          SizedBox(height: constraints.maxHeight * 0.03),

                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google Login Button with loading indicator
                              _isGoogleLoading
                                  ? Container(
                                width: constraints.maxWidth * 0.13,
                                height: constraints.maxWidth * 0.13,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: constraints.maxWidth * 0.07,
                                    height: constraints.maxWidth * 0.07,
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
                                constraints.maxWidth * 0.11,
                                onPressed: _handleGoogleSignIn,
                              ),
                              SizedBox(width: constraints.maxWidth * 0.05),
                              // Apple Login Button
                              _buildSocialLoginButton(
                                context,
                                'assets/icons/apple.png',
                                constraints.maxWidth * 0.11,
                                onPressed: () async {
                                  try {
                                    final credential = await SignInWithApple.getAppleIDCredential(
                                      scopes: [
                                        AppleIDAuthorizationScopes.email,
                                        AppleIDAuthorizationScopes.fullName,
                                      ],
                                      webAuthenticationOptions: Platform.isAndroid
                                          ? WebAuthenticationOptions(
                                              clientId: 'YOUR_SERVICE_ID', // TODO: Replace with your Apple Service ID
                                              redirectUri: Uri.parse('YOUR_REDIRECT_URI'), // TODO: Replace with your redirect URI
                                            )
                                          : null,
                                    );
                                    final idToken = credential.identityToken;
                                    if (idToken == null) {
                                      setState(() {
                                        _hasLoginError = true;
                                        _errorMessage = 'Apple sign-in failed: No ID token received.';
                                      });
                                      return;
                                    }
                                    // Send the idToken to your backend
                                    final backendResponse = await AppleAuthService.appleLogin(idToken);
                                    if (backendResponse != null && backendResponse['status'] == 200) {
                                      final data = backendResponse['data'];
                                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                                      userProvider.setUser(data['user']);
                                      userProvider.setToken(data['token']);
                                      final userType = data['user']['userType'] ?? 'user';
                                      _navigateAfterLogin(userType, data);
                                    } else {
                                      setState(() {
                                        _hasLoginError = true;
                                        if (backendResponse?['message']?.contains('Invalid or expired token') == true) {
                                          _errorMessage = 'Unable to sign in with Apple';
                                        } else {
                                          _errorMessage = backendResponse?['message'] ?? 'Apple login failed';
                                        }
                                      });
                                    }
                                  } catch (e) {
                                    print("Apple sign-in error: $e");
                                    // Suppress error display if user canceled the Apple sign-in
                                    if (e.toString().contains('AuthorizationErrorCode.canceled')) {
                                      // Do not set _hasLoginError or _errorMessage
                                      return;
                                    }
                                    setState(() {
                                      _hasLoginError = true;
                                      if (e.toString().contains('Invalid or expired token')) {
                                        _errorMessage = 'Unable to sign in with Apple';
                                      } else {
                                        _errorMessage = 'Apple sign-in error: $e';
                                      }
                                    });
                                  }
                                },
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
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
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
    );
  }

  @override
  void dispose() {
    _emailOrPhoneController.removeListener(_onEmailOrPhoneChanged);
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}