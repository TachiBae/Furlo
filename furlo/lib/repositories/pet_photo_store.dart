part of 'pet_repository.dart';

// Pet photo policy (what fits in the cloud) and the on-device mirror.

/// Largest photo payload written to a pet document.
///
/// Firestore caps documents at 1 MB; 600 KB leaves headroom for the other
/// pet fields. Base64 data URIs are ASCII, so length approximates bytes.
const int kMaxCloudPhotoBytes = 600 * 1024;

/// Returns [photoPath] when it is a base64 data URI small enough to live in
/// the pet's Firestore document, otherwise null (device file paths, empty,
/// or oversized payloads that would risk the 1 MB document cap).
String? cloudPhotoField(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty) return null;
  if (!photoPath.startsWith('data:')) return null;
  if (photoPath.length > kMaxCloudPhotoBytes) return null;
  return photoPath;
}

/// Cloud document photo when present, otherwise the device-local mirror.
Future<String?> resolvePetPhoto(
  Map<String, Object?> data,
  String petId,
  LocalPetPhotoStore store,
) async {
  final cloud = data['photo'] as String?;
  if (cloud != null && cloud.isNotEmpty) return cloud;
  return store.read(petId);
}

/// Device-side mirror for pet photos, keyed by pet id within one account.
///
/// The pet document in Firestore is the source of truth when the photo is
/// cloud-eligible; this store mirrors it for instant local display and keeps
/// legacy file paths and oversized photos that cannot live in Firestore.
/// Reads fall back to the pre-account key `photo.pet.{id}` so photos taken
/// before per-account scoping still resolve, and repin hits into the scope.
class LocalPetPhotoStore {
  LocalPetPhotoStore({this.storageScope});

  final String? storageScope;

  String _key(String petId) => storageScope == null
      ? 'photo.pet.$petId'
      : 'photo.user.${userStorageScopeToken(storageScope!)}.pet.$petId';

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<String?> read(String petId) async {
    final preferences = await _preferences();
    if (preferences == null) return null;
    final scoped = preferences.getString(_key(petId));
    if (scoped != null) return scoped;
    if (storageScope == null) return null;
    // Legacy pre-account key: adopt it into the active scope. Non-destructive
    // (the legacy key stays), matching the legacy migration's first-user rule.
    final legacy = preferences.getString('photo.pet.$petId');
    if (legacy == null || legacy.isEmpty) return null;
    await preferences.setString(_key(petId), legacy);
    return legacy;
  }

  /// Best-effort: the mirror is a cache, so a full or unavailable store
  /// (browser localStorage has a small quota) must never fail the save of
  /// the pet it belongs to.
  Future<void> write(String petId, String? photoPath) async {
    final preferences = await _preferences();
    if (preferences == null) return;
    try {
      if (photoPath == null || photoPath.isEmpty) {
        await preferences.remove(_key(petId));
        return;
      }
      // Photos too large for the cloud would also crowd out the browser's
      // small storage quota, so they are not cached either.
      if (photoPath.startsWith('data:') &&
          photoPath.length > kMaxCloudPhotoBytes) {
        logAppDiagnostic('Pet photo too large to cache on this device.');
        await preferences.remove(_key(petId));
        return;
      }
      await preferences.setString(_key(petId), photoPath);
    } catch (_) {
      logAppDiagnostic('Pet photo could not be cached on this device.');
    }
  }
}
