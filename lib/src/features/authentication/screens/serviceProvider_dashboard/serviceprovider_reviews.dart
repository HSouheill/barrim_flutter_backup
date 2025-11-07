import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../models/review.dart';
import '../../../../services/api_service.dart';
import '../../../../services/serviceprovider_controller.dart';
import '../../headers/service_provider_header.dart';
import '../../../../services/service_provider_services.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class ServiceProviderReviews extends StatefulWidget {
  final String providerId;

  const ServiceProviderReviews({
    Key? key,
    required this.providerId,
  }) : super(key: key);

  @override
  State<ServiceProviderReviews> createState() => _ServiceProviderReviewsState();
}

class _ServiceProviderReviewsState extends State<ServiceProviderReviews> {
  List<Review> reviews = [];
  bool isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;
  Map<String, bool> showReplyFields = {};

  // Add service provider controller
  late ServiceProviderController _serviceProviderController;
  final ServiceProviderService _serviceProviderService = ServiceProviderService();

  @override
  void initState() {
    super.initState();
    _fetchReviews();

    // Initialize the service provider controller
    _serviceProviderController = ServiceProviderController();
    _fetchServiceProviderData();
  }

  Future<void> _fetchServiceProviderData() async {
    await _serviceProviderController.initialize();
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

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
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
      // Create review object
      final review = Review(
        id: '', // Will be assigned by the backend
        serviceProviderId: widget.providerId,
        userId: '', // Will be assigned by the backend based on token
        username: '', // Will be assigned by the backend
        userProfilePic: '', // Will be assigned by the backend
        rating: _selectedRating,
        comment: _commentController.text.trim(),
        isVerified: false, // Will be managed by the backend
        createdAt: DateTime.now(),
      );

      // Submit review
      // Backend will automatically send notification to service provider
      final result = await ApiService.createReview(review);

      if (result['success'] == true) {
        // Clear form
        _commentController.clear();
        setState(() {
          _selectedRating = 0;
        });

        // Refresh reviews
        await _fetchReviews();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Review submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit review'),
            backgroundColor: Colors.red,
          ),
        );
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
    return ChangeNotifierProvider.value(
      value: _serviceProviderController,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Updated to use the Consumer with ServiceProviderController
            Consumer<ServiceProviderController>(
              builder: (context, controller, _) {
                return ServiceProviderHeader(
                  serviceProvider: controller.serviceProvider,
                  isLoading: controller.isLoading,
                  onLogoNavigation: () {
                    // Navigate back to the previous screen
                    Navigator.of(context).pop();
                  },
                );
              },
            ),

            // Title with horizontal lines
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.blue[200])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.blue[200])),
                ],
              ),
            ),

            // Reviews list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : reviews.isEmpty
                  ? const Center(
                child: Text(
                  'No reviews yet. Be the first to review!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return Column(
                    children: [
                      _buildReviewItem(review),
                      if (index < reviews.length - 1)
                        const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(Review review) {
    // Check if userProfilePic is not empty and is a network URL
    final hasValidProfilePic = review.userProfilePic.isNotEmpty;
    final isNetworkImage = hasValidProfilePic && review.userProfilePic.startsWith('http');
    
    return StatefulBuilder(
      builder: (context, setItemState) {
        final replyController = TextEditingController();
        final showReplyField = ValueNotifier<bool>(false);

        return ValueListenableBuilder<bool>(
          valueListenable: showReplyField,
          builder: (context, isReplyVisible, _) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: hasValidProfilePic && isNetworkImage
                            ? ClipOval(
                                child: SecureNetworkImage(
                                  imageUrl: review.userProfilePic,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  placeholder: Icon(Icons.person, size: 20, color: Colors.grey[600]),
                                  errorWidget: (context, url, error) => Icon(Icons.person, size: 20, color: Colors.grey[600]),
                                ),
                              )
                            : Icon(Icons.person, size: 20, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),

                      // User details and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  review.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (review.isVerified) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified, size: 14, color: Colors.blue),
                                ],
                                const Spacer(),
                                Text(
                                  review.getFormattedDate(),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            // Star rating
                            Row(
                              children: List.generate(
                                5,
                                    (index) => Icon(
                                  index < review.rating ? Icons.star : Icons.star_border,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Review text
                  Padding(
                    padding: const EdgeInsets.only(left: 52.0, top: 8, bottom: 8),
                    child: Text(
                      review.comment,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),

                  // Media display (image or video)
                  if (review.mediaUrl != null && review.mediaType != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0, top: 8, bottom: 8),
                      child: _buildMediaWidget(review),
                    ),

                  // Show reply if exists
                  if (review.reply != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0, top: 4, bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.reply, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.reply!.replyText,
                                    style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Replied on: '
                                        '${review.reply!.createdAt.month.toString().padLeft(2, '0')}/'
                                        '${review.reply!.createdAt.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reply button row (only if no reply yet)
                  if (review.reply == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0),
                      child: Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              showReplyField.value = true;
                            },
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Reply input field (appears when "Reply" is clicked)
                  if (isReplyVisible && review.reply == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 52.0, top: 8.0, bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: replyController,
                                      decoration: InputDecoration(
                                        hintText: 'Write reply',
                                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send, color: Colors.blue),
                                    onPressed: () async {
                                      if (replyController.text.isNotEmpty) {
                                        try {
                                          print('Posting reply for review ID: ${review.id}');
                                          print('Reply text: ${replyController.text.trim()}');
                                          await _serviceProviderService.postReviewReply(
                                            reviewId: review.id,
                                            replyText: replyController.text.trim(),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Reply submitted')),
                                          );
                                          replyController.clear();
                                          showReplyField.value = false;
                                          // Refresh reviews to show the reply
                                          await _fetchReviews();
                                        } catch (e) {
                                          print('Error posting reply: $e');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to submit reply: ${e.toString()}')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaWidget(Review review) {
    if (review.mediaType == 'image') {
      // Construct full URL if mediaUrl is relative
      String fullImageUrl = review.mediaUrl!;
      if (!fullImageUrl.startsWith('http')) {
        // Remove leading slash if present to avoid double slashes
        String cleanPath = fullImageUrl.startsWith('/') ? fullImageUrl.substring(1) : fullImageUrl;
        fullImageUrl = '${ApiService.baseUrl}/$cleanPath';
      }
      
      // Debug: Print the URL being used
      print('Loading image from URL: $fullImageUrl');
      
      return GestureDetector(
        onTap: () => _showImageDialog(context, fullImageUrl),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 200,
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildAuthenticatedImage(fullImageUrl),
          ),
        ),
      );
    } else if (review.mediaType == 'video') {
      // Construct full URL if mediaUrl is relative
      String fullVideoUrl = review.mediaUrl!;
      if (!fullVideoUrl.startsWith('http')) {
        fullVideoUrl = 'https://barrim.online$fullVideoUrl';
      }
      
      return Container(
        constraints: const BoxConstraints(
          maxWidth: 200,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            height: 200,
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildAuthenticatedImage(String imageUrl) {
    return FutureBuilder<Map<String, String>>(
      future: _getAuthHeaders(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.network(
            imageUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            headers: snapshot.data,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Image loading error for URL: $imageUrl');
              print('Error details: $error');
              print('Stack trace: $stackTrace');
              return Container(
                width: 200,
                height: 200,
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Failed to load',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      return {
        'Content-Type': 'application/json',
        'Authorization': token != null ? 'Bearer $token' : '',
      };
    } catch (e) {
      print('Error getting auth headers: $e');
      return {
        'Content-Type': 'application/json',
      };
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Full screen image
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: FutureBuilder<Map<String, String>>(
                    future: _getAuthHeaders(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          headers: snapshot.data,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: MediaQuery.of(context).size.height * 0.9,
                              color: Colors.black54,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Full screen image loading error for URL: $imageUrl');
                            print('Error details: $error');
                            return Container(
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: MediaQuery.of(context).size.height * 0.9,
                              color: Colors.black54,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          height: MediaQuery.of(context).size.height * 0.9,
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}