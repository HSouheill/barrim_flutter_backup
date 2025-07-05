import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      final success = await ApiService.createReview(review);

      if (success) {
        // Clear form
        _commentController.clear();
        setState(() {
          _selectedRating = 0;
        });

        // Refresh reviews
        await _fetchReviews();

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Review submitted successfully')),
        // );
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
    final isNetworkImage = review.userProfilePic.startsWith('http');
    final imageProvider = isNetworkImage
        ? null
        : AssetImage(review.userProfilePic.isEmpty
        ? ''
        : review.userProfilePic);

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
                        backgroundImage: isNetworkImage ? null : imageProvider,
                        onBackgroundImageError: (_, __) {
                          // Fallback if image fails to load
                        },
                        child: isNetworkImage
                            ? ClipOval(
                                child: SecureNetworkImage(
                                  imageUrl: review.userProfilePic,
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
                                          // ScaffoldMessenger.of(context).showSnackBar(
                                          //   SnackBar(content: Text('Failed to submit reply: \\${e.toString()}')),
                                          // );
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}