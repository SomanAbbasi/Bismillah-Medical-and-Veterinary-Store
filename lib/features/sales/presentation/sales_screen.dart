import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/sales_repository.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  Future<void> _handleDeleteSale(BuildContext context, WidgetRef ref, Sale sale) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Move Sale to Recycle Bin?',
      message: 'Delete "${sale.title}" (${CurrencyFormatter.formatPaisa(sale.finalAmountPaisa)})? It will stay in the 30-day Trash and can be restored anytime.',
      confirmLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    final repo = ref.read(salesRepositoryProvider);
    await repo.softDeleteSale(sale.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${sale.title}" moved to Recycle Bin.'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await repo.restoreSale(sale.id);
            },
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(recentSalesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales Ledger'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (sales) {
          if (sales.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'No Sales Recorded',
              description: 'Record daily cash sales or customer udhaar transactions.',
              actionLabel: 'New Sale',
              onAction: () => context.push('/sales/new'),
            );
          }

          final today = DateFormatter.today();
          final todaySales = sales.where((s) => !s.date.isBefore(today)).toList();
          final todayTotalPaisa = todaySales.fold(0, (sum, s) => sum + s.finalAmountPaisa);
          final todayCashPaisa = todaySales.fold(0, (sum, s) => sum + s.cashPaidPaisa);
          final todayCreditPaisa = todaySales.fold(0, (sum, s) => sum + s.creditAmountPaisa);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Summary Banner
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
                    Text("Today's Total Sales", style: AppTypography.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatPaisa(todayTotalPaisa),
                      style: AppTypography.heading1.copyWith(color: AppColors.primary),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 16, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('Cash: ${CurrencyFormatter.formatPaisa(todayCashPaisa)}', style: AppTypography.bodySmall),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.credit_card, size: 16, color: AppColors.danger),
                            const SizedBox(width: 4),
                            Text('Credit: ${CurrencyFormatter.formatPaisa(todayCreditPaisa)}', style: AppTypography.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Sale Transactions (${sales.length})', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),

              ...sales.map((sale) {
                final isCredit = sale.paymentType == 'credit';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/sales/${sale.id}'),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCredit ? AppColors.dangerLight : AppColors.primarySubtle,
                            borderRadius: AppRadii.roundedMd,
                          ),
                          child: Icon(
                            isCredit ? Icons.credit_card : Icons.receipt_long,
                            color: isCredit ? AppColors.danger : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sale.title, style: AppTypography.labelLarge),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormatter.formatDate(sale.date)}${sale.notes != null ? " • ${sale.notes}" : ""}',
                                style: AppTypography.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaisa(sale.finalAmountPaisa),
                              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            StatusChip(
                              label: isCredit ? 'Credit (Udhaar)' : 'Cash Paid',
                              type: isCredit ? StatusType.critical : StatusType.success,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => context.push('/sales/${sale.id}/edit'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                  onPressed: () => _handleDeleteSale(context, ref, sale),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
