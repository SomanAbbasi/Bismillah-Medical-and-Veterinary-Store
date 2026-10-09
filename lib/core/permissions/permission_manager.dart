import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../notifications/notification_service.dart';
import '../notifications/expiry_reminder_scheduler.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';

class PermissionManager {
  static const String _keyPermissionPrompted = 'permissions_prompted_once';

  /// Check whether all essential permissions are granted
  static Future<bool> areAllPermissionsGranted(WidgetRef ref) async {
    if (!Platform.isAndroid) return true;
    final notifService = ref.read(notificationServiceProvider);
    return await notifService.areNotificationsEnabled();
  }

  /// Request all essential background and alert permissions directly
  static Future<void> requestAllPermissions(WidgetRef ref) async {
    if (!Platform.isAndroid) return;

    try {
      final notifService = ref.read(notificationServiceProvider);
      // 1. Notification Permission (Android 13+ / API 33+)
      await notifService.requestPermissions();

      // 2. Schedule Exact Alarm (Android 12+ / API 31+)
      await notifService.canScheduleExactAlarms();

      // Reconcile and schedule immediately once permissions are handled
      final db = ref.read(databaseProvider);
      await ref.read(expiryReminderSchedulerProvider).reconcile(db);
    } catch (_) {}
  }

  /// Shows permissions prompt dialog on first launch or if notifications are disabled
  static Future<void> checkAndPromptPermissions(BuildContext context, WidgetRef ref) async {
    if (!Platform.isAndroid) return;

    final db = ref.read(databaseProvider);
    final alreadyPrompted = await db.getSetting(_keyPermissionPrompted);
    final notifService = ref.read(notificationServiceProvider);
    final isNotifGranted = await notifService.areNotificationsEnabled();

    // If never prompted OR notifications are not granted, show permission dialog
    if (alreadyPrompted != 'true' || !isNotifGranted) {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: AppRadii.roundedMd,
                ),
                child: const Icon(Icons.notifications_active, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Enable Expiry Alerts', style: AppTypography.heading3),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BismillahStore needs permission to alert you with sound and notifications before medicines expire, even when the app is closed or after restarting your phone.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildPermTile(
                icon: Icons.notifications,
                title: 'Notification Alerts',
                subtitle: 'Audible alerts for near-expiry and expired stock',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPermTile(
                icon: Icons.alarm,
                title: 'Exact Alarm Scheduling',
                subtitle: 'Fires reminders on time when phone is locked',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPermTile(
                icon: Icons.battery_charging_full,
                title: 'Background Reliability',
                subtitle: 'Ensures alarms persist after phone reboot',
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            PrimaryButton(
              label: 'Allow All Permissions',
              icon: Icons.check_circle_outline,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await db.setSetting(_keyPermissionPrompted, 'true');
                await requestAllPermissions(ref);
              },
            ),
          ],
        ),
      );
    }
  }

  static Widget _buildPermTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
