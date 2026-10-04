import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/feeding_entry.dart';
import '../../models/pet.dart';
import '../../providers/furlo_state.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../pets/pet_onboarding_screen.dart';

class FeedingScreen extends StatefulWidget {
  const FeedingScreen({
    super.key,
    required this.repository,
    this.notificationService = const NoOpNotificationService(),
  });

  final PetRepository repository;
  final NotificationService notificationService;

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen> {
  late final FurloState _furloState;
  int? _observedSelectedPetId;
  List<FeedingEntry> _schedules = [];
  bool _loading = true;
  bool _saving = false;

  Pet? get _selectedPet => _furloState.selectedPet;

  @override
  void initState() {
    super.initState();
    _furloState = context.read<FurloState>();
    _observedSelectedPetId = _selectedPet?.id;
    _furloState.addListener(_onFurloStateChanged);
    _loadSchedules();
  }

  @override
  void dispose() {
    _furloState.removeListener(_onFurloStateChanged);
    super.dispose();
  }

  void _onFurloStateChanged() {
    final selectedPetId = _selectedPet?.id;
    if (selectedPetId == _observedSelectedPetId) return;
    _observedSelectedPetId = selectedPetId;
    if (!mounted) return;
    setState(() => _schedules = []);
    unawaited(_loadSchedules());
  }

  Future<void> _loadSchedules() async {
    final petId = _selectedPet?.id;
    if (petId == null) {
      if (mounted) {
        setState(() {
          _schedules = [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final schedules = await widget.repository.getFeedingSchedules(petId);
      if (mounted && _selectedPet?.id == petId) {
        setState(() {
          _schedules = schedules;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _schedules = [];
          _loading = false;
        });
        _showMessage('Feeding schedules could not be loaded.');
      }
    }
  }

  Future<void> _choosePet(int? petId) async {
    final selected = _furloState.pets
        .where((pet) => pet.id == petId)
        .firstOrNull;
    if (selected == null || selected.id == _selectedPet?.id) return;
    _furloState.selectPet(selected);
  }

  Future<void> _editSchedule([FeedingEntry? existing]) async {
    final petId = _selectedPet?.id;
    if (petId == null || _saving) return;
    final formKey = GlobalKey<FormState>();
    var name = existing?.name ?? '';
    var time = _parseTime(existing?.time ?? '08:00');
    var frequency = existing?.frequency ?? 'Daily';
    var scheduledDate = existing?.scheduledDate ?? DateTime.now();
    var selectedPetId = existing?.petId ?? petId;
    var daysOfWeek = [...?existing?.daysOfWeek];
    var portionSize = existing?.portionSize ?? '';
    var remindMe = existing?.remindMe ?? false;
    final petsWithIds = _furloState.pets
        .where((pet) => pet.id != null)
        .toList();

    final result = await showDialog<FeedingEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Feeding Schedule' : 'Edit Schedule',
                style: AppTypography.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your pet’s meal routine',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (existing == null && petsWithIds.length > 1) ...[
                      DropdownButtonFormField<int>(
                        key: ValueKey('schedule-pet-$selectedPetId'),
                        initialValue: selectedPetId,
                        decoration: _fieldDecoration('Pet'),
                        items: petsWithIds
                            .map(
                              (pet) => DropdownMenuItem(
                                value: pet.id,
                                child: Text(pet.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedPetId = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      initialValue: name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      onSaved: (value) => name = value?.trim() ?? '',
                      decoration: _fieldDecoration(
                        'Meal name',
                        hint: 'e.g. Breakfast',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'A meal name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: AppRadius.mdRadius,
                      onTap: () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (selected != null) {
                          setDialogState(() => time = selected);
                        }
                      },
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          'Time',
                          prefixIcon: const Icon(Icons.schedule_outlined),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            time.format(context),
                            style: AppTypography.body,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: _fieldDecoration('Frequency'),
                      items:
                          const [
                                'Does not repeat',
                                'Daily',
                                'Twice daily',
                                'Weekly',
                                'Custom',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            frequency = value;
                            if (value == 'Daily' ||
                                value == 'Twice daily' ||
                                value == FeedingEntry.doesNotRepeat) {
                              daysOfWeek.clear();
                            }
                          });
                        }
                      },
                    ),
                    if (frequency == FeedingEntry.doesNotRepeat) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: AppRadius.mdRadius,
                        onTap: () async {
                          final now = DateTime.now();
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: scheduledDate,
                            firstDate:
                                scheduledDate.isBefore(
                                  DateTime(now.year, now.month, now.day),
                                )
                                ? scheduledDate
                                : DateTime(now.year, now.month, now.day),
                            lastDate: DateTime(now.year + 10),
                          );
                          if (selected != null) {
                            setDialogState(() => scheduledDate = selected);
                          }
                        },
                        child: InputDecorator(
                          decoration: _fieldDecoration(
                            'Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(scheduledDate),
                              style: AppTypography.body,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (frequency == 'Weekly' || frequency == 'Custom') ...[
                      const SizedBox(height: 16),
                      Text('Days of week', style: AppTypography.label),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                            .asMap()
                            .entries
                            .map((day) {
                              final dayNumber = day.key + 1;
                              return ChoiceChip(
                                label: Text(day.value),
                                tooltip: const [
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                  'Sunday',
                                ][day.key],
                                selected: daysOfWeek.contains(dayNumber),
                                onSelected: (selected) => setDialogState(() {
                                  if (selected) {
                                    daysOfWeek.add(dayNumber);
                                  } else {
                                    daysOfWeek.remove(dayNumber);
                                  }
                                }),
                              );
                            })
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: portionSize,
                      textCapitalization: TextCapitalization.sentences,
                      onSaved: (value) => portionSize = value?.trim() ?? '',
                      decoration: _fieldDecoration(
                        'Portion size (optional)',
                        hint: 'e.g. 1 cup',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Remind me', style: AppTypography.body),
                      value: remindMe,
                      onChanged: (value) =>
                          setDialogState(() => remindMe = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: AppTypography.bodyStrong,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: AppComponents.primaryButton,
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      formKey.currentState!.save();
                      Navigator.pop(
                        dialogContext,
                        FeedingEntry(
                          id: existing?.id,
                          petId: selectedPetId,
                          name: name,
                          time: _formatTime(time),
                          frequency: frequency,
                          scheduledDate: frequency == FeedingEntry.doesNotRepeat
                              ? scheduledDate
                              : null,
                          daysOfWeek: List.unmodifiable(daysOfWeek),
                          portionSize: portionSize.isEmpty ? null : portionSize,
                          remindMe: remindMe,
                          lastFedAt:
                              existing?.frequency != frequency ||
                                  (frequency == FeedingEntry.doesNotRepeat &&
                                      !DateUtils.isSameDay(
                                        existing?.scheduledDate,
                                        scheduledDate,
                                      ))
                              ? null
                              : existing?.lastFedAt,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;

    setState(() => _saving = true);
    try {
      final selectedPetChanged =
          existing == null && result.petId != _selectedPet?.id;
      final targetPet = selectedPetChanged
          ? _furloState.pets.where((pet) => pet.id == result.petId).firstOrNull
          : null;
      if (existing == null) {
        await widget.repository.addFeedingSchedule(result);
      } else {
        await widget.repository.updateFeedingSchedule(result);
      }
      if (targetPet != null) _furloState.selectPet(targetPet);
      await widget.notificationService.rescheduleAll();
      if (!selectedPetChanged) await _loadSchedules();
    } catch (error, stackTrace) {
      debugPrint('Failed to save feeding schedule: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('The feeding schedule could not be saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markComplete(FeedingEntry entry) async {
    if (entry.isComplete || entry.id == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateFeedingSchedule(
        entry.copyWith(lastFedAt: DateTime.now()),
      );
      await widget.notificationService.rescheduleAll();
      await _loadSchedules();
    } catch (_) {
      _showMessage('The meal could not be marked complete.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSchedule(FeedingEntry entry) async {
    final id = entry.id;
    final petId = _selectedPet?.id;
    if (id == null || petId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete schedule?', style: AppTypography.h2),
        content: Text('Delete the ${entry.name} feeding schedule?'),
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
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteFeedingSchedule(id, petId);
      await widget.notificationService.rescheduleAll();
      await _loadSchedules();
    } catch (_) {
      _showMessage('The feeding schedule could not be deleted.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    Widget? prefixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: const BorderSide(color: AppColors.textDisabled, width: 1),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: AppTypography.label.copyWith(color: AppColors.textSecondary),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final furloState = context.watch<FurloState>();
    final petsWithIds = furloState.pets.where((pet) => pet.id != null).toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Feeding Schedule', style: AppTypography.h2),
        backgroundColor: AppColors.bg,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _selectedPet == null
                  ? _NoPetState(onAddPet: _addPet)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (petsWithIds.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(_selectedPet?.id),
                              initialValue: _selectedPet?.id,
                              decoration: const InputDecoration(
                                labelText: 'Pet',
                              ),
                              items: petsWithIds
                                  .map(
                                    (pet) => DropdownMenuItem(
                                      value: pet.id,
                                      child: Text(pet.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _choosePet,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Text(
                              _selectedPet!.name,
                              style: AppTypography.h2,
                            ),
                          ),
                        if (_loading)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_schedules.isEmpty)
                          Expanded(
                            child: _EmptyFeedingState(
                              onAdd: _saving ? null : () => _editSchedule(),
                            ),
                          )
                        else ...[
                          Expanded(
                            child: ListView.separated(
                              itemCount: _schedules.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final entry = _schedules[index];
                                final status = _statusFor(entry);
                                return _FeedingScheduleCard(
                                  entry: entry,
                                  status: status,
                                  onComplete: _saving || entry.isComplete
                                      ? null
                                      : () => _markComplete(entry),
                                  onEdit: _saving
                                      ? null
                                      : () => _editSchedule(entry),
                                  onDelete: _saving
                                      ? null
                                      : () => _deleteSchedule(entry),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : () => _editSchedule(),
                            style: AppComponents.primaryButton,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Feeding Schedule'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPet() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddPetScreen(repository: widget.repository),
      ),
    );
  }

  String _statusFor(FeedingEntry entry) {
    if (entry.isComplete) return 'Completed';
    final now = DateTime.now();
    if (entry.frequency == FeedingEntry.doesNotRepeat) {
      final scheduledDate = entry.scheduledDate;
      if (scheduledDate == null) return 'Upcoming';
      final time = _parseTime(entry.time);
      final scheduled = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        time.hour,
        time.minute,
      );
      if (DateUtils.dateOnly(now).isAfter(DateUtils.dateOnly(scheduled))) {
        return 'Missed / Overdue';
      }
      return now.isAfter(scheduled) ? 'Missed / Overdue' : 'Upcoming';
    }
    final parts = entry.time.split(':');
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts.first) ?? 8,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    return now.isAfter(scheduled) ? 'Missed / Overdue' : 'Upcoming';
  }
}

class _NoPetState extends StatelessWidget {
  const _NoPetState({required this.onAddPet});
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pets_outlined, size: 44, color: AppColors.primary),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Add a pet before managing feeding schedules.',
          textAlign: TextAlign.center,
          style: AppTypography.body,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onAddPet,
          icon: const Icon(Icons.add),
          label: const Text('Add Pet'),
        ),
      ],
    ),
  );
}

class _EmptyFeedingState extends StatelessWidget {
  const _EmptyFeedingState({required this.onAdd});
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.restaurant_outlined,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('No feeding schedules yet', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add a schedule to keep track of your pet’s meals.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: onAdd,
          style: AppComponents.primaryButton,
          icon: const Icon(Icons.add),
          label: const Text('Add Feeding Schedule'),
        ),
      ],
    ),
  );
}

class _FeedingScheduleCard extends StatelessWidget {
  const _FeedingScheduleCard({
    required this.entry,
    required this.status,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final FeedingEntry entry;
  final String status;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheduledTime = _parseTime(entry.time).format(context);
    final statusColor = switch (status) {
      'Completed' => AppColors.accent,
      'Missed / Overdue' => AppColors.danger,
      _ => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: AppTypography.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        scheduledTime,
                        if (entry.frequency == FeedingEntry.doesNotRepeat &&
                            entry.scheduledDate != null)
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(entry.scheduledDate!),
                        entry.frequency,
                        if (entry.daysOfWeek.isNotEmpty)
                          entry.daysOfWeek
                              .map(
                                (day) => const [
                                  'M',
                                  'T',
                                  'W',
                                  'T',
                                  'F',
                                  'S',
                                  'S',
                                ][day - 1],
                              )
                              .join(' '),
                        if (entry.portionSize != null) entry.portionSize!,
                        if (entry.remindMe) 'Reminder on',
                      ].join(' · '),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 9),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      status,
                      style: AppTypography.caption.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onComplete,
                icon: Icon(
                  entry.isComplete
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(entry.isComplete ? 'Done' : 'Mark fed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 8,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
