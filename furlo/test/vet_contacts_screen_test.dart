import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'vet contact cards render across counts, viewport sizes, and text scales',
    (tester) async {
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      final launcherCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
            launcherCalls.add(call.method);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, null),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in [
        const Size(360, 640),
        const Size(400, 300),
        const Size(1280, 800),
      ]) {
        for (final textScale in [1.0, 1.5]) {
          for (final count in [1, 2, 5]) {
            tester.view.physicalSize = size;
            SharedPreferences.setMockInitialValues({});
            final repository = WebPetRepository();
            for (var index = 0; index < count; index++) {
              await repository.addVet(
                Vet(name: 'Dr. Lee $index', phone: '555-010$index'),
                const [],
              );
            }
            final state = FurloState(repository);
            await state.load();

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey('$size-$textScale-$count'),
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: ChangeNotifierProvider.value(
                  value: state,
                  child: VetContactsScreen(repository: repository),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$count vets at $size with text scale $textScale',
            );
            expect(find.text('Dr. Lee 0'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Dr. Lee ${count - 1}'),
              300,
              scrollable: find
                  .descendant(
                    of: find.byType(VetContactsScreen),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(find.text('Dr. Lee ${count - 1}'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'building all $count vets at $size/$textScale',
            );

            final callButton = find
                .widgetWithText(OutlinedButton, 'Call')
                .first;
            expect(
              tester.getSize(callButton).height,
              greaterThanOrEqualTo(48),
              reason: 'Call tap target at $size/$textScale/$count',
            );

            if (size == const Size(360, 640) &&
                textScale == 1.0 &&
                count == 1) {
              await tester.tap(callButton);
              await tester.pumpAndSettle();
              expect(launcherCalls, contains('canLaunch'));
              expect(launcherCalls, contains('launch'));
            }

            await tester.pumpWidget(const SizedBox.shrink());
            state.dispose();
          }
        }
      }
    },
  );
}
