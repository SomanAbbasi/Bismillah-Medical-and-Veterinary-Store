import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../customers/data/customer_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../sales/data/sales_repository.dart';

enum ReportPeriod { today, thisWeek, thisMonth, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.thisMonth;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    final todayMidnight = DateFormatter.today();
    final endOfToday = todayMidnight.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_period) {
      case ReportPeriod.today:
        return (todayMidnight, endOfToday);
      case ReportPeriod.thisWeek:
        final startOfWeek = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
        return (startOfWeek, endOfToday);
      case ReportPeriod.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (startOfMonth, endOfToday);
      case ReportPeriod.custom:
        return (DateFormatter.toDateOnly(_customStart), DateFormatter.toDateOnly(_customEnd).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();

    final salesRepo = ref.watch(salesRepositoryProvider);
    final expenseRepo = ref.watch(expenseRepositoryProvider);
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Reports & Financials'),
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          // Period Selector Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.roundedMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _PeriodTab(
                  label: 'Today',
                  isSelected: _period == ReportPeriod.today,
                  onTap: () => setState(() => _period = ReportPeriod.today),
                ),
                _PeriodTab(
                  label: 'Week',
                  isSelected: _period == ReportPeriod.thisWeek,
                  onTap: () => setState(() => _period = ReportPeriod.thisWeek),
                ),
                _PeriodTab(
                  label: 'Month',
                  isSelected: _period == ReportPeriod.thisMonth,
                  onTap: () => setState(() => _period = ReportPeriod.thisMonth),
                ),
                _PeriodTab(
                  label: 'Custom',
                  isSelected: _period == ReportPeriod.custom,
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
                    );
                    if (picked != null) {
                      setState(() {
                        _customStart = picked.start;
                        _customEnd = picked.end;
                        _period = ReportPeriod.custom;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Date label
          Text(
            'Report Range: ${DateFormatter.formatDate(startDate)} to ${DateFormatter.formatDate(endDate)}',
            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),

          // FutureBuilder for Sales & Expenses
          FutureBuilder<(List<dynamic>, List<dynamic>)>(
            future: Future.wait([
              salesRepo.getSalesForRange(startDate, endDate),
              expenseRepo.getExpensesForRange(startDate, endDate),
            ]).then((results) => (results[0], results[1])),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final (sales, expenses) = snapshot.data ?? ([], []);

              final totalSalesPaisa = sales.fold<int>(0, (sum, s) => sum + (s.finalAmountPaisa as int));
              final totalExpensesPaisa = expenses.fold<int>(0, (sum, e) => sum + (e.amountPaisa as int));
              final netSalesAfterExpensesPaisa = totalSalesPaisa - totalExpensesPaisa;

              // Category breakdown
              final Map<String, int> expensesByCategory = {};
              for (final e in expenses) {
                final cat = (e.category ?? 'General') as String;
                final amt = e.amountPaisa as int;
                expensesByCategory[cat] = (expensesByCategory[cat] ?? 0) + amt;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Core Financials
                  const SectionHeader(title: 'Sales & Expenses Summary'),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Total Sales',
                          value: CurrencyFormatter.formatPaisa(totalSalesPaisa),
                          subtitle: '${sales.length} sale entry(s)',
                          icon: Icons.trending_up,
                          accentColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MetricCard(
                          title: 'Total Expenses',
                          value: CurrencyFormatter.formatPaisa(totalExpensesPaisa),
                          subtitle: '${expenses.length} expense items',
                          icon: Icons.trending_down,
                          accentColor: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MetricCard(
                    title: 'Net Sales After Expenses',
                    value: CurrencyFormatter.formatPaisa(netSalesAfterExpensesPaisa),
                    subtitle: netSalesAfterExpensesPaisa >= 0
                        ? 'Sales exceed operational expenses'
                        : 'Operational expenses exceeded sales for this period',
                    icon: Icons.account_balance_wallet,
                    accentColor: netSalesAfterExpensesPaisa >= 0 ? AppColors.success : AppColors.danger,
                  ),

                  // Category Breakdown
                  if (expensesByCategory.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(title: 'Expenses by Category'),
                    Container(
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.roundedLg,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: expensesByCategory.entries.map((entry) {
                          final percent = totalExpensesPaisa > 0
                              ? ((entry.value / totalExpensesPaisa) * 100).toStringAsFixed(1)
                              : '0';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${entry.key} ($percent%)', style: AppTypography.bodyMedium),
                                Text(
                                  CurrencyFormatter.formatPaisa(entry.value),
                                  style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Ledger Summaries
          const SectionHeader(title: 'Customer Ledger Balance'),
          customersAsync.when(
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
            data: (customers) {
              final outstandingCredit = customers
                  .where((c) => c.balancePaisa > 0)
                  .fold(0, (sum, c) => sum + c.balancePaisa);

              return MetricCard(
                title: 'Total Outstanding Customer Credit (Udhar)',
                value: CurrencyFormatter.formatPaisa(outstandingCredit),
                subtitle: 'Store Receivables owed by customers',
                icon: Icons.people_outline,
                accentColor: AppColors.danger,
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Inventory Valuation & Health
          medicinesAsync.when(
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
            data: (medicines) {
              final totalItems = medicines.length;
              final expiredItems = medicines.where((m) => m.expiryDate.isBefore(DateFormatter.today())).length;

              return Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventory Summary', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Registered Medicines:', style: AppTypography.bodyMedium),
                        Text('$totalItems items', style: AppTypography.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expired Medicines:', style: AppTypography.bodyMedium),
                        Text(
                          '$expiredItems items',
                          style: AppTypography.labelLarge.copyWith(
                            color: expiredItems > 0 ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.roundedSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadii.roundedSm,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
