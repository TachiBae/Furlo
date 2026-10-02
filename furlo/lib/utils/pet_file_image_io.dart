import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider? petFileImage(String path) {
  final file = path.startsWith('file://')
      ? File.fromUri(Uri.parse(path))
      : File(path);
  return file.existsSync() ? FileImage(file) : null;
}
