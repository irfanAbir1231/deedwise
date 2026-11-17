import 'dart:convert';
import 'package:deedwise/main.dart';
import 'package:deedwise/src/groq_matcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GroqDeedClassifier classifier(Object result, {int status = 200}) =>
      GroqDeedClassifier(
        apiKey: 'test-key',
        clientFactory: () => MockClient((request) async {
          expect(request.url.host, 'api.groq.com');
          expect(request.headers['Authorization'], 'Bearer test-key');
          final body = jsonDecode(request.body);
          expect(body['messages'].last['content'], isA<String>());
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': jsonEncode(result)},
                },
              ],
            }),
            status,
          );
        }),
      );
  test(
    'English, Bengali and Banglish use Groq and accept known completed deeds',
    () async {
      for (final text in [
        'iv helped my friend',
        'আমি বন্ধুকে সাহায্য করেছি',
        'ami bondhuke help korechi',
      ]) {
        final result = await DeviceDeedMatcher(
          groq: classifier({
            'rule_id': 'quran-19',
            'completed': true,
            'harmful': false,
            'confidence': .94,
          }),
        ).assess(text);
        expect(result.state, ReviewState.matched);
        expect(result.rule?.id, 'quran-19');
      }
    },
  );
  test(
    'valid negative decisions do not fall back to a positive local match',
    () async {
      final result = await DeviceDeedMatcher(
        groq: classifier({
          'rule_id': null,
          'completed': false,
          'harmful': false,
          'confidence': .98,
        }),
      ).assess('I will help someone tomorrow');
      expect(result.state, ReviewState.unmatched);
      expect(result.rule, isNull);
      expect(result.message, contains('Groq'));
    },
  );
  test(
    'invalid IDs, confidence and API errors invoke local fallback',
    () async {
      for (final service in [
        classifier({
          'rule_id': 'invented',
          'completed': true,
          'harmful': false,
          'confidence': .99,
        }),
        classifier({
          'rule_id': 'quran-19',
          'completed': true,
          'harmful': false,
          'confidence': 90,
        }),
        classifier({}, status: 429),
        GroqDeedClassifier(
          apiKey: 'test',
          clientFactory: () =>
              MockClient((_) async => throw http.ClientException('offline')),
        ),
      ]) {
        final result = await DeviceDeedMatcher(
          groq: service,
        ).assess('I helped my friend');
        expect(
          result.state,
          ReviewState.unavailable,
        ); // Desktop has no Android plugin.
        expect(result.message, contains('local fallback'));
      }
    },
  );
  test('low-confidence Groq classifications remain suggestions', () async {
    final result = await DeviceDeedMatcher(
      groq: classifier({
        'rule_id': 'quran-19',
        'completed': true,
        'harmful': false,
        'confidence': .6,
      }),
    ).assess('I helped');
    expect(result.state, ReviewState.unmatched);
    expect(result.rule?.id, 'quran-19');
  });
}
