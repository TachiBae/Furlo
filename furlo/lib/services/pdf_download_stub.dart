import 'dart:typed_data';

Future<void> downloadPdf({
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('Browser PDF download is only available on web.');
}
