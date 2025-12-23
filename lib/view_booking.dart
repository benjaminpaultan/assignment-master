import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking.dart';
import 'edit.dart';
import 'appointment.dart';
import 'history.dart';
import 'notifications/notification_service.dart';

final supabase = Supabase.instance.client;

class ViewBooking extends StatefulWidget {
  final VoidCallback? onNotificationsRead;

  const ViewBooking({super.key, this.onNotificationsRead});

  @override
  State<ViewBooking> createState() => _ViewBookingState();
}

class _ViewBookingState extends State<ViewBooking> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _showNotifications = false;
  Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await NotificationService.getNotifications();
    final unreadNotifications = notifications.where((n) => n['is_read'] == false).toList();
    final unreadCount = unreadNotifications.length;
    final previousUnreadCount = _notifications.where((n) => n['is_read'] == false).length;
    
    // Find truly NEW notifications (ones we haven't shown before)
    final newNotifications = unreadNotifications.where((n) {
      final id = n['id'].toString();
      return !_shownNotificationIds.contains(id);
    }).toList();

    setState(() {
      _notifications = notifications;
      _showNotifications = unreadCount > 0;
      // Mark new notifications as shown
      for (var notif in newNotifications) {
        _shownNotificationIds.add(notif['id'].toString());
      }
    });

    // Only show snackbar for truly NEW notifications (not ones we've already shown)
    if (newNotifications.isNotEmpty && mounted) {
      final newCount = newNotifications.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have $newCount new notification${newCount > 1 ? 's' : ''}'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              _showNotificationsDialog();
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _markNotificationsAsRead() async {
    await NotificationService.markAllAsRead();
    // Clear shown notifications since they're now read
    _shownNotificationIds.clear();
    await _loadNotifications();
    if (widget.onNotificationsRead != null) {
      widget.onNotificationsRead!();
    }
    // Dismiss any active snackbars
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  Future<void> _fetchAppointments() async {

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to view appointments')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('appointment')
          .select('id, status, date, time, conselor_id(name)')
          .eq('user_id', user.id)
          .inFilter('status', ['pending', 'approved'])
          .order('date');

      final List<Appointment> appointments = (response as List<dynamic>)
          .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
          .where((appt) {
        final apptDate = DateTime.parse(appt.date);
        return apptDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
      })
          .toList();

      if (mounted) {
        setState(() => _appointments = appointments);
      }
    } catch (e) {
      print('Error fetching appointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch appointments: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editAppointment(Appointment appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBookingPage(appointment: appointment),
      ),
    ).then((value) {
      if (value == true) {
        _fetchAppointments();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: [
          if (unreadCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    _showNotificationsDialog();
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            const Text(
              'Upcoming Appointments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _appointments.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No upcoming appointments',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _appointments.length,
                itemBuilder: (context, index) {
                  final appt = _appointments[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                appt.counselorName ?? 'Unknown Counselor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: appt.status?.toLowerCase() == 'pending'
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (appt.status ?? 'Unknown').toUpperCase(),
                                  style: TextStyle(
                                    color: appt.status?.toLowerCase() == 'pending'
                                        ? Colors.orange.shade800
                                        : Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(appt.date, style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 8),
                                  Text(appt.time, style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => _editAppointment(appt),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Fixed: Wrap buttons in Flexible/Expanded to prevent overflow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BookingPage()),
                        );
                        if (result == true) {
                          _fetchAppointments();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('Booking'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HistoryPage()),
                        ).then((_) => _fetchAppointments());
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('History'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: _notifications.isEmpty
              ? const Text('No notifications')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['is_read'] == true;
                    return ListTile(
                      leading: Icon(
                        notif['type'] == 'appointment_status'
                            ? Icons.event
                            : Icons.notifications,
                        color: isRead ? Colors.grey : Colors.deepPurple,
                      ),
                      title: Text(
                        notif['title'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(notif['message'] ?? ''),
                      trailing: isRead
                          ? null
                          : const Icon(Icons.circle, size: 8, color: Colors.red),
                      onTap: () async {
                        if (!isRead) {
                          await NotificationService.markAsRead(notif['id'].toString());
                          // Remove from shown set since it's now read
                          _shownNotificationIds.remove(notif['id'].toString());
                          await _loadNotifications();
                          if (widget.onNotificationsRead != null) {
                            widget.onNotificationsRead!();
                          }
                          // Dismiss snackbar when notification is read
                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                          }
                        }
                        Navigator.pop(context);
                        _fetchAppointments(); // Refresh appointments
                      },
                    );
                  },
                ),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: () async {
                await _markNotificationsAsRead();
                Navigator.pop(context);
              },
              child: const Text('Mark all as read'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

