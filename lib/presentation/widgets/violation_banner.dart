import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Dismissible violation alert banner shown when a slot violation is detected.
/// Displays a red/amber banner with an icon, message, and dismiss button.
class ViolationBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final bool isCritical;

  const ViolationBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.isCritical = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCritical ? AppColors.error : AppColors.warning;
    final icon = isCritical ? Icons.error_rounded : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: color.withOpacity(0.7), size: 16),
          ),
        ],
      ),
    );
  }
}
