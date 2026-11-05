import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

ImageProvider? profileImage(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    if (value.startsWith('data:image/')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return NetworkImage(value);
    }
    if (!kIsWeb && File(value).existsSync()) return FileImage(File(value));
  } catch (_) {
    /* Invalid old image references use the default avatar. */
  }
  return null;
}
