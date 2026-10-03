import 'package:flutter/material.dart';

import '../../repositories/app_settings_repository.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../repositories/pet_repository.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import 'notifications_screen.dart';

const _buildName = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: '1.0.0',
);
const _buildNumber = String.fromEnvironment(
  'FLUTTER_BUILD_NUMBER',
  defaultValue: '1',
);
// Defaults mirror the version string in pubspec.yaml; build-time overrides are
// supported for release pipelines that provide Flutter build metadata.
const appVersion = '$_buildName+$_buildNumber';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.appSettings,
    required this.notificationSettings,
    required this.notificationService,
  });

  final PetRepository repository;
  final AppSettingsRepository appSettings;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final name = await widget.appSettings.getDisplayName();
      if (!mounted) return;
      setState(() {
        _displayName = name;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDisplayName() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _DisplayNameDialog(initialName: _displayName),
    );
    if (value == null || !mounted) return;
    try {
      await widget.appSettings.setDisplayName(value);
      if (mounted) setState(() => _displayName = value);
    } catch (_) {
      if (mounted) _showMessage('Could not save your display name.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Text('Profile & Settings'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _GroupHeading('Account'),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.person_outline),
                title: const Text('Display name'),
                subtitle: Text(
                  _loading
                      ? 'Loading…'
                      : _displayName.isEmpty
                      ? 'Not set'
                      : _displayName,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loading ? null : _editDisplayName,
              ),
              const SizedBox(height: AppSpacing.md),
              _GroupHeading('Preferences'),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                subtitle: const Text('Reminder preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationsScreen(
                      settings: widget.notificationSettings,
                      service: widget.notificationService,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _GroupHeading('About'),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                subtitle: Text(appVersion),
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.pets_outlined),
                title: const Text('Furlo: Pet Health & Care Tracker'),
                subtitle: const Text('Made for everyday pet care'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initialName});
  final String initialName;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Display name'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Your name'),
        validator: validateDisplayName,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _controller.text.trim());
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.sm),
    child: Text(
      title,
      style: AppTypography.label.copyWith(color: AppColors.primary),
    ),
  );
}
