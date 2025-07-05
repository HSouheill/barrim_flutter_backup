import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import '../../../../services/api_service.dart';
import '../white_headr.dart';
import 'send_otp.dart';
import '../responsive_utils.dart';

class ResetPassword extends StatefulWidget {
  final String userId;
  final String resetToken;

  const ResetPassword({
    super.key,
    required this.userId,
    required this.resetToken,
  });

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _hasLoginError = false; // State variable to track login errors
  final TextEditingController _passwordController = TextEditingController();
  bool _isConfirmPasswordVisible = false;
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Call API to reset password
        await ApiService.resetPassword(
          widget.userId,
          widget.resetToken,
          _passwordController.text.trim(),
        );

        // Show success message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Password reset successfully!'),
        //     backgroundColor: Colors.green,
        //   ),
        // );

        // Navigate to login page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to reset password: \\${e.toString()}'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
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

              // Content
              Column(
                children: [
                  // White Header
                  WhiteHeader(
                    title: 'Password Reset',

                    onBackPressed: () => Navigator.of(context).pop(),
                  ),

                  // Form Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),

                            // Instruction Text
                            Text(
                              "Set a new password",
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,


                            ),

                            Text(
                              "Password must be at least 8 characters.",
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 30),



                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputLabelFontSize(context) ,
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _hasLoginError ? Colors.red : Colors.white.withAlpha(128),
                                    width: _hasLoginError ? 2.0 : 1.0, // Thicker when error
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _hasLoginError ? Colors.red : Colors.white.withAlpha(204),
                                    width: _hasLoginError ? 2.0 : 1.0, // Thicker when error
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
                                fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 32),



                            // Confirm Password Input
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                labelStyle: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.getInputLabelFontSize(context) ,
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

                            const SizedBox(height: 32),


                            // Reset Password Button
                            Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 66,
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
                                  onPressed: _isLoading ? null : _resetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                   child: Text(
                                    'Reset Password',
                                    style: GoogleFonts.nunito(
                                      fontSize: ResponsiveUtils.getButtonFontSize(context),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Back to Login Link
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Back to ',
                                    style: GoogleFonts.nunito(
                                      fontSize: ResponsiveUtils.getInputLabelFontSize(context) *0.9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Log In',
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                          decorationThickness: 1.5,
                                        ),
                                      ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}