import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/supplier_repository.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Supplier Payables Ledger'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/suppliers/new'),
        backgroundColor: AppColors.warning,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('New Supplier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchField(
              hint: 'Search supplier name, company, phone...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
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
                  final nameMatch = s.supplier.name.toLowerCase().contains(_searchQuery);
                  final phoneMatch = s.supplier.phone.toLowerCase().contains(_searchQuery);
                  final companyMatch = (s.supplier.company ?? '').toLowerCase().contains(_searchQuery);
                  return nameMatch || phoneMatch || companyMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: _searchQuery.isNotEmpty ? 'No supplier found' : 'No Suppliers Added Yet',
                    description: _searchQuery.isNotEmpty
                        ? 'Try searching by a different name or phone number'
                        : 'Add medicine distributors and suppliers to track payable bills.',
                    actionLabel: _searchQuery.isEmpty ? 'Add Supplier' : null,
                    onAction: _searchQuery.isEmpty ? () => context.push('/suppliers/new') : null,
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
    );
  }
}
