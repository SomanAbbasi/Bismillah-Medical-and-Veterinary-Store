import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

class CurrencyField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<int>? onPaisaChanged;
  final FormFieldValidator<String>? validator;
  final String currencySymbol;
  final bool autofocus;

  const CurrencyField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onPaisaChanged,
    this.validator,
    this.currencySymbol = 'Rs.',
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (val) {
            if (onPaisaChanged != null) {
              final paisa = CurrencyFormatter.parseToPaisa(val);
              onPaisaChanged!(paisa);
            }
          },
          validator: validator,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint ?? '0.00',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              width: 50,
              child: Text(
                currencySymbol,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
