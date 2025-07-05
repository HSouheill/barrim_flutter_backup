import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../../../../models/booking.dart';
import '../../../../../models/service_provider.dart';
import '../../../../../services/booking_service.dart';
import '../../../../../services/notification_provider.dart';
import '../../../../../utils/auth_manager.dart';

class BookingSection extends StatefulWidget {
  final ServiceProvider serviceProvider;

  const BookingSection({
    Key? key,
    required this.serviceProvider,
  }) : super(key: key);

  @override
  _BookingSectionState createState() => _BookingSectionState();
}

class _BookingSectionState extends State<BookingSection> {
  // State variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  final _phoneController = TextEditingController();
  final _detailsController = TextEditingController();
  bool _isEmergency = false;
  bool _isLoading = false;
  bool _isBookingInProgress = false;
  List<String> _availableTimeSlots = [];
  String _countryCode = '+961'; // Default country code

  // Select a month to display
  DateTime _displayedMonth = DateTime.now();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Booking service
  BookingService? _bookingService;

  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  bool _isMediaUploading = false;
  String? _mediaType; // 'image' or 'video'

  // Constants for media validation
  static const int _maxImageSizeInMB = 5;
  static const int _maxVideoSizeInMB = 50;
  static const int _maxVideoDurationInMinutes = 2;

  @override
  void initState() {
    super.initState();
    _initializeBookingService();
    _setupNotificationListener();
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    // Listen for notifications
    notificationProvider.addListener(() {
      final notifications = notificationProvider.notifications;
      if (notifications.isNotEmpty) {
        final latest = notifications.last;
        if (latest['type'] == 'booking_update') {
          // Show a dialog or update UI based on booking status
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Booking Update'),
              content: Text(latest['message']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });

  }



  void _setupNotificationListener() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Received message: ${message.notification?.title}");
        if (message.data['type'] == 'booking_status_update') {
          final status = message.data['status'];
          final bookingId = message.data['booking'];

          // Show status update to user
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(message.notification?.body ?? 'Booking status updated'),
          //     backgroundColor: _getStatusColor(status),
          //   ),
          // );
        }
      });
    } catch (e) {
      print("Error setting up notification listener: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _initializeBookingService() async {
    try {
      final token = await AuthManager.getToken();

      if (token != null) {
        setState(() {
          _bookingService = BookingService(token: token);
        });

        // Load available time slots after initializing service
        await _loadAvailableTimeSlots();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Please log in to book a service')),
        // );
      }
    } catch (e) {
      print("Error initializing booking service: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error initializing booking service: $e')),
      // );
    }
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (_bookingService == null) {
      print("Booking service not initialized");
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final slots = await _bookingService!.getAvailableTimeSlots(
        widget.serviceProvider.id,
        _selectedDate,
      );

      setState(() {
        _availableTimeSlots = slots;
        _selectedTimeSlot = null;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading time slots: $e");
      setState(() {
        _isLoading = false;
        _availableTimeSlots = [];
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to load available time slots: $e')),
      // );
    }
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTimeSlot = null;
    });
    _loadAvailableTimeSlots();
  }

  void _selectTimeSlot(String timeSlot) {
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    try {
      setState(() {
        _isMediaUploading = true;
      });

      final XFile? media;
      if (type == 'image') {
        media = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } else {
        media = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: _maxVideoDurationInMinutes),
        );
      }

      if (media != null) {
        // Validate file size
        final file = File(media.path);
        final fileSizeInBytes = await file.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (type == 'image' && fileSizeInMB > _maxImageSizeInMB) {
          throw Exception('Image size must be less than $_maxImageSizeInMB MB');
        } else if (type == 'video' && fileSizeInMB > _maxVideoSizeInMB) {
          throw Exception('Video size must be less than $_maxVideoSizeInMB MB');
        }

        setState(() {
          _selectedMedia = file;
          _mediaType = type;
        });
      }
    } catch (e) {
      String errorMessage = 'Error picking media: ';
      if (e.toString().contains('size')) {
        errorMessage = e.toString();
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Please grant camera and storage permissions to upload media';
      } else {
        errorMessage += e.toString();
      }
      
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(errorMessage),
      //     backgroundColor: Colors.red,
      //     duration: const Duration(seconds: 5),
      //     action: SnackBarAction(
      //       label: 'Dismiss',
      //       textColor: Colors.white,
      //       onPressed: () {
      //         ScaffoldMessenger.of(context).hideCurrentSnackBar();
      //       },
      //     ),
      //   ),
      // );
    } finally {
      setState(() {
        _isMediaUploading = false;
      });
    }
  }

  void _showMediaPickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Add Media',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                subtitle: Text('Max size: $_maxImageSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose Photo'),
                subtitle: Text('Max size: $_maxImageSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                subtitle: Text('Max duration: $_maxVideoDurationInMinutes min, Max size: $_maxVideoSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, 'video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Video'),
                subtitle: Text('Max duration: $_maxVideoDurationInMinutes min, Max size: $_maxVideoSizeInMB MB'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, 'video');
                },
              ),
              if (_selectedMedia != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Media', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMedia = null;
                      _mediaType = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookAppointment() async {
    if (_bookingService == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Please log in to book a service')),
      // );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTimeSlot == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Please select a time slot')),
      // );
      return;
    }

    try {
      setState(() {
        _isBookingInProgress = true;
      });

      final userId = await AuthManager.getUserId();

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Convert media to base64 if exists
      String? mediaBase64;
      String? mediaFileName;
      if (_selectedMedia != null) {
        final bytes = await _selectedMedia!.readAsBytes();
        mediaBase64 = base64Encode(bytes);
        mediaFileName = _selectedMedia!.path.split('/').last;
      }

      final booking = Booking(
        userId: userId,
        serviceProviderId: widget.serviceProvider.id,
        bookingDate: _selectedDate,
        timeSlot: _selectedTimeSlot!,
        phoneNumber: '$_countryCode${_phoneController.text}',
        details: _detailsController.text,
        isEmergency: _isEmergency,
        mediaType: _mediaType,
        // Note: mediaUrl will be set by the backend after upload
      );

      final success = await _bookingService!.createBooking(
        booking,
        mediaBase64: mediaBase64,
        mediaFileName: mediaFileName,
      );

      if (success) {
        // Reset form
        _phoneController.clear();
        _detailsController.clear();
        setState(() {
          _selectedTimeSlot = null;
          _isEmergency = false;
          _selectedMedia = null;
          _mediaType = null;
        });

        await _loadAvailableTimeSlots();

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Appointment booked successfully!')),
        // );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('not available') || errorMsg.contains('unavailable') || errorMsg.contains('Provider is not available')) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('The service provider is not available at this time. Please choose another time slot.'),
        //     backgroundColor: Colors.orange,
        //   ),
        // );
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to book appointment: $e')),
        // );
      }
    } finally {
      setState(() {
        _isBookingInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booking Header with dividers
          Row(
            children: [
              Expanded(child: Divider(color: Colors.blue[200])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                child: Text(
                  'Booking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.blue[200])),
            ],
          ),
          const SizedBox(height: 4),

          // Calendar Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar month navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_displayedMonth),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            onPressed: _previousMonth,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            onPressed: _nextMonth,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calendar header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDayHeader('Mo'),
                    _buildDayHeader('Tu'),
                    _buildDayHeader('We'),
                    _buildDayHeader('Th'),
                    _buildDayHeader('Fr'),
                    _buildDayHeader('Sa'),
                    _buildDayHeader('Su'),
                  ],
                ),
                const SizedBox(height: 12),

                // Calendar grid
                _buildCalendarGrid(),
                const SizedBox(height: 20),

                // Selected date display
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Selected date: ${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Time section
                Text(
                  'Available Time Slots',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Time slots
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _availableTimeSlots.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No available time slots for this date',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
                    : Container(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableTimeSlots.length,
                    itemBuilder: (context, index) {
                      final timeSlot = _availableTimeSlots[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildTimeSlot(
                          timeSlot,
                          _selectedTimeSlot == timeSlot,
                          false,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Phone number section
                Text(
                  'Your Phone Number',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Phone input with country code
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(_countryCode),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (!RegExp(r'^\d{7,10}$').hasMatch(value)) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Details section with media upload
                Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Media preview
                if (_selectedMedia != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _mediaType == 'image'
                              ? Image.file(
                                  _selectedMedia!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Container(
                                  color: Colors.black,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_circle_outline,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        right: 8,
                                        child: Text(
                                          'Video selected',
                                          style: TextStyle(
                                            color: Colors.white,
                                            backgroundColor: Colors.black54,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedMedia = null;
                                  _mediaType = null;
                                });
                              },
                            ),
                          ),
                        ),
                        if (_isMediaUploading)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 8),
                                  Text(
                                    'Processing media...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Details input with media upload button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _detailsController,
                              decoration: const InputDecoration(
                                hintText: 'Add details about your appointment',
                                border: InputBorder.none,
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter booking details';
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _selectedMedia != null ? Icons.edit : Icons.add_photo_alternate,
                              color: Colors.blue,
                            ),
                            onPressed: _isMediaUploading ? null : _showMediaPickerModal,
                          ),
                        ],
                      ),
                      if (_isMediaUploading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        // onPressed: _isBookingInProgress ? null : _bookAppointment,
                        onPressed: _isBookingInProgress
                            ? null
                            : () {
                          setState(() {
                            _isEmergency = false;
                          });
                          _bookAppointment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isBookingInProgress
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Book Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isBookingInProgress
                            ? null
                            : () {
                          setState(() {
                            _isEmergency = true;
                          });
                          _bookAppointment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isBookingInProgress
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Emergency',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(String day) {
    return SizedBox(
      width: 30,
      child: Text(
        day,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);

    // Calculate the offset for the first day of the month (0 = Monday, 6 = Sunday)
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);

    // Create list of days
    List<Widget> dayWidgets = [];

    // Add empty slots for days before the first day of the month
    for (int i = 0; i < firstWeekday - 1; i++) {
      dayWidgets.add(_buildCalendarDay('', false, false, false));
    }

    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final isToday = date.year == currentDate.year &&
          date.month == currentDate.month &&
          date.day == currentDate.day;

      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;

      // Check if date is in the past
      final isPastDate = date.isBefore(currentDate);

      // Check if service provider is available on this day
      final weekdayName = DateFormat('EEEE').format(date);
      final isWeekdayAvailable = widget.serviceProvider.serviceProviderInfo?.availableDays
          ?.contains(weekdayName) ??
          false;

      // Check if specific date is available
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isDateAvailable = widget.serviceProvider.serviceProviderInfo?.availableDays
          ?.contains(dateStr) ??
          false;

      final isUnavailable = isPastDate || (!isWeekdayAvailable && !isDateAvailable);

      dayWidgets.add(
        GestureDetector(
          onTap: isUnavailable ? null : () => _selectDate(date),
          child: _buildCalendarDay(
            day.toString(),
            isSelected,
            isUnavailable,
            isToday,
          ),
        ),
      );
    }

    // Add empty slots for days after the last day of the month
    final remainingDays = 7 - ((firstWeekday - 1 + daysInMonth) % 7);
    if (remainingDays < 7) {
      for (int i = 0; i < remainingDays; i++) {
        dayWidgets.add(_buildCalendarDay('', false, false, false));
      }
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarDay(String day, bool isSelected, bool isUnavailable, bool isToday) {
    Color backgroundColor = Colors.transparent;
    Color textColor = Colors.black;

    if (isSelected) {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    } else if (isUnavailable) {
      backgroundColor = day.isEmpty ? Colors.grey.shade100 : Colors.red.shade100;
      textColor = day.isEmpty ? Colors.transparent : Colors.grey;
    } else if (day.isEmpty) {
      backgroundColor = Colors.grey.shade100;
    } else if (isToday) {
      backgroundColor = Colors.blue.shade100;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        day,
        style: TextStyle(
          color: day.isEmpty ? Colors.transparent : textColor,
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String time, bool isSelected, bool isUnavailable) {
    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    } else if (isUnavailable) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.grey;
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.black;
    }

    return GestureDetector(
      onTap: isUnavailable ? null : () => _selectTimeSlot(time),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}