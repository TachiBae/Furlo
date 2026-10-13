import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/auth/sign_in_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_service.dart';

/// Forms cohesion guards.
///
/// Two kinds of check: a source scan that keeps every field inside the shared
/// input table, and a run of the paths where a form must not lose the user's
/// work. The forms here are checked because they are the ones a user fills in
/// by hand; a search box is not one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('input table', () {
    /// Screens with hand-filled forms, and the one deliberate exception:
    /// [textInputAction] on every text field so the keyboard can walk the form
    /// instead of dismissing on each field.
    late final Map<String, String> formSources = {
      for (final name in const [
        'lib/screens/auth/sign_in_screen.dart',
        'lib/screens/auth/create_account_screen.dart',
        'lib/screens/auth/complete_profile_screen.dart',
        'lib/screens/auth/forgot_password_screen.dart',
        'lib/screens/settings/profile_screen.dart',
        'lib/screens/pets/pet_form_screen.dart',
        'lib/screens/vets/vet_contacts_screen.dart',
        'lib/screens/feeding/feeding_screen.dart',
        'lib/screens/health/health_records_screen.dart',
        'lib/screens/vaccinations/vaccination_screen.dart',
        'lib/screens/weight/weight_tracking_screen.dart',
      ])
        name: File(name).readAsStringSync(),
    };

    test('no raw maxLength literal survives in a form', () {
      final offenders = <String>[];
      final literal = RegExp(r'maxLength:\s*([0-9]+)');
      for (final entry in formSources.entries) {
        for (final match in literal.allMatches(entry.value)) {
          offenders.add('${entry.key}: maxLength: ${match.group(1)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a field limit belongs in AppFieldLimits so the field and its '
            'validator message cannot drift apart:\n${offenders.join('\n')}',
      );
    });

    test('every maxLength is one of the stated limits', () {
      final stated = <String>{
        'shortName',
        'title',
        'address',
        'notes',
        'phone',
      };
      final used = <String>{};
      final named = RegExp(r'maxLength:\s*AppFieldLimits\.(\w+)');
      for (final source in formSources.values) {
        for (final match in named.allMatches(source)) {
          used.add(match.group(1)!);
        }
      }
      expect(
        used.difference(stated),
        isEmpty,
        reason: 'a form names a limit that AppFieldLimits does not define',
      );
      expect(
        used,
        isNotEmpty,
        reason: 'no form used a shared limit, so the scan proved nothing',
      );
    });

    test('every field states what its enter key does', () {
      final offenders = <String>[];
      for (final entry in formSources.entries) {
        for (final body in _fieldBodies(entry.value)) {
          if (!body.contains('textInputAction:')) {
            offenders.add('${entry.key}: ${_fieldSummary(body)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a field with no textInputAction dismisses the keyboard mid-form '
            'and leaves the user to tap the submit button:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the vet field helper hands on the enter key it is given', () {
      // The vet form builds its fields through one helper, so the scan above
      // reads the helper definition rather than the call sites.
      final source = formSources['lib/screens/vets/vet_contacts_screen.dart']!;
      expect(
        source,
        contains('textInputAction: lines > 1'),
        reason: 'the helper decides the enter key from the line count',
      );
    });

    test('the longer text fields keep Enter for a newline', () {
      final offenders = <String>[];
      final multiline = RegExp(r'maxLines:\s*([2-9]|\d\d+)');
      for (final entry in formSources.entries) {
        for (final body in _fieldBodies(entry.value)) {
          if (!multiline.hasMatch(body)) continue;
          if (!body.contains('TextInputAction.newline')) {
            offenders.add('${entry.key}: ${_fieldSummary(body)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a field that shows several lines must not claim the enter key:'
            '\n${offenders.join('\n')}',
      );
    });
  });

  group('a failed save keeps what the user typed', () {
    testWidgets('the vet form stays open with its input and a live Save', (
      tester,
    ) async {
      // The form is a scrolling list, so the Save button sits below the
      // default 800x600 test viewport.
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final repository = _FailingVetSaveRepository();
      await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
      final state = FurloState(repository);
      await state.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.defaultTheme,
            home: VetFormScreen(
              repository: repository,
              notificationService: const NoOpNotificationService(),
              linkedPetIds: const ['1'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Order is Name, Clinic, Phone.
      await tester.enterText(find.byType(TextFormField).at(0), 'Dr. Lee');
      await tester.enterText(find.byType(TextFormField).at(2), '555-0100');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Dr. Lee'),
        findsOneWidget,
        reason: 'a failed save must not throw away the typed vet',
      );
      expect(
        find.text('555-0100'),
        findsOneWidget,
        reason: 'a failed save must not throw away the typed phone number',
      );
      expect(
        find.text('The vet could not be saved. Please try again.'),
        findsOneWidget,
        reason: 'a failed save must say so instead of throwing silently',
      );
      expect(
        find.text('Save'),
        findsOneWidget,
        reason:
            'the Save button must be usable again; leaving it on "Saving…" '
            'makes retrying impossible',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the keyboard submits the form it belongs to', () {
    testWidgets('the sign-in "done" key signs in', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.defaultTheme,
          home: SignInScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'person@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'hunter2secret',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        auth.calls,
        contains('signInWithEmail'),
        reason: 'the done key on the last field should submit the form',
      );
    });
  });
}

/// The argument list of every text field in [source], so a check can look at
/// one field at a time instead of guessing at a character window. Quoted
/// strings are blanked first: their content (hints like `'e.g. Mochi'`) can
/// contain brackets or the words being searched for.
Iterable<String> _fieldBodies(String source) sync* {
  final code = source
      .replaceAll(RegExp(r"'[^'\n]*'"), "''")
      .replaceAll(RegExp('"[^"\n]*"'), '""');
  for (final opener in RegExp(
    r'(TextFormField|TextField)\(',
  ).allMatches(code)) {
    var depth = 1;
    var index = opener.end;
    while (index < code.length && depth > 0) {
      final char = code[index];
      if (char == '(') depth++;
      if (char == ')') depth--;
      index++;
    }
    yield code.substring(opener.end, index);
  }
}

/// A couple of identifying words from a field body, for failure output.
String _fieldSummary(String body) {
  final words = body
      .split(RegExp(r'[\s,]+'))
      .where((word) => word.isNotEmpty)
      .take(6)
      .join(' ');
  return words;
}

/// Fails only the write under test, so the form's error path is real while the
/// rest of the repository behaves.
class _FailingVetSaveRepository extends WebPetRepository {
  @override
  Future<Vet> addVet(Vet vet, List<String> petIds) async {
    throw StateError('offline');
  }
}
