import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cloudPhotoField', () {
    test('accepts a small base64 data URI unchanged', () {
      const photo = 'data:image/jpeg;base64,Q09VQ0g=';
      expect(cloudPhotoField(photo), photo);
    });

    test('accepts a payload exactly at the size cap', () {
      const prefix = 'data:image/png;base64,';
      final photo = prefix + 'A' * (kMaxCloudPhotoBytes - prefix.length);
      expect(photo.length, kMaxCloudPhotoBytes);
      expect(cloudPhotoField(photo), photo);
    });

    test('rejects a payload one byte over the cap', () {
      const prefix = 'data:image/png;base64,';
      final photo = prefix + 'A' * (kMaxCloudPhotoBytes - prefix.length + 1);
      expect(photo.length, kMaxCloudPhotoBytes + 1);
      expect(cloudPhotoField(photo), isNull);
    });

    test('rejects device file paths so they never reach the document', () {
      expect(cloudPhotoField('/storage/emulated/0/DCIM/pet.jpg'), isNull);
      expect(cloudPhotoField('file:///var/tmp/pet.jpg'), isNull);
    });

    test('rejects null and empty values', () {
      expect(cloudPhotoField(null), isNull);
      expect(cloudPhotoField(''), isNull);
    });
  });

  group('resolvePetPhoto', () {
    test('prefers the cloud photo over the local mirror', () async {
      SharedPreferences.setMockInitialValues({
        'photo.pet.p1': 'data:image/png;base64,TE9DQUw=',
      });
      final store = LocalPetPhotoStore();

      final resolved = await resolvePetPhoto(
        {'photo': 'data:image/png;base64,Q0xPVUQ='},
        'p1',
        store,
      );

      expect(resolved, 'data:image/png;base64,Q0xPVUQ=');
    });

    test(
      'falls back to the local mirror when the cloud photo is absent',
      () async {
        SharedPreferences.setMockInitialValues({
          'photo.pet.p1': 'data:image/png;base64,TE9DQUw=',
        });
        final store = LocalPetPhotoStore();

        expect(
          await resolvePetPhoto({}, 'p1', store),
          'data:image/png;base64,TE9DQUw=',
        );
        expect(
          await resolvePetPhoto({'photo': ''}, 'p1', store),
          'data:image/png;base64,TE9DQUw=',
        );
      },
    );

    test('returns null when neither source has a photo', () async {
      final store = LocalPetPhotoStore();

      expect(await resolvePetPhoto({}, 'p1', store), isNull);
      expect(await resolvePetPhoto({'photo': null}, 'p1', store), isNull);
    });
  });
}
