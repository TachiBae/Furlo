import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../repositories/pet_repository.dart' show kMaxCloudPhotoBytes;

/// Longest-edge sizes tried, largest first, when a photo is over the limit.
const _edges = [512, 384, 288, 216, 160];

/// A `data:` URI for [bytes] that fits in [maxChars] (the pet document's
/// photo budget), shrinking the image when it is too large.
///
/// The picked file is used as-is when it fits. Otherwise it is decoded with
/// dart:ui (APIs supported on both web and mobile) and re-encoded as PNG at progressively smaller sizes, keeping its
/// aspect ratio. Returns null when even the smallest size does not fit or the
/// bytes are not an image, so the caller can say so instead of saving a
/// photo that would silently stay on this device.
Future<String?> fitPhotoDataUri(
  Uint8List bytes, {
  String mimeType = 'image/jpeg',
  int maxChars = kMaxCloudPhotoBytes,
}) async {
  String dataUri(Uint8List data, String type) =>
      'data:$type;base64,${base64Encode(data)}';

  final original = dataUri(bytes, mimeType);
  if (original.length <= maxChars) return original;

  try {
    // Size comes from a decoded frame: ImageDescriptor.width is not
    // supported on web, which is the graded platform.
    final probe = await ui.instantiateImageCodec(bytes);
    final first = await probe.getNextFrame();
    final width = first.image.width;
    final height = first.image.height;
    first.image.dispose();
    probe.dispose();
    final longest = width > height ? width : height;
    for (final edge in _edges) {
      if (edge >= longest) continue;
      final scale = edge / longest;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (width * scale).round().clamp(1, edge),
        targetHeight: (height * scale).round().clamp(1, edge),
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null) continue;
      final candidate = dataUri(png.buffer.asUint8List(), 'image/png');
      if (candidate.length <= maxChars) return candidate;
    }
  } catch (_) {
    // Not decodable as an image: report "does not fit".
  }
  return null;
}
