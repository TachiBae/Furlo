import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furlo/providers/notification_settings_provider.dart';
import 'package:furlo/repositories/notification_settings_repository.dart';
import 'package:furlo/services/notifications_service.dart';

class _FakeNotificationService implements NotificationService {
  bool granted = true;
  int permissionRequests = 0;
  int rescheduleCalls = 0;
  final cancelledTypes = <String>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> schedule(
    String type,
    int id,
    String title,
    String body,
    DateTime dateTime, {
    NotificationRepeat repeat = NotificationRepeat.none,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAllOfType(String type) async {
    cancelledTypes.add(type);
  }

  @override
  Future<void> rescheduleAll() async {
    rescheduleCalls++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('settings default on and persist after changing a toggle', () async {
    final repository = SharedPreferencesNotificationSettingsRepository();
    final service = _FakeNotificationService();
    final provider = NotificationSettingsProvider(
      repository: repository,
      service: service,
    );
    await provider.ready;
    expect(provider.isEnabled(NotificationTypes.dailyFeeding), isTrue);
    expect(provider.isEnabled(NotificationTypes.medication), isTrue);
    expect(service.permissionRequests, 1);

    await provider.toggle(NotificationTypes.dailyFeeding, false);
    expect(service.cancelledTypes, [NotificationTypes.dailyFeeding]);
    expect(
      await SharedPreferencesNotificationSettingsRepository().isEnabled(
        NotificationTypes.dailyFeeding,
      ),
      isFalse,
    );
    await provider.toggle(NotificationTypes.dailyFeeding, true);
    expect(service.rescheduleCalls, 1);
    expect(
      await SharedPreferencesNotificationSettingsRepository().isEnabled(
        NotificationTypes.dailyFeeding,
      ),
      isTrue,
    );
  });

  test(
    'denied permission keeps saved toggles and does not repeat the prompt',
    () async {
      final repository = SharedPreferencesNotificationSettingsRepository();
      final service = _FakeNotificationService()..granted = false;
      final provider = NotificationSettingsProvider(
        repository: repository,
        service: service,
      );
      await provider.ready;
      expect(provider.permissionGranted, isFalse);
      await provider.toggle(NotificationTypes.medication, false);
      await provider.toggle(NotificationTypes.medication, true);
      expect(service.permissionRequests, 1);
      expect(await repository.isEnabled(NotificationTypes.medication), isTrue);
      expect(service.rescheduleCalls, 0);
    },
  );
}
