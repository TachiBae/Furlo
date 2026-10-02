import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../utils/app_theme.dart';

class RecordFilterOption {
  const RecordFilterOption(this.value, this.label);

  final String value;
  final String label;
}

class RecordFilterTabs extends StatelessWidget {
  const RecordFilterTabs({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<RecordFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.value == selectedValue;
          return ChoiceChip(
            showCheckmark: false,
            label: Text(option.label),
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: AppTypography.label.copyWith(
              color: selected
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.textDisabled,
            ),
            onSelected: (_) => onSelected(option.value),
          );
        },
      ),
    ),
  );
}

class PetSelectorTabs extends StatelessWidget {
  const PetSelectorTabs({
    super.key,
    required this.pets,
    required this.selectedPet,
    required this.onSelected,
  });

  final List<Pet> pets;
  final Pet selectedPet;
  final ValueChanged<Pet> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      scrollDirection: Axis.horizontal,
      itemCount: pets.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) {
        final pet = pets[index];
        final selected = pet.id == selectedPet.id;
        return ChoiceChip(
          showCheckmark: false,
          label: Text(pet.name),
          selected: selected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: AppTypography.label.copyWith(
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.textDisabled,
          ),
          onSelected: (_) => onSelected(pet),
        );
      },
    ),
  );
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgRadius,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: child,
    ),
  );
}

class RecordEmptyState extends StatelessWidget {
  const RecordEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onAction,
              style: AppComponents.primaryButton,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<bool> confirmRecordDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: AppTypography.h2),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class RecordDetailRow extends StatelessWidget {
  const RecordDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueIsEmpty = false,
  });

  final String label;
  final String value;
  final bool valueIsEmpty;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 96,
        child: Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: AppTypography.body.copyWith(
            color: valueIsEmpty
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
