part of '../main.dart';

class DeedTemplate {
  final String id, title, category, description;
  final int points;
  final IconData icon;
  final Color tint;
  final String? unit;
  const DeedTemplate(
    this.id,
    this.title,
    this.category,
    this.description,
    this.points,
    this.icon,
    this.tint, {
    this.unit,
  });
}

// Presentation styles and sample point values; selectable deeds come from the
// supplied catalog below, not from these category definitions.
const activityCategories = [
  DeedTemplate(
    'kindness',
    'Faith and character',
    'Faith & character',
    'Worship, gratitude, patience, sincerity and good conduct.',
    10,
    Icons.wb_sunny_outlined,
    Color(0xFFF6EDD9),
  ),
  DeedTemplate(
    'charity',
    'Charity',
    'Charity',
    'Support someone in need with an amount that feels right for you.',
    15,
    Icons.volunteer_activism_outlined,
    Color(0xFFE8EEE3),
    unit: 'BDT donated',
  ),
  DeedTemplate(
    'learn',
    'Learning',
    'Learning',
    'Spend a few intentional minutes learning something beneficial.',
    10,
    Icons.menu_book_outlined,
    Color(0xFFEBEDF5),
    unit: 'Minutes',
  ),
  DeedTemplate(
    'help',
    'Service',
    'Service',
    'Offer your time to a neighbor, a family member, or your community.',
    15,
    Icons.handshake_outlined,
    Color(0xFFF4E8DE),
    unit: 'Volunteer minutes',
  ),
  DeedTemplate(
    'meals',
    'Feeding people',
    'Charity',
    'Prepare or share a meal with someone who needs one.',
    15,
    Icons.restaurant_outlined,
    Color(0xFFF3EADB),
    unit: 'Meals',
  ),
  DeedTemplate(
    'connect',
    'Family and community',
    'Family & community',
    'Reach out to someone you haven’t spoken to in a while. Listen with care.',
    10,
    Icons.favorite_border_rounded,
    Color(0xFFF2E6E5),
  ),
  DeedTemplate(
    'environment',
    'Environment',
    'Environment',
    'Leave a shared place a little better than you found it.',
    10,
    Icons.eco_outlined,
    Color(0xFFE5EDE4),
  ),
];
final templates = List<DeedTemplate>.unmodifiable(sourceDeedTemplates());

DeedTemplate catalogDeed(int number) => templates[number - 1];
const unclassifiedTemplate = DeedTemplate(
  'personal',
  'Personal entry',
  'Unclassified',
  'An activity written in your own words.',
  0,
  Icons.edit_note_rounded,
  sage,
);

class DeedEntry {
  String id, title, note;
  DeedTemplate template;
  DateTime date;
  double quantity;
  int repetitions;
  bool custom;
  ReviewState reviewState;
  double? similarity;
  String? matchedRuleId;
  String? nearestRuleId;
  String matchingNote;
  int? reviewedPoints;
  int revision;
  String? localPhoto;
  DeedEntry({
    required this.id,
    required this.title,
    required this.template,
    required this.date,
    this.note = '',
    this.quantity = 0,
    this.repetitions = 1,
    this.custom = false,
    this.reviewState = ReviewState.approved,
    this.similarity,
    this.matchedRuleId,
    this.nearestRuleId,
    this.matchingNote = '',
    this.reviewedPoints,
    this.revision = 1,
    this.localPhoto,
  });
  bool get eligibleForPoints =>
      DeedModeration.check(title) == null &&
      !custom &&
      (reviewState == ReviewState.matched ||
          reviewState == ReviewState.approved);
  int get basePoints =>
      eligibleForPoints ? reviewedPoints ?? template.points : 0;
}

class DeedPlan {
  String id, recurrence;
  DeedTemplate template;
  DateTime date;
  TimeOfDay time;
  bool reminder, skipped;
  String? completionId;
  DeedPlan({
    required this.id,
    required this.template,
    required this.date,
    this.recurrence = 'Once',
    this.time = const TimeOfDay(hour: 9, minute: 0),
    this.reminder = false,
    this.skipped = false,
    this.completionId,
  });
}

class Reflection {
  String id, title, text;
  DateTime date;
  String? deedId;
  Reflection(this.id, this.title, this.text, this.date, {this.deedId});
}

class GroupData {
  String id, name, description, code;
  bool owner, optedIn = false, closed = false;
  List<String> members;
  Map<String, String> shared = {};
  Map<String, String> sharedBy = {};
  String? challengeTitle;
  Set<String> goalDeedIds = {};
  Map<GoalMetric, double> goalTargets = {};
  bool goalPerMember = false;
  final Map<String, Map<GoalMetric, double>> sharedQuantities = {};
  bool accepts(DeedEntry entry) =>
      entry.eligibleForPoints &&
      selectedDeedIds.contains(entry.template.id) &&
      !dateOnly(entry.date).isBefore(dateOnly(start)) &&
      !dateOnly(entry.date).isAfter(dateOnly(end));
  Set<String> get selectedDeedIds => goalDeedIds.isNotEmpty
      ? goalDeedIds
      : templates
            .where((t) => t.title == challengeAction)
            .map((t) => t.id)
            .toSet();
  Map<GoalMetric, double> get targets => goalTargets.isNotEmpty
      ? goalTargets
      : {
          GoalMetric.values.firstWhere(
            (m) => m.name == challengeUnit,
            orElse: () => GoalMetric.completions,
          ): challengeTarget
              .toDouble(),
        };
  String challengeOccasion = 'Custom';
  String challengeAction = catalogDeed(43).title;
  String challengeUnit = 'deeds';
  int challengeTarget = 1;
  String challengeFrequency = 'total';
  final Set<String> challengeParticipants = {};
  DateTime start = today, end = today.add(const Duration(days: 7));
  List<ImpactEvent> events = [];
  GroupData(
    this.id,
    this.name,
    this.description,
    this.code,
    this.owner,
    this.members, {
    this.challengeTitle,
  });
}

class ImpactEvent {
  String title;
  String? deedId, member;
  DateTime date;
  Set<String> linkedEntryIds;
  double completions;
  double donation, minutes, meals, people;
  double value(GoalMetric metric) => switch (metric) {
    GoalMetric.completions => completions,
    GoalMetric.days => 1,
    GoalMetric.donation => donation,
    GoalMetric.minutes => minutes,
    GoalMetric.meals => meals,
    GoalMetric.people => people,
  };
  ImpactEvent(
    this.title, {
    this.donation = 0,
    this.minutes = 0,
    this.meals = 0,
    this.people = 0,
    this.completions = 0,
    this.deedId,
    this.member,
    DateTime? date,
    Set<String>? linkedEntryIds,
  }) : date = date ?? today,
       linkedEntryIds = linkedEntryIds ?? {};
}

class PersonalGoal {
  DeedTemplate template;
  int target;
  DateTime start, end;
  PersonalGoal(this.template, this.target, this.start, this.end);
}

class DeedStore extends ChangeNotifier {
  String name = 'Ayesha';
  String budget = 'No preference', availableTime = '15 minutes';
  Set<String> interests = {
    'Faith & character',
    'Charity',
    'Family & community',
  };
  bool reminders = false, challengeAccepted = false, tourSeen = false;
  int challengeIndex = 12;
  bool demoAdmin = false;
  int dailyCap = 50;
  // Pilot cosine cutoff, not an accuracy percentage. Calibrate on held-out data.
  double matchThreshold = .80;
  final reviewRequests = <DeedReviewRequest>[];
  final matchingRules = sourceDeedRules();
  final entries = <DeedEntry>[];
  final plans = <DeedPlan>[];
  final journals = <Reflection>[];
  final groups = <GroupData>[];
  PersonalGoal? goal;
  String? challengeEntryId;
  final Set<DateTime> participationDays = {};
  DeedStore() {
    DeedEntry sample(
      String id,
      int number,
      int daysAgo, {
      double quantity = 0,
    }) {
      final deed = catalogDeed(number);
      final rule = matchingRules[number - 1];
      return DeedEntry(
        id: id,
        title: deed.title,
        template: deed,
        date: today.subtract(Duration(days: daysAgo)),
        note: rule.examples.first,
        quantity: quantity,
        matchedRuleId: rule.id,
        reviewedPoints: deed.points,
        // Seed history is approved demo content, not a fabricated model result.
        reviewState: ReviewState.approved,
      );
    }

    entries.addAll([
      sample('seed1', 21, 0),
      sample('seed2', 16, 0, quantity: 200),
      sample('history1', 14, 1, quantity: 3),
      sample('history2', 19, 2, quantity: 30),
      sample('history3', 11, 3),
      sample('history4', 42, 4, quantity: 20),
      sample('history5', 27, 5),
      sample('history6', 45, 6),
    ]);
    participationDays.addAll(
      List.generate(7, (i) => today.subtract(Duration(days: i))),
    );
    plans.addAll([
      DeedPlan(
        id: 'p1',
        template: catalogDeed(2),
        date: today,
        time: const TimeOfDay(hour: 18, minute: 0),
        recurrence: 'Daily',
        reminder: true,
      ),
      DeedPlan(
        id: 'p2',
        template: catalogDeed(11),
        date: today,
        time: const TimeOfDay(hour: 20, minute: 30),
      ),
      DeedPlan(
        id: 'p3',
        template: catalogDeed(14),
        date: today.add(const Duration(days: 1)),
      ),
    ]);
    journals.add(
      Reflection(
        'r1',
        catalogDeed(11).title,
        'I cared for my mother and spoke respectfully to my father. Taking time for them helped me practise kindness and respect in our family.',
        today.subtract(const Duration(days: 3)),
        deedId: 'history3',
      ),
    );
    groups.add(
      GroupData(
          'g1',
          'Circle of kindness',
          'Practising the 50 good deeds together through everyday actions.',
          'KIND26',
          false,
          ['You', 'Sara', 'Omar', 'Nadia'],
          challengeTitle: catalogDeed(14).title,
        )
        ..challengeAction = catalogDeed(14).title
        ..challengeUnit = 'meals'
        ..challengeTarget = 10
        ..goalDeedIds = {catalogDeed(14).id}
        ..goalTargets = {GoalMetric.meals: 100, GoalMetric.people: 60}
        ..events.add(
          ImpactEvent(
            catalogDeed(14).title,
            deedId: catalogDeed(14).id,
            meals: 100,
            people: 60,
          ),
        ),
    );
    goal = PersonalGoal(
      catalogDeed(21),
      7,
      today.subtract(const Duration(days: 3)),
      today.add(const Duration(days: 3)),
    );
  }
  void changed() => notifyListeners();
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (identical(this, store)) localData.scheduleSave();
  }
  List<DeedEntry> onDay(DateTime day) =>
      entries.where((e) => sameDay(e.date, day)).toList();
  int pointsOn(DateTime day) =>
      math.min(dailyCap, onDay(day).fold(0, (sum, e) => sum + e.basePoints));
  int pointsFor(DeedEntry entry) {
    var remaining = dailyCap;
    for (final e in onDay(entry.date)) {
      final points = math.min(remaining, e.basePoints);
      if (e.id == entry.id) return points;
      remaining -= points;
    }
    return 0;
  }

  int get streak {
    var day = participationDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var count = 0;
    while (participationDays.contains(day) &&
        entries.any((e) => sameDay(e.date, day) && e.eligibleForPoints)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get goalCount => goal == null
      ? 0
      : entries
            .where(
              (e) =>
                  e.eligibleForPoints &&
                  e.template.id == goal!.template.id &&
                  !e.date.isBefore(goal!.start) &&
                  !e.date.isAfter(goal!.end),
            )
            .fold(0, (sum, entry) => sum + entry.repetitions);
  String nextId() => DateTime.now().microsecondsSinceEpoch.toString();
  void save(DeedEntry entry, {DeedPlan? plan, bool dailyChallenge = false}) {
    final issue = DeedModeration.check(entry.title);
    if (issue != null) throw FormatException(issue);
    // A second submit from a plan or daily challenge updates its canonical deed.
    final canonicalId =
        plan?.completionId ?? (dailyChallenge ? challengeEntryId : null);
    if (canonicalId != null && entries.any((e) => e.id == canonicalId)) {
      entry.id = canonicalId;
    }
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    if (sameDay(entry.date, today) && entry.eligibleForPoints) {
      participationDays.add(today);
    }
    for (final group in groups.where(
      (g) => !g.closed && g.shared.containsKey(entry.id),
    )) {
      if (!group.accepts(entry)) {
        group.shared.remove(entry.id);
        group.sharedBy.remove(entry.id);
        group.sharedQuantities.remove(entry.id);
      } else {
        group.shared[entry.id] = entry.title;
      }
    }
    if (plan != null) {
      plan.completionId = entry.id;
      if (plan.recurrence != 'Once') {
        final nextDate = plan.date.add(
          Duration(days: plan.recurrence == 'Daily' ? 1 : 7),
        );
        if (!plans.any(
          (p) => p.template.id == plan.template.id && sameDay(p.date, nextDate),
        )) {
          plans.add(
            DeedPlan(
              id: nextId(),
              template: plan.template,
              date: nextDate,
              recurrence: plan.recurrence,
              time: plan.time,
              reminder: plan.reminder,
            ),
          );
        }
      }
    }
    if (dailyChallenge) challengeEntryId = entry.id;
    for (final request in reviewRequests.where(
      (r) =>
          r.deedId == entry.id &&
          r.state == RequestState.pending &&
          r.revision != entry.revision,
    )) {
      request.state = RequestState.superseded;
    }
    notifyListeners();
  }

  DeedReviewRequest requestReview(DeedEntry entry, String reason) {
    final existing = reviewRequests
        .where(
          (r) =>
              r.deedId == entry.id &&
              r.revision == entry.revision &&
              r.state == RequestState.pending,
        )
        .firstOrNull;
    if (existing != null) return existing;
    final request = DeedReviewRequest(
      nextId(),
      entry.id,
      entry.revision,
      entry.title,
      reason,
      today,
    );
    reviewRequests.add(request);
    entry.reviewState = ReviewState.pending;
    notifyListeners();
    return request;
  }

  bool resolveReview(
    DeedReviewRequest request, {
    required bool accept,
    required String response,
    DeedTemplate? category,
    int points = 0,
    String criterion = '',
  }) {
    if (request.state != RequestState.pending) return false;
    final entry = entries
        .where((e) => e.id == request.deedId && e.revision == request.revision)
        .firstOrNull;
    if (entry == null) {
      request.state = RequestState.superseded;
      notifyListeners();
      return false;
    }
    if (response.trim().isEmpty ||
        (accept &&
            (category == null ||
                points < 1 ||
                points > dailyCap ||
                criterion.trim().isEmpty))) {
      return false;
    }
    request.state = accept ? RequestState.approved : RequestState.rejected;
    request.response = response.trim();
    entry.reviewState = accept ? ReviewState.approved : ReviewState.rejected;
    entry.custom = !accept;
    entry.reviewedPoints = accept ? points : 0;
    if (accept) {
      entry.template = category!;
      final rule = MatchingRule(
        'review-${request.id}',
        criterion.trim(),
        '',
        [criterion.trim()],
        category,
        points,
        sourceNote: 'Added through admin review.',
      );
      matchingRules.add(rule);
      entry.matchedRuleId = rule.id;
    }
    save(entry);
    return true;
  }

  void delete(DeedEntry entry) {
    if (entry.localPhoto != null) unawaited(local_media.remove(entry.localPhoto!));
    for (final request in reviewRequests.where(
      (r) => r.deedId == entry.id && r.state == RequestState.pending,
    )) {
      request.state = RequestState.superseded;
    }
    entries.removeWhere((e) => e.id == entry.id);
    for (final g in groups.where((g) => !g.closed)) {
      g.shared.remove(entry.id);
      g.sharedBy.remove(entry.id);
      g.sharedQuantities.remove(entry.id);
    }
    for (final p in plans.where((p) => p.completionId == entry.id)) {
      p.completionId = null;
    }
    if (challengeEntryId == entry.id) challengeEntryId = null;
    for (final j in journals.where((j) => j.deedId == entry.id)) {
      j.deedId = null;
    }
    notifyListeners();
  }
}
