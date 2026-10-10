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
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../expenses/data/expense_repository.dart';
import '../data/sales_repository.dart';

enum SalesExpensePeriod { today, thisWeek, thisMonth, custom }

class SalesAndExpensesScreen extends ConsumerStatefulWidget {
  final String? initialTab; // 'sales' or 'expenses'

  const SalesAndExpensesScreen({super.key, this.initialTab});

  @override
  ConsumerState<SalesAndExpensesScreen> createState() => _SalesAndExpensesScreenState();
}

class _SalesAndExpensesScreenState extends ConsumerState<SalesAndExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SalesExpensePeriod _period = SalesExpensePeriod.today;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();

  String _saleSearch = '';
  String _expenseSearch = '';

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'expenses' ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SalesAndExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      final newIndex = widget.initialTab == 'expenses' ? 1 : 0;
      if (_tabController.index != newIndex) {
        _tabController.animateTo(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    final todayMidnight = DateFormatter.today();
    final endOfToday = todayMidnight.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (_period) {
      case SalesExpensePeriod.today:
        return (todayMidnight, endOfToday);
      case SalesExpensePeriod.thisWeek:
        final startOfWeek = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
        return (startOfWeek, endOfToday);
      case SalesExpensePeriod.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (startOfMonth, endOfToday);
      case SalesExpensePeriod.custom:
        return (
          DateFormatter.toDateOnly(_customStart),
          DateFormatter.toDateOnly(_customEnd).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
    }
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
            Positioned(
              top: 40,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => Share.shareXFiles([XFile(file.path)], text: title),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(
    BuildContext context,
    int totalSales,
    int cashSales,
    int creditSales,
    int totalExpenses,
    int netSales,
    List<Sale> sales,
    List<Expense> expenses,
    DateTime startDate,
    DateTime endDate,
  ) {
    final Map<String, int> categories = {};
    for (final e in expenses) {
      final cat = e.category ?? 'General';
      categories[cat] = (categories[cat] ?? 0) + e.amountPaisa;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: AppRadii.roundedMd,
                            ),
                            child: const Icon(Icons.summarize, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text('Financial Report Summary', style: AppTypography.heading3),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Period: ${DateFormatter.formatDate(startDate)} to ${DateFormatter.formatDate(endDate)}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Core Net Profit Highlight
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: netSales >= 0 ? AppColors.successLight : AppColors.dangerLight,
                      borderRadius: AppRadii.roundedLg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          netSales >= 0 ? 'NET PROFIT (SALES EXCEED EXPENSES)' : 'NET LOSS (EXPENSES EXCEED SALES)',
                          style: AppTypography.bodySmall.copyWith(
                            color: netSales >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatPaisa(netSales),
                          style: AppTypography.heading1.copyWith(
                            color: netSales >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Sales Details
                  _buildReportRow('Total Sales', CurrencyFormatter.formatPaisa(totalSales), isBold: true),
                  _buildReportRow('  • Cash Sales', CurrencyFormatter.formatPaisa(cashSales)),
                  _buildReportRow('  • Credit (Udhaar) Sales', CurrencyFormatter.formatPaisa(creditSales)),
                  _buildReportRow('Total Sale Transactions', '${sales.length} entries'),
                  const Divider(height: 20),

                  // Expenses Details
                  _buildReportRow('Total Operational Expenses', CurrencyFormatter.formatPaisa(totalExpenses), isBold: true),
                  _buildReportRow('Total Expense Entries', '${expenses.length} entries'),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Expenses by Category:', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...categories.entries.map((cat) {
                      final pct = totalExpenses > 0 ? ((cat.value / totalExpenses) * 100).toStringAsFixed(1) : '0';
                      return _buildReportRow('  • ${cat.key} ($pct%)', CurrencyFormatter.formatPaisa(cat.value));
                    }),
                  ],
                  const Divider(height: 24),

                  // Share Report Button
                  PrimaryButton(
                    label: 'Share Financial Statement (WhatsApp)',
                    icon: Icons.share,
                    onPressed: () async {
                      final buffer = StringBuffer();
                      buffer.writeln('====================================');
                      buffer.writeln('BismillahStore - Financial Statement');
                      buffer.writeln('====================================');
                      buffer.writeln('Period: ${DateFormatter.formatDate(startDate)} to ${DateFormatter.formatDate(endDate)}');
                      buffer.writeln('------------------------------------');
                      buffer.writeln('Total Sales: ${CurrencyFormatter.formatPaisa(totalSales)}');
                      buffer.writeln('  Cash: ${CurrencyFormatter.formatPaisa(cashSales)}');
                      buffer.writeln('  Credit: ${CurrencyFormatter.formatPaisa(creditSales)}');
                      buffer.writeln('Total Expenses: ${CurrencyFormatter.formatPaisa(totalExpenses)}');
                      buffer.writeln('------------------------------------');
                      buffer.writeln('NET PROFIT: ${CurrencyFormatter.formatPaisa(netSales)}');
                      buffer.writeln('====================================');
                      buffer.writeln('Generated via BismillahStore App');

                      await Share.share(buffer.toString(), subject: 'Store Financial Report');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold ? AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold) : AppTypography.bodySmall,
          ),
          Text(
            value,
            style: isBold ? AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700) : AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showSaleDetailModal(BuildContext context, WidgetRef ref, Sale sale) {
    final db = ref.read(databaseProvider);
    final repo = ref.read(salesRepositoryProvider);
    final isCredit = sale.paymentType == 'credit';
    final attachmentService = AttachmentService();

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
                                  isCredit ? Icons.credit_card : Icons.point_of_sale,
                                  color: isCredit ? AppColors.danger : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('Sale Record Details', style: AppTypography.heading3),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount card
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
                              isCredit ? 'Credit Sale Bill (Udhaar)' : 'Cash Sale Bill',
                              style: AppTypography.bodySmall.copyWith(
                                color: isCredit ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaisa(sale.finalAmountPaisa),
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
                      _buildInfoRow('Sale Title', sale.title),
                      _buildInfoRow('Date & Time', DateFormatter.formatDateTime(sale.date)),
                      _buildInfoRow('Payment Type', isCredit ? 'Credit / Udhaar' : 'Cash Paid'),
                      if (sale.customerId != null)
                        FutureBuilder<Customer?>(
                          future: db.getCustomerById(sale.customerId!),
                          builder: (ctx, custSnap) {
                            final custName = custSnap.data?.name ?? 'Customer #${sale.customerId}';
                            return _buildInfoRow('Customer', custName);
                          },
                        ),
                      if (sale.notes != null && sale.notes!.isNotEmpty)
                        _buildInfoRow('Notes / Particulars', sale.notes!),

                      const Divider(height: 24),

                      // Attached Photo Proofs
                      Text('Sale Picture Proof', style: AppTypography.labelLarge),
                      const SizedBox(height: 8),

                      FutureBuilder<List<Attachment>>(
                        future: db.getAttachments('sale', sale.id),
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
                                  const Text('No picture proof attached to this sale.', style: AppTypography.bodySmall),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add_a_photo, size: 18),
                                    label: const Text('Add Picture Proof'),
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
                                            entityType: const drift.Value('sale'),
                                            entityId: drift.Value(sale.id),
                                            filePath: drift.Value(picked.relativePath),
                                            fileName: drift.Value(picked.originalName),
                                            mimeType: drift.Value(picked.mimeType),
                                            description: const drift.Value('Sale proof photo'),
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
                            children: attachments.map((att) {
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
                                            onTap: () => _showFullScreenImage(context, file, 'Sale #${sale.id} Proof'),
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
                                              onPressed: () => _showFullScreenImage(context, file, 'Sale #${sale.id} Proof'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),
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
                          final buffer = StringBuffer();
                          buffer.writeln('*Bismillah Medical and Veterinary Store*');
                          buffer.writeln('*Sale Bill Receipt #${sale.id}*');
                          buffer.writeln('-----------------------------------');
                          buffer.writeln('Date: ${DateFormatter.formatDateTime(sale.date)}');
                          buffer.writeln('Title: ${sale.title}');
                          buffer.writeln('Total Bill: ${CurrencyFormatter.formatPaisa(sale.finalAmountPaisa)}');
                          buffer.writeln('Payment: ${isCredit ? "Credit (Udhar)" : "Cash Paid"}');
                          if (sale.notes != null && sale.notes!.isNotEmpty) {
                            buffer.writeln('Note: ${sale.notes}');
                          }
                          buffer.writeln('-----------------------------------');
                          buffer.writeln('Thank you!');

                          await Share.share(buffer.toString(), subject: 'Sale Receipt #${sale.id}');
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Edit and Delete Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Edit Sale',
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.of(bottomSheetCtx).pop();
                                context.push('/sales/${sale.id}/edit');
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
                                title: 'Delete Sale?',
                                message: 'Move "${sale.title}" (${CurrencyFormatter.formatPaisa(sale.finalAmountPaisa)}) to Recycle Bin?',
                                isDestructive: true,
                                confirmLabel: 'Move to Trash',
                              );
                              if (confirmed) {
                                if (bottomSheetCtx.mounted) {
                                  Navigator.of(bottomSheetCtx).pop();
                                }
                                await repo.softDeleteSale(sale.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Sale moved to Recycle Bin.'),
                                      duration: const Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        textColor: Colors.yellow,
                                        onPressed: () async {
                                          await repo.restoreSale(sale.id);
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

  void _showExpenseDetailModal(BuildContext context, WidgetRef ref, Expense expense) {
    final db = ref.read(databaseProvider);
    final repo = ref.read(expenseRepositoryProvider);
    final attachmentService = AttachmentService();

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
                                  color: AppColors.warningLight,
                                  borderRadius: AppRadii.roundedMd,
                                ),
                                child: const Icon(Icons.receipt_long, color: AppColors.warning, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text('Expense Details', style: AppTypography.heading3),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: AppRadii.roundedLg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Amount Paid',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaisa(expense.amountPaisa),
                              style: AppTypography.heading1.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Information Grid
                      _buildInfoRow('Expense Title', expense.title),
                      _buildInfoRow('Category', expense.category ?? 'General'),
                      _buildInfoRow('Date & Time', DateFormatter.formatDateTime(expense.date)),
                      if (expense.note != null && expense.note!.isNotEmpty)
                        _buildInfoRow('Notes / Particulars', expense.note!),

                      const Divider(height: 24),

                      // Attached Photo Proofs
                      Text('Receipt / Bill Photo Proof', style: AppTypography.labelLarge),
                      const SizedBox(height: 8),

                      FutureBuilder<List<Attachment>>(
                        future: db.getAttachments('expense', expense.id),
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
                                  const Text('No receipt photo attached to this expense.', style: AppTypography.bodySmall),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add_a_photo, size: 18),
                                    label: const Text('Add Receipt Photo'),
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
                                            entityType: const drift.Value('expense'),
                                            entityId: drift.Value(expense.id),
                                            filePath: drift.Value(picked.relativePath),
                                            fileName: drift.Value(picked.originalName),
                                            mimeType: drift.Value(picked.mimeType),
                                            description: const drift.Value('Expense receipt photo'),
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
                            children: attachments.map((att) {
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
                                            onTap: () => _showFullScreenImage(context, file, 'Expense #${expense.id} Receipt'),
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
                                                  title: 'Delete Receipt Photo',
                                                  message: 'Are you sure you want to remove this attached receipt?',
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
                                              onPressed: () => _showFullScreenImage(context, file, 'Expense #${expense.id} Receipt'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Edit and Delete Actions
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Edit Expense',
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.of(bottomSheetCtx).pop();
                                context.push('/expenses/${expense.id}/edit');
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
                                title: 'Delete Expense?',
                                message: 'Move "${expense.title}" (${CurrencyFormatter.formatPaisa(expense.amountPaisa)}) to Recycle Bin?',
                                isDestructive: true,
                                confirmLabel: 'Move to Trash',
                              );
                              if (confirmed) {
                                if (bottomSheetCtx.mounted) {
                                  Navigator.of(bottomSheetCtx).pop();
                                }
                                await repo.softDeleteExpense(expense.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Expense moved to Recycle Bin.'),
                                      duration: const Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        textColor: Colors.yellow,
                                        onPressed: () async {
                                          await repo.restoreExpense(expense.id);
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

  @override
  Widget build(BuildContext context) {
    final (startDate, endDate) = _getDateRange();
    final isSalesTab = _tabController.index == 0;

    final salesRepo = ref.watch(salesRepositoryProvider);
    final expenseRepo = ref.watch(expenseRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales & Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Financial Report',
            onPressed: () async {
              final sales = await salesRepo.getSalesForRange(startDate, endDate);
              final expenses = await expenseRepo.getExpensesForRange(startDate, endDate);
              final totalSales = sales.fold(0, (s, e) => s + e.finalAmountPaisa);
              final cashSales = sales.fold(0, (s, e) => s + e.cashPaidPaisa);
              final creditSales = sales.fold(0, (s, e) => s + e.creditAmountPaisa);
              final totalExpenses = expenses.fold(0, (s, e) => s + e.amountPaisa);
              final netSales = totalSales - totalExpenses;
              if (context.mounted) {
                _showReportDialog(
                  context,
                  totalSales,
                  cashSales,
                  creditSales,
                  totalExpenses,
                  netSales,
                  sales,
                  expenses,
                  startDate,
                  endDate,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Recycle Bin',
            onPressed: () => context.push('/trash'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.point_of_sale_outlined),
              text: 'Sales Ledger',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_outlined),
              text: 'Expenses',
            ),
          ],
        ),
      ),
      floatingActionButton: isSalesTab
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/sales/new'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push('/expenses/new'),
              backgroundColor: AppColors.warning,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: FutureBuilder<(List<Sale>, List<Expense>)>(
        future: Future.wait([
          salesRepo.getSalesForRange(startDate, endDate),
          expenseRepo.getExpensesForRange(startDate, endDate),
        ]).then((res) => (res[0] as List<Sale>, res[1] as List<Expense>)),
        builder: (context, snapshot) {
          final (sales, expenses) = snapshot.data ?? (<Sale>[], <Expense>[]);

          final totalSales = sales.fold(0, (sum, s) => sum + s.finalAmountPaisa);
          final totalExpenses = expenses.fold(0, (sum, e) => sum + e.amountPaisa);
          final netProfit = totalSales - totalExpenses;

          return Column(
            children: [
              // Top Period Selector & Net Profit Header
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Period Selector Bar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          _PeriodTab(
                            label: 'Today',
                            isSelected: _period == SalesExpensePeriod.today,
                            onTap: () => setState(() => _period = SalesExpensePeriod.today),
                          ),
                          _PeriodTab(
                            label: 'Week',
                            isSelected: _period == SalesExpensePeriod.thisWeek,
                            onTap: () => setState(() => _period = SalesExpensePeriod.thisWeek),
                          ),
                          _PeriodTab(
                            label: 'Month',
                            isSelected: _period == SalesExpensePeriod.thisMonth,
                            onTap: () => setState(() => _period = SalesExpensePeriod.thisMonth),
                          ),
                          _PeriodTab(
                            label: 'Custom',
                            isSelected: _period == SalesExpensePeriod.custom,
                            onTap: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
                              );
                              if (picked != null) {
                                setState(() {
                                  _customStart = picked.start;
                                  _customEnd = picked.end;
                                  _period = SalesExpensePeriod.custom;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Net Profit / Net Sales Metrics
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadii.roundedSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Sales', style: AppTypography.bodySmall),
                                Text(
                                  CurrencyFormatter.formatPaisa(totalSales),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadii.roundedSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Expenses', style: AppTypography.bodySmall),
                                Text(
                                  CurrencyFormatter.formatPaisa(totalExpenses),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: netProfit >= 0 ? AppColors.successLight : AppColors.dangerLight,
                              borderRadius: AppRadii.roundedSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: netProfit >= 0 ? AppColors.success : AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPaisa(netProfit),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: netProfit >= 0 ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Search Bar per Active Tab
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SearchField(
                  hint: isSalesTab ? 'Search sale title, notes...' : 'Search expense title, category, notes...',
                  onChanged: (val) {
                    setState(() {
                      if (isSalesTab) {
                        _saleSearch = val.toLowerCase().trim();
                      } else {
                        _expenseSearch = val.toLowerCase().trim();
                      }
                    });
                  },
                ),
              ),
              const Divider(height: 1),

              // TabBarView Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ==================== TAB 1: SALES ====================
                    _buildSalesList(sales),

                    // ==================== TAB 2: EXPENSES ====================
                    _buildExpensesList(expenses),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSalesList(List<Sale> sales) {
    final filtered = sales.where((s) {
      final titleMatch = s.title.toLowerCase().contains(_saleSearch);
      final notesMatch = s.notes != null && s.notes!.toLowerCase().contains(_saleSearch);
      return titleMatch || notesMatch;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.point_of_sale_outlined,
        title: _saleSearch.isNotEmpty ? 'No sales found' : 'No Sales for Selected Period',
        description: _saleSearch.isNotEmpty
            ? 'Try adjusting your search query or date range filter.'
            : 'Record daily cash sales or customer udhaar transactions with photo proof.',
        actionLabel: _saleSearch.isEmpty ? 'Record New Sale' : null,
        onAction: _saleSearch.isEmpty ? () => context.push('/sales/new') : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final sale = filtered[index];
        final isCredit = sale.paymentType == 'credit';

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
              onTap: () => _showSaleDetailModal(context, ref, sale),
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
                        isCredit ? Icons.credit_card : Icons.point_of_sale,
                        color: isCredit ? AppColors.danger : AppColors.success,
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
                              Text(sale.title, style: AppTypography.labelLarge),
                              const SizedBox(width: 6),
                              FutureBuilder<List<Attachment>>(
                                future: ref.read(databaseProvider).getAttachments('sale', sale.id),
                                builder: (ctx, snap) {
                                  if (snap.hasData && snap.data!.isNotEmpty) {
                                    return const Icon(Icons.image, size: 14, color: AppColors.primary);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormatter.formatDate(sale.date)} • ${isCredit ? "Credit / Udhar" : "Cash"}',
                            style: AppTypography.bodySmall,
                          ),
                          if (sale.notes != null && sale.notes!.isNotEmpty)
                            Text(
                              sale.notes!,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
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
                          CurrencyFormatter.formatPaisa(sale.finalAmountPaisa),
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isCredit ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: isCredit ? 'Udhar' : 'Cash',
                          type: isCredit ? StatusType.critical : StatusType.success,
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
  }

  Widget _buildExpensesList(List<Expense> expenses) {
    final filtered = expenses.where((e) {
      final titleMatch = e.title.toLowerCase().contains(_expenseSearch);
      final catMatch = e.category != null && e.category!.toLowerCase().contains(_expenseSearch);
      final notesMatch = e.note != null && e.note!.toLowerCase().contains(_expenseSearch);
      return titleMatch || catMatch || notesMatch;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: _expenseSearch.isNotEmpty ? 'No expenses found' : 'No Expenses for Selected Period',
        description: _expenseSearch.isNotEmpty
            ? 'Try adjusting your search query or date range filter.'
            : 'Track electricity, shop rent, salaries, tea, and daily expenses with receipt photos.',
        actionLabel: _expenseSearch.isEmpty ? 'Add Expense' : null,
        onAction: _expenseSearch.isEmpty ? () => context.push('/expenses/new') : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final expense = filtered[index];

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
              onTap: () => _showExpenseDetailModal(context, ref, expense),
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: AppRadii.roundedMd,
                      ),
                      child: const Icon(Icons.receipt, color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(expense.title, style: AppTypography.labelLarge),
                              const SizedBox(width: 6),
                              FutureBuilder<List<Attachment>>(
                                future: ref.read(databaseProvider).getAttachments('expense', expense.id),
                                builder: (ctx, snap) {
                                  if (snap.hasData && snap.data!.isNotEmpty) {
                                    return const Icon(Icons.image, size: 14, color: AppColors.warning);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${expense.category ?? "General"} • ${DateFormatter.formatDate(expense.date)}',
                            style: AppTypography.bodySmall,
                          ),
                          if (expense.note != null && expense.note!.isNotEmpty)
                            Text(
                              expense.note!,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
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
                          CurrencyFormatter.formatPaisa(expense.amountPaisa),
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: expense.category ?? 'General',
                          type: StatusType.warning,
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
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadii.roundedSm,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
