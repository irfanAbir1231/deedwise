// Readiness checks only: no user records, test accounts or mutations.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final config =
      jsonDecode(File('config/supabase.local.json').readAsStringSync()) as Map;
  final url = config['SUPABASE_URL'] as String;
  final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
  final client = SupabaseClient(url, key);
  try {
    final status = await client.rpc('backend_status') as Map;
    final response = await http.get(
      Uri.parse('$url/auth/v1/settings'),
      headers: {'apikey': key},
    );
    final auth = jsonDecode(response.body) as Map;
    var anonymousRpcBlocked = false;
    try {
      await client.rpc('preview_group_invite', params: {'p_token': 'invalid'});
    } on PostgrestException catch (e) {
      anonymousRpcBlocked = e.code == '42501';
    }
    stdout.writeln(
      jsonEncode({
        'schema_version': status['schema_version'],
        'security_revision': status['security_revision'],
        'google_enabled': auth['external']?['google'],
        'auth_settings_status': response.statusCode,
        'anonymous_group_rpc_blocked': anonymousRpcBlocked,
      }),
    );
  } on PostgrestException catch (e) {
    stdout.writeln(jsonEncode({'schema_ready': false, 'code': e.code}));
    exitCode = 1;
  } catch (_) {
    stdout.writeln(jsonEncode({'connection_ready': false}));
    exitCode = 1;
  } finally {
    await client.dispose();
  }
}
