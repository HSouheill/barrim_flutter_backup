import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../../models/review.dart';
import '../../../../../services/api_service.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class ReviewsSection extends StatefulWidget {
  final String providerId;

  const ReviewsSection({
    Key? key,
    required this.providerId,
  }) : super(key: key);

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  List<Review> reviews = [];
  bool isLoading = true;
  int selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  // Media handling variables
  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  bool _isMediaUploading = false;
  String? _mediaType; // 'image' or 'video'

  // Constants for media validation
  static const int _maxImageSizeInMB = 5;
  static const int _maxVideoSizeInMB = 50;
  static const int _maxVideoDurationInMinutes = 2;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedReviews = await ApiService.getReviewsForProvider(widget.providerId);

      setState(() {
        reviews = fetchedReviews;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching reviews: $e');
    }
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    try {
      setState(() {
        _isMediaUploading = true;
      });

      final XFile? media;
      if (type == 'image') {
        media = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } else {
        media = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: _maxVideoDurationInMinutes),
        );
      }

      if (media != null) {
        // Validate file size
        final file = File(media.path);
        final fileSizeInBytes = await file.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (type == 'image' && fileSizeInMB > _maxImageSizeInMB) {
          throw Exception('Image size must be less than $_maxImageSizeInMB MB');
        } else if (type == 'video' && fileSizeInMB > _maxVideoSizeInMB) {
          throw Exception('Video size must be less than $_maxVideoSizeInMB MB');
        }

        setState(() {
          _selectedMedia = file;
          _mediaType = type;
        });
      }
    } catch (e) {
      String errorMessage = 'Error picking media: ';
      if (e.toString().contains('size')) {
        errorMessage = e.toString();
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Please grant camera and storage permissions to upload media';
      } else {
        errorMessage += e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } finally {
      setState(() {
        _isMediaUploading = false;
      });
    }
  }

  void _showMediaPickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Add Media',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                subtitle: Text('Max size: $_maxImageSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose Photo'),
                subtitle: Text('Max size: $_maxImageSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                subtitle: Text('Max duration: $_maxVideoDurationInMinutes min, Max size: $_maxVideoSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, 'video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Video'),
                subtitle: Text('Max duration: $_maxVideoDurationInMinutes min, Max size: $_maxVideoSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, 'video');
                },
              ),
              if (_selectedMedia != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Media', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMedia = null;
                      _mediaType = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create review object with media information
      final review = Review(
        id: '', // Will be assigned by the backend
        serviceProviderId: widget.providerId,
        userId: '', // Will be assigned by the backend based on token
        username: '', // Will be assigned by the backend
        userProfilePic: '', // Will be assigned by the backend
        rating: selectedRating,
        comment: _commentController.text.trim(),
        isVerified: false, // Will be managed by the backend
        createdAt: DateTime.now(),
        mediaFile: _selectedMedia, // Add the media file
        mediaType: _mediaType, // Add the media type
      );

      // Submit review
      final success = await ApiService.createReview(review);

      if (success) {
        // Clear form and media
        _commentController.clear();
        setState(() {
          selectedRating = 0;
          _selectedMedia = null;
          _mediaType = null;
        });

        // Refresh reviews
        await _fetchReviews();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully')),
        );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to submit review')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: ${e.toString()}')),
      // );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reviews Header with dividers
        Row(
          children: [
            Expanded(child: Divider(color: Colors.blue[200])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
              child: Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.blue[200])),
          ],
        ),
        const SizedBox(height: 4),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Filter by',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Rating',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reviews list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : reviews.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No reviews yet. Be the first to review!',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          )
              : Column(
            children: [
              ...reviews.map((review) => Column(
                children: [
                  _buildReviewItem(
                    name: review.username,
                    date: review.getFormattedDate(),
                    rating: review.rating,
                    comment: review.comment,
                    imageUrl: review.userProfilePic.isNotEmpty
                        ? review.userProfilePic
                        : '',
                    isVerified: review.isVerified,
                  ),
                  const SizedBox(height: 16),
                ],
              )).toList(),
            ],
          ),
        ),

        // Add review input field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User avatar - blue circle (outside the container), positioned slightly lower
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Input field container with all elements inside
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Top row with text field and stars
                      Row(
                        children: [
                          // Add Review text field
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add Review',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              maxLines: 1,
                            ),
                          ),

                          // Rating stars
                          Row(
                            children: List.generate(
                              5,
                                  (index) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2.0),
                                  child: Icon(
                                    index < selectedRating ? Icons.star : Icons.star_border,
                                    color: index < selectedRating ? Colors.blue : Colors.grey[400],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Divider or space between rows
                      const SizedBox(height: 4),

                      // Bottom row with media icons and post button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side - media icons with functionality
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _isMediaUploading ? null : () => _showMediaPickerModal(),
                                child: Icon(
                                  _selectedMedia != null ? Icons.edit : Icons.photo_camera_outlined,
                                  color: _isMediaUploading ? Colors.grey : Colors.blue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_selectedMedia != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMedia = null;
                                      _mediaType = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),

                          // Post button
                          _isSubmitting
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : GestureDetector(
                            onTap: _submitReview,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0), // Add padding to increase tap target
                              child: Text(
                                'Post',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Add media preview after the input field container:
        if (_selectedMedia != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _mediaType == 'image'
                      ? Image.file(
                          _selectedMedia!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(
                          color: Colors.black,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_outline,
                                size: 50,
                                color: Colors.white,
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Text(
                                  'Video selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    backgroundColor: Colors.black54,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (_isMediaUploading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 8),
                          Text(
                            'Processing media...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String date,
    required int rating,
    required String comment,
    required String imageUrl,
    required bool isVerified,
  }) {
    final isNetworkImage = imageUrl.startsWith('http');
    final imageProvider = isNetworkImage
        ? null
        : AssetImage(imageUrl) as ImageProvider;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User avatar
        CircleAvatar(
          radius: 24,
          backgroundImage: isNetworkImage
              ? null
              : imageProvider,
          child: isNetworkImage
              ? ClipOval(
                  child: SecureNetworkImage(
                    imageUrl: imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: Icon(Icons.person, size: 20),
                    errorWidget: (context, url, error) => Icon(Icons.person, size: 20),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),

        // Review content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name, verification badge and date
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Star rating
              Row(
                children: List.generate(
                  5,
                      (index) => Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Review text
              Text(
                comment,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}