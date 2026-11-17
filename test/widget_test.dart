import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deedwise/main.dart';

DeedStore emptyStore() {
  final data = DeedStore();
  data.entries.clear();
  data.plans.clear();
  data.participationDays.clear();
  return data;
}

DeedEntry entry(String id, {DateTime? date, bool custom = false}) => DeedEntry(
  id: id,
  title: 'A thoughtful act',
  template: templates.first,
  date: date ?? today,
  custom: custom,
);

void main() {
  testWidgets(
    'rapid tab changes preserve planner selection and show the latest tab',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DeedWiseApp());
      await tester.tap(find.text('Planner').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      final next = today.add(const Duration(days: 7));
      final selectedMonth = '${monthNames[next.month - 1]} ${next.year}';
      expect(find.text(selectedMonth).hitTestable(), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pump(const Duration(milliseconds: 15));
      await tester.tap(find.text('Progress').last);
      await tester.pump(const Duration(milliseconds: 15));
      await tester.tap(find.text('Planner').last);
      await tester.pumpAndSettle();
      expect(find.text('Your plans').hitTestable(), findsOneWidget);
      expect(find.text('Overview').hitTestable(), findsNothing);
      expect(find.text(selectedMonth).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion switches content without a delayed fade', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppShell(),
        ),
      ),
    );
    await tester.tap(find.text('Progress').last);
    await tester.pump();
    expect(find.text('Overview').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
  testWidgets('free-text sharing exposes only a neutral activity label', (
    tester,
  ) async {
    final e = DeedEntry(
      id: 'privacy-free',
      title:
          'I gave my friend BDT 5000 to help with a private medical problem.',
      template: templates[1],
      date: today,
      reviewState: ReviewState.approved,
    );
    store.entries.add(e);
    final g = store.groups.first;
    final optedIn = g.optedIn;
    g.optedIn = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ShareDeedPage(g, selectedId: e.id),
      ),
    );
    await tester.ensureVisible(find.text('Confirm and share'));
    await tester.tap(find.text('Confirm and share'));
    await tester.pumpAndSettle();
    expect(g.shared[e.id], e.template.title);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: SharedDeedPage(g, e.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text(e.template.title), findsOneWidget);
    expect(find.textContaining('private medical problem'), findsNothing);
    g.shared.remove(e.id);
    g.optedIn = optedIn;
    store.entries.remove(e);
  });
  testWidgets('review request needs explicit consent and awards no points', (
    tester,
  ) async {
    final e = entry('consent', custom: true)
      ..reviewState = ReviewState.unmatched;
    store.entries.add(e);
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: ReviewRequestPage(e.id)),
    );
    await tester.enterText(
      find.byType(TextFormField),
      'This activity helped someone.',
    );
    await tester.ensureVisible(find.text('Submit review request'));
    await tester.tap(find.text('Submit review request'));
    await tester.pumpAndSettle();
    expect(e.reviewState, ReviewState.unmatched);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit review request'));
    await tester.tap(find.text('Submit review request'));
    await tester.pumpAndSettle();
    expect(e.reviewState, ReviewState.pending);
    expect(e.basePoints, 0);
    store.reviewRequests.removeWhere((r) => r.deedId == e.id);
    store.entries.remove(e);
  });
  test('unmatched stays zero until admin accepts once', () {
    final data = emptyStore();
    final e = entry('free', custom: true)..reviewState = ReviewState.unmatched;
    data.save(e);
    final request = data.requestReview(
      e,
      'This helped a friend overcome a difficulty.',
    );
    expect(data.requestReview(e, 'Duplicate submission'), same(request));
    expect(e.basePoints, 0);
    final rulesBefore = data.matchingRules.length;
    expect(
      data.resolveReview(
        request,
        accept: true,
        response: 'Accepted as practical assistance.',
        category: templates[3],
        points: 15,
        criterion: 'Provide useful guidance to someone facing a real problem.',
      ),
      isTrue,
    );
    expect(e.basePoints, 15);
    expect(data.matchingRules.length, rulesBefore + 1);
    expect(
      data.resolveReview(
        request,
        accept: true,
        response: 'Repeat',
        category: templates[3],
        points: 15,
        criterion: 'Provide helpful guidance.',
      ),
      isFalse,
    );
    expect(data.pointsOn(today), 15);
  });
  test('rejection, superseded requests and edits cannot award points', () {
    final data = emptyStore();
    final e = entry('free', custom: true)..reviewState = ReviewState.unmatched;
    data.save(e);
    final rejected = data.requestReview(e, 'Please review.');
    expect(
      data.resolveReview(
        rejected,
        accept: false,
        response: 'Not enough evidence.',
      ),
      isTrue,
    );
    expect(e.basePoints, 0);
    final request = data.requestReview(e, 'More context.');
    data.save(
      entry('free', custom: true)
        ..reviewState = ReviewState.unchecked
        ..revision = 2,
    );
    expect(request.state, RequestState.superseded);
    expect(
      data.resolveReview(
        request,
        accept: true,
        response: 'Outdated',
        category: templates[3],
        points: 15,
        criterion: 'Useful guidance to a person.',
      ),
      isFalse,
    );
    expect(data.pointsOn(today), 0);
  });
  testWidgets(
    'device adapter applies threshold to platform response fixtures',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        DeviceDeedMatcher.channel,
        (call) async => {
          'ruleId': 'quran-19',
          'score': .95,
          'automaticMatchingEnabled': true,
        },
      );
      final matched = await DeviceDeedMatcher().assess(
        'I helped my friend solve a problem.',
      );
      expect(matched.state, ReviewState.matched);
      messenger.setMockMethodCallHandler(
        DeviceDeedMatcher.channel,
        (call) async => {
          'ruleId': 'quran-19',
          'score': .4,
          'automaticMatchingEnabled': true,
        },
      );
      expect(
        (await DeviceDeedMatcher().assess('I bought a notebook.')).state,
        ReviewState.unmatched,
      );
      messenger.setMockMethodCallHandler(
        DeviceDeedMatcher.channel,
        (call) async => {'ruleId': 'unknown', 'score': .99},
      );
      expect(
        (await DeviceDeedMatcher().assess('Some text.')).state,
        ReviewState.unavailable,
      );
      messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, null);
    },
  );
  test('daily cap applies and editing/deleting recalculates', () {
    final data = emptyStore();
    for (var i = 0; i < 8; i++) {
      data.save(entry('e$i'));
    }
    expect(data.pointsOn(today), 50);
    expect(data.pointsFor(data.entries.last), 0);
    data.save(entry('e0', custom: true));
    for (final e in [...data.entries].skip(4)) {
      data.delete(e);
    }
    expect(data.pointsOn(today), 30);
  });
  test(
    'repeated plan completion uses one canonical record and one recurrence',
    () {
      final data = emptyStore();
      final plan = DeedPlan(
        id: 'p',
        template: templates.first,
        date: today,
        recurrence: 'Daily',
      );
      data.plans.add(plan);
      data.save(entry('first'), plan: plan, dailyChallenge: true);
      data.save(entry('retry'), plan: plan, dailyChallenge: true);
      expect(data.entries.length, 1);
      expect(plan.completionId, data.challengeEntryId);
      expect(data.plans.length, 2);
      expect(data.pointsOn(today), 10);
    },
  );
  test('backdated entries and custom entries do not create streak days', () {
    final data = emptyStore();
    data.save(entry('old', date: today.subtract(const Duration(days: 1))));
    expect(data.streak, 0);
    data.save(entry('custom', custom: true));
    expect(data.streak, 0);
    data.save(entry('current'));
    expect(data.streak, 1);
    data.delete(data.entries.last);
    expect(data.streak, 0);
  });
  test('edits outside an open challenge remove sharing', () {
    final data = emptyStore();
    final g = data.groups.first;
    data.save(entry('shared'));
    g.shared['shared'] = 'A thoughtful act';
    data.save(entry('shared', date: today.subtract(const Duration(days: 1))));
    expect(g.shared, isEmpty);
  });
  testWidgets('primary navigation preserves shell and opens add flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DeedWiseApp());
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    expect(find.text('Your plans'), findsOneWidget);
    await tester.tap(find.text('Community').last);
    await tester.pumpAndSettle();
    expect(find.text('Your groups'), findsOneWidget);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(find.text('Add deed'));
    await tester.pumpAndSettle();
    expect(find.text('What good did you do?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('deed save confirms and updates the shared store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = store.entries.length;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceDeedMatcher.channel,
          (call) async => throw PlatformException(code: 'MODEL_UNAVAILABLE'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceDeedMatcher.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: DeedEditor(template: templates.first),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'My friend was stuck in a problem and I explained how to fix it.',
    );
    await tester.ensureVisible(find.text('Save and check my deed'));
    await tester.tap(find.text('Save and check my deed'));
    await tester.pumpAndSettle();
    expect(find.text('Deed saved'), findsOneWidget);
    expect(store.entries.length, before + 1);
    expect(store.entries.last.basePoints, 0);
    store.delete(store.entries.last);
    expect(tester.takeException(), isNull);
  });
  testWidgets('group-facing view excludes private content', (tester) async {
    final e = store.entries.first;
    final oldNote = e.note;
    e.note = 'PRIVATE_NOTE_SENTINEL';
    final g = store.groups.first;
    g.shared[e.id] = e.title;
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: SharedDeedPage(g, e.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text(e.title), findsOneWidget);
    expect(find.text('PRIVATE_NOTE_SENTINEL'), findsNothing);
    g.shared.remove(e.id);
    e.note = oldNote;
  });
  testWidgets('unsaved journal edits require an explicit discard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JournalEditor()),
              ),
              child: const Text('Open journal'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'An unsaved thought',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this reflection?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('An unsaved thought'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open journal'), findsOneWidget);
    expect(find.text('What felt meaningful?'), findsNothing);
  });
  testWidgets('capture anchor screens and check compact layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final name in ['DMSans', 'Lora']) {
      final loader = FontLoader(name)
        ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final previewEntry = DeedEntry(
      id: 'preview-free-text',
      title:
          'My friend was stuck in a problem and I explained a way to solve it.',
      template: unclassifiedTemplate,
      date: today,
      custom: true,
      reviewState: ReviewState.unavailable,
    );
    store.entries.add(previewEntry);
    addTearDown(() => store.entries.remove(previewEntry));
    final screens = <String, Widget>{
      '00_app_home': const AppShell(),
      '01_home': const HomePage(),
      '02_planner': const PlannerPage(),
      '03_add_deed': DeedEditor(template: templates.first),
      '04_community': const CommunityPage(),
      '05_progress': const ProgressPage(),
      '06_group': GroupDetailPage(store.groups.first),
      '07_journal': const JournalPage(),
      '08_reflection': JournalDetailPage(store.journals.first),
      '09_settings': const SettingsPage(),
      '10_welcome': const WelcomePage(),
      '11_share_preview': ShareDeedPage(
        store.groups.first,
        selectedId: store.entries.first.id,
      ),
      '12_plan_form': PlanEditor(template: templates.first),
      '13_match_result': MatchResultPage(previewEntry.id),
      '14_review_request': ReviewRequestPage(previewEntry.id),
      '15_offline_review': const OfflineModelPage(),
    };
    for (final width in [360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final item in screens.entries) {
        final key = GlobalKey();
        final shellTab = {
          '02_planner': 'Planner',
          '04_community': 'Community',
          '05_progress': 'Progress',
        }[item.key];
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme,
              home: shellTab == null
                  ? Scaffold(body: item.value)
                  : const AppShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (shellTab != null) {
          await tester.tap(find.text(shellTab).last);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '${item.key} at $width');
        if (width == 390) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('preview/${item.key}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });
}
