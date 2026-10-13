import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/settings/profile_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingClearRepository extends WebPetRepository {
  @override
  Future<void> clearAllData() async => throw StateError('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FurloState> pumpProfile(
    WidgetTester tester,
    WebPetRepository repository,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await repository.addPet(Pet(id: '1', name: 'Mochi', species: 'Dog'));
    await repository.addFeedingSchedule(
      FeedingEntry(petId: '1', name: 'Breakfast', time: '08:00'),
    );
    final state = FurloState(repository);
    await state.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ThemeSettings()),
          ChangeNotifierProvider<FurloState>.value(value: state),
        ],
        child: MaterialApp(
          home: ProfileScreen(
            repository: repository,
            appSettings: SharedPreferencesAppSettingsRepository(),
            notificationSettings:
                SharedPreferencesNotificationSettingsRepository(),
            notificationService: const NoOpNotificationService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> openAndAnswer(WidgetTester tester, String answer) async {
    await tester.ensureVisible(find.text('Delete all my data'));
    await tester.tap(find.text('Delete all my data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all your pet data?'), findsOneWidget);
    await tester.tap(find.text(answer));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Cancel keeps everything', (tester) async {
    final repository = WebPetRepository();
    final state = await pumpProfile(tester, repository);
    await openAndAnswer(tester, 'Cancel');
    expect(await repository.getPets(), hasLength(1));
    expect(state.pets, hasLength(1));
  });

  testWidgets('confirming deletes every pet and record', (tester) async {
    final repository = WebPetRepository();
    final state = await pumpProfile(tester, repository);
    await openAndAnswer(tester, 'Delete everything');

    expect(find.text('All your pet data was deleted.'), findsOneWidget);
    expect(await repository.getPets(), isEmpty);
    expect(await repository.getAllFeedingSchedules(), isEmpty);
    expect(state.pets, isEmpty);
  });

  testWidgets('a failed delete says so and keeps the data', (tester) async {
    final repository = _FailingClearRepository();
    final state = await pumpProfile(tester, repository);
    await openAndAnswer(tester, 'Delete everything');

    expect(
      find.text('Your data could not be deleted. Please try again.'),
      findsOneWidget,
    );
    expect(state.pets, hasLength(1));
  });

  test('clearing the cloud also clears photos cached on the device', () async {
    final repository = FirestorePetRepository(
      uid: 'alice',
      firestore: FakeFirebaseFirestore(),
    );
    const photo = 'data:image/png;base64,AAAA';
    await repository.addPet(
      Pet(id: 'p1', name: 'Mochi', species: 'Cat', photoPath: photo),
    );
    final store = LocalPetPhotoStore(storageScope: 'alice');
    expect(await store.read('p1'), photo);

    await repository.clearAllData();

    expect(await store.read('p1'), isNull);
  });
}
