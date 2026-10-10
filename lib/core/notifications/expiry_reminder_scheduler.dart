import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database/app_database.dart';
import '../utils/date_formatter.dart';
import 'notification_service.dart';

class ExpiryReminderScheduler {
  final NotificationService _notificationService;
  DateTime? _lastReconciledAt;
  String? _lastError;
  int _activeRemindersCount = 0;
  DateTime? _nextExpectedNotification;
  ExpiryReminderScheduler(this._notificationService);

  void dispose() {}

  /// Robust cancellation helper for a single medicine
  /// Cancels the canonical medicine notification ID and any burst IDs (id * 1000 + 1..20)
  Future<void> cancelMedicineReminders(int medicineId) async {
    await _notificationService.cancelNotification(medicineId);
    for (int i = 1; i <= 20; i++) {
      await _notificationService.cancelNotification(medicineId * 1000 + i);
    }
  }

  DateTime? get lastReconciledAt => _lastReconciledAt;
  String? get lastError => _lastError;
  int get activeRemindersCount => _activeRemindersCount;
  DateTime? get nextExpectedNotification => _nextExpectedNotification;

  /// Fetches real, live diagnostic status of the notification, alarm, and battery subsystem
  Future<NotificationDiagnosticInfo> getDiagnostics(AppDatabase db) async {
    final notifsEnabled = await _notificationService.areNotificationsEnabled();
    final canExact = await _notificationService.canScheduleExactAlarms();
    final channelHealth = await _notificationService.checkChannelHealth();
    final isBatteryExempt = await _notificationService.isIgnoringBatteryOptimizations();
    final deviceInfo = await _notificationService.getDeviceInfo();
    final pendingCount = await _notificationService.getPendingNotificationCount();
    final testExpected = _notificationService.scheduledTestExpectedAt;

    return NotificationDiagnosticInfo(
      areNotificationsEnabled: notifsEnabled,
      canScheduleExactAlarms: canExact,
      isChannelEnabled: channelHealth['channelEnabled'] ?? true,
      isSoundEnabled: channelHealth['soundEnabled'] ?? true,
      isBatteryOptimizedExempt: isBatteryExempt,
      deviceManufacturer: deviceInfo['manufacturer'] as String?,
      androidSdk: deviceInfo['sdkInt'] as int?,
      scheduledAlarmsCount: pendingCount,
      activeRemindersCount: _activeRemindersCount,
      nextExpectedNotification: _nextExpectedNotification,
      lastReconciledAt: _lastReconciledAt,
      lastError: _lastError,
      isScheduledTestActive: testExpected != null && testExpected.isAfter(DateTime.now()),
      scheduledTestExpectedAt: testExpected,
    );
  }

  /// Reconciles database records with Android scheduled notification alarms
  /// Ensures idempotent scheduling without constantly postponing future alarms
  Future<int> reconcile(AppDatabase db, {bool forceReschedule = false}) async {
    try {
      await _notificationService.initialize();

      if (forceReschedule) {
        await _notificationService.cancelAllMedicineAlarms();
      }

      // Read global settings
      final defaultMonthsStr = await db.getSetting('default_reminder_months');
      final globalDefaultMonths = defaultMonthsStr != null ? (int.tryParse(defaultMonthsStr) ?? 1) : 1;

      final intervalMinutesStr = await db.getSetting('notification_interval_minutes');
      final globalIntervalMinutes = intervalMinutesStr != null ? (int.tryParse(intervalMinutesStr) ?? 1440) : 1440;

      final canExact = await _notificationService.canScheduleExactAlarms();

      // Retrieve all medicines including soft-deleted ones so we can clean up any scheduled alarms
      final medicines = await db.getAllMedicines(includeDeleted: true);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int scheduledCount = 0;
      DateTime? earliestNext;

      for (final med in medicines) {
        if (med.isDeleted || med.isDraft) {
          await cancelMedicineReminders(med.id);
          await db.updateMedicineScheduleInfo(
            med.id,
            lastScheduledAt: null,
            nextScheduledAt: null,
            notificationId: null,
          );
          continue;
        }

        if (med.isReminderDisabled) {
          await cancelMedicineReminders(med.id);
          await db.updateMedicineScheduleInfo(
            med.id,
            lastScheduledAt: null,
            nextScheduledAt: null,
            notificationId: null,
          );
          continue;
        }

        // Calculate lead days based on user's preference or medicine override
        final leadDays = med.reminderLeadDays ??
            (med.reminderMonths != null ? med.reminderMonths! * 30 : globalDefaultMonths * 30);
        final reminderStartDate = med.expiryDate.subtract(Duration(days: leadDays));

        final isExpired = med.expiryDate.isBefore(today);
        final isEligible = isExpired || now.isAfter(reminderStartDate) || now.isAtSameMomentAs(reminderStartDate);

        if (!isEligible) {
          await cancelMedicineReminders(med.id);
          await db.updateMedicineScheduleInfo(
            med.id,
            lastScheduledAt: null,
            nextScheduledAt: null,
            notificationId: null,
          );
          continue;
        }

        // Calculate next scheduled occurrence
        final intervalMinutes = med.reminderIntervalMinutes ?? globalIntervalMinutes;
        final isFastTest = intervalMinutes <= 1;

        // If already scheduled in the future and not forcing a reset or fast test mode, keep existing schedule intact
        if (!forceReschedule && !isFastTest && med.nextScheduledAt != null && med.nextScheduledAt!.isAfter(now)) {
          scheduledCount++;
          if (earliestNext == null || med.nextScheduledAt!.isBefore(earliestNext)) {
            earliestNext = med.nextScheduledAt;
          }
          continue;
        }

        DateTime scheduledTime;

        if (intervalMinutes < 1440) {
          // Sub-daily recurrence (e.g. 1 min test mode, 15 min, 60 min)
          scheduledTime = now.add(Duration(minutes: intervalMinutes));
        } else {
          // Daily or multi-day recurrence
          final preferredHour = med.preferredHour;
          final preferredMinute = med.preferredMinute;
          var candidate = DateTime(now.year, now.month, now.day, preferredHour, preferredMinute);

          if (candidate.isAfter(now)) {
            scheduledTime = candidate;
          } else {
            final daysToAdd = (intervalMinutes / 1440).ceil().clamp(1, 30);
            scheduledTime = candidate.add(Duration(days: daysToAdd));
          }
        }

        if (earliestNext == null || scheduledTime.isBefore(earliestNext)) {
          earliestNext = scheduledTime;
        }

        var tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
        final tzNow = tz.TZDateTime.now(tz.local);
        if (tzScheduled.isBefore(tzNow)) {
          tzScheduled = tzNow.add(const Duration(minutes: 1));
        }

        final batchSuffix = (med.batchNumber != null && med.batchNumber!.isNotEmpty)
            ? ' (Batch: ${med.batchNumber})'
            : '';
        final title = isExpired
            ? '🚨 EXPIRED: ${med.name}$batchSuffix'
            : '⚠️ EXPIRING SOON: ${med.name}$batchSuffix';
        final body = isExpired
            ? '${med.name} expired on ${DateFormatter.formatDate(med.expiryDate)}. Remove from store shelves immediately.'
            : '${med.name} expires on ${DateFormatter.formatDate(med.expiryDate)}. Check stock and prioritize sales.';

        const androidDetails = AndroidNotificationDetails(
          NotificationService.expiryChannelId,
          'BismillahStore Expiry Alerts',
          channelDescription: 'Audible high-priority alerts for expiring and expired medicines',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );

        // Cancel previous schedule for this medicine before setting replacement
        await cancelMedicineReminders(med.id);

        if (Platform.isAndroid) {
          final scheduleMode = canExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle;

          if (intervalMinutes <= 1) {
            // Schedule repeating 1-minute bursts (for 1..5 minutes) for fast testing
            for (int i = 1; i <= 5; i++) {
              final burstId = med.id * 1000 + i;
              final fireTime = tzNow.add(Duration(minutes: i));
              try {
                await _notificationService.notificationsPlugin.zonedSchedule(
                  burstId,
                  title,
                  body,
                  fireTime,
                  const NotificationDetails(android: androidDetails),
                  androidScheduleMode: scheduleMode,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime,
                  payload: 'medicine:${med.id}',
                );
              } catch (_) {
                await _notificationService.notificationsPlugin.zonedSchedule(
                  burstId,
                  title,
                  body,
                  fireTime,
                  const NotificationDetails(android: androidDetails),
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime,
                  payload: 'medicine:${med.id}',
                );
              }
            }
          } else {
            try {
              await _notificationService.notificationsPlugin.zonedSchedule(
                med.id,
                title,
                body,
                tzScheduled,
                const NotificationDetails(android: androidDetails),
                androidScheduleMode: scheduleMode,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: intervalMinutes == 1440 ? DateTimeComponents.time : null,
                payload: 'medicine:${med.id}',
              );
            } catch (_) {
              await _notificationService.notificationsPlugin.zonedSchedule(
                med.id,
                title,
                body,
                tzScheduled,
                const NotificationDetails(android: androidDetails),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: intervalMinutes == 1440 ? DateTimeComponents.time : null,
                payload: 'medicine:${med.id}',
              );
            }
          }
        }

        await db.updateMedicineScheduleInfo(
          med.id,
          lastScheduledAt: now,
          nextScheduledAt: scheduledTime,
          notificationId: med.id,
        );

        scheduledCount++;
      }

      _activeRemindersCount = scheduledCount;
      _nextExpectedNotification = earliestNext;
      _lastReconciledAt = DateTime.now();
      _lastError = null;

      return scheduledCount;
    } catch (e) {
      _lastError = '[Scheduling] $e';
      return _activeRemindersCount;
    }
  }
}

final expiryReminderSchedulerProvider = Provider<ExpiryReminderScheduler>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  return ExpiryReminderScheduler(notifService);
});
