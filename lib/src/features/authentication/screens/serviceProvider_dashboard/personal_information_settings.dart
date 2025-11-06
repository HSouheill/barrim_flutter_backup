import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';

import '../../../../models/service_provider.dart';
import '../../../../services/service_provider_services.dart';
import '../../../../services/lebanon_location_data.dart';
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
  TextEditingController? _governorateController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;

  // Calendar-related variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // For multiple certification images
  List<File> _certificationImages = [];
  List<String> _certificationImagePaths = [];

  // For portfolio images
  List<String> _portfolioImageUrls = [];
  bool _isLoadingPortfolio = false;

  // For time selection
  List<TimeSlot> _timeSlots = [];

  // Available days for service (stored as date strings in YYYY-MM-DD format)
  List<String> _availableDays = [];

  // Day-specific availability system
  Map<String, List<TimeSlot>> _daySpecificAvailability = {};
  String? _selectedDateForTimeSlots;

  // Service provider data
  ServiceProvider? _serviceProvider;

  // For Lebanon-specific districts/cities
  List<String> _lebanonDistricts = [];
  List<String> _lebanonCities = [];
  
  // For Lebanon location data
  List<Governorate> _governorates = [];
  List<District> _districts = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadLocationData();
    _loadServiceProviderData();

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
    _governorateController = TextEditingController();
    _districtController = TextEditingController();
    _cityController = TextEditingController();
  }

  void _loadLocationData() {
    setState(() {
      _governorates = LebanonLocationData.getGovernorates()
          .map((g) => Governorate.fromJson(g))
          .toList();
    });
  }

  void _loadDistrictsForGovernorate(String governorateName) {
    final governorate = _governorates.firstWhere(
      (g) => g.name.toLowerCase() == governorateName.toLowerCase(),
      orElse: () => Governorate(name: '', isoCode: '', districts: []),
    );
    
    if (governorate.name.isNotEmpty) {
      setState(() {
        _districts = governorate.districts;
        _lebanonDistricts = governorate.districts.map((d) => d.name).toList();
      });
    }
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
        _governorateController?.text = provider.location?.governorate ?? '';
        _districtController.text = provider.location?.district ?? '';
        _cityController.text = provider.location?.city ?? '';
        
        // Load districts for the selected governorate if available
        if (provider.location?.governorate != null) {
          _loadDistrictsForGovernorate(provider.location!.governorate!);
        }

        // Load portfolio images from service provider info or fetch from API
        if (provider.serviceProviderInfo?.portfolioImages != null && 
            provider.serviceProviderInfo!.portfolioImages!.isNotEmpty) {
          _portfolioImageUrls = provider.serviceProviderInfo!.portfolioImages!
              .map((path) => _getFullImageUrl(path))
              .toList();
        } else {
          // Try to fetch portfolio images from API after setState completes
          Future.microtask(() => _loadPortfolioImages());
        }

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

        // Load day-specific availability if it exists
        // This would need to be added to the ServiceProvider model and API response
        // For now, we'll initialize day-specific availability from available days
        _daySpecificAvailability.clear();
        for (String date in _availableDays) {
          if (!_daySpecificAvailability.containsKey(date)) {
            _daySpecificAvailability[date] = [
              TimeSlot(
                from: const TimeOfDay(hour: 9, minute: 0),
                to: const TimeOfDay(hour: 17, minute: 0),
              )
            ];
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

  String _getFullImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    // Remove leading slash if present and construct full URL
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${_serviceProviderService.baseUrl}/$cleanPath';
  }

  Future<void> _loadPortfolioImages() async {
    try {
      setState(() {
        _isLoadingPortfolio = true;
      });
      final imagePaths = await _serviceProviderService.getPortfolioImages();
      setState(() {
        _portfolioImageUrls = imagePaths.map((path) => _getFullImageUrl(path)).toList();
        _isLoadingPortfolio = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPortfolio = false;
      });
      print('Failed to load portfolio images: $e');
      // Don't show error to user if portfolio images don't exist yet
    }
  }

  Future<void> _pickPortfolioImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        await _uploadPortfolioImage(File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadPortfolioImage(File imageFile) async {
    try {
      _showLoadingDialog();
      final updatedPortfolioImages = await _serviceProviderService.uploadPortfolioImage(imageFile);
      Navigator.of(context).pop(); // Close loading dialog
      
      setState(() {
        _portfolioImageUrls = updatedPortfolioImages.map((path) => _getFullImageUrl(path)).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Portfolio image uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload portfolio image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePortfolioImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        _showLoadingDialog();
        final updatedPortfolioImages = await _serviceProviderService.updatePortfolioImage(index, File(pickedFile.path));
        Navigator.of(context).pop(); // Close loading dialog
        
        setState(() {
          _portfolioImageUrls = updatedPortfolioImages.map((path) => _getFullImageUrl(path)).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update portfolio image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePortfolioImage(int index) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Delete Portfolio Image'),
            content: const Text('Are you sure you want to delete this portfolio image?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        _showLoadingDialog();
        final updatedPortfolioImages = await _serviceProviderService.deletePortfolioImage(index);
        Navigator.of(context).pop(); // Close loading dialog
        
        setState(() {
          _portfolioImageUrls = updatedPortfolioImages.map((path) => _getFullImageUrl(path)).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio image deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete portfolio image: $e'),
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
    _governorateController?.dispose();
    _districtController.dispose();
    _cityController.dispose();
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

      // Prepare the available hours format (legacy support)
      List<String> availableHours = _timeSlots.map((slot) {
        final fromHour = slot.from.hour.toString().padLeft(2, '0');
        final fromMinute = slot.from.minute.toString().padLeft(2, '0');
        final toHour = slot.to.hour.toString().padLeft(2, '0');
        final toMinute = slot.to.minute.toString().padLeft(2, '0');

        return '$fromHour:$fromMinute-$toHour:$toMinute';
      }).toList();

      // Prepare day-specific availability data
      Map<String, List<Map<String, String>>> daySpecificHours = {};
      _daySpecificAvailability.forEach((date, timeSlots) {
        daySpecificHours[date] = timeSlots.map((slot) {
          final fromHour = slot.from.hour.toString().padLeft(2, '0');
          final fromMinute = slot.from.minute.toString().padLeft(2, '0');
          final toHour = slot.to.hour.toString().padLeft(2, '0');
          final toMinute = slot.to.minute.toString().padLeft(2, '0');
          
          return {
            'from': '$fromHour:$fromMinute',
            'to': '$toHour:$toMinute',
          };
        }).toList();
      });

      // Prepare the update data
      final updateData = {
        'phone': _phoneController.text,
        'serviceType': _serviceTypeController.text,
        'yearsExperience': int.tryParse(_yearsExperienceController.text) ?? 0,
        'availableDays': _availableDays,
        'availableHours': availableHours, // Legacy support
        'daySpecificAvailability': daySpecificHours, // New day-specific data
        'location': {
          'country': _countryController.text,
          'governorate': _governorateController?.text ?? '',
          'district': _districtController.text,
          'city': _cityController.text,
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

                      // Portfolio Images
                      _buildFieldLabel('Portfolio Images'),
                      _buildPortfolioUpload(),
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
                      // Governorate Picker
                      _buildFieldLabel('Governorate'),
                      TextFormField(
                        controller: _governorateController ??= TextEditingController(),
                        readOnly: true,
                        onTap: _showGovernoratePickerDialog,
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
                          if (_governorateController?.text.isNotEmpty == true && (value == null || value.isEmpty)) {
                            return 'This field is required';
                          }
                          return null;
                        },
                        enabled: _governorateController?.text.isNotEmpty == true,
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
                          if (_governorateController?.text.isNotEmpty == true && (value == null || value.isEmpty)) {
                            return 'This field is required';
                          }
                          return null;
                        },
                        enabled: _governorateController?.text.isNotEmpty == true,
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

  Widget _buildPortfolioUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingPortfolio)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_portfolioImageUrls.isNotEmpty) ...[
          Text(
            'Portfolio Images (${_portfolioImageUrls.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _portfolioImageUrls.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _portfolioImageUrls[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button
                          GestureDetector(
                            onTap: () => _updatePortfolioImage(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          // Delete button
                          GestureDetector(
                            onTap: () => _deletePortfolioImage(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 16),
        ],
        
        // Add portfolio image button
        GestureDetector(
          onTap: _pickPortfolioImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Add Portfolio Image',
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
        
        // Calendar Legend
        const SizedBox(height: 12),
        _buildCalendarLegend(),
        
        // Day-specific time slots section
        if (_selectedDateForTimeSlots != null) ...[
          const SizedBox(height: 20),
          _buildDaySpecificTimeSlots(),
        ],
      ],
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Available day', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.schedule,
                    size: 8,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Custom time slots', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
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
              final hasCustomTimeSlots = _daySpecificAvailability.containsKey(dateString) && 
                  _daySpecificAvailability[dateString]!.length > 1;

              return GestureDetector(
                onTap: () {
                  if (isCurrentMonth) {
                    setState(() {
                      _selectedDay = date;
                      final dateString = DateFormat('yyyy-MM-dd').format(date);
                      
                      // Toggle availability for this day
                      if (_availableDays.contains(dateString)) {
                        _availableDays.remove(dateString);
                        _daySpecificAvailability.remove(dateString);
                      } else {
                        _availableDays.add(dateString);
                        // Initialize with default time slot if none exists
                        if (!_daySpecificAvailability.containsKey(dateString)) {
                          _daySpecificAvailability[dateString] = [
                            TimeSlot(
                              from: const TimeOfDay(hour: 9, minute: 0),
                              to: const TimeOfDay(hour: 17, minute: 0),
                            )
                          ];
                        }
                      }
                      
                      // Set selected date for time slot editing
                      _selectedDateForTimeSlots = dateString;
                    });
                  }
                },
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? hasCustomTimeSlots
                            ? Colors.green.withOpacity(0.4)
                            : Colors.blue.withOpacity(0.3)
                        : isSelected
                        ? Colors.blue
                        : isToday
                        ? Colors.blue.shade100
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: hasCustomTimeSlots
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
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
                      if (hasCustomTimeSlots)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
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

  Widget _buildDaySpecificTimeSlots() {
    if (_selectedDateForTimeSlots == null) return const SizedBox.shrink();
    
    final date = DateTime.parse(_selectedDateForTimeSlots!);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final timeSlots = _daySpecificAvailability[_selectedDateForTimeSlots!] ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time Slots for:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDateForTimeSlots = null;
                  });
                },
                icon: const Icon(Icons.close),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // List of time slots for this specific day
          ...timeSlots.asMap().entries.map((entry) {
            final index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildDaySpecificTimeSelector(index),
                  ),
                  if (timeSlots.length > 1) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          timeSlots.removeAt(index);
                          _daySpecificAvailability[_selectedDateForTimeSlots!] = timeSlots;
                        });
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          
          // Add time slot button for this day
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Time Slot', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              setState(() {
                timeSlots.add(TimeSlot(
                  from: const TimeOfDay(hour: 9, minute: 0),
                  to: const TimeOfDay(hour: 17, minute: 0),
                ));
                _daySpecificAvailability[_selectedDateForTimeSlots!] = timeSlots;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaySpecificTimeSelector(int index) {
    final timeSlots = _daySpecificAvailability[_selectedDateForTimeSlots!] ?? [];
    if (index >= timeSlots.length) return const SizedBox.shrink();
    
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDaySpecificTime(context, index, true),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Text(
                _formatTimeOfDay(timeSlots[index].from),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDaySpecificTime(context, index, false),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Text(
                _formatTimeOfDay(timeSlots[index].to),
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDaySpecificTime(BuildContext context, int index, bool isStartTime) async {
    final timeSlots = _daySpecificAvailability[_selectedDateForTimeSlots!] ?? [];
    if (index >= timeSlots.length) return;
    
    final TimeOfDay initialTime = isStartTime
        ? timeSlots[index].from
        : timeSlots[index].to;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          timeSlots[index] = TimeSlot(
            from: picked,
            to: timeSlots[index].to,
          );
        } else {
          timeSlots[index] = TimeSlot(
            from: timeSlots[index].from,
            to: picked,
          );
        }
        _daySpecificAvailability[_selectedDateForTimeSlots!] = timeSlots;
      });
    }
  }

  void _showCountryPickerDialog() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _countryController.text = country.name;
          _governorateController?.clear();
          _districtController.clear();
          _cityController.clear();
          _lebanonDistricts = [];
          _lebanonCities = [];
        });
      },
    );
  }

  void _showGovernoratePickerDialog() {
    // Ensure controller is initialized
    if (_governorateController == null) {
      _governorateController = TextEditingController();
    }
    
    if (_governorates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No governorates available.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Governorate'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _governorates.map((governorate) {
                return ListTile(
                  title: Text(governorate.name),
                  subtitle: Text('${governorate.districts.length} districts'),
                  onTap: () {
                    setState(() {
                      _governorateController?.text = governorate.name;
                      _districtController.clear();
                      _cityController.clear();
                      _lebanonDistricts.clear();
                      _lebanonCities.clear();
                      
                      // Load districts for the selected governorate
                      _loadDistrictsForGovernorate(governorate.name);
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

  void _showDistrictPickerDialog() {
    if (_governorateController?.text.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a governorate first.')),
      );
      return;
    }
    
    if (_districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No districts available for the selected governorate.')),
      );
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
              children: _districts.map((district) {
                return ListTile(
                  title: Text(district.name),
                  subtitle: Text('${district.cities.length} cities'),
                  onTap: () {
                    setState(() {
                      _districtController.text = district.name;
                      _cityController.clear();
                      _lebanonCities = district.cities;
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
    if (_governorateController?.text.isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a governorate first.')),
      );
      return;
    }
    
    if (_districtController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a district first.')),
      );
      return;
    }
    
    if (_lebanonCities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cities available for the selected district.')),
      );
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