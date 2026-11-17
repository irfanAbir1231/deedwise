import 'dart:convert';
import 'dart:math';
import 'package:supabase/supabase.dart';

class BackendConfig {
  final String url, publishableKey;
  const BackendConfig({this.url = '', this.publishableKey = ''});
  static const environment = BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;
  void validate() {
    if (!configured) {
      throw const FormatException('Supabase connection is incomplete.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Use an HTTPS Supabase project URL.');
    }
    if (publishableKey.startsWith('sb_secret_')) {
      throw const FormatException('Never put a secret key in the app.');
    }
    if (!publishableKey.startsWith('sb_publishable_')) {
      try {
        final parts = publishableKey.split('.');
        final claims =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
                )
                as Map;
        if (claims['role'] != 'anon') {
          throw const FormatException(
            'Use a publishable or legacy anon key only.',
          );
        }
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('Invalid public project key.');
      }
    }
  }
}

String newOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CloudFailure implements Exception {
  final String message;
  const CloudFailure(this.message);
  @override
  String toString() => message;
}

class CloudProfile {
  final String id, name;
  const CloudProfile(this.id, this.name);
  factory CloudProfile.fromJson(Map<String, dynamic> json) =>
      CloudProfile(json['id'] as String, json['display_name'] as String);
}

abstract interface class ProfileRepository {
  Future<CloudProfile> ensure({String? name});
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient client;
  SupabaseProfileRepository(this.client);
  @override
  Future<CloudProfile> ensure({String? name}) async => CloudProfile.fromJson(
    Map<String, dynamic>.from(
      await client.rpc('ensure_profile', params: {'p_display_name': name})
          as Map,
    ),
  );
}

class CloudGroup {
  final String id, name, description, ownerId;
  final bool closed;
  final Map<String, dynamic> goal;
  final List<String> memberIds;
  const CloudGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.goal,
    required this.memberIds,
    this.closed = false,
  });
  factory CloudGroup.fromJson(Map<String, dynamic> json) => CloudGroup(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    ownerId: json['owner_id'],
    closed: json['closed'] as bool? ?? false,
    goal: Map<String, dynamic>.from(json['goal'] as Map),
    memberIds: (json['group_members'] as List? ?? [])
        .map((m) => m['user_id'] as String)
        .toList(),
  );
}

class CloudMember {
  final String id, name, role;
  const CloudMember(this.id, this.name, this.role);
  factory CloudMember.fromJson(Map<String, dynamic> json) => CloudMember(
    json['user_id'],
    (json['profiles'] as Map?)?['display_name'] as String? ?? 'Member',
    json['role'],
  );
}

class CloudInvite {
  final String id;
  final String? token;
  final DateTime expiresAt;
  final bool revoked, mine;
  CloudInvite.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      token = json['token'],
      expiresAt = DateTime.parse(json['expires_at']),
      revoked = json['revoked'] as bool? ?? false,
      mine = json['mine'] as bool? ?? true;
}

class InvitePreview {
  final String groupId, name, description;
  final int memberCount;
  final bool alreadyMember, full;
  InvitePreview.fromJson(Map<String, dynamic> json)
    : groupId = json['group_id'],
      name = json['name'],
      description = json['description'],
      memberCount = (json['member_count'] as num).toInt(),
      alreadyMember = json['already_member'],
      full = json['full'];
}

abstract interface class GroupRepository {
  Future<List<CloudGroup>> list();
  Future<CloudGroup> get(String id);
  Future<String> create({
    required String operationId,
    required String name,
    required String description,
    required Map<String, dynamic> goal,
  });
  Future<List<CloudMember>> members(String groupId);
  Future<CloudInvite> invite(String groupId);
  Future<List<CloudInvite>> invites(String groupId);
  Future<void> revoke(String inviteId);
  Future<InvitePreview> preview(String token);
  Future<String> accept(String token);
  Future<void> removeMember(String groupId, String userId);
}

class SupabaseGroupRepository implements GroupRepository {
  final SupabaseClient client;
  SupabaseGroupRepository(this.client);
  static const projection =
      'id,name,description,owner_id,goal,closed,group_members(user_id)';
  Map<String, dynamic> _checked(dynamic data) {
    final json = Map<String, dynamic>.from(data as Map);
    if (json['error'] is String) throw CloudFailure(json['error']);
    return json;
  }

  @override
  Future<List<CloudGroup>> list() async {
    final rows = await client
        .from('groups')
        .select(projection)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(CloudGroup.fromJson).toList();
  }

  @override
  Future<CloudGroup> get(String id) async => CloudGroup.fromJson(
    await client.from('groups').select(projection).eq('id', id).single(),
  );
  @override
  Future<String> create({
    required String operationId,
    required String name,
    required String description,
    required Map<String, dynamic> goal,
  }) async =>
      await client.rpc(
            'create_group',
            params: {
              'p_request_id': operationId,
              'p_name': name,
              'p_description': description,
              'p_goal': goal,
            },
          )
          as String;
  @override
  Future<List<CloudMember>> members(String groupId) async {
    final rows = await client
        .from('group_members')
        .select(
          'user_id,role,profiles!group_members_user_id_fkey(display_name)',
        )
        .eq('group_id', groupId)
        .order('joined_at');
    return rows.map(CloudMember.fromJson).toList();
  }

  @override
  Future<CloudInvite> invite(String groupId) async => CloudInvite.fromJson(
    _checked(
      await client.rpc('create_group_invite', params: {'p_group_id': groupId}),
    ),
  );
  @override
  Future<List<CloudInvite>> invites(String groupId) async {
    final rows =
        await client.rpc('list_group_invites', params: {'p_group_id': groupId})
            as List;
    return rows
        .map((r) => CloudInvite.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<void> revoke(String inviteId) async {
    await client.rpc('revoke_group_invite', params: {'p_invite_id': inviteId});
  }

  @override
  Future<InvitePreview> preview(String token) async => InvitePreview.fromJson(
    _checked(
      await client.rpc(
        'preview_group_invite',
        params: {'p_token': token.trim().toLowerCase()},
      ),
    ),
  );
  @override
  Future<String> accept(String token) async =>
      _checked(
            await client.rpc(
              'accept_group_invite',
              params: {'p_token': token.trim().toLowerCase()},
            ),
          )['group_id']
          as String;
  @override
  Future<void> removeMember(String groupId, String userId) async {
    await client.rpc(
      'remove_group_member',
      params: {'p_group_id': groupId, 'p_user_id': userId},
    );
  }
}
