import 'package:deedwise/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 480.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'challenge actions stay fixed across all 50 suggestions at width $width and text scale $scale',
        (tester) async {
          final previousIndex = store.challengeIndex;
          final previousAccepted = store.challengeAccepted;
          final previousEntry = store.challengeEntryId;
          addTearDown(() {
            store.challengeIndex = previousIndex;
            store.challengeAccepted = previousAccepted;
            store.challengeEntryId = previousEntry;
          });
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          store.challengeIndex = 0;
          store.challengeAccepted = false;
          store.challengeEntryId = null;
          await tester.pumpWidget(
            MaterialApp(
              theme: appTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const DailyChallengePage(),
            ),
          );
          final change = find.widgetWithText(
            TextButton,
            'Try a different suggestion',
          );
          await Scrollable.ensureVisible(tester.element(change), alignment: .5);
          await tester.pumpAndSettle();
          final copy = find.byKey(const ValueKey('daily-challenge-copy'));
          final action = find.widgetWithText(
            FilledButton,
            'Accept today’s challenge',
          );
          final copyRect = tester.getRect(copy);
          final actionRect = tester.getRect(action);
          final changeRect = tester.getRect(change);
          for (var i = 0; i < templates.length; i++) {
            expect(find.text(templates[i].title), findsOneWidget);
            expect(find.text(templates[i].description), findsOneWidget);
            expect(
              tester.getRect(copy),
              copyRect,
              reason: 'Copy resized for deed ${i + 1}',
            );
            expect(
              tester.getRect(action),
              actionRect,
              reason: 'Action moved for deed ${i + 1}',
            );
            expect(
              tester.getRect(change),
              changeRect,
              reason: 'Suggestion button moved for deed ${i + 1}',
            );
            await tester.tap(change);
            await tester.pumpAndSettle();
          }
          expect(store.challengeIndex, 0);
        },
      );
    }
  }
}
