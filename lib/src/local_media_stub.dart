import 'dart:convert';
import 'dart:typed_data';

// Browser data is persisted with the deed snapshot in browser-local storage.
Future<String> save(Uint8List bytes) async =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';
Future<Uint8List?> read(String path) async {
  try {
    return base64Decode(path.split(',').last);
  } catch (_) {
    return null;
  }
}

Future<void> remove(String path) async {}
