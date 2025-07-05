import 'package:barrim/src/features/authentication/screens/responsive_utils.dart';
import 'package:barrim/src/features/authentication/screens/white_headr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barrim/src/features/authentication/screens/login_page.dart';
import 'package:barrim/src/services/api_service.dart';
import 'package:barrim/src/features/authentication/screens/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback? onVerificationSuccess;

  const OtpVerificationScreen({
    Key? key,
    required this.phoneNumber,
    this.onVerificationSuccess,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
        (index) => FocusNode(),
  );
  bool _isLoading = false;
  bool _isResending = false;

  // Get last three digits of phone number
  String get _lastThreeDigits {
    if (widget.phoneNumber.length >= 3) {
      return widget.phoneNumber.substring(widget.phoneNumber.length - 3);
    }
    return widget.phoneNumber;
  }

  @override
  void initState() {
    super.initState();

    // Set up focus listeners
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _otpControllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpControllers[i].text.length,
          );
        }
      });
    }
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Move to next field
      if (index < _otpControllers.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Please enter the complete OTP'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      final response = await apiService.smsverifyOtp(
        phone: widget.phoneNumber,
        otp: otp,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Navigate to WelcomePage only on successful verification
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WelcomePage(),
          ),
        );
      } else {
        // Show error message for incorrect OTP
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response['message'] ?? 'Invalid verification code'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } catch (error) {
      if (!mounted) return;
      
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Error verifying OTP: ${error.toString()}'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending) return; // Prevent multiple calls

    setState(() {
      _isResending = true;
    });

    try {
      // Create ApiService instance and call resend OTP
      final apiService = ApiService();
      final response = await apiService.resendOtp(
        phone: widget.phoneNumber,
      );

      if (mounted) {
        if (response['success'] == true) {
          // Show success message
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('OTP resent successfully'),
          //     backgroundColor: Colors.green,
          //   ),
          // );
        } else {
          // Show error message
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(response['message'] ?? 'Failed to resend OTP'),
          //     backgroundColor: Colors.red,
          //   ),
          // );
        }
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to resend OTP: ${e.toString()}'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
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
                    title: 'Verify Account',
                    onBackPressed: () => Navigator.of(context).pop(),
                  ),

                  // Form Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),

                            // OTP Phone Icon
                            Container(
                              child: Center(
                                child: Image.asset(
                                  'assets/images/otp.png',
                                  width: 150,
                                  height: 150,
                                  // Fallback if image is not available
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.phone_android,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Instruction Text
                            Text(
                              "Enter Verification code",
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.getSubtitleFontSize(context),
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 16),

                            // Subtitle with constrained width
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              child: Text(
                                "A message with an OTP was sent to your phone number ending with $_lastThreeDigits",
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // OTP Input Fields
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                6,
                                (index) {
                                  // Calculate responsive width and spacing
                                  final screenWidth = MediaQuery.of(context).size.width;
                                  // Calculate total available width for blocks (accounting for padding)
                                  final availableWidth = screenWidth - (MediaQuery.of(context).padding.left + MediaQuery.of(context).padding.right + 20); // 20 for container padding
                                  // Calculate block width ensuring all 6 blocks fit with spacing
                                  final blockWidth = ((availableWidth - (5 * 4)) / 6).clamp(35.0, 45.0); // 5 spaces between 6 blocks, min spacing 4
                                  final spacing = 4.0; // Fixed small spacing to prevent overflow
                                  
                                  return Container(
                                    width: blockWidth,
                                    height: blockWidth * 1.4, // Maintain aspect ratio
                                    margin: EdgeInsets.symmetric(horizontal: spacing / 2), // Half spacing on each side
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: TextFormField(
                                        controller: _otpControllers[index],
                                        focusNode: _focusNodes[index],
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.nunito(
                                          color: Colors.white,
                                          fontSize: blockWidth * 0.44, // Responsive font size
                                          fontWeight: FontWeight.bold,
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(1),
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onChanged: (value) => _onOtpDigitChanged(index, value),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Resend OTP Link (Moved to left)
                            Padding(
                              padding: EdgeInsets.only(
                                left: MediaQuery.of(context).size.width * 0.70,
                              ),
                              child: TextButton(
                                onPressed: _isResending ? null : _resendOtp,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: _isResending
                                    ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Resending...",
                                      style: GoogleFonts.nunito(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                    : Text(
                                  "Resend OTP",
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Next Button
                            Container(
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
                                onPressed: _isLoading ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                  'Next',
                                  style: GoogleFonts.nunito(
                                    fontSize: ResponsiveUtils.getButtonFontSize(context),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
    // Dispose all controllers and focus nodes
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}