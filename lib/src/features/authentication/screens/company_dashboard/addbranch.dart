import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:location/location.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';  // Add this import for TextInputFormatter
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../../../../services/api_service.dart';

class AddBranchPage extends StatefulWidget {
  final String token;

  final bool isEditMode;
  final Map<String, dynamic>? branchData;

  const AddBranchPage({
    Key? key,
    required this.token,
    this.isEditMode = false,
    this.branchData,
  }) : super(key: key);

  @override
  State<AddBranchPage> createState() => _AddBranchPageState();
}

class _AddBranchPageState extends State<AddBranchPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costPerCustomerController = TextEditingController();
  bool _isLoading = false;
  String? selectedCategory;
  String? selectedSubCategory;
  String countryCode = '+961';

  // Image and video handling
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  List<String> _existingImageUrls = []; // For storing existing image URLs
  bool _isLoadingLocation = false;

  // Location data
  double? latitude;
  double? longitude;

  // Dynamic categories and subcategories loaded from backend
  List<String> categories = [];
  Map<String, List<String>> subCategories = {};
  bool _isLoadingCategories = true;
  String? _categoriesError;

  // Image compression methods
  Future<File> _compressAndResizeImage(File imageFile) async {
    try {
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Could not decode image');
      }

      // Resize image to reasonable dimensions (e.g., 800x800)
      final resizedImage = img.copyResize(
        image,
        width: 800,
        height: 800,
        interpolation: img.Interpolation.linear,
      );

      // Compress the image with quality 85
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Create a temporary file for the compressed image
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_branch_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await tempFile.writeAsBytes(compressedBytes);
      
      print('Image compressed: Original size: ${bytes.length} bytes, Compressed size: ${compressedBytes.length} bytes');
      
      return tempFile;
    } catch (e) {
      print('Error compressing image: $e');
      // If compression fails, return the original image
      return imageFile;
    }
  }

  Future<List<File>> _compressImages(List<File> images) async {
    List<File> compressedImages = [];
    for (var image in images) {
      try {
        final compressedImage = await _compressAndResizeImage(image);
        compressedImages.add(compressedImage);
      } catch (e) {
        print('Error compressing image: $e');
        compressedImages.add(image); // Use original if compression fails
      }
    }
    return compressedImages;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _costPerCustomerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Load existing data if in edit mode
    if (widget.isEditMode && widget.branchData != null) {
      _loadBranchData();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoriesError = null;
      });

      print('AddBranchPage: Loading categories from backend...');
      final categoriesData = await ApiService.getAllCategories();
      print('AddBranchPage: Received categories: $categoriesData');
      
      if (mounted) {
        setState(() {
          categories = categoriesData.keys.toList();
          subCategories = categoriesData;
          _isLoadingCategories = false;
        });
        print('AddBranchPage: Categories loaded successfully. Count: ${categories.length}');
        print('AddBranchPage: Categories: $categories');
        print('AddBranchPage: Subcategories: $subCategories');
      }
    } catch (e) {
      print('AddBranchPage: Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'Failed to load categories: $e';
          // Don't set fallback categories - let the UI handle empty state
          categories = [];
          subCategories = {};
        });
      }
    }
  }

  void _loadBranchData() {
    final branchData = widget.branchData!;

    // Populate text fields
    _nameController.text = branchData['name']?.toString() ?? '';
    _locationController.text = branchData['location']?.toString() ?? '';
    _costPerCustomerController.text = branchData['costPerCustomer']?.toString() ?? '';

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

    // Ensure the loaded category is in the categories list
    if (selectedCategory != null && selectedCategory!.isNotEmpty && !categories.contains(selectedCategory)) {
      categories.add(selectedCategory!);
    }
    // Ensure the loaded subcategory is in the subCategories map
    if (selectedCategory != null && selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
      if (!subCategories.containsKey(selectedCategory)) {
        subCategories[selectedCategory!] = [selectedSubCategory!];
      } else if (!subCategories[selectedCategory!]!.contains(selectedSubCategory)) {
        subCategories[selectedCategory!]!.add(selectedSubCategory!);
      }
    }

    // Load existing images if available
    if (branchData['images'] != null && branchData['images'] is List) {
      List<String> imageUrls = [];
      print('AddBranchPage: Loading existing images from branch data: ${branchData['images']}');
      for (var image in branchData['images']) {
        if (image != null && image is String && image.isNotEmpty) {
          // Convert relative paths to full URLs if needed
          String fullUrl = image;
          if (!image.startsWith('http')) {
            fullUrl = '${ApiService.baseUrl}/$image';
          }
          imageUrls.add(fullUrl);
          print('AddBranchPage: Added image URL: $fullUrl');
        }
      }
      setState(() {
        _existingImageUrls = imageUrls;
      });
      print('AddBranchPage: Loaded ${imageUrls.length} existing images');
    } else {
      print('AddBranchPage: No existing images found in branch data');
    }

    // Load existing videos if available
    if (branchData['videos'] != null && branchData['videos'] is List) {
      // For now, we'll just note that videos exist
      // In a full implementation, you might want to download and display video thumbnails
      print('Branch has ${branchData['videos'].length} existing videos');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        List<File> validImages = [];
        
        for (var xFile in pickedFiles) {
          final file = File(xFile.path);
          final fileSize = await file.length();
          final maxSize = 10 * 1024 * 1024; // 10MB limit
          
          if (fileSize > maxSize) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Image ${xFile.name} is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). It will be compressed.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
          validImages.add(file);
        }
        
        setState(() {
          _selectedImages.addAll(validImages);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking images: $e")),
        );
      }
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

  Future<void> _pickMultipleVideos() async {
    try {
      // Show a dialog to let user pick multiple videos one by one
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Add Multiple Videos'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('You can add multiple videos one by one.'),
                SizedBox(height: 16),
                Text('Current videos: ${_selectedVideos.length}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Done'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickVideo(); // Pick one video at a time
                },
                child: Text('Add Another Video'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error picking videos: $e")),
      // );
    }
  }

  void _clearAllMedia() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All Media'),
          content: Text('Are you sure you want to remove all images and videos?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedImages.clear();
                  _selectedVideos.clear();
                  _existingImageUrls.clear();
                });
                Navigator.pop(context);
              },
              child: Text('Clear All'),
            ),
          ],
        );
      },
    );
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
                  subtitle: Text('Select multiple images'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.videocam, color: Color(0xFF2079C2)),
                  title: Text('Add Single Video'),
                  subtitle: Text('Select one video'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.video_library, color: Color(0xFF2079C2)),
                  title: Text('Add Multiple Videos'),
                  subtitle: Text('Select multiple videos'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultipleVideos();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location services are disabled")),
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
          SnackBar(content: Text("Location permission denied")),
        );
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

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LocationMapDialog(
          initialLatitude: latitude,
          initialLongitude: longitude,
          onLocationSelected: (LatLng position, String address) {
            setState(() {
              latitude = position.latitude;
              longitude = position.longitude;
              _locationController.text = address;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Existing images preview (for edit mode)
                  if (widget.isEditMode && _existingImageUrls.isNotEmpty) ...[
                    // Debug print
                    Builder(
                      builder: (context) {
                        print('AddBranchPage: Rendering existing images section with ${_existingImageUrls.length} images');
                        return SizedBox.shrink();
                      },
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Existing Images (${_existingImageUrls.length})",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _existingImageUrls.clear();
                                });
                              },
                              child: Text(
                                "Remove All",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey[400],
                                              size: 30,
                                            ),
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
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Selected images preview
                  if (_selectedImages.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "New Images (${_selectedImages.length})",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedImages.clear();
                                });
                              },
                              child: Text(
                                "Clear All",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                  if (_selectedVideos.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Selected Videos (${_selectedVideos.length})",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedVideos.clear();
                                });
                              },
                              child: Text(
                                "Clear All",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.videocam, size: 30, color: Colors.grey.shade700),
                                            SizedBox(height: 4),
                                            Text(
                                              "Video ${index + 1}",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
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
                      ],
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
                            if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty || _existingImageUrls.isNotEmpty) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${_selectedImages.length + _selectedVideos.length + _existingImageUrls.length}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Name field
                  _buildFieldLabel("Name"),
                  _buildTextField(_nameController, "Name"),
                  SizedBox(height: 16),

                  // Location field with map
                  _buildLocationField(),
                  SizedBox(height: 16),

                  // Category and Sub Category fields
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("Category"),
                            if (_isLoadingCategories)
                              _buildLoadingCategoryField()
                            else if (_categoriesError != null)
                              _buildErrorCategoryField()
                            else if (categories.isEmpty)
                              _buildEmptyCategoryField()
                            else
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
                            if (_isLoadingCategories)
                              _buildLoadingSubCategoryField()
                            else if (_categoriesError != null)
                              _buildErrorSubCategoryField()
                            else if (selectedCategory == null)
                              _buildDisabledSubCategoryField()
                            else if (subCategories[selectedCategory]?.isEmpty ?? true)
                              _buildEmptySubCategoryField()
                            else
                              _buildDropdown(
                                value: selectedSubCategory,
                                items: subCategories[selectedCategory]!.map((subCat) => DropdownMenuItem(
                                  value: subCat,
                                  child: Text(subCat),
                                )).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedSubCategory = value as String?;
                                  });
                                },
                                hint: "Sub Category",
                                isEnabled: true,
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
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Cost Per Customer field
                  _buildFieldLabel("Cost Per Customer"),
                  TextField(
                    controller: _costPerCustomerController,
                    decoration: InputDecoration(
                      hintText: "Cost Per Customer",
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                      ElevatedButton(
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

  void _onUpdate() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a name")),
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

    final updatedBranchData = {
      '_id': branchId,
      'name': _nameController.text,
      'location': _locationController.text.isNotEmpty ? _locationController.text : "Unknown location",
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'category': selectedCategory ?? "Uncategorized",
      'subCategory': selectedSubCategory ?? "Uncategorized",
      'phone': '${countryCode ?? "+961"} ${_phoneController.text.isNotEmpty ? _phoneController.text : "000000"}',
      'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : "No description",
      'costPerCustomer': _costPerCustomerController.text.isNotEmpty ? double.parse(_costPerCustomerController.text) : null,
      // Include existing images that should be kept
      'existingImages': _existingImageUrls,
    };

    try {
      // Compress images before sending to prevent 413 error
      List<File> compressedImages = [];
      if (_selectedImages.isNotEmpty) {
        compressedImages = await _compressImages(_selectedImages);
      }

      // Call API service to update branch with compressed images
      await ApiService.updateBranch(widget.token, branchId, updatedBranchData, compressedImages, _selectedVideos);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Branch updated successfully!")),
      // );
      Navigator.pop(context, updatedBranchData);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Extract address components from the location string
    List<String> addressParts = _locationController.text.split(', ');
    String street = addressParts.isNotEmpty ? addressParts[0] : '';
    String city = addressParts.length > 1 ? addressParts[1] : '';
    String country = addressParts.length > 2 ? addressParts.last : '';

    final branchData = {
      'name': _nameController.text,
      'location': _locationController.text,
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'category': selectedCategory ?? 'Uncategorized',
      'subCategory': selectedSubCategory ?? 'Uncategorized',
      'phone': '$countryCode ${_phoneController.text}',
      'description': _descriptionController.text,
      'costPerCustomer': _costPerCustomerController.text.isNotEmpty ? double.parse(_costPerCustomerController.text) : null,
      // Structured address data that matches backend model
      'country': country,
      'district': '',
      'city': city,
      'street': street,
      'postalCode': '',
    };

    try {
      // Compress images before sending to prevent 413 error
      List<File> compressedImages = [];
      if (_selectedImages.isNotEmpty) {
        compressedImages = await _compressImages(_selectedImages);
      }

      // Call API to upload branch with compressed images
      await ApiService.uploadBranchData(branchData, compressedImages, _selectedVideos);

      // Clear form
      _nameController.clear();
      _locationController.clear();
      _phoneController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedImages = [];
        _selectedVideos = [];
        _existingImageUrls = [];
        latitude = null;
        longitude = null;
        selectedCategory = null;
        selectedSubCategory = null;
      });

      // Show custom popup
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BranchRequestSentDialog(),
      );
      await Future.delayed(const Duration(seconds: 4));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close the dialog
      }

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Branch added successfully!")),
      // );

      // Return the branch data with a flag to refresh
      Navigator.pop(context, {'refresh': true, ...branchData});
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

  Widget _buildLoadingCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.red.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                "Failed to load categories",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          TextButton(
            onPressed: _loadCategories,
            child: Text(
              "Retry",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text("No categories available"),
      ),
    );
  }

  Widget _buildLoadingSubCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorSubCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.red.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                "Failed to load subcategories",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
          TextButton(
            onPressed: _loadCategories,
            child: Text(
              "Retry",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledSubCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text("Select a category first"),
      ),
    );
  }

  Widget _buildEmptySubCategoryField() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          "No subcategories available (backend doesn't provide subcategories yet)",
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        GestureDetector(
          onTap: _showLocationPicker,
          child: AbsorbPointer(
            child: _buildTextField(_locationController, "Tap to select location"),
          ),
        ),
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
      ],
    );
  }
}

class LocationMapDialog extends StatefulWidget {
  final Function(LatLng position, String address) onLocationSelected;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationMapDialog({
    Key? key,
    required this.onLocationSelected,
    this.initialLatitude,
    this.initialLongitude,
  }) : super(key: key);

  @override
  State<LocationMapDialog> createState() => _LocationMapDialogState();
}

class _LocationMapDialogState extends State<LocationMapDialog> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(33.8, 35.8); // Center of Lebanon
  Set<Marker> markers = {};
  LatLng? selectedLocation;
  bool isLoading = false;
  String? fullAddress;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _addMarker(LatLng(widget.initialLatitude!, widget.initialLongitude!));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          return;
        }
      }

      loc.LocationData locationData = await location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        LatLng userLocation = LatLng(locationData.latitude!, locationData.longitude!);
        mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: userLocation, zoom: 15),
        ));
        _addMarker(userLocation);
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error getting location: $e')),
      // );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          fullAddress = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}'
              .replaceAll(RegExp(r'null,?\s*'), '')
              .replaceAll(RegExp(r',\s*,'), ',')
              .replaceAll(RegExp(r'^\s*,\s*'), '')
              .replaceAll(RegExp(r'\s*,\s*$'), '');
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  void _addMarker(LatLng position) {
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      selectedLocation = position;
      _getAddressFromLatLng(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Location',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF05054F),
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: widget.initialLatitude != null && widget.initialLongitude != null
                            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
                            : _center,
                        zoom: widget.initialLatitude != null ? 15 : 7,
                      ),
                      markers: markers,
                      onTap: _addMarker,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        onPressed: _getCurrentLocation,
                        child: Icon(Icons.my_location, color: Color(0xFF05054F)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (fullAddress != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  fullAddress!,
                  style: GoogleFonts.nunito(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedLocation == null ? null : () {
                      widget.onLocationSelected(selectedLocation!, fullAddress ?? '');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0066B3),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Confirm Location'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

class _BranchRequestSentDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2079C2), size: 60),
            const SizedBox(height: 16),
            Text(
              'Branch request sent to the admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2079C2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your branch request has been submitted and is pending admin approval.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}