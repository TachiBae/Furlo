import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FurloState> pumpHome(
    WidgetTester tester, {
    bool withReminder = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Fresh store per pump: the web repository persists in SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    final repository = WebPetRepository();
    await repository.addPet(Pet(name: 'Mochi', species: 'Dog'));
    final pets = await repository.getPets();
    final mochi = pets.single;
    if (withReminder) {
      await repository.addFeedingSchedule(
        FeedingEntry(
          petId: mochi.id!,
          name: 'Breakfast',
          time: '00:00',
          frequency: 'Daily',
        ),
      );
    }
    final state = FurloState(repository);
    await state.load();

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
              notificationService: const NoOpNotificationService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('alerts badge is hidden without reminders and counts them when present', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    final state = await pumpHome(tester);
    expect(find.bySemanticsLabel('Alerts'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Alerts, \\d+ reminders')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    final stateWithReminder = await pumpHome(tester, withReminder: true);
    expect(find.bySemanticsLabel('Alerts, 1 reminders'), findsOneWidget);
    expect(find.bySemanticsLabel('Alerts'), findsNothing);
    handle.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
    stateWithReminder.dispose();
  });

  testWidgets('tapped nav destination highlights while open and Home reactivates on return', (
    tester,
  ) async {
    final state = await pumpHome(tester);

    // Labels render only for the selected destination, so 'Settings' is
    // absent while Home is active.
    expect(find.text('Settings'), findsNothing);

    // The header settings icon shares the 'Settings' tooltip; the nav item
    // is the last one in the tree.
    await tester.tap(find.byTooltip('Settings').last);
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Profile & Settings'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Profile & Settings'), findsNothing);
    expect(find.text('Settings'), findsNothing); // Home is active again
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
