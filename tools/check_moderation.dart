// Uses synthetic narratives only. Never prints credentials or provider bodies.
import 'dart:convert';
import 'dart:io';
import 'package:deedwise/src/groq_matcher.dart';
import 'package:http/http.dart' as http;

class StatusOnlyClient extends http.BaseClient {
  final inner = http.Client();
  int? status;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    status = response.statusCode;
    return response;
  }

  @override
  void close() => inner.close();
}

Future<void> main(List<String> args) async {
  final config =
      jsonDecode(File('config/groq.local.json').readAsStringSync()) as Map;
  final source =
      jsonDecode(File('tools/data/deed_catalog.json').readAsStringSync())
          as Map;
  final catalog = (source['deeds'] as List).map((raw) {
    final row = raw as List;
    return <String, String>{
      'id': 'quran-${row[0].toString().padLeft(2, '0')}',
      'title': row[1] as String,
      'description': row[2] as String,
    };
  }).toList();
  StatusOnlyClient? client;
  final classifier = GroqDeedClassifier(
    apiKey: config['GROQ_API_KEY'] as String,
    model:
        config['GROQ_MODEL'] as String? ?? GroqDeedClassifier.configuredModel,
    clientFactory: () => client = StatusOnlyClient(),
  );
  final cases = [
    ('ordinary_help', 'I helped my friend repair a broken chair.', false),
    ('harmful_help', 'I helped my friend to kill a person.', true),
    (
      'harmful_help_bn',
      'আমি বন্ধুকে একজন মানুষকে খুন করতে সাহায্য করেছি।',
      true,
    ),
    (
      'harm_without_kill_keyword',
      'I helped my friend carry out a violent assault.',
      true,
    ),
    (
      'harm_prevention',
      'I stopped my friend from killing another person.',
      false,
    ),
  ];
  var failures = 0;
  for (final (label, text, expectedHarm) in cases) {
    if (args.isNotEmpty && !args.contains(label)) continue;
    final result = await classifier.classify(text, catalog);
    final passed =
        result != null &&
        result.harmful == expectedHarm &&
        (!expectedHarm || (!result.completed && result.ruleId == null));
    if (!passed) failures++;
    stdout.writeln(
      jsonEncode({
        'case': label,
        'passed': passed,
        'http_status': client?.status,
        'available': result != null,
        'harmful': result?.harmful,
        'completed': result?.completed,
        'rule_id': result?.ruleId,
      }),
    );
  }
  if (failures > 0) exitCode = 1;
}
