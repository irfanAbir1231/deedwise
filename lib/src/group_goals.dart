part of '../main.dart';

enum GoalMetric { completions, days, donation, minutes, meals, people }

extension GoalMetricLabel on GoalMetric {
  String get label => switch (this) {
    GoalMetric.completions => 'Completions',
    GoalMetric.days => 'Days practised',
    GoalMetric.donation => 'BDT donated',
    GoalMetric.minutes => 'Minutes spent',
    GoalMetric.meals => 'Meals shared',
    GoalMetric.people => 'People helped (reported)',
  };
  bool get whole => this != GoalMetric.donation && this != GoalMetric.minutes;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String goalNumber(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

// Optional quantities are offered only where the catalog deed supports them.
Set<GoalMetric> metricsForDeed(String id) {
  final n = int.tryParse(id.replaceFirst('quran-', ''));
  return {
    GoalMetric.completions,
    GoalMetric.days,
    if ([3, 16, 20].contains(n)) GoalMetric.donation,
    if ([
      1,
      2,
      6,
      11,
      12,
      13,
      14,
      15,
      17,
      18,
      19,
      20,
      22,
      26,
      36,
      42,
      43,
      48,
    ].contains(n))
      GoalMetric.minutes,
    if (n == 14) GoalMetric.meals,
    if ([
      11,
      12,
      13,
      14,
      15,
      17,
      18,
      19,
      20,
      22,
      37,
      38,
      43,
      48,
      49,
    ].contains(n))
      GoalMetric.people,
  };
}

class GroupProgress {
  final GroupData group;
  final List<DeedEntry> entries;
  GroupProgress(this.group, Iterable<DeedEntry> entries)
    : entries = entries.toList();
  List<DeedEntry> get shared => entries
      .where((e) => group.shared.containsKey(e.id) && group.accepts(e))
      .toList();
  double target(GoalMetric metric) =>
      group.targets[metric]! *
      (group.challengeFrequency == 'daily'
          ? group.end.difference(group.start).inDays + 1
          : 1);
  double total(GoalMetric metric, {String? member, DateTime? day}) {
    double sum = 0;
    final days = <DateTime>{};
    bool inRange(DateTime date) =>
        !dateOnly(date).isBefore(dateOnly(group.start)) &&
        !dateOnly(date).isAfter(dateOnly(group.end)) &&
        (day == null || sameDay(date, day));
    for (final e in shared) {
      if (!inRange(e.date) ||
          (member != null && (group.sharedBy[e.id] ?? 'You') != member) ||
          !metricsForDeed(e.template.id).contains(metric)) {
        continue;
      }
      days.add(dateOnly(e.date));
      sum += metric == GoalMetric.completions
          ? e.repetitions
          : group.sharedQuantities[e.id]?[metric] ?? 0;
    }
    for (final event in group.events) {
      // Linked events are presentation-only references to the shared records above.
      if (event.linkedEntryIds.isNotEmpty ||
          event.deedId == null ||
          !group.selectedDeedIds.contains(event.deedId) ||
          !inRange(event.date) ||
          (member != null && event.member != member) ||
          !metricsForDeed(event.deedId!).contains(metric)) {
        continue;
      }
      days.add(dateOnly(event.date));
      sum += event.value(metric);
    }
    return metric == GoalMetric.days ? days.length.toDouble() : sum;
  }
}

class GroupGoalStats extends StatelessWidget {
  final GroupData group;
  const GroupGoalStats(this.group, {super.key});
  @override
  Widget build(BuildContext context) {
    final progress = GroupProgress(group, store.entries);
    final members = group.goalPerMember
        ? group.members
              .where(
                (m) =>
                    group.challengeParticipants.contains(m) ||
                    (m == 'You' && group.optedIn),
              )
              .toList()
        : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.goalPerMember
              ? 'Target for each participating member'
              : 'Target for the whole group',
          style: const TextStyle(color: muted),
        ),
        if (group.goalPerMember && members.isEmpty)
          const Text('Join to start tracking your target.'),
        for (final member
            in group.goalPerMember ? members : <String?>[null]) ...[
          if (member != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                member,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          for (final metric in group.targets.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label),
                    const SizedBox(height: 6),
                    Text(
                      '${goalNumber(progress.total(metric, member: member))} / ${goalNumber(progress.target(metric))}',
                      style: editorial(28),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          (progress.total(metric, member: member) /
                                  progress.target(metric))
                              .clamp(0.0, 1.0),
                    ),
                    if (group.challengeFrequency == 'daily')
                      Text(
                        'Today: ${goalNumber(progress.total(metric, member: member, day: today))} / ${goalNumber(group.targets[metric]!)}',
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (group.targets.containsKey(GoalMetric.people))
          const Text(
            'Reported counts may include repeat recipients; these are not unique people.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
      ],
    );
  }
}

// The same form is used before creation and when an owner manages the goal.
class GroupGoalForm extends StatefulWidget {
  final GroupData group;
  final VoidCallback onSave;
  final String buttonLabel;
  const GroupGoalForm(
    this.group, {
    super.key,
    required this.onSave,
    this.buttonLabel = 'Save challenge',
  });
  @override
  State<GroupGoalForm> createState() => _GroupGoalFormState();
}

class _GroupGoalFormState extends State<GroupGoalForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late Set<String> deeds;
  late Set<GoalMetric> metrics;
  late Map<GoalMetric, TextEditingController> targets;
  late bool perMember;
  late DateTime start, end;
  String query = '';
  bool get locked =>
      widget.group.shared.isNotEmpty || widget.group.events.isNotEmpty;
  Set<GoalMetric> get available => deeds.expand(metricsForDeed).toSet();
  @override
  void initState() {
    super.initState();
    final g = widget.group;
    deeds = g.challengeTitle == null ? {} : {...g.selectedDeedIds};
    metrics = g.challengeTitle == null
        ? {GoalMetric.completions}
        : {...g.targets.keys};
    targets = {
      for (final m in GoalMetric.values)
        m: TextEditingController(
          text: goalNumber(
            (g.targets[m] ?? 1) *
                (g.challengeFrequency == 'daily'
                    ? g.end.difference(g.start).inDays + 1
                    : 1),
          ),
        ),
    };
    title = TextEditingController(text: g.challengeTitle ?? '');
    perMember = g.goalPerMember;
    start = g.start;
    end = g.end;
  }

  @override
  void dispose() {
    title.dispose();
    for (final c in targets.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Goal title'),
        TextFormField(
          controller: title,
          maxLength: 80,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter a goal title.' : null,
        ),
        const FieldLabel('Choose from the 50 deeds'),
        if (locked)
          const NoteBox(
            'Deeds, fields, scope and dates stay fixed after contributions begin. You can adjust the targets.',
          ),
        TextField(
          decoration: const InputDecoration(hintText: 'Search deeds'),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        SizedBox(
          height: 230,
          child: ListView(
            children: [
              for (final t in templates.where(
                (t) => t.title.toLowerCase().contains(query),
              ))
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.title),
                  value: deeds.contains(t.id),
                  onChanged: locked
                      ? null
                      : (v) => setState(() {
                          v == true ? deeds.add(t.id) : deeds.remove(t.id);
                          metrics.removeWhere((m) => !available.contains(m));
                        }),
                ),
            ],
          ),
        ),
        const FieldLabel('Show and track only these fields'),
        for (final metric in GoalMetric.values.where(available.contains)) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(metric.label),
            value: metrics.contains(metric),
            onChanged: locked
                ? null
                : (v) => setState(() {
                    v == true ? metrics.add(metric) : metrics.remove(metric);
                  }),
          ),
          if (metrics.contains(metric))
            TextFormField(
              controller: targets[metric],
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.numberWithOptions(
                decimal: !metric.whole,
              ),
              decoration: InputDecoration(labelText: '${metric.label} target'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null ||
                    !n.isFinite ||
                    n <= 0 ||
                    n > 100000000 ||
                    (metric.whole && n != n.roundToDouble())) {
                  return 'Enter a positive ${metric.whole ? 'whole ' : ''}number.';
                }
                if (metric == GoalMetric.days &&
                    n > end.difference(start).inDays + 1) {
                  return 'Target exceeds the number of days.';
                }
                return null;
              },
            ),
        ],
        const FieldLabel('Who is the target for?'),
        DropdownButtonFormField<bool>(
          isExpanded: true,
          initialValue: perMember,
          items: const [
            DropdownMenuItem(value: false, child: Text('The whole group')),
            DropdownMenuItem(
              value: true,
              child: Text(
                'Each participating member',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: locked ? null : (v) => setState(() => perMember = v!),
        ),
        const FieldLabel('Date range'),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: Text('${shortDate(start)} - ${shortDate(end)}'),
          onPressed: locked
              ? null
              : () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(today.year - 1),
                    lastDate: today.add(const Duration(days: 730)),
                    initialDateRange: DateTimeRange(start: start, end: end),
                  );
                  if (range != null) {
                    setState(() {
                      start = range.start;
                      end = range.end;
                    });
                  }
                },
        ),
        const Section('Goal preview'),
        Text(
          '${deeds.length} selected deeds. ${perMember ? 'Each participating member' : 'The whole group'}, ${shortDate(start)} - ${shortDate(end)}.',
        ),
        for (final m in metrics)
          Text(
            '${m.label}: 0 / ${targets[m]!.text}',
            style: const TextStyle(color: green),
          ),
        const SizedBox(height: 16),
        const NoteBox(
          'Only accepted deeds you explicitly share count. Quantities are self-reported. Participation points are separate from goal progress.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.group.closed
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  if (deeds.isEmpty || metrics.isEmpty) {
                    toast(
                      context,
                      'Select at least one deed and one progress field.',
                    );
                    return;
                  }
                  final g = widget.group;
                  g.challengeTitle = title.text.trim();
                  g.goalDeedIds = {...deeds};
                  g.goalTargets = {
                    for (final m in metrics) m: double.parse(targets[m]!.text),
                  };
                  g.challengeAction = templates
                      .where((t) => deeds.contains(t.id))
                      .map((t) => t.title)
                      .join('\n');
                  g.goalPerMember = perMember;
                  g.start = start;
                  g.end = end;
                  g.challengeFrequency = 'total';
                  g.optedIn = true;
                  g.challengeParticipants.add('You');
                  widget.onSave();
                },
          child: Text(widget.buttonLabel),
        ),
      ],
    ),
  );
}

String? validateGoalQuantity(String? value, GoalMetric metric) {
  if (value == null || value.trim().isEmpty) return null;
  final n = double.tryParse(value);
  return n == null ||
          !n.isFinite ||
          n < 0 ||
          n > 100000000 ||
          (metric.whole && n != n.roundToDouble())
      ? 'Enter a non-negative ${metric.whole ? 'whole ' : ''}number.'
      : null;
}
