import 'package:flutter/material.dart';

class CategoryCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCircleButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100, // Fixed height for all buttons
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, // Slightly smaller to fit better
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF0094FF),
                    Color(0xFF05055A),
                    Color(0xFF0094FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28, // Slightly smaller icon
              ),
            ),
            const SizedBox(height: 2), // Reduced spacing
            SizedBox(
              height: 38, // Fixed height for text area to prevent overflow
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF0094FF),
                    Color(0xFF05055A),
                    Color(0xFF0094FF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: _buildLabelText(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelText() {
    // Check if label contains multiple words or is too long
    final words = label.split(' ');
    final hasMultipleWords = words.length > 1;
    final isLongText = label.length > 10;
    
    if (hasMultipleWords || isLongText) {
      // Display each word on a new line with very compact spacing
      return Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
        mainAxisSize: MainAxisSize.min,
        children: words.map((word) {
          return Text(
            word,
            style: const TextStyle(
              fontSize: 10, // Even smaller font for multi-word labels
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 0.9, // Very tight line spacing
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }).toList(),
      );
    } else {
      // Single word - display normally
      return Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11, // Slightly smaller for consistency
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.1, // Slightly tighter line spacing
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }
}