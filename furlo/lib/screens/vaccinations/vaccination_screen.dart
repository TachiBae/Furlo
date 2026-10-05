import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/vaccine_catalog.dart';
import '../../models/pet.dart';
import '../../models/vaccination.dart';
import '../../providers/vaccinations_provider.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/record_components.dart';
import '../../widgets/status_pill.dart';

class VaccinationScreen extends StatelessWidget {
  const VaccinationScreen({
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
    create: (_) => VaccinationsProvider(
      repository: repository,
      notificationService: notificationService,
      pets: pets,
      selectedPet: selectedPet,
    ),
    child: const _VaccinationsView(),
  );
}

class _VaccinationsView extends StatefulWidget {
  const _VaccinationsView();

  @override
  State<_VaccinationsView> createState() => _VaccinationsViewState();
}

class _VaccinationsViewState extends State<_VaccinationsView> {
  String _filter = VaccinationStatuses.all;

  Future<void> _edit(
    VaccinationsProvider state, [
    Vaccination? existing,
  ]) async {
    final petId = existing?.petId ?? state.selectedPet?.id;
    if (petId == null || state.saving) return;
    final result = await Navigator.of(context).push<Vaccination>(
      MaterialPageRoute(
        builder: (_) => VaccinationFormScreen(
          petId: petId,
          species: state.selectedPet?.species ?? '',
          existing: existing,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await state.save(result);
    } catch (_) {
      if (mounted) _message('The vaccination could not be saved.');
    }
  }

  Future<void> _delete(
    VaccinationsProvider state,
    Vaccination vaccination,
  ) async {
    final confirmed = await confirmRecordDelete(
      context,
      title: 'Delete vaccination?',
      message: 'Delete ${vaccination.vaccineName}?',
    );
    if (!confirmed || !mounted) return;
    try {
      await state.delete(vaccination);
    } catch (_) {
      if (mounted) _message('The vaccination could not be deleted.');
    }
  }

  Future<void> _markCompleted(
    VaccinationsProvider state,
    Vaccination vaccination,
  ) async {
    try {
      await state.toggleCompletion(vaccination);
    } catch (_) {
      if (mounted) _message('The vaccination could not be marked complete.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Consumer<VaccinationsProvider>(
    builder: (context, state, _) {
      final records = state.vaccinations.where((item) {
        return _filter == VaccinationStatuses.all || item.status == _filter;
      }).toList();
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Vaccinations'),
        ),
        floatingActionButton:
            state.selectedPet == null || state.vaccinations.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: state.saving ? null : () => _edit(state),
                icon: const Icon(Icons.add),
                label: const Text('Add vaccine'),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: RefreshIndicator(
                onRefresh: state.refresh,
                child: CustomScrollView(
                  slivers: [
                    if (state.selectedPet != null)
                      SliverToBoxAdapter(
                        child: PetSelectorTabs(
                          pets: state.pets,
                          selectedPet: state.selectedPet!,
                          onSelected: state.selectPet,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: RecordFilterTabs(
                        options: const [
                          RecordFilterOption(VaccinationStatuses.all, 'All'),
                          RecordFilterOption(
                            VaccinationStatuses.dueSoon,
                            'Due soon',
                          ),
                          RecordFilterOption(
                            VaccinationStatuses.overdue,
                            'Overdue',
                          ),
                          RecordFilterOption(
                            VaccinationStatuses.completed,
                            'Completed',
                          ),
                        ],
                        selectedValue: _filter,
                        onSelected: (status) =>
                            setState(() => _filter = status),
                      ),
                    ),
                    if (state.loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text(state.error!)),
                      )
                    else if (state.selectedPet == null)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('Add a pet to track vaccines.'),
                        ),
                      )
                    else if (records.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: RecordEmptyState(
                          icon: Icons.vaccines_outlined,
                          title: state.vaccinations.isNotEmpty
                              ? 'No vaccines in this status'
                              : 'No vaccinations yet',
                          message: state.vaccinations.isNotEmpty
                              ? 'Choose another filter to see more records.'
                              : 'Keep your pet’s vaccine history up to date.',
                          actionLabel: state.vaccinations.isNotEmpty
                              ? null
                              : 'Add vaccination',
                          onAction: state.vaccinations.isNotEmpty
                              ? null
                              : () => _edit(state),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          88,
                        ),
                        sliver: SliverList.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final item = records[index];
                            return _VaccinationCard(
                              vaccination: item,
                              onTap: () => _edit(state, item),
                              onComplete: () => _markCompleted(state, item),
                              onDelete: () => _delete(state, item),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _VaccinationCard extends StatelessWidget {
  const _VaccinationCard({
    required this.vaccination,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
  });

  final Vaccination vaccination;
  final VoidCallback onTap;
  final VoidCallback onComplete;
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
                  vaccination.vaccineName,
                  style: AppTypography.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: _titleCase(vaccination.status),
                status: vaccination.status,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RecordDetailRow(
            label: 'Date given',
            value: _formatDate(vaccination.dateGiven),
            valueIsEmpty: vaccination.dateGiven == null,
          ),
          const SizedBox(height: AppSpacing.xs),
          RecordDetailRow(
            label: 'Next due',
            value: _formatDate(vaccination.nextDueDate),
            valueIsEmpty: vaccination.nextDueDate == null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onComplete,
                style: TextButton.styleFrom(
                  foregroundColor: vaccination.isCompleted
                      ? context.appColors.textSecondary
                      : context.appColors.accent,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                icon: Icon(
                  vaccination.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                label: Text(
                  vaccination.isCompleted ? 'Undo complete' : 'Mark complete',
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete vaccination',
                onPressed: onDelete,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class VaccinationFormScreen extends StatefulWidget {
  const VaccinationFormScreen({
    super.key,
    required this.petId,
    required this.species,
    this.existing,
  });

  final int petId;
  final String species;
  final Vaccination? existing;

  @override
  State<VaccinationFormScreen> createState() => _VaccinationFormScreenState();
}

class _VaccinationFormScreenState extends State<VaccinationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otherNameFocus = FocusNode();
  late final TextEditingController _otherNameController;
  late final List<String> _vaccineOptions;
  String? _selectedVaccine;
  late DateTime? _dateGiven;
  late DateTime? _nextDueDate;

  @override
  void initState() {
    super.initState();
    _vaccineOptions = vaccinesFor(widget.species);
    final existingName = widget.existing?.vaccineName;
    final isListedVaccine =
        existingName != null && _vaccineOptions.contains(existingName);
    _selectedVaccine = isListedVaccine
        ? existingName
        : existingName == null
        ? null
        : 'Other';
    _otherNameController = TextEditingController(
      text: isListedVaccine ? '' : existingName ?? '',
    );
    _dateGiven = widget.existing?.dateGiven ?? DateTime.now();
    _nextDueDate = widget.existing?.nextDueDate;
  }

  @override
  void dispose() {
    _otherNameFocus.dispose();
    _otherNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool nextDue}) async {
    final current = nextDue ? _nextDueDate : _dateGiven;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: nextDue ? 'Select next due date' : 'Select date given',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (nextDue) {
        _nextDueDate = selected;
      } else {
        _dateGiven = selected;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateGiven == null || _isBeforeDay(_nextDueDate, _dateGiven!)) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      Vaccination(
        id: widget.existing?.id,
        petId: widget.petId,
        vaccineName: _selectedVaccine == 'Other'
            ? _otherNameController.text.trim()
            : _selectedVaccine!,
        dateGiven: _dateGiven,
        nextDueDate: _nextDueDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: Text(
        widget.existing == null ? 'Add Vaccination' : 'Edit Vaccination',
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
                DropdownButtonFormField<String>(
                  initialValue: _selectedVaccine,
                  decoration: _decoration('Vaccine', 'Choose a vaccine'),
                  items: [..._vaccineOptions, 'Other']
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Choose a vaccine' : null,
                  onChanged: (value) {
                    setState(() => _selectedVaccine = value);
                    if (value == 'Other') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _otherNameFocus.requestFocus();
                      });
                    }
                  },
                ),
                if (_selectedVaccine == 'Other') ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _otherNameController,
                    focusNode: _otherNameFocus,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      'Custom vaccine name',
                      'Enter vaccine name',
                    ),
                    validator: (value) =>
                        _selectedVaccine == 'Other' &&
                            (value == null || value.trim().isEmpty)
                        ? 'A vaccine name is required'
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _DateField(
                  label: 'Date given',
                  value: _dateGiven,
                  onTap: () => _pickDate(nextDue: false),
                ),
                if (_dateGiven == null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Select when this vaccine was given.',
                      style: AppTypography.caption.copyWith(
                        color: context.appColors.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                _DateField(
                  label: 'Next due date (optional)',
                  value: _nextDueDate,
                  onTap: () => _pickDate(nextDue: true),
                  onClear: _nextDueDate == null
                      ? null
                      : () => setState(() => _nextDueDate = null),
                ),
                if (_dateGiven != null &&
                    _nextDueDate != null &&
                    _isBeforeDay(_nextDueDate, _dateGiven!))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Next due date cannot be before the date given.',
                      style: AppTypography.caption.copyWith(
                        color: context.appColors.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _save,
                  style: AppComponents.primaryButton,
                  child: const Text('Save vaccination'),
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
    fillColor: context.appColors.surfaceAlt,
    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: AppRadius.mdRadius,
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.appColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
        suffixIcon: value == null
            ? const Icon(Icons.calendar_month_outlined)
            : IconButton(
                tooltip: 'Clear date',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(value == null ? 'Select date' : _formatDate(value)),
      ),
    ),
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  final date = value;
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

bool _isBeforeDay(DateTime? first, DateTime second) {
  if (first == null) return false;
  final firstDay = DateTime.utc(first.year, first.month, first.day);
  final secondDay = DateTime.utc(second.year, second.month, second.day);
  return firstDay.isBefore(secondDay);
}

String _titleCase(String value) => value
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
