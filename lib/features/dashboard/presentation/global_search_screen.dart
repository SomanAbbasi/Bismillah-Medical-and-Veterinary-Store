import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/search_field.dart';
import '../../customers/data/customer_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../suppliers/data/supplier_repository.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesWithBatchesStreamProvider);
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Search'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchField(
              hint: 'Search medicines, generics, customers, suppliers...',
              onChanged: (val) => setState(() => _query = val.toLowerCase().trim()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query.isEmpty
                ? const Center(
                    child: Text(
                      'Type above to search across medicines, batches, customers, and suppliers',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    padding: AppSpacing.pagePadding,
                    children: [
                      // Medicines matching
                      medicinesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox(),
                        data: (medicines) {
                          final matchingMeds = medicines.where((m) {
                            final nameMatch = m.medicine.name.toLowerCase().contains(_query);
                            final genMatch = m.medicine.genericName.toLowerCase().contains(_query);
                            final brandMatch = m.medicine.brand.toLowerCase().contains(_query);
                            final batchMatch = m.batches.any((b) => b.batchNumber.toLowerCase().contains(_query));
                            return nameMatch || genMatch || brandMatch || batchMatch;
                          }).toList();

                          if (matchingMeds.isEmpty) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Medicines (${matchingMeds.length})', style: AppTypography.heading3),
                              const SizedBox(height: AppSpacing.sm),
                              ...matchingMeds.map((m) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: AppRadii.roundedMd,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.medication, color: AppColors.primary),
                                    title: Text(m.medicine.name, style: AppTypography.labelLarge),
                                    subtitle: Text(
                                      '${m.medicine.genericName.isNotEmpty ? "${m.medicine.genericName} • " : ""}${m.availableStock} ${m.medicine.unit}s available',
                                      style: AppTypography.bodySmall,
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () => context.push('/inventory/${m.medicine.id}'),
                                  ),
                                );
                              }),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          );
                        },
                      ),

                      // Customers matching
                      customersAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, _) => const SizedBox(),
                        data: (customers) {
                          final matchingCust = customers.where((c) {
                            final nameMatch = c.customer.name.toLowerCase().contains(_query);
                            final phoneMatch = c.customer.phone.toLowerCase().contains(_query);
                            return nameMatch || phoneMatch;
                          }).toList();

                          if (matchingCust.isEmpty) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customers (${matchingCust.length})', style: AppTypography.heading3),
                              const SizedBox(height: AppSpacing.sm),
                              ...matchingCust.map((c) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: AppRadii.roundedMd,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_outline, color: AppColors.purple),
                                    title: Text(c.customer.name, style: AppTypography.labelLarge),
                                    subtitle: Text('${c.customer.phone} • Balance: ${CurrencyFormatter.formatPaisa(c.balancePaisa)}', style: AppTypography.bodySmall),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () => context.push('/customers/${c.customer.id}'),
                                  ),
                                );
                              }),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          );
                        },
                      ),

                      // Suppliers matching
                      suppliersAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, _) => const SizedBox(),
                        data: (suppliers) {
                          final matchingSup = suppliers.where((s) {
                            final nameMatch = s.supplier.name.toLowerCase().contains(_query);
                            final compMatch = (s.supplier.company ?? '').toLowerCase().contains(_query);
                            final phoneMatch = s.supplier.phone.toLowerCase().contains(_query);
                            return nameMatch || compMatch || phoneMatch;
                          }).toList();

                          if (matchingSup.isEmpty) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Suppliers (${matchingSup.length})', style: AppTypography.heading3),
                              const SizedBox(height: AppSpacing.sm),
                              ...matchingSup.map((s) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: AppRadii.roundedMd,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryLight),
                                    title: Text(s.supplier.name, style: AppTypography.labelLarge),
                                    subtitle: Text('${s.supplier.company ?? "Direct"} • ${s.supplier.phone}', style: AppTypography.bodySmall),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                    onTap: () => context.push('/suppliers/${s.supplier.id}'),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
