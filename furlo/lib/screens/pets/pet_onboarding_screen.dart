import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/pet_breeds.dart';
import '../../models/pet.dart';
import '../../providers/furlo_state.dart';
import '../../repositories/pet_repository.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pet_file_image.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
  });

  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.bg,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.lgRadius,
                        child: Image.asset(
                          'assets/images/onboarding-paw.jpeg',
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        "Track Your Pet's Care",
                        style: AppTypography.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Keep schedules, health records, and daily habits seamlessly organized.',
                        style: AppTypography.body.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddPetScreen(
                                repository: repository,
                                notificationSettings: notificationSettings,
                                notificationService: notificationService,
                              ),
                            ),
                          ),
                          style: AppComponents.primaryButton,
                          child: const Text('Get Started'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({
    super.key,
    required this.repository,
    this.notificationSettings,
    this.notificationService = const NoOpNotificationService(),
    this.existingPet,
  });

  final PetRepository repository;
  final NotificationSettingsRepository? notificationSettings;
  final NotificationService notificationService;
  final Pet? existingPet;

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  String? _species;
  String? _breed;
  DateTime? _birthDate;
  String? _photoPath;
  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pet = widget.existingPet;
    if (pet != null) {
      _nameController.text = pet.name;
      _species = pet.species;
      _breed = pet.breed;
      _birthDate = pet.birthDate;
      _photoPath = pet.photoPath;
      if (_photoPath?.startsWith('data:') == true) {
        try {
          _photoBytes = base64Decode(
            _photoPath!.substring(_photoPath!.indexOf(',') + 1),
          );
        } catch (_) {
          _photoBytes = null;
        }
      }
    }
  }

  Future<void> _selectBreed(double fieldWidth) async {
    final species = _species;
    if (species == null) return;
    final breeds = species == 'Dog' ? PetBreeds.dogs : PetBreeds.cats;
    final selected = await _showSelectionSheet(
      title: 'Select breed',
      searchHint: 'Search breeds',
      emptyMessage: 'No breeds found',
      options: breeds,
      species: species,
      selectedOption: _breed,
      fieldWidth: fieldWidth,
    );
    if (mounted && _species == species && selected != null) {
      setState(() => _breed = selected);
    }
  }

  Future<String?> _showSelectionSheet({
    required String title,
    required String searchHint,
    required String emptyMessage,
    required List<String> options,
    required String species,
    required String? selectedOption,
    required double fieldWidth,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints.tightFor(width: fieldWidth),
    backgroundColor: context.appColors.surface,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
    builder: (_) => _SearchableSelectionSheet(
      title: title,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      options: options,
      species: species,
      selectedOption: selectedOption,
      fieldWidth: fieldWidth,
    ),
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoPath =
            'data:${image.mimeType ?? 'image/jpeg'};base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the photo. Please try again.'),
        ),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select birthdate',
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final petName = _capitalizeFirst(_nameController.text.trim());
      final pet = Pet(
        id: widget.existingPet?.id,
        name: petName,
        species: _species!,
        breed: _breed,
        birthDate: _birthDate,
        photoPath: _photoPath,
      );
      if (widget.existingPet == null) {
        await context.read<FurloState>().addPet(pet);
      } else {
        await context.read<FurloState>().updatePet(pet);
      }
      if (!mounted) return;
      if (widget.existingPet != null) {
        Navigator.of(context).pop(pet);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            repository: widget.repository,
            notificationSettings:
                widget.notificationSettings ??
                SharedPreferencesNotificationSettingsRepository(),
            notificationService: widget.notificationService,
          ),
        ),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your pet. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      appBar: AppBar(
        title: Text(
          widget.existingPet == null ? 'Add New Pet' : 'Edit Pet',
          style: AppTypography.h2,
        ),
        backgroundColor: context.appColors.bg,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Center(
                    child: InkWell(
                      onTap: _choosePhoto,
                      borderRadius: BorderRadius.circular(64),
                      child: Builder(
                        builder: (context) {
                          final photo = _photoBytes != null
                              ? MemoryImage(_photoBytes!)
                              : (_photoPath == null ||
                                        _photoPath!.startsWith('data:')
                                    ? null
                                    : petFileImage(_photoPath!));
                          return CircleAvatar(
                            radius: 54,
                            backgroundColor: context.appColors.surface,
                            backgroundImage: photo,
                            child: photo == null
                                ? const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 30,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: _choosePhoto,
                          child: Text(
                            _photoPath == null ? 'Add a photo' : 'Change photo',
                          ),
                        ),
                        if (_photoPath != null)
                          TextButton(
                            onPressed: () => setState(() {
                              _photoPath = null;
                              _photoBytes = null;
                            }),
                            child: const Text('Remove photo'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Pet name', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'e.g. Mochi'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your pet’s name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Species', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: constraints.maxWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _species,
                        style: AppTypography.body,
                        decoration: const InputDecoration(
                          hintText: 'Select species',
                        ),
                        items: const ['Dog', 'Cat']
                            .map(
                              (species) => DropdownMenuItem(
                                value: species,
                                child: SizedBox(
                                  height: 48,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: FaIcon(
                                          species == 'Dog'
                                              ? FontAwesomeIcons.dog
                                              : FontAwesomeIcons.cat,
                                          size: 24,
                                          color: _species == species
                                              ? context.appColors.accent
                                              : context.appColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          species,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _species == species
                                                ? context.appColors.accent
                                                : context.appColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (_species == species)
                                        Icon(
                                          Icons.check,
                                          color: context.appColors.accent,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) => const ['Dog', 'Cat']
                            .map(
                              (species) => Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  species,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        itemHeight: 48,
                        isExpanded: true,
                        menuMaxHeight: 300,
                        dropdownColor: context.appColors.surface,
                        borderRadius: AppRadius.mdRadius,
                        onChanged: (value) => setState(() {
                          _species = value;
                          _breed = null;
                        }),
                        validator: (value) =>
                            value == null ? 'Choose a species' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Breed (optional)', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: constraints.maxWidth,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _species == null
                              ? null
                              : () => _selectBreed(constraints.maxWidth),
                          borderRadius: AppRadius.mdRadius,
                          child: InputDecorator(
                            isEmpty: _breed == null,
                            decoration: InputDecoration(
                              hintText: 'Select breed',
                              enabled: _species != null,
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _breed ?? '',
                              style: TextStyle(
                                color: _species == null
                                    ? context.appColors.textDisabled
                                    : context.appColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Birthdate (optional)', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _selectBirthDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _birthDate == null
                          ? 'Select birthdate'
                          : '${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year}',
                    ),
                  ),
                  if (_birthDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _birthDate = null),
                        child: const Text('Clear birthdate'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _saving ? null : _savePet,
                    style: AppComponents.primaryButton,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.existingPet == null
                                ? 'Save Pet'
                                : 'Save Changes',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalizeFirst(String value) {
  if (value.isEmpty) return value;
  final runes = value.runes;
  return '${String.fromCharCode(runes.first).toUpperCase()}${String.fromCharCodes(runes.skip(1))}';
}

class _SearchableSelectionSheet extends StatefulWidget {
  const _SearchableSelectionSheet({
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.options,
    required this.species,
    required this.selectedOption,
    required this.fieldWidth,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;
  final List<String> options;
  final String species;
  final String? selectedOption;
  final double fieldWidth;

  @override
  State<_SearchableSelectionSheet> createState() =>
      _SearchableSelectionSheetState();
}

class _SearchableSelectionSheetState extends State<_SearchableSelectionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = widget.options
        .where((breed) => breed.toLowerCase().contains(query))
        .toList();

    return SafeArea(
      child: SizedBox(
        width: widget.fieldWidth,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            AppSpacing.lg,
            0,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          ),
          child: SizedBox(
            height:
                (MediaQuery.sizeOf(context).height * 0.6 - (AppSpacing.lg * 2))
                    .clamp(0.0, MediaQuery.sizeOf(context).height * 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTypography.h2),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            widget.emptyMessage,
                            style: AppTypography.body.copyWith(
                              color: context.appColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final option = results[index];
                            final selected = option == widget.selectedOption;
                            return ListTile(
                              minTileHeight: 48,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              leading: SizedBox(
                                width: 24,
                                child: FaIcon(
                                  widget.species == 'Dog'
                                      ? FontAwesomeIcons.dog
                                      : FontAwesomeIcons.cat,
                                  size: 24,
                                  color: selected
                                      ? context.appColors.accent
                                      : context.appColors.textSecondary,
                                ),
                              ),
                              title: Text(
                                option,
                                style: AppTypography.body.copyWith(
                                  color: selected
                                      ? context.appColors.accent
                                      : context.appColors.textPrimary,
                                ),
                              ),
                              trailing: selected
                                  ? Icon(
                                      Icons.check,
                                      color: context.appColors.accent,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(option),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
