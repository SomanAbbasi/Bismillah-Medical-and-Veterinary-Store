import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../notifications/notification_service.dart';
import '../notifications/expiry_reminder_scheduler.dart';

class PermissionManager {
  static const String _keyOnboardingCompleted = 'notification_onboarding_completed';

  /// Check whether notification permissions are actually granted in the Android OS
  static Future<bool> areNotificationsGranted(WidgetRef ref) async {
    if (!Platform.isAndroid) return true;
    final notifService = ref.read(notificationServiceProvider);
    return await notifService.areNotificationsEnabled();
  }

  /// Check whether battery optimization is ignored (unrestricted)
  static Future<bool> isIgnoringBatteryOptimizations(WidgetRef ref) async {
    if (!Platform.isAndroid) return true;
    final notifService = ref.read(notificationServiceProvider);
    return await notifService.isIgnoringBatteryOptimizations();
  }

  /// Directly requests system notification and alarm permissions on first launch
  static Future<void> checkAndPromptPermissions(BuildContext context, WidgetRef ref) async {
    if (!Platform.isAndroid) return;

    final db = ref.read(databaseProvider);
    final onboardingDone = await db.getSetting(_keyOnboardingCompleted);

    if (onboardingDone != 'true') {
      await db.setSetting(_keyOnboardingCompleted, 'true');
      final notifService = ref.read(notificationServiceProvider);
      // 1. Trigger native Android system permission prompt
      await notifService.requestNotificationPermission();
      // 2. Prompt battery optimization exemption if not already exempt
      final isExempt = await notifService.isIgnoringBatteryOptimizations();
      if (!isExempt) {
        await notifService.openBatteryOptimizationSettings();
      }
      // 3. Reconcile and schedule immediately
      final scheduler = ref.read(expiryReminderSchedulerProvider);
      await scheduler.reconcile(db, forceReschedule: true);
    }
  }
}
