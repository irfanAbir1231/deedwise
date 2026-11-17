import 'dart:io';
import 'dart:ui' as ui;
import 'package:deedwise/main.dart';
import 'package:deedwise/src/moderation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as raster;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'DMSans': 'assets/fonts/DMSans.ttf',
      'Lora': 'assets/fonts/Lora.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    await DeedModeration.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'tour_seen_v1': true});
    await localData.initialize();
  });
  tearDown(() async {
    localData.profilePhoto = null;
    await localData.flush();
  });

  test(
    'introduction completion persists independently from the guided tour',
    () async {
      expect(localData.introSeen, isFalse);
      expect(await localData.markIntroSeen(), isTrue);
      await localData.initialize();
      expect(localData.introSeen, isTrue);
      expect(store.tourSeen, isTrue);
    },
  );

  testWidgets(
    'initialization shows a branded splash then first-use introduction',
    (tester) async {
      await tester.pumpWidget(const DeedWiseApp(initialize: true));
      expect(find.byType(AppSplash), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(AppIntroduction), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(localData.introSeen, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('returning user bypasses the introduction', (tester) async {
    await localData.markIntroSeen();
    await tester.pumpWidget(const DeedWiseApp(initialize: true));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppIntroduction), findsNothing);
    expect(tester.takeException(), isNull);
    await localData.flush();
  });

  testWidgets('all introduction pages fit a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var finished = false;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.3),
          ),
          child: RepaintBoundary(
            key: boundaryKey,
            child: AppIntroduction(
              onDone: () async {
                finished = true;
              },
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < introSlides.length; i++) {
      expect(find.text('${i + 1} of 3'), findsOneWidget);
      expect(find.text(introSlides[i].title), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (i == 0 || i == 2) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('preview/introduction-${i + 1}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text(i == 2 ? 'Start my journey' : 'Continue'));
      await tester.pumpAndSettle();
    }
    expect(finished, isTrue);
  });

  testWidgets('cached home header updates when a profile photo is saved', (
    tester,
  ) async {
    final file = File('preview/avatar-test.jpg');
    await tester.runAsync(() async {
      final image = raster.Image(width: 80, height: 80);
      raster.fill(image, color: raster.ColorRgb8(95, 139, 104));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(raster.encodeJpg(image));
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: HomePage()),
      ),
    );
    final profile = find.byTooltip('Profile and settings');
    expect(
      find.descendant(of: profile, matching: find.byType(LocalPhoto)),
      findsNothing,
    );
    await tester.runAsync(() async {
      await localData.setProfilePhoto(file.absolute.path);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: profile, matching: find.byType(LocalPhoto)),
      findsOneWidget,
    );
    expect(
      localData.preferences!.getString('profile_photo_v1'),
      file.absolute.path,
    );
    localData.profilePhoto = null;
    store.changed();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: profile, matching: find.byType(LocalPhoto)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await localData.flush();
  });
}
