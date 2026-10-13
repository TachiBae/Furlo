import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/furlo_state.dart';
import '../../repositories/app_settings_repository.dart';
import '../../repositories/notification_settings_repository.dart';
import '../../repositories/pet_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notifications_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_error_messages.dart';
import '../../utils/app_diagnostics.dart';
import '../../utils/form_input.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

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
    this.storageScope,
    this.onDeleteAccount,
  });

  final PetRepository repository;
  final AppSettingsRepository appSettings;
  final NotificationSettingsRepository notificationSettings;
  final NotificationService notificationService;
  final String? storageScope;

  /// Deletes the signed-in account (re-authenticating with the password
  /// when one is given). Null hides the option.
  final Future<void> Function(String? password)? onDeleteAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  bool _loading = true;
  bool _signingOut = false;
  bool _deleting = false;
  bool _deletingAccount = false;

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

  /// Deletes every pet and record in the account after an explicit
  /// confirmation. The account itself, and its settings, stay.
  Future<void> _deleteAllData() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: const Text('Delete all your pet data?'),
        content: const Text(
          'This permanently deletes every pet, feeding schedule, vaccination, '
          'health record, weight entry and vet contact in your account, on '
          'every device. Your account stays. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final furloState = context.read<FurloState?>();
    setState(() => _deleting = true);
    try {
      await widget.repository.clearAllData();
      // Nothing is left to remind about; this also clears pending ones.
      await widget.notificationService.rescheduleAll();
      await furloState?.load();
      if (mounted) _showMessage('All your pet data was deleted.');
    } catch (_) {
      logAppDiagnostic('Delete all data failed.');
      // A partial delete is safe to retry: it only removes what is left.
      if (mounted) {
        _showMessage('Your data could not be deleted. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteAccount(AuthService authService) async {
    final onDelete = widget.onDeleteAccount;
    if (onDelete == null || _deletingAccount) return;
    final usesPassword = authService.signsInWithPassword;
    // The dialog owns its text field; it returns the typed password ('' for
    // a Google account) or null when cancelled.
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(usesPassword: usesPassword),
    );
    if (typed == null || !mounted) return;
    if (usesPassword && typed.isEmpty) {
      _showMessage('Enter your password to delete your account.');
      return;
    }
    setState(() => _deletingAccount = true);
    try {
      await onDelete(usesPassword ? typed : null);
      // Signed out now: return to the root, where sign-in is showing.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (mounted) _showMessage(authErrorMessage(error.code));
    } catch (_) {
      logAppDiagnostic('Account deletion failed.');
      if (mounted) {
        _showMessage('Your account could not be deleted. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _signOut(AuthService authService) async {
    if (_signingOut) return;
    // The dialog barrier blocks re-entry while the choice is open, so the
    // busy flag only needs to cover the sign-out itself, keeping the tile
    // spinner limited to work that actually runs.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use Furlo on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await authService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (mounted) _showMessage(authErrorMessage(error.code));
    } catch (_) {
      logAppDiagnostic('Sign-out failed.');
      if (mounted) _showMessage(authErrorMessage(AuthErrorCode.unknown));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
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
              if (Provider.of<AuthService?>(context, listen: false)
                  case final authService?) ...[
                ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(
                    authService.currentUser?.email ?? 'Not available',
                  ),
                ),
                ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  trailing: _signingOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _signingOut ? null : () => _signOut(authService),
                ),
              ],
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
                    color: context.appColors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loading ? null : _editDisplayName,
              ),
              const SizedBox(height: AppSpacing.md),
              _GroupHeading('Preferences'),
              _ThemePreferenceRow(onSaveError: _showMessage),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                subtitle: const Text('Reminder preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationSettingsScreen(
                      settings: widget.notificationSettings,
                      service: widget.notificationService,
                      storageScope: widget.storageScope,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _GroupHeading('Data'),
              ListTile(
                minTileHeight: 56,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: context.appColors.danger,
                ),
                title: Text(
                  'Delete all my data',
                  style: TextStyle(color: context.appColors.danger),
                ),
                subtitle: const Text('Every pet and record in your account'),
                trailing: _deleting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _deleting ? null : _deleteAllData,
              ),
              if (widget.onDeleteAccount != null)
                if (Provider.of<AuthService?>(context, listen: false)
                    case final authService?)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(
                      Icons.person_remove_outlined,
                      color: context.appColors.danger,
                    ),
                    title: Text(
                      'Delete account',
                      style: TextStyle(color: context.appColors.danger),
                    ),
                    subtitle: const Text('Your account and all its data'),
                    trailing: _deletingAccount
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _deletingAccount
                        ? null
                        : () => _deleteAccount(authService),
                  ),
              const SizedBox(height: AppSpacing.md),
              _GroupHeading('About'),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                subtitle: const Text('What is stored and who can see it'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyScreen(),
                  ),
                ),
              ),
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

class _ThemePreferenceRow extends StatelessWidget {
  const _ThemePreferenceRow({required this.onSaveError});

  final ValueChanged<String> onSaveError;

  String _label(AppThemeChoice choice) => switch (choice) {
    AppThemeChoice.defaultTheme => 'Default',
    AppThemeChoice.light => 'Light',
    AppThemeChoice.dark => 'Dark',
  };

  @override
  Widget build(BuildContext context) => Consumer<ThemeSettings>(
    builder: (context, settings, _) => ListTile(
      minTileHeight: 56,
      leading: const Icon(Icons.contrast_outlined),
      title: const Text('Theme'),
      subtitle: Text(
        !settings.persistenceFailed
            ? _label(settings.choice)
            : 'Preference could not be restored; using Default',
      ),
      trailing: DropdownButton<AppThemeChoice>(
        value: settings.choice,
        underline: const SizedBox.shrink(),
        items: AppThemeChoice.values
            .map(
              (mode) =>
                  DropdownMenuItem(value: mode, child: Text(_label(mode))),
            )
            .toList(),
        onChanged: (mode) async {
          if (mode == null) return;
          try {
            await settings.setThemeMode(mode);
          } catch (_) {
            if (!context.mounted) return;
            onSaveError('Could not save your theme preference.');
          }
        },
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
        maxLength: AppFieldLimits.shortName,
        textInputAction: TextInputAction.done,
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
      style: AppTypography.label.copyWith(color: context.appColors.primary),
    ),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.usesPassword});

  final bool usesPassword;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(context, _password.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.appColors.surface,
    title: const Text('Delete your account?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This permanently deletes your Furlo account and every pet and '
          'record in it, on every device. This cannot be undone.',
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.usesPassword)
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Confirm it is you',
            ),
            onSubmitted: (_) => _confirm(),
          )
        else
          Text(
            'You will confirm with Google first.',
            style: AppTypography.body.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: context.appColors.danger),
        onPressed: _confirm,
        child: const Text('Delete account'),
      ),
    ],
  );
}
