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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../customers/data/customer_repository.dart';
import '../data/sales_repository.dart';

class NewSaleScreen extends ConsumerStatefulWidget {
  final int? saleId; // null if creating new, int if editing

  const NewSaleScreen({super.key, this.saleId});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Store Sale');
  final _notesController = TextEditingController();
  final _attachmentService = AttachmentService();

  DateTime _saleDate = DateTime.now();
  String _paymentType = 'cash'; // 'cash' or 'credit'
  int? _selectedCustomerId;
  int _amountPaisa = 0;

  final List<AttachmentResult> _attachedProofs = [];
  List<Attachment> _existingAttachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.saleId != null) {
      _loadExistingSale();
    }
  }

  Future<void> _loadExistingSale() async {
    final repo = ref.read(salesRepositoryProvider);
    final db = ref.read(databaseProvider);
    final details = await repo.getSaleDetails(widget.saleId!);

    if (details != null && mounted) {
      final s = details.sale;
      final attach = await db.getAttachments('sale', s.id);

      setState(() {
        _titleController.text = s.title;
        _notesController.text = s.notes ?? '';
        _saleDate = s.date;
        _paymentType = s.paymentType;
        _selectedCustomerId = s.customerId;
        _amountPaisa = s.finalAmountPaisa;
        _existingAttachments = attach;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProof(bool fromCamera) async {
    try {
      final result = fromCamera
          ? await _attachmentService.capturePhoto()
          : await _attachmentService.pickImageFromGallery();

      if (result != null && mounted) {
        setState(() => _attachedProofs.add(result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e')),
        );
      }
    }
  }

  Future<void> _showQuickAddCustomerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Customer Name *', hintText: 'e.g. Haji Rashid'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', hintText: '0300-1234567'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final repo = ref.read(customerRepositoryProvider);
              final id = await repo.addCustomer(
                CustomersCompanion(
                  name: drift.Value(name),
                  phone: drift.Value(phoneController.text.trim().isEmpty ? '0300-0000000' : phoneController.text.trim()),
                ),
              );

              if (mounted) {
                setState(() => _selectedCustomerId = id);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added and selected for this sale.')),
      );
    }
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    if (_amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sale amount greater than 0')),
      );
      return;
    }

    if (_paymentType == 'credit' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer for credit (udhaar) sale')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      final db = ref.read(databaseProvider);
      final isEditing = widget.saleId != null;
      final int effectiveSaleId;

      if (isEditing) {
        effectiveSaleId = widget.saleId!;
        await repo.updateSale(
          id: effectiveSaleId,
          date: _saleDate,
          title: _titleController.text.trim(),
          amountPaisa: _amountPaisa,
          paymentType: _paymentType,
          customerId: _selectedCustomerId,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        effectiveSaleId = await repo.createSale(
          date: _saleDate,
          title: _titleController.text.trim(),
          amountPaisa: _amountPaisa,
          paymentType: _paymentType,
          customerId: _selectedCustomerId,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      // Save new attached proofs
      for (final proof in _attachedProofs) {
        await db.insertAttachment(
          AttachmentsCompanion(
            entityType: const drift.Value('sale'),
            entityId: drift.Value(effectiveSaleId),
            filePath: drift.Value(proof.relativePath),
            fileName: drift.Value(proof.originalName),
            mimeType: drift.Value(proof.mimeType),
            description: const drift.Value('Sale Picture Proof'),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Sale updated successfully!' : 'Sale saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sale: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersWithBalancesStreamProvider);
    final isCredit = _paymentType == 'credit';
    final isEditing = widget.saleId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sale Record' : 'Add New Sale'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Type & Customer Selector Card
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
                        Text('Payment Mode', style: AppTypography.heading3),
                        DateField(
                          label: 'Sale Date',
                          selectedDate: _saleDate,
                          onDateSelected: (d) => setState(() => _saleDate = d),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _paymentType = 'cash'),
                            borderRadius: AppRadii.roundedMd,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !isCredit ? AppColors.successLight : AppColors.surface,
                                borderRadius: AppRadii.roundedMd,
                                border: Border.all(
                                  color: !isCredit ? AppColors.success : AppColors.border,
                                  width: !isCredit ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payments, color: !isCredit ? AppColors.success : AppColors.textMuted, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cash Sale',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: !isCredit ? AppColors.success : AppColors.textSecondary,
                                      fontWeight: !isCredit ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _paymentType = 'credit'),
                            borderRadius: AppRadii.roundedMd,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isCredit ? AppColors.dangerLight : AppColors.surface,
                                borderRadius: AppRadii.roundedMd,
                                border: Border.all(
                                  color: isCredit ? AppColors.danger : AppColors.border,
                                  width: isCredit ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card, color: isCredit ? AppColors.danger : AppColors.textMuted, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Credit / Udhaar',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: isCredit ? AppColors.danger : AppColors.textSecondary,
                                      fontWeight: isCredit ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isCredit) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Customer *', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: _showQuickAddCustomerDialog,
                            icon: const Icon(Icons.person_add_alt_1, size: 16),
                            label: const Text('+ New Customer'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      customersAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Error: $err'),
                        data: (customers) {
                          if (customers.isEmpty) {
                            return OutlinedButton.icon(
                              onPressed: _showQuickAddCustomerDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('No customers found. Tap to add new customer.'),
                            );
                          }

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
                                  final bal = c.balancePaisa;
                                  final balStr = bal > 0 ? ' (Owes: ${CurrencyFormatter.formatPaisa(bal)})' : '';
                                  return DropdownMenuItem<int>(
                                    value: c.customer.id,
                                    child: Text(
                                      '${c.customer.name} - ${c.customer.phone}$balStr',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedCustomerId = v),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Sale Details & Amount Card
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
                    Text('Sale Details', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Sale Title / Description *',
                      hint: 'e.g. Evening counter sale, Veterinary medicines',
                      controller: _titleController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CurrencyField(
                      label: 'Total Sale Amount *',
                      hint: 'e.g. 1,250',
                      autofocus: !isEditing,
                      onPaisaChanged: (p) => setState(() => _amountPaisa = p),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Notes / Remarks (Optional)',
                      hint: 'e.g. Prescribed by Dr. Tariq, Paid cash at counter',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Multiple Pictures Proof Attachment Card
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
                        Row(
                          children: [
                            const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Pictures & Proofs (${_attachedProofs.length + _existingAttachments.length})', style: AppTypography.labelLarge),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: AppColors.primary),
                              tooltip: 'Camera',
                              onPressed: () => _pickProof(true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: AppColors.primary),
                              tooltip: 'Gallery',
                              onPressed: () => _pickProof(false),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Snap or attach multiple photos of receipts, handwritten slips, or prescriptions.', style: AppTypography.bodySmall),
                    const SizedBox(height: AppSpacing.md),

                    if (_attachedProofs.isNotEmpty || _existingAttachments.isNotEmpty) ...[
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._existingAttachments.map((attach) {
                              return FutureBuilder<String>(
                                future: _attachmentService.getAbsolutePath(attach.filePath),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox();
                                  final file = File(snap.data!);
                                  if (!file.existsSync()) return const SizedBox();

                                  return Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: AppRadii.roundedMd,
                                          child: Image.file(file, width: 85, height: 85, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () async {
                                              final db = ref.read(databaseProvider);
                                              await db.deleteAttachment(attach.id);
                                              setState(() {
                                                _existingAttachments.removeWhere((a) => a.id == attach.id);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                            ..._attachedProofs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final proof = entry.value;

                              return FutureBuilder<String>(
                                future: _attachmentService.getAbsolutePath(proof.relativePath),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox();
                                  final file = File(snap.data!);

                                  return Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: AppRadii.roundedMd,
                                          child: Image.file(file, width: 85, height: 85, fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _attachedProofs.removeAt(index)),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, size: 16, color: Colors.white),
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
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: () => _pickProof(true),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Add Photo (Camera)'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: () => _pickProof(false),
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Add Photo (Gallery)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: isEditing ? 'Update Sale Record' : 'Save Sale Record',
                icon: Icons.check_circle_outline,
                isLoading: _isLoading,
                onPressed: _submitSale,
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}
