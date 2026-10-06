import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/auth_validators.dart';
import 'auth_screen_support.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with AuthRequestState<CreateAccountScreen> {
  late final NavigatorState _navigator = Navigator.of(context);
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _completeNewAccount() async {
    await widget.authService.signOut();
    if (mounted) _navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _google() => runAuthRequest(() async {
    final result = await widget.authService.signInWithGoogle();
    if (result.isNewAccount) {
      await _completeNewAccount();
    } else if (mounted) {
      _navigator.popUntil((route) => route.isFirst);
    }
  }, suppressCancelled: true);

  Future<void> _submit() async {
    if (isBusy || !_formKey.currentState!.validate()) return;
    await runAuthRequest(() async {
      final result = await widget.authService.registerWithEmail(
        _email.text.trim(),
        _password.text,
      );
      if (result.isNewAccount) {
        await _completeNewAccount();
      } else if (mounted) {
        _navigator.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) => authScreenScaffold(
    context: context,
    title: 'Create account',
    message: message,
    busy: isBusy,
    form: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('auth-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('auth-password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('auth-confirm-password'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) =>
                validateConfirmPassword(value, _password.text),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('create-account-submit'),
            onPressed: isBusy ? null : _submit,
            child: const Text('Create account'),
          ),
          const SizedBox(height: 12),
          googleSignInButton(busy: isBusy, onPressed: _google),
        ],
      ),
    ),
  );
}
