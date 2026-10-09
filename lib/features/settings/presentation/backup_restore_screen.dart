import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isCreatingBackup = false;
  bool _isRestoring = false;
  String? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final db = ref.read(databaseProvider);
    final val = await db.getSetting('last_backup_timestamp');
    if (val != null && mounted) {
      final dt = DateTime.tryParse(val);
      if (dt != null) {
        setState(() => _lastBackupTime = DateFormatter.formatDateTime(dt));
      }
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isCreatingBackup = true);

    try {
      final db = ref.read(databaseProvider);
      final backupService = ref.read(backupServiceProvider);
      final file = await backupService.createBackup(db);

      await _loadLastBackup();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: ${file.path.split(Platform.pathSeparator).last}'),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => backupService.shareBackup(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _handleRestoreBackup() async {
    final backupService = ref.read(backupServiceProvider);
    final pickedFile = await backupService.pickBackupFile();
    if (pickedFile == null) return;

    setState(() => _isRestoring = true);

    try {
      final validation = await backupService.validateBackupFile(pickedFile);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Validation failed: ${validation.errorMessage}')),
          );
        }
        return;
      }

      final manifest = validation.manifest!;
      if (!mounted) return;

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Confirm Database Restore',
        message: 'Restore backup from ${manifest.timestamp}?\n\n'
            'Contents in backup:\n'
            '• ${manifest.medicineCount} Medicines\n'
            '• ${manifest.batchCount} Batches\n'
            '• ${manifest.customerCount} Customers\n'
            '• ${manifest.saleCount} Sales\n'
            '• ${manifest.attachmentCount} Attachments\n\n'
            'A safety backup of your current database will be saved before restore.',
        confirmLabel: 'Restore & Overwrite',
        isDestructive: true,
      );

      if (!confirmed) return;

      final db = ref.read(databaseProvider);
      await backupService.restoreBackup(pickedFile, db);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database restored successfully! Data has been reloaded.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e. Current data is safe.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backup & Data Safety'),
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadii.roundedMd,
                      ),
                      child: const Icon(Icons.security, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Offline Data Protection', style: AppTypography.heading3),
                          const SizedBox(height: 2),
                          Text(
                            _lastBackupTime != null
                                ? 'Last Backup: $_lastBackupTime'
                                : 'No backup created yet',
                            style: AppTypography.bodySmall.copyWith(
                              color: _lastBackupTime != null ? AppColors.success : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Save a complete offline backup file (medicines, sales, ledger & photos) to your phone or share via WhatsApp / Google Drive.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Backup Now',
                  icon: Icons.cloud_upload_outlined,
                  isLoading: _isCreatingBackup,
                  onPressed: _handleCreateBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

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
                Text('Restore From Backup', style: AppTypography.heading3),
                const SizedBox(height: 4),
                const Text(
                  'Restore store records from a previously exported backup ZIP file.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: _isRestoring ? 'Restoring...' : 'Select Backup ZIP to Restore',
                  icon: Icons.restore,
                  onPressed: _isRestoring ? null : _handleRestoreBackup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
