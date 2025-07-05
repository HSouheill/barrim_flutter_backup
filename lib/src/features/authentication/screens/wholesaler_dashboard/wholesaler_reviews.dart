// Updated company_review.dart
import 'package:barrim/src/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Make sure provider is added to pubspec.yaml
import 'package:barrim/src/components/secure_network_image.dart';

import '../../../../models/branch_review.dart';
import '../../../../services/api_service.dart';

class WholesalerReviewsPage extends StatefulWidget {
  final String branchId;
  final String branchName;

  const WholesalerReviewsPage({
    Key? key,
    required this.branchId,
    required this.branchName,
  }) : super(key: key);

  @override
  State<WholesalerReviewsPage> createState() => _WholesalerReviewsPageState();
}

class _WholesalerReviewsPageState extends State<WholesalerReviewsPage> {
  List<BranchReview> reviews = [];
  bool isLoading = true;
  String errorMessage = '';
  bool hasMore = true;
  int page = 1;
  final int limit = 10;
  final ScrollController _scrollController = ScrollController();
  bool retryVisible = false;
  bool isCompanyUser = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _scrollController.addListener(_scrollListener);
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    // Check if the current user is a wholesaler or admin
    final authService = Provider.of<AuthService>(context, listen: false);
    final userType = await authService.getUserType();
    setState(() {
      isCompanyUser = userType == 'wholesaler' || userType == 'admin';
    });
    print("User type: $userType, isWholesalerUser: $isCompanyUser");
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        hasMore &&
        !isLoading) {
      _fetchMoreReviews();
    }
  }

  Future<void> _fetchReviews() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await ApiService.getBranchComments(
        widget.branchId,
        page: page,
        limit: limit,
      );

      if (response['status'] == 'success' || response['status'] == 200) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['comments'] is List && data['comments'].isNotEmpty) {
          final List<dynamic> commentsData = data['comments'];
          final List<BranchReview> newReviews = commentsData
              .map((item) => BranchReview.fromJson(item))
              .toList();

          setState(() {
            reviews = newReviews;
            isLoading = false;
            hasMore = newReviews.length >= limit;
            retryVisible = false;
          });
        } else {
          // Handle empty comments list
          setState(() {
            reviews = [];
            isLoading = false;
            hasMore = false;
            retryVisible = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = response['message'] ?? 'Failed to load reviews';
          retryVisible = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading reviews: $e';
        retryVisible = true;
      });
    }
  }

  Future<void> _fetchMoreReviews() async {
    if (!hasMore || isLoading) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nextPage = page + 1;
      final response = await ApiService.getBranchComments(
        widget.branchId,
        page: nextPage,
        limit: limit,
      );

      if (response['status'] == 'success' || response['status'] == 200) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['comments'] is List) {
          final List<dynamic> commentsData = data['comments'];
          final List<BranchReview> newReviews = commentsData
              .map((item) => BranchReview.fromJson(item))
              .toList();

          setState(() {
            reviews.addAll(newReviews);
            isLoading = false;
            page = nextPage;
            hasMore = newReviews.length >= limit;
          });
        } else {
          setState(() {
            isLoading = false;
            hasMore = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshReviews() async {
    page = 1;
    await _fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.branchName} Reviews'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshReviews,
        child: _buildReviewsList(),
      ),
      floatingActionButton: isCompanyUser
          ? null  // Don't show "Add Review" button for wholesaler users
          : FloatingActionButton(
        onPressed: () {
          // Add a new review (only for regular users, not wholesaler)
          _showAddReviewDialog();
        },
        backgroundColor: const Color(0xFF2079C2),
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (isLoading && reviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty && retryVisible) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchReviews,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No reviews yet. Be the first to review!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (errorMessage.isNotEmpty && !retryVisible)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == reviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final review = reviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(BranchReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and rating
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundImage: review.userImage.isNotEmpty
                    ? null
                    : const AssetImage('assets/default_avatar.png')
                as ImageProvider,
                backgroundColor: Colors.grey[300],
                child: review.userImage.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: review.userImage,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.grey),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('MM/dd/yyyy').format(review.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Star rating
              if (review.rating > 0)
                Row(
                  children: List.generate(
                    5,
                        (i) => Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Review text
          Text(
            review.comment,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Display existing replies
          if (review.replies.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Replies from Business',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ...review.replies.map((reply) => _buildReplyItem(reply)),
          ],

          // Reply button - now always shown (removed isCompanyUser condition)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showReplyDialog(review.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2079C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply as Business'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommentReply reply) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8, left: 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Business Response',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MM/dd/yyyy').format(reply.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply.reply,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    final TextEditingController commentController = TextEditingController();
    int selectedRating = 5;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rating selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                    (index) => IconButton(
                  onPressed: () {
                    selectedRating = index + 1;
                    Navigator.of(context).pop();
                    _showAddReviewDialog();
                  },
                  icon: Icon(
                    index < selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Comment text field
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Your comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a comment')),
                );
                return;
              }

              // Close the dialog
              Navigator.of(context).pop();

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Posting comment...')),
              );

              try {
                // Submit the review
                await ApiService.createBranchComment(
                  widget.branchId,
                  commentController.text.trim(),
                  selectedRating,
                );

                // Refresh the reviews list
                _refreshReviews();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment posted successfully')),
                );
              } catch (e) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Failed to post comment: $e')),
                // );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(String commentId) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: replyController,
              decoration: const InputDecoration(
                labelText: 'Your reply',
                border: OutlineInputBorder(),
                hintText: 'Thank you for your feedback...',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reply')),
                );
                return;
              }

              // Close the dialog
              Navigator.of(context).pop();

              // Show loading indicator
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Posting reply...')),
              // );

              try {
                // Submit the reply
                await ApiService.replyToBranchComment(
                  commentId,
                  replyController.text.trim(),
                );

                // Refresh the reviews to show the new reply
                _refreshReviews();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reply posted successfully')),
                );
              } catch (e) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Failed to post reply: $e')),
                // );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2079C2),
            ),
            child: const Text('Submit Reply'),
          ),
        ],
      ),
    );
  }
}