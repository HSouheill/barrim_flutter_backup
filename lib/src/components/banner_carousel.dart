import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BannerCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final Duration autoPlayInterval;
  final bool autoPlay;

  const BannerCarousel({
    super.key,
    required this.imageUrls,
    this.height = 180,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.autoPlay = true,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.autoPlay && widget.imageUrls.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(widget.autoPlayInterval, () {
      if (mounted && widget.imageUrls.isNotEmpty) {
        final nextPage = (_currentPage + 1) % widget.imageUrls.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                if (widget.autoPlay) {
                  _startAutoPlay();
                }
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Handle banner tap - navigate to advertisement page
                    _handleBannerTap(index);
                  },
                  child: _buildBannerItem(widget.imageUrls[index]),
                );
              },
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imageUrls.length,
                    (index) => _buildPageIndicator(index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerItem(String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Try to load image from network or asset
        _buildImageWidget(imageUrl),
        // Gradient overlay for better text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    try {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        // Network image
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
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
        );
      } else {
        // Asset image
        return Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              'Advertisement',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _handleBannerTap(int index) {
    // Show snackbar or navigate to advertisement details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Advertisement ${index + 1} tapped'),
        duration: const Duration(seconds: 2),
      ),
    );
    // You can navigate to a dedicated advertisement page here
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => AdvertisementDetailsPage(adIndex: index),
    //   ),
    // );
  }
}

// Example usage with default advertisements
class BannerCarouselDemo extends StatelessWidget {
  final List<String> defaultAds = [
    'assets/images/subscription.png',
    'assets/images/6months_subscription.png',
    'assets/images/monthly_subscription.png',
  ];

  BannerCarouselDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return BannerCarousel(
      imageUrls: defaultAds,
      height: 180,
    );
  }
}
