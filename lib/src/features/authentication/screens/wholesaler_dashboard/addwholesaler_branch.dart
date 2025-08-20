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
    _locationController.removeListener(_onLocationChanged);
    _locationController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    
    // Add listener to location controller for manual input
    _locationController.addListener(_onLocationChanged);
    
    // Load existing data if in edit mode
    if (widget.isEditMode && widget.branchData != null) {
      _loadBranchData();
      _loadMediaFromExistingBranch();
    }
  }

  void _onLocationChanged() {
    // If user types in location field and we don't have coordinates, show the manual location button
    if (_locationController.text.isNotEmpty && (latitude == null || longitude == null)) {
      setState(() {
        // Trigger rebuild to show manual location button
      });
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
        List<File> validImages = [];
        List<String> skippedFiles = [];
        
        for (var xFile in pickedFiles) {
          final file = File(xFile.path);
          try {
            final fileSize = await file.length();
            final maxSize = 5 * 1024 * 1024; // 5MB limit for UI warning
            
            if (fileSize > maxSize) {
              skippedFiles.add('${xFile.name} (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)');
            } else {
              validImages.add(file);
            }
          } catch (e) {
            print('Error checking file size: $e');
            validImages.add(file); // Add anyway if we can't check size
          }
        }
        
        setState(() {
          _selectedImages.addAll(validImages);
        });
        
        if (skippedFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Skipped large files: ${skippedFiles.join(', ')}. Max size: 5MB"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking images: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        try {
          final fileSize = await file.length();
          final maxSize = 25 * 1024 * 1024; // 25MB limit for UI warning
          
          if (fileSize > maxSize) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Video is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Max size: 25MB"),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }
          
          setState(() {
            _selectedVideos.add(file);
          });
        } catch (e) {
          print('Error checking video file size: $e');
          setState(() {
            _selectedVideos.add(file);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking video: $e"),
          backgroundColor: Colors.red,
        ),
      );
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

    try {
      // Check if location service is enabled
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          setState(() {
            _isLoadingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location services are disabled. Please enable location services in your device settings."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location permission denied. Please grant location permission in your device settings."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }

      // Get location
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location captured successfully!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _isLoadingLocation = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location captured but couldn't get address. You can type the address manually."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to get location coordinates. Please try again or type the address manually."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to get location: $e. Please type the address manually."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Method to handle manual location input
  void _handleManualLocationInput() {
    String locationText = _locationController.text.trim();
    if (locationText.isNotEmpty) {
      // Set default coordinates for Lebanon (Beirut) when user types manually
      if (latitude == null || longitude == null) {
        setState(() {
          latitude = 33.8935; // Beirut latitude
          longitude = 35.5018; // Beirut longitude
        });
      
      }
    }
  }

  // Method to show file processing results
  void _showFileProcessingResults(int originalImageCount, int processedImageCount, int originalVideoCount, int processedVideoCount) {
    if (originalImageCount > processedImageCount || originalVideoCount > processedVideoCount) {
      String message = "";
      if (originalImageCount > processedImageCount) {
        message += "${originalImageCount - processedImageCount} large images were compressed or skipped. ";
      }
      if (originalVideoCount > processedVideoCount) {
        message += "${originalVideoCount - processedVideoCount} large videos were skipped. ";
      }
      message += "Only files under size limits will be uploaded.";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
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
                                // File size indicator
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FutureBuilder<String>(
                                      future: _getFileSize(_selectedImages[index]),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? '...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
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
                                // File size indicator
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FutureBuilder<String>(
                                      future: _getFileSize(_selectedVideos[index]),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? '...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
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
                  
                  // File size limits info
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "📁 File limits: Images max 5MB, Videos max 25MB. Large files will be automatically compressed or skipped.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
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
                            Icon(Icons.my_location, size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Auto-pin",
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
                  
                  
                  
                  // Warning when coordinates are missing
                  if (_locationController.text.isNotEmpty && (latitude == null || longitude == null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Location coordinates not set. Please use one of the buttons below to set coordinates.",
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Manual location button
                  if (_locationController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleManualLocationInput(),
                              icon: Icon(Icons.edit_location, size: 16),
                              label: Text("Set Coordinates for Manual Location"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          
                        ],
                      ),
                    ),
                  
                  if (latitude != null && longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Coordinates set: Lat: ${latitude!.toStringAsFixed(6)}, Long: ${longitude!.toStringAsFixed(6)}",
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a location")),
      );
      return;
    }

    // Check if we have coordinates (either from GPS or manual input)
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please set location coordinates. Use 'Auto-pin' or 'Set Coordinates for Manual Location' button."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
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
      // Improved address parsing with fallbacks (same as _onAdd)
      String locationText = _locationController.text.trim();
      List<String> locationParts = locationText.split(',').map((e) => e.trim()).toList();
      
      String country = 'Lebanon'; // Default country
      String city = 'Beirut';     // Default city
      String street = locationText; // Default to full text if parsing fails
      String district = '';
      String postalCode = '';

      if (locationParts.length >= 3) {
        // Format: Street, City, Country
        street = locationParts[0];
        city = locationParts[1];
        country = locationParts[2];
        if (locationParts.length > 3) {
          district = locationParts[1]; // Use second part as district
          city = locationParts[2];     // Use third part as city
          country = locationParts[3];  // Use fourth part as country
        }
      } else if (locationParts.length == 2) {
        // Format: Street, City
        street = locationParts[0];
        city = locationParts[1];
      } else if (locationParts.length == 1) {
        // Only street provided
        street = locationParts[0];
      }

      // Create address object
      final address = Address(
        country: country,
        district: district,
        city: city,
        street: street,
        postalCode: postalCode,
        lat: latitude ?? 0.0,
        lng: longitude ?? 0.0,
      );

      if (!mounted) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text("Updating branch..."),
            ],
          ),
          duration: Duration(seconds: 30), // Long duration for upload
        ),
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

      if (!mounted) return;

      if (updatedBranch != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Branch updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return the updated branch data to the previous screen
        Navigator.pop(context, {'branch': updatedBranch, 'refresh': true});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update branch. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = "Failed to update branch";
      
      if (e.toString().contains("Unauthorized")) {
        errorMessage = "Session expired. Please login again.";
      } else if (e.toString().contains("Wholesaler not found")) {
        errorMessage = "Wholesaler account not found. Please contact support.";
      } else if (e.toString().contains("Bad request")) {
        errorMessage = "Please check your input data and try again.";
      } else if (e.toString().contains("Server error")) {
        errorMessage = "Server error. Please try again later.";
      } else if (e.toString().contains("Authentication token not found")) {
        errorMessage = "Please login again to continue.";
      } else {
        errorMessage = "Error: ${e.toString()}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  void _onAdd() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a location")),
      );
      return;
    }

    // Check if we have coordinates (either from GPS or manual input)
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please set location coordinates. Use 'Auto-pin' or 'Set Coordinates for Manual Location' button."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Improved address parsing with fallbacks
      String locationText = _locationController.text.trim();
      List<String> locationParts = locationText.split(',').map((e) => e.trim()).toList();
      
      String country = 'Lebanon'; // Default country
      String city = 'Beirut';     // Default city
      String street = locationText; // Default to full text if parsing fails
      String district = '';
      String postalCode = '';

      if (locationParts.length >= 3) {
        // Format: Street, City, Country
        street = locationParts[0];
        city = locationParts[1];
        country = locationParts[2];
        if (locationParts.length > 3) {
          district = locationParts[1]; // Use second part as district
          city = locationParts[2];     // Use third part as city
          country = locationParts[3];  // Use fourth part as country
        }
      } else if (locationParts.length == 2) {
        // Format: Street, City
        street = locationParts[0];
        city = locationParts[1];
      } else if (locationParts.length == 1) {
        // Only street provided
        street = locationParts[0];
      }

      // Create address object using the wholesaler_model Address class
      final address = Address(
        country: country,
        district: district,
        city: city,
        street: street,
        postalCode: postalCode,
        lat: latitude!,
        lng: longitude!,
      );

      if (!mounted) return;


      // Call the service to create branch
      final branch = await WholesalerService().createBranch(
        name: _nameController.text,
        location: address,
        phone: '${countryCode ?? "+961"} ${_phoneController.text.isNotEmpty ? _phoneController.text : "000000"}',
        category: selectedCategory ?? 'Uncategorized',
        subCategory: selectedSubCategory ?? '',
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'No description provided',
        images: _selectedImages,
        videos: _selectedVideos,
      );

      if (!mounted) return;

      if (branch != null) {
        // Show file processing results feedback
        _showFileProcessingResults(_selectedImages.length, branch.images?.length ?? 0, _selectedVideos.length, branch.videos?.length ?? 0);
        
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Branch added successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, {'refresh': true});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to add branch. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = "Failed to add branch";
      
      if (e.toString().contains("Unauthorized")) {
        errorMessage = "Session expired. Please login again.";
      } else if (e.toString().contains("Wholesaler not found")) {
        errorMessage = "Wholesaler account not found. Please contact support.";
      } else if (e.toString().contains("Bad request")) {
        errorMessage = "Please check your input data and try again.";
      } else if (e.toString().contains("Server error")) {
        errorMessage = "Server error. Please try again later.";
      } else if (e.toString().contains("Authentication token not found")) {
        errorMessage = "Please login again to continue.";
      } else {
        errorMessage = "Error: ${e.toString()}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // Helper method to format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Helper method to get file size
  Future<String> _getFileSize(File file) async {
    try {
      final size = await file.length();
      return _formatFileSize(size);
    } catch (e) {
      return 'Unknown size';
    }
  }
}