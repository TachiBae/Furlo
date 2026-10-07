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
      'overdue' => context.appColors.danger,
      'due soon' => context.appColors.textSecondary,
      'completed' => context.appColors.primary,
      'upcoming' => context.appColors.textSecondary,
      _ =>
        isActive == true
            ? context.appColors.primary
            : context.appColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: context.appColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
