// Updated company_review.dart
import 'package:barrim/src/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Make sure provider is added to pubspec.yaml
import 'package:barrim/src/components/secure_network_image.dart';

import '../../../../models/branch_review.dart';
import '../../../../models/user.dart'; // You'll need this to check if user is a company
import '../../../../services/api_service.dart';
import '../../headers/company_header.dart';
import '../responsive_utils.dart';

class CompanyReviewsPage extends StatefulWidget {
  final String branchId;
  final String branchName;
   final Map<String, dynamic> userData;
   final String? logoUrl;

  const CompanyReviewsPage({
    Key? key,
    required this.branchId,
    required this.branchName,
    required this.userData,
    this.logoUrl,
  }) : super(key: key);

  @override
  State<CompanyReviewsPage> createState() => _CompanyReviewsPageState();
}

class _CompanyReviewsPageState extends State<CompanyReviewsPage> {
  List<BranchReview> reviews = [];
  bool isLoading = true;
  String errorMessage = '';
  bool hasMore = true;
  int page = 1;
  final int limit = 10;
  final ScrollController _scrollController = ScrollController();
  bool retryVisible = false;
  bool isCompanyUser = false;
  String? logoUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReviews();
      _checkUserType();
      _loadCompanyData();
    });
  }

  Future<void> _checkUserType() async {
    // Check if the current user is a company or admin
    final authService = Provider.of<AuthService>(context, listen: false);
    final userType = await authService.getUserType();
    setState(() {
      isCompanyUser = userType == 'company' || userType == 'admin';
    });
    print("User type: $userType, isCompanyUser: $isCompanyUser");
  }

  Future<void> _loadCompanyData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      if (token != null && token.isNotEmpty) {
        var data = await ApiService.getCompanyData(token);
        if (data['companyInfo'] != null) {
          setState(() {
            logoUrl = data['companyInfo']['logo'];
          });
        }
      }
    } catch (error) {
      print('Error loading company data: $error');
    }
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

      print('Fetching reviews for branch: ${widget.branchId}, page: $page');
      final response = await ApiService.getBranchComments(
        widget.branchId,
        page: page,
        limit: limit,
      );

      print('API response: $response');

      if (response['status'] == 'success' || response['status'] == 200) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['comments'] is List && data['comments'].isNotEmpty) {
          final List<dynamic> commentsData = data['comments'];
          final List<BranchReview> newReviews = commentsData
              .map((item) => BranchReview.fromJson(item))
              .toList();

          print('Parsed ${newReviews.length} reviews');
          for (var review in newReviews) {
            print('Review ${review.id}: ${review.replies.length} replies');
          }

          setState(() {
            reviews = newReviews;
            isLoading = false;
            hasMore = newReviews.length >= limit;
            retryVisible = false;
          });
        } else {
          // Handle empty comments list
          print('No comments found in response');
          setState(() {
            reviews = [];
            isLoading = false;
            hasMore = false;
            retryVisible = false;
          });
        }
      } else {
        print('API error: ${response['message']}');
        setState(() {
          isLoading = false;
          errorMessage = response['message'] ?? 'Failed to load reviews';
          retryVisible = true;
        });
      }
    } catch (e) {
      print('Error fetching reviews: $e');
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
    print('Refreshing reviews...');
    setState(() {
      page = 1;
      reviews.clear();
      hasMore = true;
    });
    await _fetchReviews();
    print('Reviews refreshed. Total reviews: ${reviews.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CompanyAppHeader(
            logoUrl: widget.logoUrl,
            userData: widget.userData,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshReviews,
              child: _buildReviewsList(),
            ),
          ),
        ],
      ),
      floatingActionButton: isCompanyUser
          ? null  // Don't show "Add Review" button for company users
          : FloatingActionButton(
        onPressed: () {
          // Add a new review (only for regular users, not companies)
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
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
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
          ),
        ),
      );
    }

    if (reviews.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
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
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
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
      key: ValueKey(review.id),
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getCardPadding(context) * 0.4),
      padding: EdgeInsets.all(ResponsiveUtils.getCardPadding(context) * 0.6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 0.5,
            blurRadius: 4,
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
                radius: ResponsiveUtils.getIconSize(context) * 0.6,
                backgroundImage: review.userImage.isNotEmpty
                    ? null
                    : const AssetImage('assets/default_avatar.png')
                as ImageProvider,
                backgroundColor: Colors.grey[300],
                child: review.userImage.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: review.userImage,
                          width: ResponsiveUtils.getIconSize(context) * 1.2,
                          height: ResponsiveUtils.getIconSize(context) * 1.2,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.7),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.7),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.7),
              ),
              SizedBox(width: ResponsiveUtils.getGridSpacing(context) * 0.6),
              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getSubtitleFontSize(context) * 0.7,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.getGridSpacing(context) * 0.2),
                        // Add verification checkmark if needed
                        if (review.rating >= 5)
                          Icon(
                            Icons.verified,
                            size: ResponsiveUtils.getIconSize(context) * 0.3,
                            color: Colors.blue[600],
                          ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.1),
                    Text(
                      DateFormat('MM/dd').format(review.date),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.7,
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
                      size: ResponsiveUtils.getIconSize(context) * 0.6,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.4),
          // Review text
          Text(
            review.comment,
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.85,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.4),

          // Display existing replies
          if (review.replies.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.3),
            ...review.replies.map((reply) => _buildReplyItem(reply)),
          ],

          // Reply button
          Padding(
            padding: EdgeInsets.only(top: ResponsiveUtils.getCardPadding(context) * 0.3),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  _showReplyDialog(review.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2079C2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getCardPadding(context) * 0.8,
                    vertical: ResponsiveUtils.getActionButtonHeight(context) * 0.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Reply',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getActionButtonFontSize(context) * 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommentReply reply) {
    return Container(
      key: ValueKey(reply.id),
      padding: EdgeInsets.all(ResponsiveUtils.getCardPadding(context) * 0.4),
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getCardPadding(context) * 0.2,
        left: ResponsiveUtils.getCardPadding(context) * 0.8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0.3,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business_center,
                size: ResponsiveUtils.getIconSize(context) * 0.25,
                color: Colors.grey[600],
              ),
              SizedBox(width: ResponsiveUtils.getGridSpacing(context) * 0.3),
              Text(
                'Business Response',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.75,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MM/dd').format(reply.date),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.65,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.3),
          Text(
            reply.reply,
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.8,
              color: Colors.grey[700],
              height: 1.4,
            ),
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
        title: Text(
          'Add a Review',
          style: TextStyle(
            fontSize: ResponsiveUtils.getTitleFontSize(context),
          ),
        ),
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
                    index < selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: ResponsiveUtils.getIconSize(context),
                  ),
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getGridSpacing(context)),
            // Comment text field
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: 'Your comment',
                labelStyle: TextStyle(
                  fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                ),
                border: const OutlineInputBorder(),
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getInputTextFontSize(context),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getButtonFontSize(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a comment')),
                );
                return;
              }

              Navigator.of(context).pop();
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Posting comment...')),
              // );

              try {
                await ApiService.createBranchComment(
                  widget.branchId,
                  commentController.text.trim(),
                  selectedRating,
                );

                _refreshReviews();

                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Comment posted successfully')),
                // );
              } catch (e) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Failed to post comment: $e')),
                // );
              }
            },
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: ResponsiveUtils.getButtonFontSize(context),
              ),
            ),
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
        title: Text(
          'Reply to Customer',
          style: TextStyle(
            fontSize: ResponsiveUtils.getTitleFontSize(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: replyController,
              decoration: InputDecoration(
                labelText: 'Your reply',
                labelStyle: TextStyle(
                  fontSize: ResponsiveUtils.getInputLabelFontSize(context),
                ),
                border: const OutlineInputBorder(),
                hintText: 'Thank you for your feedback...',
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getInputTextFontSize(context),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getButtonFontSize(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reply')),
                );
                return;
              }

              Navigator.of(context).pop();
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Posting reply...')),
              // );

              try {
                print('Posting reply to comment: $commentId');
                print('Reply text: ${replyController.text.trim()}');
                
                final response = await ApiService.replyToBranchComment(
                  commentId,
                  replyController.text.trim(),
                  token: widget.userData['token'],
                );
                
                print('Reply API response: $response');

                _refreshReviews();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reply posted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print('Error posting reply: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to post reply: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2079C2),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getCardPadding(context),
                vertical: ResponsiveUtils.getActionButtonHeight(context) * 0.25,
              ),
            ),
            child: Text(
              'Submit Reply',
              style: TextStyle(
                fontSize: ResponsiveUtils.getActionButtonFontSize(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}