import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/pet.dart';
import '../../repositories/pet_repository.dart';
import '../../screens/feeding/feeding_screen.dart';
import '../../screens/health/health_records_screen.dart';
import '../../screens/pets/pet_onboarding_screen.dart';
import '../../screens/settings/notifications_screen.dart';
import '../../screens/settings/profile_screen.dart';
import '../../screens/vaccinations/vaccination_screen.dart';
import '../../screens/vets/vet_contacts_screen.dart';
import '../../screens/weight/weight_tracking_screen.dart';
import '../../utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final PetRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Pet>> _pets;

  @override
  void initState() {
    super.initState();
    _pets = widget.repository.getPets();
  }

  Future<void> _addPet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPetScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(() => _pets = widget.repository.getPets());
  }

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _selectTab(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        _open(const NotificationsScreen());
        break;
      case 2:
        _addPet();
        break;
      case 3:
        setState(() {});
        break;
      case 4:
        _open(const ProfileScreen());
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
                            onSettings: () => _open(const ProfileScreen()),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeading(
                            title: 'My Pets',
                            action: 'See all',
                            onAction: () {},
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
                                    : _PetTile(pet: pets[index]),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          const _SectionHeading(title: "Today's Reminders"),
                          const SizedBox(height: AppSpacing.sm),
                          const _ReminderEmptyCard(),
                          const SizedBox(height: AppSpacing.lg),
                          const _SectionHeading(title: 'Quick Actions'),
                          const SizedBox(height: AppSpacing.sm),
                          _QuickActions(onOpen: _open),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Pet',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'My Pets',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.date, required this.onSettings});
  final DateTime date;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, pet parent!', style: AppTypography.h1),
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
  const _PetTile({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final data = pet.photoPath;
    final image = data != null && data.startsWith('data:')
        ? MemoryImage(base64Decode(data.substring(data.indexOf(',') + 1)))
        : null;
    return Container(
      width: 145,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpen});
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData('Feeding', Icons.restaurant_outlined, const FeedingScreen()),
      _ActionData(
        'Vaccines',
        Icons.vaccines_outlined,
        const VaccinationScreen(),
      ),
      _ActionData(
        'Health Records',
        Icons.medical_information_outlined,
        const HealthRecordsScreen(),
      ),
      _ActionData(
        'Vet Contacts',
        Icons.local_hospital_outlined,
        const VetContactsScreen(),
      ),
      _ActionData(
        'Weight Tracking',
        Icons.monitor_weight_outlined,
        const WeightTrackingScreen(),
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
