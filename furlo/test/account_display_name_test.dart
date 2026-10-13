import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/app_settings_repository.dart';
import 'package:furlo/repositories/account_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineProfile extends NoOpAccountProfileRepository {
  const _OfflineProfile();
  @override
  Future<String?> getDisplayName(String uid) => throw StateError('offline');
  @override
  Future<void> setDisplayName(String uid, String displayName) =>
      throw StateError('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeFirebaseFirestore firestore;
  late FirestoreAccountProfileRepository profile;
  setUp(() {
    firestore = FakeFirebaseFirestore();
    profile = FirestoreAccountProfileRepository(firestore: firestore);
  });

  AccountSyncedAppSettingsRepository device(String scope) =>
      AccountSyncedAppSettingsRepository(
        local: SharedPreferencesAppSettingsRepository(storageScope: scope),
        profile: profile,
        uid: 'alice',
      );

  test('a name set on one device shows on another', () async {
    await device('phone').setDisplayName(' Jo ');
    // A different local scope stands in for a second device's empty cache.
    expect(await device('laptop').getDisplayName(), 'Jo');
  });

  test('the account name refreshes the device cache', () async {
    await profile.setDisplayName('alice', 'Cloud name');
    final local = SharedPreferencesAppSettingsRepository(storageScope: 'p');
    await local.setDisplayName('Old name');
    final synced = AccountSyncedAppSettingsRepository(
      local: local,
      profile: profile,
      uid: 'alice',
    );
    expect(await synced.getDisplayName(), 'Cloud name');
    expect(await local.getDisplayName(), 'Cloud name');
  });

  test('offline, the cached name is shown', () async {
    final local = SharedPreferencesAppSettingsRepository(storageScope: 'p');
    await local.setDisplayName('Cached');
    final synced = AccountSyncedAppSettingsRepository(
      local: local,
      profile: const _OfflineProfile(),
      uid: 'alice',
    );
    expect(await synced.getDisplayName(), 'Cached');
  });

  test('a failed cloud save still updates the device, then throws', () async {
    final local = SharedPreferencesAppSettingsRepository(storageScope: 'p');
    final synced = AccountSyncedAppSettingsRepository(
      local: local,
      profile: const _OfflineProfile(),
      uid: 'alice',
    );
    await expectLater(synced.setDisplayName('New'), throwsStateError);
    expect(await local.getDisplayName(), 'New');
  });

  test('saving the name keeps the other profile flags', () async {
    await profile.markSetupComplete('alice');
    await profile.setDisplayName('alice', 'Jo');
    expect(await profile.isSetupComplete('alice'), isTrue);
    final doc = await firestore
        .collection('users')
        .doc('alice')
        .collection('settings')
        .doc('profile')
        .get();
    expect(doc.data()!['displayName'], 'Jo');
  });
}
