import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pet.dart';
import '../../models/vet.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/vet_validation.dart';
import '../../widgets/record_components.dart';

class VetContactsScreen extends StatefulWidget {
  const VetContactsScreen({
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
  State<VetContactsScreen> createState() => _VetContactsScreenState();
}

class _VetContactsScreenState extends State<VetContactsScreen> {
  bool _loading = true;
  String _filter = 'all';
  List<Vet> _vets = [];
  final Map<int, List<Pet>> _linkedPets = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.selectedPet?.id?.toString() ?? 'all';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _vets = await widget.repository.getAllVets();
    _linkedPets.clear();
    for (final vet in _vets) {
      if (vet.id != null) {
        _linkedPets[vet.id!] = await widget.repository.getPetsForVet(vet.id!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm([Vet? vet]) async {
    List<int> ids = [];
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
          pets: widget.pets,
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
      ...widget.pets
          .where((p) => p.id != null)
          .map((p) => RecordFilterOption(p.id.toString(), p.name)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Vet Contacts')),
      body: Column(
        children: [
          RecordFilterTabs(
            options: filters,
            selectedValue: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? RecordEmptyState(
                    title: 'No vets yet',
                    message: _filter == 'all'
                        ? 'Add a vet contact to keep important details close.'
                        : 'No vets are linked to this pet yet.',
                    icon: Icons.local_hospital_outlined,
                    actionLabel: 'Add vet',
                    onAction: () => _openForm(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
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
                                vet: vet,
                              ),
                            ),
                          );
                          if (changed == true) await _load();
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
                                      color: AppColors.textSecondary,
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
                                    style: AppComponents.secondaryButton,
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
    required this.pets,
    this.vet,
    this.linkedPetIds = const [],
  });
  final PetRepository repository;
  final NotificationService notificationService;
  final List<Pet> pets;
  final Vet? vet;
  final List<int> linkedPetIds;
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
  late final Set<int> _selected = {...widget.linkedPetIds};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _clinic, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
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
    if (widget.vet == null) {
      await widget.repository.addVet(vet, _selected.toList());
    } else {
      await widget.repository.updateVet(vet, _selected.toList());
    }
    await widget.notificationService.rescheduleAll();
    if (mounted) Navigator.pop(context, true);
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.vet == null ? 'Add Vet' : 'Edit Vet')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_name, 'Name', required: true),
          _field(_clinic, 'Clinic'),
          _field(
            _phone,
            'Phone',
            required: true,
            validator: validateVetPhone,
            keyboard: TextInputType.phone,
          ),
          _field(
            _email,
            'Email',
            validator: validateVetEmail,
            keyboard: TextInputType.emailAddress,
          ),
          _field(_address, 'Address'),
          _field(_notes, 'Notes', lines: 3),
          const SizedBox(height: 16),
          Text('Associated pets', style: AppTypography.h2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: widget.pets
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
            child: Text(_saving ? 'Saving…' : 'Save vet'),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: lines,
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
        fillColor: AppColors.surface,
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
  });
  final PetRepository repository;
  final Vet vet;
  final NotificationService notificationService;
  @override
  State<VetDetailsScreen> createState() => _VetDetailsScreenState();
}

class _VetDetailsScreenState extends State<VetDetailsScreen> {
  bool _loading = true;
  bool _changed = false;
  Vet? _vet;
  List<Pet> _pets = [];
  Map<int, DateTime?> _appointments = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.vet.id;
    if (id == null) return;
    final vet = await widget.repository.getVetById(id);
    final pets = await widget.repository.getPetsForVet(id);
    final links = await widget.repository.getVetPetAssociations(id);
    if (mounted) {
      setState(() {
        _vet = vet;
        _pets = pets;
        _appointments = {
          for (final link in links) link.petId: link.nextAppointmentDate,
        };
        _loading = false;
      });
    }
  }

  Future<void> _call() async {
    final phone = _vet?.phone ?? '';
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri) && await launchUrl(uri)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Call $phone')));
    }
  }

  String _date(DateTime? value) => value == null
      ? 'Not set'
      : '${_month(value.month)} ${value.day}, ${value.year}';
  String _month(int month) => const [
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
  ][month - 1];
  Future<void> _appointment(Pet pet) async {
    final current = _appointments[pet.id];
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      await widget.repository.setNextAppointment(_vet!.id!, pet.id!, selected);
      await widget.notificationService.rescheduleAll();
      _changed = true;
      await _load();
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
    await widget.repository.deleteVet(_vet!.id!);
    await widget.notificationService.rescheduleAll();
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
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: const Text('Vet Details'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
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
                          color: AppColors.textSecondary,
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
                      color: AppColors.surface,
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
                                    _date(_appointments[pet.id]),
                                    style: AppTypography.caption.copyWith(
                                      color: _appointments[pet.id] == null
                                          ? AppColors.textDisabled
                                          : AppColors.textPrimary,
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
                                onPressed: () async {
                                  await widget.repository.setNextAppointment(
                                    vet.id!,
                                    pet.id!,
                                    null,
                                  );
                                  await widget.notificationService
                                      .rescheduleAll();
                                  _changed = true;
                                  await _load();
                                },
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
                      final pets = await widget.repository.getPets();
                      if (!context.mounted) return;
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VetFormScreen(
                            repository: widget.repository,
                            notificationService: widget.notificationService,
                            pets: pets,
                            vet: vet,
                            linkedPetIds: _pets.map((pet) => pet.id!).toList(),
                          ),
                        ),
                      );
                      if (changed == true) {
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
    backgroundColor: AppColors.primaryMuted,
    labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
    visualDensity: VisualDensity.compact,
  );
}
