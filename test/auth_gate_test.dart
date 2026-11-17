import 'package:deedwise/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({'tour_seen_v1': true});
    await localData.initialize();
    backend.ready = true;
    backend.userId = null;
    backend.changingAccount = false;
    backend.identityError = null;
    backend.error = null;
  });
  tearDown(() async {
    backend.ready = false;
    backend.userId = null;
    await localData.flush();
  });
  testWidgets(
    'entry gate shows login, restores Home when signed in and returns to login when signed out',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const BackendAccountGate()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CloudLoginPage), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      backend.userId = 'signed-in-user';
      backend.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(CloudLoginPage), findsNothing);
      backend.userId = null;
      backend.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(CloudLoginPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'signed-in profile shows Log out rather than another login prompt',
    (tester) async {
      backend.userId = 'signed-in-user';
      await tester.pumpWidget(
        MaterialApp(theme: appTheme, home: const SettingsPage()),
      );
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('initial login page fits a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.3),
          ),
          child: CloudLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    expect(tester.takeException(), isNull);
  });
}
