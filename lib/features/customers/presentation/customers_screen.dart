import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/customer_repository.dart';
import '../../suppliers/data/supplier_repository.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  final String? initialTab; // 'customer' or 'supplier'

  const CustomersScreen({super.key, this.initialTab});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _customerSearch = '';
  String _supplierSearch = '';

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'supplier' ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      final newIndex = widget.initialTab == 'supplier' ? 1 : 0;
      if (_tabController.index != newIndex) {
        _tabController.animateTo(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);
    final isCustomerTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Ledger & Udhaar'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.people_alt_outlined),
              text: 'Customer Credit',
            ),
            Tab(
              icon: Icon(Icons.local_shipping_outlined),
              text: 'Supplier Payables',
            ),
          ],
        ),
      ),
      floatingActionButton: isCustomerTab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/customers/new'),
              backgroundColor: AppColors.purple,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('New Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push('/suppliers/new'),
              backgroundColor: AppColors.warning,
              icon: const Icon(Icons.add_business, color: Colors.white),
              label: const Text('New Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==================== TAB 1: CUSTOMERS ====================
          Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SearchField(
                  hint: 'Search customer name, phone number...',
                  onChanged: (val) => setState(() => _customerSearch = val.toLowerCase().trim()),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: customersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (customers) {
                    final totalReceivable = customers
                        .where((c) => c.balancePaisa > 0)
                        .fold(0, (sum, c) => sum + c.balancePaisa);

                    final filtered = customers.where((c) {
                      final nameMatch = c.customer.name.toLowerCase().contains(_customerSearch);
                      final phoneMatch = c.customer.phone.toLowerCase().contains(_customerSearch);
                      return nameMatch || phoneMatch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.people_outline,
                        title: _customerSearch.isNotEmpty ? 'No customer found' : 'No Customers Added Yet',
                        description: _customerSearch.isNotEmpty
                            ? 'Try searching by a different name or phone number'
                            : 'Add customers to track credit (udhar) and payment ledger.',
                        actionLabel: _customerSearch.isEmpty ? 'Add Customer' : null,
                        onAction: _customerSearch.isEmpty ? () => context.push('/customers/new') : null,
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        MetricCard(
                          title: 'Total Outstanding Customer Credit',
                          value: CurrencyFormatter.formatPaisa(totalReceivable),
                          subtitle: 'Money currently owed to your medical store',
                          icon: Icons.account_balance_wallet_outlined,
                          accentColor: AppColors.danger,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Customer Accounts (${filtered.length})', style: AppTypography.heading3),
                        const SizedBox(height: AppSpacing.sm),
                        ...filtered.map((item) {
                          final owes = item.owesMoney;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: AppSpacing.cardPadding,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.roundedMd,
                              border: Border.all(
                                color: owes ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => context.push('/customers/${item.customer.id}'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: owes ? AppColors.dangerLight : AppColors.primarySubtle,
                                    foregroundColor: owes ? AppColors.danger : AppColors.primary,
                                    child: Text(
                                      item.customer.name.isNotEmpty
                                          ? item.customer.name[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.customer.name, style: AppTypography.labelLarge),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.customer.phone,
                                          style: AppTypography.bodySmall,
                                        ),
                                        if (item.lastTransactionDate != null)
                                          Text(
                                            'Last activity: ${DateFormatter.formatDate(item.lastTransactionDate)}',
                                            style: AppTypography.bodySmall.copyWith(fontSize: 10),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.formatPaisa(item.balancePaisa),
                                        style: AppTypography.heading3.copyWith(
                                          color: owes ? AppColors.danger : AppColors.success,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      StatusChip(
                                        label: owes ? 'Owes Store' : 'Cleared',
                                        type: owes ? StatusType.critical : StatusType.success,
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
              ),
            ],
          ),

          // ==================== TAB 2: SUPPLIERS ====================
          Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SearchField(
                  hint: 'Search supplier name, company, phone...',
                  onChanged: (val) => setState(() => _supplierSearch = val.toLowerCase().trim()),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: suppliersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (suppliers) {
                    final totalPayable = suppliers
                        .where((s) => s.balancePaisa > 0)
                        .fold(0, (sum, s) => sum + s.balancePaisa);

                    final filtered = suppliers.where((s) {
                      final nameMatch = s.supplier.name.toLowerCase().contains(_supplierSearch);
                      final phoneMatch = s.supplier.phone.toLowerCase().contains(_supplierSearch);
                      final companyMatch = (s.supplier.company ?? '').toLowerCase().contains(_supplierSearch);
                      return nameMatch || phoneMatch || companyMatch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return EmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: _supplierSearch.isNotEmpty ? 'No supplier found' : 'No Suppliers Added Yet',
                        description: _supplierSearch.isNotEmpty
                            ? 'Try searching by a different name or phone number'
                            : 'Add medicine distributors and suppliers to track payable bills.',
                        actionLabel: _supplierSearch.isEmpty ? 'Add Supplier' : null,
                        onAction: _supplierSearch.isEmpty ? () => context.push('/suppliers/new') : null,
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        MetricCard(
                          title: 'Total Outstanding Supplier Payables',
                          value: CurrencyFormatter.formatPaisa(totalPayable),
                          subtitle: 'Total debt currently owed to medicine distributors',
                          icon: Icons.local_shipping_outlined,
                          accentColor: AppColors.warning,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Suppliers (${filtered.length})', style: AppTypography.heading3),
                        const SizedBox(height: AppSpacing.sm),
                        ...filtered.map((item) {
                          final owes = item.owesSupplier;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: AppSpacing.cardPadding,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.roundedMd,
                              border: Border.all(
                                color: owes ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => context.push('/suppliers/${item.supplier.id}'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: owes ? AppColors.warningLight : AppColors.primarySubtle,
                                    foregroundColor: owes ? AppColors.warning : AppColors.primary,
                                    child: Text(
                                      item.supplier.name.isNotEmpty
                                          ? item.supplier.name[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.supplier.name, style: AppTypography.labelLarge),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.supplier.phone}${item.supplier.company != null ? " • ${item.supplier.company}" : ""}',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.formatPaisa(item.balancePaisa),
                                        style: AppTypography.heading3.copyWith(
                                          color: owes ? AppColors.warning : AppColors.success,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      StatusChip(
                                        label: owes ? 'Store Owes' : 'Cleared',
                                        type: owes ? StatusType.warning : StatusType.success,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
