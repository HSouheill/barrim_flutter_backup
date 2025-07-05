import 'package:barrim/src/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:barrim/src/components/secure_network_image.dart';

class ProfileHeader extends StatefulWidget {
  final Map<String, dynamic> providerData;
  final Function() onBackPressed;

  const ProfileHeader({
    Key? key,
    required this.providerData,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool isFavorite = false;
  bool isLoading = true;
  final ApiService _apiService = ApiService();


  @override
  void initState() {
    super.initState();
    print('Provider data: ${widget.providerData}'); // Debug what data we have
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    // First check if we have a valid ID
    if (widget.providerData['id'] == null) {
      setState(() {
        isLoading = false;
      });
      print('Warning: Provider ID is missing in provider data');
      return;
    }

    try {
      final result = await _apiService.isServiceProviderFavorited(widget.providerData['id']);
      setState(() {
        isFavorite = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error checking favorite status: $e');
    }
  }




  Future<void> _toggleFavorite() async {
    if (widget.providerData['id'] == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Provider ID is missing'),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final success = await _apiService.toggleFavoriteStatus(
          widget.providerData['id'].toString(),
          isFavorite
      );

      if (success) {
        setState(() {
          isFavorite = !isFavorite;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isFavorite
                    ? 'Added to favorites'
                    : 'Removed from favorites'
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          isLoading = false;
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Failed to update favorites'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error toggling favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-width background image
        SizedBox(
          width: double.infinity,
          height: 200,
          child: _buildProfileImage(
            widget.providerData['profilePic'] ??
            widget.providerData['logoPath'] ??
            null,
          ),
        ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBackPressed,
            ),
          ),
        ),

        // Action buttons
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),

        // Name and verification
        Positioned(
          bottom: 48,
          left: 16,
          child: Row(
            children: [
              Text(
                widget.providerData['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),

        // Years of experience
        Positioned(
          bottom: 24,
          left: 16,
          child: Text(
            '${_getYearsExperience(widget.providerData['position'] ?? "0")} Years of Experience',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4.0,
                  color: Colors.black,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
          ),
        ),

        // Rating stars
        Positioned(
          bottom: 24,
          right: 16,
          child: Row(
            children: List.generate(5, (index) {
              return Icon(
                index < (widget.providerData['rating'] ?? 0) ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }),
          ),
        ),
      ],
    );
  }

  int _getYearsExperience(String position) {
    final RegExp regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(position);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  Widget _buildProfileImage(dynamic imagePath) {
    if (imagePath == null || (imagePath is String && imagePath.isEmpty)) {
      // Return a default asset or a transparent image
      return Image.asset('assets/logo/barrim_logo1.png', fit: BoxFit.cover);
    }
    if (imagePath is String && (imagePath.startsWith('http://') || imagePath.startsWith('https://'))) {
      return SecureNetworkImage(
        imageUrl: imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: Center(child: Icon(Icons.person, size: 60)),
        ),
      );
    }
    if (imagePath is String) {
      return Image.asset(imagePath, fit: BoxFit.cover);
    }
    // Fallback to default asset if not a string
    return Image.asset('assets/logo/barrim_logo1.png', fit: BoxFit.cover);
  }
}