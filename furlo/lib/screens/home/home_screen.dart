import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../providers/furlo_state.dart';
import '../../providers/home_reminders_provider.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../repositories/pet_repository.dart';
import '../../screens/feeding/feeding_screen.dart';
import '../../screens/health/health_records_screen.dart';
import '../../screens/pets/pet_form_screen.dart';
import '../../screens/pets/pet_profile_screen.dart';
import '../../screens/settings/notifications_screen.dart';
import '../../screens/settings/profile_screen.dart';
import '../../screens/vaccinations/vaccination_screen.dart';
import '../../screens/vets/vet_contacts_screen.dart';
import '../../screens/weight/weight_tracking_screen.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_diagnostics.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatting.dart';
import '../../widgets/record_components.dart';

part 'widgets/all_pets_screen.dart';
part 'widgets/home_bottom_bar.dart';
part 'widgets/home_pets.dart';
part 'widgets/home_reminders.dart';
part 'widgets/quick_actions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
    this.storageScope,
    this.appSettings,
    this.onDeleteAccount,
  });

  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;
  final String? storageScope;

  /// Where the display name lives. The signed-in app passes the
  /// account-synced store; without one this device's store is used.
  final AppSettingsRepository? appSettings;

  /// Deletes the signed-in account; null hides the option (no account).
  final Future<void> Function(String? password)? onDeleteAccount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppSettingsRepository _appSettings =
      widget.appSettings ??
      SharedPreferencesAppSettingsRepository(storageScope: widget.storageScope);
  late final HomeRemindersProvider _remindersProvider = HomeRemindersProvider(
    widget.repository,
    notificationService: widget.notificationService,
  );
  late final FurloState _furloState;
  // The pet list the reminders were last built for. FurloState caches its
  // pets view, so identity changes only when the list itself changes.
  List<Pet>? _remindersBuiltFor;
  int _activeTab = 0;
  StreamSubscription<NotificationTap>? _tapSubscription;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _furloState = context.read<FurloState>();
    _furloState.addListener(_onFurloStateChanged);
    _refreshReminders();
    _tapSubscription = widget.notificationService.taps.listen(
      _handleNotificationTap,
    );
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final name = await _appSettings.getDisplayName();
      if (mounted) setState(() => _displayName = name);
    } catch (_) {
      // The greeting falls back to a generic name, so this is not worth
      // interrupting the user for, but it should not vanish silently either.
      logAppDiagnostic('Display name could not be loaded.');
    }
  }

  /// Selecting a pet or a load toggling notifies too; reminders only depend
  /// on which pets exist, so anything else would be a wasted reload.
  void _onFurloStateChanged() {
    if (identical(_furloState.pets, _remindersBuiltFor)) return;
    _refreshReminders();
  }

  void _refreshReminders() {
    _remindersBuiltFor = _furloState.pets;
    unawaited(_remindersProvider.refresh(pets: _remindersBuiltFor));
  }

  @override
  void dispose() {
    unawaited(_tapSubscription?.cancel());
    _furloState.removeListener(_onFurloStateChanged);
    _remindersProvider.dispose();
    super.dispose();
  }

  Future<void> _addPet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPetScreen(
          repository: widget.repository,
          notificationSettings: widget.notificationSettings,
          notificationService: widget.notificationService,
          storageScope: widget.storageScope,
        ),
      ),
    );
  }

  Future<void> _openPetProfile(Pet pet) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(
          petId: pet.id!,
          repository: widget.repository,
          notificationService: widget.notificationService,
          storageScope: widget.storageScope,
        ),
      ),
    );
    if (!mounted) return;
    // Records may have changed on the profile's linked screens.
    _refreshReminders();
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${pet.name} was deleted.')));
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    // Feeding, vaccinations, health and vets all change what is due today.
    _refreshReminders();
    await _loadDisplayName();
  }

  Future<void> _openProfile() => _open(
    ProfileScreen(
      repository: widget.repository,
      appSettings: _appSettings,
      onDeleteAccount: widget.onDeleteAccount,
      notificationSettings: widget.notificationSettings,
      notificationService: widget.notificationService,
      storageScope: widget.storageScope,
    ),
  );

  Future<void> _openAllPets() async {
    final selected = await Navigator.of(context).push<Pet>(
      MaterialPageRoute(builder: (_) => _AllPetsScreen(onAddPet: _addPet)),
    );
    if (selected != null && mounted) {
      _furloState.selectPet(selected);
      await _openPetProfile(selected);
    }
  }

  void _openReminder(HomeReminder reminder, List<Pet> pets) {
    final pet = pets.where((item) => item.id == reminder.petId).firstOrNull;
    if (pet == null) return;
    _openRecordScreen(reminder.type, pet, pets);
  }

  /// Opens the screen that owns a [type] of record, with [pet] selected.
  void _openRecordScreen(ReminderType type, Pet pet, List<Pet> pets) {
    Widget screen;
    switch (type) {
      case ReminderType.feeding:
        screen = FeedingScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          storageScope: widget.storageScope,
        );
      case ReminderType.vaccination:
        screen = VaccinationScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: pets,
          selectedPet: pet,
        );
      case ReminderType.vetAppointment:
        screen = VetContactsScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          storageScope: widget.storageScope,
        );
      case ReminderType.medication:
        screen = HealthRecordsScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: pets,
          selectedPet: pet,
        );
    }
    context.read<FurloState?>()?.selectPet(pet);
    _open(screen);
  }

  /// A tapped reminder opens its screen for its pet; "Mark fed" feeds the
  /// meal without leaving the dashboard.
  Future<void> _handleNotificationTap(NotificationTap tap) async {
    try {
      final target = await _resolveTap(tap);
      if (target == null || !mounted) return;
      final (type, pet, title) = target;
      if (tap.markFed && type == ReminderType.feeding) {
        await _remindersProvider.markFed(
          HomeReminder(
            petId: pet.id!,
            petName: pet.name,
            title: title,
            type: type,
            urgency: ReminderUrgency.today,
            recordId: tap.recordId,
            secondMeal: tap.isSecondMeal,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title marked fed.')));
        return;
      }
      _furloState.selectPet(pet);
      _openRecordScreen(type, pet, _furloState.pets);
    } catch (_) {
      logAppDiagnostic('Notification tap could not be handled.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That reminder could not be opened.')),
      );
    }
  }

  /// The screen type, pet and record title a reminder belongs to, or null
  /// when the record or its pet no longer exists.
  Future<(ReminderType, Pet, String)?> _resolveTap(NotificationTap tap) async {
    final repository = widget.repository;
    ReminderType type;
    String? petId;
    var title = '';
    switch (tap.type) {
      case NotificationTypes.dailyFeeding:
      case NotificationTypes.missedMeal:
        final entry = (await repository.getAllFeedingSchedules())
            .where((item) => item.id == tap.recordId)
            .firstOrNull;
        type = ReminderType.feeding;
        petId = entry?.petId;
        title = entry?.name ?? '';
      case NotificationTypes.upcomingVaccine:
      case NotificationTypes.overdueVaccine:
        final record = (await repository.getAllVaccinations())
            .where((item) => item.id == tap.recordId)
            .firstOrNull;
        type = ReminderType.vaccination;
        petId = record?.petId;
        title = record?.vaccineName ?? '';
      case NotificationTypes.medication:
        final record = (await repository.getAllHealthRecords())
            .where((item) => item.id == tap.recordId)
            .firstOrNull;
        type = ReminderType.medication;
        petId = record?.petId;
        title = record?.title ?? '';
      case NotificationTypes.vetAppointment:
        type = ReminderType.vetAppointment;
        petId = tap.petId;
      default:
        return null;
    }
    final pet = _furloState.pets.where((item) => item.id == petId).firstOrNull;
    return pet == null ? null : (type, pet, title);
  }

  Future<void> _markFed(HomeReminder reminder) async {
    try {
      await _remindersProvider.markFed(reminder);
    } catch (_) {
      logAppDiagnostic('Dashboard mark-fed failed.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The meal could not be marked fed.')),
      );
    }
  }

  void _showMoreReminders(List<HomeReminder> reminders, List<Pet> pets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.bg,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text("Today's Reminders", style: AppTypography.h2),
                    ),
                    IconButton(
                      tooltip: 'Close reminders',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: reminders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _ReminderTile(
                    reminder: reminders[index],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openReminder(reminders[index], pets);
                    },
                    onMarkFed: () {
                      Navigator.pop(sheetContext);
                      _markFed(reminders[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTab(int index) async {
    // The tapped destination highlights while its route is open; Home
    // becomes the active dashboard destination again when that route closes.
    if (index == 0) {
      setState(() => _activeTab = 0);
      return;
    }
    setState(() => _activeTab = index);
    switch (index) {
      case 1:
        await _open(
          NotificationsScreen(
            settings: widget.notificationSettings,
            service: widget.notificationService,
            storageScope: widget.storageScope,
          ),
        );
      case 2:
        await _addPet();
      case 3:
        await _openAllPets();
      case 4:
        await _openProfile();
    }
    if (mounted) setState(() => _activeTab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Rebuild only when the pet list or selection changes; other FurloState
    // notifications (e.g. load progress) pass through without a rebuild.
    final pets = context.select<FurloState, List<Pet>>((s) => s.pets);
    final selectedPet = context.select<FurloState, Pet?>((s) => s.selectedPet);
    // Pets loaded earlier stay on screen when a refresh fails: an offline
    // moment must not look like deleted data.
    final refreshFailed = context.select<FurloState, bool>(
      (s) => s.loadError != null && s.pets.isNotEmpty,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _DashboardHeader(
                        date: today,
                        displayName: _displayName,
                        onSettings: _openProfile,
                      ),
                      if (refreshFailed) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PetsRefreshBanner(onRetry: _furloState.load),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _SectionHeading(
                        title: 'My Pets',
                        action: 'See all',
                        onAction: _openAllPets,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (pets.isEmpty)
                        _AddFirstPetCard(onTap: _addPet)
                      else
                        SizedBox(
                          // Tile captions are AppTypography.label, so the strip
                          // grows with the user's text scale. Pinned at 150 it
                          // clips the caption at 2.0.
                          height:
                              150 +
                              (MediaQuery.textScalerOf(
                                    context,
                                  ).scale(AppTypography.label.fontSize!) -
                                  AppTypography.label.fontSize!),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: pets.length + 1,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) =>
                                index == pets.length
                                ? _AddPetTile(onTap: _addPet)
                                : _PetTile(
                                    pet: pets[index],
                                    selected: pets[index].id == selectedPet?.id,
                                    onTap: () {
                                      _furloState.selectPet(pets[index]);
                                      _openPetProfile(pets[index]);
                                    },
                                  ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionHeading(title: "Today's Reminders"),
                      const SizedBox(height: AppSpacing.sm),
                      _HomeRemindersSection(
                        provider: _remindersProvider,
                        onTap: (reminder) => _openReminder(reminder, pets),
                        onMarkFed: _markFed,
                        onMore: (reminders) =>
                            _showMoreReminders(reminders, pets),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionHeading(title: 'Quick Actions'),
                      const SizedBox(height: AppSpacing.sm),
                      _QuickActions(
                        onOpen: _open,
                        repository: widget.repository,
                        notificationService: widget.notificationService,
                        storageScope: widget.storageScope,
                        pets: pets,
                        selectedPet: selectedPet,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _remindersProvider,
        builder: (context, _) => _HomeBottomBar(
          activeTab: _activeTab,
          reminderCount: _remindersProvider.reminders.length,
          onTap: _selectTab,
          onAddPet: _addPet,
        ),
      ),
    );
  }
}
