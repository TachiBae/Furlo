import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/auth_validators.dart';
import 'auth_screen_support.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with AuthRequestState<SignInScreen> {
  late final NavigatorState _navigator = Navigator.of(context);
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isBusy || !_formKey.currentState!.validate()) return;
    await runAuthRequest(() async {
      await widget.authService.signInWithEmail(
        _email.text.trim(),
        _password.text,
      );
      if (mounted) _navigator.popUntil((route) => route.isFirst);
    });
  }

  Future<void> _google() => runAuthRequest(() async {
    final result = await widget.authService.signInWithGoogle();
    if (result.isNewAccount) {
      await widget.authService.signOut();
      return;
    }
    if (mounted) _navigator.popUntil((route) => route.isFirst);
  }, suppressCancelled: true);

  @override
  Widget build(BuildContext context) => authScreenScaffold(
    context: context,
    title: 'Sign in',
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
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            validator: validateSignInPassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isBusy
                  ? null
                  : () => _navigator.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ForgotPasswordScreen(
                          authService: widget.authService,
                        ),
                      ),
                    ),
              child: const Text('Forgot password'),
            ),
          ),
          FilledButton(
            key: const Key('sign-in-submit'),
            onPressed: isBusy ? null : _submit,
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          googleSignInButton(busy: isBusy, onPressed: _google),
          TextButton(
            onPressed: isBusy
                ? null
                : () => _navigator.push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CreateAccountScreen(authService: widget.authService),
                    ),
                  ),
            child: const Text('Create account'),
          ),
        ],
      ),
    ),
  );
}
