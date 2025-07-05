import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import './responsive_utils.dart';

class CustomHeader extends StatelessWidget {
  final int currentPageIndex;
  final int totalPages;

  final String subtitle;
  final VoidCallback onBackPressed;

  const CustomHeader({
    super.key,
    required this.currentPageIndex,
    this.totalPages = 4,
    required this.subtitle,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // User Type Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBackPressed,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: ResponsiveUtils.getSubtitleFontSize(context),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Adding an empty SizedBox with the same width as the back button
              // to ensure proper centering
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Progress Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            children: List.generate(
              totalPages,
                  (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < totalPages - 1 ? 12 : 0),
                  height: 10,
                  decoration: BoxDecoration(
                    color: index < currentPageIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}