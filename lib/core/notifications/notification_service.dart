import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../utils/date_formatter.dart';
import '../utils/expiry_utils.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String expiryChannelId = 'bismillah_expiry_reminders';
  static const String backupChannelId = 'bismillah_backup_reminders';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle payload
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          expiryChannelId,
          'Medicine Expiry Reminders',
          description: 'Timely notifications for expiring and expired medicines',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          backupChannelId,
          'Data Backup Reminders',
          description: 'Reminders to backup your store records',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> showExpiryNotification({
    required int id,
    required String medicineName,
    required DateTime expiryDate,
  }) async {
    await initialize();

    final formattedDate = DateFormatter.formatDate(expiryDate);
    final isExpired = expiryDate.isBefore(DateFormatter.today());

    final title = isExpired
        ? 'EXPIRED: $medicineName'
        : 'EXPIRING SOON: $medicineName';

    final body = isExpired
        ? '$medicineName expired on $formattedDate. Please sell or dispose immediately.'
        : '$medicineName expires on $formattedDate. Try to sell as soon as possible.';

    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'Medicine Expiry Reminders',
      channelDescription: 'Timely notifications for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: 'medicine:$id',
    );
  }

  /// Fires an instant test notification with system sound
  Future<void> testSoundNotification() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      expiryChannelId,
      'Medicine Expiry Reminders',
      channelDescription: 'Timely notifications for expiring and expired medicines',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      7777,
      '🔔 Expiry Sound Alert Test',
      'System notification sound and vibration alert is working properly!',
      notificationDetails,
      payload: 'test',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Evaluates all medicines against expiry thresholds and creates notifications
  Future<int> checkAndSyncExpiryReminders(AppDatabase db) async {
    final medicines = await db.getAllMedicines();
    final today = DateFormatter.today();
    final defaultReminderSetting = await db.getSetting('default_reminder_months');
    final globalDefaultMonths = defaultReminderSetting != null ? (int.tryParse(defaultReminderSetting) ?? 1) : 1;

    int activeAlertCount = 0;

    for (final med in medicines) {
      if (med.isReminderDisabled || med.isDraft) {
        continue;
      }

      final reminderThresholdMonths = med.reminderMonths ?? globalDefaultMonths;
      final isExpiring = ExpiryUtils.isInReminderWindow(
        med.expiryDate,
        reminderThresholdMonths,
        referenceDate: today,
      );
      final isExpired = med.expiryDate.isBefore(today);

      if (isExpiring || isExpired) {
        activeAlertCount++;

        if (activeAlertCount <= 3) {
          await showExpiryNotification(
            id: med.id,
            medicineName: med.name,
            expiryDate: med.expiryDate,
          );
        }
      }
    }

    if (activeAlertCount > 3) {
      await _notificationsPlugin.show(
        9990,
        'Attention: $activeAlertCount Medicines Need Attention',
        'You have $activeAlertCount medicines expired or nearing expiration.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            expiryChannelId,
            'Medicine Expiry Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: 'expiry_summary',
      );
    }

    return activeAlertCount;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});
