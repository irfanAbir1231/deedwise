import 'package:deedwise/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog preserves all 50 document deeds and multilingual references',
    () {
      final rules = DeedStore().matchingRules;
      expect(rules.map((r) => r.id).toList(), [
        for (var i = 1; i <= 50; i++) 'quran-${i.toString().padLeft(2, '0')}',
      ]);
      expect(rules.first.label, 'Worship God sincerely.');
      expect(rules.last.label, 'Replace wrongdoing with righteous action.');
      expect(rules[18].label, 'Help people who need assistance.');
      expect(rules[13].sourceNote, 'Al-Baqarah 2:177; Al-Insan 76:8');
      for (final rule in rules) {
        expect(rule.category.id, rule.id);
        expect(rule.category.title, rule.label);
        expect(rule.examples.length, 3);
        expect(rule.examples[1], matches(RegExp(r'[\u0980-\u09FF]')));
        expect(rule.internalSource, isNotEmpty);
        expect(rule.points, rule.category.points);
      }
    },
  );

  test(
    'demo content and all 50 selectable activities share the matching catalog',
    () {
      final data = DeedStore();
      final byId = {for (final rule in data.matchingRules) rule.id: rule};
      expect(templates.map((t) => t.id), byId.keys);
      expect(templates.length, 50);
      for (final entry in data.entries) {
        expect(byId.containsKey(entry.template.id), isTrue);
        expect(entry.title, byId[entry.template.id]!.label);
        expect(entry.matchedRuleId, entry.template.id);
        expect(entry.similarity, isNull);
      }
      for (final plan in data.plans) {
        expect(byId.containsKey(plan.template.id), isTrue);
      }
      expect(byId.containsKey(data.goal!.template.id), isTrue);
      expect(byId.containsKey(templates[data.challengeIndex].id), isTrue);
      expect(data.groups.first.challengeTitle, catalogDeed(14).title);
      expect(data.groups.first.challengeAction, catalogDeed(14).title);
      expect(data.groups.first.events.first.title, catalogDeed(14).title);
      expect(
        data.entries
            .where((e) => e.template.unit == 'BDT donated')
            .single
            .quantity,
        200,
      );
      expect(
        data.entries.where((e) => e.template.unit == 'Meals').single.quantity,
        3,
      );
    },
  );

  testWidgets('the 50-deed planning library fits a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: appTheme, home: const LibraryPage(forPlan: true)),
    );
    expect(find.byType(ActivityRow), findsNWidgets(50));
    expect(find.text(catalogDeed(17).title), findsOneWidget);
    expect(find.text('Make someone smile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'threshold accepts boundary and keeps lower scores in review flow',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, null),
      );
      var score = store.matchThreshold;
      var enabled = true;
      final extra = MatchingRule(
        'review-test-only',
        'Manual review',
        '',
        ['Manual review'],
        templates.first,
        1,
      );
      store.matchingRules.add(extra);
      addTearDown(() => store.matchingRules.remove(extra));
      messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        final rules = args['rules'] as List;
        expect(rules.length, 50);
        expect((rules.first as Map)['id'], 'quran-01');
        return {
          'ruleId': 'quran-14',
          'score': score,
          'automaticMatchingEnabled': enabled,
        };
      });
      final matcher = DeviceDeedMatcher();
      final matched = await matcher.assess(
        'I shared lunch with a hungry person.',
      );
      expect(matched.state, ReviewState.matched);
      expect(matched.rule?.id, 'quran-14');
      enabled = false;
      score = .99;
      final suggestion = await matcher.assess(
        'A high score from a suggestion-only model.',
      );
      expect(suggestion.state, ReviewState.unmatched);
      expect(suggestion.rule?.id, 'quran-14');
      expect(suggestion.message, contains('suggested activity'));
      enabled = true;
      score = store.matchThreshold - .000001;
      expect(
        (await matcher.assess('An uncertain action.')).state,
        ReviewState.unmatched,
      );
      score = double.nan;
      expect(
        (await matcher.assess('An invalid model result.')).state,
        ReviewState.unavailable,
      );
    },
  );

  testWidgets(
    'unmatched deed offers review without submitting or awarding points',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final e = DeedEntry(
        id: 'catalog-review-test',
        title: 'An activity that needs context.',
        template: unclassifiedTemplate,
        date: today,
        reviewState: ReviewState.unmatched,
        custom: true,
        similarity: .79,
        nearestRuleId: 'quran-14',
      );
      store.entries.add(e);
      addTearDown(() => store.entries.remove(e));
      final requestsBefore = store.reviewRequests.length;
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: MatchResultPage(e.id)),
      );
      await tester.ensureVisible(find.text('Request a review'));
      expect(find.text('Request a review'), findsOneWidget);
      expect(
        find.text('Closest suggestion: Feed people who are hungry or poor.'),
        findsOneWidget,
      );
      expect(find.textContaining('Match score: 0.790'), findsOneWidget);
      expect(e.matchedRuleId, isNull);
      expect(tester.takeException(), isNull);
      expect(e.basePoints, 0);
      expect(store.reviewRequests.length, requestsBefore);
      await tester.tap(find.text('Request a review'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewRequestPage), findsOneWidget);
      expect(store.reviewRequests.length, requestsBefore);
      expect(e.reviewState, ReviewState.unmatched);
    },
  );

  testWidgets(
    'saving retains the best candidate below the automatic cutoff',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        DeviceDeedMatcher.channel,
        (_) async => {
          'ruleId': 'quran-19',
          'score': .76,
          'automaticMatchingEnabled': true,
        },
      );
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, null),
      );
      final existing = store.entries.map((e) => e.id).toSet();
      addTearDown(
        () => store.entries.removeWhere((e) => !existing.contains(e.id)),
      );
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const FreeTextDeedEditor()),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'I helped my friend fix a problem.',
      );
      await tester.ensureVisible(find.text('Save and check my deed'));
      await tester.tap(find.text('Save and check my deed'));
      await tester.pumpAndSettle();
      final saved = store.entries.singleWhere((e) => !existing.contains(e.id));
      expect(saved.nearestRuleId, 'quran-19');
      expect(saved.matchedRuleId, isNull);
      expect(saved.reviewState, ReviewState.unmatched);
      expect(saved.basePoints, 0);
      expect(saved.similarity, .76);
      expect(find.byType(DeedDetailPage), findsOneWidget);
      expect(find.byType(MatchResultPage), findsNothing);
      expect(find.text('View this entry'), findsNothing);
      expect(
        find.text('Closest suggestion: Help people who need assistance.'),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'short deed descriptions can receive a qualifying match',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, (
        call,
      ) async {
        expect((call.arguments as Map)['text'], 'namaz');
        return {
          'ruleId': 'quran-02',
          'score': .84,
          'automaticMatchingEnabled': true,
        };
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(DeviceDeedMatcher.channel, null),
      );
      final existing = store.entries.map((e) => e.id).toSet();
      addTearDown(
        () => store.entries.removeWhere((e) => !existing.contains(e.id)),
      );
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const FreeTextDeedEditor()),
      );
      await tester.enterText(find.byType(TextFormField).first, 'namaz');
      await tester.ensureVisible(find.text('Save and check my deed'));
      await tester.tap(find.text('Save and check my deed'));
      await tester.pumpAndSettle();
      final saved = store.entries.singleWhere((e) => !existing.contains(e.id));
      expect(saved.matchedRuleId, 'quran-02');
      expect(saved.nearestRuleId, 'quran-02');
      expect(saved.eligibleForPoints, isTrue);
      expect(find.byType(DeedDetailPage), findsOneWidget);
      expect(find.text('Deed saved'), findsOneWidget);
      expect(
        find.text('Matched activity: Perform regular prayers.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Share card'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardPage), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
