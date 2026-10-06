import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';

void main() {
  group('NotificationSettingsRepository.clearAll', () {
    test(
      'removes only notification.* keys — pet and feeding data survive',
      () async {
        SharedPreferences.setMockInitialValues({
          'furlo.pets': ['{"id":"1","name":"Milo","species":"Dog"}'],
          'furlo.feeding_schedules': <String>[],
          'notification.enabled.daily_feeding': true,
          'notification.enabled.missed_meal': false,
          'notification.permission_requested': true,
        });

        final repo = SharedPreferencesNotificationSettingsRepository();
        await repo.clearAll();

        final prefs = await SharedPreferences.getInstance();

        // Notification keys must be gone.
        for (final type in NotificationTypes.all) {
          expect(
            prefs.getBool('notification.enabled.$type'),
            isNull,
            reason: 'notification.enabled.$type should be removed',
          );
        }
        expect(prefs.getBool('notification.permission_requested'), isNull);

        // Non-notification keys must be untouched.
        expect(prefs.getStringList('furlo.pets'), isNotNull);
        expect(prefs.getStringList('furlo.feeding_schedules'), isNotNull);
      },
    );

    test(
      'clearAll resets in-memory state so subsequent reads return defaults',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = SharedPreferencesNotificationSettingsRepository();

        await repo.setEnabled(NotificationTypes.dailyFeeding, false);
        expect(await repo.isEnabled(NotificationTypes.dailyFeeding), isFalse);

        await repo.clearAll();

        // After clearing, the setting should return the default (true).
        expect(await repo.isEnabled(NotificationTypes.dailyFeeding), isTrue);
        expect(await repo.permissionWasRequested(), isFalse);
      },
    );
  });
}
