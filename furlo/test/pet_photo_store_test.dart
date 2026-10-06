import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
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
}
