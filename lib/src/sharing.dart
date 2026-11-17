part of '../main.dart';

class ShareCardPage extends StatefulWidget {
  final DeedEntry entry;
  const ShareCardPage(this.entry, {super.key});
  @override
  State<ShareCardPage> createState() => _ShareCardPageState();
}

class _ShareCardPageState extends State<ShareCardPage> {
  final cardKey = GlobalKey();
  bool sharing = false;
  bool includeProfile = false, includePhoto = false;
  late final TextEditingController caption;
  @override
  void initState() {
    super.initState();
    caption = TextEditingController(text: cardCaption(widget.entry));
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> shareCard() async {
    if (sharing) return;
    if (caption.text.trim().isEmpty) {
      toast(context, 'Write a caption for your card.');
      return;
    }
    final issue = DeedModeration.check(caption.text);
    if (issue != null) {
      toast(context, issue);
      return;
    }
    setState(() => sharing = true);
    try {
      for (final path in [
        if (includePhoto) widget.entry.localPhoto,
        if (includeProfile) localData.profilePhoto,
      ].whereType<String>()) {
        final bytes = await local_media.read(path);
        if (bytes == null) throw StateError('Photo missing.');
        if (!mounted) return;
        await precacheImage(MemoryImage(bytes), context);
      }
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not render the card.');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (kIsWeb) {
        await web_share.downloadShareCard(bytes);
        try {
          await Clipboard.setData(
            ClipboardData(text: shareText(widget.entry, caption: caption.text)),
          );
        } catch (_) {}
        if (mounted) {
          toast(
            context,
            'Card downloaded. Deed text copied so you can add it to your post.',
          );
        }
        return;
      }
      await const MethodChannel('deedwise/share_card').invokeMethod<void>(
        'shareImage',
        {
          'bytes': bytes,
          'text': shareText(widget.entry, caption: caption.text),
        },
      );
    } on MissingPluginException {
      await Clipboard.setData(
        ClipboardData(text: shareText(widget.entry, caption: caption.text)),
      );
      if (mounted) {
        toast(context, 'Card preview is ready. Deed text copied to clipboard.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        toast(context, error.message ?? 'Could not open the share menu.');
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not prepare the share card.');
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Share your deed',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose what you share.',
          style: TextStyle(fontSize: 14, color: muted),
        ),
        const SizedBox(height: 8),
        const NoteBox(
          'Your card includes the caption, count, date and only the photos you select below. Private notes and journals stay private. Photos are never uploaded to our backend.',
        ),
        const FieldLabel('Card caption'),
        TextField(
          controller: caption,
          readOnly: sharing,
          maxLines: 4,
          minLines: 2,
          maxLength: 600,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            helperText: 'Describe what you did, in your own voice.',
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include profile photo'),
          subtitle: Text(
            localData.profilePhoto == null
                ? 'Add a photo in Settings first.'
                : 'Shown in the upper-right corner.',
          ),
          value: includeProfile,
          onChanged: sharing || localData.profilePhoto == null
              ? null
              : (v) => setState(() => includeProfile = v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include deed photo'),
          subtitle: Text(
            widget.entry.localPhoto == null
                ? 'Attach a photo when writing or editing this deed.'
                : 'Add your attached photo to this card.',
          ),
          value: includePhoto,
          onChanged: sharing || widget.entry.localPhoto == null
              ? null
              : (v) => setState(() => includePhoto = v),
        ),
        const SizedBox(height: 20),
        RepaintBoundary(
          key: cardKey,
          child: Container(
            key: const ValueKey('share-card-canvas'),
            width: double.infinity,
            height: 430,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFCF4), Color(0xFFE0EBDF)],
              ),
              border: Border.all(color: const Color(0xFFD8E2D7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 34),
                    const Spacer(),
                    if (includeProfile && localData.profilePhoto != null)
                      ClipOval(
                        child: LocalPhoto(
                          localData.profilePhoto!,
                          height: 52,
                          width: 52,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (includePhoto && widget.entry.localPhoto != null) ...[
                  CardDeedPhoto(widget.entry.localPhoto!),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Text(
                            caption.text.trim(),
                            style: editorial(29),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Done ${widget.entry.repetitions} ${widget.entry.repetitions == 1 ? 'time' : 'times'}  ·  ${dateLabel(widget.entry.date)}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Brand(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'A little good, remembered.',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          key: tourShareActionKey,
          onPressed: sharing ? null : shareCard,
          icon: sharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          label: SizedBox(
            width: double.infinity,
            child: Center(
              child: Text(
                sharing
                    ? 'Preparing card…'
                    : kIsWeb
                    ? 'Download share card'
                    : 'Share card',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final issue = DeedModeration.check(caption.text);
            if (issue != null) {
              toast(context, issue);
              return;
            }
            await Clipboard.setData(
              ClipboardData(
                text: shareText(widget.entry, caption: caption.text),
              ),
            );
            if (context.mounted) toast(context, 'Deed text copied.');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy deed text instead'),
        ),
      ],
    ),
  );
}

String shareText(DeedEntry entry, {String? caption}) =>
    '${caption?.trim() ?? cardCaption(entry)}\nDone ${entry.repetitions} ${entry.repetitions == 1 ? 'time' : 'times'} · ${dateLabel(entry.date)}\nShared from DeedWise';

class CardDeedPhoto extends StatelessWidget {
  final String path;
  const CardDeedPhoto(this.path, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LocalPhoto(path, fit: BoxFit.cover),
          // Fade in a blurred copy only at the right edge; text and branding
          // remain outside this clipped image effect.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.transparent, Colors.transparent, Colors.white],
              stops: [0, .55, 1],
            ).createShader(bounds),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 6,
                sigmaY: 6,
                tileMode: TileMode.clamp,
              ),
              child: LocalPhoto(path, fit: BoxFit.cover),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0x88E0EBDF)],
                stops: [.45, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x55D8E2D7)),
            ),
          ),
        ],
      ),
    ),
  );
}
