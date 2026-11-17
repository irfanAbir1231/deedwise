part of '../main.dart';

Future<String?> chooseLocalPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Photos stay on this device. They are included outside the app only when you share a card.',
            ),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final Uint8List? raw = kIsWeb
        ? await web_share.pickPhoto()
        : await const MethodChannel(
            'deedwise/local_photos',
          ).invokeMethod<Uint8List>('pick', source);
    if (raw == null) return null;
    if (raw.length > 20 * 1024 * 1024) {
      throw const FormatException('Please choose an image smaller than 20 MB.');
    }
    final bytes = await compute(prepareLocalPhoto, raw);
    return await local_media.save(bytes);
  } on MissingPluginException {
    if (context.mounted) {
      toast(context, 'Photo selection is available on Android and web.');
    }
  } catch (_) {
    if (context.mounted) {
      toast(
        context,
        'Could not read this photo. Please choose a JPG or PNG under 20 MB.',
      );
    }
  }
  return null;
}

Uint8List prepareLocalPhoto(Uint8List raw) {
  final decoder = raster.findDecoderForData(raw);
  final header = decoder?.startDecode(raw);
  if (header == null || header.width * header.height > 40000000) {
    throw const FormatException('Unsupported or oversized image.');
  }
  var image = raster.decodeImage(raw);
  if (image == null || image.width * image.height > 40000000) {
    throw const FormatException('Unsupported image.');
  }
  image = raster.bakeOrientation(image);
  if (image.width > 1400 || image.height > 1400) {
    image = raster.copyResize(
      image,
      width: image.width >= image.height ? 1400 : null,
      height: image.height > image.width ? 1400 : null,
    );
  }
  // Fresh RGB pixels carry no EXIF, GPS, comments or other source metadata.
  final clean = raster.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  raster.compositeImage(clean, image);
  return Uint8List.fromList(raster.encodeJpg(clean, quality: 85));
}

class LocalPhoto extends StatefulWidget {
  final String path;
  final double? height, width;
  final BoxFit fit;
  const LocalPhoto(
    this.path, {
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });
  @override
  State<LocalPhoto> createState() => _LocalPhotoState();
}

class _LocalPhotoState extends State<LocalPhoto> {
  late Future<Uint8List?> bytes;
  @override
  void initState() {
    super.initState();
    bytes = local_media.read(widget.path);
  }

  @override
  void didUpdateWidget(covariant LocalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) bytes = local_media.read(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, snapshot) => snapshot.data == null
        ? SizedBox(
            height: widget.height,
            width: widget.width,
            child: const Icon(Icons.image_outlined, color: muted),
          )
        : Image.memory(
            snapshot.data!,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.broken_image_outlined),
          ),
  );
}
