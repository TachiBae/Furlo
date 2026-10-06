/// Returns a compact, non-reversible namespace for a user scope.
///
/// This is a local partition key, not a credential or a cryptographic hash.
String userStorageScopeToken(String scope) {
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final unit in scope.codeUnits) {
    first = ((first ^ unit) * 0x01000193) & 0xffffffff;
    second = ((second ^ unit) * 0x85ebca6b) & 0xffffffff;
  }
  return '${first.toRadixString(16).padLeft(8, '0')}'
      '${second.toRadixString(16).padLeft(8, '0')}';
}
