import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> save(Uint8List bytes) async {
  final root = await getApplicationSupportDirectory();
  final directory = await Directory(
    '${root.path}/deedwise_photos',
  ).create(recursive: true);
  final file = File(
    '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> read(String path) async {
  try {
    return await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> remove(String path) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/deedwise_photos').absolute.path;
  final file = File(path).absolute;
  if (!file.path.startsWith('$directory${Platform.pathSeparator}')) return;
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
