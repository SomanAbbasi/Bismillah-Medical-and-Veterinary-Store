import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/files/attachment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/receipt_share_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/supplier_repository.dart';

class SupplierAccountScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierAccountScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierAccountScreen> createState() => _SupplierAccountScreenState();
}

class _SupplierAccountScreenState extends ConsumerState<SupplierAccountScreen> {
  String _shopName = 'BismillahStore';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final db = ref.read(databaseProvider);
    final name = await db.getSetting('shop_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _shopName = name);
    }
  }

  Future<void> _shareStatement(SupplierWithBalance item, List<SupplierTransactionWithRunningBalance> history) async {
    final repo = ref.read(supplierRepositoryProvider);
    final statement = repo.generateStatementText(
      shopName: _shopName,
      supplier: item.supplier,
      history: history,
      currentBalancePaisa: item.balancePaisa,
    );

    await Share.share(statement, subject: 'Supplier Statement - ${item.supplier.name}');
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null && mounted) {
      setState(() {
        _startDate = range.start;
        _endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);

    return suppliersAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
      data: (suppliers) {
        final matching = suppliers.where((s) => s.supplier.id == widget.supplierId).toList();
        if (matching.isEmpty) {
          return const Scaffold(body: Center(child: Text('Supplier not found')));
        }
        final item = matching.first;
        final supplier = item.supplier;
        final owes = item.owesSupplier;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement',
                onPressed: () async {
                  final history = await ref.read(supplierRepositoryProvider).getTransactionsWithRunningBalance(supplier.id);
                  _shareStatement(item, history);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Supplier',
                onPressed: () async {
                  await context.push('/suppliers/${supplier.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Delete Supplier',
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Delete Supplier',
                    message: 'Are you sure you want to move "${supplier.name}" to Recycle Bin? All transactions will be preserved.',
                    isDestructive: true,
                    confirmLabel: 'Delete',
                  );
                  if (confirmed && context.mounted) {
                    await ref.read(supplierRepositoryProvider).softDeleteSupplier(supplier.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Supplier "${supplier.name}" moved to Recycle Bin.'),
                          backgroundColor: AppColors.danger,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      context.pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: Consumer(
            builder: (context, ref, _) {
              final txsAsync = ref.watch(supplierTransactionsStreamProvider(supplier.id));

              return txsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (rawTxs) {
                  // Filter by date range if selected
                  final filtered = rawTxs.where((t) {
                    if (_startDate != null && t.date.isBefore(_startDate!)) return false;
                    if (_endDate != null && t.date.isAfter(_endDate!)) return false;
                    return true;
                  }).toList();

                  // Sort chronological ascending to compute running balances correctly
                  filtered.sort((a, b) => a.date.compareTo(b.date));
                  int running = 0;
                  final List<SupplierTransactionWithRunningBalance> history = [];
                  for (final t in filtered) {
                    if (t.type == 'payable') {
                      running += t.amountPaisa;
                    } else if (t.type == 'payment') {
                      running -= t.amountPaisa;
                    }
                    history.add(SupplierTransactionWithRunningBalance(
                      transaction: t,
                      runningBalancePaisa: running,
                    ));
                  }

                  return ListView(
                    padding: AppSpacing.pagePadding,
                    children: [
                      // Profile & Balance Card (Identical layout to Customer Account)
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(supplier.name, style: AppTypography.heading2),
                                    const SizedBox(height: 2),
                                    Text(supplier.phone, style: AppTypography.bodyMedium),
                                    if (supplier.company != null && supplier.company!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(supplier.company!, style: AppTypography.bodySmall),
                                    ],
                                    if (supplier.address != null && supplier.address!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(supplier.address!, style: AppTypography.bodySmall),
                                    ],
                                  ],
                                ),
                                StatusChip(
                                  label: owes ? 'Store Owes' : 'Cleared',
                                  type: owes ? StatusType.warning : StatusType.success,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Current Balance', style: AppTypography.bodySmall),
                                    Text(
                                      CurrencyFormatter.formatPaisa(item.balancePaisa),
                                      style: AppTypography.numberDisplay.copyWith(
                                        color: owes ? AppColors.warning : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  owes ? 'Payable by Store' : 'Zero Balance',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: owes ? AppColors.warning : AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Record Payment',
                              icon: Icons.payments,
                              backgroundColor: AppColors.success,
                              onPressed: () => context.push('/suppliers/${supplier.id}/payment'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Add Bill (Payable)',
                              icon: Icons.receipt_long,
                              backgroundColor: AppColors.danger,
                              onPressed: () => context.push('/suppliers/${supplier.id}/payable'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'Share Account Statement (WhatsApp/SMS)',
                        icon: Icons.share,
                        onPressed: () => _shareStatement(item, history),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Date Filter Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ledger Transactions (${history.length})', style: AppTypography.heading3),
                          Row(
                            children: [
                              if (_startDate != null) ...[
                                TextButton(
                                  onPressed: _clearDateFilter,
                                  child: const Text('Clear Filter', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                                ),
                              ],
                              IconButton(
                                icon: Icon(
                                  _startDate != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                                  color: _startDate != null ? AppColors.primary : AppColors.textMuted,
                                ),
                                tooltip: 'Filter by Date Range',
                                onPressed: () => _pickDateRange(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_startDate != null && _endDate != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'Showing transactions from ${DateFormatter.formatDate(_startDate!)} to ${DateFormatter.formatDate(_endDate!)}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),

                      if (history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text('No transactions recorded for this period.', style: AppTypography.bodyMedium),
                          ),
                        )
                      else
                        ...history.reversed.map((txItem) {
                          final tx = txItem.transaction;
                          final isPayable = tx.type == 'payable';

                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadii.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: AppRadii.roundedMd,
                              child: InkWell(
                                borderRadius: AppRadii.roundedMd,
                                onTap: () => _showSupplierTransactionDetailModal(context, ref, tx, supplier),
                                child: Padding(
                                  padding: AppSpacing.cardPadding,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isPayable ? AppColors.warningLight : AppColors.successLight,
                                          borderRadius: AppRadii.roundedMd,
                                        ),
                                        child: Icon(
                                          isPayable ? Icons.receipt_long : Icons.arrow_downward,
                                          color: isPayable ? AppColors.warning : AppColors.success,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isPayable ? 'Bill (+)' : 'Payment (-)',
                                              style: AppTypography.labelLarge.copyWith(
                                                color: isPayable ? AppColors.warning : AppColors.success,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${DateFormatter.formatDate(tx.date)}${tx.paymentMethod != null ? " • ${tx.paymentMethod}" : (tx.reference != null ? " • ${tx.reference}" : "")}',
                                              style: AppTypography.bodySmall,
                                            ),
                                            if (tx.note != null && tx.note!.isNotEmpty)
                                              Text(
                                                tx.note!,
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyFormatter.formatPaisa(tx.amountPaisa),
                                            style: AppTypography.labelLarge.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isPayable ? AppColors.warning : AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Bal: ${CurrencyFormatter.formatPaisa(txItem.runningBalancePaisa)}',
                                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: AppSpacing.huge),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showSupplierTransactionDetailModal(
    BuildContext context,
    WidgetRef ref,
    SupplierTransaction tx,
    Supplier supplier,
  ) {
    final db = ref.read(databaseProvider);
    final repo = ref.read(supplierRepositoryProvider);
    final attachmentService = AttachmentService();
    final isPayable = tx.type == 'payable';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPayable ? AppColors.warningLight : AppColors.successLight,
                                  borderRadius: AppRadii.roundedMd,
                                ),
                                child: Icon(
                                  isPayable ? Icons.receipt_long : Icons.payments,
                                  color: isPayable ? AppColors.warning : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPayable ? 'Payable Bill Details' : 'Payment Details',
                                style: AppTypography.heading3,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount Display Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPayable ? AppColors.warningLight : AppColors.successLight,
                          borderRadius: AppRadii.roundedLg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPayable ? 'Bill Amount (Owed to Supplier)' : 'Payment Amount Paid',
                              style: AppTypography.bodySmall.copyWith(
                                color: isPayable ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaisa(tx.amountPaisa),
                              style: AppTypography.heading1.copyWith(
                                color: isPayable ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Information Grid
                      _buildInfoRow('Supplier', supplier.name),
                      _buildInfoRow('Date', DateFormatter.formatDateTime(tx.date)),
                      if (tx.paymentMethod != null && tx.paymentMethod!.isNotEmpty)
                        _buildInfoRow(
                          'Payment Method',
                          tx.otherPaymentMethod != null && tx.otherPaymentMethod!.isNotEmpty
                              ? '${tx.paymentMethod} (${tx.otherPaymentMethod})'
                              : tx.paymentMethod!,
                        ),
                      if (tx.reference != null && tx.reference!.isNotEmpty)
                        _buildInfoRow('Reference / Bill #', tx.reference!),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _buildInfoRow('Note / Remarks', tx.note!),

                      const Divider(height: 24),

                      // Attached Photo Proofs
                      Text('Transaction Picture Proof', style: AppTypography.labelLarge),
                      const SizedBox(height: 8),

                      FutureBuilder<List<Attachment>>(
                        future: db.getAttachments('supplier_transaction', tx.id),
                        builder: (ctx, snap) {
                          final attachments = snap.data ?? [];

                          if (attachments.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadii.roundedMd,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted, size: 36),
                                  const SizedBox(height: 8),
                                  const Text('No photo proof attached to this transaction.', style: AppTypography.bodySmall),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add_a_photo, size: 18),
                                    label: const Text('Add Photo Proof'),
                                    onPressed: () async {
                                      final picked = await showModalBottomSheet<AttachmentResult?>(
                                        context: context,
                                        builder: (c) => SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons.camera_alt),
                                                title: const Text('Take Photo from Camera'),
                                                onTap: () async {
                                                  final res = await attachmentService.capturePhoto();
                                                  if (c.mounted) Navigator.pop(c, res);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.photo_library),
                                                title: const Text('Choose from Gallery'),
                                                onTap: () async {
                                                  final res = await attachmentService.pickImageFromGallery();
                                                  if (c.mounted) Navigator.pop(c, res);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      if (picked != null) {
                                        await db.insertAttachment(
                                          AttachmentsCompanion(
                                            entityType: const drift.Value('supplier_transaction'),
                                            entityId: drift.Value(tx.id),
                                            filePath: drift.Value(picked.relativePath),
                                            fileName: drift.Value(picked.originalName),
                                            mimeType: drift.Value(picked.mimeType),
                                            description: const drift.Value('Supplier proof photo'),
                                          ),
                                        );
                                        setModalState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...attachments.map((att) {
                                return FutureBuilder<String>(
                                  future: attachmentService.getAbsolutePath(att.filePath),
                                  builder: (ctx, pathSnap) {
                                    if (!pathSnap.hasData) return const SizedBox();
                                    final file = File(pathSnap.data!);
                                    if (!file.existsSync()) return const SizedBox();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadii.roundedMd,
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: AppRadii.roundedMd,
                                            child: InkWell(
                                              onTap: () => _showFullScreenImage(context, file, 'Supplier Bill #${tx.id} Proof'),
                                              child: Image.file(
                                                file,
                                                width: double.infinity,
                                                height: 180,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 52,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              radius: 18,
                                              child: IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                                tooltip: 'Delete Photo',
                                                onPressed: () async {
                                                  final confirmed = await ConfirmationDialog.show(
                                                    context: context,
                                                    title: 'Delete Photo Proof',
                                                    message: 'Are you sure you want to remove this attached photo?',
                                                    isDestructive: true,
                                                    confirmLabel: 'Delete',
                                                  );
                                                  if (confirmed) {
                                                    await db.deleteAttachment(att.id);
                                                    setModalState(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              radius: 18,
                                              child: IconButton(
                                                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                                                onPressed: () => _showFullScreenImage(context, file, 'Supplier Bill #${tx.id} Proof'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Share Receipt Action
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share Receipt (WhatsApp)'),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          final shopName = await db.getSetting('shop_name') ?? 'Bismillah Medical & Veterinary Store';
                          final receipt = ReceiptShareHelper.buildSupplierReceipt(
                            storeName: shopName,
                            supplierName: supplier.name,
                            type: tx.type,
                            amountPaisa: tx.amountPaisa,
                            date: tx.date,
                            paymentMethod: tx.paymentMethod,
                            reference: tx.reference,
                            note: tx.note,
                          );
                          if (bottomSheetCtx.mounted) {
                            Navigator.of(bottomSheetCtx).pop();
                            ReceiptShareHelper.showReceiptShareSheet(
                              context: context,
                              personName: supplier.name,
                              phone: supplier.phone,
                              formattedAmount: CurrencyFormatter.formatPaisa(tx.amountPaisa),
                              typeLabel: tx.type == 'payable' ? 'Supplier Bill' : 'Supplier Payment',
                              receiptText: receipt,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Edit and Delete Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Edit Transaction',
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.of(bottomSheetCtx).pop();
                                _showEditSupplierTransactionDialog(context, ref, tx, supplier);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            tooltip: 'Move to Trash',
                            onPressed: () async {
                              final confirmed = await ConfirmationDialog.show(
                                context: context,
                                title: 'Delete Transaction?',
                                message: 'Move this transaction of ${CurrencyFormatter.formatPaisa(tx.amountPaisa)} to Recycle Bin?',
                                isDestructive: true,
                                confirmLabel: 'Move to Trash',
                              );
                              if (confirmed) {
                                if (bottomSheetCtx.mounted) {
                                  Navigator.of(bottomSheetCtx).pop();
                                }
                                await repo.softDeleteTransaction(tx.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Transaction moved to Recycle Bin.'),
                                      duration: const Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        textColor: Colors.yellow,
                                        onPressed: () async {
                                          await repo.restoreTransaction(tx.id);
                                        },
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSupplierTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    SupplierTransaction tx,
    Supplier supplier,
  ) {
    final repo = ref.read(supplierRepositoryProvider);
    int amountPaisa = tx.amountPaisa;
    DateTime date = tx.date;
    final amountController = TextEditingController(
      text: amountPaisa % 100 == 0 ? (amountPaisa ~/ 100).toString() : (amountPaisa / 100).toStringAsFixed(2),
    );
    final refController = TextEditingController(text: tx.reference ?? '');
    final noteController = TextEditingController(text: tx.note ?? '');
    String paymentMethod = tx.paymentMethod ?? 'Cash';
    final otherMethodController = TextEditingController(text: tx.otherPaymentMethod ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: Text(tx.type == 'payable' ? 'Edit Payable Bill' : 'Edit Supplier Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CurrencyField(
                  label: 'Amount (PKR)',
                  controller: amountController,
                  onPaisaChanged: (paisa) => amountPaisa = paisa,
                ),
                const SizedBox(height: AppSpacing.md),
                DateField(
                  label: 'Date',
                  selectedDate: date,
                  onDateSelected: (newDate) => setDlgState(() => date = newDate),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Invoice / Bill Reference # (Optional)',
                  controller: refController,
                ),
                if (tx.type == 'payment') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: ['Cash', 'Bank Transfer', 'EasyPaisa / JazzCash', 'Other'].contains(paymentMethod)
                        ? paymentMethod
                        : 'Cash',
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'EasyPaisa / JazzCash', child: Text('EasyPaisa / JazzCash')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => paymentMethod = val);
                    },
                  ),
                  if (paymentMethod == 'Other') ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Specify Payment Method',
                      controller: otherMethodController,
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Note / Remarks (Optional)',
                  controller: noteController,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountPaisa <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount greater than 0')),
                  );
                  return;
                }

                Navigator.pop(dlgCtx);
                await repo.updateTransaction(
                  id: tx.id,
                  supplierId: supplier.id,
                  date: date,
                  amountPaisa: amountPaisa,
                  type: tx.type,
                  reference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                  paymentMethod: tx.type == 'payment' ? paymentMethod : null,
                  otherPaymentMethod: tx.type == 'payment' && paymentMethod == 'Other'
                      ? otherMethodController.text.trim()
                      : null,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Record updated successfully! Balance updated.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, File file, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            Positioned(
              top: 48,
              left: 70,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
