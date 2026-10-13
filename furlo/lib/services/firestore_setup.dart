import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_diagnostics.dart';

/// Keeps a device copy of the account's data, so pets and records still load
/// with a weak or missing connection (a vet's waiting room). Writes made
/// offline are queued by Firestore and sync once the device is back online.
///
/// Web needs persistence switched on explicitly (it defaults to memory only);
/// the multi-tab manager lets two open tabs share the cache instead of the
/// second one failing to start.
const furloFirestoreSettings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024,
  webPersistentTabManager: WebPersistentMultipleTabManager(),
);

/// Applies [furloFirestoreSettings]. Must run before the first read or write.
///
/// Best-effort: settings cannot change once Firestore is in use (for example
/// after a web hot restart), and the app works without the offline cache.
void configureFirestore(FirebaseFirestore firestore) {
  try {
    firestore.settings = furloFirestoreSettings;
  } catch (_) {
    logAppDiagnostic('Firestore offline cache could not be configured.');
  }
}
