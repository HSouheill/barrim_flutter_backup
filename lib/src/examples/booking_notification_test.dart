import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/booking_service.dart';
import '../models/booking.dart';
import '../utils/auth_manager.dart';

/// Example widget to test booking notifications
class BookingNotificationTest extends StatefulWidget {
  const BookingNotificationTest({super.key});

  @override
  State<BookingNotificationTest> createState() => _BookingNotificationTestState();
}

class _BookingNotificationTestState extends State<BookingNotificationTest> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _serviceProviderIdController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _serviceTypeController = TextEditingController();
  bool _isEmergency = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default values for testing
    _serviceProviderIdController.text = 'test-provider-id';
    _customerNameController.text = 'John Doe';
    _serviceTypeController.text = 'Plumbing Service';
  }

  @override
  void dispose() {
    _serviceProviderIdController.dispose();
    _customerNameController.dispose();
    _serviceTypeController.dispose();
    super.dispose();
  }

  Future<void> _testBookingNotification() async {
    if (_serviceProviderIdController.text.isEmpty ||
        _customerNameController.text.isEmpty ||
        _serviceTypeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _notificationService.sendBookingNotification(
        serviceProviderId: _serviceProviderIdController.text,
        customerName: _customerNameController.text,
        serviceType: _serviceTypeController.text,
        bookingDate: 'Monday, Jan 15, 2024',
        timeSlot: '10:00 AM',
        bookingId: 'test-booking-123',
        isEmergency: _isEmergency,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent successfully! Check service provider device.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send test notification. Check console logs.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRealBooking() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthManager.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
        return;
      }

      final bookingService = BookingService(token: token);
      
      // Create a test booking
      final booking = Booking(
        userId: 'test-user-id',
        serviceProviderId: _serviceProviderIdController.text,
        bookingDate: DateTime.now().add(const Duration(days: 1)),
        timeSlot: '10:00 AM',
        phoneNumber: '+961123456789',
        details: 'Test booking for notification testing',
        isEmergency: _isEmergency,
      );

      final success = await bookingService.createBooking(booking);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test booking created and notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create test booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('Booking Notification Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Booking Notifications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Service Provider ID
            TextField(
              controller: _serviceProviderIdController,
              decoration: const InputDecoration(
                labelText: 'Service Provider ID',
                border: OutlineInputBorder(),
                hintText: 'Enter service provider ID',
              ),
            ),
            const SizedBox(height: 16),
            
            // Customer Name
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                hintText: 'Enter customer name',
              ),
            ),
            const SizedBox(height: 16),
            
            // Service Type
            TextField(
              controller: _serviceTypeController,
              decoration: const InputDecoration(
                labelText: 'Service Type',
                border: OutlineInputBorder(),
                hintText: 'Enter service type',
              ),
            ),
            const SizedBox(height: 16),
            
            // Emergency Checkbox
            CheckboxListTile(
              title: const Text('Emergency Booking'),
              value: _isEmergency,
              onChanged: (value) {
                setState(() {
                  _isEmergency = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testBookingNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Test Notification Only'),
              ),
            ),
            const SizedBox(height: 12),
            
            // Test Real Booking Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testRealBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Test Real Booking + Notification'),
              ),
            ),
            const SizedBox(height: 24),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Fill in the service provider ID (use a real one from your database)\n'
                    '2. Enter customer name and service type\n'
                    '3. Check "Emergency Booking" if testing emergency notifications\n'
                    '4. Click "Test Notification Only" to send just a notification\n'
                    '5. Click "Test Real Booking + Notification" to create a real booking (requires login)',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
