import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/utils/photo_fit.dart';

/// A PNG of random noise, which compresses badly: a stand-in for a large
/// phone photo.
Future<Uint8List> _noisyPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final random = Random(7);
  final paint = Paint();
  for (var y = 0; y < height; y += 2) {
    for (var x = 0; x < width; x += 2) {
      paint.color = Color(0xFF000000 | random.nextInt(0xFFFFFF));
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 2), paint);
    }
  }
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a small photo is kept exactly as picked', (tester) async {
    await tester.runAsync(() async {
      final bytes = await _noisyPng(40, 40);
      final uri = await fitPhotoDataUri(bytes, mimeType: 'image/png');
      expect(uri, startsWith('data:image/png;base64,'));
      expect(uri!.length, lessThan(kMaxCloudPhotoBytes));
    });
  });

  testWidgets('a large photo is shrunk until it fits the cloud budget', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await _noisyPng(900, 600);
      final rawLength =
          'data:image/png;base64,'.length + (bytes.length * 4 / 3);
      expect(rawLength, greaterThan(kMaxCloudPhotoBytes));

      final uri = await fitPhotoDataUri(bytes, mimeType: 'image/png');

      expect(uri, isNotNull);
      expect(uri!.length, lessThanOrEqualTo(kMaxCloudPhotoBytes));
      expect(cloudPhotoField(uri), uri); // cloud-eligible
    });
  });

  testWidgets('bytes that are not an image do not fit', (tester) async {
    await tester.runAsync(() async {
      final junk = Uint8List.fromList(List.filled(kMaxCloudPhotoBytes, 1));
      expect(await fitPhotoDataUri(junk), isNull);
    });
  });
}
