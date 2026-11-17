import 'dart:convert';
import 'package:deedwise/main.dart';
import 'package:deedwise/src/backend/repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('app accepts a public Supabase key and rejects server-secret keys', () {
    const BackendConfig(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    ).validate();
    expect(
      () => const BackendConfig(
        url: 'http://example.supabase.co',
        publishableKey: 'sb_publishable_test',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const BackendConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_test',
      ).validate(),
      throwsFormatException,
    );
    final jwt =
        'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'service_role'})))}.y';
    expect(
      () => BackendConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt,
      ).validate(),
      throwsFormatException,
    );
  });
  SupabaseClient mockClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return client;
  }

  test(
    'group creation sends stable operation ID and goal without local/private records',
    () async {
      final operation = newOperationId();
      expect(
        operation,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      var calls = 0;
      final repo = SupabaseGroupRepository(
        mockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/create_group');
          final payload = jsonDecode(request.body) as Map;
          expect(payload['p_request_id'], operation);
          expect(payload.keys.toSet(), {
            'p_request_id',
            'p_name',
            'p_description',
            'p_goal',
          });
          expect(request.headers['apikey'], 'sb_publishable_test');
          calls++;
          return http.Response(
            jsonEncode('group-uuid'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      for (var i = 0; i < 2; i++) {
        expect(
          await repo.create(
            operationId: operation,
            name: 'Our circle',
            description: 'A goal',
            goal: {'title': 'Meals'},
          ),
          'group-uuid',
        );
      }
      expect(calls, 2);
    },
  );
  test(
    'profile updates contain only the authenticated person’s name',
    () async {
      final repo = SupabaseProfileRepository(
        mockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/ensure_profile');
          expect(jsonDecode(request.body), {'p_display_name': 'Ayesha'});
          return http.Response(
            jsonEncode({'id': 'user-id', 'display_name': 'Ayesha'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      expect((await repo.ensure(name: 'Ayesha')).name, 'Ayesha');
    },
  );
  test(
    'invitation preview never calls acceptance and reports structured errors',
    () async {
      final paths = <String>[];
      final repo = SupabaseGroupRepository(
        mockClient((request) async {
          paths.add(request.url.path);
          expect(jsonDecode(request.body), {'p_token': 'abcdef'});
          return http.Response(
            jsonEncode({'error': 'This invitation is invalid or has expired.'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await expectLater(repo.preview(' ABCDEF '), throwsA(isA<CloudFailure>()));
      expect(paths, ['/rest/v1/rpc/preview_group_invite']);
    },
  );
  test(
    'guest and two real accounts keep local deeds and photo references separate',
    () async {
      SharedPreferences.setMockInitialValues({});
      await localData.initialize();
      store.entries.clear();
      DeedEntry entry(String id) => DeedEntry(
        id: id,
        title: 'I helped my neighbour.',
        template: templates[18],
        date: today,
        custom: true,
        reviewState: ReviewState.unchecked,
      );
      store.entries.add(entry('guest'));
      store.budget = 'No-spend only';
      await localData.preferences!.setString('profile_photo_v1', 'guest-photo');
      await localData.flush();
      await localData.switchAccount('account-a');
      expect(store.entries, isEmpty);
      expect(localData.profilePhoto, isNull);
      expect(store.budget, 'No preference');
      store.entries.add(entry('private-a'));
      store.budget = 'A little to give';
      await localData.preferences!.setString(
        localData.scopedKey('profile_photo_v1'),
        'photo-a',
      );
      await localData.flush();
      await localData.switchAccount('account-b');
      expect(store.entries, isEmpty);
      expect(localData.profilePhoto, isNull);
      store.entries.add(entry('private-b'));
      await localData.switchAccount('account-a');
      expect(store.entries.single.id, 'private-a');
      expect(localData.profilePhoto, 'photo-a');
      expect(store.budget, 'A little to give');
      await localData.switchAccount(null);
      expect(store.entries.single.id, 'guest');
      expect(localData.profilePhoto, 'guest-photo');
      expect(store.budget, 'No-spend only');
      expect(
        localData.preferences!.getString('deeds_v1:account-b'),
        contains('private-b'),
      );
      await localData.flush();
    },
  );

  testWidgets(
    'account-transition splash preserves the mounted navigator and app shell',
    (tester) async {
      SharedPreferences.setMockInitialValues({'tour_seen_v1': true});
      await localData.initialize();
      await tester.pumpWidget(const DeedWiseApp());
      await tester.pumpAndSettle();
      final shell = tester.state(find.byType(AppShell));
      final navigator = rootNavigatorKey.currentState;
      backend.changingAccount = true;
      backend.notifyListeners();
      await tester.pump();
      expect(find.byType(AppSplash), findsOneWidget);
      expect(identical(rootNavigatorKey.currentState, navigator), isTrue);
      expect(identical(tester.state(find.byType(AppShell)), shell), isTrue);
      backend.changingAccount = false;
      backend.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(AppSplash), findsNothing);
      expect(identical(tester.state(find.byType(AppShell)), shell), isTrue);
      expect(tester.takeException(), isNull);
      await localData.flush();
    },
  );
}
