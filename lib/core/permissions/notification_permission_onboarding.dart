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
  int _currentStep = 1; // 1: Notifications, 2: Exact Alarm, 3: Battery Optimization, 4: Sound/Channel
  bool _isLoading = false;

  bool _isNotifGranted = false;
  bool _canExactAlarm = false;
  bool _hasCheckedStatus = false;
  String? _statusFeedback;

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
      // Re-verify actual Android OS status upon returning to app
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

    if (mounted) {
      setState(() {
        _isNotifGranted = notifGranted;
        _canExactAlarm = exactGranted;
        _hasCheckedStatus = true;
      });
    }
  }

  Future<void> _handleStep1Request() async {
    setState(() => _isLoading = true);
    final notifService = ref.read(notificationServiceProvider);

    // Request Android 13+ POST_NOTIFICATIONS
    await notifService.requestNotificationPermission();

    // Re-verify directly from Android OS
    final actualStatus = await notifService.areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isNotifGranted = actualStatus;
        if (actualStatus) {
          _statusFeedback = 'Notification permission granted!';
          _currentStep = 2; // Proceed to exact alarm step
        } else {
          _statusFeedback =
              'Notifications are currently disabled. Please enable them in App Settings to receive medicine expiry reminders.';
        }
      });
    }
  }

  Future<void> _handleOpenSettings() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openNotificationSettings();
  }

  Future<void> _handleStep2Request() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openExactAlarmSettings();
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reminder Setup', style: AppTypography.heading3),
        automaticallyImplyLeading: false,
        actions: [
          if (_currentStep >= 2)
            TextButton(
              onPressed: _finishOnboarding,
              child: const Text('Skip & Continue'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Progress Indicator
              Row(
                children: [
                  _buildStepIndicator(1, 'Notifications', _currentStep >= 1, _isNotifGranted),
                  _buildStepDivider(),
                  _buildStepIndicator(2, 'Timing', _currentStep >= 2, _canExactAlarm),
                  _buildStepDivider(),
                  _buildStepIndicator(3, 'Battery', _currentStep >= 3, false),
                  _buildStepDivider(),
                  _buildStepIndicator(4, 'Complete', _currentStep >= 4, true),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Step 1: Notifications
              if (_currentStep == 1) _buildStep1Widget(),

              // Step 2: Exact Alarm
              if (_currentStep == 2) _buildStep2Widget(),

              // Step 3: Battery Optimization
              if (_currentStep == 3) _buildStep3Widget(),

              // Step 4: Summary & Channel health
              if (_currentStep == 4) _buildStep4Widget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, bool isActive, bool isDone) {
    Color color;
    if (isDone) {
      color = AppColors.success;
    } else if (isActive) {
      color = AppColors.primary;
    } else {
      color = AppColors.textMuted.withValues(alpha: 0.3);
    }

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 16,
      height: 2,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _buildStep1Widget() {
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
        const Text('Enable Medicine Expiry Alerts', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'BismillahStore monitors your medicine inventory daily and sends audible alerts to your phone before stock expires, preventing financial loss and expired sales.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (_statusFeedback != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isNotifGranted ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
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

        if (!_isNotifGranted) ...[
          PrimaryButton(
            label: 'Allow Notifications',
            icon: Icons.notifications,
            isLoading: _isLoading,
            onPressed: _handleStep1Request,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Open App Settings'),
            onPressed: _handleOpenSettings,
          ),
        ] else ...[
          PrimaryButton(
            label: 'Continue to Timing Setup',
            icon: Icons.arrow_forward,
            onPressed: () => setState(() => _currentStep = 2),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2Widget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.alarm, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Exact Reminder Scheduling', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Android 12 and newer allows apps to schedule exact reminders so alerts ring on time even when your phone is locked or screen is off.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _canExactAlarm ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: AppRadii.roundedMd,
            border: Border.all(
              color: _canExactAlarm ? AppColors.success : AppColors.warning,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _canExactAlarm ? Icons.check_circle : Icons.info_outline,
                color: _canExactAlarm ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _canExactAlarm
                      ? 'Exact alarm scheduling is active and permitted.'
                      : 'Exact alarms are currently optional. If disabled, reminders will use standard battery-optimized scheduling.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _canExactAlarm ? AppColors.success : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (!_canExactAlarm) ...[
          PrimaryButton(
            label: 'Enable Exact Alarms in Settings',
            icon: Icons.alarm_add,
            onPressed: _handleStep2Request,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Continue With Standard Scheduling'),
            onPressed: () => setState(() => _currentStep = 3),
          ),
        ] else ...[
          PrimaryButton(
            label: 'Next: Battery Reliability',
            icon: Icons.arrow_forward,
            onPressed: () => setState(() => _currentStep = 3),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3Widget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.battery_charging_full, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Samsung & Android Battery Tips', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Devices like Samsung Galaxy use aggressive battery saving. For the most reliable morning reminders, you can optionally ensure BismillahStore is not restricted.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Optional recommendations:', style: AppTypography.labelMedium),
                SizedBox(height: 6),
                Text('• Allow app to run in background', style: AppTypography.bodySmall),
                Text('• Exclude BismillahStore from "Sleeping Apps" in Samsung Device Care', style: AppTypography.bodySmall),
                Text('• Standard reminders work without this, but this maximizes reliability', style: AppTypography.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.battery_alert),
          label: const Text('Open Battery Settings (Optional)'),
          onPressed: () async {
            final notifService = ref.read(notificationServiceProvider);
            await notifService.openBatteryOptimizationSettings();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Continue to Final Step',
          icon: Icons.arrow_forward,
          onPressed: () => setState(() => _currentStep = 4),
        ),
      ],
    );
  }

  Widget _buildStep4Widget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, size: 48, color: AppColors.success),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Reminder Setup Completed!', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Your expiry alert system is configured with high-priority audible alerts and system vibration. Reminders will be reconciled automatically as you manage medicines.',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.volume_up, color: AppColors.primary),
          title: const Text('Audible Alerts & Vibration', style: AppTypography.labelLarge),
          subtitle: const Text('System sound configured on BismillahStore channel', style: AppTypography.bodySmall),
          trailing: OutlinedButton(
            child: const Text('Test Sound'),
            onPressed: () async {
              final notifService = ref.read(notificationServiceProvider);
              await notifService.testSoundNotification();
            },
          ),
        ),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        PrimaryButton(
          label: 'Open Dashboard',
          icon: Icons.store,
          onPressed: _finishOnboarding,
        ),
      ],
    );
  }
}
