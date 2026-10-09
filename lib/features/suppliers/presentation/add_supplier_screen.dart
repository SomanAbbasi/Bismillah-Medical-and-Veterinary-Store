import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/supplier_repository.dart';

class AddSupplierScreen extends ConsumerStatefulWidget {
  final int? supplierId; // If provided, edit mode

  const AddSupplierScreen({super.key, this.supplierId});

  @override
  ConsumerState<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends ConsumerState<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(supplierRepositoryProvider);
    final s = await repo.getSupplierById(widget.supplierId!);
    if (s != null && mounted) {
      setState(() {
        _nameController.text = s.name;
        _phoneController.text = s.phone;
        _companyController.text = s.company ?? '';
        _addressController.text = s.address ?? '';
        _notesController.text = s.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(supplierRepositoryProvider);
      if (widget.supplierId == null) {
        await repo.addSupplier(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await repo.updateSupplier(
          id: widget.supplierId!,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.supplierId == null ? 'Supplier added successfully' : 'Supplier updated'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplierId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Supplier' : 'Add New Supplier'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
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
                    Text('Supplier Details', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Supplier / Distributor Name *',
                      hint: 'e.g. Ali Pharma Distributors, Bilal Medicines',
                      controller: _nameController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Supplier name is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Contact Phone Number (Optional)',
                      hint: 'e.g. 0300-1234567',
                      keyboardType: TextInputType.phone,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Company / Distribution House (Optional)',
                      hint: 'e.g. GlaxoSmithKline Agency, Getz Distributor',
                      controller: _companyController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Office / Warehouse Address (Optional)',
                      hint: 'e.g. Wholesale Market, Shop #12',
                      controller: _addressController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Notes / Payment Terms (Optional)',
                      hint: 'e.g. 15 days credit period, Delivery on Mondays',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: isEditing ? 'Update Supplier' : 'Save Supplier',
                icon: Icons.check,
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
