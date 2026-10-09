import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum StatusType {
  expired,
  critical,
  warning,
  notice,
  success,
  info,
  neutral,
}

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  Color get _backgroundColor {
    switch (type) {
      case StatusType.expired:
      case StatusType.critical:
        return AppColors.dangerLight;
      case StatusType.warning:
        return AppColors.warningLight;
      case StatusType.notice:
        return const Color(0xFFFEF9C3);
      case StatusType.success:
        return AppColors.successLight;
      case StatusType.info:
        return AppColors.primarySubtle;
      case StatusType.neutral:
        return AppColors.surfaceVariant;
    }
  }

  Color get _textColor {
    switch (type) {
      case StatusType.expired:
      case StatusType.critical:
        return AppColors.dangerDark;
      case StatusType.warning:
        return AppColors.warningDark;
      case StatusType.notice:
        return const Color(0xFF854D0E);
      case StatusType.success:
        return AppColors.successDark;
      case StatusType.info:
        return AppColors.primaryDark;
      case StatusType.neutral:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: AppRadii.roundedSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _textColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: _textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
