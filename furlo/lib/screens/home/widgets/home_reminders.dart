part of '../home_screen.dart';

// The Today's Reminders section and its rows.

class _ReminderEmptyCard extends StatelessWidget {
  const _ReminderEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: AppRadius.lgRadius,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.appColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: context.appColors.accent),
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
    required this.onMarkFed,
    required this.onMore,
  });

  final HomeRemindersProvider provider;
  final ValueChanged<HomeReminder> onTap;
  final ValueChanged<HomeReminder> onMarkFed;
  final ValueChanged<List<HomeReminder>> onMore;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: provider,
    child: Consumer<HomeRemindersProvider>(
      builder: (context, state, _) {
        if (state.loading && state.reminders.isEmpty) {
          return const RecordListSkeleton(count: 2, padding: EdgeInsets.zero);
        }
        if (state.hasError && state.reminders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: AppRadius.lgRadius,
            ),
            child: Text(
              'Your reminders could not be loaded. Try again later.',
              style: AppTypography.body.copyWith(
                color: context.appColors.textSecondary,
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
                  onMarkFed: () => onMarkFed(reminder),
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
  const _ReminderTile({
    required this.reminder,
    required this.onTap,
    required this.onMarkFed,
  });
  final HomeReminder reminder;
  final VoidCallback onTap;

  /// Shown only on feeding reminders: feeds the meal without leaving home.
  final VoidCallback onMarkFed;

  @override
  Widget build(BuildContext context) {
    final urgencyColor = switch (reminder.urgency) {
      ReminderUrgency.overdue => context.appColors.danger,
      ReminderUrgency.today => context.appColors.primary,
      ReminderUrgency.upcoming => context.appColors.textSecondary,
    };
    // Same clock format as the Feeding screen (and the device's 24-hour
    // setting), not the stored HH:mm.
    final time = reminder.time;
    final trailing = time == null
        ? _dateLabel(reminder.date)
        : _clock(time).format(context);
    return Material(
      color: context.appColors.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
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
                          color: context.appColors.textSecondary,
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
                        color: context.appColors.textPrimary,
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
                if (reminder.type == ReminderType.feeding &&
                    reminder.recordId != null)
                  IconButton(
                    tooltip: 'Mark ${reminder.title} fed',
                    onPressed: onMarkFed,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: context.appColors.accent,
                    ),
                  )
                else ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    color: context.appColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TimeOfDay _clock(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
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
    // Same month-name style as dates elsewhere in the app ('Oct 5').
    return formatMonthDay(date);
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
