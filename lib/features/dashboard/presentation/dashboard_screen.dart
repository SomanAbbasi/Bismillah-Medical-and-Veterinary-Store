import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_provider.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/expiry_reminder_scheduler.dart';
import '../../../core/reports/pdf_report_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/quick_action_sheet.dart';
import '../../../core/permissions/permission_manager.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  String _shopName = 'BismillahStore';
  bool _isNotificationDisabled = false;
  bool _isBatteryOptimizationActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShopName();
    _checkNotificationStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseProvider);
      ref.read(expiryReminderSchedulerProvider).reconcile(db);
      PermissionManager.checkAndPromptPermissions(context, ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
      final db = ref.read(databaseProvider);
      ref.read(expiryReminderSchedulerProvider).reconcile(db);
    }
  }

  Future<void> _checkNotificationStatus() async {
    final isGranted = await PermissionManager.areNotificationsGranted(ref);
    final isBatteryExempt = await PermissionManager.isIgnoringBatteryOptimizations(ref);
    if (mounted) {
      setState(() {
        _isNotificationDisabled = !isGranted;
        _isBatteryOptimizationActive = !isBatteryExempt;
      });
    }
  }

  Future<void> _loadShopName() async {
    final db = ref.read(databaseProvider);
    final name = await db.getSetting('shop_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _shopName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 38,
                  height: 38,
                  color: AppColors.primarySubtle,
                  child: const Icon(Icons.local_hospital, color: AppColors.primary, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shopName,
                    style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormatter.formatShortDate(DateTime.now()),
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Export Daily PDF Report",
            onPressed: () async {
              final summary = summaryAsync.valueOrNull;
              if (summary != null) {
                final shopProfile = await ref.read(shopProfileProvider.future);
                await PdfReportService.printExecutiveSummary(
                  shop: shopProfile,
                  summary: summary,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Recycle Bin (Trash)',
            onPressed: () => context.push('/trash'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Global Search',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          await _loadShopName();
        },
        child: summaryAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Failed to load dashboard', style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(err.toString(), style: AppTypography.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(dashboardSummaryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (summary) {
            return ListView(
              padding: AppSpacing.pagePadding,
              children: [
                if (_isNotificationDisabled) ...[
                  InkWell(
                    borderRadius: AppRadii.roundedMd,
                    onTap: () async {
                      final notifService = ref.read(notificationServiceProvider);
                      await notifService.requestNotificationPermission();
                      final granted = await notifService.areNotificationsEnabled();
                      if (!granted) {
                        await notifService.openNotificationSettings();
                      }
                      await _checkNotificationStatus();
                      final db = ref.read(databaseProvider);
                      await ref.read(expiryReminderSchedulerProvider).reconcile(db, forceReschedule: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expiry Notifications Disabled',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Tap here to enable notifications and protect stock.',
                                  style: TextStyle(color: AppColors.danger, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (!_isNotificationDisabled && _isBatteryOptimizationActive) ...[
                  InkWell(
                    borderRadius: AppRadii.roundedMd,
                    onTap: () async {
                      final notifService = ref.read(notificationServiceProvider);
                      await notifService.openBatteryOptimizationSettings();
                      await _checkNotificationStatus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.battery_alert_outlined, color: AppColors.warning, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Battery Optimization Restricting Alarms',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Tap here to allow Unrestricted background activity so reminders ring on time.',
                                  style: TextStyle(color: AppColors.warning, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.warning),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Quick Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickActionButton(
                        icon: Icons.point_of_sale,
                        label: 'Sale',
                        color: AppColors.primary,
                        onTap: () => context.push('/sales/new'),
                      ),
                      _QuickActionButton(
                        icon: Icons.receipt_long,
                        label: 'Expense',
                        color: AppColors.warning,
                        onTap: () => context.push('/expenses/new'),
                      ),
                      _QuickActionButton(
                        icon: Icons.account_balance_wallet,
                        label: 'Customer',
                        color: AppColors.danger,
                        onTap: () => context.go('/customers?tab=customer'),
                      ),
                      _QuickActionButton(
                        icon: Icons.local_shipping,
                        label: 'Supplier',
                        color: AppColors.purple,
                        onTap: () => context.go('/customers?tab=supplier'),
                      ),
                      _QuickActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'More',
                        color: AppColors.purple,
                        onTap: () => QuickActionSheet.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Financial & Expiry Overview
                SectionHeader(
                  title: "Today's Performance",
                  actionLabel: 'PDF Summary',
                  onAction: () async {
                    final shopProfile = await ref.read(shopProfileProvider.future);
                    await PdfReportService.printExecutiveSummary(
                      shop: shopProfile,
                      summary: summary,
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: "Today's Sales",
                        value: CurrencyFormatter.formatPaisa(summary.todaySalesPaisa),
                        icon: Icons.trending_up,
                        accentColor: AppColors.primary,
                        onTap: () => context.go('/sales-expenses?tab=sales'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        title: "Today's Expenses",
                        value: CurrencyFormatter.formatPaisa(summary.todayExpensesPaisa),
                        icon: Icons.trending_down,
                        accentColor: AppColors.warning,
                        onTap: () => context.go('/sales-expenses?tab=expenses'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MetricCard(
                  title: "Today's Net Sales (Profit)",
                  value: CurrencyFormatter.formatPaisa(summary.todayNetPaisa),
                  subtitle: summary.todayNetPaisa >= 0
                      ? "Sales exceed operational expenses today"
                      : "Expenses exceeded sales today",
                  icon: Icons.savings_outlined,
                  accentColor: summary.todayNetPaisa >= 0 ? AppColors.success : AppColors.danger,
                  onTap: () => context.go('/sales-expenses'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        title: "Customer Udhaar",
                        value: CurrencyFormatter.formatPaisa(summary.customerOutstandingPaisa),
                        subtitle: "Receivable from customers",
                        icon: Icons.account_balance_wallet,
                        accentColor: AppColors.danger,
                        onTap: () => context.go('/customers?tab=customer'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: MetricCard(
                        title: "Supplier Debt",
                        value: CurrencyFormatter.formatPaisa(summary.supplierOutstandingPaisa),
                        subtitle: "Payable to distributors",
                        icon: Icons.local_shipping_outlined,
                        accentColor: AppColors.warning,
                        onTap: () => context.go('/customers?tab=supplier'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MetricCard(
                  title: "Medicine Expiry Alerts",
                  value: '${summary.expiredMedicinesCount + summary.expiringSoonMedicinesCount}',
                  subtitle: '${summary.expiredMedicinesCount} already expired • ${summary.expiringSoonMedicinesCount} expiring soon',
                  icon: Icons.warning_amber_rounded,
                  accentColor: (summary.expiredMedicinesCount + summary.expiringSoonMedicinesCount) > 0
                      ? AppColors.danger
                      : AppColors.success,
                  onTap: () => context.push('/expiry'),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Expiry Alerts List
                if (summary.topExpiringMedicines.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Near Expiry & Expired Medicines',
                    actionLabel: 'View All',
                    onAction: () => context.push('/expiry'),
                  ),
                  ...summary.topExpiringMedicines.take(4).map((med) {
                    final isExpired = med.expiryDate.isBefore(DateFormatter.today());

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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isExpired ? AppColors.dangerLight : AppColors.warningLight,
                              borderRadius: AppRadii.roundedSm,
                            ),
                            child: Icon(
                              isExpired ? Icons.cancel : Icons.access_time,
                              color: isExpired ? AppColors.danger : AppColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.name, style: AppTypography.labelLarge),
                                Text(
                                  'Expiry: ${DateFormatter.formatDate(med.expiryDate)} • ${med.category}',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: isExpired ? 'Expired' : ExpiryUtils.getHumanRemainingText(med.expiryDate),
                            type: isExpired ? StatusType.critical : StatusType.warning,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Overdue Customer Balances
                if (summary.topOverdueCustomers.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Highest Customer Udhaar Balances',
                    actionLabel: 'View Ledger',
                    onAction: () => context.go('/customers'),
                  ),
                  ...summary.topOverdueCustomers.take(4).map((custWithBal) {
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(custWithBal.customer.name, style: AppTypography.labelLarge),
                                Text(custWithBal.customer.phone, style: AppTypography.bodySmall),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.formatPaisa(custWithBal.balancePaisa),
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text('Outstanding Balance', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 14),
                            onPressed: () => context.push('/customers/${custWithBal.customer.id}'),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.roundedMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadii.roundedMd,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
