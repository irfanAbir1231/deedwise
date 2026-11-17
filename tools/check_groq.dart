import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../lib/src/groq_matcher.dart';

class StatusClient extends http.BaseClient {
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
  final fields = (source['fields'] as List).cast<String>();
  final targets = (source['deeds'] as List).map((row) {
    final record = Map.fromIterables(fields, row as List);
    return <String, String>{
      'id': 'quran-${record['number'].toString().padLeft(2, '0')}',
      'title': record['label'] as String,
      'description': record['description'] as String,
    };
  }).toList();
  final client = StatusClient();
  final result = await GroqDeedClassifier(
    apiKey: config['GROQ_API_KEY'] as String,
    model:
        config['GROQ_MODEL'] as String? ?? GroqDeedClassifier.configuredModel,
    clientFactory: () => client,
  ).classify(args.isEmpty ? 'iv helped my friend' : args.join(' '), targets);
  final passed =
      result?.ruleId == 'quran-19' &&
      result?.completed == true &&
      (result?.confidence ?? 0) >= .8;
  // Never output credentials, request headers, or raw provider responses.
  stdout.writeln(
    jsonEncode({
      'http_status': client.status,
      'sample_passed': passed,
      'rule_id': result?.ruleId,
      'confidence': result?.confidence,
      'completed': result?.completed,
    }),
  );
  if (!passed) exitCode = 1;
}
