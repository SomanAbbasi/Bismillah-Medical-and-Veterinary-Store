import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/files/attachment_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/expiry_reminder_scheduler.dart';
import '../../../core/reports/pdf_report_service.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_header.dart';
import 'notification_diagnostics_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController(text: 'BismillahStore');
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _shopLogoPath;
  File? _logoFile;

  int _defaultReminderMonths = 1;
  int _notificationIntervalMinutes = 1440; // Default: Daily (1440 mins)
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(databaseProvider);
    final shopName = await db.getSetting('shop_name');
    final ownerName = await db.getSetting('owner_name');
    final phone = await db.getSetting('phone');
    final address = await db.getSetting('store_address');
    final logoPath = await db.getSetting('shop_logo_path');
    final reminderMonths = await db.getSetting('default_reminder_months');
    final intervalMins = await db.getSetting('notification_interval_minutes');

    if (mounted) {
      setState(() {
        if (shopName != null && shopName.isNotEmpty) _shopNameController.text = shopName;
        if (ownerName != null) _ownerNameController.text = ownerName;
        if (phone != null) _phoneController.text = phone;
        if (address != null) _addressController.text = address;
        if (logoPath != null && logoPath.isNotEmpty) {
          final file = File(logoPath);
          if (file.existsSync()) {
            _logoFile = file;
            _shopLogoPath = logoPath;
          }
        }
        if (reminderMonths != null) _defaultReminderMonths = int.tryParse(reminderMonths) ?? 1;
        if (intervalMins != null) _notificationIntervalMinutes = int.tryParse(intervalMins) ?? 1440;
      });
    }
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final attachmentService = AttachmentService();
      AttachmentResult? result;
      if (source == ImageSource.camera) {
        result = await attachmentService.capturePhoto();
      } else {
        result = await attachmentService.pickImageFromGallery();
      }
      if (result != null) {
        final fullPath = await attachmentService.getAbsolutePath(result.relativePath);
        setState(() {
          _shopLogoPath = fullPath;
          _logoFile = File(fullPath);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick logo: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showLogoSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Store Logo', style: AppTypography.heading3),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Capture with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveShopProfile() async {
    final db = ref.read(databaseProvider);
    await db.setSetting('shop_name', _shopNameController.text.trim());
    await db.setSetting('owner_name', _ownerNameController.text.trim());
    await db.setSetting('phone', _phoneController.text.trim());
    await db.setSetting('store_address', _addressController.text.trim());
    await db.setSetting('shop_logo_path', _shopLogoPath ?? '');
    await db.setSetting('default_reminder_months', _defaultReminderMonths.toString());
    await db.setSetting('notification_interval_minutes', _notificationIntervalMinutes.toString());

    ref.invalidate(shopProfileProvider);

    // Reconcile notifications immediately
    await ref.read(expiryReminderSchedulerProvider).reconcile(db);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store Profile & Settings saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleClearAllData() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Clear Store Records?',
      message: 'This will permanently remove medicines, sales, expenses, and ledger records.',
      confirmLabel: 'Delete All Records',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final db = ref.read(databaseProvider);
      await db.clearAllData();
      await ref.read(notificationServiceProvider).cancelAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All records cleared successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear records: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
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
                const SectionHeader(title: 'Medical Store Profile'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Store Logo Preview & Picker
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                  child: ClipOval(
                                    child: _logoFile != null && _logoFile!.existsSync()
                                        ? Image.file(_logoFile!, fit: BoxFit.cover)
                                        : Image.asset(
                                            'assets/images/default_store_logo.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_hospital, size: 42, color: AppColors.primary),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: _showLogoSourceModal,
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _shopLogoPath != null && _shopLogoPath!.isNotEmpty
                                  ? 'Custom Logo Uploaded (Printed on PDFs)'
                                  : 'Default Bismillah Logo Active (Printed on PDFs)',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                            if (_shopLogoPath != null && _shopLogoPath!.isNotEmpty) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _shopLogoPath = null;
                                    _logoFile = null;
                                  });
                                },
                                child: const Text('Reset to Default Logo', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Store Name',
                        controller: _shopNameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Owner Name (Optional)',
                        controller: _ownerNameController,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Phone Number (Optional)',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Store Address / Location (Optional)',
                        controller: _addressController,
                        hint: 'e.g. Main Hospital Road, Chowk Azam',
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
                const SectionHeader(title: 'Notification Settings & Frequency'),
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
                        'Alert Me Before Medicine Expiry:',
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
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _defaultReminderMonths = val);
                            final db = ref.read(databaseProvider);
                            await db.setSetting('default_reminder_months', val.toString());
                            await ref.read(expiryReminderSchedulerProvider).reconcile(db, forceReschedule: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Expiry alert preference updated!'),
                                  backgroundColor: AppColors.success,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Text(
                        'Reminder Notification Interval:',
                        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<int>(
                        initialValue: _notificationIntervalMinutes,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Every 1 Minute (Fast Testing ⚡)')),
                          DropdownMenuItem(value: 15, child: Text('Every 15 Minutes')),
                          DropdownMenuItem(value: 30, child: Text('Every 30 Minutes')),
                          DropdownMenuItem(value: 60, child: Text('Every 1 Hour (60 Minutes)')),
                          DropdownMenuItem(value: 120, child: Text('Every 2 Hours')),
                          DropdownMenuItem(value: 360, child: Text('Every 6 Hours')),
                          DropdownMenuItem(value: 1440, child: Text('Daily (Every 24 Hours at 9:00 AM)')),
                          DropdownMenuItem(value: 2880, child: Text('Every 2 Days')),
                          DropdownMenuItem(value: 10080, child: Text('Weekly (Every 7 Days)')),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _notificationIntervalMinutes = val);
                            final db = ref.read(databaseProvider);
                            await db.setSetting('notification_interval_minutes', val.toString());
                            await ref.read(expiryReminderSchedulerProvider).reconcile(db, forceReschedule: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notification interval updated and active!'),
                                  backgroundColor: AppColors.success,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        icon: const Icon(Icons.notifications_active, color: AppColors.primary),
                        label: const Text('Send Test Alert Now (Sound & Vibration)', style: TextStyle(fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          final notif = ref.read(notificationServiceProvider);
                          await notif.testImmediateNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Immediate test alert sent with sound & vibration!'),
                                backgroundColor: AppColors.success,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                        title: const Text('Notification Diagnostics', style: AppTypography.labelLarge),
                        subtitle: const Text('View permission status, pending alarms & detailed logs', style: AppTypography.bodySmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationDiagnosticsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // App Lock Security
                const SectionHeader(title: 'Security & App Lock'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Phone Security Lock', style: AppTypography.labelLarge),
                    subtitle: Text(
                      lockState.isLockEnabled
                          ? 'Protected with phone fingerprint, face, or device PIN'
                          : 'Lock disabled (anyone holding this phone can open the app)',
                      style: AppTypography.bodySmall,
                    ),
                    value: lockState.isLockEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      if (val) {
                        final success = await ref.read(appLockServiceProvider.notifier).enableDeviceLock();
                        if (!success && context.mounted) {
                          final err = ref.read(appLockServiceProvider).lastError ??
                              'Could not enable lock. Make sure your phone has a screen lock configured in Android Settings.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                          );
                        }
                      } else {
                        final confirmed = await ConfirmationDialog.show(
                          context: context,
                          title: 'Disable App Lock?',
                          message: 'Anyone holding this phone will be able to open BismillahStore without authentication.',
                          confirmLabel: 'Disable Lock',
                        );
                        if (confirmed) {
                          await ref.read(appLockServiceProvider.notifier).disableDeviceLock();
                        }
                      }
                    },
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
                        subtitle: const Text('Export ZIP backup or restore store database', style: AppTypography.bodySmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/backup'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                        title: const Text('Recycle Bin (30-Day Trash)', style: AppTypography.labelLarge),
                        subtitle: const Text('Restore recently deleted records or delete permanently', style: AppTypography.bodySmall),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => context.push('/trash'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Danger Zone
                const SectionHeader(title: 'Danger Zone'),
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.roundedLg,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Permanent Data Removal',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Clear all medicine, sale, expense, customer, and supplier records.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          onPressed: _handleClearAllData,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Clear All Store Records'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
    );
  }
}
