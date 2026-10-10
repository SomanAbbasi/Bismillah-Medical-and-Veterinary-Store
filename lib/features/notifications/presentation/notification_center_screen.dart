import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_provider.dart';

import '../../../core/notifications/expiry_reminder_scheduler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/data/inventory_repository.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  bool _isChecking = false;

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    final db = ref.read(databaseProvider);
    final count = await ref.read(expiryReminderSchedulerProvider).reconcile(db);
    if (mounted) {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notifications refreshed. $count active alert(s) evaluated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications & Reminders'),
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Check Expiries Now',
            onPressed: _isChecking ? null : _checkNow,
          ),
        ],
      ),
      body: medicinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => AppErrorWidget(
          title: 'Unable to load notifications',
          error: err,
          stackTrace: stack,
          onRetry: () => ref.invalidate(medicinesStreamProvider),
        ),
        data: (medicines) {
          final activeAlerts = medicines.where((m) {
            if (m.isReminderDisabled) return false;
            final isExpired = m.expiryDate.isBefore(DateFormatter.today());
            final status = ExpiryUtils.getStatus(m.expiryDate);
            return isExpired || status != ExpiryStatus.healthy;
          }).toList();

          if (activeAlerts.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: 'No Pending Notifications',
              description: 'All your medicines are within safe expiry periods, or reminders are completed.',
              actionLabel: 'Check Expiries Again',
              onAction: _checkNow,
            );
          }

          return ListView.separated(
            padding: AppSpacing.pagePadding,
            itemCount: activeAlerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final med = activeAlerts[index];
              final isExpired = med.expiryDate.isBefore(DateFormatter.today());

              return Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedMd,
                  border: Border.all(
                    color: isExpired ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isExpired ? 'EXPIRED: ${med.name}' : 'EXPIRING SOON: ${med.name}',
                            style: AppTypography.labelLarge.copyWith(
                              color: isExpired ? AppColors.danger : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: isExpired ? 'EXPIRED' : ExpiryUtils.getHumanRemainingText(med.expiryDate),
                          type: isExpired ? StatusType.expired : StatusType.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires on ${DateFormatter.formatDate(med.expiryDate)}. Brand: ${med.brand}',
                      style: AppTypography.bodyMedium,
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push('/inventory/${med.id}'),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View Medicine'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final repo = ref.read(inventoryRepositoryProvider);
                            await repo.toggleReminderDisabled(med.id, true);
                          },
                          child: const Text('Mute Reminder', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
