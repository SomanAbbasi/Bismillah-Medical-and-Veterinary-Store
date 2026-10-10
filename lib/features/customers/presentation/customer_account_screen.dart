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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/customer_repository.dart';

class CustomerAccountScreen extends ConsumerStatefulWidget {
  final int customerId;

  const CustomerAccountScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends ConsumerState<CustomerAccountScreen> {
  String _shopName = 'Bismillah Medical and Veterinary Store';
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

  Future<void> _shareStatement(CustomerWithBalance item, List<CustomerTransactionWithRunningBalance> history) async {
    final repo = ref.read(customerRepositoryProvider);
    final statement = repo.generateStatementText(
      shopName: _shopName,
      customer: item.customer,
      history: history,
      currentBalancePaisa: item.balancePaisa,
    );

    await Share.share(statement, subject: 'Account Statement - ${item.customer.name}');
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
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);

    return customersAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
      data: (customers) {
        final matching = customers.where((c) => c.customer.id == widget.customerId).toList();
        if (matching.isEmpty) {
          return const Scaffold(body: Center(child: Text('Customer not found')));
        }
        final item = matching.first;

        final cust = item.customer;
        final owes = item.owesMoney;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(cust.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share Statement',
                onPressed: () async {
                  final history = await ref.read(customerRepositoryProvider).getTransactionsWithRunningBalance(cust.id);
                  _shareStatement(item, history);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Customer',
                onPressed: () async {
                  await context.push('/customers/${cust.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Delete Customer',
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context: context,
                    title: 'Delete Customer',
                    message: 'Are you sure you want to move "${cust.name}" to the Recycle Bin? All transactions will be preserved.',
                    isDestructive: true,
                    confirmLabel: 'Delete',
                  );
                  if (confirmed && context.mounted) {
                    await ref.read(customerRepositoryProvider).softDeleteCustomer(cust.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Customer "${cust.name}" moved to Recycle Bin.'),
                          backgroundColor: AppColors.danger,
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
              final txsAsync = ref.watch(customerTransactionsStreamProvider(cust.id));

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
                  final List<CustomerTransactionWithRunningBalance> history = [];
                  for (final t in filtered) {
                    if (t.type == 'credit' || t.type == 'adjustment_debit') {
                      running += t.amountPaisa;
                    } else if (t.type == 'payment' || t.type == 'adjustment_credit') {
                      running -= t.amountPaisa;
                    }
                    history.add(CustomerTransactionWithRunningBalance(
                      transaction: t,
                      runningBalancePaisa: running,
                    ));
                  }

                  return ListView(
                    padding: AppSpacing.pagePadding,
                    children: [
                      // Profile & Balance Card
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
                                    Text(cust.name, style: AppTypography.heading2),
                                    const SizedBox(height: 2),
                                    Text(cust.phone, style: AppTypography.bodyMedium),
                                    if (cust.address != null && cust.address!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(cust.address!, style: AppTypography.bodySmall),
                                    ],
                                  ],
                                ),
                                StatusChip(
                                  label: owes ? 'Owes Store' : 'Cleared',
                                  type: owes ? StatusType.critical : StatusType.success,
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
                                        color: owes ? AppColors.danger : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  owes ? 'Payable by Customer' : 'Zero Balance',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: owes ? AppColors.danger : AppColors.success,
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
                              onPressed: () => context.push('/customers/${cust.id}/payment'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Add Credit',
                              icon: Icons.credit_card,
                              backgroundColor: AppColors.danger,
                              onPressed: () => context.push('/customers/${cust.id}/credit'),
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
                          final isCredit = tx.type == 'credit' || tx.type == 'adjustment_debit';

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
                                onTap: () => _showTransactionDetailModal(context, ref, tx, cust),
                                child: Padding(
                                  padding: AppSpacing.cardPadding,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                                          borderRadius: AppRadii.roundedMd,
                                        ),
                                        child: Icon(
                                          isCredit ? Icons.arrow_outward : Icons.arrow_downward,
                                          color: isCredit ? AppColors.danger : AppColors.success,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isCredit ? 'Credit (+)' : 'Payment (-)',
                                              style: AppTypography.labelLarge.copyWith(
                                                color: isCredit ? AppColors.danger : AppColors.success,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${DateFormatter.formatDate(tx.date)}${tx.paymentMethod != null ? " • ${tx.paymentMethod}" : ""}',
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
                                              color: isCredit ? AppColors.danger : AppColors.success,
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

  void _showTransactionDetailModal(
    BuildContext context,
    WidgetRef ref,
    CustomerTransaction tx,
    Customer cust,
  ) {
    final db = ref.read(databaseProvider);
    final repo = ref.read(customerRepositoryProvider);
    final attachmentService = AttachmentService();
    final isCredit = tx.type == 'credit' || tx.type == 'adjustment_debit';

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
                                  color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                                  borderRadius: AppRadii.roundedMd,
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_outward : Icons.arrow_downward,
                                  color: isCredit ? AppColors.danger : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isCredit ? 'Credit Record Details' : 'Payment Details',
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
                          color: isCredit ? AppColors.dangerLight : AppColors.successLight,
                          borderRadius: AppRadii.roundedLg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCredit ? 'Credit Added' : 'Payment Received',
                              style: AppTypography.bodySmall.copyWith(
                                color: isCredit ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaisa(tx.amountPaisa),
                              style: AppTypography.heading1.copyWith(
                                color: isCredit ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Information Grid
                      _buildInfoRow('Customer', cust.name),
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
                        future: db.getAttachments('customer_transaction', tx.id),
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
                                            entityType: const drift.Value('customer_transaction'),
                                            entityId: drift.Value(tx.id),
                                            filePath: drift.Value(picked.relativePath),
                                            fileName: drift.Value(picked.originalName),
                                            mimeType: drift.Value(picked.mimeType),
                                            description: const drift.Value('Proof photo'),
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
                                              onTap: () => _showFullScreenImage(context, file, 'Transaction #${tx.id} Proof'),
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
                                                onPressed: () => _showFullScreenImage(context, file, 'Transaction #${tx.id} Proof'),
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

                      // Edit and Delete Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Edit Transaction',
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.of(bottomSheetCtx).pop();
                                _showEditTransactionDialog(context, ref, tx, cust);
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
                                    SnackBar(
                                      content: const Text('Transaction moved to Recycle Bin.'),
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

  void _showEditTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerTransaction tx,
    Customer cust,
  ) {
    final repo = ref.read(customerRepositoryProvider);
    int amountPaisa = tx.amountPaisa;
    DateTime date = tx.date;
    final amountController = TextEditingController(
      text: amountPaisa % 100 == 0 ? (amountPaisa ~/ 100).toString() : (amountPaisa / 100).toStringAsFixed(2),
    );
    String paymentMethod = tx.paymentMethod ?? 'Cash';
    final otherMethodController = TextEditingController(text: tx.otherPaymentMethod ?? '');
    final noteController = TextEditingController(text: tx.note ?? '');
    final refController = TextEditingController(text: tx.reference ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
          title: Text(tx.type == 'credit' ? 'Edit Credit Record' : 'Edit Payment Record'),
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
                  label: 'Transaction Date',
                  selectedDate: date,
                  onDateSelected: (newDate) => setDlgState(() => date = newDate),
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
                  label: 'Reference / Slip # (Optional)',
                  controller: refController,
                ),
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
                  customerId: cust.id,
                  date: date,
                  amountPaisa: amountPaisa,
                  type: tx.type,
                  paymentMethod: tx.type == 'payment' ? paymentMethod : null,
                  otherPaymentMethod: tx.type == 'payment' && paymentMethod == 'Other'
                      ? otherMethodController.text.trim()
                      : null,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  reference: refController.text.trim().isEmpty ? null : refController.text.trim(),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction updated successfully! Balance updated.'),
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
