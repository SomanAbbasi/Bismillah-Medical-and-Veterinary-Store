import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import '../data/sample_data_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController(text: 'Bismillah Medical and Veterinary Store');
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();

  int _defaultReminderMonths = 3;
  bool _dailyReminders = true;
  bool _isBiometricsAvailable = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref.read(appLockServiceProvider.notifier).isBiometricsAvailable();
    if (mounted) setState(() => _isBiometricsAvailable = available);
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final shopName = await db.getSetting('shop_name');
    final ownerName = await db.getSetting('owner_name');
    final phone = await db.getSetting('phone');
    final reminderMonths = await db.getSetting('default_reminder_months');
    final daily = await db.getSetting('daily_reminders');

    if (mounted) {
      setState(() {
        if (shopName != null) _shopNameController.text = shopName;
        if (ownerName != null) _ownerNameController.text = ownerName;
        if (phone != null) _phoneController.text = phone;
        if (reminderMonths != null) _defaultReminderMonths = int.tryParse(reminderMonths) ?? 3;
        if (daily != null) _dailyReminders = daily == 'true';
      });
    }
  }

  Future<void> _saveShopProfile() async {
    final db = ref.read(databaseProvider);
    await db.setSetting('shop_name', _shopNameController.text.trim());
    await db.setSetting('owner_name', _ownerNameController.text.trim());
    await db.setSetting('phone', _phoneController.text.trim());
    await db.setSetting('default_reminder_months', _defaultReminderMonths.toString());
    await db.setSetting('daily_reminders', _dailyReminders.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _setupPinDialog() async {
    final pinController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set 4-Digit Security PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, pinController.text.trim()),
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );

    if (result != null && result.length >= 4) {
      await ref.read(appLockServiceProvider.notifier).setPin(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App lock PIN enabled!'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _handleLoadDemoData() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Load Demo Records?',
      message: 'This will add sample medicines (Panadol, Augmentin, Brufen), batches, and ledger records.',
      confirmLabel: 'Load Demo Records',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final db = ref.read(databaseProvider);
    final success = await SampleDataService.populateSampleData(db);

    if (mounted) {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Demo records loaded!' : 'Failed to load demo data'),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleClearAllData() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Clear Store Records?',
      message: 'This will permanently remove medicines, batches, sales, and ledger records.',
      confirmLabel: 'Delete All Records',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final db = ref.read(databaseProvider);
    await db.clearAllData();

    if (mounted) {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All records cleared successfully.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isBusy
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: AppSpacing.pagePadding,
              children: [
                // Store Info
                const SectionHeader(title: 'Store Profile'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Store Name',
                        controller: _shopNameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Save Profile',
                        icon: Icons.check,
                        onPressed: _saveShopProfile,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Expiry Reminders Config
                const SectionHeader(title: 'Expiry Alerts & Sounds'),
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
                      Text(
                        'Remind me before expiry:',
                        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<int>(
                        initialValue: _defaultReminderMonths,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('30 Days (1 Month Before)')),
                          DropdownMenuItem(value: 2, child: Text('60 Days (2 Months Before)')),
                          DropdownMenuItem(value: 3, child: Text('90 Days (3 Months Before)')),
                          DropdownMenuItem(value: 6, child: Text('180 Days (6 Months Before)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _defaultReminderMonths = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Daily Alerts', style: AppTypography.labelLarge),
                        subtitle: const Text('Alert daily until medicine is sold or disposed', style: AppTypography.bodySmall),
                        value: _dailyReminders,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _dailyReminders = val),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            await ref.read(notificationServiceProvider).testSoundNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔔 Notification sound triggered! Check status bar.'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Test Notification with Sound'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // App Lock Security
                const SectionHeader(title: 'Security'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('PIN Protection', style: AppTypography.labelLarge),
                        subtitle: Text(
                          lockState.isLockEnabled ? 'PIN lock active' : 'Lock disabled',
                          style: AppTypography.bodySmall,
                        ),
                        value: lockState.isLockEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) async {
                          if (val) {
                            await _setupPinDialog();
                          } else {
                            final confirmed = await ConfirmationDialog.show(
                              context: context,
                              title: 'Disable App Lock?',
                              message: 'Anyone holding this phone will be able to open the app.',
                              confirmLabel: 'Disable Lock',
                            );
                            if (confirmed) {
                              await ref.read(appLockServiceProvider.notifier).disableAppLock();
                            }
                          }
                        },
                      ),
                      if (lockState.isLockEnabled && _isBiometricsAvailable) ...[
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fingerprint / Face Unlock', style: AppTypography.labelLarge),
                          value: lockState.isBiometricEnabled,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(appLockServiceProvider.notifier).setBiometricsEnabled(val);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Backup & Restore
                const SectionHeader(title: 'Backup & Data Safety'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                        title: const Text('Offline Backup & Restore', style: AppTypography.labelLarge),
                        subtitle: const Text('Save ZIP file or restore data', style: AppTypography.bodySmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/backup'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                        title: const Text('Recycle Bin (30-Day Trash)', style: AppTypography.labelLarge),
                        subtitle: const Text('Restore soft-deleted medicines, sales & ledger records', style: AppTypography.bodySmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/trash'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Database Actions
                const SectionHeader(title: 'Data Management'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: AppColors.success,
                                side: const BorderSide(color: AppColors.success),
                              ),
                              onPressed: _handleLoadDemoData,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Load Demo Data'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                              onPressed: _handleClearAllData,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear All Data'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Version Footer
                const Center(
                  child: Text(
                    'Bismillah Medical and Veterinary Store • 100% Offline & Free',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}
