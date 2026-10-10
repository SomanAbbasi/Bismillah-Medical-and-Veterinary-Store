import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
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

  int _globalDefaultMonths = 1;
  int? _nearExpiryDaysFilter; // null = use setting default, 15, 30, 60, 90, 180, -1 = custom
  DateTime? _customNearExpiryDate;

  int? _expiredDaysFilter; // null = all expired, 30, 90, 365, -1 = custom
  DateTime? _customExpiredDate;

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

    _loadGlobalSetting();
  }

  Future<void> _loadGlobalSetting() async {
    final db = ref.read(databaseProvider);
    final setting = await db.getSetting('default_reminder_months');
    if (setting != null && mounted) {
      setState(() {
        _globalDefaultMonths = int.tryParse(setting) ?? 1;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomNearDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customNearExpiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Select Near Expiry Cutoff Date',
    );
    if (picked != null && mounted) {
      setState(() {
        _nearExpiryDaysFilter = -1;
        _customNearExpiryDate = picked;
      });
    }
  }

  Future<void> _pickCustomExpiredDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customExpiredDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Show Medicines Expired After Date',
    );
    if (picked != null && mounted) {
      setState(() {
        _expiredDaysFilter = -1;
        _customExpiredDate = picked;
      });
    }
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
          duration: const Duration(seconds: 2),
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
                    hintText: 'Search medicine, batch, formula or brand...',
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
                    _buildNearExpiryTab(allMedicines),
                    _buildExpiredTab(allMedicines),
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

  Widget _buildNearExpiryTab(List<Medicine> allMedicines) {
    return Column(
      children: [
        // Filter options for Near Expiry
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Store Alert (${_globalDefaultMonths * 30} Days)',
                isSelected: _nearExpiryDaysFilter == null,
                onSelected: () => setState(() => _nearExpiryDaysFilter = null),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '15 Days',
                isSelected: _nearExpiryDaysFilter == 15,
                onSelected: () => setState(() => _nearExpiryDaysFilter = 15),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '30 Days',
                isSelected: _nearExpiryDaysFilter == 30,
                onSelected: () => setState(() => _nearExpiryDaysFilter = 30),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '60 Days',
                isSelected: _nearExpiryDaysFilter == 60,
                onSelected: () => setState(() => _nearExpiryDaysFilter = 60),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '90 Days',
                isSelected: _nearExpiryDaysFilter == 90,
                onSelected: () => setState(() => _nearExpiryDaysFilter = 90),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: '6 Months',
                isSelected: _nearExpiryDaysFilter == 180,
                onSelected: () => setState(() => _nearExpiryDaysFilter = 180),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: _customNearExpiryDate != null
                    ? 'Until ${DateFormatter.formatDate(_customNearExpiryDate!)} 📅'
                    : 'Custom Date 📅',
                isSelected: _nearExpiryDaysFilter == -1,
                onSelected: _pickCustomNearDate,
              ),
            ],
          ),
        ),
        Expanded(child: _buildMedicineListView(allMedicines, filterType: 'near_expiry')),
      ],
    );
  }

  Widget _buildExpiredTab(List<Medicine> allMedicines) {
    return Column(
      children: [
        // Filter options for Expired
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All Expired',
                isSelected: _expiredDaysFilter == null,
                onSelected: () => setState(() => _expiredDaysFilter = null),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Past 30 Days',
                isSelected: _expiredDaysFilter == 30,
                onSelected: () => setState(() => _expiredDaysFilter = 30),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Past 90 Days',
                isSelected: _expiredDaysFilter == 90,
                onSelected: () => setState(() => _expiredDaysFilter = 90),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Past 1 Year',
                isSelected: _expiredDaysFilter == 365,
                onSelected: () => setState(() => _expiredDaysFilter = 365),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: _customExpiredDate != null
                    ? 'After ${DateFormatter.formatDate(_customExpiredDate!)} 📅'
                    : 'Custom Date 📅',
                isSelected: _expiredDaysFilter == -1,
                onSelected: _pickCustomExpiredDate,
              ),
            ],
          ),
        ),
        Expanded(child: _buildMedicineListView(allMedicines, filterType: 'expired')),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }

  Widget _buildMedicineListView(List<Medicine> allMedicines, {required String filterType}) {
    final today = DateFormatter.today();

    var filtered = allMedicines.where((m) {
      if (_searchQuery.isNotEmpty) {
        final nameMatch = m.name.toLowerCase().contains(_searchQuery);
        final brandMatch = m.brand.toLowerCase().contains(_searchQuery);
        final catMatch = m.category.toLowerCase().contains(_searchQuery);
        final batchMatch = (m.batchNumber ?? '').toLowerCase().contains(_searchQuery);
        final formulaMatch = m.genericName.toLowerCase().contains(_searchQuery);
        if (!nameMatch && !brandMatch && !catMatch && !batchMatch && !formulaMatch) return false;
      }

      if (filterType == 'drafts') {
        return m.isDraft;
      }
      if (m.isDraft) return false;

      final isExpired = m.expiryDate.isBefore(today);

      if (filterType == 'expired') {
        if (!isExpired) return false;
        if (_expiredDaysFilter == 30) {
          final cutoff = today.subtract(const Duration(days: 30));
          return m.expiryDate.isAfter(cutoff);
        } else if (_expiredDaysFilter == 90) {
          final cutoff = today.subtract(const Duration(days: 90));
          return m.expiryDate.isAfter(cutoff);
        } else if (_expiredDaysFilter == 365) {
          final cutoff = today.subtract(const Duration(days: 365));
          return m.expiryDate.isAfter(cutoff);
        } else if (_expiredDaysFilter == -1 && _customExpiredDate != null) {
          return m.expiryDate.isAfter(_customExpiredDate!);
        }
        return true;
      }

      if (filterType == 'near_expiry') {
        if (isExpired) return false;

        if (_nearExpiryDaysFilter == -1 && _customNearExpiryDate != null) {
          return m.expiryDate.isBefore(_customNearExpiryDate!) ||
              m.expiryDate.isAtSameMomentAs(_customNearExpiryDate!);
        }

        final daysWindow = _nearExpiryDaysFilter ??
            (m.reminderLeadDays ?? (m.reminderMonths != null ? m.reminderMonths! * 30 : _globalDefaultMonths * 30));
        final cutoff = today.add(Duration(days: daysWindow));
        return m.expiryDate.isBefore(cutoff) || m.expiryDate.isAtSameMomentAs(cutoff);
      }

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            med.name,
                            style: AppTypography.labelLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (med.batchNumber != null && med.batchNumber!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: Text(
                              'Batch: ${med.batchNumber}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Expiry: ${DateFormatter.formatDate(med.expiryDate)} • ${med.category}${med.brand.isNotEmpty ? " • ${med.brand}" : ""}',
                      style: AppTypography.bodySmall,
                    ),
                    if (med.genericName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Formula: ${med.genericName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (med.notes != null && med.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        med.notes!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                      ),
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
