// lib/src/components/optimized_loading_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_loading_manager.dart';

/// Optimized loading widget that shows progress and handles different loading states
class OptimizedLoadingWidget extends StatelessWidget {
  final List<String> dataTypes;
  final Widget child;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final bool showProgress;
  final String? customMessage;

  const OptimizedLoadingWidget({
    Key? key,
    required this.dataTypes,
    required this.child,
    this.loadingWidget,
    this.errorWidget,
    this.showProgress = true,
    this.customMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DataLoadingManager>(
      builder: (context, dataManager, _) {
        // Check if any data is loading
        final isLoading = dataTypes.any((type) => dataManager.isLoading(type));
        final hasError = dataTypes.any((type) => dataManager.getError(type) != null);
        final allLoaded = dataManager.areAllLoaded(dataTypes);
        
        // Show loading state
        if (isLoading && !allLoaded) {
          return loadingWidget ?? _buildDefaultLoadingWidget(dataManager);
        }
        
        // Show error state
        if (hasError && !allLoaded) {
          return errorWidget ?? _buildDefaultErrorWidget(dataManager);
        }
        
        // Show content
        return child;
      },
    );
  }

  Widget _buildDefaultLoadingWidget(DataLoadingManager dataManager) {
    final progress = dataManager.getLoadingProgress(dataTypes);
    final loadingTypes = dataTypes.where((type) => dataManager.isLoading(type)).toList();
    
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated progress indicator
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue, // Use a default color instead of context
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Loading message
            Text(
              customMessage ?? 'Loading data...',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Loading details
            if (loadingTypes.isNotEmpty)
              Text(
                'Loading: ${loadingTypes.join(', ')}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 16),
            
            // Online status indicator
            if (!dataManager.isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Offline mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget(DataLoadingManager dataManager) {
    final errorTypes = dataTypes.where((type) => dataManager.getError(type) != null).toList();
    final firstError = errorTypes.isNotEmpty ? dataManager.getError(errorTypes.first) : 'Unknown error';
    
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              
              const SizedBox(height: 16),
              
              // Error message
              Text(
                'Failed to load data',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Error details
              Text(
                firstError ?? 'Unknown error occurred',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Retry button
              ElevatedButton.icon(
                onPressed: () {
                  // Clear errors and retry
                  for (final type in errorTypes) {
                    dataManager.clearCachedData(type);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Use a default color instead of context
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Offline indicator
              if (!dataManager.isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'No internet connection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading effect for better UX
class ShimmerLoadingWidget extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoadingWidget({
    Key? key,
    required this.child,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<ShimmerLoadingWidget> createState() => _ShimmerLoadingWidgetState();
}

class _ShimmerLoadingWidgetState extends State<ShimmerLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _animationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.grey,
                Colors.white,
                Colors.grey,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
