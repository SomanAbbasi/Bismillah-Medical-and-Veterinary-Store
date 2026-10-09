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

  DateTime? get lastReconciledAt => _lastReconciledAt;
  String? get lastError => _lastError;
  int get activeRemindersCount => _activeRemindersCount;
  DateTime? get nextExpectedNotification => _nextExpectedNotification;

  /// Reconciles database records with Android scheduled notification alarms
  Future<int> reconcile(AppDatabase db) async {
    try {
      await _notificationService.initialize();

      // Read global settings
      final defaultMonthsStr = await db.getSetting('default_reminder_months');
      final globalDefaultMonths = defaultMonthsStr != null ? (int.tryParse(defaultMonthsStr) ?? 1) : 1;

      final intervalMinutesStr = await db.getSetting('notification_interval_minutes');
      final globalIntervalMinutes = intervalMinutesStr != null ? (int.tryParse(intervalMinutesStr) ?? 1440) : 1440;

      final canExact = await _notificationService.canScheduleExactAlarms();

      final medicines = await db.getAllMedicines();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int scheduledCount = 0;
      DateTime? earliestNext;

      for (final med in medicines) {
        if (med.isDeleted || med.isDraft) {
          await _notificationService.cancelNotification(med.id);
          continue;
        }

        if (med.isReminderDisabled) {
          await _notificationService.cancelNotification(med.id);
          await db.updateMedicineScheduleInfo(
            med.id,
            lastScheduledAt: null,
            nextScheduledAt: null,
            notificationId: null,
          );
          continue;
        }

        // Calculate lead days
        final leadDays = med.reminderLeadDays ?? (med.reminderMonths != null ? med.reminderMonths! * 30 : globalDefaultMonths * 30);
        final reminderStartDate = med.expiryDate.subtract(Duration(days: leadDays));

        final isExpired = med.expiryDate.isBefore(today);
        final isEligible = isExpired || now.isAfter(reminderStartDate) || now.isAtSameMomentAs(reminderStartDate);

        if (!isEligible) {
          await _notificationService.cancelNotification(med.id);
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
        DateTime scheduledTime;

        if (intervalMinutes < 1440) {
          // Sub-daily recurrence (e.g. every 60 min, 120 min)
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
          tzScheduled = tzNow.add(const Duration(minutes: 2));
        }

        final batchSuffix = (med.batchNumber != null && med.batchNumber!.isNotEmpty) ? ' (Batch: ${med.batchNumber})' : '';
        final title = isExpired
            ? '🚨 EXPIRED: ${med.name}$batchSuffix'
            : '⚠️ EXPIRING SOON: ${med.name}$batchSuffix';
        final body = isExpired
            ? '${med.name} expired on ${DateFormatter.formatDate(med.expiryDate)}. Remove from store shelves immediately.'
            : '${med.name} expires on ${DateFormatter.formatDate(med.expiryDate)}. Check stock and prioritize sales.';

        final androidDetails = AndroidNotificationDetails(
          NotificationService.expiryChannelId,
          'BismillahStore Expiry Alerts',
          channelDescription: 'Timely notifications for expiring and expired medicines',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.alarm,
        );

        // Cancel previous schedule for this stable ID before setting replacement
        await _notificationService.cancelNotification(med.id);

        if (Platform.isAndroid) {
          if (intervalMinutes == 1) {
            // Schedule repeating 1-minute burst for fast testing
            for (int i = 1; i <= 5; i++) {
              final burstId = med.id * 1000 + i;
              await _notificationService.cancelNotification(burstId);
              await _notificationService.notificationsPlugin.zonedSchedule(
                burstId,
                title,
                body,
                tzNow.add(Duration(minutes: i)),
                NotificationDetails(android: androidDetails),
                androidScheduleMode: canExact
                    ? AndroidScheduleMode.exactAllowWhileIdle
                    : AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: 'medicine:${med.id}',
              );
            }
          } else {
            await _notificationService.notificationsPlugin.zonedSchedule(
              med.id,
              title,
              body,
              tzScheduled,
              NotificationDetails(android: androidDetails),
              androidScheduleMode: canExact
                  ? AndroidScheduleMode.exactAllowWhileIdle
                  : AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: intervalMinutes == 1440 ? DateTimeComponents.time : null,
              payload: 'medicine:${med.id}',
            );
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

      // If active expiring medicines exist, alert immediately so the user sees live feedback
      if (scheduledCount > 0) {
        int expCount = 0;
        int soonCount = 0;
        for (final m in medicines) {
          if (m.isDeleted || m.isDraft || m.isReminderDisabled) continue;
          if (m.expiryDate.isBefore(today)) {
            expCount++;
          } else {
            final leadDays = m.reminderLeadDays ?? (m.reminderMonths != null ? m.reminderMonths! * 30 : globalDefaultMonths * 30);
            final reminderStartDate = m.expiryDate.subtract(Duration(days: leadDays));
            if (now.isAfter(reminderStartDate) || now.isAtSameMomentAs(reminderStartDate)) {
              soonCount++;
            }
          }
        }
        await _notificationService.showExpirySummaryNotification(
          expiredCount: expCount,
          expiringCount: soonCount,
        );
      }

      _activeRemindersCount = scheduledCount;
      _nextExpectedNotification = earliestNext;
      _lastReconciledAt = DateTime.now();
      _lastError = null;

      return scheduledCount;
    } catch (e) {
      _lastError = e.toString();
      return _activeRemindersCount;
    }
  }

  Future<NotificationDiagnosticInfo> getDiagnostics(AppDatabase db) async {
    final enabled = await _notificationService.areNotificationsEnabled();
    final canExact = await _notificationService.canScheduleExactAlarms();

    return NotificationDiagnosticInfo(
      areNotificationsEnabled: enabled,
      canScheduleExactAlarms: canExact,
      activeRemindersCount: _activeRemindersCount,
      nextExpectedNotification: _nextExpectedNotification,
      lastReconciledAt: _lastReconciledAt,
      lastError: _lastError,
    );
  }
}

final expiryReminderSchedulerProvider = Provider<ExpiryReminderScheduler>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  return ExpiryReminderScheduler(notifService);
});
