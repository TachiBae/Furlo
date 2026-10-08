import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/utils/user_storage_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocalPetPhotoStore', () {
    test(
      'keeps a photo on the device and returns it for the same pet',
      () async {
        final store = LocalPetPhotoStore(storageScope: 'alice-uid');
        await store.write('pet-1', 'data:image/png;base64,QUJD');

        expect(await store.read('pet-1'), 'data:image/png;base64,QUJD');
      },
    );

    test('does not leak photos between accounts', () async {
      final alice = LocalPetPhotoStore(storageScope: 'alice-uid');
      final bob = LocalPetPhotoStore(storageScope: 'bob-uid');
      await alice.write('pet-1', 'data:image/png;base64,QUJD');

      expect(await bob.read('pet-1'), isNull);
    });

    test('clears a photo when the pet has none', () async {
      final store = LocalPetPhotoStore(storageScope: 'alice-uid');
      await store.write('pet-1', 'data:image/png;base64,QUJD');
      await store.write('pet-1', null);

      expect(await store.read('pet-1'), isNull);
    });

    test('treats an empty photo as absent', () async {
      final store = LocalPetPhotoStore(storageScope: 'alice-uid');
      await store.write('pet-1', '');

      expect(await store.read('pet-1'), isNull);
    });
  });

  group('LocalPetPhotoStore legacy fallback', () {
    test('adopts a legacy unscoped photo into the account scope', () async {
      const photo = 'data:image/png;base64,QUJD';
      SharedPreferences.setMockInitialValues({'photo.pet.p1': photo});

      expect(
        await LocalPetPhotoStore(storageScope: 'alice-uid').read('p1'),
        photo,
      );

      // Repinned into the scope: still readable once the legacy key is gone.
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('photo.pet.p1');
      expect(
        await LocalPetPhotoStore(storageScope: 'alice-uid').read('p1'),
        photo,
      );
    });

    test('prefers the scoped photo over the legacy key', () async {
      SharedPreferences.setMockInitialValues({
        'photo.pet.p1': 'legacy',
        'photo.user.${userStorageScopeToken('alice-uid')}.pet.p1': 'scoped',
      });

      expect(
        await LocalPetPhotoStore(storageScope: 'alice-uid').read('p1'),
        'scoped',
      );
    });

    test(
      'signed-out store reads the same key directly with no fallback',
      () async {
        SharedPreferences.setMockInitialValues({
          'photo.pet.p1': 'data:image/png;base64,QUJD',
        });

        expect(
          await LocalPetPhotoStore().read('p1'),
          'data:image/png;base64,QUJD',
        );
        expect(
          await LocalPetPhotoStore(storageScope: 'bob-uid').read('other'),
          isNull,
        );
      },
    );
  });
}
