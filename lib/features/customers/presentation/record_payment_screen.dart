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
import '../../../core/utils/whatsapp_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/customer_repository.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final int? preselectedCustomerId;

  const RecordPaymentScreen({super.key, this.preselectedCustomerId});

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();
  final _otherMethodController = TextEditingController();
  final _attachmentService = AttachmentService();

  int? _selectedCustomerId;
  DateTime _date = DateTime.now();
  int _amountPaisa = 0;
  String _paymentMethod = 'Cash';
  AttachmentResult? _attachedProof;
  bool _isLoading = false;

  final List<String> _methods = ['Cash', 'Bank Transfer', 'EasyPaisa / JazzCash', 'Other'];

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _referenceController.dispose();
    _otherMethodController.dispose();
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

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a payment amount greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final db = ref.read(databaseProvider);
      final shopName = (await db.getSetting('shop_name')) ?? 'Bismillah Medical and Veterinary Store';

      final prevBalancePaisa = await repo.getCustomerBalance(_selectedCustomerId!);

      await repo.recordPayment(
        customerId: _selectedCustomerId!,
        amountPaisa: _amountPaisa,
        date: _date,
        paymentMethod: _paymentMethod,
        otherPaymentMethod: _paymentMethod == 'Other' ? _otherMethodController.text.trim() : null,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      );

      // Save attachment proof if selected
      if (_attachedProof != null) {
        await db.insertAttachment(
          AttachmentsCompanion(
            entityType: const drift.Value('customer'),
            entityId: drift.Value(_selectedCustomerId!),
            filePath: drift.Value(_attachedProof!.relativePath),
            fileName: drift.Value(_attachedProof!.originalName),
            mimeType: drift.Value(_attachedProof!.mimeType),
            description: const drift.Value('Payment Slip / Screenshot Proof'),
          ),
        );
      }

      final remainingBalancePaisa = prevBalancePaisa - _amountPaisa;
      final cust = await db.getCustomerById(_selectedCustomerId!);

      if (mounted && cust != null) {
        final whatsappMsg = repo.generateWhatsAppPaymentMessage(
          shopName: shopName,
          customerName: cust.name,
          paymentAmountPaisa: _amountPaisa,
          previousBalancePaisa: prevBalancePaisa,
          remainingBalancePaisa: remainingBalancePaisa,
        );

        // Prompt user to send WhatsApp notification
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Recorded Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining Balance: ${CurrencyFormatter.formatPaisa(remainingBalancePaisa)}'),
                const SizedBox(height: 12),
                const Text('Would you like to send a WhatsApp receipt to the customer?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop();
                },
                child: const Text('Skip'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
                label: const Text('Send WhatsApp'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  context.pop();
                  await WhatsAppHelper.sendWhatsAppMessage(
                    phone: cust.phone,
                    message: whatsappMsg,
                  );
                },
              ),
            ],
          ),
        );
      } else if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
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
        title: const Text('Record Customer Payment'),
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
                    Text('Receive Payment', style: AppTypography.heading3),
                    const SizedBox(height: 4),
                    Text(
                      'Customer pays off their outstanding credit. This decreases their balance.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('Select Customer *', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    customersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error: $err'),
                      data: (customers) {
                        final selectedCust = customers
                            .where((c) => c.customer.id == _selectedCustomerId)
                            .firstOrNull;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
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
                            ),
                            if (selectedCust != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Current Outstanding Balance: ${CurrencyFormatter.formatPaisa(selectedCust.balancePaisa)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: selectedCust.balancePaisa > 0 ? AppColors.danger : AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DateField(
                      label: 'Payment Date *',
                      selectedDate: _date,
                      onDateSelected: (d) => setState(() => _date = d),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CurrencyField(
                      label: 'Payment Amount *',
                      hint: 'e.g. 1,500',
                      autofocus: true,
                      onPaisaChanged: (p) => _amountPaisa = p,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text('Payment Method *', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.roundedMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          isExpanded: true,
                          items: _methods.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m, style: AppTypography.bodyLarge));
                          }).toList(),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ),
                    ),
                    if (_paymentMethod == 'Other') ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        label: 'Specify Payment Method Name *',
                        hint: 'e.g. Cheque, Token, Barter',
                        controller: _otherMethodController,
                        validator: (val) {
                          if (_paymentMethod == 'Other' && (val == null || val.trim().isEmpty)) {
                            return 'Please enter custom payment method';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Notes / Remarks',
                      hint: 'e.g. Cash received at counter, partial payment',
                      controller: _noteController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Receipt / Bank Reference (Optional)',
                      hint: 'e.g. Cash Receipt #50, EasyPaisa TID',
                      controller: _referenceController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Proof photo attachment
                    Text('Payment Receipt / Screenshot Photo', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
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
                                  const Icon(Icons.receipt, color: AppColors.success),
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
                label: 'Save Payment Receipt',
                icon: Icons.check,
                backgroundColor: AppColors.success,
                isLoading: _isLoading,
                onPressed: _submitPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
