import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationDiagnosticInfo {
  final bool areNotificationsEnabled;
  final bool canScheduleExactAlarms;
  final bool isChannelEnabled;
  final bool isSoundEnabled;
  final bool isBatteryOptimizedExempt;
  final String? deviceManufacturer;
  final int? androidSdk;
  final int scheduledAlarmsCount;
  final int activeRemindersCount;
  final DateTime? nextExpectedNotification;
  final DateTime? lastReconciledAt;
  final String? lastError;
  final bool isScheduledTestActive;
  final DateTime? scheduledTestExpectedAt;

  NotificationDiagnosticInfo({
    required this.areNotificationsEnabled,
    required this.canScheduleExactAlarms,
    required this.isChannelEnabled,
    required this.isSoundEnabled,
    required this.isBatteryOptimizedExempt,
    this.deviceManufacturer,
    this.androidSdk,
    required this.scheduledAlarmsCount,
    required this.activeRemindersCount,
    this.nextExpectedNotification,
    this.lastReconciledAt,
    this.lastError,
    this.isScheduledTestActive = false,
    this.scheduledTestExpectedAt,
  });
}

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String expiryChannelId = 'bismillahstore_expiry_v4';
  static const String backupChannelId = 'bismillahstore_backup_v4';
  static const MethodChannel _settingsChannel = MethodChannel('com.bismillahstore/settings_channel');

  static const int immediateTestNotificationId = 7777;
  static const int scheduledTestNotificationId = 8888;
  static const int expirySummaryNotificationId = 9999;

  DateTime? _scheduledTestExpectedAt;
  DateTime? get scheduledTestExpectedAt => _scheduledTestExpectedAt;

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize timezones with reliable local matching
    tz.initializeTimeZones();
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      if (offsetMs == 18000000) {
        // Pakistan Standard Time (PKT, UTC+5)
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } else {
        tz.Location? matched;
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.timeZone(now.millisecondsSinceEpoch).offset == offsetMs) {
            matched = loc;
            break;
          }
        }
        if (matched != null) {
          tz.setLocalLocation(matched);
        } else {
          tz.setLocalLocation(tz.UTC);
        }
      }
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    // 2. Initialize local notifications with drawable icon resource
    // 'ic_notification' is located in android/app/src/main/res/drawable
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Response handling
        },
      );
    } catch (_) {
      // Fallback with standard launcher icon name
      const fallbackSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
      );
      await notificationsPlugin.initialize(fallbackSettings);
    }

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

  /// Requests the POST_NOTIFICATIONS permission on Android 13+ (API 33+)
  Future<bool> requestNotificationPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;

    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  /// Requests exact alarm scheduling permission (Android 12+)
  Future<bool> requestExactAlarmsPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;

    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        final granted = await androidImplementation.requestExactAlarmsPermission();
        return granted ?? false;
      } catch (_) {
        await openExactAlarmSettings();
        return false;
      }
    }
    return false;
  }

  /// Checks if exact alarms can be scheduled in the OS
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return false;
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      try {
        final canExact = await androidImplementation.canScheduleExactNotifications();
        return canExact ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Checks if notifications are actually enabled in the OS
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled();
      return enabled ?? false;
    }
    return false;
  }

  /// Checks if battery optimization exemption is active (unrestricted background)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _settingsChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves device info (Manufacturer, SDK level)
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (!Platform.isAndroid) return {'manufacturer': 'Unknown', 'sdkInt': 0, 'isSamsung': false};
    try {
      final res = await _settingsChannel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return res ?? {};
    } catch (_) {
      return {'manufacturer': 'Android', 'sdkInt': 0, 'isSamsung': false};
    }
  }

  /// Opens the device App Notification Settings page via native Intent
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _settingsChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Opens the device Exact Alarm Settings page via native Intent
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final androidImplementation = notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestExactAlarmsPermission();
        return;
      }
    } catch (_) {}
    try {
      await _settingsChannel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  /// Opens battery optimization settings with device-specific intent
  Future<Map<String, dynamic>> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return {'launched': false};
    try {
      final res = await _settingsChannel.invokeMapMethod<String, dynamic>('openBatteryOptimizationSettings');
      return res ?? {'launched': true};
    } catch (e) {
      return {'launched': false, 'error': e.toString()};
    }
  }

  /// Returns total count of pending notifications registered with the OS AlarmManager
  Future<int> getPendingNotificationCount() async {
    try {
      final pending = await notificationsPlugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// Inspects notification channels for enabled and sound status
  Future<Map<String, bool>> checkChannelHealth() async {
    if (!Platform.isAndroid) return {'channelEnabled': true, 'soundEnabled': true};
    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      try {
        final channels = await androidImplementation.getNotificationChannels();
        if (channels != null && channels.isNotEmpty) {
          final expiryChannel = channels.firstWhere(
            (c) => c.id == expiryChannelId,
            orElse: () => channels.first,
          );
          final isEnabled = expiryChannel.importance != Importance.none;
          final hasSound = expiryChannel.playSound;
          return {'channelEnabled': isEnabled, 'soundEnabled': hasSound};
        }
      } catch (_) {}
    }
    return {'channelEnabled': true, 'soundEnabled': true};
  }

  /// Fires an immediate test notification with thorough OS status validation
  Future<void> testImmediateNotification() async {
    await initialize();

    // 1. Verify notification permission
    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      throw Exception('Notification permission is not granted. Please enable notifications in Android Settings.');
    }

    // 2. Verify channel health
    final health = await checkChannelHealth();
    if (!(health['channelEnabled'] ?? true)) {
      throw Exception('The "$expiryChannelId" notification channel is blocked or disabled in system settings.');
    }

    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'BismillahStore Expiry Alerts',
      channelDescription: 'Audible high-priority alerts for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: 'ic_notification',
    );

    await notificationsPlugin.show(
      immediateTestNotificationId,
      '🔔 BismillahStore Immediate Test',
      'Immediate alert test successful! Sound, banner, and vibration are active.',
      const NotificationDetails(android: androidDetails),
      payload: 'immediate_test',
    );
  }

  /// Backward-compatible alias for testImmediateNotification
  Future<void> testSoundNotification() async {
    await testImmediateNotification();
  }

  /// Schedules a standalone test notification a few seconds into the future
  Future<DateTime> scheduleTestNotification({int secondsFromNow = 30}) async {
    await initialize();

    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      throw Exception('Cannot schedule test: Notification permission is disabled.');
    }

    final canExact = await canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final tzNow = tz.TZDateTime.now(tz.local);
    final scheduledDate = tzNow.add(Duration(seconds: secondsFromNow));

    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'BismillahStore Expiry Alerts',
      channelDescription: 'Audible high-priority alerts for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: 'ic_notification',
    );

    await cancelNotification(scheduledTestNotificationId);

    await notificationsPlugin.zonedSchedule(
      scheduledTestNotificationId,
      '⏰ BismillahStore Scheduled Alarm Test',
      'Scheduled reminder delivered successfully on time while app was closed/idle!',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'test_scheduled',
    );

    _scheduledTestExpectedAt = DateTime.now().add(Duration(seconds: secondsFromNow));
    return _scheduledTestExpectedAt!;
  }

  /// Cancels any pending scheduled test notification
  Future<void> cancelTestNotification() async {
    await cancelNotification(scheduledTestNotificationId);
    _scheduledTestExpectedAt = null;
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
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'ic_notification',
    );

    await notificationsPlugin.show(
      expirySummaryNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'expiry_summary',
    );
  }

  Future<void> cancelNotification(int id) async {
    try {
      await notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await notificationsPlugin.cancelAll();
      _scheduledTestExpectedAt = null;
    } catch (_) {}
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});
