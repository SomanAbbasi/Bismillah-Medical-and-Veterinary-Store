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
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/expense_repository.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final int? expenseId; // null if creating, int if editing

  const AddExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Store Expense');
  final _categoryController = TextEditingController(text: 'General');
  final _notesController = TextEditingController();
  final _attachmentService = AttachmentService();

  DateTime _expenseDate = DateTime.now();
  int _amountPaisa = 0;
  final List<AttachmentResult> _attachedReceipts = [];
  List<Attachment> _existingAttachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExistingExpense();
    }
  }

  Future<void> _loadExistingExpense() async {
    final repo = ref.read(expenseRepositoryProvider);
    final db = ref.read(databaseProvider);
    final exp = await repo.getExpenseById(widget.expenseId!);

    if (exp != null && mounted) {
      final attach = await db.getAttachments('expense', exp.id);
      setState(() {
        _titleController.text = exp.title;
        _expenseDate = exp.date;
        _amountPaisa = exp.amountPaisa;
        _categoryController.text = exp.category ?? 'General';
        _notesController.text = exp.note ?? '';
        _existingAttachments = attach;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(bool fromCamera) async {
    try {
      final result = fromCamera
          ? await _attachmentService.capturePhoto()
          : await _attachmentService.pickImageFromGallery();

      if (result != null && mounted) {
        setState(() => _attachedReceipts.add(result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e')),
        );
      }
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense amount greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final db = ref.read(databaseProvider);
      final isEditing = widget.expenseId != null;
      final int effectiveExpenseId;

      if (isEditing) {
        effectiveExpenseId = widget.expenseId!;
        await repo.updateExpense(
          id: effectiveExpenseId,
          date: _expenseDate,
          title: _titleController.text.trim(),
          amountPaisa: _amountPaisa,
          category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
          note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        effectiveExpenseId = await repo.addExpense(
          date: _expenseDate,
          title: _titleController.text.trim(),
          amountPaisa: _amountPaisa,
          category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
          note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      // Save attachment proof if selected
      for (final receipt in _attachedReceipts) {
        await db.insertAttachment(
          AttachmentsCompanion(
            entityType: const drift.Value('expense'),
            entityId: drift.Value(effectiveExpenseId),
            filePath: drift.Value(receipt.relativePath),
            fileName: drift.Value(receipt.originalName),
            mimeType: drift.Value(receipt.mimeType),
            description: const drift.Value('Expense Bill Proof'),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Expense updated successfully!' : 'Expense recorded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorFormatter.toUserFriendlyMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expenseId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense Record' : 'Add Store Expense'),
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
                    Text('Expense Details', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.lg),

                    AppTextField(
                      label: 'Expense Title *',
                      hint: 'e.g. Tea & Refreshment, Electric Bill',
                      controller: _titleController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter expense title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DateField(
                      label: 'Date *',
                      selectedDate: _expenseDate,
                      onDateSelected: (d) => setState(() => _expenseDate = d),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CurrencyField(
                      label: 'Expense Amount *',
                      hint: 'e.g. 500',
                      autofocus: !isEditing,
                      onPaisaChanged: (p) => _amountPaisa = p,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Category (Optional)',
                      hint: 'e.g. Utility, Tea, Maintenance, Rent',
                      controller: _categoryController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Notes / Remarks (Optional)',
                      hint: 'e.g. SEPCO electricity bill for September',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Picture Attachments Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text('Bill / Receipt Photos (${_attachedReceipts.length + _existingAttachments.length})', style: AppTypography.labelLarge),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: AppColors.warning),
                              onPressed: () => _pickReceipt(true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: AppColors.warning),
                              onPressed: () => _pickReceipt(false),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    if (_attachedReceipts.isNotEmpty || _existingAttachments.isNotEmpty) ...[
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
                            ..._attachedReceipts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final receipt = entry.value;

                              return FutureBuilder<String>(
                                future: _attachmentService.getAbsolutePath(receipt.relativePath),
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
                                            onTap: () => setState(() => _attachedReceipts.removeAt(index)),
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
                              onPressed: () => _pickReceipt(true),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickReceipt(false),
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
                label: isEditing ? 'Update Expense' : 'Save Expense',
                icon: Icons.check,
                backgroundColor: AppColors.warning,
                isLoading: _isLoading,
                onPressed: _submitExpense,
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}
