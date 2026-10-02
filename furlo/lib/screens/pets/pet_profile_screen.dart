import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/pet.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pet_file_image.dart';
import '../feeding/feeding_screen.dart';
import '../health/health_records_screen.dart';
import 'pet_onboarding_screen.dart';
import '../vaccinations/vaccination_screen.dart';
import '../vets/vet_contacts_screen.dart';
import '../weight/weight_tracking_screen.dart';

int? petAgeInMonths(DateTime? birthDate, {DateTime? today}) {
  if (birthDate == null) return null;
  final now = today ?? DateTime.now();
  if (birthDate.isAfter(now)) return null;
  var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  if (now.day < birthDate.day) months--;
  return months < 0 ? null : months;
}

String petAgeLabel(DateTime? birthDate, {DateTime? today}) {
  final months = petAgeInMonths(birthDate, today: today);
  if (months == null) {
    return 'Not provided';
  }
  final years = months ~/ 12;
  final remainingMonths = months % 12;
  if (years == 0) {
    return '$remainingMonths ${remainingMonths == 1 ? 'mo' : 'mos'}';
  }
  if (remainingMonths == 0) {
    return '$years ${years == 1 ? 'yr' : 'yrs'}';
  }
  return '$years ${years == 1 ? 'yr' : 'yrs'} $remainingMonths ${remainingMonths == 1 ? 'mo' : 'mos'}';
}

class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({
    super.key,
    required this.petId,
    required this.repository,
    required this.pets,
    this.notificationService = const NoOpNotificationService(),
    this.onPetDeleted,
  });

  final int petId;
  final PetRepository repository;
  final List<Pet> pets;
  final NotificationService notificationService;
  final ValueChanged<int>? onPetDeleted;

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  late Future<void> _load;
  Pet? _pet;
  Map<String, int> _counts = {};
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load = _refresh();
  }

  Future<void> _refresh() async {
    final pets = await widget.repository.getPets();
    final pet = pets.where((item) => item.id == widget.petId).firstOrNull;
    if (pet == null) throw StateError('Pet not found');
    final results = await Future.wait<Object>([
      widget.repository.getFeedingSchedules(widget.petId),
      widget.repository.getVaccinationsForPet(widget.petId),
      widget.repository.getHealthRecordsForPet(widget.petId),
      widget.repository.getVetsForPet(widget.petId),
      widget.repository.getWeightLogsForPet(widget.petId),
    ]);
    if (!mounted) return;
    setState(() {
      _pet = pet;
      _counts = {
        'Feeding': (results[0] as List).length,
        'Vaccinations': (results[1] as List).length,
        'Health Records': (results[2] as List).length,
        'Vets': (results[3] as List).length,
        'Weight': (results[4] as List).length,
      };
    });
  }

  Future<void> _edit() async {
    final pet = _pet;
    if (pet == null) return;
    final saved = await Navigator.of(context).push<Pet>(
      MaterialPageRoute(
        builder: (_) =>
            AddPetScreen(repository: widget.repository, existingPet: pet),
      ),
    );
    if (saved != null && mounted) {
      setState(() => _load = _refresh());
    }
  }

  Future<void> _delete() async {
    final pet = _pet;
    if (pet == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pet?'),
        content: Text(
          '${pet.name} and all of their feeding, vaccination, health, weight, and vet-link records. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Delete pet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.repository.deletePet(widget.petId);
      widget.onPetDeleted?.call(widget.petId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this pet. Please try again.'),
          ),
        );
      }
    }
  }

  void _openLink(String label) {
    final pet = _pet;
    if (pet == null) return;
    Widget screen;
    switch (label) {
      case 'Feeding':
        screen = FeedingScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: widget.pets,
          selectedPet: pet,
        );
      case 'Vaccinations':
        screen = VaccinationScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: widget.pets,
          selectedPet: pet,
        );
      case 'Health Records':
        screen = HealthRecordsScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: widget.pets,
          selectedPet: pet,
        );
      case 'Vets':
        screen = VetContactsScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: widget.pets,
          selectedPet: pet,
        );
      default:
        screen = WeightTrackingScreen(
          repository: widget.repository,
          pets: widget.pets,
          selectedPet: pet,
        );
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text('Pet Profile'),
      actions: [
        IconButton(
          tooltip: 'Edit pet',
          onPressed: _pet == null ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        final pet = _pet;
        if (snapshot.connectionState == ConnectionState.waiting &&
            pet == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || pet == null) {
          return Center(
            child: Text(
              'Could not load this pet.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        final photo = _photo(pet.photoPath);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppColors.primaryMuted,
                        backgroundImage: photo,
                        child: photo == null
                            ? const Icon(
                                Icons.pets,
                                size: 42,
                                color: AppColors.textPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(pet.name, style: AppTypography.h1),
                      Text(
                        [
                          pet.species,
                          if (pet.breed?.trim().isNotEmpty == true) pet.breed!,
                        ].join(' · '),
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        petAgeLabel(pet.birthDate),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Details', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                _details(pet),
                const SizedBox(height: AppSpacing.lg),
                Text('Care records', style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                ...[
                  'Feeding',
                  'Vaccinations',
                  'Health Records',
                  'Vets',
                  'Weight',
                ].map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _linkTile(label),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_deleting ? 'Deleting…' : 'Delete pet'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _details(Pet pet) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.mdRadius,
    ),
    child: Column(
      children: [
        _detailRow('Name', pet.name),
        _detailRow('Species', pet.species),
        _detailRow('Breed', pet.breed),
        _detailRow(
          'Birthdate',
          pet.birthDate == null
              ? null
              : '${pet.birthDate!.month}/${pet.birthDate!.day}/${pet.birthDate!.year}',
        ),
        _detailRow('Age', petAgeLabel(pet.birthDate)),
      ],
    ),
  );

  Widget _detailRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value?.trim().isNotEmpty == true ? value! : 'Not provided',
            style: AppTypography.body.copyWith(
              color: value?.trim().isNotEmpty == true
                  ? AppColors.textPrimary
                  : AppColors.textDisabled,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _linkTile(String label) => Material(
    color: AppColors.surface,
    borderRadius: AppRadius.mdRadius,
    child: InkWell(
      onTap: () => _openLink(label),
      borderRadius: AppRadius.mdRadius,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(_icon(label), color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTypography.bodyStrong)),
              Text(
                '${_counts[label] ?? 0}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    ),
  );

  ImageProvider? _photo(String? path) {
    if (path == null) return null;
    if (!path.startsWith('data:')) return petFileImage(path);
    try {
      return MemoryImage(base64Decode(path.substring(path.indexOf(',') + 1)));
    } catch (_) {
      return null;
    }
  }

  IconData _icon(String label) => switch (label) {
    'Feeding' => Icons.restaurant_outlined,
    'Vaccinations' => Icons.vaccines_outlined,
    'Health Records' => Icons.medical_information_outlined,
    'Vets' => Icons.local_hospital_outlined,
    _ => Icons.monitor_weight_outlined,
  };
}
