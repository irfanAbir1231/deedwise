import 'package:deedwise/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'seasonal browsing includes religious, cultural and secular activities on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const SeasonalPage()),
      );
      expect(find.text('Ramadan & Eid kindness'), findsOneWidget);
      expect(find.text('Christmas giving'), findsOneWidget);
      expect(find.text('Durga Puja community support'), findsOneWidget);
      expect(find.text('Vesak / Buddha Purnima kindness'), findsOneWidget);
      expect(find.text('Hanukkah giving & connection'), findsOneWidget);
      expect(find.text('Vaisakhi & shared service'), findsOneWidget);
      expect(find.text('Winter warmth'), findsOneWidget);
      expect(find.text('Back-to-school support'), findsOneWidget);
      expect(
        find.textContaining('Client-approved seasonal activities'),
        findsNothing,
      );
      final search = find.byType(TextField);
      await reveal(tester, search);
      await tester.enterText(search, 'Christmas');
      await tester.pumpAndSettle();
      expect(find.text('Christmas giving'), findsOneWidget);
      expect(find.text('Ramadan & Eid kindness'), findsNothing);
      await tester.enterText(search, 'no-such-occasion');
      await tester.pumpAndSettle();
      expect(find.text('No activities found'), findsOneWidget);
      await tester.enterText(search, '');
      final chip = find.widgetWithText(ChoiceChip, 'Environment');
      await reveal(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Earth & environment action'), findsOneWidget);
      expect(find.text('Seasonal neighbourhood clean-up'), findsOneWidget);
      expect(find.text('Christmas giving'), findsNothing);
    },
  );

  testWidgets(
    'seasonal suggestion opens planner with the matching canonical deed and saves it',
    (tester) async {
      final activity = seasonalActivities.firstWhere(
        (a) => a.title == 'Christmas giving',
      );
      final previous = {...store.plans};
      addTearDown(() => store.plans.removeWhere((p) => !previous.contains(p)));
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: SeasonalDetailPage(activity)),
      );
      final plan = find
          .ancestor(
            of: find.text('Plan this deed'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .first;
      await reveal(tester, plan);
      await tester.tap(plan);
      await tester.pumpAndSettle();
      final picker = tester.widget<DropdownButtonFormField<DeedTemplate>>(
        find.byType(DropdownButtonFormField<DeedTemplate>),
      );
      expect(picker.initialValue!.id, catalogDeed(14).id);
      final save = find.widgetWithText(FilledButton, 'Save my plan');
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.plans.last.template.id, catalogDeed(14).id);
      expect(find.byType(SeasonalDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'seasonal group setup preselects relevant deeds and allows a user-defined goal',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final activity = seasonalActivities.firstWhere(
        (a) => a.title == 'Winter warmth',
      );
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: SeasonalDetailPage(activity)),
      );
      final create = find
          .ancestor(
            of: find.text('Create a seasonal group goal'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          )
          .first;
      await reveal(tester, create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.first.controller!.text, 'Winter warmth');
      expect(fields[2].controller!.text, 'Winter warmth');
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search deeds',
      );
      for (final action in activity.actions) {
        await reveal(tester, search);
        await tester.enterText(search, catalogDeed(action.deedNumber).title);
        await tester.pumpAndSettle();
        final tile = tester.widget<CheckboxListTile>(
          find.widgetWithText(
            CheckboxListTile,
            catalogDeed(action.deedNumber).title,
          ),
        );
        expect(tile.value, isTrue);
        expect(tile.onChanged, isNotNull);
      }
      expect(find.text('Completions: 0 / 5'), findsOneWidget);
      expect(find.text('BDT donated target'), findsNothing);
    },
  );
}
