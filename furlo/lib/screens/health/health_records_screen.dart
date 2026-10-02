import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/health_record_types.dart';
import '../../models/health_record.dart';
import '../../models/pet.dart';
import '../../providers/health_records_provider.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/health_record_validation.dart';
import '../../widgets/record_components.dart';
import '../../widgets/status_pill.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({
    super.key,
    required this.repository,
    this.notificationService = const NoOpNotificationService(),
    required this.pets,
    this.selectedPet,
  });

  final PetRepository repository;
  final NotificationService notificationService;
  final List<Pet> pets;
  final Pet? selectedPet;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => HealthRecordsProvider(
      repository: repository,
      notificationService: notificationService,
      pets: pets,
      selectedPet: selectedPet,
    ),
    child: const _HealthRecordsView(),
  );
}

class _HealthRecordsView extends StatefulWidget {
  const _HealthRecordsView();

  @override
  State<_HealthRecordsView> createState() => _HealthRecordsViewState();
}

class _HealthRecordsViewState extends State<_HealthRecordsView> {
  static const _allTypes = 'all';
  String _filter = _allTypes;

  Future<void> _edit(
    HealthRecordsProvider state, [
    HealthRecord? existing,
  ]) async {
    final petId = existing?.petId ?? state.selectedPet?.id;
    if (petId == null || state.saving) return;
    final result = await Navigator.of(context).push<HealthRecord>(
      MaterialPageRoute(
        builder: (_) =>
            HealthRecordFormScreen(petId: petId, existing: existing),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await state.save(result);
    } catch (_) {
      if (mounted) _showMessage('The health record could not be saved.');
    }
  }

  Future<void> _delete(HealthRecordsProvider state, HealthRecord record) async {
    final confirmed = await confirmRecordDelete(
      context,
      title: 'Delete health record?',
      message: 'Delete ${record.title}?',
    );
    if (!confirmed || !mounted) return;
    try {
      await state.delete(record);
    } catch (_) {
      if (mounted) _showMessage('The health record could not be deleted.');
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Consumer<HealthRecordsProvider>(
    builder: (context, state, _) {
      final records = state.records
          .where((record) => _filter == _allTypes || record.type == _filter)
          .toList();
      final filters = [
        const RecordFilterOption(_allTypes, 'All'),
        ...HealthRecordTypes.values.map(
          (type) => RecordFilterOption(type, type),
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Health Records'),
        ),
        floatingActionButton: state.selectedPet == null
            ? null
            : FloatingActionButton.extended(
                onPressed: state.saving ? null : () => _edit(state),
                icon: const Icon(Icons.add),
                label: const Text('Add record'),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.selectedPet != null)
                    PetSelectorTabs(
                      pets: state.pets,
                      selectedPet: state.selectedPet!,
                      onSelected: state.selectPet,
                    ),
                  RecordFilterTabs(
                    options: filters,
                    selectedValue: _filter,
                    onSelected: (type) => setState(() => _filter = type),
                  ),
                  if (state.loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.error != null)
                    Expanded(child: Center(child: Text(state.error!)))
                  else if (state.selectedPet == null)
                    const Expanded(
                      child: RecordEmptyState(
                        title: 'Add a pet first',
                        message: 'Add a pet to keep their health history here.',
                        icon: Icons.medical_information_outlined,
                      ),
                    )
                  else if (records.isEmpty)
                    Expanded(
                      child: RecordEmptyState(
                        title: state.records.isEmpty
                            ? 'No health records yet'
                            : 'No records of this type',
                        message: state.records.isEmpty
                            ? 'Keep your pet’s health history in one place.'
                            : 'Choose another type to see more records.',
                        icon: Icons.medical_information_outlined,
                        actionLabel: state.records.isEmpty
                            ? 'Add record'
                            : null,
                        onAction: state.records.isEmpty
                            ? () => _edit(state)
                            : null,
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: state.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            88,
                          ),
                          itemCount: records.length,
                          itemBuilder: (context, index) => _HealthRecordCard(
                            record: records[index],
                            onTap: () => _edit(state, records[index]),
                            onDelete: () => _delete(state, records[index]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HealthRecordCard extends StatelessWidget {
  const _HealthRecordCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final HealthRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => RecordCard(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: AppTypography.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: record.type,
                isActive: record.type == HealthRecordTypes.medication,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RecordDetailRow(
            label: 'Date',
            value: _formatDate(record.date),
            valueIsEmpty: record.date == null,
          ),
          const SizedBox(height: AppSpacing.xs),
          _NotesPreview(notes: record.notes),
          if (record.type == HealthRecordTypes.medication &&
              record.reminderActive == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reminder: ${record.reminderFrequency ?? ''}',
              style: AppTypography.caption.copyWith(color: AppColors.accent),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Delete health record',
              onPressed: onDelete,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotesPreview extends StatelessWidget {
  const _NotesPreview({required this.notes});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final value = notes?.trim() ?? '';
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            'Notes',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(
              color: value.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class HealthRecordFormScreen extends StatefulWidget {
  const HealthRecordFormScreen({super.key, required this.petId, this.existing});

  final int petId;
  final HealthRecord? existing;

  @override
  State<HealthRecordFormScreen> createState() => _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState extends State<HealthRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _type;
  late DateTime? _date;
  late bool _reminderActive;
  String? _reminderFrequency;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _type = widget.existing?.type ?? HealthRecordTypes.checkup;
    final today = DateTime.now();
    _date =
        widget.existing?.date ?? DateTime(today.year, today.month, today.day);
    _reminderActive = widget.existing?.reminderActive ?? false;
    _reminderFrequency = widget.existing?.reminderFrequency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date != null && !_isFutureDay(_date!)
          ? DateTime(_date!.year, _date!.month, _date!.day)
          : DateTime(today.year, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select record date',
    );
    if (selected == null || !mounted) return;
    setState(() => _date = selected);
    field.didChange(selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final medication = _type == HealthRecordTypes.medication;
    final record = HealthRecord(
      id: widget.existing?.id,
      petId: widget.petId,
      title: _titleController.text.trim(),
      date: _date,
      type: _type,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      reminderActive: medication ? _reminderActive : null,
      reminderFrequency: medication && _reminderActive
          ? _reminderFrequency
          : null,
    );
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: Text(
        widget.existing == null ? 'Add Health Record' : 'Edit Health Record',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Title', 'e.g. Annual checkup'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'A title is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: _decoration('Type', 'Choose a type'),
                  items: HealthRecordTypes.values
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Choose a record type' : null,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _type = value;
                      if (_type != HealthRecordTypes.medication) {
                        _reminderActive = false;
                        _reminderFrequency = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FormField<DateTime>(
                  initialValue: _date,
                  validator: (value) {
                    if (value == null) return 'A date is required';
                    if (_isFutureDay(value)) {
                      return 'Date cannot be in the future';
                    }
                    return null;
                  },
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: AppRadius.mdRadius,
                        onTap: () => _pickDate(field),
                        child: InputDecorator(
                          decoration: _decoration('Date', 'Select a date')
                              .copyWith(
                                errorText: field.errorText,
                                suffixIcon: const Icon(
                                  Icons.calendar_month_outlined,
                                ),
                              ),
                          child: Text(
                            _date == null
                                ? 'Select a date'
                                : _formatDate(_date),
                            style: _date == null
                                ? AppTypography.body.copyWith(
                                    color: AppColors.textSecondary,
                                  )
                                : AppTypography.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _decoration('Notes (optional)', 'Add details'),
                ),
                if (_type == HealthRecordTypes.medication) ...[
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Medication reminder',
                      style: AppTypography.body,
                    ),
                    value: _reminderActive,
                    onChanged: (value) => setState(() {
                      _reminderActive = value;
                      if (!value) _reminderFrequency = null;
                    }),
                  ),
                  if (_reminderActive) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _reminderFrequency,
                      decoration: _decoration('Frequency', 'Choose frequency'),
                      items: HealthReminderFrequencies.values
                          .map(
                            (frequency) => DropdownMenuItem(
                              value: frequency,
                              child: Text(_titleCase(frequency)),
                            ),
                          )
                          .toList(),
                      validator: (_) => validateHealthReminderFrequency(
                        type: _type,
                        reminderActive: _reminderActive,
                        frequency: _reminderFrequency,
                      ),
                      onChanged: (value) =>
                          setState(() => _reminderFrequency = value),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _save,
                  style: AppComponents.primaryButton,
                  child: const Text('Save record'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppComponents.secondaryButton,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceAlt,
    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
  );
}

bool _isFutureDay(DateTime value) {
  final date = DateTime.utc(value.year, value.month, value.day);
  final today = DateTime.now();
  final todayDate = DateTime.utc(today.year, today.month, today.day);
  return date.isAfter(todayDate);
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _titleCase(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';
