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

class NotificationPermissionOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;

  const NotificationPermissionOnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  ConsumerState<NotificationPermissionOnboardingScreen> createState() =>
      _NotificationPermissionOnboardingScreenState();
}

class _NotificationPermissionOnboardingScreenState
    extends ConsumerState<NotificationPermissionOnboardingScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isNotifGranted = false;
  bool _canExactAlarm = false;
  bool _isBatteryExempt = false;
  bool _isSamsung = false;
  bool _hasCheckedStatus = false;
  String? _statusFeedback;
  bool _showSetupComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentStatuses();
    }
  }

  Future<void> _checkCurrentStatuses() async {
    if (!Platform.isAndroid) {
      widget.onCompleted();
      return;
    }

    final notifService = ref.read(notificationServiceProvider);
    final notifGranted = await notifService.areNotificationsEnabled();
    final exactGranted = await notifService.canScheduleExactAlarms();
    final batteryExempt = await notifService.isIgnoringBatteryOptimizations();
    final deviceInfo = await notifService.getDeviceInfo();

    if (mounted) {
      setState(() {
        _isNotifGranted = notifGranted;
        _canExactAlarm = exactGranted;
        _isBatteryExempt = batteryExempt;
        _isSamsung = deviceInfo['isSamsung'] == true;
        _hasCheckedStatus = true;
        if (notifGranted) {
          _showSetupComplete = true;
        }
      });
    }
  }

  Future<void> _handleRequestPermission() async {
    setState(() => _isLoading = true);
    final notifService = ref.read(notificationServiceProvider);

    await notifService.requestNotificationPermission();
    final actualStatus = await notifService.areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isNotifGranted = actualStatus;
        if (actualStatus) {
          _statusFeedback = 'Notification permission granted!';
          _showSetupComplete = true;
        } else {
          _statusFeedback =
              'Notifications are currently disabled. Please tap "Open App Settings" below to turn them on.';
        }
      });
    }
  }

  Future<void> _handleOpenSettings() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openNotificationSettings();
  }

  Future<void> _handleOpenExactAlarm() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openExactAlarmSettings();
  }

  Future<void> _handleOpenBatterySettings() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openBatteryOptimizationSettings();

    if (mounted && _isSamsung) {
      // Show Samsung-specific guidance dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: Row(
            children: [
              const Icon(Icons.battery_charging_full, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Samsung Battery Guidance', style: AppTypography.heading3),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To ensure Samsung One UI does not delay morning notifications:',
                style: AppTypography.bodySmall,
              ),
              SizedBox(height: 10),
              Text('1. Go to App Info (opened or in Settings).', style: AppTypography.bodySmall),
              Text('2. Tap "Battery".', style: AppTypography.bodySmall),
              Text('3. Select "Unrestricted".', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'Note: Standard reminders still work even if battery optimization is kept as Optimized.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleTestSound() async {
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.testImmediateNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification dispatched with sound & vibration!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _finishOnboarding() async {
    final db = ref.read(databaseProvider);
    await db.setSetting('notification_onboarding_completed', 'true');
    await ref.read(expiryReminderSchedulerProvider).reconcile(db);
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedStatus) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          _showSetupComplete ? 'Reminder Readiness' : 'Enable Notifications',
          style: AppTypography.heading3,
        ),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: _showSetupComplete ? _buildSetupCompleteView() : _buildRequestPermissionView(),
        ),
      ),
    );
  }

  Widget _buildRequestPermissionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications_active, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Never Miss Expiring Stock', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'BismillahStore monitors your medicine inventory daily and sends audible alerts before stock expires, preventing financial losses and expired sales.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_statusFeedback != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isNotifGranted
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.danger.withValues(alpha: 0.1),
              borderRadius: AppRadii.roundedMd,
              border: Border.all(
                color: _isNotifGranted ? AppColors.success : AppColors.danger,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isNotifGranted ? Icons.check_circle : Icons.error_outline,
                  color: _isNotifGranted ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _statusFeedback!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isNotifGranted ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        PrimaryButton(
          label: 'Allow Notifications',
          icon: Icons.notifications,
          isLoading: _isLoading,
          onPressed: _handleRequestPermission,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.settings),
          label: const Text('Open App Settings'),
          onPressed: _handleOpenSettings,
        ),
      ],
    );
  }

  Widget _buildSetupCompleteView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading & explanation
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 36, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reminder Setup Ready', style: AppTypography.heading2),
                  SizedBox(height: 2),
                  Text(
                    'Your device is configured to deliver medicine expiry alerts.',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Status Card 1: Notifications
        _buildStatusCard(
          icon: Icons.notifications_active,
          title: 'Android Notifications',
          subtitle: _isNotifGranted
              ? 'Audible alerts and banners are enabled'
              : 'Permission disabled in system settings',
          isHealthy: _isNotifGranted,
          actionLabel: _isNotifGranted ? null : 'Enable in Settings',
          onAction: _handleOpenSettings,
        ),
        const SizedBox(height: AppSpacing.md),

        // Status Card 2: Exact Alarms
        _buildStatusCard(
          icon: Icons.alarm,
          title: 'Alarm Scheduling',
          subtitle: _canExactAlarm
              ? 'Exact alarms permitted (alerts fire precisely on time)'
              : 'Standard battery-optimized scheduling active',
          isHealthy: _canExactAlarm,
          actionLabel: _canExactAlarm ? null : 'Enable Exact Alarms',
          onAction: _handleOpenExactAlarm,
        ),
        const SizedBox(height: AppSpacing.md),

        // Status Card 3: Battery Optimization
        _buildStatusCard(
          icon: Icons.battery_charging_full,
          title: 'Battery Reliability',
          subtitle: _isBatteryExempt
              ? 'Unrestricted background access granted'
              : 'Standard mode active. You can optionally set to Unrestricted for morning reminders.',
          isHealthy: _isBatteryExempt,
          actionLabel: _isBatteryExempt ? null : 'Battery Settings (Optional)',
          onAction: _handleOpenBatterySettings,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Test Sound Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            borderRadius: AppRadii.roundedMd,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.volume_up, color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Notification Sound', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Send an immediate audible alert to verify delivery', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _handleTestSound,
                child: const Text('Test'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Actions
        PrimaryButton(
          label: 'Open Store Dashboard',
          icon: Icons.store,
          onPressed: _finishOnboarding,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _finishOnboarding,
            child: const Text('Skip and Continue', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isHealthy,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isHealthy ? AppColors.success : AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHealthy ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHealthy ? 'Active' : 'Standard',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isHealthy ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
