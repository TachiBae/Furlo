import 'dart:math';

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random.secure();

/// A 20-character random id in the same shape as a Firestore auto-id.
///
/// Created on the client before the first save, so retrying a save that
/// failed halfway writes the same record again instead of adding a second one.
String generateRecordId() => List.generate(
  20,
  (_) => _alphabet[_random.nextInt(_alphabet.length)],
).join();
