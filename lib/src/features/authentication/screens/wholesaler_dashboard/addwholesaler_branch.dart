import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:location/location.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

import '../../../../models/wholesaler_model.dart';
import '../../../../services/wholesaler_service.dart';
import '../../../../services/api_service.dart'; // Added import for ApiService

class AddWholeSalerBranchPage extends StatefulWidget {
  final String token;

  final bool isEditMode;
  final Map<String, dynamic>? branchData;


  const AddWholeSalerBranchPage({
    Key? key,
    required this.token,
    this.isEditMode = false,
    this.branchData,
  }) : super(key: key);

  @override
  State<AddWholeSalerBranchPage> createState() => _AddWholeSalerBranchPageState();
}

class _AddWholeSalerBranchPageState extends State<AddWholeSalerBranchPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? selectedCategory;
  String? selectedSubCategory;
  String countryCode = '+961';
  final WholesalerService _wholesalerService = WholesalerService();
  List<String> _existingImageUrls = [];
  List<String> _existingVideoUrls = [];

  // Image and video handling
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  bool _isLoadingLocation = false;

  // Location data
  double? latitude;
  double? longitude;

  // Dynamic categories and subcategories loaded from backend
  List<String> categories = [];
  Map<String, List<String>> subCategories = {};
  bool _isLoadingCategories = true;
  String? _categoriesError;

  void _loadMediaFromExistingBranch() {
    if (widget.isEditMode && widget.branchData != null) {
      // Load existing image URLs
      if (widget.branchData!['images'] != null && widget.branchData!['images'] is List) {
        _existingImageUrls = List<String>.from(widget.branchData!['images']);
      }

      // Load existing video URLs
      if (widget.branchData!['videos'] != null && widget.branchData!['videos'] is List) {
        _existingVideoUrls = List<String>.from(widget.branchData!['videos']);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Load existing data if in edit mode
    if (widget.isEditMode && widget.branchData != null) {
      _loadBranchData();
      _loadMediaFromExistingBranch();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });

      final categoriesData = await ApiService.getAllCategories();
      
      if (mounted) {
        setState(() {
          categories = categoriesData.keys.toList();
          subCategories = categoriesData;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'Failed to load categories: $e';
          // Fallback to default categories if backend fails
          categories = ['Restaurant', 'Hotel', 'Shop', 'Office'];
          subCategories = {
            'Restaurant': ['Fast Food', 'Fine Dining', 'Cafe'],
            'Hotel': ['Resort', 'Boutique', 'Business'],
            'Shop': ['Clothing', 'Electronics', 'Grocery'],
            'Office': ['Corporate', 'Co-working', 'Agency'],
          };
        });
      }
    }
  }

  void _loadBranchData() {
    final branchData = widget.branchData!;

    // Populate text fields
    _nameController.text = branchData['name']?.toString() ?? '';
    _locationController.text = branchData['location']?.toString() ?? '';

    // Parse phone number to separate country code and number
    String phoneNum = branchData['phone']?.toString() ?? '';
    if (phoneNum.startsWith('+')) {
      // Extract country code (like +961)
      int spaceIndex = phoneNum.indexOf(' ');
      if (spaceIndex > 0) {
        countryCode = phoneNum.substring(0, spaceIndex);
        _phoneController.text = phoneNum.substring(spaceIndex + 1);
      } else {
        _phoneController.text = phoneNum;
      }
    } else {
      _phoneController.text = phoneNum;
    }

    _descriptionController.text = branchData['description']?.toString() ?? '';

    // Set location coordinates
    latitude = branchData['latitude'] is num ? branchData['latitude'] : null;
    longitude = branchData['longitude'] is num ? branchData['longitude'] : null;

    // Set category and subcategory
    selectedCategory = branchData['category']?.toString();
    selectedSubCategory = branchData['subCategory']?.toString();

    // Load images if available
    // For edit mode, we would likely need to handle remote images differently
    // This is a placeholder for that logic
    if (branchData['images'] != null && branchData['images'] is List) {
      // Here you would implement logic to handle existing images
      // This might involve downloading them or displaying them from URLs
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles.map((xFile) => File(xFile.path)).toList());
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error picking images: $e")),
      // );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedVideos.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error picking video: $e")),
      // );
    }
  }

  void _showMediaPickerOptions() {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: Color(0xFF2079C2)),
                  title: Text('Add Images'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.videocam, color: Color(0xFF2079C2)),
                  title: Text('Add Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
              ],
            ),
          );
        }
    );
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    loc.Location location = loc.Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    // Check if location service is enabled
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Location services are disabled")),
        // );
        return;
      }
    }

    // Check location permission
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() {
          _isLoadingLocation = false;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Location permission denied")),
        // );
        return;
      }
    }

    // Get location
    try {
      _locationData = await location.getLocation();
      latitude = _locationData.latitude;
      longitude = _locationData.longitude;

      // Get address from coordinates
      if (latitude != null && longitude != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = [
            place.street,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((element) => element != null && element.isNotEmpty).join(", ");

          setState(() {
            _locationController.text = address;
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to get location: $e")),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? "Edit Branch" : "Add Branch"),
        backgroundColor: Color(0xFF2079C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display existing images if in edit mode
                  if (widget.isEditMode && _existingImageUrls.isNotEmpty)
                    _buildExistingImagesList(),

                  // Display existing videos if in edit mode
                  if (widget.isEditMode && _existingVideoUrls.isNotEmpty) ...[
                    SizedBox(height: 16),
                    _buildExistingVideosList(),
                  ],

                  SizedBox(height: 16),

                  // Selected new images preview
                  if (_selectedImages.isNotEmpty) ...[
                    Text(
                      "New Images",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImages[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
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

                  // Selected new videos preview
                  if (_selectedVideos.isNotEmpty) ...[
                    Text(
                      "New Videos",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedVideos.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.videocam, size: 40, color: Colors.grey.shade700),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedVideos.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
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

                  // Combined Add Media Button
                  GestureDetector(
                    onTap: _showMediaPickerOptions,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF2079C2),
                            Color(0xFF1F4889),
                            Color(0xFF10105D),
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: Colors.white),
                            SizedBox(width: 4),
                            Icon(Icons.videocam, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Add Media",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // The rest of your form fields...
                  // Name field
                  _buildFieldLabel("Name"),
                  _buildTextField(_nameController, "Name"),
                  SizedBox(height: 16),

                  // Location field
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldLabel("Location"),
                      ),
                      TextButton(
                        onPressed: _isLoadingLocation ? null : _getLocation,
                        child: Row(
                          children: [
                            if (_isLoadingLocation)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                            if (_isLoadingLocation)
                              SizedBox(width: 8),
                            Text(
                              "Auto-pin locations",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(_locationController, "Location"),
                  if (latitude != null && longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Lat: ${latitude!.toStringAsFixed(6)}, Long: ${longitude!.toStringAsFixed(6)}",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  SizedBox(height: 16),

                  // The rest of your form fields remain the same...
                  // Category and Sub Category fields
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("Category"),
                            _buildDropdown(
                              value: selectedCategory,
                              items: categories.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              )).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedCategory = value as String?;
                                  selectedSubCategory = null;
                                });
                              },
                              hint: "Category",
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("Sub Category"),
                            _buildDropdown(
                              value: selectedSubCategory,
                              items: (selectedCategory != null && subCategories.containsKey(selectedCategory))
                                  ? subCategories[selectedCategory]!.map((subCat) => DropdownMenuItem(
                                value: subCat,
                                child: Text(subCat),
                              )).toList()
                                  : [],
                              onChanged: (value) {
                                setState(() {
                                  selectedSubCategory = value as String?;
                                });
                              },
                              hint: "Sub Category",
                              isEnabled: selectedCategory != null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Phone field
                  _buildFieldLabel("Phone"),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: countryCode,
                          underline: SizedBox(),
                          items: [
                            DropdownMenuItem(value: '+961', child: Text('+961')),
                            DropdownMenuItem(value: '+971', child: Text('+971')),
                            DropdownMenuItem(value: '+966', child: Text('+966')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              countryCode = value!;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: "Phone",
                            border: InputBorder.none,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Description field
                  _buildFieldLabel("Description"),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: "Description",
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () {
                            if (widget.isEditMode) {
                              _onUpdate();
                            } else {
                              _onAdd();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0066B3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                          )
                              : Text(widget.isEditMode ? "Update" : "Add"),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text("Cancel"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExistingImagesList() {
    return _existingImageUrls.isEmpty
        ? SizedBox()
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Existing Images",
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _existingImageUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _existingImageUrls[index],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade300,
                            child: Icon(Icons.broken_image, color: Colors.grey.shade700),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _existingImageUrls.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
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
      ],
    );
  }

// Similar function for existing videos
  Widget _buildExistingVideosList() {
    return _existingVideoUrls.isEmpty
        ? SizedBox()
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Existing Videos",
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _existingVideoUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(Icons.videocam, size: 40, color: Colors.grey.shade700),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _existingVideoUrls.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
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
      ],
    );
  }

  void _onUpdate() async {
    if (_nameController.text.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Please enter a name")),
      // );
      return;
    }

    // Get branch ID
    var branchId = widget.branchData!['_id'];
    if (branchId is Map && branchId.containsKey("\$oid")) {
      branchId = branchId["\$oid"];
    } else if (branchId == null) {
      branchId = widget.branchData!['id'];
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create address object
      final address = Address(
        country: _locationController.text.split(',').length > 2 ?
        _locationController.text.split(',').last.trim() : 'N/A',
        district: '', // Provide a default even if empty
        city: _locationController.text.split(',').length > 1 ?
        _locationController.text.split(',')[1].trim() : 'N/A',
        street: _locationController.text.split(',').first.trim(),
        postalCode: '', // Provide a default even if empty
        lat: latitude ?? 0.0,
        lng: longitude ?? 0.0,
      );

      // Call the service to edit branch with all the required parameters
      final updatedBranch = await _wholesalerService.editBranch(
        branchId: branchId.toString(),
        name: _nameController.text,
        location: address,
        phone: '${countryCode ?? "+961"} ${_phoneController.text.isNotEmpty ? _phoneController.text : "000000"}',
        category: selectedCategory ?? "Uncategorized",
        subCategory: selectedSubCategory ?? "",
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : "No description",
        newImages: _selectedImages,
        newVideos: _selectedVideos,
      );

      if (updatedBranch != null) {
        // Return the updated branch data to the previous screen
        Navigator.pop(context, {'branch': updatedBranch, 'refresh': true});
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to update branch")),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to update branch: ${e.toString()}")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _onAdd() async {
    if (_nameController.text.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Please enter a name")),
      // );
      return;
    }

    if (latitude == null || longitude == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Please select a location")),
      // );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create address object using the wholesaler_model Address class
      final address = Address(
        country: _locationController.text.split(',').last.trim(),
        district: '', // You might want to add a field for this
        city: _locationController.text.split(',').length > 1
            ? _locationController.text.split(',')[1].trim()
            : '',
        street: _locationController.text.split(',').first.trim(),
        postalCode: '', // You might want to add a field for this
        lat: latitude!,
        lng: longitude!,
      );

      // Call the service to create branch
      final branch = await WholesalerService().createBranch(
        name: _nameController.text,
        location: address,
        phone: '${countryCode ?? "+961"} ${_phoneController.text}',
        category: selectedCategory ?? 'Uncategorized',
        subCategory: selectedSubCategory,
        description: _descriptionController.text,
        images: _selectedImages,
        videos: _selectedVideos,
      );

      if (branch != null) {
        // Clear form
        _nameController.clear();
        _locationController.clear();
        _phoneController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedImages = [];
          _selectedVideos = [];
          latitude = null;
          longitude = null;
          selectedCategory = null;
          selectedSubCategory = null;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Branch added successfully!")),
        // );

        Navigator.pop(context, {'refresh': true});
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to add branch: ${e.toString()}")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    bool isEnabled = true,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: SizedBox(),
        icon: Icon(Icons.keyboard_arrow_down),
        items: items,
        onChanged: isEnabled ? onChanged : null,
      ),
    );
  }
}