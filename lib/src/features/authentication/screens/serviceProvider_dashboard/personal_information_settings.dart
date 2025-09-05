import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';

import '../../../../models/service_provider.dart';
import '../../../../services/service_provider_services.dart';
import '../../headers/service_provider_header.dart';


class ServiceProviderInfoPage extends StatefulWidget {
  const ServiceProviderInfoPage({Key? key}) : super(key: key);

  @override
  State<ServiceProviderInfoPage> createState() => _ServiceProviderInfoPageState();
}

class _ServiceProviderInfoPageState extends State<ServiceProviderInfoPage> {
  final ServiceProviderService _serviceProviderService = ServiceProviderService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  ServiceProvider? serviceProvider;
  bool isLoading = true;


  // Form controllers
  late TextEditingController _phoneController;
  late TextEditingController _serviceTypeController;
  late TextEditingController _yearsExperienceController;
  late TextEditingController _countryController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;
  late TextEditingController _streetController;
  late TextEditingController _postalCodeController;

  // Calendar-related variables
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // For multiple certification images
  List<File> _certificationImages = [];
  List<String> _certificationImagePaths = [];

  // For time selection
  List<TimeSlot> _timeSlots = [];

  // Available days for service (stored as date strings in YYYY-MM-DD format)
  List<String> _availableDays = [];

  // Service provider data
  ServiceProvider? _serviceProvider;

  // Location data
  Map<String, dynamic> _locationData = {};
  List<String> _countries = [];
  List<String> _districts = [];
  List<String> _cities = [];
  String? _selectedCountry;
  String? _selectedDistrict;
  String? _selectedCity;

  // For Lebanon-specific districts/cities
  List<String> _lebanonDistricts = [];
  List<String> _lebanonCities = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLocationData().then((_) {
      _loadServiceProviderData();
    });

    // Initialize with one empty time slot
    _timeSlots.add(TimeSlot(
        from: const TimeOfDay(hour: 9, minute: 0),
        to: const TimeOfDay(hour: 17, minute: 0)
    ));
  }

  void _initializeControllers() {
    _phoneController = TextEditingController();
    _serviceTypeController = TextEditingController();
    _yearsExperienceController = TextEditingController();
    _countryController = TextEditingController(text: 'Lebanon');
    _districtController = TextEditingController();
    _cityController = TextEditingController();
    _streetController = TextEditingController();
    _postalCodeController = TextEditingController();
  }

  Future<void> _loadLocationData() async {
    final String jsonString = await rootBundle.loadString('assets/countries_districts_cities.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    setState(() {
      _locationData = jsonData;
      _countries = jsonData.keys.toList();
    });
  }

  Future<void> _loadServiceProviderData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      print('Loading service provider data...');
      final provider = await _serviceProviderService.getServiceProviderData();
      print('Service provider data loaded successfully: ${provider.fullName}');
      
      setState(() {
        _serviceProvider = provider;
        isLoading = false;
        _phoneController.text = provider.phone ?? '';
        _serviceTypeController.text = provider.serviceProviderInfo?.serviceType ?? '';
        _yearsExperienceController.text =
            provider.serviceProviderInfo?.yearsExperience.toString() ?? '0';
        // Set location dropdowns from provider data
        _selectedCountry = provider.location?.country;
        if (_selectedCountry != null && _locationData.containsKey(_selectedCountry)) {
          _districts = (_locationData[_selectedCountry] as Map<String, dynamic>).keys.toList();
          _selectedDistrict = provider.location?.district;
          if (_selectedDistrict != null && (_locationData[_selectedCountry] as Map<String, dynamic>).containsKey(_selectedDistrict)) {
            _cities = List<String>.from((_locationData[_selectedCountry][_selectedDistrict] as List<dynamic>));
            _selectedCity = provider.location?.city;
          }
        }
        _districtController.text = provider.location?.district ?? '';
        _cityController.text = provider.location?.city ?? '';
        _streetController.text = provider.location?.street ?? '';
        _postalCodeController.text = provider.location?.postalCode ?? '';

        // Set available days if they exist
        if (provider.serviceProviderInfo?.availableDays != null) {
          _availableDays = provider.serviceProviderInfo!.availableDays!;
          print('Loaded availableDays: $_availableDays');
        }

        // Load available hours if they exist
        if (provider.serviceProviderInfo?.availableHours != null &&
            provider.serviceProviderInfo!.availableHours!.isNotEmpty) {
          _timeSlots.clear();
          for (String timeRange in provider.serviceProviderInfo!.availableHours!) {
            final parts = timeRange.split('-');
            if (parts.length == 2) {
              final fromParts = parts[0].trim().split(':');
              final toParts = parts[1].trim().split(':');

              if (fromParts.length == 2 && toParts.length == 2) {
                _timeSlots.add(TimeSlot(
                    from: TimeOfDay(
                        hour: int.tryParse(fromParts[0]) ?? 9,
                        minute: int.tryParse(fromParts[1]) ?? 0
                    ),
                    to: TimeOfDay(
                        hour: int.tryParse(toParts[0]) ?? 17,
                        minute: int.tryParse(toParts[1]) ?? 0
                    )
                ));
              }
            }
          }

          // If no valid time slots were loaded, add a default one
          if (_timeSlots.isEmpty) {
            _timeSlots.add(TimeSlot(
                from: const TimeOfDay(hour: 9, minute: 0),
                to: const TimeOfDay(hour: 17, minute: 0)
            ));
          }
        }
      });
      print('Service provider data loaded and form populated successfully');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Failed to load service provider data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load service provider data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _serviceTypeController.dispose();
    _yearsExperienceController.dispose();
    _countryController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  String getLogoUrl() {
    if (_serviceProvider?.logoPath != null && _serviceProvider!.logoPath!.isNotEmpty) {
      return _serviceProvider!.logoPath!.startsWith('http')
          ? _serviceProvider!.logoPath!
          : '${_serviceProviderService.baseUrl}/${_serviceProvider!.logoPath!}';
    }
    return '';
  }

  Future<void> _pickCertificationImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _certificationImages.add(File(pickedFile.path));
          _certificationImagePaths.add(pickedFile.path);
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to pick image: $e')),
      // );
    }
  }

  void _removeCertificationImage(int index) {
    setState(() {
      _certificationImages.removeAt(index);
      _certificationImagePaths.removeAt(index);
    });
  }

  Future<void> _saveServiceProviderData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Show loading indicator
      _showLoadingDialog();

      // Prepare the available hours format
      List<String> availableHours = _timeSlots.map((slot) {
        final fromHour = slot.from.hour.toString().padLeft(2, '0');
        final fromMinute = slot.from.minute.toString().padLeft(2, '0');
        final toHour = slot.to.hour.toString().padLeft(2, '0');
        final toMinute = slot.to.minute.toString().padLeft(2, '0');

        return '$fromHour:$fromMinute-$toHour:$toMinute';
      }).toList();

      // Prepare the update data
      final updateData = {
        'phone': _phoneController.text,
        'serviceType': _serviceTypeController.text,
        'yearsExperience': int.tryParse(_yearsExperienceController.text) ?? 0,
        'availableDays': _availableDays,
        'availableHours': availableHours,
        'location': {
          'country': _countryController.text,
          'district': _districtController.text,
          'city': _cityController.text,
          'street': _streetController.text,
          'postalCode': _postalCodeController.text,
        },
      };



      print('Updating service provider info with certificates...');
      print('Form data: $updateData');
      print('Certificate count: ${_certificationImages.length}');

      // Call the update service with the form data and certificates
      await _serviceProviderService.updateServiceProviderInfo(
        businessName: _serviceProvider?.fullName ?? '',
        email: _serviceProvider?.email,
        additionalData: updateData, // Pass the form data
        certificateFiles: _certificationImages.isNotEmpty ? _certificationImages : null, // Pass certificates
      ).timeout(
        Duration(seconds: 60), // 60 second timeout for the entire operation
        onTimeout: () {
          throw Exception('Profile update timed out. Please try again.');
        },
      );

      print('Service provider info updated successfully');

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


// Helper method to show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Saving profile...",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ServiceProviderHeader(
            serviceProvider: _serviceProvider,
            isLoading: isLoading,
            onLogoNavigation: () {
              // Navigate back to the previous screen
              Navigator.of(context).pop();
            },

          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button and title
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.blue),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Field
                      _buildFieldLabel('Phone Number'),
                      _buildTextField(_phoneController, 'Enter phone number'),
                      const SizedBox(height: 16),

                      // Service Type Dropdown
                      _buildFieldLabel('Service Type'),
                      _buildTextField(_serviceTypeController, 'Enter service type'),
                      const SizedBox(height: 16),

                      // Years of Experience Dropdown
                      _buildFieldLabel('Years of Experience'),
                      _buildTextField(
                        _yearsExperienceController,
                        'Enter years of experience',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Certifications - Modified to use image upload
                      _buildFieldLabel('Certifications'),
                      _buildCertificationUpload(),
                      const SizedBox(height: 16),

                      // Country Picker
                      _buildFieldLabel('Country'),
                      TextFormField(
                        controller: _countryController,
                        readOnly: true,
                        onTap: _showCountryPickerDialog,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'This field is required' : null,
                      ),
                      const SizedBox(height: 16),
                      // District Picker (only for Lebanon)
                      _buildFieldLabel('District'),
                      TextFormField(
                        controller: _districtController,
                        readOnly: true,
                        onTap: _showDistrictPickerDialog,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        validator: (value) {
                          if (_countryController.text == 'Lebanon' && (value == null || value.isEmpty)) {
                            return 'This field is required';
                          }
                          return null;
                        },
                        enabled: _countryController.text == 'Lebanon',
                      ),
                      const SizedBox(height: 16),
                      // City Picker (only for Lebanon)
                      _buildFieldLabel('City'),
                      TextFormField(
                        controller: _cityController,
                        readOnly: true,
                        onTap: _showCityPickerDialog,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        validator: (value) {
                          if (_countryController.text == 'Lebanon' && (value == null || value.isEmpty)) {
                            return 'This field is required';
                          }
                          return null;
                        },
                        enabled: _countryController.text == 'Lebanon',
                      ),
                      const SizedBox(height: 16),
                      // Street (remains a text field)
                      _buildFieldLabel('Street'),
                      _buildTextField(_streetController, 'Enter street'),
                      const SizedBox(height: 16),
                      // Postal Code
                      _buildFieldLabel('Postal Code'),
                      _buildTextField(
                        _postalCodeController,
                        'Enter postal code',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),

                      // Availability Calendar
                      _buildFieldLabel('Availability Calendar'),
                      _buildCalendarSection(),
                      const SizedBox(height: 16),

                      // Time Selection
                      _buildTimeSelectionSection(),
                      const SizedBox(height: 16),

                      // Save Button
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display existing certificates
        if (_certificationImages.isNotEmpty) ...[
          Text(
            'Uploaded Certificates (${_certificationImages.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _certificationImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _certificationImages[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeCertificationImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // Add certificate button
        GestureDetector(
          onTap: _pickCertificationImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Add Certificate',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    return Column(
      children: [
        // Calendar Title and Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // Apply to all months functionality - select all weekdays for the current month
                setState(() {
                  _availableDays.clear();
                  final year = _focusedDay.year;
                  final month = _focusedDay.month;
                  final daysInMonth = DateTime(year, month + 1, 0).day;
                  
                  for (int day = 1; day <= daysInMonth; day++) {
                    final date = DateTime(year, month, day);
                    final weekday = date.weekday;
                    // Add Monday (1) through Friday (5)
                    if (weekday >= 1 && weekday <= 5) {
                      final dateString = DateFormat('yyyy-MM-dd').format(date);
                      _availableDays.add(dateString);
                    }
                  }
                });
              },
              child: Text(
                'Apply for all months',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 20),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 20),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                    });
                  },
                ),
              ],
            ),
          ],
        ),

        // Custom Calendar
        _buildCustomCalendar(),
      ],
    );
  }

  Widget _buildTimeSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Time Slots',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),

        // List of time slots
        ..._timeSlots.asMap().entries.map((entry) {
          final index = entry.key;
          final slot = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(index),
                ),
                if (_timeSlots.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _timeSlots.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }).toList(),

        // Add time slot button
        ElevatedButton.icon(
          icon: Icon(Icons.add, color: Colors.white),
          label: Text('Add Time Slot', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: _addTimeSlot,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: _saveServiceProviderData,
        child: Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hintText, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildCustomCalendar() {
    const daysOfWeek = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Days of week header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: daysOfWeek
                  .map((day) => SizedBox(
                width: 30,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ))
                  .toList(),
            ),
          ),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 0,
              childAspectRatio: 1,
            ),
            itemCount: 42, // 6 weeks
            itemBuilder: (context, index) {
              // Calculate the day to display
              final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
              final firstWeekday = firstDayOfMonth.weekday; // 1-7 where 1 is Monday

              final day = index - firstWeekday + 2;
              final date = DateTime(_focusedDay.year, _focusedDay.month, day);

              final isCurrentMonth = date.month == _focusedDay.month;
              final isSelected = _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              final dateString = DateFormat('yyyy-MM-dd').format(date);
              final isAvailable = _availableDays.contains(dateString);

              return GestureDetector(
                onTap: () {
                  if (isCurrentMonth) {
                                          setState(() {
                        _selectedDay = date;
                        // Toggle availability for this day
                        final dateString = DateFormat('yyyy-MM-dd').format(date);
                        if (_availableDays.contains(dateString)) {
                          _availableDays.remove(dateString);
                        } else {
                          _availableDays.add(dateString);
                        }
                      });
                  }
                },
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.blue.withOpacity(0.3)
                        : isSelected
                        ? Colors.blue
                        : isToday
                        ? Colors.blue.shade100
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isCurrentMonth ? day.toString() : '',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isCurrentMonth
                            ? Colors.black
                            : Colors.grey,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(int index) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectTime(context, index, true),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeOfDay(_timeSlots[index].from),
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectTime(context, index, false),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeOfDay(_timeSlots[index].to),
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hour.toString().padLeft(2, '0');
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context, int index, bool isStartTime) async {
    final TimeOfDay initialTime = isStartTime
        ? _timeSlots[index].from
        : _timeSlots[index].to;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _timeSlots[index] = TimeSlot(
            from: picked,
            to: _timeSlots[index].to,
          );
        } else {
          _timeSlots[index] = TimeSlot(
            from: _timeSlots[index].from,
            to: picked,
          );
        }
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlots.add(TimeSlot(
        from: const TimeOfDay(hour: 9, minute: 0),
        to: const TimeOfDay(hour: 17, minute: 0),
      ));
    });
  }

  void _showCountryPickerDialog() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _countryController.text = country.name;
          _districtController.clear();
          _cityController.clear();
          if (country.name == 'Lebanon' && _locationData.containsKey('Lebanon')) {
            _lebanonDistricts = (_locationData['Lebanon'] as Map<String, dynamic>).keys.toList();
          } else {
            _lebanonDistricts = [];
            _lebanonCities = [];
          }
        });
      },
    );
  }

  void _showDistrictPickerDialog() {
    if (_countryController.text != 'Lebanon' || _lebanonDistricts.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Districts only available for Lebanon.')),
      // );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select District'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _lebanonDistricts.map((district) {
                return ListTile(
                  title: Text(district),
                  onTap: () {
                    setState(() {
                      _districtController.text = district;
                      _cityController.clear();
                      _lebanonCities = List<String>.from((_locationData['Lebanon'][district] as List<dynamic>));
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showCityPickerDialog() {
    if (_countryController.text != 'Lebanon' || _districtController.text.isEmpty || _lebanonCities.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Cities only available for selected district in Lebanon.')),
      // );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select City'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _lebanonCities.map((city) {
                return ListTile(
                  title: Text(city),
                  onTap: () {
                    setState(() {
                      _cityController.text = city;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class TimeSlot {
  final TimeOfDay from;
  final TimeOfDay to;

  TimeSlot({required this.from, required this.to});
}