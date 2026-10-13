import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:furlo/utils/user_storage_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TapService extends NoOpNotificationService {
  _TapService();
  final controller = StreamController<NotificationTap>.broadcast();
  @override
  Stream<NotificationTap> get taps => controller.stream;
}

void main() {
  group('parseNotificationTap', () {
    final token = userStorageScopeToken('alice');

    test('reads a scoped feeding payload with its second-meal slot', () {
      final tap = parseNotificationTap(
        '$token|${NotificationTypes.dailyFeeding}|$token:f1:2',
        actionId: markFedActionId,
        storageScope: 'alice',
      )!;
      expect(tap.type, NotificationTypes.dailyFeeding);
      expect(tap.recordId, 'f1');
      expect(tap.isSecondMeal, isTrue);
      expect(tap.markFed, isTrue);
    });

    test('a weekly slot is not the second meal', () {
      final tap = parseNotificationTap(
        '$token|${NotificationTypes.dailyFeeding}|$token:f1:w3',
        storageScope: 'alice',
      )!;
      expect(tap.slot, 'w3');
      expect(tap.isSecondMeal, isFalse);
      expect(tap.markFed, isFalse);
    });

    test('appointment keys carry the vet and the pet', () {
      final tap = parseNotificationTap(
        '$token|${NotificationTypes.vetAppointment}|$token:v9:p2',
        storageScope: 'alice',
      )!;
      expect(tap.recordId, 'v9');
      expect(tap.petId, 'p2');
    });

    test('unscoped legacy payloads still parse', () {
      final tap = parseNotificationTap(
        '${NotificationTypes.upcomingVaccine}|7',
      )!;
      expect(tap.recordId, '7');
    });

    test("another account's or a broken payload is ignored", () {
      final other = userStorageScopeToken('bob');
      expect(
        parseNotificationTap(
          '$other|${NotificationTypes.dailyFeeding}|$other:f1',
          storageScope: 'alice',
        ),
        isNull,
      );
      expect(parseNotificationTap(null, storageScope: 'alice'), isNull);
      expect(
        parseNotificationTap(
          '$token|${NotificationTypes.dailyFeeding}|',
          storageScope: 'alice',
        ),
        isNull,
      );
    });
  });

  group('dashboard reacts to taps', () {
    Future<(WebPetRepository, _TapService)> pumpHome(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final repository = WebPetRepository();
      await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
      await repository.addPet(Pet(id: '2', name: 'Poppy', species: 'Cat'));
      await repository.addFeedingSchedule(
        FeedingEntry(id: 'f1', petId: '2', name: 'Wet food', time: '23:59'),
      );
      await repository.addVaccination(
        Vaccination(id: 'v1', petId: '2', vaccineName: 'FVRCP'),
      );
      await repository.addVet(Vet(id: 'vet1', name: 'Dr Kim', phone: '1'), [
        '2',
      ]);
      final state = FurloState(repository);
      await state.load();
      final service = _TapService();
      addTearDown(service.controller.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: ChangeNotifierProvider<ThemeSettings>(
            create: (_) => ThemeSettings(),
            child: MaterialApp(
              theme: AppTheme.dark,
              home: HomeScreen(
                repository: repository,
                notificationSettings:
                    SharedPreferencesNotificationSettingsRepository(),
                notificationService: service,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (repository, service);
    }

    testWidgets('a feeding tap opens Feeding with that pet selected', (
      tester,
    ) async {
      final (_, service) = await pumpHome(tester);
      service.controller.add(
        const NotificationTap(
          type: NotificationTypes.dailyFeeding,
          recordId: 'f1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feeding Schedule'), findsOneWidget);
      expect(find.text('Wet food'), findsOneWidget);
    });

    testWidgets('Mark fed feeds the meal and stays on the dashboard', (
      tester,
    ) async {
      final (repository, service) = await pumpHome(tester);
      service.controller.add(
        const NotificationTap(
          type: NotificationTypes.dailyFeeding,
          recordId: 'f1',
          markFed: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wet food marked fed.'), findsOneWidget);
      expect(find.text('Feeding Schedule'), findsNothing);
      expect(
        (await repository.getFeedingSchedules('2')).single.doneToday,
        isTrue,
      );
    });

    testWidgets('vaccine and appointment taps open their screens', (
      tester,
    ) async {
      final (_, service) = await pumpHome(tester);
      service.controller.add(
        const NotificationTap(
          type: NotificationTypes.upcomingVaccine,
          recordId: 'v1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vaccinations'), findsOneWidget);
      expect(find.text('FVRCP'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      service.controller.add(
        const NotificationTap(
          type: NotificationTypes.vetAppointment,
          recordId: 'vet1',
          petId: '2',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dr Kim'), findsWidgets);
    });

    testWidgets('a tap for a deleted record does nothing', (tester) async {
      final (_, service) = await pumpHome(tester);
      service.controller.add(
        const NotificationTap(
          type: NotificationTypes.dailyFeeding,
          recordId: 'gone',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Feeding Schedule'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
