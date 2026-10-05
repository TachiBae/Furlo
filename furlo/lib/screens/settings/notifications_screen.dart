import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_settings_provider.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.settings,
    required this.service,
  });
  final NotificationSettingsRepository settings;
  final NotificationService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Notification settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NotificationSettingsScreen(
                settings: settings,
                service: service,
              ),
            ),
          ),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: context.appColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('No notifications yet', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reminders will appear in your device notification center. Use the gear to choose which reminders Furlo sends.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.settings,
    required this.service,
  });

  final NotificationSettingsRepository settings;
  final NotificationService service;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        NotificationSettingsProvider(repository: settings, service: service),
    child: const _NotificationsView(),
  );
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();
  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationSettingsProvider>().refreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Text('Notification settings'),
    ),
    body: Consumer<NotificationSettingsProvider>(
      builder: (context, state, _) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (state.isWeb) ...[
              _InfoBanner(
                icon: Icons.info_outline,
                message: 'Reminders only fire on the mobile app',
                muted: true,
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (state.permissionGranted == false) ...[
              _PermissionBanner(onOpenSettings: state.openSettings),
              const SizedBox(height: AppSpacing.md),
            ],
            _group('Feeding', [
              _NotificationOption(
                NotificationTypes.dailyFeeding,
                'Daily feeding',
                'A reminder at each saved feeding time.',
              ),
              _NotificationOption(
                NotificationTypes.missedMeal,
                'Missed meal',
                'A reminder 60 minutes after a meal is missed.',
              ),
            ], state),
            _group('Vaccines', [
              _NotificationOption(
                NotificationTypes.upcomingVaccine,
                'Upcoming vaccine',
                'A reminder three days before a vaccine is due.',
              ),
              _NotificationOption(
                NotificationTypes.overdueVaccine,
                'Overdue vaccine',
                'A reminder the morning after a vaccine is due.',
              ),
            ], state),
            _group('Appointments', [
              _NotificationOption(
                NotificationTypes.vetAppointment,
                'Vet appointment',
                'A reminder one day before an appointment.',
              ),
            ], state),
            _group('Medication', [
              _NotificationOption(
                NotificationTypes.medication,
                'Medication',
                'Reminders for active medication schedules.',
              ),
            ], state),
          ],
        );
      },
    ),
  );

  Widget _group(
    String title,
    List<_NotificationOption> options,
    NotificationSettingsProvider state,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(title, style: AppTypography.h2),
        ),
        Card(
          color: context.appColors.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          child: Column(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  title: Text(
                    options[index].title,
                    style: AppTypography.bodyStrong,
                  ),
                  subtitle: Text(
                    options[index].description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  value: state.isEnabled(options[index].type),
                  onChanged: state.busy
                      ? null
                      : (value) => state.toggle(options[index].type, value),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _NotificationOption {
  const _NotificationOption(this.type, this.title, this.description);
  final String type;
  final String title;
  final String description;
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onOpenSettings});
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) => _InfoBanner(
    icon: Icons.notifications_off_outlined,
    message:
        'Notifications are disabled in system settings. Furlo reminders cannot appear until permission is enabled.',
    action: TextButton(
      onPressed: onOpenSettings,
      child: const Text('Open settings'),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    this.action,
    this.muted = false,
  });
  final IconData icon;
  final String message;
  final Widget? action;
  final bool muted;
  @override
  Widget build(BuildContext context) => Card(
    color: context.appColors.surface,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: muted
                ? context.appColors.textSecondary
                : context.appColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                if (action != null)
                  Align(alignment: Alignment.centerLeft, child: action!),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
