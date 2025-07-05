import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double getButtonFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 32.0; // Large tablets/desktop
    } else if (screenWidth > 900) {
      return 28.0; // Medium tablets
    } else if (screenWidth > 600) {
      return 24.0; // Small tablets
    } else if (screenWidth > 400) {
      return 20.0; // Medium phones
    } else {
      return 18.0; // Small phones
    }
  }

  static double getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 42.0;
    } else if (screenWidth > 900) {
      return 38.0;
    } else if (screenWidth > 600) {
      return 34.0;
    } else if (screenWidth > 400) {
      return 30.0;
    } else {
      return 26.0;
    }
  }

  static double getInputTextFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 24.0;
    } else if (screenWidth > 900) {
      return 22.0;
    } else if (screenWidth > 600) {
      return 20.0;
    } else if (screenWidth > 400) {
      return 18.0;
    } else {
      return 16.0;
    }
  }

  static double getInputLabelFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 30.0;
    } else if (screenWidth > 900) {
      return 28.0;
    } else if (screenWidth > 600) {
      return 26.0;
    } else if (screenWidth > 400) {
      return 24.0;
    } else {
      return 22.0;
    }
  }

  static double getTitleFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 48.0;
    } else if (screenWidth > 900) {
      return 44.0;
    } else if (screenWidth > 600) {
      return 40.0;
    } else if (screenWidth > 400) {
      return 36.0;
    } else {
      return 32.0;
    }
  }

  static double getSubtitleFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 36.0;
    } else if (screenWidth > 900) {
      return 34.0;
    } else if (screenWidth > 600) {
      return 30.0;
    } else if (screenWidth > 400) {
      return 28.0;
    } else {
      return 24.0;
    }
  }

  // New responsive utility methods
  static double getCardPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 32.0;
    } else if (screenWidth > 900) {
      return 28.0;
    } else if (screenWidth > 600) {
      return 24.0;
    } else {
      return 16.0;
    }
  }

  static double getGridSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 24.0;
    } else if (screenWidth > 900) {
      return 20.0;
    } else if (screenWidth > 600) {
      return 16.0;
    } else {
      return 12.0;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 4;
    } else if (screenWidth > 900) {
      return 3;
    } else if (screenWidth > 600) {
      return 2;
    } else {
      return 2;
    }
  }

  static double getBranchImageHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 180.0;
    } else if (screenWidth > 900) {
      return 160.0;
    } else if (screenWidth > 600) {
      return 140.0;
    } else {
      return 100.0;
    }
  }

  static double getActionButtonHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 72.0;
    } else if (screenWidth > 900) {
      return 64.0;
    } else if (screenWidth > 600) {
      return 56.0;
    } else {
      return 48.0;
    }
  }

  static double getActionButtonFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return 24.0;
    } else if (screenWidth > 900) {
      return 22.0;
    } else if (screenWidth > 600) {
      return 20.0;
    } else {
      return 16.0;
    }
  }
}