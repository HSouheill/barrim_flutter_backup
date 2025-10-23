// Temporarily disabled Firebase messaging
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
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
  List<File> _selectedMedia = [];
  List<String> _mediaTypes = []; // 'image' or 'video' for each file
  static const int _maxMediaFiles = 5;
  static const int _maxImageSizeInMB = 5;
  static const int _maxVideoSizeInMB = 50;
  static const int _maxVideoDurationInMinutes = 2;
  bool _isMediaUploading = false;

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
      // Temporarily disabled Firebase messaging
      // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //   print("Received message: ${message.notification?.title}");
      //   if (message.data['type'] == 'booking_status_update') {
      //     final status = message.data['status'];
      //     final bookingId = message.data['booking'];

      //     // Show status update to user
      //     // ScaffoldMessenger.of(context).showSnackBar(
      //     //   SnackBar(
      //     //     content: Text(message.notification?.body ?? 'Booking status updated'),
      //     //     backgroundColor: _getStatusColor(status),
      //     //   ),
      //     // );
      //   }
      // });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to book a service')),
        );
      }
    } catch (e) {
      print("Error initializing booking service: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing booking service: $e')),
      );
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

      print("=== LOADING TIME SLOTS ===");
      print("Loading time slots for provider: ${widget.serviceProvider.id}");
      print("Selected date: $_selectedDate");
      print("Provider available hours: ${widget.serviceProvider.serviceProviderInfo?.availableHours}");
      print("Provider available days: ${widget.serviceProvider.serviceProviderInfo?.availableDays}");
      print("Provider available days length: ${widget.serviceProvider.serviceProviderInfo?.availableDays?.length}");

      final slots = await _bookingService!.getAvailableTimeSlots(
        widget.serviceProvider.id,
        _selectedDate,
      );

      print("Received time slots from API: $slots");

      // If no slots returned from API or API returns incomplete slots, generate them locally based on provider availability
      List<String> finalSlots = slots;
      if (slots.isEmpty) {
        print("No slots from API, generating locally...");
        finalSlots = _generateLocalTimeSlots();
        print("Generated local time slots: $finalSlots");
      } else {
        // Check if API returned complete time slots (should be 8 slots for 9 AM to 5 PM)
        final expectedSlots = _generateLocalTimeSlots();
        if (slots.length < expectedSlots.length) {
          print("API returned incomplete slots (${slots.length}), expected ${expectedSlots.length}, generating locally...");
          finalSlots = expectedSlots;
          print("Generated local time slots: $finalSlots");
        } else {
          print("Using API time slots: $finalSlots");
        }
      }

      setState(() {
        _availableTimeSlots = finalSlots;
        _selectedTimeSlot = null;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading time slots: $e");
      
      // Even if API fails, try to generate slots locally
      print("API failed, generating local time slots as fallback...");
      final localSlots = _generateLocalTimeSlots();
      print("Generated fallback time slots: $localSlots");
      
      setState(() {
        _isLoading = false;
        _availableTimeSlots = localSlots;
        _selectedTimeSlot = null;
      });
    }
  }

  // Generate time slots locally based on provider's available hours
  List<String> _generateLocalTimeSlots() {
    // Check if date is in the past
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final isPastDate = _selectedDate.isBefore(currentDate);
    
    // If the date is in the past, don't generate time slots
    if (isPastDate) {
      print("Selected date is in the past - no time slots generated");
      return [];
    }
    
    // Get available days and hours
    final availableDays = widget.serviceProvider.serviceProviderInfo?.availableDays ?? [];
    final availableHours = widget.serviceProvider.serviceProviderInfo?.availableHours;
    
    print("=== BOOKING SECTION DEBUG ===");
    print("Provider availableDays length: ${availableDays.length}");
    print("Provider availability hours: $availableHours");
    print("Selected date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}");
    
    // If we have available days, check if the selected date is available
    if (availableDays.isNotEmpty) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final selectedWeekday = DateFormat('EEEE').format(_selectedDate);
      
      // Check if the selected date is available (prioritize specific dates over weekdays)
      final isDateAvailable = availableDays.contains(selectedDateStr);
      final isWeekdayAvailable = availableDays.contains(selectedWeekday);
      
      // If we have specific dates, only use those. Otherwise, use weekdays.
      final hasSpecificDates = availableDays.any((day) => day.contains('-'));
      final isAvailable = hasSpecificDates ? isDateAvailable : isWeekdayAvailable;
      
      print("isDateAvailable: $isDateAvailable");
      print("isWeekdayAvailable: $isWeekdayAvailable");
      print("hasSpecificDates: $hasSpecificDates");
      print("isAvailable: $isAvailable");
      
      // For now, let's be more permissive - if we have 366 days (full year), assume all future dates are available
      if (availableDays.length >= 365 && !isPastDate) {
        print("Provider has full year availability - allowing all future dates");
      } else if (!isAvailable) {
        print("Selected date $selectedDateStr is not available - no time slots generated");
        return []; // Return empty list if date is not available
      }
    }
    
    // If no available days are set, assume all days are available (legacy behavior)
    if (availableDays.isEmpty) {
      print("No available days set - assuming all days are available");
    }
    if (availableHours == null || availableHours.isEmpty) {
      print("No available hours found, using default 9 AM to 5 PM");
      return _generateTimeSlotsFromRange('09:00', '17:00');
    }

    if (availableHours.length >= 2) {
      final startTime = availableHours[0];
      final endTime = availableHours[1];
      print("Generating slots from $startTime to $endTime");
      final slots = _generateTimeSlotsFromRange(startTime, endTime);
      print("Generated ${slots.length} time slots for date ${DateFormat('yyyy-MM-dd').format(_selectedDate)}: $slots");
      return slots;
    }

    // Fallback to default hours
    print("Using fallback hours 09:00 to 17:00");
    final slots = _generateTimeSlotsFromRange('09:00', '17:00');
    print("Generated ${slots.length} fallback time slots for date ${DateFormat('yyyy-MM-dd').format(_selectedDate)}: $slots");
    return slots;
  }

  // Format time slot to 12-hour format with AM/PM
  String _formatTimeSlot(int hour, int minute) {
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Generate time slots in 1-hour intervals from start to end time
  List<String> _generateTimeSlotsFromRange(String startTime, String endTime) {
    List<String> slots = [];
    
    try {
      // Parse start and end times
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      if (startParts.length != 2 || endParts.length != 2) {
        print("Invalid time format, using default slots");
        return ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00'];
      }
      
      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);
      int endHour = int.parse(endParts[0]);
      int endMinute = int.parse(endParts[1]);
      
      // Convert to minutes for easier calculation
      int startMinutes = startHour * 60 + startMinute;
      int endMinutes = endHour * 60 + endMinute;
      
      // Generate slots every hour
      for (int minutes = startMinutes; minutes < endMinutes; minutes += 60) {
        int hour = minutes ~/ 60;
        int minute = minutes % 60;
        String timeSlot = _formatTimeSlot(hour, minute);
        slots.add(timeSlot);
      }
      
      print("Generated ${slots.length} time slots: $slots");
      return slots;
    } catch (e) {
      print("Error generating time slots: $e");
      // Return default slots if parsing fails
      return ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00'];
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
    print("User selected date: ${DateFormat('yyyy-MM-dd').format(date)} (${DateFormat('EEEE, MMM d, yyyy').format(date)})");
    setState(() {
      _selectedDate = date;
      _selectedTimeSlot = null;
    });
    _loadAvailableTimeSlots();
  }

  void _selectTimeSlot(String timeSlot) {
    print("User selected time slot: $timeSlot");
    print("Full booking selection - Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)} (${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)}), Time: $timeSlot");
    setState(() {
      _selectedTimeSlot = timeSlot;
    });
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    try {
      setState(() {
        _isMediaUploading = true;
      });

      if (_selectedMedia.length >= _maxMediaFiles) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('You can only upload up to $_maxMediaFiles files.')),
        // );
        return;
      }

      final List<XFile> mediaFiles = [];
      if (type == 'image' && source == ImageSource.gallery) {
        final images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (images != null) mediaFiles.addAll(images);
      } else {
        final XFile? media = type == 'image'
            ? await _picker.pickImage(
                source: source,
                maxWidth: 1920,
                maxHeight: 1080,
                imageQuality: 85,
              )
            : await _picker.pickVideo(
                source: source,
                maxDuration: const Duration(minutes: _maxVideoDurationInMinutes),
              );
        if (media != null) mediaFiles.add(media);
      }

      for (final media in mediaFiles) {
        if (_selectedMedia.length >= _maxMediaFiles) break;
        final file = File(media.path);
        final fileSizeInBytes = await file.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (type == 'image' && fileSizeInMB > _maxImageSizeInMB) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Image size must be less than $_maxImageSizeInMB MB')),
          // );
          continue;
        } else if (type == 'video' && fileSizeInMB > _maxVideoSizeInMB) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Video size must be less than $_maxVideoSizeInMB MB')),
          // );
          continue;
        }
        setState(() {
          _selectedMedia.add(file);
          _mediaTypes.add(type);
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
                  'Add Media (max $_maxMediaFiles)',
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
                title: const Text('Choose Photos'),
                subtitle: Text('Select multiple, Max size: $_maxImageSizeInMB MB each'),
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
              if (_selectedMedia.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove All Media', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMedia.clear();
                      _mediaTypes.clear();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to book a service')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    try {
      print('=== STARTING BOOKING PROCESS ===');
      setState(() {
        _isBookingInProgress = true;
      });

      final userId = await AuthManager.getUserId();
      print('User ID: $userId');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Log the booking details
      print("=== BOOKING DETAILS ===");
      print("Provider ID: ${widget.serviceProvider.id}");
      print("User ID: $userId");
      print("Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)} (${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)})");
      print("Selected Time: $_selectedTimeSlot");
      print("Phone: $_countryCode${_phoneController.text}");
      print("Details: ${_detailsController.text}");
      print("Is Emergency: $_isEmergency");
      print("=======================");

      final booking = Booking(
        userId: userId,
        serviceProviderId: widget.serviceProvider.id,
        bookingDate: _selectedDate,
        timeSlot: _selectedTimeSlot!,
        phoneNumber: '$_countryCode${_phoneController.text}',
        details: _detailsController.text,
        isEmergency: _isEmergency,
      );

      // TODO: Update backend and BookingService to support multiple media files
      // For now, send only the first media if any
      String? mediaBase64;
      String? mediaFileName;
      String? mediaType;
      if (_selectedMedia.isNotEmpty) {
        final bytes = await _selectedMedia[0].readAsBytes();
        mediaBase64 = base64Encode(bytes);
        mediaFileName = _selectedMedia[0].path.split('/').last;
        mediaType = _mediaTypes[0];
      }

      print('=== CALLING BOOKING SERVICE ===');
      final success = await _bookingService!.createBooking(
        booking,
        mediaBase64: mediaBase64,
        mediaFileName: mediaFileName,
        mediaType: mediaType,
      );
      print('Booking service result: $success');

      if (success) {
        print('=== BOOKING SUCCESSFUL ===');
        // Store the selected time slot before clearing the form
        final selectedTimeSlot = _selectedTimeSlot;
        final selectedDate = _selectedDate;
        
        // Reset form
        _phoneController.clear();
        _detailsController.clear();
        setState(() {
          _selectedTimeSlot = null;
          _isEmergency = false;
          _selectedMedia.clear();
          _mediaTypes.clear();
        });

        await _loadAvailableTimeSlots();

        // Show success popup with the stored values
        _showBookingSuccessDialog(selectedDate, selectedTimeSlot);
      }
    } catch (e) {
      print('Booking error: $e');
      String errorMsg = e.toString();
      if (errorMsg.contains('not available') || errorMsg.contains('unavailable') || errorMsg.contains('Provider is not available')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The service provider is not available at this time. Please choose another time slot.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: $e')),
        );
      }
    } finally {
      setState(() {
        _isBookingInProgress = false;
      });
    }
  }

  void _showBookingSuccessDialog(DateTime selectedDate, String? selectedTimeSlot) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xFF0094FF),
                  Color(0xFF05055A),
                  Color(0xFF0094FF),
                ],
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Booking Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your appointment has been booked for ${DateFormat('EEEE, MMM d, yyyy').format(selectedDate)} at ${selectedTimeSlot ?? 'selected time'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The service provider has been notified',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF05055A),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

                // Media preview (multiple)
                if (_selectedMedia.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedMedia.length,
                            itemBuilder: (context, index) {
                              final file = _selectedMedia[index];
                              final type = _mediaTypes[index];
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: type == 'image'
                                          ? Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            )
                                          : GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => Dialog(
                                                    insetPadding: const EdgeInsets.all(16),
                                                    child: AspectRatio(
                                                      aspectRatio: 16 / 9,
                                                      child: _VideoPlayerDialog(file: file),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                color: Colors.black,
                                                child: Center(
                                                  child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedMedia.removeAt(index);
                                          _mediaTypes.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_selectedMedia.length < _maxMediaFiles)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: IconButton(
                              icon: Icon(Icons.add_photo_alternate, color: Colors.blue),
                              onPressed: _isMediaUploading ? null : _showMediaPickerModal,
                              tooltip: 'Add more media',
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
                  child: Row(
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
                      if (_selectedMedia.isEmpty)
                        IconButton(
                          icon: Icon(Icons.add_photo_alternate, color: Colors.blue),
                          onPressed: _isMediaUploading ? null : _showMediaPickerModal,
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
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final weekdayName = DateFormat('EEEE').format(date);
      
      // Check if specific date is available (prioritize specific dates over weekdays)
      final isDateAvailable = widget.serviceProvider.serviceProviderInfo?.availableDays
          ?.contains(dateStr) ??
          false;
      
      // Check if weekday is available (fallback if no specific dates)
      final isWeekdayAvailable = widget.serviceProvider.serviceProviderInfo?.availableDays
          ?.contains(weekdayName) ??
          false;

      // If we have specific dates, only use those. Otherwise, use weekdays.
      final hasSpecificDates = widget.serviceProvider.serviceProviderInfo?.availableDays
          ?.any((day) => day.contains('-')) ?? false;
      
      final isAvailable = isPastDate ? false : (hasSpecificDates ? isDateAvailable : isWeekdayAvailable);
      final isUnavailable = !isAvailable;
      
      // Debug logging for calendar
      if (day <= 5) { // Only log first few days to avoid spam
        print("Calendar - Date: $dateStr, isDateAvailable: $isDateAvailable, isWeekdayAvailable: $isWeekdayAvailable, hasSpecificDates: $hasSpecificDates, isAvailable: $isAvailable, isUnavailable: $isUnavailable");
      }

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

class _VideoPlayerDialog extends StatefulWidget {
  final File file;
  const _VideoPlayerDialog({Key? key, required this.file}) : super(key: key);

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              VideoProgressIndicator(_controller, allowScrubbing: true),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}