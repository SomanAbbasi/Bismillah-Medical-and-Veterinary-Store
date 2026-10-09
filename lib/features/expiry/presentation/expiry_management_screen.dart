import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/data/inventory_repository.dart';

class ExpiryManagementScreen extends ConsumerWidget {
  const ExpiryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final db = ref.watch(databaseProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Medicine Expiry Alerts'),
          actions: [
            IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              tooltip: 'Test Sound Notification',
              onPressed: () async {
                await ref.read(notificationServiceProvider).testSoundNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔔 System notification sound triggered! Check status bar.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Expired Medicines'),
              Tab(text: 'Expiring Soon'),
            ],
          ),
        ),
        body: medicinesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (medicines) {
            final today = DateFormatter.today();

            return FutureBuilder<String?>(
              future: db.getSetting('default_reminder_months'),
              builder: (context, settingSnap) {
                final defaultMonths = settingSnap.data != null ? (int.tryParse(settingSnap.data!) ?? 1) : 1;

                final expired = medicines.where((m) => !m.isDraft && m.expiryDate.isBefore(today)).toList()
                  ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                final expiringSoon = medicines.where((m) {
                  if (m.isDraft || m.expiryDate.isBefore(today)) return false;
                  final threshold = m.reminderMonths ?? defaultMonths;
                  return ExpiryUtils.isInReminderWindow(m.expiryDate, threshold, referenceDate: today);
                }).toList()
                  ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                return TabBarView(
                  children: [
                    _ExpiryMedicineList(
                      items: expired,
                      emptyTitle: 'No Expired Medicines',
                      emptyDesc: 'All medicines in stock are fresh and non-expired!',
                      isExpiredTab: true,
                    ),
                    _ExpiryMedicineList(
                      items: expiringSoon,
                      emptyTitle: 'No Medicines Expiring Soon',
                      emptyDesc: 'No medicines inside your active reminder window.',
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ExpiryMedicineList extends ConsumerWidget {
  final List<Medicine> items;
  final String emptyTitle;
  final String emptyDesc;
  final bool isExpiredTab;

  const _ExpiryMedicineList({
    required this.items,
    required this.emptyTitle,
    required this.emptyDesc,
    this.isExpiredTab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: emptyTitle,
        description: emptyDesc,
      );
    }

    final repo = ref.watch(inventoryRepositoryProvider);

    return ListView.builder(
      padding: AppSpacing.pagePadding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final med = items[index];
        final humanText = ExpiryUtils.getHumanRemainingText(med.expiryDate);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.roundedMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpiredTab ? AppColors.dangerLight : AppColors.amberLight,
                  borderRadius: AppRadii.roundedMd,
                ),
                child: Icon(
                  isExpiredTab ? Icons.cancel_outlined : Icons.access_time_filled,
                  color: isExpiredTab ? AppColors.danger : AppColors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: AppTypography.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Expiry: ${DateFormatter.formatDate(med.expiryDate)}${med.brand.isNotEmpty ? " • ${med.brand}" : ""}',
                      style: AppTypography.bodySmall,
                    ),
                    if (med.isReminderDisabled) ...[
                      const SizedBox(height: 2),
                      const Text('Alerts Disabled', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: isExpiredTab ? 'Expired' : humanText,
                    type: isExpiredTab ? StatusType.critical : StatusType.warning,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          med.isReminderDisabled ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                          size: 18,
                          color: med.isReminderDisabled ? AppColors.textMuted : AppColors.primary,
                        ),
                        tooltip: med.isReminderDisabled ? 'Enable Alerts' : 'Turn Off Alerts',
                        onPressed: () async {
                          await repo.setReminderDisabled(med.id, !med.isReminderDisabled);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  med.isReminderDisabled ? 'Alerts re-enabled' : 'Expiry alerts turned off for ${med.name}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => context.push('/inventory/${med.id}/edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
