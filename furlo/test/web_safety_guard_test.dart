import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Web safety guards.
///
/// The app is graded on web, where a single unguarded platform call throws and
/// takes the whole screen with it. These checks pin the guards that keep the
/// web build working: `dart:io` behind a conditional import, and the
/// notification plugin behind `kIsWeb`.
void main() {
  final sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String readable(String path) => path.replaceAll(r'\', '/');

  String read(String relative) => File(relative).readAsStringSync();

  test('the lib scan actually found the Dart sources', () {
    expect(sources.length, greaterThan(40));
  });

  test('dart:io is confined to the conditional-import target', () {
    // pet_file_image.dart conditionally exports _stub or _io depending on
    // dart.library.io, which is what keeps the import off the web build.
    final offenders = <String>[];
    for (final file in sources) {
      final path = readable(file.path);
      if (path.endsWith('_io.dart')) continue;
      if (file.readAsStringSync().contains("import 'dart:io'")) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'dart:io does not exist on web; reach it through a conditional '
          'import instead:\n${offenders.join('\n')}',
    );
  });

  test('the platform-image helper keeps its conditional export', () {
    final helper = read('lib/utils/pet_file_image.dart');
    expect(helper, contains('export'));
    expect(helper, contains('dart.library.io'));
    expect(helper, contains('pet_file_image_stub.dart'));
    expect(helper, contains('pet_file_image_io.dart'));
  });

  test('the local-notifications plugin is only reached off web', () {
    final offenders = <String>[];
    for (final file in sources) {
      final path = readable(file.path);
      final source = file.readAsStringSync();
      if (!source.contains('flutter_local_notifications')) continue;
      if (!source.contains('kIsWeb')) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'flutter_local_notifications has no web implementation; the file '
          'that imports it must branch on kIsWeb:\n${offenders.join('\n')}',
    );
  });

  test('the notification factory returns a no-op service on web', () {
    final source = read('lib/services/notifications_service.dart');
    expect(
      source,
      contains('kIsWeb'),
      reason: 'the factory must branch on kIsWeb',
    );
    expect(
      source,
      contains('NoOpNotificationService()'),
      reason: 'web must get the no-op service, not the plugin-backed one',
    );
  });

  test('the legacy migration guards its sqflite reader behind kIsWeb', () {
    final source = read('lib/services/legacy_local_migration.dart');
    expect(source, contains('kIsWeb'));
    expect(
      source,
      contains('SqlitePetRepository'),
      reason: 'the guarded sqflite reader should still be the mobile path',
    );
  });
}
