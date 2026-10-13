import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/services/firestore_setup.dart';

void main() {
  test('the offline cache is on, sized, and shared across web tabs', () {
    expect(furloFirestoreSettings.persistenceEnabled, isTrue);
    expect(furloFirestoreSettings.cacheSizeBytes, 100 * 1024 * 1024);
    expect(
      furloFirestoreSettings.webPersistentTabManager,
      const WebPersistentMultipleTabManager(),
    );
  });

  test('configuring never throws, even where settings are unsupported', () {
    expect(() => configureFirestore(FakeFirebaseFirestore()), returnsNormally);
  });
}
