import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/pet.dart';
import '../../repositories/pet_repository.dart';
import '../../utils/app_theme.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.repository});

  final PetRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
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
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddPetScreen(repository: repository),
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
  );
}

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key, required this.repository});

  final PetRepository repository;

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _picker = ImagePicker();
  String? _species;
  DateTime? _birthDate;
  String? _photoPath;
  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
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
      await widget.repository.addPet(
        Pet(
          name: _nameController.text.trim(),
          species: _species!,
          breed: _breedController.text.trim().isEmpty
              ? null
              : _breedController.text.trim(),
          birthDate: _birthDate,
          photoPath: _photoPath,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(repository: widget.repository),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Add New Pet', style: AppTypography.h2),
        backgroundColor: AppColors.bg,
        centerTitle: true,
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
                  Center(
                    child: InkWell(
                      onTap: _choosePhoto,
                      borderRadius: BorderRadius.circular(64),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.surface,
                        backgroundImage: _photoBytes == null
                            ? null
                            : MemoryImage(_photoBytes!),
                        child: _photoBytes == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 30)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: _choosePhoto,
                      child: const Text('Add a photo'),
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
                  DropdownButtonFormField<String>(
                    initialValue: _species,
                    decoration: const InputDecoration(
                      hintText: 'Select species',
                    ),
                    items: const ['Dog', 'Cat', 'Bird', 'Rabbit', 'Other']
                        .map(
                          (species) => DropdownMenuItem(
                            value: species,
                            child: Text(species),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _species = value),
                    validator: (value) =>
                        value == null ? 'Choose a species' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Breed (optional)', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _breedController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Shiba Inu',
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
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _saving ? null : _savePet,
                    style: AppComponents.primaryButton,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Pet'),
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
