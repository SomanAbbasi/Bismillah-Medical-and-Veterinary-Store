import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';

class DeletedItemModel {
  final int id;
  final String entityType; // 'medicine', 'sale', 'expense', 'transaction', 'customer'
  final String title;
  final String subtitle;
  final DateTime? deletedAt;

  DeletedItemModel({
    required this.id,
    required this.entityType,
    required this.title,
    required this.subtitle,
    this.deletedAt,
  });

  int get daysLeft {
    if (deletedAt == null) return 30;
    final passed = DateTime.now().difference(deletedAt!).inDays;
    return (30 - passed).clamp(0, 30);
  }
}

final deletedItemsFutureProvider = FutureProvider<List<DeletedItemModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  final List<DeletedItemModel> items = [];

  // Deleted Medicines
  final meds = await (db.select(db.medicines)..where((tbl) => tbl.isDeleted.equals(true))).get();
  for (final m in meds) {
    items.add(DeletedItemModel(
      id: m.id,
      entityType: 'medicine',
      title: m.name,
      subtitle: 'Expiry: ${DateFormatter.formatDate(m.expiryDate)} • ${m.category}',
      deletedAt: m.deletedAt,
    ));
  }

  // Deleted Sales
  final sales = await (db.select(db.sales)..where((tbl) => tbl.isDeleted.equals(true))).get();
  for (final s in sales) {
    items.add(DeletedItemModel(
      id: s.id,
      entityType: 'sale',
      title: s.title,
      subtitle: '${DateFormatter.formatDate(s.date)} • ${CurrencyFormatter.formatPaisa(s.finalAmountPaisa)} (${s.paymentType.toUpperCase()})',
      deletedAt: s.deletedAt,
    ));
  }

  // Deleted Expenses
  final exp = await (db.select(db.expenses)..where((tbl) => tbl.isDeleted.equals(true))).get();
  for (final e in exp) {
    items.add(DeletedItemModel(
      id: e.id,
      entityType: 'expense',
      title: e.title,
      subtitle: '${DateFormatter.formatDate(e.date)} • ${CurrencyFormatter.formatPaisa(e.amountPaisa)} (${e.category ?? "General"})',
      deletedAt: e.deletedAt,
    ));
  }

  // Deleted Customers
  final custs = await (db.select(db.customers)..where((tbl) => tbl.isDeleted.equals(true))).get();
  for (final c in custs) {
    items.add(DeletedItemModel(
      id: c.id,
      entityType: 'customer',
      title: c.name,
      subtitle: 'Phone: ${c.phone}',
      deletedAt: c.deletedAt,
    ));
  }

  // Deleted Customer Transactions
  final txs = await (db.select(db.customerTransactions)..where((tbl) => tbl.isDeleted.equals(true))).get();
  for (final t in txs) {
    items.add(DeletedItemModel(
      id: t.id,
      entityType: 'transaction',
      title: '${t.type == "credit" ? "Credit Entry" : "Payment Record"} (${CurrencyFormatter.formatPaisa(t.amountPaisa)})',
      subtitle: '${DateFormatter.formatDate(t.date)}${t.note != null ? " • ${t.note}" : ""}',
      deletedAt: t.deletedAt,
    ));
  }

  items.sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
  return items;
});

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _restoreItem(BuildContext context, WidgetRef ref, DeletedItemModel item) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Restore Item?',
      message: 'Restore "${item.title}" back to active records?',
      confirmLabel: 'Restore Item',
    );
    if (!confirmed) return;

    final db = ref.read(databaseProvider);
    if (item.entityType == 'medicine') {
      await db.restoreMedicine(item.id);
    } else if (item.entityType == 'sale') {
      await db.restoreSale(item.id);
    } else if (item.entityType == 'expense') {
      await db.restoreExpense(item.id);
    } else if (item.entityType == 'customer') {
      await db.restoreCustomer(item.id);
    } else if (item.entityType == 'transaction') {
      await db.restoreCustomerTransaction(item.id);
    }

    ref.invalidate(deletedItemsFutureProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.title}" restored successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _permanentDelete(BuildContext context, WidgetRef ref, DeletedItemModel item) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Permanently Delete?',
      message: 'This will permanently remove "${item.title}" from your database. It cannot be recovered.',
      confirmLabel: 'Permanently Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    final db = ref.read(databaseProvider);
    if (item.entityType == 'medicine') {
      await (db.delete(db.medicines)..where((tbl) => tbl.id.equals(item.id))).go();
    } else if (item.entityType == 'sale') {
      await (db.delete(db.sales)..where((tbl) => tbl.id.equals(item.id))).go();
    } else if (item.entityType == 'expense') {
      await (db.delete(db.expenses)..where((tbl) => tbl.id.equals(item.id))).go();
    } else if (item.entityType == 'customer') {
      await (db.delete(db.customers)..where((tbl) => tbl.id.equals(item.id))).go();
    } else if (item.entityType == 'transaction') {
      await (db.delete(db.customerTransactions)..where((tbl) => tbl.id.equals(item.id))).go();
    }

    ref.invalidate(deletedItemsFutureProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item permanently deleted.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(deletedItemsFutureProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recycle Bin (30-Day Trash)'),
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline,
              title: 'Recycle Bin is Empty',
              description: 'Deleted sales, expenses, medicines, and ledger records stay here for 30 days before auto-deletion.',
            );
          }

          return ListView(
            padding: AppSpacing.pagePadding,
            children: [
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Deleted items stay in the Recycle Bin for 30 days. You can restore them anytime.',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              ...items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(12),
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
                          color: AppColors.dangerLight,
                          borderRadius: AppRadii.roundedMd,
                        ),
                        child: Icon(
                          item.entityType == 'medicine'
                              ? Icons.medication
                              : item.entityType == 'sale'
                                  ? Icons.receipt_long
                                  : item.entityType == 'expense'
                                      ? Icons.account_balance_wallet
                                      : Icons.credit_card,
                          color: AppColors.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: AppTypography.labelLarge),
                            const SizedBox(height: 2),
                            Text(item.subtitle, style: AppTypography.bodySmall),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-deletes in ${item.daysLeft} days',
                              style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo, color: AppColors.primary),
                            tooltip: 'Restore Item',
                            onPressed: () => _restoreItem(context, ref, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                            tooltip: 'Permanently Delete',
                            onPressed: () => _permanentDelete(context, ref, item),
                          ),
                        ],
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
