import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../providers/furlo_state.dart';
import '../../providers/home_reminders_provider.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/pet_repository.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../services/notifications_service.dart';
import '../../screens/feeding/feeding_screen.dart';
import '../../screens/health/health_records_screen.dart';
import '../../screens/pets/pet_onboarding_screen.dart';
import '../../screens/pets/pet_profile_screen.dart';
import '../../screens/settings/notifications_screen.dart';
import '../../screens/settings/profile_screen.dart';
import '../../screens/vaccinations/vaccination_screen.dart';
import '../../screens/vets/vet_contacts_screen.dart';
import '../../screens/weight/weight_tracking_screen.dart';
import '../../utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.notificationSettings,
    required this.notificationService,
  });

  final PetRepository repository;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppSettingsRepository _appSettings =
      SharedPreferencesAppSettingsRepository();
  late final HomeRemindersProvider _remindersProvider = HomeRemindersProvider(
    widget.repository,
  );
  late Future<List<Pet>> _pets;
  List<Pet>? _cachedPets;
  int? _fallbackSelectedPetId;
  int _activeTab = 0;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _pets = _loadPets();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final name = await _appSettings.getDisplayName();
      if (mounted) setState(() => _displayName = name);
    } catch (_) {}
  }

  Future<List<Pet>> _loadPets() async {
    final pets = await widget.repository.getPets();
    if (mounted) {
      context.read<FurloState?>()?.setPets(pets);
      _fallbackSelectedPetId =
          pets.any((pet) => pet.id == _fallbackSelectedPetId)
          ? _fallbackSelectedPetId
          : pets.firstOrNull?.id;
      await _remindersProvider.refresh(pets: pets);
    }
    return pets;
  }

  @override
  void dispose() {
    _remindersProvider.dispose();
    super.dispose();
  }

  Future<void> _addPet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPetScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _pets = _loadPets());
  }

  Future<void> _openPetProfile(Pet pet) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(
          petId: pet.id!,
          repository: widget.repository,
          pets: _cachedPets ?? [pet],
          notificationService: widget.notificationService,
        ),
      ),
    );
    if (!mounted) return;
    final pets = await widget.repository.getPets();
    if (!mounted) return;
    setState(() {
      _cachedPets = pets;
      context.read<FurloState?>()?.setPets(pets);
      _fallbackSelectedPetId =
          pets.any((item) => item.id == _fallbackSelectedPetId)
          ? _fallbackSelectedPetId
          : pets.firstOrNull?.id;
      _pets = Future.value(pets);
    });
    await _remindersProvider.refresh(pets: pets);
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
    setState(() => _pets = _loadPets());
    await _loadDisplayName();
  }

  void _openProfile() => _open(
    ProfileScreen(
      repository: widget.repository,
      appSettings: _appSettings,
      notificationSettings: widget.notificationSettings,
      notificationService: widget.notificationService,
    ),
  );

  Future<void> _openAllPets(List<Pet> pets) async {
    final selected = await Navigator.of(
      context,
    ).push<Pet>(MaterialPageRoute(builder: (_) => _AllPetsScreen(pets: pets)));
    if (selected != null && mounted) {
      _fallbackSelectedPetId = selected.id;
      context.read<FurloState?>()?.selectPet(selected);
      await _openPetProfile(selected);
    }
  }

  void _openReminder(HomeReminder reminder, List<Pet> pets) {
    final pet = pets.where((item) => item.id == reminder.petId).firstOrNull;
    if (pet == null) return;
    Widget screen;
    switch (reminder.type) {
      case ReminderType.feeding:
        screen = FeedingScreen(
          repository: widget.repository,
          notificationService: widget.notificationService,
          pets: pets,
          selectedPet: pet,
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
          pets: pets,
          selectedPet: pet,
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

  void _showMoreReminders(List<HomeReminder> reminders, List<Pet> pets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    // This navigation bar launches secondary screens from the dashboard;
    // Home remains the active dashboard destination when those routes close.
    setState(() => _activeTab = 0);
    switch (index) {
      case 0:
        break;
      case 1:
        _open(
          NotificationsScreen(
            settings: widget.notificationSettings,
            service: widget.notificationService,
          ),
        );
        break;
      case 2:
        _addPet();
        break;
      case 3:
        break;
      case 4:
        _openProfile();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: FutureBuilder<List<Pet>>(
              future: _pets,
              builder: (context, snapshot) {
                final pets = snapshot.data ?? const <Pet>[];
                _cachedPets = pets;
                final storedSelection = context
                    .watch<FurloState?>()
                    ?.selectedPet;
                final selectedPet =
                    pets
                        .where(
                          (pet) =>
                              pet.id ==
                              (storedSelection?.id ?? _fallbackSelectedPetId),
                        )
                        .firstOrNull ??
                    pets.firstOrNull;
                return CustomScrollView(
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
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeading(
                            title: 'My Pets',
                            action: 'See all',
                            onAction: () => _openAllPets(pets),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const SizedBox(
                              height: 130,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (snapshot.hasError)
                            const _MessageCard(
                              message: 'Your pets could not be loaded.',
                            )
                          else if (pets.isEmpty)
                            _AddFirstPetCard(onTap: _addPet)
                          else
                            SizedBox(
                              height: 150,
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
                                        selected:
                                            pets[index].id == selectedPet?.id,
                                        onTap: () {
                                          _fallbackSelectedPetId =
                                              pets[index].id;
                                          context
                                              .read<FurloState?>()
                                              ?.selectPet(pets[index]);
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
                            pets: pets,
                            selectedPet: selectedPet,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: _HomeBottomBar(
        activeTab: _activeTab,
        onTap: _selectTab,
        onAddPet: _addPet,
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.activeTab,
    required this.onTap,
    required this.onAddPet,
  });

  final int activeTab;
  final ValueChanged<int> onTap;
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) => BottomAppBar(
    color: AppColors.surface,
    elevation: 8,
    padding: EdgeInsets.zero,
    child: SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.textDisabled, width: 0.35),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                selected: activeTab == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                label: 'Alerts',
                icon: Icons.notifications_none,
                selectedIcon: Icons.notifications,
                selected: activeTab == 1,
                showBadge: true,
                onTap: () => onTap(1),
              ),
            ),
            Expanded(child: _AddPetNavItem(onTap: onAddPet)),
            Expanded(
              child: _NavItem(
                label: 'My Pets',
                icon: Icons.pets_outlined,
                selectedIcon: Icons.pets,
                selected: activeTab == 3,
                onTap: () => onTap(3),
              ),
            ),
            Expanded(
              child: _NavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                selected: activeTab == 4,
                onTap: () => onTap(4),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddPetNavItem extends StatelessWidget {
  const _AddPetNavItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add Pet',
    child: Tooltip(
      message: 'Add Pet',
      child: Center(
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.add, size: 27, color: AppColors.textOnPrimary),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: showBadge ? '$label, unread reminders' : label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          containedInkWell: true,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: selected ? 1.08 : 1,
                        child: Icon(
                          selected ? selectedIcon : icon,
                          size: 27,
                          color: iconColor,
                        ),
                      ),
                      if (showBadge)
                        Positioned(
                          top: 1,
                          right: 5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: selected
                      ? Text(
                          label,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                        )
                      : const SizedBox(height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.date,
    required this.displayName,
    required this.onSettings,
  });
  final DateTime date;
  final String displayName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${displayName.isEmpty ? 'pet parent' : displayName}!',
              style: AppTypography.h1,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDate(date),
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        onPressed: onSettings,
        tooltip: 'Settings',
        icon: const Icon(Icons.person_outline),
      ),
    ],
  );

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppTypography.h2.copyWith(color: AppColors.primary),
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class _PetTile extends StatelessWidget {
  const _PetTile({
    required this.pet,
    required this.selected,
    required this.onTap,
    this.width = 145,
  });
  final Pet pet;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final data = pet.photoPath;
    final image = data != null && data.startsWith('data:')
        ? MemoryImage(base64Decode(data.substring(data.indexOf(',') + 1)))
        : null;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.primary.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primaryMuted,
                backgroundImage: image,
                child: image == null
                    ? const Icon(Icons.pets, color: AppColors.textPrimary)
                    : null,
              ),
              const Spacer(),
              Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong,
              ),
              Text(
                [
                  pet.species,
                  if (pet.breed?.isNotEmpty == true) pet.breed!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPetTile extends StatelessWidget {
  const _AddPetTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 30),
          SizedBox(height: AppSpacing.sm),
          Text('Add pet'),
        ],
      ),
    ),
  );
}

class _AddFirstPetCard extends StatelessWidget {
  const _AddFirstPetCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.pets, color: AppColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('Add a pet to start keeping their care in one place.'),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
          ),
        ],
      ),
    ),
  );
}

class _ReminderEmptyCard extends StatelessWidget {
  const _ReminderEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.lgRadius,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All caught up', style: AppTypography.bodyStrong),
              Text(
                'Your care reminders will show here.',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeRemindersSection extends StatelessWidget {
  const _HomeRemindersSection({
    required this.provider,
    required this.onTap,
    required this.onMore,
  });

  final HomeRemindersProvider provider;
  final ValueChanged<HomeReminder> onTap;
  final ValueChanged<List<HomeReminder>> onMore;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: provider,
    child: Consumer<HomeRemindersProvider>(
      builder: (context, state, _) {
        if (state.loading && state.reminders.isEmpty) {
          return const SizedBox(
            height: 84,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.hasError && state.reminders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgRadius,
            ),
            child: Text(
              'Your reminders could not be loaded. Try again later.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        if (state.reminders.isEmpty) return const _ReminderEmptyCard();
        final visible = state.result.visibleItems;
        return Column(
          children: [
            ...visible.map(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ReminderTile(
                  reminder: reminder,
                  onTap: () => onTap(reminder),
                ),
              ),
            ),
            if (state.result.remainingCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onMore(state.reminders),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text('+${state.result.remainingCount} more'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.onTap});
  final HomeReminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgencyColor = switch (reminder.urgency) {
      ReminderUrgency.overdue => AppColors.danger,
      ReminderUrgency.today => AppColors.warning,
      ReminderUrgency.upcoming => AppColors.textSecondary,
    };
    final trailing = reminder.time ?? _dateLabel(reminder.date);
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(_reminderIcon(reminder.type), color: urgencyColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                      Text(
                        reminder.petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailing,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _urgencyLabel(reminder.urgency),
                      style: AppTypography.caption.copyWith(
                        color: urgencyColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) {
      return '';
    }
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}';
  }

  String _urgencyLabel(ReminderUrgency urgency) => switch (urgency) {
    ReminderUrgency.overdue => 'Overdue',
    ReminderUrgency.today => 'Today',
    ReminderUrgency.upcoming => 'Upcoming',
  };

  IconData _reminderIcon(ReminderType type) => switch (type) {
    ReminderType.feeding => Icons.restaurant_outlined,
    ReminderType.vaccination => Icons.vaccines_outlined,
    ReminderType.vetAppointment => Icons.local_hospital_outlined,
    ReminderType.medication => Icons.medication_outlined,
  };
}

class _AllPetsScreen extends StatelessWidget {
  const _AllPetsScreen({required this.pets});
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Pets')),
    body: pets.isEmpty
        ? Center(
            child: Text(
              'No pets yet.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _PetTile(
              pet: pets[index],
              selected: false,
              width: double.infinity,
              onTap: () => Navigator.of(context).pop(pets[index]),
            ),
          ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpen,
    required this.repository,
    required this.notificationService,
    required this.pets,
    required this.selectedPet,
  });
  final ValueChanged<Widget> onOpen;
  final PetRepository repository;
  final NotificationService notificationService;
  final List<Pet> pets;
  final Pet? selectedPet;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        'Feeding',
        Icons.restaurant_outlined,
        FeedingScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Vaccines',
        Icons.vaccines_outlined,
        VaccinationScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Health Records',
        Icons.medical_information_outlined,
        HealthRecordsScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Vet Contacts',
        Icons.local_hospital_outlined,
        VetContactsScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Weight Tracking',
        Icons.monitor_weight_outlined,
        WeightTrackingScreen(
          repository: repository,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: AppColors.surface,
          borderRadius: AppRadius.mdRadius,
          child: InkWell(
            borderRadius: AppRadius.mdRadius,
            onTap: () => onOpen(action.screen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(action.icon, color: AppColors.primary, size: 21),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(action.label, style: AppTypography.bodyStrong),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionData {
  const _ActionData(this.label, this.icon, this.screen);
  final String label;
  final IconData icon;
  final Widget screen;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(message),
    ),
  );
}
