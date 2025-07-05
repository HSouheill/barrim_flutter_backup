import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../verification_code.dart';
import '../white_headr.dart';
import '../responsive_utils.dart';
import '../welcome_page.dart';
import '../../../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class SignupServiceprovider4 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupServiceprovider4({super.key, required this.userData});

  @override
  _SignupServiceprovider4State createState() => _SignupServiceprovider4State();
}

class _SignupServiceprovider4State extends State<SignupServiceprovider4> {
  final List<String> _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  final List<String> _fullWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // Calendar state variables
  DateTime _currentDate = DateTime.now();
  Map<String, List<int>> _selectedDaysPerMonth = {};
  List<int> _selectedWeekdays = []; // Store weekday indices (1=Monday, 7=Sunday)
  String _startTime = 'From';
  String _endTime = 'Till';
  bool _agreeToTerms = false;
  bool _applyToAllMonths = false;
  Map<int, bool> _firstMonthWeekdayPattern = {}; // Stores which weekdays are selected in first month

  @override
  void initState() {
    super.initState();
    // Initialize with current month and day 1 selected
    String monthKey = _getMonthKey(_currentDate);
    _selectedDaysPerMonth[monthKey] = [1];

    // Initialize the weekday for day 1
    DateTime firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    _selectedWeekdays = [firstDay.weekday]; // Add the weekday of the 1st

    // Initialize the weekday pattern for the first month
    for (int i = 1; i <= 7; i++) {
      _firstMonthWeekdayPattern[i] = i == firstDay.weekday;
    }
  }

  // Get consistent month key format for the map
  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  // Format the month display string
  String _formatMonth(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  // Get the first day of the month (0=Monday, 6=Sunday in our UI)
  int _getFirstDayOfMonthIndex() {
    final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    // Convert from DateTime day (1=Monday, 7=Sunday) to our index (0=Monday, 6=Sunday)
    return (firstDay.weekday - 1) % 7;
  }

  // Get days in the current month
  int _getDaysInMonth() {
    return DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
  }

  // Generate days for the previous month that show in the calendar
  List<int> _generatePrevMonthDays() {
    final firstDayIndex = _getFirstDayOfMonthIndex();
    if (firstDayIndex == 0) return []; // No previous month days needed

    final prevMonth = DateTime(_currentDate.year, _currentDate.month, 0);
    final daysInPrevMonth = prevMonth.day;

    // Return the last few days of the previous month
    return List.generate(
        firstDayIndex,
            (index) => daysInPrevMonth - firstDayIndex + index + 1
    );
  }

  // Generate days for the current month
  List<int> _generateDaysInMonth() {
    return List.generate(_getDaysInMonth(), (index) => index + 1);
  }

  // Generate days for the next month that show in the calendar
  List<int> _generateNextMonthDays() {
    final daysInMonth = _getDaysInMonth();
    final firstDayIndex = _getFirstDayOfMonthIndex();

    // Calculate how many cells are already filled
    final filledCells = firstDayIndex + daysInMonth;

    // Calculate how many next month days we need to complete the grid
    // We want to display up to 42 days (6 weeks)
    final remainingCells = 42 - filledCells;

    if (remainingCells <= 0) return [];

    return List.generate(remainingCells, (index) => index + 1);
  }

  // Change month in the calendar
  void _changeMonth(int delta) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);

      // Initialize the new month with empty selection if not existing
      String monthKey = _getMonthKey(_currentDate);
      _selectedDaysPerMonth.putIfAbsent(monthKey, () => []);

      // If apply to all months is enabled, apply first month pattern to this month
      if (_applyToAllMonths) {
        _applyFirstMonthPatternToCurrentMonth();
      }
    });
  }

  // Apply first month weekday pattern to the current month
  void _applyFirstMonthPatternToCurrentMonth() {
    final monthKey = _getMonthKey(_currentDate);
    final daysInMonth = _getDaysInMonth();

    // Clear current month selection
    _selectedDaysPerMonth[monthKey] = [];

    // Select all days in the current month that match the selected pattern from first month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentDate.year, _currentDate.month, day);
      if (_firstMonthWeekdayPattern[date.weekday] == true) {
        _selectedDaysPerMonth[monthKey]!.add(day);
      }
    }
  }

  // Update the first month weekday pattern based on selections
  void _updateFirstMonthPattern() {
    // Get the first month in our data
    final firstMonthKey = _getMonthKey(DateTime.now());
    final firstMonthSelectedDays = _selectedDaysPerMonth[firstMonthKey] ?? [];

    // Reset pattern
    for (int i = 1; i <= 7; i++) {
      _firstMonthWeekdayPattern[i] = false;
    }

    // For each selected day in first month, mark its weekday as true in pattern
    for (final day in firstMonthSelectedDays) {
      final date = DateTime(DateTime.now().year, DateTime.now().month, day);
      _firstMonthWeekdayPattern[date.weekday] = true;
    }
  }

  // Handle day selection
  void _selectDay(int day) {
    setState(() {
      final monthKey = _getMonthKey(_currentDate);
      final date = DateTime(_currentDate.year, _currentDate.month, day);
      final weekday = date.weekday; // 1=Monday, 7=Sunday

      // Initialize the month if not already in the map
      _selectedDaysPerMonth.putIfAbsent(monthKey, () => []);

      // Toggle individual day selection
      if (_selectedDaysPerMonth[monthKey]!.contains(day)) {
        _selectedDaysPerMonth[monthKey]!.remove(day);
      } else {
        _selectedDaysPerMonth[monthKey]!.add(day);
      }

      // If we're on first month, update pattern and apply to all months if enabled
      if (monthKey == _getMonthKey(DateTime.now())) {
        _updateFirstMonthPattern();

        if (_applyToAllMonths) {
          _applyPatternToAllMonths();
        }
      }

      // Update the weekday selection based on the selected days in this month
      _updateWeekdaysFromSelectedDays();
    });
  }

  // Update the selectedWeekdays list based on the currently selected days
  void _updateWeekdaysFromSelectedDays() {
    final monthKey = _getMonthKey(_currentDate);
    final selectedDays = _selectedDaysPerMonth[monthKey] ?? [];

    // Clear weekday selection
    _selectedWeekdays = [];

    // For each selected day, add its weekday to the list if not already there
    for (final day in selectedDays) {
      final date = DateTime(_currentDate.year, _currentDate.month, day);
      if (!_selectedWeekdays.contains(date.weekday)) {
        _selectedWeekdays.add(date.weekday);
      }
    }
  }

  // Apply first month pattern to all future months
  void _applyPatternToAllMonths() {
    // Apply to 12 months starting from current month
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final monthDate = DateTime(now.year, now.month + i, 1);
      final monthKey = _getMonthKey(monthDate);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      // Skip the first month as it's our pattern source
      if (i == 0) continue;

      // Initialize empty list for this month
      _selectedDaysPerMonth[monthKey] = [];

      // Select all days that match the first month pattern
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(monthDate.year, monthDate.month, day);
        if (_firstMonthWeekdayPattern[date.weekday] == true) {
          _selectedDaysPerMonth[monthKey]!.add(day);
        }
      }
    }
  }

  // Toggle apply to all months
  void _toggleApplyToAllMonths() {
    setState(() {
      _applyToAllMonths = !_applyToAllMonths;

      if (_applyToAllMonths) {
        // First, ensure the pattern is up to date
        _updateFirstMonthPattern();
        // Then apply pattern to all months
        _applyPatternToAllMonths();
      }
    });
  }

  // Show time picker for start or end time
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay initialTime = isStartTime
        ? _startTime != 'From'
        ? TimeOfDay(
        hour: int.parse(_startTime.split(':')[0]),
        minute: int.parse(_startTime.split(':')[1]))
        : TimeOfDay(hour: 9, minute: 0)
        : _endTime != 'Till'
        ? TimeOfDay(
        hour: int.parse(_endTime.split(':')[0]),
        minute: int.parse(_endTime.split(':')[1]))
        : TimeOfDay(hour: 17, minute: 0);

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF009DFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        // Format time as HH:MM
        String hour = pickedTime.hour.toString().padLeft(2, '0');
        String minute = pickedTime.minute.toString().padLeft(2, '0');
        String formattedTime = '$hour:$minute';

        if (isStartTime) {
          _startTime = formattedTime;
        } else {
          _endTime = formattedTime;
        }
      });
    }
  }

  // Format availability data for API
  Map<String, dynamic> _formatAvailabilityData() {
    // Get actual time values, or use defaults if not selected
    final actualStartTime = _startTime != 'From' ? _startTime : '09:00';
    final actualEndTime = _endTime != 'Till' ? _endTime : '17:00';

    // Format the selected days data
    Map<String, List<String>> availabilityCalendar = {};
    List<String> availableDays = [];

    // Get weekday names for selected weekdays in first month pattern
    List<String> selectedWeekdayNames = [];
    _firstMonthWeekdayPattern.forEach((weekday, isSelected) {
      if (isSelected) {
        selectedWeekdayNames.add(_getWeekdayName(weekday));
      }
    });

    _selectedDaysPerMonth.forEach((monthKey, days) {
      List<String> formattedDays = days.map((day) {
        // Parse the month key to get year and month
        final parts = monthKey.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);

        // Format as ISO date string: YYYY-MM-DD
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        availableDays.add(dateStr);

        return dateStr;
      }).toList();

      availabilityCalendar[monthKey] = formattedDays;
    });

    return {
      'availabilityCalendar': availabilityCalendar,
      'availableHours': [actualStartTime, actualEndTime],
      'availableDays': availableDays,
      'applyToAllMonths': _applyToAllMonths,
      'availableWeekdays': _applyToAllMonths ? selectedWeekdayNames : [], // Include weekday names when apply to all months is enabled
    };
  }

  // Helper method to convert weekday number to name
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF05054F).withOpacity(0.77),
                ),
                WhiteHeader(title: 'Sign Up', onBackPressed: () => Navigator.pop(context)),
                SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.13),
                        CustomHeader(currentPageIndex: 4, totalPages: 4, subtitle: 'Service Provider', onBackPressed: () => Navigator.pop(context)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.02),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Availability Calendar',
                                      style: GoogleFonts.nunito(
                                        fontSize: ResponsiveUtils.getInputLabelFontSize(context) * 0.9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Select your preferred days and working hours.',
                                      style: GoogleFonts.nunito(
                                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15),
                              _buildCalendarCard(),
                              SizedBox(height: 15),
                              _buildTermsCheckbox(),
                              SizedBox(height: 15),
                              _buildSignUpButton(constraints),
                              SizedBox(height: 25),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to check if current displayed month is first month
  bool _isInFirstMonth() {
    final now = DateTime.now();
    return _currentDate.year == now.year && _currentDate.month == now.month;
  }

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            SizedBox(height: 12),
            _buildCalendarGrid(),
            SizedBox(height: 16),
            _buildTimeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatMonth(_currentDate),
          style: GoogleFonts.nunito(
            fontSize: ResponsiveUtils.getInputTextFontSize(context) ,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: _toggleApplyToAllMonths,
              child: Row(
                children: [
                  Icon(
                    _applyToAllMonths
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: _applyToAllMonths ? Color(0xFF009DFF) : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Apply for all months',
                    style: GoogleFonts.nunito(
                      fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.6,
                      color: _applyToAllMonths ? Color(0xFF009DFF) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 24, color: Colors.grey),
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 24, color: Colors.grey),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final monthKey = _getMonthKey(_currentDate);
    final selectedDays = _selectedDaysPerMonth[monthKey] ?? [];
    final prevMonthDays = _generatePrevMonthDays();
    final currentMonthDays = _generateDaysInMonth();
    final nextMonthDays = _generateNextMonthDays();

    // Determine if this is the first month (pattern source)
    final isFirstMonth = _isInFirstMonth();
    // Check if we should disable selections in non-first months when pattern is applied
    final disableSelection = _applyToAllMonths && !isFirstMonth;

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _weekdays.map((day) =>
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.nunito(
                      fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
          ).toList(),
        ),
        SizedBox(height: 10),
        // Calendar days grid
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.3,
          children: [
            // Previous month days
            ...prevMonthDays.map((day) =>
                Container(
                  margin: EdgeInsets.all(2),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.nunito(
                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
            ),

            // Current month days
            ...currentMonthDays.map((day) =>
                GestureDetector(
                  onTap: disableSelection ? null : () => _selectDay(day),
                  child: Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selectedDays.contains(day) ? Color(0xFF009DFF) : null,
                      borderRadius: BorderRadius.circular(5),
                      // Add subtle indicator for disabled cells
                      border: disableSelection ? Border.all(color: Colors.grey.withOpacity(0.2)) : null,
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: GoogleFonts.nunito(
                          fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                          color: selectedDays.contains(day) ? Colors.white :
                          disableSelection ? Colors.black.withOpacity(0.6) : Colors.black,
                          fontWeight: selectedDays.contains(day) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                )
            ),

            // Next month days
            ...nextMonthDays.map((day) =>
                Container(
                  margin: EdgeInsets.all(2),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.nunito(
                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: GoogleFonts.nunito(
            fontSize: ResponsiveUtils.getInputTextFontSize(context) ,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(context, true),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startTime,
                        style: GoogleFonts.nunito(
                          fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                          color: _startTime == 'From' ? Colors.grey : Colors.black,
                        ),
                      ),
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Text(
              '—',
              style: GoogleFonts.nunito(
                fontSize: ResponsiveUtils.getInputTextFontSize(context),
                color: Colors.black,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(context, false),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _endTime,
                        style: GoogleFonts.nunito(
                          fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.8,
                          color: _endTime == 'Till' ? Colors.grey : Colors.black,
                        ),
                      ),
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          fillColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              return Colors.white;
            },
          ),
          checkColor: Colors.blue,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(
                fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                color: Colors.white,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF05054F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              'Terms of Service & Privacy Policy',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Terms of Service',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. You must provide accurate and complete information during registration.\n'
                                    '2. You are responsible for maintaining the confidentiality of your account.\n'
                                    '3. You agree not to use the app for any unlawful or prohibited activities.\n'
                                    '4. We reserve the right to suspend or terminate accounts that violate our terms.\n'
                                    '5. The app and its content are provided as-is without warranties of any kind.',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. We collect personal information to provide and improve our services.\n'
                                    '2. Your data will not be shared with third parties except as required by law.\n'
                                    '3. We use industry-standard security measures to protect your information.\n'
                                    '4. You may request to access, update, or delete your personal data at any time.\n'
                                    '5. By using this app, you consent to our data practices as described.',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text(
                      'Terms of Service',
                      style: GoogleFonts.nunito(
                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                        color: Colors.blue[200],
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text: ' and ',
                  style: TextStyle(
                    decoration: TextDecoration.none,
                    color: Colors.white,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF05054F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              'Terms of Service & Privacy Policy',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Terms of Service',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. You must provide accurate and complete information during registration.\n'
                                    '2. You are responsible for maintaining the confidentiality of your account.\n'
                                    '3. You agree not to use the app for any unlawful or prohibited activities.\n'
                                    '4. We reserve the right to suspend or terminate accounts that violate our terms.\n'
                                    '5. The app and its content are provided as-is without warranties of any kind.',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. We collect personal information to provide and improve our services.\n'
                                    '2. Your data will not be shared with third parties except as required by law.\n'
                                    '3. We use industry-standard security measures to protect your information.\n'
                                    '4. You may request to access, update, or delete your personal data at any time.\n'
                                    '5. By using this app, you consent to our data practices as described.',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text(
                      'Privacy Policy',
                      style: GoogleFonts.nunito(
                        fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                        color: Colors.blue[200],
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(BoxConstraints constraints) {
    // Calculate responsive button size
    final buttonWidth = constraints.maxWidth * 0.7;
    final buttonHeight = MediaQuery.of(context).size.height * 0.07;

    return Center(
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
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
          onPressed: () async {
            if (_agreeToTerms) {
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  },
                );

                // Get formatted availability data
                final availabilityData = _formatAvailabilityData();

                // Extract logo file from userData
                final logoFile = widget.userData['logo'] as File?;

                // Create a new map without the logo file for JSON data
                final Map<String, dynamic> dataToSend = Map<String, dynamic>.from(widget.userData);
                dataToSend.remove('logo');

                // Combine all user data
                final completeUserData = {
                  ...dataToSend,
                  'userType': 'serviceProvider',
                  'serviceProviderInfo': {
                    'serviceType': widget.userData['serviceType'],
                    'yearsExperience': int.parse(widget.userData['yearsExperience'] ?? '1'),
                    'availableHours': availabilityData['availableHours'],
                    'availableDays': availabilityData['availableDays'],
                    'availableWeekdays': availabilityData['availableWeekdays'],
                    'availabilityCalendar': availabilityData['availabilityCalendar'],
                    'applyToAllMonths': availabilityData['applyToAllMonths'],
                  },
                  'location': widget.userData['location'],
                  'agreeToTerms': _agreeToTerms,
                };

                print('Sending service provider signup request...');
                print('Phone number: ${widget.userData['phone']}');
                
                // Create multipart request for signup with logo
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('${ApiService.baseUrl}/api/auth/signup-service-provider-with-logo'),
                );

                // Add headers
                request.headers.addAll({
                  'Content-Type': 'multipart/form-data',
                });

                // Add JSON data as a string field
                request.fields['userData'] = jsonEncode(completeUserData);

                // Add logo file if provided
                if (logoFile != null) {
                  var stream = http.ByteStream(logoFile.openRead());
                  var length = await logoFile.length();

                  var multipartFile = http.MultipartFile(
                    'logo',
                    stream,
                    length,
                    filename: path.basename(logoFile.path),
                    contentType: MediaType('image', _getImageMimeType(logoFile.path)),
                  );

                  request.files.add(multipartFile);
                }

                // Send the request
                var streamedResponse = await request.send();
                var signupResponse = await http.Response.fromStream(streamedResponse);

                print('Signup response status: ${signupResponse.statusCode}');
                print('Signup response body: ${signupResponse.body}');

                if (signupResponse.statusCode == 201 || signupResponse.statusCode == 200) {
                  // Close loading dialog
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  // Navigate directly to OTP verification since OTP was already sent
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtpVerificationScreen(
                          phoneNumber: widget.userData['phone'] ?? '',
                          onVerificationSuccess: () async {
                            if (mounted) {
                              // Navigate to welcome page
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const WelcomePage()),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }
                } else {
                  // Handle signup error
                  if (mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    final responseData = jsonDecode(signupResponse.body);
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   SnackBar(content: Text(responseData['message'] ?? 'Signup failed')),
                    // );
                  }
                }
              } catch (e) {
                print('==== SIGNUP ERROR ====');
                print(e.toString());
                print('=====================');

                // Close loading dialog if it's showing
                if (mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }

                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Error: ${e.toString()}')),
                // );
              }
            } else {
              print('User tried to sign up without agreeing to terms');
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text('Please agree to the Terms of Service and Privacy Policy')),
              // );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonHeight / 2),
            ),
          ),
          child: Text(
            'Sign Up',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: ResponsiveUtils.getButtonFontSize(context),
            ),
          ),
        ),
      ),
    );
  }

  String _getImageMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.gif':
        return 'gif';
      case '.webp':
        return 'webp';
      case '.bmp':
        return 'bmp';
      default:
        return 'octet-stream';
    }
  }
}