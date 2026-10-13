import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Plain-language summary of what Furlo stores, where, and who can see it.
///
/// Keep this in step with the code: it is a promise to the person reading it.
/// (Firestore under users/{uid}, owner-only rules, base64 pet photos capped
/// at 600 KB, local notifications, no analytics or ads packages.)
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'What Furlo stores',
      'Your account email and the name you choose; your pets and everything '
          'you record for them: feeding schedules, vaccinations, health '
          'records, weight entries, vet contacts and appointments; and pet '
          'photos, shrunk to a small size.',
    ),
    (
      'Where it is kept',
      'In your Furlo account, using Google Firebase (Cloud Firestore and '
          'Firebase Authentication), so it follows you to every device you '
          'sign in on. This device also keeps a copy of your pet photos, '
          'your display name, theme and reminder settings so they load '
          'quickly.',
    ),
    (
      'Who can see it',
      'Only you, while signed in. The database rules let an account read '
          'and change only its own data. Reminders are scheduled on your '
          'phone itself and are not sent through a server.',
    ),
    (
      'What Furlo does not do',
      'No ads, no analytics or tracking, and your data is not sold or '
          'shared.',
    ),
    (
      'Deleting your data',
      'In Profile & Settings, "Delete all my data" removes every pet and '
          'record but keeps your account. "Delete account" removes the '
          'account and everything in it. Both apply on every device and '
          'cannot be undone.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const BackButton(), title: const Text('Privacy')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final (heading, body) in _sections) ...[
                Text(heading, style: AppTypography.h2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: AppTypography.body.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
