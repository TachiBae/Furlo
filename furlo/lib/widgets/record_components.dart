import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../utils/app_theme.dart';

class RecordFilterOption {
  const RecordFilterOption(this.value, this.label);

  final String value;
  final String label;
}

/// Form-field labels for record forms (vaccinations, health). Fill, borders
/// and text styles come from the theme's inputDecorationTheme.
InputDecoration recordFormDecoration(
  BuildContext context, {
  required String label,
  String? hint,
}) => InputDecoration(labelText: label, hintText: hint);

/// The single chip recipe for every selectable chip in the app: the pet
/// selector, the record filter tabs, and the feeding day picker.
///
/// Keeping one recipe is what stops a chip from silently falling back to the
/// framework's default Material colours inside the dark theme.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    showCheckmark: false,
    label: Text(label),
    tooltip: tooltip,
    selected: selected,
    selectedColor: context.appColors.primary,
    backgroundColor: context.appColors.surface,
    labelStyle: AppTypography.label.copyWith(
      color: selected
          ? context.appColors.textOnPrimary
          : context.appColors.textSecondary,
    ),
    side: BorderSide(
      color: selected
          ? context.appColors.primary
          : context.appColors.textDisabled,
    ),
    onSelected: onSelected,
  );
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
          return AppChoiceChip(
            label: option.label,
            selected: option.value == selectedValue,
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
        return AppChoiceChip(
          label: pet.name,
          selected: pet.id == selectedPet.id,
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
    color: context.appColors.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgRadius,
      side: BorderSide(
        color: context.appColors.primary.withValues(alpha: 0.25),
      ),
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
          Icon(icon, size: 48, color: context.appColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: context.appColors.textSecondary,
            ),
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
        backgroundColor: context.appColors.surface,
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

/// Asks before throwing away unsaved form input.
///
/// Returns true only when the user chooses to discard. Named separately from
/// [confirmRecordDelete] because discarding an edit and deleting a record are
/// different consequences and should not share a verb.
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String title = 'Discard changes?',
  String message = 'Your edits will be lost.',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(title, style: AppTypography.h2),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
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
          style: AppTypography.body.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: AppTypography.body.copyWith(
            color: valueIsEmpty
                ? context.appColors.textSecondary
                : context.appColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

/// Placeholder cards shown while a record list loads, shaped like
/// [RecordCard] rows so the screen keeps its layout instead of flashing a
/// lone spinner. Deliberately static: no shimmer, so it respects reduced
/// motion and never keeps a frame loop alive.
class RecordListSkeleton extends StatelessWidget {
  const RecordListSkeleton({
    super.key,
    this.count = 3,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      0,
    ),
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bar = context.appColors.textDisabled.withValues(alpha: 0.25);
    Widget line(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: bar, borderRadius: AppRadius.smRadius),
      ),
    );
    return Semantics(
      label: 'Loading',
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              for (var index = 0; index < count; index++)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(
                      color: context.appColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: bar,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            line(0.6, 14),
                            const SizedBox(height: AppSpacing.sm),
                            line(0.4, 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
