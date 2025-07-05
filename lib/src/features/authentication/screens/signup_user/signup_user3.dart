import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import 'signup_user4.dart'; // Assuming next page is SignupUserPage4
import '../responsive_utils.dart';
class SignupUserPage3 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupUserPage3({super.key, required this.userData});

  @override
  _SignupUserPage3State createState() => _SignupUserPage3State();
}

class _SignupUserPage3State extends State<SignupUserPage3> {
  final List<String> dealOptions = [
    'Restaurant',
    'Sport',
    'Real State',
    'Shopping',
    'Healthcare',
    'Education',
    'Construction',
    'Hospitality',
    'Transportation',
    'Technology',
  ];

  List<String> selectedDeals = [];

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

                          // Sign Up Text
                          Positioned(
                            top: 103,
                            left: 33,
                            right: 0,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.nunito(
                                  fontSize: ResponsiveUtils.getTitleFontSize(context),
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

                  // Custom Header with Progress Bar
                  Positioned(
                    top: constraints.maxHeight * 0.20, // Position right after the white header
                    left: 0,
                    right: 0,
                    child: CustomHeader(
                      currentPageIndex: 3,
                      totalPages: 4,
                      subtitle: 'User',
                      onBackPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Deals Selection Area
                  Positioned(
                    left: 24,
                    right: 24,
                    top: constraints.maxHeight * 0.30, // Adjusted position
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Type of deals" heading
                        Text(
                          'Type of deals',
                          style: GoogleFonts.nunito(
                            fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        // Subheading text
                        Text(
                          'Enter the type of deals you are interested in.',
                          style: GoogleFonts.nunito(
                            fontSize: ResponsiveUtils.getSubtitleFontSize(context),
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),

                        SizedBox(height: constraints.maxHeight * 0.03),

                        // Grid of deal options
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: dealOptions.length,
                            itemBuilder: (context, index) {
                              final deal = dealOptions[index];
                              final isSelected = selectedDeals.contains(deal);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedDeals.remove(deal);
                                    } else {
                                      selectedDeals.add(deal);
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0094FF)
                                          : Colors.white.withOpacity(0.6),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isSelected
                                        ? const Color(0xFF0094FF).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      deal,
                                      style: GoogleFonts.nunito(
                                        fontSize: ResponsiveUtils.getInputTextFontSize(context),
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Sign Up Button
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: constraints.maxHeight * 0.05,
                            top: constraints.maxHeight * 0.02,
                          ),
                          child: Center(
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
                                  // Save selected deals to userData
                                  final updatedUserData = {
                                    ...widget.userData,
                                    'selectedDeals': selectedDeals,
                                  };
                                  // Navigate to next page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignupUserPage4(userData: updatedUserData),
                                    ),
                                  );
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
                                    fontSize: ResponsiveUtils.getButtonFontSize(context),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
}