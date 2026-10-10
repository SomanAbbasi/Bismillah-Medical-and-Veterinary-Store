import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController(text: 'BismillahStore');
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      await db.setSetting('shop_name', _shopNameController.text.trim());
      await db.setSetting('owner_name', _ownerNameController.text.trim());
      await db.setSetting('phone', _phoneController.text.trim());
      await db.setSetting('currency', 'PKR');
      await db.setSetting('onboarding_completed', 'true');

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadii.roundedLg,
                    ),
                    child: const Icon(
                      Icons.local_pharmacy,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Welcome to BismillahStore',
                    style: AppTypography.heading1,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Manage your medicines, expiry reminders, sales, expenses, and credit records in one place.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Shop / Pharmacy Name *',
                    hint: 'e.g. Arslan Medical Store',
                    controller: _shopNameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your shop name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Owner Name',
                    hint: 'e.g. Arslan Tariq',
                    controller: _ownerNameController,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Phone Number (Optional)',
                    hint: 'e.g. 0300-1234567',
                    keyboardType: TextInputType.phone,
                    controller: _phoneController,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    label: 'Get Started',
                    icon: Icons.arrow_forward,
                    isLoading: _isLoading,
                    onPressed: _handleGetStarted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
