part of '../home_screen.dart';

// Dashboard header, section headings, pet tiles and the refresh banner.

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
                color: context.appColors.textSecondary,
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
          style: AppTypography.h2.copyWith(color: context.appColors.primary),
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
    MemoryImage? image;
    if (data != null && data.startsWith('data:')) {
      try {
        image = MemoryImage(
          base64Decode(data.substring(data.indexOf(',') + 1)),
        );
      } on FormatException {
        image = null; // A damaged photo shows the paw icon instead.
      }
    }
    return Material(
      color: context.appColors.surface,
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
                  ? context.appColors.accent
                  : context.appColors.primary.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: context.appColors.primaryMuted,
                backgroundImage: image,
                child: image == null
                    ? Icon(Icons.pets, color: context.appColors.textPrimary)
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
        side: BorderSide(
          color: context.appColors.primary.withValues(alpha: 0.7),
        ),
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
    color: context.appColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.pets, color: context.appColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('Add a pet to start keeping their care in one place.'),
          ),
          IconButton(
            tooltip: 'Add a pet',
            onPressed: onTap,
            icon: Icon(Icons.add_circle, color: context.appColors.primary),
          ),
        ],
      ),
    ),
  );
}

/// Inline notice that a pet refresh failed, with one retry action. Lives in
/// the dashboard's own scroll view, so it gets the screen's Material, safe
/// area and theme like every other row.
class _PetsRefreshBanner extends StatelessWidget {
  const _PetsRefreshBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: AppRadius.lgRadius,
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off_outlined, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Your pets could not be refreshed.',
            style: AppTypography.body.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
