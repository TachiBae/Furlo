import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pet.dart';
import '../../models/vet.dart';
import '../../providers/furlo_state.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_diagnostics.dart';
import '../../utils/app_copy.dart';
import '../../utils/form_input.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatting.dart';
import '../../utils/vet_validation.dart';
import '../../widgets/record_components.dart';

class VetContactsScreen extends StatefulWidget {
  const VetContactsScreen({
    super.key,
    required this.repository,
    this.notificationService = const NoOpNotificationService(),
    this.storageScope,
  });
  final PetRepository repository;
  final NotificationService notificationService;
  final String? storageScope;

  @override
  State<VetContactsScreen> createState() => _VetContactsScreenState();
}

class _VetContactsScreenState extends State<VetContactsScreen> {
  bool _loading = true;
  bool _loadError = false;
  String _filter = 'all';
  List<Vet> _vets = [];
  final Map<String, List<Pet>> _linkedPets = {};
  late final FurloState _furloState;

  @override
  void initState() {
    super.initState();
    _furloState = context.read<FurloState>();
    _filter = _furloState.selectedPet?.id?.toString() ?? 'all';
    _furloState.addListener(_onFurloStateChanged);
    _load();
  }

  @override
  void dispose() {
    _furloState.removeListener(_onFurloStateChanged);
    super.dispose();
  }

  void _onFurloStateChanged() {
    if (_filter != 'all' &&
        !_furloState.pets.any((pet) => pet.id.toString() == _filter)) {
      _filter = _furloState.selectedPet?.id?.toString() ?? 'all';
    }
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      // Three reads in total, rather than a full pet list per vet.
      final (vets, pets, links) = await (
        widget.repository.getAllVets(),
        widget.repository.getPets(),
        widget.repository.getAllVetLinks(),
      ).wait;
      if (!mounted) return;
      final petsById = {
        for (final pet in pets)
          if (pet.id != null) pet.id!: pet,
      };
      final linkedPets = <String, List<Pet>>{
        for (final vet in vets)
          if (vet.id != null)
            vet.id!:
                [
                  for (final link in links)
                    if (link.vetId == vet.id && petsById[link.petId] != null)
                      petsById[link.petId]!,
                ]..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
      };
      if (!mounted) return;
      _vets = vets;
      _linkedPets
        ..clear()
        ..addAll(linkedPets);
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      logAppDiagnostic('Vet contacts load failed.');
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _openForm([Vet? vet]) async {
    List<String> ids = [];
    if (vet?.id != null) {
      ids = (await widget.repository.getPetsForVet(
        vet!.id!,
      )).map((pet) => pet.id!).toList();
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VetFormScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          storageScope: widget.storageScope,
          vet: vet,
          linkedPetIds: ids,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) await _load();
  }

  Future<void> _call(Vet vet) async {
    final number = vet.phone ?? '';
    try {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri) && await launchUrl(uri)) return;
    } catch (_) {
      /* The number remains available when dialers are unsupported. */
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Call $number')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = context.select<FurloState, List<Pet>>((s) => s.pets);
    final visible = _filter == 'all'
        ? _vets
        : _vets
              .where(
                (vet) =>
                    _linkedPets[vet.id]?.any(
                      (pet) => pet.id.toString() == _filter,
                    ) ??
                    false,
              )
              .toList();
    final filters = [
      const RecordFilterOption('all', 'All'),
      ...pets
          .where((p) => p.id != null)
          .map((p) => RecordFilterOption(p.id.toString(), p.name)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Vet Contacts')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RecordFilterTabs(
                options: filters,
                selectedValue: _filter,
                onSelected: (value) {
                  if (value != 'all') {
                    final selectedPet = pets
                        .where((pet) => pet.id.toString() == value)
                        .firstOrNull;
                    if (selectedPet != null) _furloState.selectPet(selectedPet);
                  }
                  setState(() => _filter = value);
                },
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: RecordEmptyState(
                  icon: Icons.error_outline,
                  title: 'Vet contacts could not be loaded.',
                  message: AppCopy.checkConnection,
                  actionLabel: 'Try again',
                  onAction: () => _load(),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: RecordEmptyState(
                  title: 'No vets yet',
                  message: _filter == 'all'
                      ? 'Add a vet contact to keep important details close.'
                      : 'No vets are linked to this pet yet.',
                  icon: Icons.local_hospital_outlined,
                  actionLabel: 'Add vet',
                  onAction: () => _openForm(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final vet = visible[index];
                    return RecordCard(
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VetDetailsScreen(
                              repository: widget.repository,
                              notificationService: widget.notificationService,
                              storageScope: widget.storageScope,
                              vet: vet,
                            ),
                          ),
                        );
                        if (changed == true && context.mounted) await _load();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.h2,
                            ),
                            if ((vet.clinic ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  vet.clinic!,
                                  style: AppTypography.body.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    vet.phone ?? '',
                                    style: AppTypography.body,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _call(vet),
                                  style: AppComponents.secondaryButton.copyWith(
                                    minimumSize:
                                        const WidgetStatePropertyAll<Size>(
                                          Size(64, 48),
                                        ),
                                  ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _petChips(_linkedPets[vet.id] ?? []),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add vet'),
      ),
    );
  }

  List<Widget> _petChips(List<Pet> pets) {
    return [
      ...pets.take(2).map((pet) => _PetChip(pet.name)),
      if (pets.length > 2) const _PetChip('…'),
      if (pets.length > 2) _PetChip('+${pets.length - 2}'),
    ];
  }
}

class VetFormScreen extends StatefulWidget {
  const VetFormScreen({
    super.key,
    required this.repository,
    this.notificationService = const NoOpNotificationService(),
    this.storageScope,
    this.vet,
    this.linkedPetIds = const [],
  });
  final PetRepository repository;
  final NotificationService notificationService;
  final String? storageScope;
  final Vet? vet;
  final List<String> linkedPetIds;
  @override
  State<VetFormScreen> createState() => _VetFormScreenState();
}

class _VetFormScreenState extends State<VetFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.vet?.name ?? '');
  late final _clinic = TextEditingController(text: widget.vet?.clinic ?? '');
  late final _phone = TextEditingController(text: widget.vet?.phone ?? '');
  late final _email = TextEditingController(text: widget.vet?.email ?? '');
  late final _address = TextEditingController(text: widget.vet?.address ?? '');
  late final _notes = TextEditingController(text: widget.vet?.notes ?? '');
  late final Set<String> _selected = {...widget.linkedPetIds};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _clinic, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one pet')));
      return;
    }
    setState(() => _saving = true);
    final vet = Vet(
      id: widget.vet?.id,
      name: _name.text.trim(),
      clinic: _optional(_clinic.text),
      phone: _phone.text.trim(),
      email: _optional(_email.text),
      address: _optional(_address.text),
      notes: _optional(_notes.text),
    );
    try {
      if (widget.vet == null) {
        await widget.repository.addVet(vet, _selected.toList());
      } else {
        await widget.repository.updateVet(vet, _selected.toList());
      }
      await widget.notificationService.rescheduleAll();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      // Keep the form open with everything the user typed: an error here is
      // usually transient, and dropping back to the list would lose the vet.
      if (!mounted) return;
      logAppDiagnostic('Vet save failed.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The vet could not be saved. Please try again.'),
        ),
      );
    } finally {
      // Without this the button stays disabled and there is no way to retry.
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final pets = context.select<FurloState, List<Pet>>((s) => s.pets);
    return Scaffold(
      appBar: AppBar(title: Text(widget.vet == null ? 'Add Vet' : 'Edit Vet')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(
              _name,
              'Name',
              required: true,
              maxLength: AppFieldLimits.shortName,
              next: true,
            ),
            _field(
              _clinic,
              'Clinic',
              maxLength: AppFieldLimits.title,
              next: true,
            ),
            _field(
              _phone,
              'Phone',
              required: true,
              validator: validateVetPhone,
              keyboard: TextInputType.phone,
              maxLength: AppFieldLimits.phone,
              next: true,
            ),
            _field(
              _email,
              'Email',
              validator: validateVetEmail,
              keyboard: TextInputType.emailAddress,
              next: true,
            ),
            _field(
              _address,
              'Address',
              maxLength: AppFieldLimits.address,
              next: true,
            ),
            _field(
              _notes,
              'Notes',
              lines: 3,
              maxLength: AppFieldLimits.notes,
              keyboard: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            Text('Associated pets', style: AppTypography.h2),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: pets
                  .where((pet) => pet.id != null)
                  .map(
                    (pet) => FilterChip(
                      label: Text(pet.name),
                      selected: _selected.contains(pet.id),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selected.add(pet.id!);
                        } else {
                          _selected.remove(pet.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: AppComponents.primaryButton,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: AppComponents.secondaryButton,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int lines = 1,
    int? maxLength,
    bool next = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: lines,
      maxLength: maxLength,
      // Multiline fields keep the newline key; the rest offer "next" so the
      // keyboard can walk the form instead of dismissing on every field.
      textInputAction: lines > 1
          ? TextInputAction.newline
          : next
          ? TextInputAction.next
          : TextInputAction.done,
      validator:
          validator ??
          (required
              ? (value) => value == null || value.trim().isEmpty
                    ? '$label is required'
                    : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.appColors.surface,
        border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
      ),
    ),
  );
}

class VetDetailsScreen extends StatefulWidget {
  const VetDetailsScreen({
    super.key,
    required this.repository,
    required this.vet,
    this.notificationService = const NoOpNotificationService(),
    this.storageScope,
  });
  final PetRepository repository;
  final Vet vet;
  final NotificationService notificationService;
  final String? storageScope;
  @override
  State<VetDetailsScreen> createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends State<VetDetailsScreen> {
  bool _loading = true;
  bool _loadError = false;
  bool _changed = false;
  bool _busy = false;
  Vet? _vet;
  List<Pet> _pets = [];
  Map<String, DateTime?> _appointments = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.vet.id;
    if (id == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }
    try {
      final vet = await widget.repository.getVetById(id);
      final pets = await widget.repository.getPetsForVet(id);
      final links = await widget.repository.getVetPetAssociations(id);
      if (!mounted) return;
      setState(() {
        _vet = vet;
        _pets = pets;
        _appointments = {
          for (final link in links) link.petId: link.nextAppointmentDate,
        };
        _loading = false;
      });
    } catch (_) {
      logAppDiagnostic('Vet details load failed.');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _call() async {
    final phone = _vet?.phone ?? '';
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri) && await launchUrl(uri)) return;
    } catch (_) {
      // A dialer that refuses to open is not a dead end: the SnackBar below
      // still hands the number to the user, so there is nothing to report.
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Call $phone')));
    }
  }

  Future<void> _appointment(Pet pet) async {
    final current = _appointments[pet.id];
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    await _saveAppointment(pet, selected);
  }

  /// Sets ([date]) or clears (null) a pet's next appointment with this vet.
  Future<void> _saveAppointment(Pet pet, DateTime? date) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.setNextAppointment(_vet!.id!, pet.id!, date);
      _changed = true;
      await widget.notificationService.rescheduleAll();
      if (!mounted) return;
      await _load();
    } catch (_) {
      logAppDiagnostic('Vet appointment save failed.');
      if (mounted) _showMessage('The appointment could not be saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmRecordDelete(
      context,
      title: 'Delete vet?',
      message: 'This vet contact and its pet links will be removed.',
    )) {
      return;
    }
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteVet(_vet!.id!);
    } catch (_) {
      logAppDiagnostic('Vet delete failed.');
      if (mounted) {
        setState(() => _busy = false);
        _showMessage('The vet could not be deleted.');
      }
      return;
    }
    // The vet is gone either way; a reminder rebuild failure is not fatal.
    await widget.notificationService.rescheduleAll().catchError((Object _) {});
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final vet = _vet;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            // A custom leading replaces the AppBar's own back button, which is
            // the only thing that carried its (localized) label.
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: const Text('Vet Details'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError
            ? RecordEmptyState(
                icon: Icons.error_outline,
                title: 'This vet could not be loaded.',
                message: AppCopy.checkConnection,
                actionLabel: 'Try again',
                onAction: _load,
              )
            : vet == null
            ? const RecordEmptyState(
                title: 'Vet not found',
                message: 'This contact may have been deleted.',
                icon: Icons.person_off_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(vet.name, style: AppTypography.h1),
                  if ((vet.clinic ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        vet.clinic!,
                        style: AppTypography.body.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _detail('Phone', vet.phone),
                  _detail('Email', vet.email),
                  _detail('Address', vet.address),
                  _detail('Notes', vet.notes),
                  const SizedBox(height: 20),
                  Text('Associated pets', style: AppTypography.h2),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _pets.map((pet) => _PetChip(pet.name)).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Next appointments', style: AppTypography.h2),
                  ..._pets.map(
                    (pet) => Card(
                      color: context.appColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet.name,
                                    style: AppTypography.bodyStrong,
                                  ),
                                  Text(
                                    formatShortDate(_appointments[pet.id]),
                                    style: AppTypography.caption.copyWith(
                                      color: _appointments[pet.id] == null
                                          ? context.appColors.textDisabled
                                          : context.appColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _appointment(pet),
                              child: const Text('Set date'),
                            ),
                            if (_appointments[pet.id] != null)
                              IconButton(
                                tooltip: 'Clear date',
                                onPressed: () => _saveAppointment(pet, null),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _call,
                    style: AppComponents.secondaryButton,
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VetFormScreen(
                            repository: widget.repository,
                            notificationService: widget.notificationService,
                            storageScope: widget.storageScope,
                            vet: vet,
                            linkedPetIds: _pets.map((pet) => pet.id!).toList(),
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        _changed = true;
                        await _load();
                      }
                    },
                    style: AppComponents.primaryButton,
                    child: const Text('Edit'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _delete,
                    style: AppComponents.secondaryButton,
                    child: const Text('Delete'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _detail(String label, String? value) => RecordDetailRow(
    label: label,
    value: value?.trim().isNotEmpty == true ? value! : 'Not set',
    valueIsEmpty: value?.trim().isNotEmpty != true,
  );
}

class _PetChip extends StatelessWidget {
  const _PetChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    backgroundColor: context.appColors.primaryMuted,
    labelStyle: AppTypography.caption.copyWith(
      color: context.appColors.textPrimary,
    ),
    visualDensity: VisualDensity.compact,
  );
}
