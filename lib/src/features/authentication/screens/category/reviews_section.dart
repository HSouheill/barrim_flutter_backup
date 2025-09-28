import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../services/api_service.dart';
import '../../../../models/branch_comment.dart'; // Import the BranchComment model
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
  List<BranchComment> _comments = []; // Changed to use BranchComment type
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _limit = 10;
  int _totalComments = 0;
  bool _hasMoreComments = true;
  TextEditingController _commentController = TextEditingController();
  int _userRating = 0;
  bool _isSubmitting = false;
  String? _profileImagePath;
  
  // Media support variables
  final ImagePicker _picker = ImagePicker();
  File? _selectedMediaFile;
  String? _selectedMediaType;
  bool _isPickingMedia = false;
  
  // Bad word detection variables
  bool _hasInappropriateContent = false;


  @override
  void initState() {
    super.initState();
    print('ReviewsSection: initState called');
    _fetchUserData();

    // Log the branch data for debugging
    print('ReviewsSection - Branch Data:');
    widget.branch.forEach((key, value) {
      print('$key: $value');
    });

    // Get branch ID from either _id or id field
    String branchId = _getBranchId();
    print('Using Branch ID: $branchId');

    print('ReviewsSection: About to call _loadComments');
    _loadComments();
    
    // Add listener for real-time bad word detection
    _commentController.addListener(_checkForBadWords);
  }

  // Helper method to get branch ID from multiple possible fields
  String _getBranchId() {
    // First try _id, then id, then fallback to empty string
    final branchId = widget.branch['_id']?.toString() ??
        widget.branch['id']?.toString() ??
        '';
    print('ReviewsSection: _getBranchId returning: $branchId');
    print('ReviewsSection: Available keys in branch: ${widget.branch.keys.toList()}');
    return branchId;
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await ApiService.getUserData();
      if (userData['profilePic'] != null) {
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
      });
      return;
    }

    final hasBadWords = BadWordFilter.containsBadWords(text);

    setState(() {
      _hasInappropriateContent = hasBadWords;
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_checkForBadWords);
    _commentController.dispose();
    super.dispose();
  }

  // Media picker methods
  Future<void> _pickImage() async {
    try {
      setState(() {
        _isPickingMedia = true;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        setState(() {
          _selectedMediaFile = File(image.path);
          _selectedMediaType = 'image';
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    } finally {
      setState(() {
        _isPickingMedia = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      setState(() {
        _isPickingMedia = true;
      });

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 2), // Limit to 2 minutes
      );

      if (video != null) {
        setState(() {
          _selectedMediaFile = File(video.path);
          _selectedMediaType = 'video';
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    } finally {
      setState(() {
        _isPickingMedia = false;
      });
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedMediaFile = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _comments = [];
        _hasMoreComments = true;
      });
    }

    if (!_hasMoreComments) return;

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

      // Debug logging
      print('ReviewsSection: API Response: $response');
      print('ReviewsSection: Status: ${response['status']}');
      print('ReviewsSection: Message: ${response['message']}');
      print('ReviewsSection: Data: ${response['data']}');

      if (response['status'] == 'success' && response['data'] != null) {
        final data = response['data'];
        final List<dynamic> comments = data['comments'] ?? [];
        final int total = data['total'] ?? 0;

        setState(() {
          List<BranchComment> newComments = [];

          // Convert each comment to a BranchComment object
          for (var comment in comments) {
            print('ReviewsSection: Processing comment: $comment');
            print('ReviewsSection: Comment type: ${comment.runtimeType}');
            
            if (comment is Map) {
              try {
                // Convert to BranchComment object directly
                final branchComment = BranchComment.fromJson(comment as Map<String, dynamic>);
                print('ReviewsSection: Successfully parsed comment: ${branchComment.userName} - ${branchComment.comment}');
                newComments.add(branchComment);
              } catch (e, stackTrace) {
                print('ReviewsSection: Error parsing comment: $e');
                print('ReviewsSection: Stack trace: $stackTrace');
                
                // Try alternative approach - convert to Map<String, dynamic> first
                try {
                  Map<String, dynamic> typedComment = Map<String, dynamic>.from(comment);
                  print('ReviewsSection: Trying with typed comment: $typedComment');
                  final branchComment = BranchComment.fromJson(typedComment);
                  print('ReviewsSection: Successfully parsed comment (second attempt): ${branchComment.userName} - ${branchComment.comment}');
                  newComments.add(branchComment);
                } catch (e2) {
                  print('ReviewsSection: Second attempt also failed: $e2');
                }
              }
            } else {
              print('ReviewsSection: Comment is not a Map, it is: ${comment.runtimeType}');
            }
          }

          if (refresh) {
            _comments = newComments;
          } else {
            // Add new comments to existing list
            _comments.addAll(newComments);
          }

          _totalComments = total;
          _hasMoreComments = _comments.length < _totalComments;
          _currentPage++;
          
          print('ReviewsSection: Final state - Comments count: ${_comments.length}, Total: $_totalComments, Has more: $_hasMoreComments');
        });
      } else {
        throw Exception('Failed to load comments: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      print('Error loading comments: $_errorMessage');
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

      // Use the branch comments API endpoint
      final response = await ApiService.createBranchComment(
        branchId,
        _commentController.text.trim(),
        _userRating,
      );

      if (response['status'] == 201 || response['status'] == 'success') {
        // Success - reset form and reload reviews
        setState(() {
          _commentController.clear();
          _userRating = 0;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Review submitted successfully')),
        // );

        // Refresh comments to include the new one
        await _loadComments(refresh: true);
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
    print('ReviewsSection: Building UI - Comments count: ${_comments.length}, Has error: $_hasError, Is loading: $_isLoading');
    
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

          

          // Only show comments if there are comments and no error
          if (!_hasError && _comments.isNotEmpty) ..._buildCommentsList(),

          // Show message if no comments and not loading
          if (!_hasError && _comments.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No comments yet. Be the first to leave a review!',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Loading indicator or load more button (only if there are comments)
          if (_isLoading && _comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasMoreComments && _comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _loadComments,
                child: Text('Load More Comments'),
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

          // Media selection section
          Row(
            children: [
              // Add image button
              GestureDetector(
                onTap: _isPickingMedia ? null : _pickImage,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, color: Colors.blue, size: 20),
                      SizedBox(width: 4),
                      Text('Add Image', style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Add video button
              GestureDetector(
                onTap: _isPickingMedia ? null : _pickVideo,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.red, size: 20),
                      SizedBox(width: 4),
                      Text('Add Video', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Spacer(),
              // Media preview and remove button
              if (_selectedMediaFile != null)
                Row(
                  children: [
                    if (_selectedMediaType == 'image')
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedMediaFile!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.videocam, color: Colors.red, size: 20),
                      ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removeMedia,
                      child: Icon(Icons.close, color: Colors.red, size: 20),
                    ),
                  ],
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

  List<Widget> _buildCommentsList() {
    print('ReviewsSection: _buildCommentsList called with ${_comments.length} comments');
    // Only build the list if there are comments
    if (_comments.isEmpty) {
      print('ReviewsSection: No comments to display');
      return [];
    }
    // Build the list of comment widgets
    print('ReviewsSection: Building ${_comments.length} comment widgets');
    return _comments.map<Widget>((comment) {
      print('ReviewsSection: Building comment widget for: ${comment.userName} - ${comment.comment}');
      return _buildCommentItem(comment);
    }).toList();
  }

  Widget _buildCommentItem(BranchComment comment) {
    try {
      print('ReviewsSection: _buildCommentItem called for comment: ${comment.userName} - ${comment.comment}');
      // Extract comment data from BranchComment object
      final String name = comment.userName;
      final String date = _formatDate(comment.createdAt);
      final double rating = comment.rating.toDouble();
      final String commentText = comment.comment;
      final String? profilePic = comment.userAvatar.isNotEmpty ? ApiService.getImageUrl(comment.userAvatar) : null;
      
      print('ReviewsSection: Comment data - Name: "$name" (length: ${name.length}), Date: $date, Rating: $rating, Text: "$commentText"');

      print('ReviewsSection: About to build Container widget');
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
                child: profilePic != null && profilePic.isNotEmpty
                    ? ClipOval(
                        child: SecureNetworkImage(
                          imageUrl: profilePic,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: Text(
                            (name.isNotEmpty && name.length > 0) ? name[0].toUpperCase() : 'A',
                            style: TextStyle(color: Colors.black54),
                          ),
                          errorWidget: (context, url, error) => Text(
                            (name.isNotEmpty && name.length > 0) ? name[0].toUpperCase() : 'A',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    : Text(
                        (name.isNotEmpty && name.length > 0) ? name[0].toUpperCase() : 'A',
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
              if (rating > 0) _buildRatingStars(rating),
            ],
          ),
          SizedBox(height: 8),
          Text(commentText),
        ],
      ),
    );
    } catch (e) {
      print('ReviewsSection: Error building comment item: $e');
      return Container(
        padding: EdgeInsets.all(16),
        child: Text('Error displaying comment: $e'),
      );
    }
  }



  Widget _buildRatingStars(double rating) {
    try {
      print('ReviewsSection: _buildRatingStars called with rating: $rating');
      // Round to nearest 0.5
      final roundedRating = (rating * 2).round() / 2;
      print('ReviewsSection: Rounded rating: $roundedRating');

      return Row(
        children: List.generate(5, (index) {
          print('ReviewsSection: Generating star $index');
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
    } catch (e) {
      print('ReviewsSection: Error in _buildRatingStars: $e');
      return Row(children: []);
    }
  }

  String _formatDate(DateTime date) {
    // Format the date - adjust as needed
    return '${date.day}/${date.month}/${date.year}';
  }
}