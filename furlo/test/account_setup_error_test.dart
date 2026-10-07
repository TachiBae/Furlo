import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/app.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_service.dart';

/// Account setup status that fails the way a missing database or unpublished
/// rules would: a [FirebaseException] carrying a platform error code.
class _FailingOnboardingRepository implements AccountOnboardingRepository {
  _FailingOnboardingRepository(this._error);

  final Object _error;

  @override
  Future<bool> requiresFirstPet(String uid) async => throw _error;

  @override
  Future<void> markFirstPetRequired(String uid) async {}

  @override
  Future<void> markFirstPetComplete(String uid) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpFailure(WidgetTester tester, Object error) async {
    final auth = FakeAuthService(
      initialUser: const AuthUser(
        uid: 'alice-uid',
        email: 'alice@example.com',
        displayName: null,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      FurloApp(
        authService: auth,
        accountOnboardingRepository: _FailingOnboardingRepository(error),
        repository: WebPetRepository(storageScope: 'alice-uid'),
        notificationService: const NoOpNotificationService(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'account setup failure shows the platform error code, not a bare message',
    (tester) async {
      await pumpFailure(
        tester,
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        find.text('Your account setup could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text('Support code: permission-denied'), findsOneWidget);
    },
  );

  testWidgets('a missing database is reported as its own code', (tester) async {
    await pumpFailure(
      tester,
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );

    expect(find.text('Support code: unavailable'), findsOneWidget);
    expect(find.text('Support code: permission-denied'), findsNothing);
  });

  testWidgets('an uncoded error falls back to the error type', (tester) async {
    await pumpFailure(tester, StateError('boom'));

    expect(find.textContaining('StateError'), findsOneWidget);
  });

  testWidgets('the retry button stays available after a failure', (
    tester,
  ) async {
    await pumpFailure(
      tester,
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );

    expect(find.text('Try again'), findsOneWidget);
  });
}
