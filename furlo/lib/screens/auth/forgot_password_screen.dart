import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/auth_validators.dart';
import 'auth_screen_support.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with AuthRequestState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isBusy || !_formKey.currentState!.validate()) return;
    await runAuthRequest(
      () async {
        await widget.authService.sendPasswordReset(_email.text.trim());
        if (mounted) {
          setState(() {
            message =
                'If an account exists for that email, a reset link has been sent.';
            messageIsSuccess = true;
          });
        }
      },
      onUserNotFound: () async {
        if (mounted) {
          setState(() {
            message =
                'If an account exists for that email, a reset link has been sent.';
            messageIsSuccess = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => authScreenScaffold(
    context: context,
    title: 'Forgot password',
    message: message,
    messageIsSuccess: messageIsSuccess,
    busy: isBusy,
    leading: BackButton(
      onPressed: isBusy ? null : () => Navigator.of(context).pop(),
    ),
    form: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('reset-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('send-reset-link'),
            onPressed: isBusy ? null : _submit,
            child: const Text('Send reset link'),
          ),
        ],
      ),
    ),
  );
}
