import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


class NotificationDiagnosticInfo {
  final bool areNotificationsEnabled;
  final bool canScheduleExactAlarms;
  final int activeRemindersCount;
  final DateTime? nextExpectedNotification;
  final DateTime? lastReconciledAt;
  final String? lastError;

  NotificationDiagnosticInfo({
    required this.areNotificationsEnabled,
    required this.canScheduleExactAlarms,
    required this.activeRemindersCount,
    this.nextExpectedNotification,
    this.lastReconciledAt,
    this.lastError,
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String expiryChannelId = 'bismillahstore_expiry_v4';
  static const String backupChannelId = 'bismillahstore_backup_v4';

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize timezones with modern offset matching
    tz.initializeTimeZones();
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      tz.Location? matched;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.timeZone(now.millisecondsSinceEpoch).offset == offsetMs) {
          matched = loc;
          break;
        }
      }
      if (matched != null) {
        tz.setLocalLocation(matched);
      } else if (offsetMs == 18000000) {
        // Fallback for Pakistan Standard Time (PKT, UTC+5)
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } else {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    // 2. Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Notification payload routing if needed
      },
    );

    // 3. Create high-importance notification channels
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          expiryChannelId,
          'BismillahStore Expiry Alerts',
          description: 'Audible high-priority alerts for expiring and expired medicines',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          backupChannelId,
          'BismillahStore Backup Reminders',
          description: 'Periodic reminders to export and secure store records',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (!Platform.isAndroid) return true;

    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final notifGranted = await androidImplementation.requestNotificationsPermission();
      try {
        await androidImplementation.requestExactAlarmsPermission();
      } catch (_) {}
      return notifGranted ?? false;
    }
    return true;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return false;
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      try {
        final canExact = await androidImplementation.canScheduleExactNotifications();
        return canExact ?? true;
      } catch (_) {
        return true;
      }
    }
    return false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled();
      return enabled ?? true;
    }
    return true;
  }

  /// Fires an instant sound notification to verify system audio and alerts
  Future<void> testSoundNotification() async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'BismillahStore Expiry Alerts',
      channelDescription: 'Timely notifications for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      7777,
      '🔔 BismillahStore Notification Test',
      'System sound and vibration alert is working properly with full audio!',
      notificationDetails,
      payload: 'test_alert',
    );
  }

  /// Fires an instant status bar notification summarizing expiring or expired medicines
  Future<void> showExpirySummaryNotification({
    required int expiredCount,
    required int expiringCount,
  }) async {
    await initialize();

    String title;
    String body;
    if (expiredCount > 0 && expiringCount > 0) {
      title = '🚨 Expiry Alert: $expiredCount Expired, $expiringCount Expiring Soon';
      body = 'Immediate review required. Open BismillahStore to inspect shelf stock.';
    } else if (expiredCount > 0) {
      title = '🚨 Expired Medicine Alert ($expiredCount items)';
      body = 'Medicines have reached expiry date. Remove from store shelves immediately.';
    } else {
      title = '⚠️ Near Expiry Warning ($expiringCount items)';
      body = 'Medicines approaching expiry date. Prioritize sales and customer orders.';
    }

    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'BismillahStore Expiry Alerts',
      channelDescription: 'Timely notifications for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    await notificationsPlugin.show(
      9999,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'expiry_summary',
    );
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await notificationsPlugin.cancelAll();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});
