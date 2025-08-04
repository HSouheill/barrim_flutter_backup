import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_provider.dart';
import 'session_manager.dart';

/// Example widget showing how to use session management
class SessionManagementExample extends StatefulWidget {
  const SessionManagementExample({super.key});

  @override
  State<SessionManagementExample> createState() => _SessionManagementExampleState();
}

class _SessionManagementExampleState extends State<SessionManagementExample> {
  Map<String, dynamic>? _sessionStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionStatus();
    _listenToSessionEvents();
  }

  void _listenToSessionEvents() {
    SessionManager.sessionEvents.listen((event) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session event: $event'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _loadSessionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await SessionManager.getSessionStatus();
      setState(() {
        _sessionStatus = status;
      });
    } catch (e) {
      print('Error loading session status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSession() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await userProvider.refreshSession();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh session'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      await _loadSessionStatus();
    } catch (e) {
      print('Error refreshing session: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndHandleSession() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await userProvider.checkAndHandleSession();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session is valid'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session is invalid or expired'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      await _loadSessionStatus();
    } catch (e) {
      print('Error checking session: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSessionStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Session Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_sessionStatus != null) ...[
                            _buildStatusItem('Has Token', _sessionStatus!['hasToken']),
                            _buildStatusItem('Has User Data', _sessionStatus!['hasUserData']),
                            _buildStatusItem('Is Valid', _sessionStatus!['isValid']),
                            _buildStatusItem('Is Expiring Soon', _sessionStatus!['isExpiringSoon']),
                            _buildStatusItem('Time Until Expiry', '${_sessionStatus!['timeUntilExpiry']} minutes'),
                            _buildStatusItem('Session Timeout', '${_sessionStatus!['sessionTimeout']} minutes'),
                            _buildStatusItem('Warning Threshold', '${_sessionStatus!['warningThreshold']} minutes'),
                          ] else
                            const Text('No session status available'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _refreshSession,
                          child: const Text('Refresh Session'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _checkAndHandleSession,
                          child: const Text('Check Session'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // User Provider Info
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Provider Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildStatusItem('Is Logged In', userProvider.isLoggedIn),
                              _buildStatusItem('Has Token', userProvider.token != null),
                              _buildStatusItem('Has User', userProvider.user != null),
                              if (userProvider.user != null)
                                _buildStatusItem('User ID', userProvider.user!.id),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value?.toString() ?? 'null',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: value == true ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
} 