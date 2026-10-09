import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/inventory_repository.dart';

class AddEditMedicineScreen extends ConsumerStatefulWidget {
  final int? medicineId; // null if adding new

  const AddEditMedicineScreen({super.key, this.medicineId});

  @override
  ConsumerState<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends ConsumerState<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _batchController = TextEditingController();
  final _formulaController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Tablets');
  final _notesController = TextEditingController();

  DateTime _expiryDate = DateTime.now(); // Default to current date as requested
  int? _customReminderMonths; // null = use global settings
  bool _isDraft = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.medicineId != null) {
      _loadExistingMedicine();
    }
  }

  Future<void> _loadExistingMedicine() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final med = await repo.getMedicineById(widget.medicineId!);
    if (med != null && mounted) {
      setState(() {
        _nameController.text = med.name;
        _batchController.text = med.batchNumber ?? '';
        _formulaController.text = med.genericName;
        _brandController.text = med.brand;
        _categoryController.text = med.category.isNotEmpty ? med.category : 'Tablets';
        _notesController.text = med.notes ?? '';
        _expiryDate = med.expiryDate;
        _customReminderMonths = med.reminderMonths;
        _isDraft = med.isDraft;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _formulaController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);

      if (widget.medicineId == null) {
        await repo.addMedicine(
          name: _nameController.text.trim(),
          batchNumber: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
          genericName: _formulaController.text.trim().isEmpty ? null : _formulaController.text.trim(),
          expiryDate: _expiryDate,
          brand: _brandController.text.trim(),
          category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          reminderMonths: _customReminderMonths,
          isDraft: _isDraft,
        );
      } else {
        await repo.updateMedicine(
          id: widget.medicineId!,
          name: _nameController.text.trim(),
          batchNumber: _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
          genericName: _formulaController.text.trim().isEmpty ? null : _formulaController.text.trim(),
          expiryDate: _expiryDate,
          brand: _brandController.text.trim(),
          category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          reminderMonths: _customReminderMonths,
          isDraft: _isDraft,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.medicineId == null
                  ? 'Medicine saved successfully!'
                  : 'Medicine details updated!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save medicine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicineId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine Details' : 'Add New Medicine'),
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
                    Text('Medicine Details', style: AppTypography.heading3),
                    const SizedBox(height: 4),
                    const Text('Enter medicine name and expiry date to track expiry reminders.', style: AppTypography.bodySmall),
                    const SizedBox(height: AppSpacing.lg),

                    AppTextField(
                      label: 'Medicine Name *',
                      hint: 'e.g. Panadol, Augmentin, Flagyl',
                      controller: _nameController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter medicine name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Batch / Lot Number (Optional)',
                      hint: 'e.g. B-101, Lot 24, New Stock Nov',
                      controller: _batchController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Formula / Generic Name (Optional)',
                      hint: 'e.g. Paracetamol 500mg, Amoxicillin',
                      controller: _formulaController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DateField(
                      label: 'Expiry Date * (Default: Today)',
                      selectedDate: _expiryDate,
                      onDateSelected: (d) => setState(() => _expiryDate = d),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Brand / Manufacturer (Optional)',
                      hint: 'e.g. GSK, Pfizer, Getz, Abbott',
                      controller: _brandController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text('Medicine Type / Dosage Form', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: ['Tablets', 'Syrups', 'Capsules', 'Injections', 'Drops', 'Creams', 'Inhalers', 'Veterinary', 'General'].contains(_categoryController.text)
                          ? _categoryController.text
                          : 'Tablets',
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: const [
                        DropdownMenuItem(value: 'Tablets', child: Text('Tablets')),
                        DropdownMenuItem(value: 'Syrups', child: Text('Syrup / Suspension')),
                        DropdownMenuItem(value: 'Capsules', child: Text('Capsules')),
                        DropdownMenuItem(value: 'Injections', child: Text('Injections / Ampoules')),
                        DropdownMenuItem(value: 'Drops', child: Text('Drops (Eye / Ear / Nasal)')),
                        DropdownMenuItem(value: 'Creams', child: Text('Creams / Ointments')),
                        DropdownMenuItem(value: 'Inhalers', child: Text('Inhalers / Nebulizers')),
                        DropdownMenuItem(value: 'Veterinary', child: Text('Veterinary Medicine')),
                        DropdownMenuItem(value: 'General', child: Text('General / Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _categoryController.text = v);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text('Custom Expiry Reminder Alert', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int?>(
                      initialValue: _customReminderMonths,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Use Store Default Settings')),
                        DropdownMenuItem(value: 1, child: Text('Remind 30 Days (1 Month) Before')),
                        DropdownMenuItem(value: 2, child: Text('Remind 60 Days (2 Months) Before')),
                        DropdownMenuItem(value: 3, child: Text('Remind 90 Days (3 Months) Before')),
                        DropdownMenuItem(value: 6, child: Text('Remind 180 Days (6 Months) Before')),
                      ],
                      onChanged: (v) => setState(() => _customReminderMonths = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save as Draft', style: AppTypography.labelLarge),
                      subtitle: const Text('Keep in draft tab to complete later', style: AppTypography.bodySmall),
                      value: _isDraft,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _isDraft = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Notes / Remarks (Optional)',
                      hint: 'e.g. Store in cool place, Dr. Special recommendation',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              PrimaryButton(
                label: isEditing ? 'Update Medicine' : 'Save Medicine',
                icon: Icons.check_circle_outline,
                isLoading: _isLoading,
                onPressed: _saveMedicine,
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}
