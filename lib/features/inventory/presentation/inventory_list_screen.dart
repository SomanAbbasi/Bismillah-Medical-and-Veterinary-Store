import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/inventory_repository.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const InventoryListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (widget.initialFilter == 'expiring_soon') {
      _tabController.animateTo(1);
    } else if (widget.initialFilter == 'expired') {
      _tabController.animateTo(2);
    } else if (widget.initialFilter == 'drafts') {
      _tabController.animateTo(3);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteMedicine(Medicine medicine) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Move to Recycle Bin?',
      message: 'Delete "${medicine.name}"? It will stay in the 30-day Recycle Bin and can be restored anytime.',
      confirmLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final repo = ref.read(inventoryRepositoryProvider);
    await repo.softDeleteMedicine(medicine.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${medicine.name}" moved to Recycle Bin.'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await repo.restoreMedicine(medicine.id);
            },
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medicines & Expiry'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Near Expiry'),
            Tab(text: 'Expired'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/new'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: medicinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allMedicines) {
          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search medicine by name, brand or category...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.roundedMd,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMedicineListView(allMedicines, filterType: 'all'),
                    _buildMedicineListView(allMedicines, filterType: 'near_expiry'),
                    _buildMedicineListView(allMedicines, filterType: 'expired'),
                    _buildMedicineListView(allMedicines, filterType: 'drafts'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedicineListView(List<Medicine> allMedicines, {required String filterType}) {
    final today = DateFormatter.today();

    var filtered = allMedicines.where((m) {
      if (_searchQuery.isNotEmpty) {
        final nameMatch = m.name.toLowerCase().contains(_searchQuery);
        final brandMatch = m.brand.toLowerCase().contains(_searchQuery);
        final catMatch = m.category.toLowerCase().contains(_searchQuery);
        if (!nameMatch && !brandMatch && !catMatch) return false;
      }

      if (filterType == 'drafts') {
        return m.isDraft;
      }
      if (m.isDraft) return false;

      final isExpired = m.expiryDate.isBefore(today);
      final isNear = ExpiryUtils.isInReminderWindow(m.expiryDate, m.reminderMonths ?? 1, referenceDate: today);

      if (filterType == 'expired') return isExpired;
      if (filterType == 'near_expiry') return isNear && !isExpired;

      return true;
    }).toList();

    filtered.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.medication_outlined,
        title: filterType == 'expired'
            ? 'No Expired Medicines'
            : filterType == 'near_expiry'
                ? 'No Near Expiry Alerts'
                : filterType == 'drafts'
                    ? 'No Draft Medicines'
                    : 'No Medicines Added',
        description: filterType == 'all'
            ? 'Add medicines with their expiry dates to receive automatic alerts.'
            : 'All medicines in this category are clear.',
        actionLabel: 'Add Medicine',
        onAction: () => context.push('/inventory/new'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final med = filtered[index];
        final isExpired = med.expiryDate.isBefore(today);
        final humanText = ExpiryUtils.getHumanRemainingText(med.expiryDate);

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
                  color: isExpired ? AppColors.dangerLight : AppColors.primarySubtle,
                  borderRadius: AppRadii.roundedMd,
                ),
                child: Icon(
                  isExpired ? Icons.cancel_outlined : Icons.medication,
                  color: isExpired ? AppColors.danger : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: AppTypography.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Expiry: ${DateFormatter.formatDate(med.expiryDate)}${med.brand.isNotEmpty ? " • ${med.brand}" : ""}',
                      style: AppTypography.bodySmall,
                    ),
                    if (med.notes != null && med.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(med.notes!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted), maxLines: 1),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: isExpired ? 'Expired' : humanText,
                    type: isExpired ? StatusType.critical : StatusType.warning,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => context.push('/inventory/${med.id}/edit'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => _handleDeleteMedicine(med),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
