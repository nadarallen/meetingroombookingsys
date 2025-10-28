import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/database/models/booking.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // Initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    // Request permission for FCM
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    // Save token to Firestore if user is logged in
    await _saveTokenToFirestore(_fcmToken);

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });

    // Configure foreground notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Configure background message handler
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Handle notification taps
    _setupNotificationTapHandling();
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    try {
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;

      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        'Foreground notification received: ${message.notification?.title}');

    // Show local notification when app is in foreground
    final notification = message.notification;
    if (notification != null) {
      showNotification(
        notification.title ?? 'Notification',
        notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  void _setupNotificationTapHandling() {
    _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showSimple(String title, String body) async {
    await showNotification(title, body);
  }

  /// Schedule a notification for a specific date/time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled',
      channelDescription: 'Scheduled notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Send notification to all users
  Future<void> sendBroadcast({
    required String title,
    required String body,
    List<String>? userIds,
  }) async {
    // This would be implemented via Cloud Functions
    // For now, we'll simulate it
    debugPrint('Broadcast: $title - $body');

    if (userIds != null && userIds.isEmpty) {
      await showNotification(title, body);
    } else {
      await showNotification(title, body);
    }
  }

  /// Check and send reminder for upcoming bookings
  Future<void> checkAndSendReminders() async {
    final bookings = await _getUpcomingBookings();

    for (final booking in bookings) {
      final minutesUntilStart =
          booking.startTime.difference(DateTime.now()).inMinutes;

      // Send reminders at specific intervals
      if (minutesUntilStart == 30 && !booking.metadata['reminded_30min']) {
        await sendBookingReminder(booking, 30);
        booking.metadata['reminded_30min'] = true;
      } else if (minutesUntilStart == 15 &&
          !booking.metadata['reminded_15min']) {
        await sendBookingReminder(booking, 15);
        booking.metadata['reminded_15min'] = true;
      }
    }
  }

  Future<void> sendBookingReminder(Booking booking, int minutes) async {
    final title = 'Meeting in $minutes minutes';
    final body = 'Your booking for ${booking.roomId} starts soon';

    await showNotification(title, body);
  }

  Future<List<Booking>> _getUpcomingBookings() async {
    // Get bookings from local database
    // This is a simplified version
    return [];
  }

  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }
}

// Background message handler (must be top-level function)
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint(
      'Background notification received: ${message.notification?.title}');
}
