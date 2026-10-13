import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/settings/notifications_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingVetRepository extends WebPetRepository {
  bool failAppointments = false;
  bool failDelete = false;
  bool failLoad = false;

  @override
  Future<Vet?> getVetById(String id) async {
    if (failLoad) throw StateError('offline');
    return super.getVetById(id);
  }

  @override
  Future<void> setNextAppointment(
    String vetId,
    String petId,
    DateTime? date,
  ) async {
    if (failAppointments) throw StateError('offline');
    return super.setNextAppointment(vetId, petId, date);
  }

  @override
  Future<void> deleteVet(String id) async {
    if (failDelete) throw StateError('offline');
    return super.deleteVet(id);
  }
}

class _FailingSettings extends SharedPreferencesNotificationSettingsRepository {
  int loadFailures = 0;
  bool failWrites = false;

  @override
  Future<Map<String, bool>> getAll() async {
    if (loadFailures > 0) {
      loadFailures--;
      throw StateError('storage unavailable');
    }
    return super.getAll();
  }

  @override
  Future<void> setEnabled(String type, bool enabled) async {
    if (failWrites) throw StateError('storage full');
    return super.setEnabled(type, enabled);
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.forChoice(AppThemeChoice.defaultTheme),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(_FailingVetRepository, Vet)> seedVet() async {
    final repository = _FailingVetRepository();
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Cat'));
    final vet = await repository.addVet(Vet(name: 'Dr Kim', phone: '5551'), [
      '1',
    ]);
    return (repository, vet);
  }

  group('vet details', () {
    testWidgets('a failed appointment save says so', (tester) async {
      final (repository, vet) = await seedVet();
      await tester.pumpWidget(
        _app(VetDetailsScreen(repository: repository, vet: vet)),
      );
      await tester.pumpAndSettle();
      repository.failAppointments = true;

      await tester.tap(find.text('Set date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('The appointment could not be saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed delete says so and stays on the vet', (tester) async {
      final (repository, vet) = await seedVet();
      await tester.pumpWidget(
        _app(VetDetailsScreen(repository: repository, vet: vet)),
      );
      await tester.pumpAndSettle();
      repository.failDelete = true;

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('The vet could not be deleted.'), findsOneWidget);
      expect(find.text('Vet Details'), findsOneWidget);
      expect(await repository.getAllVets(), hasLength(1));
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final (repository, vet) = await seedVet();
      repository.failLoad = true;
      await tester.pumpWidget(
        _app(VetDetailsScreen(repository: repository, vet: vet)),
      );
      await tester.pumpAndSettle();
      expect(find.text('This vet could not be loaded.'), findsOneWidget);

      repository.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Dr Kim'), findsWidgets);
    });
  });

  group('notification settings', () {
    testWidgets('a failed load shows an error with retry', (tester) async {
      final settings = _FailingSettings()..loadFailures = 1;
      await tester.pumpWidget(
        _app(
          NotificationSettingsScreen(
            settings: settings,
            service: const NoOpNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Notification settings could not be loaded.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Daily feeding'), findsOneWidget);
    });

    testWidgets('a toggle that cannot be saved says so', (tester) async {
      final settings = _FailingSettings();
      await tester.pumpWidget(
        _app(
          NotificationSettingsScreen(
            settings: settings,
            service: const NoOpNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      settings.failWrites = true;

      await tester.tap(find.text('Daily feeding'));
      await tester.pumpAndSettle();

      expect(find.text('That setting could not be saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
