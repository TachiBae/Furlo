import 'package:flutter_test/flutter_test.dart';

import 'package:furlo/services/google_web_identity_contract.dart';

void main() {
  group('gisMomentOutcome', () {
    const cases = <String, GisMomentOutcome>{
      'display': GisMomentOutcome.shown,
      'notDisplayed': GisMomentOutcome.fallback,
      'skipped': GisMomentOutcome.fallback,
      'dismissed': GisMomentOutcome.cancel,
      '': GisMomentOutcome.shown,
      'unexpected-type': GisMomentOutcome.shown,
    };

    for (final entry in cases.entries) {
      test("'${entry.key}' maps to ${entry.value.name}", () {
        expect(gisMomentOutcome(entry.key), entry.value);
      });
    }
  });
}
