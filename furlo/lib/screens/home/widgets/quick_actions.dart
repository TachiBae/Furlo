part of '../home_screen.dart';

// The Quick Actions grid.

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpen,
    required this.repository,
    required this.notificationService,
    required this.storageScope,
    required this.pets,
    required this.selectedPet,
  });
  final ValueChanged<Widget> onOpen;
  final PetRepository repository;
  final NotificationService notificationService;
  final String? storageScope;
  final List<Pet> pets;
  final Pet? selectedPet;

  @override
  Widget build(BuildContext context) {
    // Destination screens are built lazily on tap; constructing all five
    // on every home rebuild was wasted work.
    final actions = [
      _ActionData(
        'Feeding',
        Icons.restaurant_outlined,
        () => FeedingScreen(
          repository: repository,
          notificationService: notificationService,
          storageScope: storageScope,
        ),
      ),
      _ActionData(
        'Vaccinations',
        Icons.vaccines_outlined,
        () => VaccinationScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Health Records',
        Icons.medical_information_outlined,
        () => HealthRecordsScreen(
          repository: repository,
          notificationService: notificationService,
          pets: pets,
          selectedPet: selectedPet,
        ),
      ),
      _ActionData(
        'Vet Contacts',
        Icons.local_hospital_outlined,
        () => VetContactsScreen(
          repository: repository,
          notificationService: notificationService,
          storageScope: storageScope,
        ),
      ),
      _ActionData(
        'Weight Tracking',
        Icons.monitor_weight_outlined,
        () => WeightTrackingScreen(
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
          color: context.appColors.surface,
          borderRadius: AppRadius.mdRadius,
          child: InkWell(
            borderRadius: AppRadius.mdRadius,
            onTap: () => onOpen(action.buildScreen()),
            // No chevron: the whole tile is the target, and at 375px the
            // label needs that width or 'Vaccinations' breaks mid-word.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(action.icon, color: context.appColors.primary, size: 21),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      action.label,
                      style: AppTypography.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
  const _ActionData(this.label, this.icon, this.buildScreen);
  final String label;
  final IconData icon;
  final Widget Function() buildScreen;
}
