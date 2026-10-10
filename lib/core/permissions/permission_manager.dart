import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../notifications/notification_service.dart';
import '../notifications/expiry_reminder_scheduler.dart';
import 'notification_permission_onboarding.dart';

class PermissionManager {
  static const String _keyOnboardingCompleted = 'notification_onboarding_completed';

  /// Check whether notification permissions are actually granted in the Android OS
  static Future<bool> areNotificationsGranted(WidgetRef ref) async {
    if (!Platform.isAndroid) return true;
    final notifService = ref.read(notificationServiceProvider);
    return await notifService.areNotificationsEnabled();
  }

  /// Checks and prompts the step-by-step onboarding flow if not yet completed or notifications disabled
  static Future<void> checkAndPromptPermissions(BuildContext context, WidgetRef ref) async {
    if (!Platform.isAndroid) return;

    final db = ref.read(databaseProvider);
    final onboardingDone = await db.getSetting(_keyOnboardingCompleted);

    // Show onboarding on first launch until completed or dismissed
    if (onboardingDone != 'true') {
      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => NotificationPermissionOnboardingScreen(
            onCompleted: () {
              Navigator.of(ctx).pop();
              final db = ref.read(databaseProvider);
              ref.read(expiryReminderSchedulerProvider).reconcile(db);
            },
          ),
        ),
      );
    }
  }
}
