import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../custom_header.dart';
import '../white_headr.dart';
import '../responsive_utils.dart';
import 'signup_serviceprovider4.dart';

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
  List<Map<String, dynamic>> _serviceTypes = [
    {'name': 'Home Repairs', 'icon': Icons.home_repair_service},
    {'name': 'Plumber', 'icon': Icons.plumbing},
    {'name': 'Electrician', 'icon': Icons.electrical_services},
    {'name': 'Carpenter', 'icon': Icons.handyman},
    {'name': 'Appliances', 'icon': Icons.devices},
    {'name': 'AC repair', 'icon': Icons.ac_unit},
    {'name': 'Driver', 'icon': Icons.drive_eta},
    {'name': 'Guide', 'icon': Icons.tour},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services},
    {'name': 'Painting', 'icon': Icons.format_paint},
    {'name': 'Gardening', 'icon': Icons.yard},
    {'name': 'Moving Services', 'icon': Icons.local_shipping},
    {'name': 'Computer Repair', 'icon': Icons.computer},
    {'name': 'Photography', 'icon': Icons.camera_alt},
    {'name': 'Beauty & Spa', 'icon': Icons.spa},
    {'name': 'Tutoring', 'icon': Icons.school},
    {'name': 'Personal Training', 'icon': Icons.fitness_center},
    {'name': 'Pet Services', 'icon': Icons.pets},
    {'name': 'Interior Design', 'icon': Icons.design_services},
    {'name': 'Event Planning', 'icon': Icons.event},
    {'name': 'Catering', 'icon': Icons.restaurant},
    {'name': 'Tailoring', 'icon': Icons.content_cut},
    {'name': 'Locksmith', 'icon': Icons.vpn_key},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];

  List<Map<String, dynamic>> _filteredServiceTypes = [];

  @override
  void initState() {
    super.initState();
    _filteredServiceTypes = List.from(_serviceTypes);
  }

  void _filterServiceTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredServiceTypes = List.from(_serviceTypes);
      } else {
        _filteredServiceTypes = _serviceTypes
            .where((service) => service['name'].toLowerCase().contains(query.toLowerCase()))
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
                        SizedBox(height: MediaQuery.of(context).size.height * 0.21),
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
          onTap: () {
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
                Text(
                  _selectedServiceType ?? 'Select Service Type',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: textFontSize,
                  ),
                ),
                Icon(
                  _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_isDropdownOpen)
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
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 300, // Increased height to show more items
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredServiceTypes.length,
                    itemBuilder: (context, index) {
                      final service = _filteredServiceTypes[index];
                      return ListTile(
                        leading: service['icon'] != null
                            ? Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(service['icon'], color: Colors.blue, size: 20),
                        )
                            : null,
                        title: Text(
                          service['name'],
                          style: GoogleFonts.nunito(
                            color: const Color(0xFF05054F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedServiceType = service['name'];
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