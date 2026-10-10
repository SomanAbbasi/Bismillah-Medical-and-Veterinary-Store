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

  void _shareStatement(SupplierWithBalance item, List<dynamic> txs) {
    final buffer = StringBuffer();
    buffer.writeln('====================================');
    buffer.writeln('$_shopName - Supplier Statement');
    buffer.writeln('====================================');
    buffer.writeln('Supplier: ${item.supplier.name}');
    buffer.writeln('Phone: ${item.supplier.phone}');
    if (item.supplier.company != null && item.supplier.company!.isNotEmpty) {
      buffer.writeln('Company: ${item.supplier.company}');
    }
    buffer.writeln('Date: ${DateFormatter.formatDate(DateTime.now())}');
    buffer.writeln('------------------------------------');
    buffer.writeln('TRANSACTIONS:');

    for (final tx in txs) {
      final dateStr = DateFormatter.formatShortDate(tx.date);
      final isPayable = tx.type == 'payable';
      final typeLabel = isPayable ? 'Bill (Owed)' : 'Payment';
      final amount = CurrencyFormatter.formatPaisa(tx.amountPaisa);
      buffer.writeln('$dateStr | $typeLabel | $amount | ${tx.reference ?? tx.note ?? ''}');
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('Total Bills: ${CurrencyFormatter.formatPaisa(item.totalPayablePaisa)}');
    buffer.writeln('Total Paid: ${CurrencyFormatter.formatPaisa(item.totalPaidPaisa)}');
    buffer.writeln('CURRENT BALANCE OWED: ${CurrencyFormatter.formatPaisa(item.balancePaisa)}');
    buffer.writeln('====================================');

    Share.share(buffer.toString(), subject: 'Supplier Statement - ${item.supplier.name}');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(supplierRepositoryProvider);
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);
    final txsAsync = ref.watch(supplierTransactionsStreamProvider(widget.supplierId));

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
          return Scaffold(
            appBar: AppBar(title: const Text('Supplier Details')),
            body: const Center(child: Text('Supplier not found')),
          );
        }

        final supplierWithBal = matching.first;
        final supplier = supplierWithBal.supplier;
        final owes = supplierWithBal.owesSupplier;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement',
                onPressed: () {
                  final txs = txsAsync.asData?.value ?? [];
                  _shareStatement(supplierWithBal, txs);
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
                    message: 'Are you sure you want to move this supplier to trash? You can restore it later from Trash.',
                    isDestructive: true,
                    confirmLabel: 'Delete',
                  );
                  if (confirmed && context.mounted) {
                    await repo.softDeleteSupplier(widget.supplierId);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Supplier Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.roundedLg,
                  border: Border.all(
                    color: owes ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: owes ? AppColors.warningLight : AppColors.primarySubtle,
                          foregroundColor: owes ? AppColors.warning : AppColors.primary,
                          child: Text(
                            supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(supplier.name, style: AppTypography.heading3),
                              const SizedBox(height: 2),
                              Text('Phone: ${supplier.phone}', style: AppTypography.bodySmall),
                              if (supplier.company != null && supplier.company!.isNotEmpty)
                                Text('Company: ${supplier.company}', style: AppTypography.bodySmall),
                              if (supplier.address != null && supplier.address!.isNotEmpty)
                                Text('Address: ${supplier.address}', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaisa(supplierWithBal.balancePaisa),
                              style: AppTypography.heading2.copyWith(
                                color: owes ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StatusChip(
                              label: owes ? 'Store Owes' : 'Cleared',
                              type: owes ? StatusType.warning : StatusType.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Add Bill (Payable)',
                            icon: Icons.add,
                            onPressed: () => context.push('/suppliers/${widget.supplierId}/payable'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Record Payment',
                            icon: Icons.payments_outlined,
                            onPressed: () => context.push('/suppliers/${widget.supplierId}/payment'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ledger Transactions List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ledger Transactions', style: AppTypography.heading3),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(_startDate == null ? 'Filter Date' : 'Clear Filter'),
                      onPressed: () async {
                        if (_startDate != null) {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        } else {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (range != null) {
                            setState(() {
                              _startDate = range.start;
                              _endDate = range.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Transactions
              Expanded(
                child: txsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (txs) {
                    var filtered = txs;
                    if (_startDate != null && _endDate != null) {
                      filtered = filtered.where((t) => t.date.isAfter(_startDate!) && t.date.isBefore(_endDate!)).toList();
                    }

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No transaction records found for this period.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final isPayable = tx.type == 'payable';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
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
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isPayable ? AppColors.warningLight : AppColors.successLight,
                                        borderRadius: AppRadii.roundedSm,
                                      ),
                                      child: Icon(
                                        isPayable ? Icons.receipt_long : Icons.payments,
                                        color: isPayable ? AppColors.warning : AppColors.success,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isPayable ? 'Payable Bill (Owed)' : 'Payment Made',
                                            style: AppTypography.labelLarge,
                                          ),
                                          Text(
                                            '${DateFormatter.formatDate(tx.date)}${tx.reference != null ? " • ${tx.reference}" : ""}',
                                            style: AppTypography.bodySmall,
                                          ),
                                          if (tx.note != null && tx.note!.isNotEmpty)
                                            Text(tx.note!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatPaisa(tx.amountPaisa),
                                          style: AppTypography.labelLarge.copyWith(
                                            color: isPayable ? AppColors.warning : AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                      },
                    );
                  },
                ),
              ),
            ],
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
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                              isPayable ? 'Bill Amount (Owed)' : 'Payment Amount Paid',
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
                      if (tx.reference != null && tx.reference!.isNotEmpty)
                        _buildInfoRow('Invoice / Bill #', tx.reference!),
                      if (tx.paymentMethod != null && tx.paymentMethod!.isNotEmpty)
                        _buildInfoRow(
                          'Payment Method',
                          tx.otherPaymentMethod != null && tx.otherPaymentMethod!.isNotEmpty
                              ? '${tx.paymentMethod} (${tx.otherPaymentMethod})'
                              : tx.paymentMethod!,
                        ),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _buildInfoRow('Note / Remarks', tx.note!),

                      const Divider(height: 24),

                      // Attached Photo Proofs
                      Text('Bill / Receipt Picture Proof', style: AppTypography.labelLarge),
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
                                  const Text('No photo proof attached to this supplier record.', style: AppTypography.bodySmall),
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
                                              onTap: () => _showFullScreenImage(context, file, 'Bill #${tx.id} Proof'),
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
                                            right: 8,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              radius: 18,
                                              child: IconButton(
                                                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                                                onPressed: () => _showFullScreenImage(context, file, 'Bill #${tx.id} Proof'),
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
                                message: 'Move this transaction of ${CurrencyFormatter.formatPaisa(tx.amountPaisa)} to Trash?',
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
                                    const SnackBar(
                                      content: Text('Transaction moved to Recycle Bin.'),
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

