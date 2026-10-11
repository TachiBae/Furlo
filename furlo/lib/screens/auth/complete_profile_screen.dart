import 'package:flutter/material.dart';

import '../../repositories/app_settings_repository.dart';
import '../../services/account_onboarding_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_error_messages.dart';
import '../../utils/auth_validators.dart';
import 'auth_screen_support.dart';

/// Final step for a brand-new Google account.
///
/// The account gets a full name, a display name and a password, so it can be
/// opened by email later as well. Submitting links the password first, then
/// updates the account name, then saves the app display name, and writes the
/// profile document with the completion marker last.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.authService,
    required this.profileRepository,
    required this.appSettings,
    required this.uid,
    required this.onCompleted,
  });

  final AuthService authService;
  final AccountProfileRepository profileRepository;
  final AppSettingsRepository appSettings;
  final String uid;
  final Future<void> Function() onCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with AuthRequestState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signingOut = false;

  @override
  void dispose() {
    _fullName.dispose();
    _displayName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isBusy || !_formKey.currentState!.validate()) return;
    final fullName = _fullName.text.trim();
    final displayName = _displayName.text.trim();
    await runAuthRequest(() async {
      await widget.authService.linkPassword(_password.text);
      await widget.authService.updateFullName(fullName);
      await widget.appSettings.setDisplayName(displayName);
      await widget.profileRepository.completeProfile(
        widget.uid,
        fullName: fullName,
        displayName: displayName,
      );
      await widget.onCompleted();
    });
  }

  Future<void> _signOut() async {
    if (_signingOut || isBusy) return;
    setState(() => _signingOut = true);
    try {
      await widget.authService.signOut();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          message = authErrorMessage(error.code);
          messageIsSuccess = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Sign-out failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          message = authErrorMessage(AuthErrorCode.unknown);
          messageIsSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => authScreenScaffold(
    context: context,
    title: 'Complete your profile',
    message: message,
    busy: isBusy || _signingOut,
    form: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('profile-full-name'),
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: validateDisplayName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-display-name'),
            controller: _displayName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: validateDisplayName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-confirm-password'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) =>
                validateConfirmPassword(value, _password.text),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('complete-profile-submit'),
            onPressed: isBusy || _signingOut ? null : _submit,
            child: const Text('Save and continue'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('complete-profile-sign-out'),
            onPressed: isBusy || _signingOut ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}
