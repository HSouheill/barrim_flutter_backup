import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/booking.dart';
import '../../../../services/booking_service.dart';
import '../../../../services/serviceprovider_controller.dart';
import '../../../../utils/token_manager.dart';
import '../../headers/service_provider_header.dart';

class SPMyBookingsPage extends StatefulWidget {
  const SPMyBookingsPage({Key? key}) : super(key: key);

  @override
  State<SPMyBookingsPage> createState() => _SPMyBookingsPageState();
}

class _SPMyBookingsPageState extends State<SPMyBookingsPage> {
  final TokenManager _tokenManager = TokenManager();
  final ServiceProviderController _serviceProviderController = ServiceProviderController();
  BookingService? _bookingService;

  // Initialize with a default Future that returns an empty list
  Future<List<Booking>> _bookingsFuture = Future.value([]);
  bool _isLoading = true;
  String? _error;

  // Track bookings being updated to show individual loading indicators
  Set<String> _updatingBookings = {};


  static const String STATUS_PENDING = 'pending';
  static const String STATUS_ACCEPTED = 'accepted';
  static const String STATUS_REJECTED = 'rejected';
  static const String STATUS_CONFIRMED = 'confirmed';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';

  @override
  void initState() {
    super.initState();
    _initializeBookingService();
    _setupNotificationListener();
    _fetchServiceProviderData();
  }

  void _setupNotificationListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'new_booking') {
        // Refresh bookings when new booking arrives
        _loadBookings();

        // Show local notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification?.title ?? 'New booking'),
          ),
        );
      }
    });
  }

  Future<void> _initializeBookingService() async {
    try {
      final token = await _tokenManager.getToken();
      if (token.isEmpty) {
        setState(() {
          _error = "Authentication token not found. Please login again.";
          _isLoading = false;
        });
        return;
      }

      _bookingService = BookingService(token: token);
      _loadBookings();
    } catch (e) {
      setState(() {
        _error = "Failed to initialize: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookings() async {
    // Don't proceed if booking service isn't initialized
    if (_bookingService == null) {
      print('SPMyBookingsPage: Booking service is null, cannot load bookings');
      return;
    }

    print('SPMyBookingsPage: Starting to load bookings...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      setState(() {
        _bookingsFuture = _bookingService!.getProviderBookings();
      });
      final bookings = await _bookingsFuture; // Wait to catch any errors
      print('SPMyBookingsPage: Loaded ${bookings.length} bookings');
      for (var booking in bookings) {
        print('SPMyBookingsPage: Booking - ID: ${booking.id}, Status: ${booking.status}, Date: ${booking.bookingDate}');
      }
    } catch (e) {
      print('SPMyBookingsPage: Error loading bookings: $e');
      setState(() {
        _error = "Failed to load bookings: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchServiceProviderData() async {
    await _serviceProviderController.initialize();
  }

  // In _SPMyBookingsPageState class, update this method:

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    if (_bookingService == null) return;

    // Add to updating set to show loading indicator
    setState(() {
      _updatingBookings.add(bookingId);
    });

    try {
      // Map the internal status constants to what the API accepts
      String apiStatus;

      // For responding to pending bookings
      if (status == STATUS_CONFIRMED) {
        apiStatus = STATUS_ACCEPTED; // Map "confirmed" to "accepted" for the API
      } else if (status == STATUS_REJECTED) {
        apiStatus = STATUS_REJECTED; // Keep "rejected" as is
      } else {
        // For other status updates like marking as completed
        apiStatus = status;
      }

      // Call the appropriate method based on the status type
      if (apiStatus == STATUS_ACCEPTED || apiStatus == STATUS_REJECTED) {
        // Use respondToBooking for accept/reject operations
        await _bookingService!.respondToBooking(bookingId, apiStatus);
      } else {
        // Use updateBookingStatus for other operations like completing a booking
        await _bookingService!.updateBookingStatus(bookingId, apiStatus);
      }

      // Reload bookings after status update
      await _loadBookings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${_getStatusActionText(status)} successfully'),
            backgroundColor: _getStatusColor(status),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to update booking: $e'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
    } finally {
      // Remove from updating set
      if (mounted) {
        setState(() {
          _updatingBookings.remove(bookingId);
        });
      }
    }
  }

  String _getStatusActionText(String status) {
    switch (status.toLowerCase()) {
      case STATUS_ACCEPTED:
        return 'accepted';
      case STATUS_REJECTED:
        return 'rejected';
      case STATUS_CONFIRMED:
        return 'confirmed';
      case STATUS_CANCELLED:
        return 'cancelled';
      case STATUS_COMPLETED:
        return 'marked as completed';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd').format(date);
  }

  Widget _buildMediaGallery(Booking booking) {
    // Debug: Print booking media information
    print('Booking ${booking.id}: mediaUrls=${booking.mediaUrls.length}, mediaTypes=${booking.mediaTypes.length}');
    if (booking.mediaUrls.isNotEmpty) {
      print('Media URLs: ${booking.mediaUrls}');
      print('Media Types: ${booking.mediaTypes}');
    }

    if (booking.mediaUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media (${booking.mediaUrls.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: booking.mediaUrls.length,
              itemBuilder: (context, index) {
                final mediaUrl = booking.mediaUrls[index];
                final mediaType = index < booking.mediaTypes.length 
                    ? booking.mediaTypes[index] 
                    : 'image';
                final thumbnailUrl = index < booking.thumbnailUrls.length 
                    ? booking.thumbnailUrls[index] 
                    : null;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: GestureDetector(
                    onTap: () => _showMediaFullScreen(booking, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          if (mediaType == 'image')
                            CachedNetworkImage(
                              imageUrl: mediaUrl,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error, color: Colors.grey),
                              ),
                            )
                          else
                            Container(
                              color: Colors.black,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (thumbnailUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: thumbnailUrl,
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.error, color: Colors.grey),
                                      ),
                                    ),
                                  const Icon(
                                    Icons.play_circle_outline,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                mediaType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaFullScreen(Booking booking, int initialIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: booking.mediaUrls.length,
                  controller: PageController(initialPage: initialIndex),
                  itemBuilder: (context, index) {
                    final mediaUrl = booking.mediaUrls[index];
                    final mediaType = index < booking.mediaTypes.length 
                        ? booking.mediaTypes[index] 
                        : 'image';
                    final thumbnailUrl = index < booking.thumbnailUrls.length 
                        ? booking.thumbnailUrls[index] 
                        : null;

                    return Center(
                      child: mediaType == 'image'
                          ? CachedNetworkImage(
                              imageUrl: mediaUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.error, color: Colors.white, size: 50),
                              ),
                            )
                          : Container(
                              color: Colors.black,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (thumbnailUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: thumbnailUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  const Icon(
                                    Icons.play_circle_outline,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                  Positioned(
                                    bottom: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Video - Tap to play',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
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
    if (_error != null) {
      return _buildErrorScreen();
    }

    return ChangeNotifierProvider.value(
      value: _serviceProviderController,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Consumer<ServiceProviderController>(
              builder: (context, controller, _) {
                return ServiceProviderHeader(
                  serviceProvider: controller.serviceProvider,
                  isLoading: controller.isLoading,
                  onLogoNavigation: () {
                    // Navigate back to the previous screen
                    Navigator.of(context).pop();
                  },
                );
              },
            ),

            // Page Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const Divider(),

            // Bookings List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBookings,
                child: _isLoading ?
                const Center(child: CircularProgressIndicator()) :
                FutureBuilder<List<Booking>>(
                  future: _bookingsFuture,
                  builder: (context, snapshot) {
                    print('SPMyBookingsPage: FutureBuilder - ConnectionState: ${snapshot.connectionState}');
                    print('SPMyBookingsPage: FutureBuilder - HasData: ${snapshot.hasData}');
                    print('SPMyBookingsPage: FutureBuilder - HasError: ${snapshot.hasError}');
                    if (snapshot.hasError) {
                      print('SPMyBookingsPage: FutureBuilder - Error: ${snapshot.error}');
                    }
                    if (snapshot.hasData) {
                      print('SPMyBookingsPage: FutureBuilder - Data length: ${snapshot.data!.length}');
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadBookings,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      print('SPMyBookingsPage: FutureBuilder - No bookings found');
                      return const Center(
                        child: Text('No bookings found'),
                      );
                    }

                    final bookings = snapshot.data!;

                    // Sort bookings by status and date
                    bookings.sort((a, b) {
                      // First sort by status priority
                      final statusPriority = {
                        STATUS_PENDING: 0,
                        STATUS_CONFIRMED: 1,
                        STATUS_COMPLETED: 2,
                        STATUS_CANCELLED: 3,
                      };

                      final priorityA = statusPriority[a.status
                          .toLowerCase()] ?? 4;
                      final priorityB = statusPriority[b.status
                          .toLowerCase()] ?? 4;

                      if (priorityA != priorityB) {
                        return priorityA.compareTo(priorityB);
                      }

                      // Then sort by date (newest first)
                      return b.bookingDate.compareTo(a.bookingDate);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        final isEmergency = booking.isEmergency;
                        final isUpdating = _updatingBookings.contains(
                            booking.id);
                        final bookingStatus = booking.status.toLowerCase();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: bookingStatus == STATUS_PENDING
                                ? const BorderSide(
                                color: Colors.orange, width: 1)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Avatar
                                Builder(
                                  builder: (context) {
                                    print('SPMyBookingsPage: Profile pic URL: ${booking.userProfilePic}');
                                    return CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey.shade300,
                                      child: booking.userProfilePic?.isNotEmpty == true
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: booking.userProfilePic!,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) {
                                                  print('SPMyBookingsPage: Loading profile image: $url');
                                                  return const Icon(
                                                    Icons.person, 
                                                    color: Colors.white,
                                                    size: 20,
                                                  );
                                                },
                                                errorWidget: (context, url, error) {
                                                  print('SPMyBookingsPage: Error loading profile image: $url, Error: $error');
                                                  return const Icon(
                                                    Icons.person, 
                                                    color: Colors.white,
                                                    size: 20,
                                                  );
                                                },
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person, 
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),

                                // Booking Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(
                                            booking.userFullName?.isNotEmpty == true
                                                ? booking.userFullName!
                                                : booking.userId.length > 5
                                                    ? 'User #${booking.userId.substring(0, 5)}'
                                                    : 'User #${booking.userId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(booking.bookingDate),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),
                                      Text(
                                        '${DateFormat('MMMM d, yyyy').format(
                                            booking.bookingDate)} • ${booking
                                            .timeSlot} • ${booking
                                            .phoneNumber}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),

                                      const SizedBox(height: 4),
                                      Text(
                                        booking.details,
                                        style: const TextStyle(fontSize: 14),
                                      ),

                                      // Display media gallery
                                      _buildMediaGallery(booking),

                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          if (isEmergency)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius
                                                    .circular(4),
                                              ),
                                              child: Text(
                                                'Emergency',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),

                                          const Spacer(),

                                          // Action buttons
                                          if (isUpdating)
                                          // Show loading indicator when updating
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else
                                            if (bookingStatus == STATUS_PENDING)
                                              Row(
                                                children: [
                                                  // Deny Button
                                                  InkWell(
                                                    onTap: () =>
                                                        _showCancelConfirmation(
                                                            booking.id!),
                                                    child: CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: Colors
                                                          .red.shade100,
                                                      child: Icon(
                                                          Icons.close, size: 16,
                                                          color: Colors.red
                                                              .shade700),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Accept Button
                                                  InkWell(
                                                    onTap: () =>
                                                        _updateBookingStatus(
                                                            booking.id!,
                                                            STATUS_CONFIRMED),
                                                    child: CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: Colors
                                                          .green.shade100,
                                                      child: Icon(
                                                          Icons.check, size: 16,
                                                          color: Colors.green
                                                              .shade700),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              if (bookingStatus ==
                                                  STATUS_CONFIRMED)
                                              // Add Complete button for confirmed bookings
                                                InkWell(
                                                  onTap: () =>
                                                      _updateBookingStatus(
                                                          booking.id!,
                                                          STATUS_COMPLETED),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .shade50,
                                                      borderRadius: BorderRadius
                                                          .circular(4),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize
                                                          .min,
                                                      children: [
                                                        Icon(Icons
                                                            .check_circle_outline,
                                                            size: 14,
                                                            color: Colors.blue
                                                                .shade700),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          'Complete',
                                                          style: TextStyle(
                                                            color: Colors.blue
                                                                .shade700,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight
                                                                .w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                        booking.status),
                                                    borderRadius: BorderRadius
                                                        .circular(4),
                                                  ),
                                                  child: Text(
                                                    booking.status
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight
                                                          .w500,
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show confirmation dialog before cancelling a booking
  // Show confirmation dialog before cancelling a booking
  Future<void> _showCancelConfirmation(String bookingId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reject Booking?'),
          content: const SingleChildScrollView(
            child: Text('Are you sure you want to reject this booking? This action cannot be undone.'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _updateBookingStatus(bookingId, STATUS_REJECTED);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeBookingService,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case STATUS_ACCEPTED:
      case STATUS_CONFIRMED:
        return Colors.blue;
      case STATUS_COMPLETED:
        return Colors.green;
      case STATUS_REJECTED:
      case STATUS_CANCELLED:
        return Colors.red;
      case STATUS_PENDING:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}