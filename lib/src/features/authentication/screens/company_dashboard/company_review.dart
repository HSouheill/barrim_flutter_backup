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
    _fetchReviews();
    _scrollController.addListener(_scrollListener);
    _checkUserType();
    _loadCompanyData();
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
      
      body: Column(
        children: [
         CompanyAppHeader(
          logoUrl: widget.logoUrl,
          userData: widget.userData,
        ),
          SizedBox(height: 10),
          RefreshIndicator(
            onRefresh: _refreshReviews,
            child: _buildReviewsList(),
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
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getCardPadding(context)),
      padding: EdgeInsets.all(ResponsiveUtils.getCardPadding(context)),
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
                radius: ResponsiveUtils.getIconSize(context) * 0.5,
                backgroundImage: review.userImage.isNotEmpty
                    ? null
                    : const AssetImage('assets/default_avatar.png')
                as ImageProvider,
                backgroundColor: Colors.grey[300],
                child: review.userImage.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: review.userImage,
                          width: ResponsiveUtils.getIconSize(context),
                          height: ResponsiveUtils.getIconSize(context),
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.6),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.6),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.grey, size: ResponsiveUtils.getIconSize(context) * 0.6),
              ),
              SizedBox(width: ResponsiveUtils.getGridSpacing(context)),
              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getSubtitleFontSize(context),
                      ),
                    ),
                    Text(
                      DateFormat('MM/dd/yyyy').format(review.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: ResponsiveUtils.getInputTextFontSize(context),
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
                      size: ResponsiveUtils.getIconSize(context) * 0.5,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context)),
          // Review text
          Text(
            review.comment,
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputTextFontSize(context),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context)),

          // Display existing replies
          if (review.replies.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: EdgeInsets.only(bottom: ResponsiveUtils.getCardPadding(context) * 0.5),
              child: Text(
                'Replies from Business',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getSubtitleFontSize(context),
                ),
              ),
            ),
            ...review.replies.map((reply) => _buildReplyItem(reply)),
          ],

          // Reply button
          Padding(
            padding: EdgeInsets.only(top: ResponsiveUtils.getCardPadding(context) * 0.5),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showReplyDialog(review.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2079C2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getCardPadding(context),
                    vertical: ResponsiveUtils.getActionButtonHeight(context) * 0.25,
                  ),
                ),
                icon: Icon(Icons.reply, size: ResponsiveUtils.getIconSize(context) * 0.4),
                label: Text(
                  'Reply as Business',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getActionButtonFontSize(context),
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
      padding: EdgeInsets.all(ResponsiveUtils.getCardPadding(context) * 0.75),
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getCardPadding(context) * 0.5,
        left: ResponsiveUtils.getCardPadding(context) * 1.5,
      ),
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
              Icon(Icons.business, size: ResponsiveUtils.getIconSize(context) * 0.4, color: Colors.grey),
              SizedBox(width: ResponsiveUtils.getGridSpacing(context) * 0.5),
              Text(
                'Business Response',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getInputTextFontSize(context),
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MM/dd/yyyy').format(reply.date),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getInputTextFontSize(context) * 0.8,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getGridSpacing(context) * 0.5),
          Text(
            reply.reply,
            style: TextStyle(
              fontSize: ResponsiveUtils.getInputTextFontSize(context),
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
                await ApiService.replyToBranchComment(
                  commentId,
                  replyController.text.trim(),
                );

                _refreshReviews();

                // ScaffoldMessenger.of(context).showSnackBar(
                //   const SnackBar(content: Text('Reply posted successfully')),
                // );
              } catch (e) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Failed to post reply: $e')),
                // );
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