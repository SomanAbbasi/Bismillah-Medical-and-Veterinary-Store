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
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/supplier_repository.dart';

class SupplierAccountScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierAccountScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierAccountScreen> createState() => _SupplierAccountScreenState();
}

class _SupplierAccountScreenState extends ConsumerState<SupplierAccountScreen> {
  String _shopName = 'BismillahStore';
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

  void _shareStatement(SupplierWithBalance item, List<dynamic> txs) {
    final buffer = StringBuffer();
    buffer.writeln('====================================');
    buffer.writeln('$_shopName - Supplier Statement');
    buffer.writeln('====================================');
    buffer.writeln('Supplier: ${item.supplier.name}');
    buffer.writeln('Phone: ${item.supplier.phone}');
    if (item.supplier.company != null && item.supplier.company!.isNotEmpty) {
      buffer.writeln('Company: ${item.supplier.company}');
    }
    buffer.writeln('Date: ${DateFormatter.formatDate(DateTime.now())}');
    buffer.writeln('------------------------------------');
    buffer.writeln('TRANSACTIONS:');

    for (final tx in txs) {
      final dateStr = DateFormatter.formatShortDate(tx.date);
      final isPayable = tx.type == 'payable';
      final typeLabel = isPayable ? 'Bill (Owed)' : 'Payment';
      final amount = CurrencyFormatter.formatPaisa(tx.amountPaisa);
      buffer.writeln('$dateStr | $typeLabel | $amount | ${tx.reference ?? tx.note ?? ''}');
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('Total Bills: ${CurrencyFormatter.formatPaisa(item.totalPayablePaisa)}');
    buffer.writeln('Total Paid: ${CurrencyFormatter.formatPaisa(item.totalPaidPaisa)}');
    buffer.writeln('CURRENT BALANCE OWED: ${CurrencyFormatter.formatPaisa(item.balancePaisa)}');
    buffer.writeln('====================================');

    Share.share(buffer.toString(), subject: 'Supplier Statement - ${item.supplier.name}');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(supplierRepositoryProvider);
    final txsAsync = ref.watch(supplierTransactionsStreamProvider(widget.supplierId));

    return FutureBuilder<SupplierWithBalance?>(
      future: repo.getSupplierWithBalance(widget.supplierId),
      builder: (context, snapshot) {
        final supplierWithBal = snapshot.data;

        if (supplierWithBal == null && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (supplierWithBal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Supplier Details')),
            body: const Center(child: Text('Supplier not found')),
          );
        }

        final supplier = supplierWithBal.supplier;
        final owes = supplierWithBal.owesSupplier;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement',
                onPressed: () {
                  final txs = txsAsync.asData?.value ?? [];
                  _shareStatement(supplierWithBal, txs);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Supplier',
                onPressed: () async {
                  await context.push('/suppliers/${supplier.id}/edit');
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Supplier',
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Delete Supplier',
                    message: 'Are you sure you want to move this supplier to trash? You can restore it later from Trash.',
                    isDestructive: true,
                    confirmLabel: 'Delete',
                  );
                  if (confirmed && context.mounted) {
                    await repo.softDeleteSupplier(widget.supplierId);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Supplier Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(
                    color: owes ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: owes ? AppColors.warningLight : AppColors.primarySubtle,
                          foregroundColor: owes ? AppColors.warning : AppColors.primary,
                          child: Text(
                            supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(supplier.name, style: AppTypography.heading3),
                              const SizedBox(height: 2),
                              Text('Phone: ${supplier.phone}', style: AppTypography.bodySmall),
                              if (supplier.company != null && supplier.company!.isNotEmpty)
                                Text('Company: ${supplier.company}', style: AppTypography.bodySmall),
                              if (supplier.address != null && supplier.address!.isNotEmpty)
                                Text('Address: ${supplier.address}', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaisa(supplierWithBal.balancePaisa),
                              style: AppTypography.heading2.copyWith(
                                color: owes ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StatusChip(
                              label: owes ? 'Store Owes' : 'Cleared',
                              type: owes ? StatusType.warning : StatusType.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Add Bill (Payable)',
                            icon: Icons.add,
                            onPressed: () async {
                              await context.push('/suppliers/${widget.supplierId}/payable');
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Record Payment',
                            icon: Icons.payments_outlined,
                            onPressed: () async {
                              await context.push('/suppliers/${widget.supplierId}/payment');
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ledger Transactions List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ledger Transactions', style: AppTypography.heading3),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(_startDate == null ? 'Filter Date' : 'Clear Filter'),
                      onPressed: () async {
                        if (_startDate != null) {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        } else {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (range != null) {
                            setState(() {
                              _startDate = range.start;
                              _endDate = range.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Transactions
              Expanded(
                child: txsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (txs) {
                    var filtered = txs;
                    if (_startDate != null && _endDate != null) {
                      filtered = filtered.where((t) => t.date.isAfter(_startDate!) && t.date.isBefore(_endDate!)).toList();
                    }

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No transaction records found for this period.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final isPayable = tx.type == 'payable';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPayable ? AppColors.warningLight : AppColors.successLight,
                                  borderRadius: AppRadii.roundedSm,
                                ),
                                child: Icon(
                                  isPayable ? Icons.receipt_long : Icons.payments,
                                  color: isPayable ? AppColors.warning : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPayable ? 'Payable Bill (Owed)' : 'Payment Made',
                                      style: AppTypography.labelLarge,
                                    ),
                                    Text(
                                      '${DateFormatter.formatDate(tx.date)}${tx.reference != null ? " • ${tx.reference}" : ""}',
                                      style: AppTypography.bodySmall,
                                    ),
                                    if (tx.note != null && tx.note!.isNotEmpty)
                                      Text(tx.note!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.formatPaisa(tx.amountPaisa),
                                    style: AppTypography.labelLarge.copyWith(
                                      color: isPayable ? AppColors.warning : AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted),
                                    onPressed: () async {
                                      final ok = await ConfirmationDialog.show(
                                        context: context,
                                        title: 'Delete Transaction',
                                        message: 'Delete this record from ledger?',
                                        isDestructive: true,
                                      );
                                      if (ok) {
                                        await repo.softDeleteTransaction(tx.id);
                                        setState(() {});
                                      }
                                    },
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
              ),
            ],
          ),
        );
      },
    );
  }
}
