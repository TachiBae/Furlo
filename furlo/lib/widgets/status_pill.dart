import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.status,
    this.isActive,
  });

  final String label;
  final String? status;
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    final color = switch (status?.toLowerCase()) {
      'overdue' => AppColors.danger,
      'due soon' => AppColors.warning,
      'completed' => AppColors.accent,
      'upcoming' => AppColors.primary,
      _ => isActive == true ? AppColors.accent : AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
