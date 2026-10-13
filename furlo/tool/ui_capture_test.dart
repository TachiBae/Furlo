// ignore_for_file: invalid_use_of_visible_for_testing_member

// Renders real Furlo screens with real fonts and writes PNGs for visual review
// at phone (375) and desktop (1440) widths in all three themes.
//
// It lives in tool/, so `flutter test` never runs it. Run it directly:
//
//   flutter test tool/ui_capture_test.dart \
//     --dart-define=CAPTURE_DIR=/tmp/furlo-shots --dart-define=SCENES=feeding
//
// SCENES is a comma-separated list of scene-name prefixes (empty = all).
// Unlike tool/screenshot_harness.dart this can tap through flows (open a
// dialog, pick a value) before capturing, and it needs no browser.
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/feeding_entry.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/providers/furlo_state.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/screens/feeding/feeding_screen.dart';
import 'package:furlo/screens/home/home_screen.dart';
import 'package:furlo/screens/vaccinations/vaccination_screen.dart';
import 'package:furlo/screens/settings/notifications_screen.dart';
import 'package:furlo/screens/vets/vet_contacts_screen.dart';
import 'package:furlo/services/notifications_service.dart';
import 'package:furlo/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outDir = String.fromEnvironment(
  'CAPTURE_DIR',
  defaultValue: 'build/ui_capture',
);
const _only = String.fromEnvironment('SCENES');

const _sizes = {'375': Size(375, 812), '1440': Size(1440, 900)};

/// One screen state to capture. [build] seeds data and returns the screen;
/// [act] optionally drives it (taps, picks) before the capture.
class Scene {
  const Scene(this.name, this.build, {this.act});

  final String name;
  final Future<Widget> Function() build;
  final Future<void> Function(WidgetTester tester)? act;
}

// ---------------------------------------------------------------- data

class _Seeded {
  _Seeded(this.repository, this.state, this.mochi, this.vet);
  final WebPetRepository repository;
  final FurloState state;
  final Pet mochi;
  final Vet vet;
}

Future<_Seeded> _seed([WebPetRepository? repository]) async {
  SharedPreferences.setMockInitialValues({});
  final repo = repository ?? WebPetRepository();
  final now = DateTime.now();
  await repo.addPet(
    Pet(id: '1', name: 'Mochi', species: 'Dog', breed: 'Shiba Inu'),
  );
  await repo.addPet(Pet(id: '2', name: 'Poppy', species: 'Cat'));
  await repo.addFeedingSchedule(
    FeedingEntry(
      petId: '1',
      name: 'Kibble',
      time: '07:30',
      frequency: FeedingFrequency.twiceDaily,
      secondTime: '18:30',
      portionSize: '1 cup',
      remindMe: true,
      lastFedAt: DateTime(now.year, now.month, now.day, 7, 35),
    ),
  );
  await repo.addFeedingSchedule(
    FeedingEntry(
      petId: '1',
      name: 'Joint supplement',
      time: '12:00',
      frequency: FeedingFrequency.weekly,
      daysOfWeek: const [1, 4],
      remindMe: true,
    ),
  );
  await repo.addFeedingSchedule(
    FeedingEntry(
      petId: '1',
      name: 'Dental chew',
      time: '20:00',
      lastFedAt: now,
    ),
  );
  await repo.addFeedingSchedule(
    FeedingEntry(petId: '2', name: 'Wet food', time: '00:05'),
  );
  final vet = await repo.addVet(
    Vet(
      name: 'Dr. Amelia Kim',
      clinic: 'Riverside Animal Clinic',
      phone: '555-0142',
      email: 'kim@riverside.vet',
    ),
    ['1', '2'],
  );
  await repo.setNextAppointment(vet.id!, '1', DateTime(now.year, 12, 3));
  final state = FurloState(repo);
  await state.load();
  final mochi = state.pets.firstWhere((p) => p.id == '1');
  state.selectPet(mochi);
  return _Seeded(repo, state, mochi, vet);
}

Widget _withState(FurloState state, Widget child) =>
    ChangeNotifierProvider<FurloState>.value(value: state, child: child);

class _FailingVetRepository extends WebPetRepository {
  bool fail = false;
  @override
  Future<Vet?> getVetById(String id) async {
    if (fail) throw StateError('offline');
    return super.getVetById(id);
  }
}

class _PendingRepository extends WebPetRepository {
  @override
  Future<List<Vaccination>> getVaccinationsForPet(String petId) =>
      Completer<List<Vaccination>>().future;
}

class _FailingSettings extends SharedPreferencesNotificationSettingsRepository {
  @override
  Future<Map<String, bool>> getAll() async => throw StateError('offline');
}

// ---------------------------------------------------------------- scenes

final List<Scene> scenes = [
  Scene('dashboard', () async {
    final s = await _seed();
    return _withState(
      s.state,
      ChangeNotifierProvider<ThemeSettings>(
        create: (_) => ThemeSettings(),
        child: HomeScreen(
          repository: s.repository,
          notificationSettings:
              SharedPreferencesNotificationSettingsRepository(),
          notificationService: const NoOpNotificationService(),
        ),
      ),
    );
  }),
  Scene('vet-list', () async {
    final s = await _seed();
    return _withState(s.state, VetContactsScreen(repository: s.repository));
  }),
  Scene('vaccinations-loading', () async {
    final repo = _PendingRepository();
    final s = await _seed(repo);
    return VaccinationScreen(repository: repo, pets: s.state.pets);
  }),
  Scene('feeding-list', () async {
    final s = await _seed();
    return _withState(s.state, FeedingScreen(repository: s.repository));
  }),
  Scene(
    'feeding-form-twice-daily',
    () async {
      final s = await _seed();
      return _withState(s.state, FeedingScreen(repository: s.repository));
    },
    act: (tester) async {
      await tester.tap(find.text('Add feeding schedule').last);
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Kibble');
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await _settle(tester);
      await tester.tap(find.text(FeedingFrequency.twiceDaily).last);
      await _settle(tester);
    },
  ),
  Scene('vet-details', () async {
    final s = await _seed();
    return VetDetailsScreen(repository: s.repository, vet: s.vet);
  }),
  Scene('vet-details-load-error', () async {
    final repo = _FailingVetRepository();
    final s = await _seed(repo);
    repo.fail = true;
    return VetDetailsScreen(repository: repo, vet: s.vet);
  }),
  Scene('notification-settings-load-error', () async {
    SharedPreferences.setMockInitialValues({});
    return NotificationSettingsScreen(
      settings: _FailingSettings(),
      service: const NoOpNotificationService(),
    );
  }),
];

// ---------------------------------------------------------------- engine

/// pumpAndSettle that tolerates endless animations (spinners).
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

String _cacheDir() {
  final exe = Platform.resolvedExecutable;
  final index = exe.indexOf(
    '${Platform.pathSeparator}bin'
    '${Platform.pathSeparator}cache',
  );
  if (index < 0) throw StateError('Cannot locate the Flutter cache from $exe');
  return exe.substring(0, index + '/bin/cache'.length);
}

/// Filesystem root of [name], read from the package config `pub get` wrote.
String _packageRoot(String name) {
  final configFile = File('.dart_tool/package_config.json');
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  final entry = (config['packages'] as List).cast<Map>().firstWhere(
    (p) => p['name'] == name,
  );
  final root = configFile.uri.resolve(entry['rootUri'] as String);
  return root.toFilePath().replaceAll(RegExp(r'/$'), '');
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      File(path).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final material = '${_cacheDir()}/artifacts/material_fonts';
  // 'FlutterTest' is the test engine's fallback family, used by any text
  // whose style names no family (button labels set their own style).
  for (final family in ['FlutterTest', 'Ahem']) {
    await _loadFont(family, [
      for (final w in ['Regular', 'Medium', 'Bold']) '$material/Roboto-$w.ttf',
    ]);
  }
  await _loadFont('Roboto', [
    for (final w in ['Regular', 'Medium', 'Bold', 'Light'])
      '$material/Roboto-$w.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  final faRoot = _packageRoot('font_awesome_flutter');
  for (final (family, file) in [
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeBrands', 'Font-Awesome-7-Brands-Regular-400.otf'),
  ]) {
    await _loadFont('packages/font_awesome_flutter/$family', [
      '$faRoot/lib/fonts/$file',
    ]);
  }
}

/// The app's text styles name no family, so a device supplies its platform
/// font. The test engine's fallback is a box glyph, so captures pin Roboto
/// (the Android/web default) at the text-theme level, where every Text
/// inherits it.
ThemeData _withRoboto(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
  primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
);

String _themeName(AppThemeChoice choice) => switch (choice) {
  AppThemeChoice.defaultTheme => 'default',
  AppThemeChoice.light => 'light',
  AppThemeChoice.dark => 'dark',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  final wanted = _only.isEmpty
      ? <String>[]
      : _only.split(',').map((s) => s.trim()).toList();

  for (final scene in scenes) {
    if (wanted.isNotEmpty && !wanted.any(scene.name.startsWith)) continue;
    for (final choice in AppThemeChoice.values) {
      for (final MapEntry(key: width, value: size) in _sizes.entries) {
        final file = '$_outDir/${scene.name}-${_themeName(choice)}-$width.png';
        testWidgets(file, (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          final screen = await tester.runAsync(scene.build);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _withRoboto(AppTheme.forChoice(choice)),
                home: screen,
              ),
            ),
          );
          // Seeded stores were created in real async time; give their
          // futures real time to land, then let the frames settle.
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await _settle(tester);
          }
          if (scene.act != null) await scene.act!(tester);
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(file)
              ..createSync(recursive: true)
              ..writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          // Overflow and other framework errors fail the capture loudly.
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
