import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WhiteHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBackPressed;

  const WhiteHeader({
    Key? key,
    required this.title,
    this.subtitle,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = MediaQuery.of(context).size.height < 700;

        double getTitleFontSize() {
          if (isSmallScreen) {
            return 28;
          }
          return 36;
        }

        // Use a fixed height instead of percentage to prevent resizing with keyboard
        double headerHeight = isSmallScreen ? 150 : 170;

        return Container(
          height: headerHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(63),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0), // Add fixed space at top and bottom
            child: Stack(
              children: [
                // Back Button
                Positioned(
                  top: 24, // Adjusted for new padding
                  left: 20,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: isSmallScreen ? 30 : 40,
                    ),
                    onPressed: onBackPressed,
                  ),
                ),

                // Title Text
                Positioned(
                  top: subtitle != null ? 54 : 87, // Adjusted for new padding
                  left: 33,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      title,
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
        );
      },
    );
  }
}