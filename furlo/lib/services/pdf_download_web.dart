import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadPdf({
  required String fileName,
  required Uint8List bytes,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  try {
    web.document.body!.appendChild(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    // Allow the browser to consume the URL before releasing the Blob.
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }
}
