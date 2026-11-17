part of '../main.dart';

final localData = LocalData();

class LocalData {
  SharedPreferences? preferences;
  Timer? _timer;
  String? profilePhoto;
  bool introSeen = false;
  String? accountId;
  String scopedKey(String base) =>
      accountId == null ? base : '$base:$accountId';
  final _sessions =
      <
        String,
        ({
          List<DeedPlan> plans,
          List<Reflection> journals,
          List<GroupData> groups,
          PersonalGoal? goal,
        })
      >{};
  bool get ready => preferences != null;
  Future<void> initialize({String? forAccount}) async {
    accountId = forAccount;
    preferences = await SharedPreferences.getInstance();
    store.tourSeen = preferences!.getBool('tour_seen_v1') ?? false;
    introSeen = preferences!.getBool('intro_seen_v1') ?? false;
    profilePhoto = preferences!.getString(scopedKey('profile_photo_v1'));
    final snapshot = preferences!.getString(scopedKey('deeds_v1'));
    if (snapshot == null) return;
    try {
      final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
      final restored = (decoded['entries'] as List).map((raw) {
        final e = raw as Map<String, dynamic>;
        final template =
            [
              ...templates,
              ...activityCategories,
              unclassifiedTemplate,
            ].where((t) => t.id == e['template']).firstOrNull ??
            unclassifiedTemplate;
        return DeedEntry(
          id: e['id'],
          title: e['title'],
          template: template,
          date: DateTime.parse(e['date']),
          note: e['note'] ?? '',
          quantity: (e['quantity'] as num).toDouble(),
          repetitions: e['repetitions'],
          custom: e['custom'],
          reviewState: ReviewState.values.byName(e['state']),
          similarity: (e['similarity'] as num?)?.toDouble(),
          matchedRuleId: e['matchedRule'],
          nearestRuleId: e['nearestRule'],
          matchingNote: e['matchingNote'] ?? '',
          reviewedPoints: e['points'],
          revision: e['revision'],
          localPhoto: e['photo'],
        );
      }).toList();
      store.entries
        ..clear()
        ..addAll(restored);
      store.name = decoded['name'] ?? store.name;
      final personal = decoded['preferences'] as Map?;
      if (personal != null) {
        store.budget = personal['budget'] as String? ?? 'No preference';
        store.availableTime =
            personal['availableTime'] as String? ?? '15 minutes';
        store.interests = (personal['interests'] as List? ?? [])
            .cast<String>()
            .toSet();
        store.reminders = personal['reminders'] as bool? ?? false;
      }
      store.participationDays
        ..clear()
        ..addAll(
          (decoded['participationDays'] as List? ?? []).map(
            (d) => DateTime.parse(d as String),
          ),
        );
      store.reviewRequests
        ..clear()
        ..addAll(
          (decoded['reviews'] as List? ?? []).map((raw) {
            final r = raw as Map<String, dynamic>;
            return DeedReviewRequest(
                r['id'],
                r['deed'],
                r['revision'],
                r['narrative'],
                r['reason'],
                DateTime.parse(r['date']),
              )
              ..state = RequestState.values.byName(r['state'])
              ..response = r['response'];
          }),
        );
    } catch (_) {
      // Preserve the original snapshot for recovery instead of overwriting it.
      preferences = null;
    }
  }

  Future<void> switchAccount(String? userId) async {
    if (accountId == userId) return;
    if (!await flush()) {
      throw StateError('Could not save the current device data.');
    }
    _sessions[accountId ?? 'guest'] = (
      plans: [...store.plans],
      journals: [...store.journals],
      groups: [...store.groups],
      goal: store.goal,
    );
    store.entries.clear();
    store.reviewRequests.clear();
    store.participationDays.clear();
    store.plans.clear();
    store.journals.clear();
    store.groups.clear();
    store.goal = null;
    store.challengeEntryId = null;
    store.challengeAccepted = false;
    store.demoAdmin = false;
    store.name = '';
    store.reminders = false;
    store.interests = {};
    store.budget = 'No preference';
    store.availableTime = '15 minutes';
    final extra = _sessions[userId ?? 'guest'];
    if (extra != null) {
      store.plans.addAll(extra.plans);
      store.journals.addAll(extra.journals);
      store.groups.addAll(extra.groups);
      store.goal = extra.goal;
    }
    await initialize(forAccount: userId);
    if (!ready) throw StateError('Could not load this account’s device data.');
    store.changed();
  }

  Future<void> markTourSeen() async {
    await preferences?.setBool('tour_seen_v1', true);
  }

  Future<bool> markIntroSeen() async {
    final saved = await preferences?.setBool('intro_seen_v1', true) ?? false;
    if (saved) introSeen = true;
    return saved;
  }

  void scheduleSave() {
    if (!ready) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), () {
      unawaited(flush().catchError((Object _) => false));
    });
  }

  Future<bool> flush() async {
    _timer?.cancel();
    final p = preferences;
    if (p == null) return false;
    return p.setString(
      scopedKey('deeds_v1'),
      jsonEncode({
        'name': store.name,
        'preferences': {
          'budget': store.budget,
          'availableTime': store.availableTime,
          'interests': store.interests.toList(),
          'reminders': store.reminders,
        },
        'participationDays': store.participationDays
            .map((d) => d.toIso8601String())
            .toList(),
        'entries': store.entries
            .map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'template': e.template.id,
                'date': e.date.toIso8601String(),
                'note': e.note,
                'quantity': e.quantity,
                'repetitions': e.repetitions,
                'custom': e.custom,
                'state': e.reviewState.name,
                'similarity': e.similarity,
                'matchedRule': e.matchedRuleId,
                'nearestRule': e.nearestRuleId,
                'matchingNote': e.matchingNote,
                'points': e.reviewedPoints,
                'revision': e.revision,
                'photo': e.localPhoto,
              },
            )
            .toList(),
        'reviews': store.reviewRequests
            .map(
              (r) => {
                'id': r.id,
                'deed': r.deedId,
                'revision': r.revision,
                'narrative': r.narrative,
                'reason': r.reason,
                'date': r.date.toIso8601String(),
                'state': r.state.name,
                'response': r.response,
              },
            )
            .toList(),
      }),
    );
  }

  Future<void> setProfilePhoto(String? path) async {
    final previous = profilePhoto;
    final p = preferences;
    if (p == null) throw StateError('Local storage is unavailable.');
    final saved = path == null
        ? await p.remove(scopedKey('profile_photo_v1'))
        : await p.setString(scopedKey('profile_photo_v1'), path);
    if (!saved) throw StateError('Could not save the profile photo.');
    profilePhoto = path;
    if (previous != null && previous != path) {
      await local_media.remove(previous);
    }
    store.changed();
  }
}
