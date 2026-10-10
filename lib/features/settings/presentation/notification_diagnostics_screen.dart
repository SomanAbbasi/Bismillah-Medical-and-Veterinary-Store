import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/expiry_reminder_scheduler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/primary_button.dart';

class NotificationDiagnosticsScreen extends ConsumerStatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  ConsumerState<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends ConsumerState<NotificationDiagnosticsScreen>
    with WidgetsBindingObserver {
  NotificationDiagnosticInfo? _info;
  bool _isLoading = true;
  String? _actionMessage;
  bool _isActionError = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDiagnostics();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDiagnostics();
    }
  }

  Future<void> _refreshDiagnostics() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final scheduler = ref.read(expiryReminderSchedulerProvider);
      final info = await scheduler.getDiagnostics(db);
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
          if (info.isScheduledTestActive && info.scheduledTestExpectedAt != null) {
            _startCountdown(info.scheduledTestExpectedAt!);
          } else {
            _countdownTimer?.cancel();
            _secondsRemaining = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _actionMessage = 'Failed to fetch diagnostics: $e';
          _isActionError = true;
        });
      }
    }
  }

  void _startCountdown(DateTime target) {
    _countdownTimer?.cancel();
    final remaining = target.difference(DateTime.now()).inSeconds;
    _secondsRemaining = remaining > 0 ? remaining : 0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final diff = target.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        _refreshDiagnostics();
      } else {
        setState(() => _secondsRemaining = diff);
      }
    });
  }

  Future<void> _testImmediate() async {
    setState(() {
      _actionMessage = null;
    });
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.testImmediateNotification();
      if (mounted) {
        setState(() {
          _actionMessage = 'Immediate test notification sent successfully with sound & vibration!';
          _isActionError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionMessage = 'Immediate test failed: $e';
          _isActionError = true;
        });
      }
    }
  }

  Future<void> _scheduleTest() async {
    setState(() {
      _actionMessage = null;
    });
    try {
      final notifService = ref.read(notificationServiceProvider);
      const testSeconds = 30;
      final expectedAt = await notifService.scheduleTestNotification(secondsFromNow: testSeconds);
      _startCountdown(expectedAt);
      await _refreshDiagnostics();

      if (mounted) {
        setState(() {
          _actionMessage =
              'Test notification scheduled! Expected delivery in $testSeconds seconds. You can now minimize or lock your screen.';
          _isActionError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionMessage = 'Scheduling test failed: $e';
          _isActionError = true;
        });
      }
    }
  }

  Future<void> _cancelScheduledTest() async {
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.cancelTestNotification();
      _countdownTimer?.cancel();
      _secondsRemaining = 0;
      await _refreshDiagnostics();
      if (mounted) {
        setState(() {
          _actionMessage = 'Scheduled test cancelled.';
          _isActionError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionMessage = 'Failed to cancel test: $e';
          _isActionError = true;
        });
      }
    }
  }

  Future<void> _rebuildSchedule() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final scheduler = ref.read(expiryReminderSchedulerProvider);
      final count = await scheduler.reconcile(db, forceReschedule: true);
      await _refreshDiagnostics();
      if (mounted) {
        setState(() {
          _actionMessage = 'Reminder schedule rebuilt successfully. $count medicine(s) scheduled.';
          _isActionError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _actionMessage = 'Rebuild failed: $e';
          _isActionError = true;
        });
      }
    }
  }

  Future<void> _openBatterySettings() async {
    final notifService = ref.read(notificationServiceProvider);
    await notifService.openBatteryOptimizationSettings();

    if (mounted && _info?.deviceManufacturer?.toLowerCase() == 'samsung') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: const Text('Samsung Battery Guidance', style: AppTypography.heading3),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'On Samsung Galaxy devices (One UI):',
                style: AppTypography.bodySmall,
              ),
              SizedBox(height: 8),
              Text('1. In App Info, tap "Battery".', style: AppTypography.bodySmall),
              Text('2. Select "Unrestricted" (instead of Optimized).', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'This prevents Samsung sleeping app policies from delaying morning alarms.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notification Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check Status Again',
            onPressed: _refreshDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_actionMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isActionError
                            ? AppColors.danger.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(
                          color: _isActionError ? AppColors.danger : AppColors.success,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isActionError ? Icons.error_outline : Icons.check_circle,
                            color: _isActionError ? AppColors.danger : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _actionMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isActionError ? AppColors.danger : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Scheduled Test Active Banner
                  if (_info?.isScheduledTestActive == true) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.alarm_on, color: AppColors.primary, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Test Scheduled: Delivery Pending in ${_secondsRemaining}s',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Target time: ${DateFormatter.formatDateTime(_info!.scheduledTestExpectedAt!)}. Lock your phone to test background delivery.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.cancel, size: 14),
                            label: const Text('Cancel Test Alarm'),
                            onPressed: _cancelScheduledTest,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Subsystem Permissions Card
                  Text('OS Permissions & Channel Health', style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.roundedLg,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                          icon: Icons.notifications,
                          label: 'Android Notification Permission',
                          isHealthy: _info?.areNotificationsEnabled ?? false,
                          healthyText: 'Granted (POST_NOTIFICATIONS)',
                          unhealthyText: 'Denied in Android OS',
                        ),
                        const Divider(height: 1),
                        _buildStatusRow(
                          icon: Icons.alarm,
                          label: 'Exact Alarm Access (Timing)',
                          isHealthy: _info?.canScheduleExactAlarms ?? false,
                          healthyText: 'Exact Alarms Allowed',
                          unhealthyText: 'Inexact / Battery-Optimized Only',
                        ),
                        const Divider(height: 1),
                        _buildStatusRow(
                          icon: Icons.tune,
                          label: 'Notification Channel Status',
                          isHealthy: _info?.isChannelEnabled ?? true,
                          healthyText: 'Active (${NotificationService.expiryChannelId})',
                          unhealthyText: 'Blocked by User Settings',
                        ),
                        const Divider(height: 1),
                        _buildStatusRow(
                          icon: Icons.volume_up,
                          label: 'Audible Sound & Audio Alert',
                          isHealthy: _info?.isSoundEnabled ?? true,
                          healthyText: 'Audible Sound Enabled',
                          unhealthyText: 'Muted in Channel Settings',
                        ),
                        const Divider(height: 1),
                        _buildStatusRow(
                          icon: Icons.battery_charging_full,
                          label: 'Battery Optimization Exemption',
                          isHealthy: _info?.isBatteryOptimizedExempt ?? false,
                          healthyText: 'Unrestricted (Background Allowed)',
                          unhealthyText: 'Optimized (Standard Mode)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Scheduler Metrics Card
                  Text('Scheduler Status & Tracked Medicines', style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.roundedLg,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildMetricRow(
                          'OS Registered Alarms',
                          '${_info?.scheduledAlarmsCount ?? 0} alarm(s)',
                        ),
                        _buildMetricRow(
                          'Eligible Expiring Medicines',
                          '${_info?.activeRemindersCount ?? 0} item(s)',
                        ),
                        _buildMetricRow(
                          'Next Scheduled Reminder',
                          _info?.nextExpectedNotification != null
                              ? DateFormatter.formatDateTime(_info!.nextExpectedNotification!)
                              : 'None pending',
                        ),
                        _buildMetricRow(
                          'Last Schedule Reconciliation',
                          _info?.lastReconciledAt != null
                              ? DateFormatter.formatDateTime(_info!.lastReconciledAt!)
                              : 'Never reconciled',
                        ),
                        if (_info?.deviceManufacturer != null)
                          _buildMetricRow(
                            'Device / OS Level',
                            '${_info!.deviceManufacturer} (API ${_info?.androidSdk ?? "Unknown"})',
                          ),
                      ],
                    ),
                  ),
                  if (_info?.lastError != null)
                    _buildErrorCard(_info!.lastError!),
                  const SizedBox(height: AppSpacing.xl),

                  // Diagnostic Actions
                  Text('Diagnostic Actions', style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),

                  PrimaryButton(
                    label: 'Test Immediate Notification',
                    icon: Icons.notifications_active,
                    onPressed: _testImmediate,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.timer),
                    label: const Text('Test Scheduled Notification (30s)'),
                    onPressed: _scheduleTest,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.sync),
                    label: const Text('Rebuild Reminder Schedule'),
                    onPressed: _rebuildSchedule,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Check Permissions Again'),
                    onPressed: _refreshDiagnostics,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open App Notification Settings'),
                    onPressed: () async {
                      final notifService = ref.read(notificationServiceProvider);
                      await notifService.openNotificationSettings();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (Platform.isAndroid) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Open Exact Alarm Settings'),
                      onPressed: () async {
                        final notifService = ref.read(notificationServiceProvider);
                        await notifService.openExactAlarmSettings();
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.battery_alert),
                      label: const Text('Open Battery Settings'),
                      onPressed: _openBatterySettings,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required bool isHealthy,
    required String healthyText,
    required String unhealthyText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: isHealthy ? AppColors.success : AppColors.danger, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  isHealthy ? healthyText : unhealthyText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isHealthy ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isHealthy ? Icons.check_circle : Icons.cancel,
            color: isHealthy ? AppColors.success : AppColors.danger,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isError ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String rawError) {
    String summary = rawError;
    String details = '';
    if (rawError.contains('TypeToken')) {
      summary = 'R8 Generic Signature Error (TypeToken): Generic type signatures were stripped during shrinking.';
      details = rawError;
    } else if (rawError.contains('\n') || rawError.contains('at ')) {
      final lines = rawError.split('\n');
      summary = lines.first;
      details = lines.skip(1).join('\n');
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diagnostic Error Detected',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('View Full Stack Trace', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: AppRadii.roundedSm,
                    ),
                    child: SelectableText(
                      details,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
