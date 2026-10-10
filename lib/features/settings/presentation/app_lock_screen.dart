import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockScreen({super.key, required this.child});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAuthenticate();
    });
  }

  Future<void> _tryAuthenticate() async {
    final lockState = ref.read(appLockServiceProvider);
    if (lockState.isLockEnabled && !lockState.isUnlocked) {
      await ref.read(appLockServiceProvider.notifier).authenticate();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('BismillahStore Secured', style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Authenticate with your phone\'s fingerprint, face, or device PIN to continue.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (lockState.lastError != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadii.roundedMd,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          lockState.lastError!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Unlock with Phone Security',
                icon: Icons.lock_open,
                onPressed: _tryAuthenticate,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
