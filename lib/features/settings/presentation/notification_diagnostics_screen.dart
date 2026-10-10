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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDiagnostics();
  }

  @override
  void dispose() {
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _actionMessage = 'Failed to fetch diagnostics: $e';
        });
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.testSoundNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification dispatched with system sound and vibration!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _rebuildSchedule() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final scheduler = ref.read(expiryReminderSchedulerProvider);
      final count = await scheduler.reconcile(db);
      await _refreshDiagnostics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder schedule rebuilt successfully. $count item(s) scheduled.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rebuild failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
            tooltip: 'Refresh Status',
            onPressed: _refreshDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_actionMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Text(_actionMessage!, style: AppTypography.bodySmall),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Subsystem Status Card
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
                          label: 'Exact Alarm Access (Schedule)',
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
                          label: 'Notification Sound & Audio',
                          isHealthy: _info?.isSoundEnabled ?? true,
                          healthyText: 'Audible Alert Enabled',
                          unhealthyText: 'Muted in Android Channel Settings',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Scheduler Metrics Card
                  Text('Active Schedules & Metrics', style: AppTypography.heading3),
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
                          'OS Alarms Registered',
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
                        if (_info?.lastError != null)
                          _buildMetricRow(
                            'Last Error',
                            _info!.lastError!,
                            isError: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Diagnostics Actions
                  Text('Diagnostic Actions', style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),

                  PrimaryButton(
                    label: 'Send Test Notification',
                    icon: Icons.notifications_active,
                    onPressed: _testNotification,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.sync),
                    label: const Text('Rebuild Reminder Schedule Now'),
                    onPressed: _rebuildSchedule,
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

                  if (Platform.isAndroid)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Open Exact Alarm Settings'),
                      onPressed: () async {
                        final notifService = ref.read(notificationServiceProvider);
                        await notifService.openExactAlarmSettings();
                      },
                    ),
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
}
