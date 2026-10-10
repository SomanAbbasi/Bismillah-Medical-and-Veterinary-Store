import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/files/attachment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/receipt_share_helper.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/customer_repository.dart';

class AddCreditScreen extends ConsumerStatefulWidget {
  final int? preselectedCustomerId;

  const AddCreditScreen({super.key, this.preselectedCustomerId});

  @override
  ConsumerState<AddCreditScreen> createState() => _AddCreditScreenState();
}

class _AddCreditScreenState extends ConsumerState<AddCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();
  final _attachmentService = AttachmentService();

  int? _selectedCustomerId;
  DateTime _date = DateTime.now();
  int _amountPaisa = 0;
  AttachmentResult? _attachedProof;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickProof(bool fromCamera) async {
    try {
      final result = fromCamera
          ? await _attachmentService.capturePhoto()
          : await _attachmentService.pickImageFromGallery();

      if (result != null && mounted) {
        setState(() => _attachedProof = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e')),
        );
      }
    }
  }

  Future<void> _submitCredit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a credit amount greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final db = ref.read(databaseProvider);
      final shopName = (await db.getSetting('shop_name')) ?? 'Bismillah Medical and Veterinary Store';

      final prevBalancePaisa = await repo.getCustomerBalance(_selectedCustomerId!);

      final txId = await repo.addCredit(
        customerId: _selectedCustomerId!,
        amountPaisa: _amountPaisa,
        date: _date,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      );

      // Save attachment proof if selected
      if (_attachedProof != null) {
        await db.insertAttachment(
          AttachmentsCompanion(
            entityType: const drift.Value('customer_transaction'),
            entityId: drift.Value(txId),
            filePath: drift.Value(_attachedProof!.relativePath),
            fileName: drift.Value(_attachedProof!.originalName),
            mimeType: drift.Value(_attachedProof!.mimeType),
            description: const drift.Value('Credit Slip / Record Proof'),
          ),
        );
      }

      final newBalancePaisa = prevBalancePaisa + _amountPaisa;
      final cust = await db.getCustomerById(_selectedCustomerId!);

      if (mounted && cust != null) {
        final receipt = ReceiptShareHelper.buildCustomerReceipt(
          storeName: shopName,
          customerName: cust.name,
          type: 'credit',
          amountPaisa: _amountPaisa,
          date: _date,
          previousBalancePaisa: prevBalancePaisa,
          newBalancePaisa: newBalancePaisa,
          reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

        await ReceiptShareHelper.showReceiptShareSheet(
          context: context,
          personName: cust.name,
          phone: cust.phone,
          formattedAmount: CurrencyFormatter.formatPaisa(_amountPaisa),
          typeLabel: 'Credit Recorded',
          receiptText: receipt,
          onDismissed: () {
            if (mounted) context.pop();
          },
        );
      } else if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record credit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Customer Credit'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text('Credit Entry', style: AppTypography.heading3),
                    const SizedBox(height: 4),
                    Text(
                      'Give medicine on credit. This increases customer receivable balance.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Select Customer *', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    customersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => AppErrorWidget(
                        isCompact: true,
                        error: err,
                        onRetry: () => ref.invalidate(customersWithBalancesStreamProvider),
                      ),
                      data: (customers) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.roundedMd,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedCustomerId,
                              hint: const Text('Choose customer account'),
                              isExpanded: true,
                              items: customers.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.customer.id,
                                  child: Text('${c.customer.name} (${c.customer.phone})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCustomerId = val),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DateField(
                      label: 'Date *',
                      selectedDate: _date,
                      onDateSelected: (d) => setState(() => _date = d),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CurrencyField(
                      label: 'Credit Amount *',
                      hint: 'e.g. 3,500',
                      autofocus: true,
                      onPaisaChanged: (p) => _amountPaisa = p,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Medicines / Details Note',
                      hint: 'e.g. 2 boxes Augmentin, 1 syrup',
                      controller: _noteController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Reference / Slip # (Optional)',
                      hint: 'e.g. Slip #104',
                      controller: _referenceController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Proof photo attachment
                    Text('Slip / Prescription Photo Proof', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    if (_attachedProof != null) ...[
                      FutureBuilder<String>(
                        future: _attachmentService.getAbsolutePath(_attachedProof!.relativePath),
                        builder: (context, snap) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: AppRadii.roundedMd,
                            ),
                            child: Row(
                              children: [
                                if (snap.hasData && File(snap.data!).existsSync())
                                  ClipRRect(
                                    borderRadius: AppRadii.roundedSm,
                                    child: Image.file(
                                      File(snap.data!),
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  const Icon(Icons.receipt, color: AppColors.primary),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    _attachedProof!.originalName,
                                    style: AppTypography.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _attachedProof = null),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickProof(true),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickProof(false),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Save Credit Transaction',
                icon: Icons.check,
                backgroundColor: AppColors.danger,
                isLoading: _isLoading,
                onPressed: _submitCredit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
