import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedLocationMarker extends StatefulWidget {
  final double size;
  final Color color;
  final bool isLive;

  const AnimatedLocationMarker({
    Key? key,
    this.size = 40.0, 
    this.color = Colors.blue,
    this.isLive = true,
  }) : super(key: key);

  @override
  State<AnimatedLocationMarker> createState() => _AnimatedLocationMarkerState();
}

class _AnimatedLocationMarkerState extends State<AnimatedLocationMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the outer ring
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Reduced from 1500 to 1200
      vsync: this,
    );
    
    // Bounce animation for the main icon
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced from 1000 to 800
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.9, // Reduced from 0.8 to 0.9
      end: 1.1, // Reduced from 1.2 to 1.1
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    if (widget.isLive) {
      _pulseController.repeat();
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring - smaller and more subtle
          if (widget.isLive)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.3), // Reduced from 0.5 to 0.3
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.2 * (1.0 - _pulseAnimation.value)), // Reduced opacity
                    ),
                  ),
                );
              },
            ),
          
          // Middle pulsing ring - smaller
          if (widget.isLive)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value * 0.2), // Reduced from 0.3 to 0.2
                  child: Container(
                    width: widget.size * 0.6, // Reduced from 0.7 to 0.6
                    height: widget.size * 0.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.3 * (1.0 - _pulseAnimation.value)), // Reduced opacity
                    ),
                  ),
                );
              },
            ),
          
          // Main location icon with bounce animation - smaller
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isLive ? _bounceAnimation.value : 1.0,
                child: Container(
                  width: widget.size * 0.4, // Reduced from 0.5 to 0.4
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.3), // Reduced opacity
                        blurRadius: 4, // Reduced from 8 to 4
                        spreadRadius: 1, // Reduced from 2 to 1
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: widget.size * 0.2, // Reduced from 0.25 to 0.2
                  ),
                ),
              );
            },
          ),
          
          // Live indicator dot - smaller
          if (widget.isLive)
            Positioned(
              top: widget.size * 0.05, // Reduced from 0.1 to 0.05
              right: widget.size * 0.05, // Reduced from 0.1 to 0.05
              child: Container(
                width: widget.size * 0.12, // Reduced from 0.15 to 0.12
                height: widget.size * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  border: Border.all(
                    color: Colors.white,
                    width: 1, // Reduced from 2 to 1
                  ),
                ),
                child: Center(
                  child: Container(
                    width: widget.size * 0.06, // Reduced from 0.08 to 0.06
                    height: widget.size * 0.06,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 