import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/files/attachment_service.dart';
import '../../../core/reports/pdf_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/receipt_share_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
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
  bool _isSingleDay = false;

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

  Future<void> _exportPdfStatement(CustomerWithBalance item, List<CustomerTransactionWithRunningBalance> history) async {
    final shopProfile = await ref.read(shopProfileProvider.future);
    String? periodLabel;
    if (_startDate != null && _endDate != null) {
      if (_isSingleDay) {
        periodLabel = 'Single Date: ${DateFormatter.formatDate(_startDate!)}';
      } else {
        periodLabel = '${DateFormatter.formatDate(_startDate!)} to ${DateFormatter.formatDate(_endDate!)}';
      }
    } else {
      periodLabel = 'All Recorded Transactions';
    }

    await PdfReportService.printCustomerLedger(
      shop: shopProfile,
      customer: item.customer,
      history: history,
      currentBalancePaisa: item.balancePaisa,
      periodLabel: periodLabel,
    );
  }

  List<CustomerTransactionWithRunningBalance> _filterHistory(List<CustomerTransactionWithRunningBalance> raw) {
    if (_startDate == null || _endDate == null) return raw;
    return raw.where((h) {
      final txDate = h.transaction.date.toLocal();
      final txDay = DateTime(txDate.year, txDate.month, txDate.day);
      final sDay = DateTime(_startDate!.toLocal().year, _startDate!.toLocal().month, _startDate!.toLocal().day);
      final eDay = DateTime(_endDate!.toLocal().year, _endDate!.toLocal().month, _endDate!.toLocal().day);

      if (_isSingleDay) {
        return txDay.year == sDay.year && txDay.month == sDay.month && txDay.day == sDay.day;
      } else {
        return (txDay.isAtSameMomentAs(sDay) || txDay.isAfter(sDay)) &&
               (txDay.isAtSameMomentAs(eDay) || txDay.isBefore(eDay));
      }
    }).toList();
  }

  Future<void> _showCustomDateDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Custom Date Filter', style: AppTypography.heading3),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      borderRadius: AppRadii.roundedMd,
                    ),
                    child: const Icon(Icons.calendar_today, color: AppColors.primary),
                  ),
                  title: const Text('Specific Single Day', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('View transactions from one exact date (e.g. today or any past date)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickSingleDate(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      borderRadius: AppRadii.roundedMd,
                    ),
                    child: const Icon(Icons.date_range, color: AppColors.primary),
                  ),
                  title: const Text('Custom Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('View transactions between two dates (From Date - To Date)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDateRange(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickSingleDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        _endDate = DateTime(picked.year, picked.month, picked.day);
        _isSingleDay = true;
      });
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null && !_isSingleDay
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null && mounted) {
      setState(() {
        _startDate = DateTime(range.start.year, range.start.month, range.start.day);
        _endDate = DateTime(range.end.year, range.end.month, range.end.day);
        _isSingleDay = false;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isSingleDay = false;
    });
  }

  Widget _buildPeriodChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadii.roundedSm,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
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
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF Statement',
                onPressed: () async {
                  final rawHistory = await ref.read(customerRepositoryProvider).getTransactionsWithRunningBalance(cust.id);
                  final history = _filterHistory(rawHistory);
                  _exportPdfStatement(item, history.isNotEmpty ? history : rawHistory);
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement (WhatsApp)',
                onPressed: () async {
                  final rawHistory = await ref.read(customerRepositoryProvider).getTransactionsWithRunningBalance(cust.id);
                  final history = _filterHistory(rawHistory);
                  _shareStatement(item, history.isNotEmpty ? history : rawHistory);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Customer',
                onPressed: () async {
                  await context.push('/customers/${cust.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Delete Customer',
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Delete Customer',
                    message: 'Are you sure you want to move "${cust.name}" to the Recycle Bin? All transactions will be preserved.',
                    isDestructive: true,
                    confirmLabel: 'Delete',
                  );
                  if (confirmed && context.mounted) {
                    await ref.read(customerRepositoryProvider).softDeleteCustomer(cust.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Customer "${cust.name}" moved to Recycle Bin.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      context.pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: Consumer(
            builder: (context, ref, _) {
              final txsAsync = ref.watch(customerTransactionsStreamProvider(cust.id));

              return txsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (rawTxs) {
                  // Filter by date range or specific single date if selected
                  final filtered = rawTxs.where((t) {
                    if (_startDate != null && _endDate != null) {
                      final txDate = t.date.toLocal();
                      final txDay = DateTime(txDate.year, txDate.month, txDate.day);
                      final sDay = DateTime(_startDate!.toLocal().year, _startDate!.toLocal().month, _startDate!.toLocal().day);
                      final eDay = DateTime(_endDate!.toLocal().year, _endDate!.toLocal().month, _endDate!.toLocal().day);

                      if (_isSingleDay) {
                        return txDay.year == sDay.year && txDay.month == sDay.month && txDay.day == sDay.day;
                      } else {
                        return (txDay.isAtSameMomentAs(sDay) || txDay.isAfter(sDay)) &&
                               (txDay.isAtSameMomentAs(eDay) || txDay.isBefore(eDay));
                      }
                    }
                    return true;
                  }).toList();

                  // Sort chronological ascending to compute running balances correctly
                  filtered.sort((a, b) => a.date.compareTo(b.date));
                  int running = 0;
                  final List<CustomerTransactionWithRunningBalance> history = [];
                  for (final t in filtered) {
                    if (t.type == 'credit' || t.type == 'adjustment_debit') {
                      running += t.amountPaisa;
                    } else if (t.type == 'payment' || t.type == 'adjustment_credit') {
                      running -= t.amountPaisa;
                    }
                    history.add(CustomerTransactionWithRunningBalance(
                      transaction: t,
                      runningBalancePaisa: running,
                    ));
                  }

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
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _shareStatement(item, history),
                              borderRadius: AppRadii.roundedMd,
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8EE),
                                  borderRadius: AppRadii.roundedMd,
                                  border: Border.all(color: const Color(0xFF25D366), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.share, size: 18, color: Color(0xFF128C7E)),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'WhatsApp Share',
                                          style: TextStyle(
                                            color: Color(0xFF128C7E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: InkWell(
                              onTap: () => _exportPdfStatement(item, history),
                              borderRadius: AppRadii.roundedMd,
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: AppRadii.roundedMd,
                                  border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFFC62828)),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Export PDF',
                                          style: TextStyle(
                                            color: Color(0xFFC62828),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Date Filter Bar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.roundedMd,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _buildPeriodChip(
                              'All Time',
                              _startDate == null,
                              _clearDateFilter,
                            ),
                            _buildPeriodChip(
                              'Today',
                              _startDate != null && _endDate != null && _isSingleDay && DateFormatter.isToday(_startDate!),
                              () {
                                final now = DateFormatter.today();
                                setState(() {
                                  _startDate = DateTime(now.year, now.month, now.day);
                                  _endDate = DateTime(now.year, now.month, now.day);
                                  _isSingleDay = true;
                                });
                              },
                            ),
                            _buildPeriodChip(
                              'Month',
                              _startDate != null && _endDate != null && !_isSingleDay && _startDate!.day == 1,
                              () {
                                final now = DateTime.now();
                                setState(() {
                                  _startDate = DateTime(now.year, now.month, 1);
                                  _endDate = DateTime(now.year, now.month + 1, 0);
                                  _isSingleDay = false;
                                });
                              },
                            ),
                            _buildPeriodChip(
                              'Custom Date',
                              _startDate != null && !(_startDate != null && _isSingleDay && DateFormatter.isToday(_startDate!)) && !(_startDate != null && !_isSingleDay && _startDate!.day == 1),
                              () => _showCustomDateDialog(context),
                            ),
                          ],
                        ),
                      ),

                      // Active Date Filter Banner
                      if (_startDate != null && _endDate != null) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.25),
                            borderRadius: AppRadii.roundedSm,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _isSingleDay
                                      ? 'Filtered Single Day: ${DateFormatter.formatDate(_startDate!)}'
                                      : 'Filtered Range: ${DateFormatter.formatDate(_startDate!)} to ${DateFormatter.formatDate(_endDate!)}',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              InkWell(
                                onTap: () => _showCustomDateDialog(context),
                                child: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: _clearDateFilter,
                                child: const Text('Clear', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text('Ledger Transactions (${history.length})', style: AppTypography.heading3),
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
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: AppRadii.roundedMd,
                              child: InkWell(
                                borderRadius: AppRadii.roundedMd,
                                onTap: () => _showTransactionDetailModal(context, ref, tx, cust),
                                child: Padding(
                                  padding: AppSpacing.cardPadding,
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
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: AppSpacing.huge),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showTransactionDetailModal(
    BuildContext context,
    WidgetRef ref,
    CustomerTransaction tx,
    Customer cust,
  ) {
    final db = ref.read(databaseProvider);
    final repo = ref.read(customerRepositoryProvider);
    final attachmentService = AttachmentService();
    final isCredit = tx.type == 'credit' || tx.type == 'adjustment_debit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                                  borderRadius: AppRadii.roundedMd,
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_outward : Icons.arrow_downward,
                                  color: isCredit ? AppColors.danger : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isCredit ? 'Credit Record Details' : 'Payment Details',
                                style: AppTypography.heading3,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount Display Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                          borderRadius: AppRadii.roundedLg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCredit ? 'Credit Added' : 'Payment Received',
                              style: AppTypography.bodySmall.copyWith(
                                color: isCredit ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaisa(tx.amountPaisa),
                              style: AppTypography.heading1.copyWith(
                                color: isCredit ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Information Grid
                      _buildInfoRow('Customer', cust.name),
                      _buildInfoRow('Date', DateFormatter.formatDateTime(tx.date)),
                      if (tx.paymentMethod != null && tx.paymentMethod!.isNotEmpty)
                        _buildInfoRow(
                          'Payment Method',
                          tx.otherPaymentMethod != null && tx.otherPaymentMethod!.isNotEmpty
                              ? '${tx.paymentMethod} (${tx.otherPaymentMethod})'
                              : tx.paymentMethod!,
                        ),
                      if (tx.reference != null && tx.reference!.isNotEmpty)
                        _buildInfoRow('Reference / Bill #', tx.reference!),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _buildInfoRow('Note / Remarks', tx.note!),

                      const Divider(height: 24),

                      // Attached Photo Proofs
                      Text('Transaction Picture Proof', style: AppTypography.labelLarge),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Attachment>>(
                        future: db.getAttachments('customer_transaction', tx.id),
                        builder: (ctx, snap) {
                          final attachments = snap.data ?? [];

                          if (attachments.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadii.roundedMd,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 36),
                                  const SizedBox(height: 8),
                                  const Text('No photo proof attached to this transaction.', style: AppTypography.bodySmall),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add_a_photo, size: 18),
                                    label: const Text('Add Photo Proof'),
                                    onPressed: () async {
                                      final picked = await showModalBottomSheet<AttachmentResult?>(
                                        context: context,
                                        builder: (c) => SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.camera_alt),
                                                title: const Text('Take Photo from Camera'),
                                                onTap: () async {
                                                  final res = await attachmentService.capturePhoto();
                                                  if (c.mounted) Navigator.pop(c, res);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.photo_library),
                                                title: const Text('Choose from Gallery'),
                                                onTap: () async {
                                                  final res = await attachmentService.pickImageFromGallery();
                                                  if (c.mounted) Navigator.pop(c, res);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      if (picked != null) {
                                        await db.insertAttachment(
                                          AttachmentsCompanion(
                                            entityType: const drift.Value('customer_transaction'),
                                            entityId: drift.Value(tx.id),
                                            filePath: drift.Value(picked.relativePath),
                                            fileName: drift.Value(picked.originalName),
                                            mimeType: drift.Value(picked.mimeType),
                                            description: const drift.Value('Proof photo'),
                                          ),
                                        );
                                        setModalState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...attachments.map((att) {
                                return FutureBuilder<String>(
                                  future: attachmentService.getAbsolutePath(att.filePath),
                                  builder: (ctx, pathSnap) {
                                    if (!pathSnap.hasData) return const SizedBox();
                                    final file = File(pathSnap.data!);
                                    if (!file.existsSync()) return const SizedBox();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadii.roundedMd,
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: AppRadii.roundedMd,
                                            child: InkWell(
                                              onTap: () => _showFullScreenImage(context, file, 'Transaction #${tx.id} Proof'),
                                              child: Image.file(
                                                file,
                                                width: double.infinity,
                                                height: 180,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              radius: 18,
                                              child: IconButton(
                                                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                                                onPressed: () => _showFullScreenImage(context, file, 'Transaction #${tx.id} Proof'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Share Receipt Action
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share Receipt (WhatsApp)'),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          final shopName = await db.getSetting('shop_name') ?? 'Bismillah Medical & Veterinary Store';
                          final receipt = ReceiptShareHelper.buildCustomerReceipt(
                            storeName: shopName,
                            customerName: cust.name,
                            type: tx.type,
                            amountPaisa: tx.amountPaisa,
                            date: tx.date,
                            paymentMethod: tx.paymentMethod,
                            reference: tx.reference,
                            note: tx.note,
                          );
                          if (bottomSheetCtx.mounted) {
                            Navigator.of(bottomSheetCtx).pop();
                            ReceiptShareHelper.showReceiptShareSheet(
                              context: context,
                              personName: cust.name,
                              phone: cust.phone,
                              formattedAmount: CurrencyFormatter.formatPaisa(tx.amountPaisa),
                              typeLabel: tx.type == 'credit' ? 'Credit Sale' : 'Payment Received',
                              receiptText: receipt,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Edit and Delete Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Edit Transaction',
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.of(bottomSheetCtx).pop();
                                _showEditTransactionDialog(context, ref, tx, cust);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
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
                                if (bottomSheetCtx.mounted) {
                                  Navigator.of(bottomSheetCtx).pop();
                                }
                                await repo.softDeleteTransaction(tx.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Transaction moved to Recycle Bin.'),
                                      duration: const Duration(seconds: 2),
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerTransaction tx,
    Customer cust,
  ) {
    final repo = ref.read(customerRepositoryProvider);
    int amountPaisa = tx.amountPaisa;
    DateTime date = tx.date;
    final amountController = TextEditingController(
      text: amountPaisa % 100 == 0 ? (amountPaisa ~/ 100).toString() : (amountPaisa / 100).toStringAsFixed(2),
    );
    String paymentMethod = tx.paymentMethod ?? 'Cash';
    final otherMethodController = TextEditingController(text: tx.otherPaymentMethod ?? '');
    final noteController = TextEditingController(text: tx.note ?? '');
    final refController = TextEditingController(text: tx.reference ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: Text(tx.type == 'credit' ? 'Edit Credit Record' : 'Edit Payment Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CurrencyField(
                  label: 'Amount (PKR)',
                  controller: amountController,
                  onPaisaChanged: (paisa) => amountPaisa = paisa,
                ),
                const SizedBox(height: AppSpacing.md),
                DateField(
                  label: 'Transaction Date',
                  selectedDate: date,
                  onDateSelected: (newDate) => setDlgState(() => date = newDate),
                ),
                if (tx.type == 'payment') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: ['Cash', 'Bank Transfer', 'EasyPaisa / JazzCash', 'Other'].contains(paymentMethod)
                        ? paymentMethod
                        : 'Cash',
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'EasyPaisa / JazzCash', child: Text('EasyPaisa / JazzCash')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => paymentMethod = val);
                    },
                  ),
                  if (paymentMethod == 'Other') ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Specify Payment Method',
                      controller: otherMethodController,
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Reference / Slip # (Optional)',
                  controller: refController,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Note / Remarks (Optional)',
                  controller: noteController,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountPaisa <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount greater than 0')),
                  );
                  return;
                }

                Navigator.pop(dlgCtx);
                await repo.updateTransaction(
                  id: tx.id,
                  customerId: cust.id,
                  date: date,
                  amountPaisa: amountPaisa,
                  type: tx.type,
                  paymentMethod: tx.type == 'payment' ? paymentMethod : null,
                  otherPaymentMethod: tx.type == 'payment' && paymentMethod == 'Other'
                      ? otherMethodController.text.trim()
                      : null,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  reference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction updated successfully! Balance updated.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, File file, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            Positioned(
              top: 48,
              left: 70,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
