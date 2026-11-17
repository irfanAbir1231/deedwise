import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

Future<void> downloadShareCard(Uint8List bytes) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = 'deedwise-card.png'
    ..click();
  Future<void>.delayed(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
}

Future<Uint8List?> pickPhoto() async {
  final input = html.FileUploadInputElement()..accept = 'image/jpeg,image/png,image/webp';
  final done = Completer<Uint8List?>();
  input.onChange.first.then((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) { if (!done.isCompleted) done.complete(null); return; }
    if (files.first.size > 20 * 1024 * 1024) {
      if (!done.isCompleted) done.completeError(const FormatException('Image too large'));
      return;
    }
    final reader = html.FileReader()..readAsArrayBuffer(files.first);
    await reader.onLoadEnd.first;
    if (!done.isCompleted) done.complete(reader.result as Uint8List?);
  });
  input.addEventListener('cancel', (_) { if (!done.isCompleted) done.complete(null); });
  input.click();
  return done.future;
}
