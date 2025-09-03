import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../models/branch_review.dart'; // Import the BranchReview model
import '../../../../components/secure_network_image.dart';
import '../../../../utils/bad_word_filter.dart';

class ReviewsSection extends StatefulWidget {
  final Map<String, dynamic> branch;

  const ReviewsSection({Key? key, required this.branch}) : super(key: key);

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  String _filterBy = 'Rating';
  List<BranchReview> _reviews = []; // Changed to use BranchReview type
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _limit = 10;
  int _totalReviews = 0;
  bool _hasMoreReviews = true;
  TextEditingController _commentController = TextEditingController();
  int _userRating = 0;
  bool _isSubmitting = false;
  String? _profileImagePath;
  
  // Bad word detection variables
  bool _hasInappropriateContent = false;
  List<dynamic> _detectedBadWords = [];


  @override
  void initState() {
    super.initState();
    _fetchUserData();

    // Log the branch data for debugging
    print('ReviewsSection - Branch Data:');
    widget.branch.forEach((key, value) {
      print('$key: $value');
    });

    // Get branch ID from either _id or id field
    String branchId = _getBranchId();
    print('Using Branch ID: $branchId');

    _loadReviews();
    
    // Add listener for real-time bad word detection
    _commentController.addListener(_checkForBadWords);
  }

  // Helper method to get branch ID from multiple possible fields
  String _getBranchId() {
    // First try _id, then id, then fallback to empty string
    return widget.branch['_id']?.toString() ??
        widget.branch['id']?.toString() ??
        '';
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData != null && userData['profilePic'] != null) {
        setState(() {
          _profileImagePath = ApiService.getImageUrl(userData['profilePic']);
          print('Profile Image Path: $_profileImagePath');
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Check for bad words in real-time
  void _checkForBadWords() {
    final text = _commentController.text;
    if (text.isEmpty) {
      setState(() {
        _hasInappropriateContent = false;
        _detectedBadWords = [];
      });
      return;
    }

    final hasBadWords = BadWordFilter.containsBadWords(text);
    final badWords = hasBadWords ? BadWordFilter.getBadWordsFound(text) : [];

    setState(() {
      _hasInappropriateContent = hasBadWords;
      _detectedBadWords = badWords;
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_checkForBadWords);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _reviews = [];
        _hasMoreReviews = true;
      });
    }

    if (!_hasMoreReviews) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      String branchId = _getBranchId();
      if (branchId.isEmpty) {
        throw Exception('Branch ID is missing');
      }

      final response = await ApiService.getBranchComments(
        branchId,
        page: _currentPage,
        limit: _limit,
      );

      if (response['status'] == 200 && response['data'] != null) {
        final data = response['data'];
        final List<dynamic> comments = data['comments'] ?? [];
        final int total = data['total'] ?? 0;

        setState(() {
          List<BranchReview> newReviews = [];

          // Convert each comment to a BranchReview object
          for (var comment in comments) {
            if (comment is Map) {
              // Make sure we have a Map<String, dynamic>
              Map<String, dynamic> typedComment = Map<String, dynamic>.from(comment);
              // Convert to BranchReview object
              newReviews.add(BranchReview.fromJson(typedComment));
            }
          }

          if (refresh) {
            _reviews = newReviews;
          } else {
            // Add new reviews to existing list
            _reviews.addAll(newReviews);
          }

          _totalReviews = total;
          _hasMoreReviews = _reviews.length < _totalReviews;
          _currentPage++;
        });
      } else {
        throw Exception('Failed to load reviews: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      print('Error loading reviews: $_errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    // Check for inappropriate content
    final commentText = _commentController.text.trim();
    if (BadWordFilter.containsBadWords(commentText)) {
      final badWords = BadWordFilter.getBadWordsFound(commentText);
      final shouldContinue = await BadWordFilter.showBadWordWarningDialog(context, badWords);
      
      if (!shouldContinue) {
        return; // User chose to cancel
      }
      
      // User acknowledged but we still prevent submission
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please remove inappropriate language from your review before submitting.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });

      String branchId = _getBranchId();
      if (branchId.isEmpty) {
        throw Exception('Branch ID is missing');
      }

      final response = await ApiService.createBranchComment(
        branchId,
        _commentController.text.trim(),
        _userRating,
      );

      if (response['status'] == 201) {
        // Success - reset form and reload reviews
        setState(() {
          _commentController.clear();
          _userRating = 0;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Review submitted successfully')),
        // );

        // Refresh reviews to include the new one
        await _loadReviews(refresh: true);
      } else {
        throw Exception('Failed to submit review: ${response['message']}');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(e.toString())),
      // );
      print('Error submitting review: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _filterBy,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Add Review form
          _buildAddReviewForm(),

          // Only show reviews if there are reviews and no error
          if (!_hasError && _reviews.isNotEmpty) ..._buildReviewsList(),

          // Loading indicator or load more button (only if there are reviews)
          if (_isLoading && _reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasMoreReviews && _reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _loadReviews,
                child: Text('Load More Reviews'),
              ),
            ),

          // Add padding at the bottom
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAddReviewForm() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _profileImagePath != null && _profileImagePath!.isNotEmpty
                    ? null
                    : null,
                onBackgroundImageError: _profileImagePath != null && _profileImagePath!.isNotEmpty
                    ? (exception, stackTrace) {
                        print('Error loading profile image: $exception');
                        print('Failed profile image path: $_profileImagePath');
                      }
                    : null,
                child: _profileImagePath != null && _profileImagePath!.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: _profileImagePath!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Icon(Icons.person, color: Colors.white),
                          errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white),
              ),
              SizedBox(width: 6),
              Text(
                'Add Review',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Spacer(),
              // Rating selection
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _userRating ? Icons.star : Icons.star_border,
                      color: index < _userRating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _userRating = index + 1;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Comment text field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write your review here...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              // Bad word warning indicator
              if (_hasInappropriateContent)
                Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Inappropriate content detected',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),

          // Submit button
          Center(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: _isSubmitting
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReviewsList() {
    // Only build the list if there are reviews
    if (_reviews.isEmpty) {
      return [];
    }
    // Build the list of review widgets
    return _reviews.map<Widget>((review) {
      return _buildReviewItem(review);
    }).toList();
  }

  Widget _buildReviewItem(BranchReview review) {
    // Extract review data from BranchReview object
    final String name = review.userName;
    final String date = _formatDate(review.date);
    final double rating = review.rating.toDouble();
    final String comment = review.comment;
    final String? profilePic = review.userImage != null ? ApiService.getImageUrl(review.userImage) : null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage: profilePic != null && profilePic.isNotEmpty
                    ? null
                    : null,
                onBackgroundImageError: profilePic != null && profilePic.isNotEmpty
                    ? (exception, stackTrace) {
                        print('Error loading profile image: $exception');
                        print('Failed profile image path: $profilePic');
                      }
                    : null,
                child: profilePic != null && profilePic.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: profilePic,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(color: Colors.black54),
                          ),
                          errorWidget: (context, url, error) => Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: TextStyle(color: Colors.black54),
                      ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Spacer(),
              _buildRatingStars(rating),
            ],
          ),
          SizedBox(height: 8),
          Text(comment),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    // Round to nearest 0.5
    final roundedRating = (rating * 2).round() / 2;

    return Row(
      children: List.generate(5, (index) {
        if (index < roundedRating.floor()) {
          // Full star
          return Icon(Icons.star, color: Colors.blue, size: 16);
        } else if (index < roundedRating.ceil() && roundedRating.floor() != roundedRating.ceil()) {
          // Half star
          return Icon(Icons.star_half, color: Colors.blue, size: 16);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.blue, size: 16);
        }
      }),
    );
  }

  String _formatDate(DateTime date) {
    // Format the date - adjust as needed
    return '${date.day}/${date.month}/${date.year}';
  }
}