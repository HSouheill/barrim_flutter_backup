import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_user/signup_user1.dart';
import 'signup_wholesaler/signup_wholesaler1.dart';
import  'signup_company/signup_company1.dart';
import 'service_provider/signup_serviceprovider1.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate responsive values
    final buttonWidth = screenWidth * 0.75; // 85% of screen width
    final buttonHeight = screenHeight * 0.06; // 8% of screen height
    final borderRadius = screenWidth * 0.16; // Responsive border radius
    final bottomSpacing = 10.0; // Fixed 20px from bottom
    
    // Calculate the height needed for all content
    final titleHeight = 40.0; // Approximate height for "Sign Up As:" text
    final buttonSpacing = screenHeight * 0.025; // 2.5% spacing between buttons
    final topPadding = screenHeight * 0.03; // 3% top padding
    
    final totalContentHeight = topPadding + titleHeight + (4 * buttonHeight) + (5 * buttonSpacing) + bottomSpacing;
    final bottomAreaHeight = totalContentHeight.clamp(screenHeight * 0.45, screenHeight * 0.65);
    
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),

          // Overlay Color (semi-transparent) over Background Image
          Positioned.fill(
            child: Container(
              color: const Color(0xFF05054F).withAlpha((0.77 * 255).toInt()),
            ),
          ),

          // Centered Title Text - Made responsive
          Positioned(
            left: screenWidth * 0.05, // 5% margin from left
            right: screenWidth * 0.05, // 5% margin from right
            top: screenHeight * 0.12, // Adjusted to give more space for bottom area
            child: Text(
              'Discover the best of your neighborhood with Barrim!',
              textAlign: TextAlign.start,
              style: GoogleFonts.nunito(
                fontSize: screenWidth > 400 ? 38 : 32,
                fontWeight: FontWeight.w700,
                height: 1.375,
                color: Colors.white,
              ),
            ),
          ),

          // Bottom White Area with Top-Right Border Radius - Made responsive
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: screenWidth,
              height: bottomAreaHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(borderRadius),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  children: [
                    SizedBox(height: topPadding),

                    Center(
                      child: Text(
                        'Sign Up As:',
                        style: GoogleFonts.nunito(
                          fontSize: screenWidth * 0.055, // Responsive font size
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF05055A),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: buttonSpacing),

                    // User Button
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupUserPage1()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).copyWith(
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                            elevation: MaterialStateProperty.all(0),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF0094FF),
                                Color(0xFF05055A),
                                Color(0xFF0094FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'User',
                              style: GoogleFonts.nunito(
                                fontSize: screenWidth * 0.050, // Responsive font size
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: buttonSpacing),

                    // Company Button
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupCompany1()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          elevation: MaterialStateProperty.all(0),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF0094FF),
                                Color(0xFF05055A),
                                Color(0xFF0094FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Company',
                              style: GoogleFonts.nunito(
                                fontSize: screenWidth * 0.050,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: buttonSpacing),

                    // Service Provider Button
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupServiceprovider1()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          elevation: MaterialStateProperty.all(0),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF0094FF),
                                Color(0xFF05055A),
                                Color(0xFF0094FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Service Provider',
                              style: GoogleFonts.nunito(
                                fontSize: screenWidth * 0.050,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: buttonSpacing),

                    // Wholesaler Button
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupWholesalerPage1()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.all(Colors.transparent),
                          elevation: MaterialStateProperty.all(0),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF0094FF),
                                Color(0xFF05055A),
                                Color(0xFF0094FF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Wholesaler',
                              style: GoogleFonts.nunito(
                                fontSize: screenWidth * 0.050,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Fixed bottom padding only after the last button
                  ],
                  
                ),
                
              ),
              
            ),
            
          ),
        ],
      ),
    );
  }
}
