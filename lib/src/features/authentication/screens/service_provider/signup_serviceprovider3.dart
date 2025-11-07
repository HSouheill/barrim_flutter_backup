import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import '../responsive_utils.dart';
import 'signup_serviceprovider4.dart';
import '../../../../services/service_provider_category_service.dart';

class SignupServiceprovider3 extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SignupServiceprovider3({super.key, required this.userData});

  @override
  _SignupServiceprovider3State createState() => _SignupServiceprovider3State();
}

class _SignupServiceprovider3State extends State<SignupServiceprovider3> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedServiceType;
  File? _selectedImage;
  bool _isDropdownOpen = false;
  bool _isLoadingCategories = true;
  String? _errorMessage;
  
  List<ServiceProviderCategory> _serviceTypes = [];
  List<ServiceProviderCategory> _filteredServiceTypes = [];

  @override
  void initState() {
    super.initState();
    _loadServiceProviderCategories();
  }

  Future<void> _loadServiceProviderCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _errorMessage = null;
      });

      final categories = await ServiceProviderCategoryService.getAllServiceProviderCategories();
      
      // If no categories found from API, load static fallback categories
      if (categories.isEmpty) {
        setState(() {
          _isLoadingCategories = false;
          _loadFallbackCategories();
        });
      } else {
        setState(() {
          _serviceTypes = categories;
          _filteredServiceTypes = List.from(categories);
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = e.toString();
        // Fallback to hardcoded categories if API fails
        _loadFallbackCategories();
      });
    }
  }

  void _loadFallbackCategories() {
    // Fallback categories in case API fails
    _serviceTypes = [
      ServiceProviderCategory(id: '1', name: 'Home Repairs', icon: 'home_repair_service'),
      ServiceProviderCategory(id: '2', name: 'Plumber', icon: 'plumbing'),
      ServiceProviderCategory(id: '3', name: 'Electrician', icon: 'electrical_services'),
      ServiceProviderCategory(id: '4', name: 'Carpenter', icon: 'handyman'),
      ServiceProviderCategory(id: '5', name: 'Appliances', icon: 'devices'),
      ServiceProviderCategory(id: '6', name: 'AC repair', icon: 'ac_unit'),
      ServiceProviderCategory(id: '7', name: 'Driver', icon: 'drive_eta'),
      ServiceProviderCategory(id: '8', name: 'Guide', icon: 'tour'),
      ServiceProviderCategory(id: '9', name: 'Cleaning', icon: 'cleaning_services'),
      ServiceProviderCategory(id: '10', name: 'Painting', icon: 'format_paint'),
      ServiceProviderCategory(id: '11', name: 'Gardening', icon: 'yard'),
      ServiceProviderCategory(id: '12', name: 'Moving Services', icon: 'local_shipping'),
      ServiceProviderCategory(id: '13', name: 'Computer Repair', icon: 'computer'),
      ServiceProviderCategory(id: '14', name: 'Photography', icon: 'camera_alt'),
      ServiceProviderCategory(id: '15', name: 'Beauty & Spa', icon: 'spa'),
      ServiceProviderCategory(id: '16', name: 'Tutoring', icon: 'school'),
      ServiceProviderCategory(id: '17', name: 'Personal Training', icon: 'fitness_center'),
      ServiceProviderCategory(id: '18', name: 'Pet Services', icon: 'pets'),
      ServiceProviderCategory(id: '19', name: 'Interior Design', icon: 'design_services'),
      ServiceProviderCategory(id: '20', name: 'Event Planning', icon: 'event'),
      ServiceProviderCategory(id: '21', name: 'Catering', icon: 'restaurant'),
      ServiceProviderCategory(id: '22', name: 'Tailoring', icon: 'content_cut'),
      ServiceProviderCategory(id: '23', name: 'Locksmith', icon: 'vpn_key'),
      ServiceProviderCategory(id: '24', name: 'Other', icon: 'more_horiz'),
    ];
    _filteredServiceTypes = List.from(_serviceTypes);
  }

  void _filterServiceTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredServiceTypes = List.from(_serviceTypes);
      } else {
        _filteredServiceTypes = _serviceTypes
            .where((service) => service.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  IconData _getIconFromString(String iconString) {
    // Map icon strings to Flutter icons
    switch (iconString.toLowerCase()) {
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'handyman':
        return Icons.handyman;
      case 'devices':
        return Icons.devices;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'drive_eta':
        return Icons.drive_eta;
      case 'tour':
        return Icons.tour;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'format_paint':
        return Icons.format_paint;
      case 'yard':
        return Icons.yard;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'computer':
        return Icons.computer;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'spa':
        return Icons.spa;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'pets':
        return Icons.pets;
      case 'design_services':
        return Icons.design_services;
      case 'event':
        return Icons.event;
      case 'restaurant':
        return Icons.restaurant;
      case 'content_cut':
        return Icons.content_cut;
      case 'vpn_key':
        return Icons.vpn_key;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final labelFontSize = ResponsiveUtils.getInputLabelFontSize(context);
          final inputTextFontSize = ResponsiveUtils.getInputTextFontSize(context);
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
                // WhiteHeader
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 180,
                    child: WhiteHeader(
                      title: 'Sign Up',
                      onBackPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Add fixed space between WhiteHeader and progress bar
                Positioned(
                  top: 180,
                  left: 0,
                  right: 0,
                  child: SizedBox(height: 16),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                        CustomHeader(currentPageIndex: 3, totalPages: 4, subtitle: 'Service Provider', onBackPressed: () => Navigator.pop(context)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.06),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                _buildUploadLogo(),
                                SizedBox(height: 20),
                                _buildServiceTypeDropdown(labelFontSize, inputTextFontSize),
                                SizedBox(height: 20),
                                if (!_isDropdownOpen) _buildReferralField(),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                                if (!_isDropdownOpen) _buildNextButton(constraints),
                                SizedBox(height: 30),
                              ],
                            ),
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

  Widget _buildUploadLogo() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: MediaQuery.of(context).size.width * 0.125,
            backgroundColor: Colors.white,
            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
            child: _selectedImage == null
                ? Icon(Icons.person_outline, size: MediaQuery.of(context).size.width * 0.1, color: Colors.grey)
                : null,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Add Profile Photo',
          style: GoogleFonts.nunito(
              fontSize: ResponsiveUtils.getSubtitleFontSize(context),
              color: Colors.white,
              fontWeight: FontWeight.w600
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTypeDropdown(double labelFontSize, double textFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Type',
          style: GoogleFonts.nunito(
            color: const Color(0xFFDBD5D5),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        InkWell(
          onTap: _isLoadingCategories ? null : () {
            setState(() {
              _isDropdownOpen = !_isDropdownOpen;
              if (!_isDropdownOpen) {
                _searchController.clear();
                _filteredServiceTypes = List.from(_serviceTypes);
              }
            });
          },
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _isLoadingCategories
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Loading categories...',
                              style: GoogleFonts.nunito(
                                color: Colors.white70,
                                fontSize: textFontSize,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _selectedServiceType ?? 'Select Service Type',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: textFontSize,
                          ),
                        ),
                ),
                if (!_isLoadingCategories)
                  Icon(
                    _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
        if (_isDropdownOpen && !_isLoadingCategories)
          Container(
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterServiceTypes,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          'Error loading categories: ${_errorMessage}',
                          style: GoogleFonts.nunito(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            _loadServiceProviderCategories();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 300, // Increased height to show more items
                  ),
                  child: _filteredServiceTypes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage == null 
                                ? 'No service provider categories found'
                                : 'No categories found',
                            style: GoogleFonts.nunito(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredServiceTypes.length,
                          itemBuilder: (context, index) {
                            final service = _filteredServiceTypes[index];
                            return ListTile(
                              leading: service.icon != null
                                  ? Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIconFromString(service.icon!),
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              )
                                  : Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.category,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                service.name,
                                style: GoogleFonts.nunito(
                                  color: const Color(0xFF05054F),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedServiceType = service.name;
                                  _isDropdownOpen = false;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReferralField() {
    return TextFormField(
      controller: _experienceController,
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: ResponsiveUtils.getInputTextFontSize(context),
      ),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Years of Experience',
        labelStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: ResponsiveUtils.getInputLabelFontSize(context),
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }

  Widget _buildNextButton(BoxConstraints constraints) {
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
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedServiceType != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SignupServiceprovider4(
                    userData: {
                      ...widget.userData,
                      'serviceType': _selectedServiceType,
                      'yearsExperience': _experienceController.text,
                      'logo': _selectedImage,
                    },
                  ),
                ),
              );
            } else if (_selectedServiceType == null) {
              // Show validation message for service type
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please select a service type')),
              );
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
            'Next',
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
}