import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/expense_repository.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Recycle Bin',
            onPressed: () => context.push('/trash'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/new'),
        backgroundColor: AppColors.warning,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => AppErrorWidget(
          title: 'Unable to load expenses',
          error: err,
          stackTrace: stack,
          onRetry: () => ref.invalidate(expensesStreamProvider),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Expenses Recorded',
              description: 'Track electricity, rent, tea, salaries, and daily shop expenses.',
              actionLabel: 'Add Expense',
              onAction: () => context.push('/expenses/new'),
            );
          }

          final today = DateFormatter.today();
          final todayExpenses = expenses.where((e) => !e.date.isBefore(today)).toList();
          final todayTotalPaisa = todayExpenses.fold(0, (sum, e) => sum + e.amountPaisa);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
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
                    Text("Today's Expenses", style: AppTypography.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatPaisa(todayTotalPaisa),
                      style: AppTypography.heading1.copyWith(color: AppColors.warning),
                    ),
                    const SizedBox(height: 4),
                    Text('${todayExpenses.length} expense entry(s) recorded today', style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('Expense History (${expenses.length})', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),

              ...expenses.map((expense) {
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
                          color: AppColors.warningLight,
                          borderRadius: AppRadii.roundedMd,
                        ),
                        child: const Icon(Icons.receipt, color: AppColors.warning, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(expense.title, style: AppTypography.labelLarge),
                            const SizedBox(height: 2),
                            Text(
                              '${expense.category ?? "General"} • ${DateFormatter.formatDate(expense.date)}${expense.note != null ? " • ${expense.note}" : ""}',
                              style: AppTypography.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaisa(expense.amountPaisa),
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                        tooltip: 'Edit Expense',
                        onPressed: () => context.push('/expenses/${expense.id}/edit'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                        tooltip: 'Move to Trash',
                        onPressed: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context: context,
                            title: 'Delete Expense?',
                            message: 'Move "${expense.title}" (${CurrencyFormatter.formatPaisa(expense.amountPaisa)}) to Trash?',
                            isDestructive: true,
                            confirmLabel: 'Move to Trash',
                          );
                          if (confirmed) {
                            final repo = ref.read(expenseRepositoryProvider);
                            await repo.softDeleteExpense(expense.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Expense moved to Recycle Bin.'),
                                  duration: const Duration(seconds: 2),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: Colors.yellow,
                                    onPressed: () async {
                                      await repo.restoreExpense(expense.id);
                                    },
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
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
