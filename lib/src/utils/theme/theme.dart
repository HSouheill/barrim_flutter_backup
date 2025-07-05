import 'package:barrim/src/utils/theme/widgets_theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  AppTheme._();
  static ThemeData lightTheme = ThemeData(brightness: Brightness.light,
  textTheme: textTheme.lightTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom()),
  );
  static ThemeData darkTheme = ThemeData(brightness: Brightness.dark,
  textTheme: textTheme.darkTextTheme,
      // elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom()),
  );


}