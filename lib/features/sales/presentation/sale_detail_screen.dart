import 'dart:io';
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
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/sales_repository.dart';

class SaleDetailScreen extends ConsumerWidget {
  final int saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  void _showFullScreenImage(BuildContext context, File file, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => Share.shareXFiles([XFile(file.path)], text: title),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareReceipt(WidgetRef ref, SaleWithCustomer details, {List<String>? imagePaths}) async {
    final sale = details.sale;
    final isCredit = sale.paymentType == 'credit';

    final buffer = StringBuffer();
    buffer.writeln('*Bismillah Medical and Veterinary Store*');
    buffer.writeln('*Sale Receipt #${sale.id}*');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Title: ${sale.title}');
    buffer.writeln('Date: ${DateFormatter.formatDateTime(sale.date)}');
    if (details.customer != null) {
      buffer.writeln('Customer: ${details.customer!.name} (${details.customer!.phone})');
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln('Total Bill: ${CurrencyFormatter.formatPaisa(sale.finalAmountPaisa)}');
    buffer.writeln('Payment: ${isCredit ? "Credit / Udhaar" : "Cash Paid"}');

    if (sale.notes != null && sale.notes!.isNotEmpty) {
      buffer.writeln('Note: ${sale.notes}');
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('Thank you for visiting Bismillah Medical and Veterinary Store!');

    if (imagePaths != null && imagePaths.isNotEmpty) {
      final xfiles = imagePaths.where((p) => File(p).existsSync()).map((p) => XFile(p)).toList();
      if (xfiles.isNotEmpty) {
        await Share.shareXFiles(xfiles, text: buffer.toString(), subject: 'Sale Receipt #${sale.id}');
        return;
      }
    }

    await Share.share(buffer.toString(), subject: 'Sale Receipt #${sale.id}');
  }

  Future<void> _handleDeleteSale(BuildContext context, WidgetRef ref, Sale sale) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Move Sale to Recycle Bin?',
      message: 'Delete "${sale.title}" (${CurrencyFormatter.formatPaisa(sale.finalAmountPaisa)})? It will stay in the 30-day Trash and can be restored anytime.',
      confirmLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    final repo = ref.read(salesRepositoryProvider);
    await repo.softDeleteSale(sale.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${sale.title}" moved to Recycle Bin.'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await repo.restoreSale(sale.id);
            },
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final attachmentService = AttachmentService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Sale Record #$saleId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Sale',
            onPressed: () => context.push('/sales/$saleId/edit'),
          ),
        ],
      ),
      body: FutureBuilder<SaleWithCustomer?>(
        future: ref.read(salesRepositoryProvider).getSaleDetails(saleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final details = snapshot.data;
          if (details == null) {
            return const Center(child: Text('Sale record not found'));
          }

          final sale = details.sale;
          final isCredit = sale.paymentType == 'credit';

          return StreamBuilder<List<Attachment>>(
            stream: db.watchAttachments('sale', saleId),
            builder: (context, attachSnap) {
              final attachments = attachSnap.data ?? [];

              return ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  // Invoice Summary Card
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
                                const Text('BISMILLAH STORE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(sale.title, style: AppTypography.heading3),
                              ],
                            ),
                            StatusChip(
                              label: isCredit ? 'Credit / Udhaar' : 'Cash Paid',
                              type: isCredit ? StatusType.critical : StatusType.success,
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
                                Text('Date & Time', style: AppTypography.bodySmall),
                                Text(DateFormatter.formatDateTime(sale.date), style: AppTypography.labelLarge),
                              ],
                            ),
                            if (details.customer != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Customer', style: AppTypography.bodySmall),
                                  Text(details.customer!.name, style: AppTypography.labelLarge),
                                  Text(details.customer!.phone, style: AppTypography.bodySmall),
                                ],
                              ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Sale Amount', style: AppTypography.heading2),
                            Text(
                              CurrencyFormatter.formatPaisa(sale.finalAmountPaisa),
                              style: AppTypography.heading1.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadii.roundedMd,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(child: Text(sale.notes!, style: AppTypography.bodyMedium)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Multiple Pictures Grid Card
                  if (attachments.isNotEmpty) ...[
                    Text('Attached Picture Proofs (${attachments.length})', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        final attach = attachments[index];
                        return FutureBuilder<String>(
                          future: attachmentService.getAbsolutePath(attach.filePath),
                          builder: (context, pathSnap) {
                            if (!pathSnap.hasData) return const SizedBox();
                            final file = File(pathSnap.data!);
                            if (!file.existsSync()) return const SizedBox();

                            return InkWell(
                              onTap: () => _showFullScreenImage(context, file, 'Sale #${sale.id} Picture'),
                              child: ClipRRect(
                                borderRadius: AppRadii.roundedMd,
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Action Buttons
                  PrimaryButton(
                    label: 'Share Receipt on WhatsApp',
                    icon: Icons.share,
                    backgroundColor: const Color(0xFF25D366),
                    onPressed: () async {
                      final paths = <String>[];
                      for (final a in attachments) {
                        final p = await attachmentService.getAbsolutePath(a.filePath);
                        paths.add(p);
                      }
                      await _shareReceipt(ref, details, imagePaths: paths);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Edit Sale Details',
                    icon: Icons.edit_outlined,
                    onPressed: () => context.push('/sales/$saleId/edit'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Move to Recycle Bin',
                    icon: Icons.delete_outline,
                    onPressed: () => _handleDeleteSale(context, ref, sale),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
