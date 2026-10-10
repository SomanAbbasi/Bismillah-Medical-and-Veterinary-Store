import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/receipt_share_helper.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/currency_field.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/supplier_repository.dart';

class AddSupplierPayableScreen extends ConsumerStatefulWidget {
  final int? preselectedSupplierId;

  const AddSupplierPayableScreen({super.key, this.preselectedSupplierId});

  @override
  ConsumerState<AddSupplierPayableScreen> createState() => _AddSupplierPayableScreenState();
}

class _AddSupplierPayableScreenState extends ConsumerState<AddSupplierPayableScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedSupplierId;
  DateTime _date = DateTime.now();
  int _amountPaisa = 0;
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.preselectedSupplierId;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier')),
      );
      return;
    }
    if (_amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than zero')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final repo = ref.read(supplierRepositoryProvider);
      final prevBalancePaisa = await repo.getSupplierBalancePaisa(_selectedSupplierId!);
      final newBalancePaisa = prevBalancePaisa + _amountPaisa;
      final shopName = await db.getSetting('shop_name') ?? 'Bismillah Medical & Veterinary Store';
      final supplier = await db.getSupplierById(_selectedSupplierId!);

      await repo.addTransaction(
        supplierId: _selectedSupplierId!,
        date: _date,
        amountPaisa: _amountPaisa,
        type: 'payable',
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted && supplier != null) {
        final receipt = ReceiptShareHelper.buildSupplierReceipt(
          storeName: shopName,
          supplierName: supplier.name,
          type: 'payable',
          amountPaisa: _amountPaisa,
          date: _date,
          previousBalancePaisa: prevBalancePaisa,
          newBalancePaisa: newBalancePaisa,
          reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

        await ReceiptShareHelper.showReceiptShareSheet(
          context: context,
          personName: supplier.name,
          phone: supplier.phone,
          formattedAmount: CurrencyFormatter.formatPaisa(_amountPaisa),
          typeLabel: 'Supplier Bill Recorded',
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersWithBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Supplier Payable (Bill)'),
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
                    Text('Payable Details', style: AppTypography.heading3),
                    const SizedBox(height: 4),
                    const Text('Record a medicine supply invoice or bill owed to a supplier.', style: AppTypography.bodySmall),
                    const SizedBox(height: AppSpacing.lg),

                    // Supplier Selector
                    suppliersAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error loading suppliers: $err'),
                      data: (suppliers) {
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedSupplierId,
                          decoration: const InputDecoration(
                            labelText: 'Select Supplier *',
                            border: OutlineInputBorder(),
                          ),
                          items: suppliers.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.supplier.id,
                              child: Text('${s.supplier.name} (${s.supplier.phone})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedSupplierId = val),
                          validator: (v) => v == null ? 'Please select a supplier' : null,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DateField(
                      label: 'Bill / Invoice Date *',
                      selectedDate: _date,
                      onDateSelected: (d) => setState(() => _date = d),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    CurrencyField(
                      label: 'Bill Amount (PKR) *',
                      onPaisaChanged: (paisa) => _amountPaisa = paisa,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Invoice / Bill Number (Optional)',
                      hint: 'e.g. INV-90412, Bill #45',
                      controller: _referenceController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Notes / Particulars (Optional)',
                      hint: 'e.g. Antibiotics stock order, Monthly medicine shipment',
                      controller: _noteController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Save Payable Bill',
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
