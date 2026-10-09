import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/customer_repository.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final int? customerId; // null = add new, provided = edit mode

  const AddCustomerScreen({super.key, this.customerId});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    final repo = ref.read(customerRepositoryProvider);
    final cust = await repo.getCustomerById(widget.customerId!);
    if (cust != null && mounted) {
      setState(() {
        _nameController.text = cust.name;
        _phoneController.text = cust.phone;
        _altPhoneController.text = cust.alternativePhone ?? '';
        _addressController.text = cust.address ?? '';
        _notesController.text = cust.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final isEditing = widget.customerId != null;

      if (isEditing) {
        await repo.updateCustomer(
          CustomersCompanion(
            id: drift.Value(widget.customerId!),
            name: drift.Value(_nameController.text.trim()),
            phone: drift.Value(_phoneController.text.trim()),
            alternativePhone: drift.Value(
              _altPhoneController.text.trim().isEmpty ? null : _altPhoneController.text.trim(),
            ),
            address: drift.Value(
              _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            ),
            notes: drift.Value(
              _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            ),
          ),
        );
      } else {
        await repo.addCustomer(
          CustomersCompanion(
            name: drift.Value(_nameController.text.trim()),
            phone: drift.Value(_phoneController.text.trim()),
            alternativePhone: drift.Value(
              _altPhoneController.text.trim().isEmpty ? null : _altPhoneController.text.trim(),
            ),
            address: drift.Value(
              _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            ),
            notes: drift.Value(
              _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            ),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Customer details updated successfully!' : 'Customer account created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save customer: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customerId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add New Customer'),
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
                    Text('Customer Profile', style: AppTypography.heading3),
                    const SizedBox(height: 4),
                    const Text('Track customer ledger and credit history. Phone is optional.', style: AppTypography.bodySmall),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Full Name *',
                      hint: 'e.g. Ali Khan, Dr. Usman, Ch. Aslam',
                      controller: _nameController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter customer name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Phone Number (Optional)',
                      hint: 'e.g. 0300-1234567',
                      keyboardType: TextInputType.phone,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Alternative Phone (Optional)',
                      hint: 'e.g. 0321-7654321',
                      keyboardType: TextInputType.phone,
                      controller: _altPhoneController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Address / Location (Optional)',
                      hint: 'e.g. House 4, Street 2, Main Bazaar',
                      controller: _addressController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Notes / Identification (Optional)',
                      hint: 'e.g. Regular patient, reference Dr. Tariq',
                      controller: _notesController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: isEditing ? 'Update Customer' : 'Save Customer',
                icon: Icons.check,
                backgroundColor: AppColors.purple,
                isLoading: _isLoading,
                onPressed: _saveCustomer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
