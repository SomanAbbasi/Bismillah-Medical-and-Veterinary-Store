import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/expiry_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/data/inventory_repository.dart';

class ExpiryManagementScreen extends ConsumerStatefulWidget {
  const ExpiryManagementScreen({super.key});

  @override
  ConsumerState<ExpiryManagementScreen> createState() => _ExpiryManagementScreenState();
}

class _ExpiryManagementScreenState extends ConsumerState<ExpiryManagementScreen> {
  String _searchQuery = '';
  // Near-expiry filter preset: 'default', '30d', '60d', '90d', '180d', '365d', 'custom'
  String _filterPreset = 'default';
  DateTime? _customCutoffDate;

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesStreamProvider);
    final db = ref.watch(databaseProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Medicine Expiry Alerts'),
          actions: [
            IconButton(
              icon: const Icon(Icons.volume_up_outlined),
              tooltip: 'Test Sound Notification',
              onPressed: () async {
                await ref.read(notificationServiceProvider).testSoundNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔔 System notification sound triggered! Check status bar.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'Expiring Soon'),
              Tab(text: 'Expired Medicines'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search field
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                hint: 'Search medicine name, brand, category...',
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
              ),
            ),

            // Filter Presets & Custom Date Picker
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Window: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('Store Default'),
                      selected: _filterPreset == 'default',
                      onSelected: (_) => setState(() => _filterPreset = 'default'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Next 30 Days'),
                      selected: _filterPreset == '30d',
                      onSelected: (_) => setState(() => _filterPreset = '30d'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Next 60 Days'),
                      selected: _filterPreset == '60d',
                      onSelected: (_) => setState(() => _filterPreset = '60d'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Next 90 Days'),
                      selected: _filterPreset == '90d',
                      onSelected: (_) => setState(() => _filterPreset = '90d'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Next 6 Months'),
                      selected: _filterPreset == '180d',
                      onSelected: (_) => setState(() => _filterPreset = '180d'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(
                        _customCutoffDate != null
                            ? 'Before: ${DateFormatter.formatShortDate(_customCutoffDate!)}'
                            : 'Custom Date...',
                      ),
                      selected: _filterPreset == 'custom',
                      onSelected: (_) async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customCutoffDate ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setState(() {
                            _customCutoffDate = picked;
                            _filterPreset = 'custom';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: medicinesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (medicines) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);

                  return FutureBuilder<String?>(
                    future: db.getSetting('default_reminder_months'),
                    builder: (context, settingSnap) {
                      final defaultMonths = settingSnap.data != null ? (int.tryParse(settingSnap.data!) ?? 1) : 1;

                      // Calculate cutoff date for "expiring soon"
                      DateTime cutoffDate;
                      if (_filterPreset == '30d') {
                        cutoffDate = today.add(const Duration(days: 30));
                      } else if (_filterPreset == '60d') {
                        cutoffDate = today.add(const Duration(days: 60));
                      } else if (_filterPreset == '90d') {
                        cutoffDate = today.add(const Duration(days: 90));
                      } else if (_filterPreset == '180d') {
                        cutoffDate = today.add(const Duration(days: 180));
                      } else if (_filterPreset == 'custom' && _customCutoffDate != null) {
                        cutoffDate = DateTime(
                          _customCutoffDate!.year,
                          _customCutoffDate!.month,
                          _customCutoffDate!.day,
                          23,
                          59,
                          59,
                        );
                      } else {
                        // Store default
                        cutoffDate = today.add(Duration(days: defaultMonths * 30));
                      }

                      // Expired medicines: expiryDate is before today
                      final expired = medicines.where((m) {
                        if (m.isDraft) return false;
                        final isExp = m.expiryDate.isBefore(today);
                        if (!isExp) return false;
                        if (_searchQuery.isNotEmpty) {
                          final match = m.name.toLowerCase().contains(_searchQuery) ||
                              m.brand.toLowerCase().contains(_searchQuery) ||
                              m.category.toLowerCase().contains(_searchQuery);
                          return match;
                        }
                        return true;
                      }).toList()..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                      // Expiring soon: expiryDate is on or after today, and before cutoffDate
                      final expiringSoon = medicines.where((m) {
                        if (m.isDraft) return false;
                        final isNotExpired = !m.expiryDate.isBefore(today);
                        if (!isNotExpired) return false;

                        // Check window
                        bool inWindow = false;
                        if (_filterPreset == 'default') {
                          final threshold = m.reminderMonths ?? defaultMonths;
                          inWindow = ExpiryUtils.isInReminderWindow(m.expiryDate, threshold, referenceDate: today);
                        } else {
                          inWindow = m.expiryDate.isBefore(cutoffDate) || m.expiryDate.isAtSameMomentAs(cutoffDate);
                        }

                        if (!inWindow) return false;

                        if (_searchQuery.isNotEmpty) {
                          final match = m.name.toLowerCase().contains(_searchQuery) ||
                              m.brand.toLowerCase().contains(_searchQuery) ||
                              m.category.toLowerCase().contains(_searchQuery);
                          return match;
                        }
                        return true;
                      }).toList()..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                      return TabBarView(
                        children: [
                          _ExpiryMedicineList(
                            items: expiringSoon,
                            emptyTitle: 'No Medicines Expiring Soon',
                            emptyDesc: _searchQuery.isNotEmpty
                                ? 'No matching medicines found.'
                                : 'No medicines are expiring within the selected window.',
                          ),
                          _ExpiryMedicineList(
                            items: expired,
                            emptyTitle: 'No Expired Medicines',
                            emptyDesc: _searchQuery.isNotEmpty
                                ? 'No matching medicines found.'
                                : 'All medicines in stock are fresh and non-expired!',
                            isExpiredTab: true,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryMedicineList extends ConsumerWidget {
  final List<Medicine> items;
  final String emptyTitle;
  final String emptyDesc;
  final bool isExpiredTab;

  const _ExpiryMedicineList({
    required this.items,
    required this.emptyTitle,
    required this.emptyDesc,
    this.isExpiredTab = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: emptyTitle,
        description: emptyDesc,
      );
    }

    final repo = ref.watch(inventoryRepositoryProvider);

    return ListView.builder(
      padding: AppSpacing.pagePadding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final med = items[index];
        final humanText = ExpiryUtils.getHumanRemainingText(med.expiryDate);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.roundedMd,
            border: Border.all(color: isExpiredTab ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpiredTab ? AppColors.dangerLight : AppColors.warningLight,
                  borderRadius: AppRadii.roundedMd,
                ),
                child: Icon(
                  isExpiredTab ? Icons.cancel_outlined : Icons.access_time_filled,
                  color: isExpiredTab ? AppColors.danger : AppColors.warning,
                  size: 22,
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
                          child: Text(med.name, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis),
                        ),
                        if (med.batchNumber != null && med.batchNumber!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: Text(
                              'Batch: ${med.batchNumber}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Expiry: ${DateFormatter.formatDate(med.expiryDate)}${med.brand.isNotEmpty ? " • ${med.brand}" : ""}',
                      style: AppTypography.bodySmall,
                    ),
                    if (med.isReminderDisabled) ...[
                      const SizedBox(height: 2),
                      const Text('Alerts Disabled', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: isExpiredTab ? 'Expired' : humanText,
                    type: isExpiredTab ? StatusType.critical : StatusType.warning,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          med.isReminderDisabled ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                          size: 18,
                          color: med.isReminderDisabled ? AppColors.textMuted : AppColors.primary,
                        ),
                        tooltip: med.isReminderDisabled ? 'Enable Alerts' : 'Turn Off Alerts',
                        onPressed: () async {
                          await repo.setReminderDisabled(med.id, !med.isReminderDisabled);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  med.isReminderDisabled ? 'Alerts re-enabled' : 'Expiry alerts turned off for ${med.name}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Expiry Date & Info',
                        onPressed: () => context.push('/inventory/${med.id}/edit'),
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
