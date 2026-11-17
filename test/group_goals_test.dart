import 'package:deedwise/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GroupData circle({bool perMember = false}) =>
    GroupData('test', 'Test circle', '', 'TEST', true, ['You', 'Sara'])
      ..challengeTitle = 'Our goal'
      ..goalDeedIds = {catalogDeed(14).id}
      ..goalTargets = {GoalMetric.meals: 10, GoalMetric.days: 3}
      ..goalPerMember = perMember
      ..optedIn = true
      ..challengeParticipants.addAll(['You', 'Sara']);

DeedEntry entry(
  String id,
  int number, {
  int repetitions = 1,
  DateTime? date,
  ReviewState state = ReviewState.approved,
}) => DeedEntry(
  id: id,
  title: catalogDeed(number).title,
  template: catalogDeed(number),
  date: date ?? today,
  repetitions: repetitions,
  reviewState: state,
);

void main() {
  test(
    'all 50 deeds support completions and days; optional fields are relevant',
    () {
      for (final deed in templates) {
        expect(
          metricsForDeed(deed.id),
          containsAll([GoalMetric.completions, GoalMetric.days]),
        );
      }
      expect(
        metricsForDeed(catalogDeed(2).id),
        isNot(contains(GoalMetric.donation)),
      );
      expect(metricsForDeed(catalogDeed(24).id), {
        GoalMetric.completions,
        GoalMetric.days,
      });
      expect(metricsForDeed(catalogDeed(14).id), contains(GoalMetric.meals));
      expect(metricsForDeed(catalogDeed(16).id), contains(GoalMetric.donation));
      expect(metricsForDeed(catalogDeed(42).id), contains(GoalMetric.minutes));
    },
  );

  test(
    'counts only accepted explicitly shared relevant entries in date range',
    () {
      final g = circle();
      final entries = [
        entry('ok', 14, repetitions: 4),
        entry('unshared', 14),
        entry('wrong', 2),
        entry('pending', 14, state: ReviewState.pending),
        entry('old', 14, date: today.subtract(const Duration(days: 1))),
      ];
      for (final e in entries.where((e) => e.id != 'unshared')) {
        g.shared[e.id] = e.title;
        g.sharedQuantities[e.id] = {GoalMetric.meals: 7};
      }
      final progress = GroupProgress(g, entries);
      expect(progress.shared.map((e) => e.id), ['ok']);
      expect(progress.total(GoalMetric.meals), 7);
      expect(progress.total(GoalMetric.completions), 4);
      expect(progress.total(GoalMetric.days), 1);
    },
  );

  test('quantities never inferred from repetitions or private quantity', () {
    final g = circle();
    final e = entry('a', 14, repetitions: 8)..quantity = 100;
    g.shared[e.id] = e.title;
    final p = GroupProgress(g, [e]);
    expect(p.total(GoalMetric.meals), 0);
    expect(p.total(GoalMetric.people), 0);
    expect(p.total(GoalMetric.completions), 8);
  });

  test('days are distinct and per member progress stays independent', () {
    final g = circle(perMember: true);
    final a = entry('a', 14),
        b = entry('b', 14),
        c = entry('c', 14, date: today.add(const Duration(days: 1)));
    for (final e in [a, b, c]) {
      g.shared[e.id] = e.title;
      g.sharedBy[e.id] = e == b ? 'Sara' : 'You';
      g.sharedQuantities[e.id] = {GoalMetric.meals: 2};
    }
    final p = GroupProgress(g, [a, b, c]);
    expect(p.total(GoalMetric.days), 2);
    expect(p.total(GoalMetric.days, member: 'Sara'), 1);
    expect(p.total(GoalMetric.meals, member: 'You'), 4);
    expect(p.total(GoalMetric.meals, member: 'Sara'), 2);
    expect(p.target(GoalMetric.meals), 10);
  });

  test(
    'linked events never duplicate shared entries and standalone events use deed and date',
    () {
      final g = circle();
      final e = entry('a', 14);
      g.shared[e.id] = e.title;
      g.sharedQuantities[e.id] = {GoalMetric.meals: 3};
      g.events.addAll([
        ImpactEvent(
          'Linked',
          deedId: e.template.id,
          meals: 300,
          linkedEntryIds: {e.id},
        ),
        ImpactEvent('Separate', deedId: e.template.id, meals: 4),
        ImpactEvent('Wrong deed', deedId: catalogDeed(16).id, meals: 100),
        ImpactEvent(
          'Old',
          deedId: e.template.id,
          meals: 100,
          date: today.subtract(const Duration(days: 1)),
        ),
      ]);
      final p = GroupProgress(g, [e]);
      expect(p.total(GoalMetric.meals), 7);
      expect(p.total(GoalMetric.days), 1);
      g.shared.remove(e.id);
      expect(p.total(GoalMetric.meals), 4);
    },
  );

  test(
    'quantity validation rejects fractional counts, infinity and negatives',
    () {
      expect(validateGoalQuantity('1.5', GoalMetric.meals), isNotNull);
      expect(validateGoalQuantity('1.5', GoalMetric.donation), isNull);
      expect(validateGoalQuantity('NaN', GoalMetric.minutes), isNotNull);
      expect(validateGoalQuantity('-1', GoalMetric.people), isNotNull);
      expect(validateGoalQuantity('', GoalMetric.meals), isNull);
    },
  );

  testWidgets(
    'selected zero totals remain visible; unrelated fields are absent',
    (tester) async {
      final g = circle()..goalTargets = {GoalMetric.completions: 7};
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GroupGoalStats(g))),
      );
      expect(find.text('Completions'), findsOneWidget);
      expect(find.text('0 / 7'), findsOneWidget);
      expect(find.text('Meals shared'), findsNothing);
      expect(find.text('BDT donated'), findsNothing);
      expect(find.text('Days practised'), findsNothing);
    },
  );

  testWidgets('each member receives their own target display', (tester) async {
    final g = circle(perMember: true)
      ..goalTargets = {GoalMetric.completions: 5};
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GroupGoalStats(g))),
    );
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('0 / 5'), findsNWidgets(2));
  });
  testWidgets(
    'creation chooses a catalog deed and saves only selected fields on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = {...store.groups};
      addTearDown(() => store.groups.removeWhere((g) => !before.contains(g)));
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const GroupEditor()),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Prayer circle');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Pray regularly',
      );
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search deeds',
      );
      await Scrollable.ensureVisible(tester.element(search), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'regular prayers');
      await tester.pumpAndSettle();
      final deed = find.widgetWithText(CheckboxListTile, catalogDeed(2).title);
      await Scrollable.ensureVisible(tester.element(deed), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(deed);
      await tester.pumpAndSettle();
      final target = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Completions target',
      );
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.enterText(target, '7');
      await tester.pump();
      expect(find.text('Completions: 0 / 7'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Create my circle');
      await Scrollable.ensureVisible(tester.element(create), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      final g = store.groups.last;
      expect(g.name, 'Prayer circle');
      expect(g.selectedDeedIds, {catalogDeed(2).id});
      expect(g.targets, {GoalMetric.completions: 7});
      expect(g.optedIn, isTrue);
    },
  );

  testWidgets(
    'sharing asks only relevant quantities and counts the confirmed value',
    (tester) async {
      final g = circle()..goalTargets = {GoalMetric.meals: 10};
      final e = entry('group-share-test', 14)..quantity = 999;
      store.entries.add(e);
      addTearDown(() => store.entries.remove(e));
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ShareDeedPage(g, selectedId: e.id),
        ),
      );
      final amount = find.byType(TextFormField);
      await Scrollable.ensureVisible(tester.element(amount), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.enterText(amount, '3');
      final share = find.widgetWithText(FilledButton, 'Confirm and share');
      await Scrollable.ensureVisible(tester.element(share), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(g.sharedQuantities[e.id], {GoalMetric.meals: 3});
      expect(GroupProgress(g, [e]).total(GoalMetric.meals), 3);
      expect(e.quantity, 999);
    },
  );
}
