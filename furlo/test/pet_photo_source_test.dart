import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/pets/pet_onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpForm(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = WebPetRepository();
  final state = FurloState(repository);
  await state.load();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: AddPetScreen(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('on ${platform.name} the photo button offers the camera', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await _pumpForm(tester);

      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from library'), findsOneWidget);

      // The picker plugin is absent in tests; choosing must close the sheet
      // without an uncaught error (a real camera is device-only).
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('on desktop the photo button opens the file picker directly', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await _pumpForm(tester);

    await tester.tap(find.text('Add a photo'));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
