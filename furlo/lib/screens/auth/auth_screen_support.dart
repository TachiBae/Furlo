import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_error_messages.dart';
import '../../utils/app_diagnostics.dart';

mixin AuthRequestState<T extends StatefulWidget> on State<T> {
  bool isBusy = false;
  String? message;

  Future<void> runAuthRequest(
    Future<void> Function() request, {
    bool suppressCancelled = false,
    Future<void> Function()? onUserNotFound,
  }) async {
    if (isBusy) return;
    setState(() {
      isBusy = true;
      message = null;
    });
    try {
      await request();
    } on AuthException catch (error) {
      if (!mounted) return;
      if (suppressCancelled && error.code == AuthErrorCode.cancelled) return;
      if (error.code == AuthErrorCode.userNotFound && onUserNotFound != null) {
        await onUserNotFound();
        return;
      }
      setState(() => message = authErrorMessage(error.code));
    } catch (_) {
      logAppDiagnostic('Authentication request failed.');
      if (mounted) {
        setState(() => message = authErrorMessage(AuthErrorCode.unknown));
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }
}

Widget authScreenScaffold({
  required BuildContext context,
  required String title,
  required Widget form,
  String? message,
  bool busy = false,
  Widget? leading,
}) => Scaffold(
  appBar: AppBar(leading: leading, title: const Text('Furlo')),
  body: SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title == 'Sign in' ? 'Welcome to Furlo' : title,
                style: AppTypography.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              if (message != null) ...[
                Text(
                  message,
                  style: TextStyle(color: context.appColors.danger),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              form,
              if (busy) ...[
                const SizedBox(height: AppSpacing.sm),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);

Widget googleSignInButton({
  required bool busy,
  required VoidCallback onPressed,
}) => OutlinedButton.icon(
  onPressed: busy ? null : onPressed,
  icon: const Icon(Icons.g_mobiledata),
  label: const Text('Continue with Google'),
);
