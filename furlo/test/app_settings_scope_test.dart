import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'display name scopes isolate account settings and preserve legacy key',
    () async {
      SharedPreferences.setMockInitialValues({
        'profile.display_name': 'Legacy',
      });
      final legacy = SharedPreferencesAppSettingsRepository();
      final alice = SharedPreferencesAppSettingsRepository(
        storageScope: 'alice',
      );
      final bob = SharedPreferencesAppSettingsRepository(storageScope: 'bob');

      await alice.setDisplayName('Alice');

      expect(await legacy.getDisplayName(), 'Legacy');
      expect(await alice.getDisplayName(), 'Alice');
      expect(await bob.getDisplayName(), isEmpty);

      await alice.clearDisplayName();
      expect(await alice.getDisplayName(), isEmpty);
      expect(await bob.getDisplayName(), isEmpty);
      expect(await legacy.getDisplayName(), 'Legacy');
    },
  );
}
