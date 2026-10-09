import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometrics();
    });
  }

  Future<void> _tryBiometrics() async {
    final lockState = ref.read(appLockServiceProvider);
    if (lockState.isLockEnabled && !lockState.isUnlocked && lockState.isBiometricEnabled) {
      final success = await ref.read(appLockServiceProvider.notifier).authenticateWithBiometrics();
      if (!success && mounted) {
        setState(() => _errorMessage = 'Biometrics cancelled or failed. Please enter PIN.');
      }
    }
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length >= 4) {
        _verifyEnteredPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyEnteredPin() async {
    final success = await ref.read(appLockServiceProvider.notifier).verifyPin(_enteredPin);
    if (!success) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Try again.';
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockServiceProvider);

    if (!lockState.isLockEnabled || lockState.isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('BismillahStore Locked', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.xs),
            const Text('Enter your security PIN to unlock', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.xl),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.primary : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            const Spacer(),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3'].map((d) => _NumpadButton(digit: d, onTap: () => _onDigitPress(d))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6'].map((d) => _NumpadButton(digit: d, onTap: () => _onDigitPress(d))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9'].map((d) => _NumpadButton(digit: d, onTap: () => _onDigitPress(d))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (lockState.isBiometricEnabled)
                        IconButton(
                          icon: const Icon(Icons.fingerprint, size: 36, color: AppColors.primary),
                          onPressed: _tryBiometrics,
                        )
                      else
                        const SizedBox(width: 64),
                      _NumpadButton(digit: '0', onTap: () => _onDigitPress('0')),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, size: 28, color: AppColors.textSecondary),
                        onPressed: _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _NumpadButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
