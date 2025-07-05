import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart' as cp;

class CountryCodeDropdown extends StatefulWidget {
  final Function(String) onChanged;
  final String initialValue;
  final double textFontSize;

  const CountryCodeDropdown({
    Key? key,
    required this.onChanged,
    required this.initialValue,
    required this.textFontSize,
  }) : super(key: key);

  @override
  State<CountryCodeDropdown> createState() => _CountryCodeDropdownState();
}

class _CountryCodeDropdownState extends State<CountryCodeDropdown> {
  late String _selectedCode;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.initialValue;
  }

  void _showCountryPicker() {
    cp.showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: cp.CountryListThemeData(
        borderRadius: BorderRadius.circular(8.0),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          labelStyle: GoogleFonts.nunito(
            color: Colors.white70,
            fontSize: widget.textFontSize * 0.8,
          ),
          hintStyle: GoogleFonts.nunito(
            color: Colors.white54,
            fontSize: widget.textFontSize * 0.8,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF05054F),
        ),
        backgroundColor: const Color(0xFF05054F),
        textStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: widget.textFontSize * 0.8,
        ),
        searchTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: widget.textFontSize * 0.8,
        ),
      ),
      onSelect: (cp.Country country) {
        setState(() {
          _selectedCode = '+${country.phoneCode}';
          _isDropdownOpen = false;
        });
        widget.onChanged(_selectedCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: GestureDetector(
        onTap: _showCountryPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 1.0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Country code
              Text(
                _selectedCode,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: widget.textFontSize,
                ),
              ),
              const SizedBox(width: 4),
              // Arrow icon
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}