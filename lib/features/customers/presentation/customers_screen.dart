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

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Credit Ledger'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        backgroundColor: AppColors.purple,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchField(
              hint: 'Search customer name, phone number...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
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
                  final nameMatch = c.customer.name.toLowerCase().contains(_searchQuery);
                  final phoneMatch = c.customer.phone.toLowerCase().contains(_searchQuery);
                  return nameMatch || phoneMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: _searchQuery.isNotEmpty ? 'No customer found' : 'No Customers Added Yet',
                    description: _searchQuery.isNotEmpty
                        ? 'Try searching by a different name or phone number'
                        : 'Add customers to track credit (udhar) and payment ledger.',
                    actionLabel: _searchQuery.isEmpty ? 'Add Customer' : null,
                    onAction: _searchQuery.isEmpty ? () => context.push('/customers/new') : null,
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
    );
  }
}
