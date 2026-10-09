import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/customer_repository.dart';

class CustomerAccountScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerAccountScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends ConsumerState<CustomerAccountScreen> {
  String _shopName = 'Bismillah Medical and Veterinary Store';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final db = ref.read(databaseProvider);
    final name = await db.getSetting('shop_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _shopName = name);
    }
  }

  Future<void> _shareStatement(CustomerWithBalance item, List<CustomerTransactionWithRunningBalance> history) async {
    final repo = ref.read(customerRepositoryProvider);
    final statement = repo.generateStatementText(
      shopName: _shopName,
      customer: item.customer,
      history: history,
      currentBalancePaisa: item.balancePaisa,
    );

    await Share.share(statement, subject: 'Account Statement - ${item.customer.name}');
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null && mounted) {
      setState(() {
        _startDate = range.start;
        _endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);

    return customersAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
      data: (customers) {
        final matching = customers.where((c) => c.customer.id == widget.customerId).toList();
        if (matching.isEmpty) {
          return const Scaffold(body: Center(child: Text('Customer not found')));
        }
        final item = matching.first;

        final cust = item.customer;
        final owes = item.owesMoney;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(cust.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement',
                onPressed: () async {
                  final history = await ref.read(customerRepositoryProvider).getTransactionsWithRunningBalance(cust.id);
                  _shareStatement(item, history);
                },
              ),
            ],
          ),
          body: FutureBuilder<List<CustomerTransactionWithRunningBalance>>(
            future: ref.watch(customerRepositoryProvider).getTransactionsWithRunningBalance(
                  cust.id,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
            builder: (context, snapshot) {
              final history = snapshot.data ?? [];

              return ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  // Profile & Balance Card
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cust.name, style: AppTypography.heading2),
                                const SizedBox(height: 2),
                                Text(cust.phone, style: AppTypography.bodyMedium),
                                if (cust.address != null && cust.address!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(cust.address!, style: AppTypography.bodySmall),
                                ],
                              ],
                            ),
                            StatusChip(
                              label: owes ? 'Owes Store' : 'Cleared',
                              type: owes ? StatusType.critical : StatusType.success,
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
                                Text('Current Balance', style: AppTypography.bodySmall),
                                Text(
                                  CurrencyFormatter.formatPaisa(item.balancePaisa),
                                  style: AppTypography.numberDisplay.copyWith(
                                    color: owes ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              owes ? 'Payable by Customer' : 'Zero Balance',
                              style: AppTypography.bodySmall.copyWith(
                                color: owes ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Record Payment',
                          icon: Icons.payments,
                          backgroundColor: AppColors.success,
                          onPressed: () => context.push('/customers/${cust.id}/payment'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Add Credit',
                          icon: Icons.credit_card,
                          backgroundColor: AppColors.danger,
                          onPressed: () => context.push('/customers/${cust.id}/credit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Share Account Statement (WhatsApp/SMS)',
                    icon: Icons.share,
                    onPressed: () => _shareStatement(item, history),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Date Filter Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ledger Transactions (${history.length})', style: AppTypography.heading3),
                      Row(
                        children: [
                          if (_startDate != null) ...[
                            TextButton(
                              onPressed: _clearDateFilter,
                              child: const Text('Clear Filter', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                            ),
                          ],
                          IconButton(
                            icon: Icon(
                              _startDate != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                              color: _startDate != null ? AppColors.primary : AppColors.textMuted,
                            ),
                            tooltip: 'Filter by Date Range',
                            onPressed: () => _pickDateRange(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_startDate != null && _endDate != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Showing transactions from ${DateFormatter.formatDate(_startDate!)} to ${DateFormatter.formatDate(_endDate!)}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),

                  if (history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text('No transactions recorded for this period.', style: AppTypography.bodyMedium),
                      ),
                    )
                  else
                    ...history.reversed.map((txItem) {
                      final tx = txItem.transaction;
                      final isCredit = tx.type == 'credit' || tx.type == 'adjustment_debit';

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
                                color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                                borderRadius: AppRadii.roundedMd,
                              ),
                              child: Icon(
                                isCredit ? Icons.arrow_outward : Icons.arrow_downward,
                                color: isCredit ? AppColors.danger : AppColors.success,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCredit ? 'Credit (+)' : 'Payment (-)',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: isCredit ? AppColors.danger : AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${DateFormatter.formatDate(tx.date)}${tx.paymentMethod != null ? " • ${tx.paymentMethod}" : ""}',
                                    style: AppTypography.bodySmall,
                                  ),
                                  if (tx.note != null && tx.note!.isNotEmpty)
                                    Text(
                                      tx.note!,
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
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
                                  CurrencyFormatter.formatPaisa(tx.amountPaisa),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isCredit ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bal: ${CurrencyFormatter.formatPaisa(txItem.runningBalancePaisa)}',
                                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                              tooltip: 'Move to Trash',
                              onPressed: () async {
                                final confirmed = await ConfirmationDialog.show(
                                  context: context,
                                  title: 'Delete Transaction?',
                                  message: 'Move this transaction of ${CurrencyFormatter.formatPaisa(tx.amountPaisa)} to Trash?',
                                  isDestructive: true,
                                  confirmLabel: 'Move to Trash',
                                );
                                if (confirmed) {
                                  final repo = ref.read(customerRepositoryProvider);
                                  await repo.softDeleteTransaction(tx.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Transaction moved to Recycle Bin.'),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          textColor: Colors.yellow,
                                          onPressed: () async {
                                            await repo.restoreTransaction(tx.id);
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

                  const SizedBox(height: AppSpacing.huge),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
