import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lib/src/utils/edge_to_edge_helper.dart';

/// Test script to verify edge-to-edge implementation
/// Run this as a standalone Flutter app to test edge-to-edge functionality
void main() {
  runApp(EdgeToEdgeTestApp());
}

class EdgeToEdgeTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge-to-Edge Test',
      theme: ThemeData.light(),
      builder: (context, child) {
        // Configure edge-to-edge support
        EdgeToEdgeHelper.configureSystemUIOverlayForLightTheme();
        return child!;
      },
      home: EdgeToEdgeTestScreen(),
    );
  }
}

class EdgeToEdgeTestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPadding = EdgeToEdgeHelper.getTopPadding(context);
    final bottomPadding = EdgeToEdgeHelper.getBottomPadding(context);
    final contentPadding = EdgeToEdgeHelper.getContentPadding(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Background that extends edge-to-edge
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade300,
                    Colors.purple.shade300,
                  ],
                ),
              ),
            ),
          ),
          
          // Content with proper inset handling
          Column(
            children: [
              // Status bar spacer
              SizedBox(height: topPadding),
              
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                child: Text(
                  'Edge-to-Edge Test',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Test information
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard('Top Padding', '${topPadding.toStringAsFixed(1)}px'),
                      SizedBox(height: 16),
                      _buildInfoCard('Bottom Padding', '${bottomPadding.toStringAsFixed(1)}px'),
                      SizedBox(height: 16),
                      _buildInfoCard('Content Padding', '${contentPadding.toString()}'),
                      SizedBox(height: 16),
                      _buildInfoCard('Screen Size', '${MediaQuery.of(context).size.width.toStringAsFixed(1)} x ${MediaQuery.of(context).size.height.toStringAsFixed(1)}'),
                      SizedBox(height: 16),
                      _buildInfoCard('Platform', '${Theme.of(context).platform}'),
                    ],
                  ),
                ),
              ),
              
              // Bottom section with SafeArea
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This content respects the navigation bar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Test system UI overlay change
                            EdgeToEdgeHelper.configureSystemUIOverlayForDarkTheme();
                          },
                          child: Text('Test Dark Theme'),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Test system UI overlay change
                            EdgeToEdgeHelper.configureSystemUIOverlayForLightTheme();
                          },
                          child: Text('Test Light Theme'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
