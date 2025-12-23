import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class NotificationService {
  /// Create a notification when appointment status changes
  static Future<void> createAppointmentNotification({
    required String userId,
    required String appointmentId,
    required String status, // 'approved' or 'rejected'
    required String counselorName,
    required String date,
    required String time,
  }) async {
    try {
      final message = status == 'approved'
          ? 'Your appointment with $counselorName on $date at $time has been approved!'
          : 'Your appointment with $counselorName on $date at $time has been rejected.';

      await supabase.from('notifications').insert({
        'user_id': userId,
        'type': 'appointment_status',
        'title': status == 'approved' ? 'Appointment Approved' : 'Appointment Rejected',
        'message': message,
        'appointment_id': appointmentId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  /// Get unread notification count for current user
  static Future<int> getUnreadCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for current user
  static Future<void> markAllAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Get all notifications for current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }
}

