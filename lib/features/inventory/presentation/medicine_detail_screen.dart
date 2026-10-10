import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/inventory_repository.dart';

class MedicineDetailScreen extends ConsumerWidget {
  final int medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medicine Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Medicine',
            onPressed: () => context.push('/inventory/$medicineId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Move to Trash',
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context: context,
                title: 'Delete Medicine?',
                message: 'Move this medicine to Recycle Bin (30-day Trash)?',
                isDestructive: true,
                confirmLabel: 'Move to Trash',
              );
              if (confirmed && context.mounted) {
                final repo = ref.read(inventoryRepositoryProvider);
                await repo.softDeleteMedicine(medicineId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Medicine moved to Recycle Bin.'),
                      duration: const Duration(seconds: 2),
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: Colors.yellow,
                        onPressed: () async {
                          await repo.restoreMedicine(medicineId);
                        },
                      ),
                    ),
                  );
                  context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: medicinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (medicines) {
          final matching = medicines.where((m) => m.id == medicineId).toList();
          if (matching.isEmpty) {
            return const Center(child: Text('Medicine not found'));
          }
          final med = matching.first;
          final status = ExpiryUtils.getStatus(med.expiryDate);
          final isExpired = med.expiryDate.isBefore(DateFormatter.today());

          return ListView(
            padding: AppSpacing.pagePadding,
            children: [
              // Header Card
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isExpired ? AppColors.dangerLight : AppColors.primarySubtle,
                            borderRadius: AppRadii.roundedMd,
                          ),
                          child: Icon(
                            Icons.medication,
                            color: isExpired ? AppColors.danger : AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(med.name, style: AppTypography.heading2),
                              if (med.genericName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Generic: ${med.genericName}', style: AppTypography.bodyMedium),
                              ],
                              if (med.brand.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Brand: ${med.brand}', style: AppTypography.bodySmall),
                              ],
                            ],
                          ),
                        ),
                        StatusChip(
                          label: isExpired ? 'EXPIRED' : ExpiryUtils.getHumanRemainingText(med.expiryDate),
                          type: isExpired
                              ? StatusType.expired
                              : status == ExpiryStatus.critical1Month
                                  ? StatusType.critical
                                  : status == ExpiryStatus.warning3Months
                                      ? StatusType.warning
                                      : StatusType.success,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Expiry Date', style: AppTypography.bodySmall),
                            Text(
                              DateFormatter.formatDate(med.expiryDate),
                              style: AppTypography.heading3.copyWith(
                                color: isExpired ? AppColors.danger : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Category', style: AppTypography.bodySmall),
                            Text(
                              med.category,
                              style: AppTypography.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (med.notes != null && med.notes!.isNotEmpty) ...[
                      Text('Notes / Remarks', style: AppTypography.bodySmall),
                      Text(med.notes!, style: AppTypography.bodyMedium),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Expiry Reminder Setting Card
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Expiry Alert Schedule', style: AppTypography.heading3),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      med.reminderMonths != null
                          ? 'Custom reminder set: ${med.reminderMonths} month(s) before expiry'
                          : 'Using global settings default (3 months before expiry)',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      med.isReminderDisabled ? 'Status: Muted / Completed' : 'Status: Active Daily Reminders',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: med.isReminderDisabled ? AppColors.textMuted : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}
