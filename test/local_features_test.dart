import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:deedwise/main.dart';
import 'package:deedwise/src/groq_matcher.dart';
import 'package:deedwise/src/moderation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as raster;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await localData.initialize();
    await DeedModeration.load();
    store.tourSeen = true;
  });
  tearDown(() async {
    await localData.flush();
  });

  test(
    'tour flag survives a new startup while fresh storage is first-use',
    () async {
      expect(localData.preferences!.getBool('tour_seen_v1'), isNull);
      await localData.markTourSeen();
      store.tourSeen = false;
      await localData.initialize();
      expect(store.tourSeen, isTrue);
    },
  );

  test(
    'curated language filter blocks profanity, variants and explicit harm',
    () {
      for (final text in [
        'You are an asshole',
        'FUCK',
        'f.u.c.k',
        'f u c k',
        'f\u200Buck',
        'sh1t',
        'তুই মাদার চোদ',
        'bokachoda',
        'I helped my friend to kill a person.',
        'আমি বন্ধুকে খুন করতে সাহায্য করেছি',
        'ami bondhuke khun korte help korechi',
        'I stopped an argument but killed a person',
      ]) {
        expect(DeedModeration.check(text), isNotNull, reason: text);
      }
      for (final text in [
        'I assisted my classmate',
        'I gave food to a child in Bangladesh',
        'বাংলাদেশে একটি বাচ্চাকে খাবার দিয়েছি',
        'I stopped my friend from killing someone',
        'I prevented a murder',
        'আমি বন্ধুকে খুন করা থেকে বিরত রেখেছি',
        ...templates.map((t) => t.title),
      ]) {
        expect(DeedModeration.check(text), isNull, reason: text);
      }
    },
  );

  test(
    'semantic harm decision overrides even a high confidence positive ID',
    () async {
      final matcher = DeviceDeedMatcher(
        groq: GroqDeedClassifier(
          apiKey: 'test',
          clientFactory: () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'rule_id': 'quran-19',
                        'confidence': .99,
                        'completed': true,
                        'harmful': true,
                      }),
                    },
                  },
                ],
              }),
              200,
            ),
          ),
        ),
      );
      final result = await matcher.assess(
        'I helped someone carry out a cruel plan.',
      );
      expect(result.state, ReviewState.rejected);
      expect(result.rule, isNull);
    },
  );

  test(
    'offline similarity cannot approve context-sensitive descriptions',
    () async {
      final result = await DeviceDeedMatcher().assessLocally(
        'I prevented a murder',
      );
      expect(result.state, ReviewState.unavailable);
      expect(result.rule, isNull);
    },
  );

  test('deeds, photo references and deleted entries survive reload', () async {
    final original = store.entries.toList();
    final e = DeedEntry(
      id: 'local-test',
      title: 'I helped my neighbour.',
      template: templates[18],
      date: today,
      localPhoto: 'test-local-photo',
      reviewState: ReviewState.unchecked,
      custom: true,
    );
    store.entries
      ..clear()
      ..add(e);
    expect(await localData.flush(), isTrue);
    store.entries.clear();
    await localData.initialize();
    expect(store.entries.single.localPhoto, 'test-local-photo');
    expect(store.entries.single.title, e.title);
    expect(store.entries.single.eligibleForPoints, isFalse);
    store.entries.clear();
    await localData.flush();
    await localData.initialize();
    expect(store.entries, isEmpty);
    store.entries.addAll(original);
  });

  test('all catalog card captions use first-person completed actions', () {
    expect(completedCardCaptions, hasLength(50));
    for (var i = 0; i < 50; i++) {
      final e = DeedEntry(
        id: '$i',
        title: templates[i].title,
        template: templates[i],
        date: today,
      );
      expect(cardCaption(e), startsWith('I '));
      expect(shareText(e), startsWith(cardCaption(e)));
    }
    expect(
      completedCardCaptions[15],
      'I gave voluntary charity from my wealth.',
    );
  });

  test('photo processing resizes and strips source EXIF', () {
    final image = raster.Image(width: 1700, height: 400);
    image.exif.imageIfd[0x010E] = 'private location description';
    final encoded = raster.encodeJpg(image);
    final result = raster.decodeJpg(prepareLocalPhoto(encoded))!;
    expect(result.width, 1400);
    expect(result.exif.isEmpty, isTrue);
  });

  testWidgets('both save paths reject harmful deed without adding an entry', (
    tester,
  ) async {
    final count = store.entries.length;
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: const FreeTextDeedEditor()),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'I helped my friend to kill a person.',
    );
    final save = find.text('Just save for now');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.entries.length, count);
    expect(find.text(DeedModeration.harmMessage), findsOneWidget);
    final check = find.text('Save and check my deed');
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(store.entries.length, count);
    expect(find.text(DeedModeration.harmMessage), findsOneWidget);
  });

  testWidgets(
    'card photo options default off and render both photos at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final file = File('preview/local-card-test-photo.jpg');
      await tester.runAsync(() async {
        for (final entry in {
          'DMSans': 'assets/fonts/DMSans.ttf',
          'Lora': 'assets/fonts/Lora.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(rootBundle.load(entry.value));
          await loader.load();
        }
        await file.parent.create(recursive: true);
        final image = raster.Image(width: 320, height: 800);
        raster.fill(image, color: raster.ColorRgb8(80, 130, 95));
        for (var x = 0; x < 320; x += 40) {
          raster.fillRect(
            image,
            x1: x,
            y1: 0,
            x2: x + 19,
            y2: 799,
            color: raster.ColorRgb8(186, 202, 156),
          );
        }
        await file.writeAsBytes(raster.encodeJpg(image));
      });
      final e = DeedEntry(
        id: 'card-photo',
        title: templates[15].title,
        template: templates[15],
        date: today,
        localPhoto: file.absolute.path,
      );
      localData.profilePhoto = file.absolute.path;
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: ShareCardPage(e)),
      );
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((s) => !s.value),
        isTrue,
      );
      final canvas = find.byKey(const ValueKey('share-card-canvas'));
      final originalSize = tester.getSize(canvas);
      expect(originalSize.height, 430);
      for (final title in ['Include profile photo', 'Include deed photo']) {
        await Scrollable.ensureVisible(
          tester.element(find.text(title)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text(title));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tester.getSize(canvas), originalSize);
      expect(tester.getSize(find.byType(CardDeedPhoto)).height, 108);
      expect(find.byType(LocalPhoto), findsNWidgets(3));
      expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      final preview = find
          .ancestor(
            of: find.byKey(const ValueKey('share-card-canvas')),
            matching: find.byType(RepaintBoundary),
          )
          .first;
      final boundary = tester.renderObject<RenderRepaintBoundary>(preview);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'preview/share-card-with-photos.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      localData.profilePhoto = null;
    },
  );
}
