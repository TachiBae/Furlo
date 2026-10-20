part of '../home_screen.dart';

// The dashboard bottom navigation bar.

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.activeTab,
    required this.reminderCount,
    required this.onTap,
    required this.onAddPet,
  });

  final int activeTab;
  final int reminderCount;
  final ValueChanged<int> onTap;
  final VoidCallback onAddPet;

  @override
  Widget build(BuildContext context) {
    // The nav label is set in AppTypography.label, so it grows with the user's
    // text scale. A bar pinned at 68 clips that label at 2.0, so the bar grows
    // by exactly the same amount the label does.
    final labelGrowth =
        MediaQuery.textScalerOf(context).scale(AppTypography.label.fontSize!) -
        AppTypography.label.fontSize!;
    return BottomAppBar(
      color: context.appColors.surface,
      elevation: 8,
      height: 68 + labelGrowth,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.appColors.textDisabled,
                width: 0.35,
              ),
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
                  badgeCount: reminderCount,
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
}

class _AddPetNavItem extends StatelessWidget {
  const _AddPetNavItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add pet',
    child: Tooltip(
      message: 'Add pet',
      child: Center(
        child: Material(
          color: context.appColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.add,
                size: 27,
                color: context.appColors.textOnPrimary,
              ),
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
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? context.appColors.textPrimary
        : context.appColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount reminders' : label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          containedInkWell: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
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
                        ? context.appColors.primary.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: AppRadius.pillRadius,
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
                      if (badgeCount > 0)
                        Positioned(
                          top: 1,
                          right: 5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.appColors.primaryMuted,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.appColors.surface,
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
                          style: AppTypography.label.copyWith(
                            color: context.appColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
