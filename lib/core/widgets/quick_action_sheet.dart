import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class QuickActionSheet extends StatelessWidget {
  const QuickActionSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QuickActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.point_of_sale,
        label: 'Add Sale',
        subtitle: 'Cash or credit bill',
        color: AppColors.primary,
        onTap: () {
          Navigator.pop(context);
          context.push('/sales/new');
        },
      ),
      _ActionItem(
        icon: Icons.receipt_long,
        label: 'Add Expense',
        subtitle: 'Daily bills & store costs',
        color: AppColors.warning,
        onTap: () {
          Navigator.pop(context);
          context.push('/expenses/new');
        },
      ),
      _ActionItem(
        icon: Icons.medication,
        label: 'Add Medicine',
        subtitle: 'New medicine & batch',
        color: AppColors.success,
        onTap: () {
          Navigator.pop(context);
          context.push('/inventory/new');
        },
      ),
      _ActionItem(
        icon: Icons.person_add,
        label: 'Add Customer',
        subtitle: 'New credit account',
        color: AppColors.purple,
        onTap: () {
          Navigator.pop(context);
          context.push('/customers/new');
        },
      ),
      _ActionItem(
        icon: Icons.credit_card,
        label: 'Add Credit',
        subtitle: 'Record medicine on credit',
        color: AppColors.danger,
        onTap: () {
          Navigator.pop(context);
          context.push('/customers/credit');
        },
      ),
      _ActionItem(
        icon: Icons.payments,
        label: 'Record Payment',
        subtitle: 'Receive customer payment',
        color: AppColors.success,
        onTap: () {
          Navigator.pop(context);
          context.push('/customers/payment');
        },
      ),
      _ActionItem(
        icon: Icons.local_shipping,
        label: 'Add Supplier',
        subtitle: 'New supplier record',
        color: AppColors.primaryLight,
        onTap: () {
          Navigator.pop(context);
          context.push('/suppliers/new');
        },
      ),
      _ActionItem(
        icon: Icons.post_add,
        label: 'Supplier Bill',
        subtitle: 'Record payable invoice',
        color: AppColors.warning,
        onTap: () {
          Navigator.pop(context);
          context.push('/customers?tab=supplier');
        },
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: AppSpacing.sheetPadding,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadii.roundedSm,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quick Actions', style: AppTypography.heading2),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = actions[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.12),
                      borderRadius: AppRadii.roundedMd,
                    ),
                    child: Icon(a.icon, color: a.color, size: 22),
                  ),
                  title: Text(a.label, style: AppTypography.labelLarge),
                  subtitle: Text(a.subtitle, style: AppTypography.bodySmall),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                  onTap: a.onTap,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
