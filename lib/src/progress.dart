part of '../main.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int days = 7;
  @override
  Widget build(BuildContext context) {
    final start = today.subtract(Duration(days: days - 1));
    final entries = store.entries
        .where((e) => !e.date.isBefore(start) && !e.date.isAfter(today))
        .toList();
    return RootPage(
      title: 'Overview',
      subtitle: 'Your activity, goals and personal impact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('This week')),
              ButtonSegment(value: 30, label: Text('This month')),
            ],
            selected: {days},
            onSelectionChanged: (v) => setState(() => days = v.first),
          ),
          const SizedBox(height: 22),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Recorded activity'),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${entries.length}', style: editorial(49)),
                    const SizedBox(width: 12),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: Text(
                        'good deeds recorded',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final d = today.subtract(Duration(days: 6 - i));
                      final count = store.onDay(d).length;
                      final maxCount = List.generate(
                        7,
                        (n) => store
                            .onDay(today.subtract(Duration(days: n)))
                            .length,
                      ).fold(1, math.max);
                      return Expanded(
                        child: InkWell(
                          onTap: () => openPage(context, HistoryPage(day: d)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 8 + count / maxCount * 60,
                                  decoration: BoxDecoration(
                                    color: i == 6
                                        ? green
                                        : const Color(0xFFCEDBC6),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(7),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  weekNames[d.weekday - 1][0],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Daily activity · last 7 days',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          Section(
            'Summary',
            key: tourProgressKey,
            link: 'History',
            onTap: () => openPage(context, const HistoryPage()),
          ),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Metric(
                  '${List.generate(days, (i) => store.pointsOn(today.subtract(Duration(days: i)))).fold(0, (a, b) => a + b)}',
                  'Period points',
                  Icons.auto_awesome_outlined,
                ),
                Container(width: 1, height: 50, color: line),
                Metric(
                  '${store.streak} days',
                  'Current streak',
                  Icons.local_fire_department_outlined,
                  onTap: () => openPage(context, const StreakPage()),
                ),
              ],
            ),
          ),
          const Section('Current goal'),
          Surface(
            color: sage,
            onTap: () => openPage(context, const GoalPage()),
            child: store.goal == null
                ? Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Set a small, meaningful goal.',
                          style: editorial(23),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Goal progress', color: green),
                      const SizedBox(height: 14),
                      Text(store.goal!.template.title, style: editorial(25)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (store.goalCount / store.goal!.target).clamp(
                            0,
                            1,
                          ),
                          minHeight: 6,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${store.goalCount} of ${store.goal!.target} completions · Until ${shortDate(store.goal!.end)}',
                        style: const TextStyle(fontSize: 11, color: green),
                      ),
                    ],
                  ),
          ),
          const Section('Details'),
          Surface(
            key: tourProgressDetailsKey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Column(
              children: [
                reviewLink(
                  context,
                  Icons.pie_chart_outline,
                  'Category insights',
                  'The good you return to',
                  const InsightsPage(),
                ),
                const Divider(height: 1),
                reviewLink(
                  context,
                  Icons.volunteer_activism_outlined,
                  'Personal impact',
                  'Your contributions, in their own units',
                  const PersonalImpactPage(),
                ),
                const Divider(height: 1),
                reviewLink(
                  context,
                  Icons.edit_note_rounded,
                  'Private journal',
                  'A little space to reflect',
                  const JournalPage(),
                ),
                const Divider(height: 1),
                reviewLink(
                  context,
                  Icons.history,
                  'Deed history',
                  'Revisit your recorded moments',
                  const HistoryPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget reviewLink(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
  Widget page,
) => ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(icon, color: green, size: 23),
  title: Text(
    title,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  ),
  subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
  trailing: const Icon(Icons.chevron_right, size: 18, color: muted),
  onTap: () => openPage(context, page),
);

class HistoryPage extends StatefulWidget {
  final DateTime? day;
  final String? category;
  const HistoryPage({super.key, this.day, this.category});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? day;
  late String category;
  @override
  void initState() {
    super.initState();
    day = widget.day;
    category = widget.category ?? 'All';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final entries =
          store.entries
              .where(
                (e) =>
                    (day == null || sameDay(e.date, day!)) &&
                    (category == 'All' || e.template.category == category),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      final dates = entries.map((e) => e.date).toSet().toList();
      return DetailPage(
        title: day == null ? 'Your deed history' : 'Daily summary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Little moments of good.', style: editorial(34)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(day == null ? 'Choose a date' : shortDate(day!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: day ?? today,
                      firstDate: DateTime(2020),
                      lastDate: today,
                    );
                    if (d != null) setState(() => day = d);
                  },
                ),
                if (day != null)
                  ActionChip(
                    label: const Text('All dates ×'),
                    onPressed: () => setState(() => day = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: [
                'All',
                ...templates.map((t) => t.category).toSet(),
                'Unclassified',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            if (day != null) ...[
              const SizedBox(height: 20),
              Surface(
                color: sage,
                child: Row(
                  children: [
                    Metric(
                      '${store.pointsOn(day!)}',
                      'Day’s points',
                      Icons.auto_awesome_outlined,
                    ),
                    Metric(
                      '${store.onDay(day!).length}',
                      'Recorded deeds',
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ],
            if (entries.isEmpty)
              const EmptyState(
                'A fresh page',
                'There are no deeds for these filters yet.',
              )
            else
              for (final d in dates) ...[
                Section(dateLabel(d)),
                Surface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  child: Column(
                    children: [
                      for (final e in entries.where((e) => sameDay(e.date, d)))
                        ActivityRow(
                          e.template,
                          title: e.title,
                          subtitle:
                              '${e.repetitions}× · ${e.custom ? 'Awaiting review' : e.template.category} · Private',
                          trailing: Tag('+${store.pointsFor(e)}'),
                          onTap: () => openPage(context, DeedDetailPage(e.id)),
                        ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      );
    },
  );
}

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  int days = 7;
  @override
  Widget build(BuildContext context) {
    final entries = store.entries
        .where(
          (e) => !e.date.isBefore(today.subtract(Duration(days: days - 1))),
        )
        .toList();
    final categories =
        {
          ...templates.map((t) => t.category),
          ...entries.map((e) => e.template.category),
        }.toList()..sort(
          (a, b) => entries
              .where((e) => e.template.category == b)
              .length
              .compareTo(entries.where((e) => e.template.category == a).length),
        );
    return DetailPage(
      title: 'Category insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The good you return to.', style: editorial(34)),
          const SizedBox(height: 20),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('Week')),
              ButtonSegment(value: 30, label: Text('Month')),
            ],
            selected: {days},
            onSelectionChanged: (v) => setState(() => days = v.first),
          ),
          const SizedBox(height: 24),
          if (entries.isEmpty)
            const EmptyState(
              'Your patterns will grow',
              'Start recording deeds to see your category breakdown.',
            )
          else ...[
            Surface(
              color: sage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Most recorded category'),
                  const SizedBox(height: 14),
                  Text(categories.first, style: editorial(32)),
                  const SizedBox(height: 8),
                  const Text(
                    'A pattern in your recorded activities.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final c in categories)
              InkWell(
                onTap: () => openPage(context, HistoryPage(category: c)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(c)),
                          Text(
                            '${entries.where((e) => e.template.category == c).length}',
                            style: const TextStyle(color: green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value:
                              entries
                                  .where((e) => e.template.category == c)
                                  .length /
                              entries.length,
                          minHeight: 7,
                          backgroundColor: sage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const NoteBox(
            'These counts describe logged participation. They do not measure ability, sincerity, or personal worth.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}

class PersonalImpactPage extends StatelessWidget {
  const PersonalImpactPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final measures = [
        ('charity', 'BDT donated', Icons.volunteer_activism_outlined),
        ('help', 'Volunteer minutes', Icons.handshake_outlined),
        ('meals', 'Meals shared', Icons.restaurant_outlined),
      ];
      return DetailPage(
        title: 'Your personal impact',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A little care goes far.', style: editorial(34)),
            const SizedBox(height: 14),
            const Text(
              'Your personal contributions, recorded in their own units.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            for (final m in measures)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Surface(
                  onTap: () => openPage(
                    context,
                    HistoryPage(
                      category: m.$1 == 'help' ? 'Service' : 'Charity',
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(m.$3, color: green, size: 27),
                      const SizedBox(width: 20),
                      Expanded(child: Text(m.$2)),
                      Text(
                        '${store.entries.where((e) => e.template.unit == (m.$1 == 'meals' ? 'Meals' : m.$2)).fold<double>(0, (s, e) => s + e.quantity).toInt()}',
                        style: editorial(31),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 15),
            const NoteBox(
              'Group event totals are separate. Donation amounts never multiply participation points.',
              icon: Icons.info_outline,
            ),
          ],
        ),
      );
    },
  );
}

class StreakPage extends StatelessWidget {
  const StreakPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Your participation streak',
    child: Column(
      children: [
        const SizedBox(height: 15),
        const Icon(Icons.local_fire_department_outlined, size: 60, color: gold),
        const SizedBox(height: 20),
        Text(
          '${store.streak} days of little good.',
          style: editorial(34),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        const Text(
          'Consistency is built one small act at a time.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 30),
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final d = today.subtract(Duration(days: i));
              final qualifies =
                  store.participationDays.contains(d) &&
                  store.onDay(d).any((e) => e.eligibleForPoints);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  qualifies ? Icons.check_circle : Icons.circle_outlined,
                  color: qualifies ? green : muted,
                ),
                title: Text(dateLabel(d)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPage(context, HistoryPage(day: d)),
              );
            },
          ),
        const SizedBox(height: 20),
        const NoteBox(
          'Eligible completed days advance your streak. Plans alone and backdated entries do not. Days use Asia/Dhaka time.',
          icon: Icons.info_outline,
        ),
      ],
    ),
  );
}

class GoalPage extends StatelessWidget {
  const GoalPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final goal = store.goal;
      return DetailPage(
        title: 'Your personal goal',
        child: goal == null
            ? EmptyState(
                'One small intention',
                'Choose one activity to make time for.',
                icon: Icons.flag_outlined,
                action: FilledButton(
                  onPressed: () => openPage(context, const GoalEditor()),
                  child: const Text('Set a goal'),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TemplateIcon(goal.template, size: 76),
                  const SizedBox(height: 24),
                  Text(goal.template.title, style: editorial(35)),
                  const SizedBox(height: 15),
                  Text(
                    '${shortDate(goal.start)} – ${shortDate(goal.end)}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '${store.goalCount} / ${goal.target}',
                    style: editorial(48),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (store.goalCount / goal.target).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: sage,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Recorded completions in your goal period.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 25),
                  FilledButton(
                    onPressed: () =>
                        openPage(context, DeedEditor(template: goal.template)),
                    child: const Text('Record a little progress'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () =>
                        openPage(context, GoalEditor(template: goal.template)),
                    child: const Text('Edit this goal'),
                  ),
                  TextButton(
                    onPressed: () => openPage(
                      context,
                      HistoryPage(category: goal.template.category),
                    ),
                    child: const Text('Review related deeds'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await confirm(
                        context,
                        'End this personal goal?',
                        'Your recorded deeds and reflections will stay in your history.',
                        action: 'End goal',
                      )) {
                        store.goal = null;
                        store.changed();
                      }
                    },
                    child: const Text('End goal'),
                  ),
                ],
              ),
      );
    },
  );
}

class GoalEditor extends StatefulWidget {
  final DeedTemplate? template;
  final int days;
  const GoalEditor({super.key, this.template, this.days = 7});
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final form = GlobalKey<FormState>();
  late DeedTemplate template;
  late final TextEditingController target;
  late int days;
  @override
  void initState() {
    super.initState();
    template = widget.template ?? store.goal?.template ?? templates.first;
    target = TextEditingController(text: '${store.goal?.target ?? 7}');
    days = widget.days;
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'A personal intention',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Small enough to begin.', style: editorial(34)),
          const SizedBox(height: 16),
          const Text(
            'Choose one meaningful goal for this season of your life.',
            style: TextStyle(color: muted),
          ),
          const FieldLabel('Activity'),
          DropdownButtonFormField<DeedTemplate>(
            initialValue: template,
            isExpanded: true,
            items: templates
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => template = v!),
          ),
          const FieldLabel('Number of completions'),
          TextFormField(
            controller: target,
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 999
                  ? 'Choose a target from 1 to 999.'
                  : null;
            },
          ),
          const FieldLabel('Period'),
          Wrap(
            spacing: 8,
            children: [7, 30]
                .map(
                  (d) => ChoiceChip(
                    label: Text(d == 7 ? 'One week' : 'One month'),
                    selected: days == d,
                    onSelected: (_) => setState(() => days = d),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          const NoteBox(
            'V1 supports one active personal goal. Saving replaces the current goal and starts a new period today.',
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 25),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              store.goal = PersonalGoal(
                template,
                int.parse(target.text),
                today,
                today.add(Duration(days: days - 1)),
              );
              store.changed();
              Navigator.pop(context);
            },
            child: const Text('Save my goal'),
          ),
        ],
      ),
    ),
  );
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  int days = 30;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final reflections =
          store.journals
              .where(
                (j) =>
                    !j.date.isBefore(today.subtract(Duration(days: days - 1))),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return DetailPage(
        title: 'Your private journal',
        actions: [
          IconButton(
            tooltip: 'Write reflection',
            onPressed: () => openPage(context, const JournalEditor()),
            icon: const Icon(Icons.add),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('A space that is only yours'),
            const SizedBox(height: 15),
            Text('Pause. Notice. Remember.', style: editorial(34)),
            const SizedBox(height: 15),
            const Text(
              'Little reflections on a life of doing good.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Week')),
                ButtonSegment(value: 30, label: Text('Month')),
              ],
              selected: {days},
              onSelectionChanged: (v) => setState(() => days = v.first),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openPage(context, const JournalEditor()),
              icon: const Icon(Icons.edit_note),
              label: const Text('Write a reflection'),
            ),
            const SizedBox(height: 25),
            if (reflections.isEmpty)
              const EmptyState(
                'Let a moment stay',
                'Write a few words about something meaningful.',
              )
            else
              for (final j in reflections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    onTap: () => openPage(context, JournalDetailPage(j)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(dateLabel(j.date)),
                        const SizedBox(height: 14),
                        Text(j.title, style: editorial(26)),
                        const SizedBox(height: 12),
                        Text(
                          j.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        const Tag('Only you', icon: Icons.lock_outline),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class JournalDetailPage extends StatelessWidget {
  final Reflection reflection;
  const JournalDetailPage(this.reflection, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final e = store.entries
          .where((e) => e.id == reflection.deedId)
          .firstOrNull;
      return DetailPage(
        title: 'A private reflection',
        actions: [
          IconButton(
            tooltip: 'Edit reflection',
            onPressed: () =>
                openPage(context, JournalEditor(reflection: reflection)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(dateLabel(reflection.date)),
            const SizedBox(height: 20),
            Text(reflection.title, style: editorial(36)),
            const SizedBox(height: 20),
            const Tag('Private reflection', icon: Icons.lock_outline),
            const SizedBox(height: 30),
            SelectableText(
              reflection.text,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                height: 1.9,
                color: ink,
              ),
            ),
            if (e != null) ...[
              const Section('A moment connected'),
              ActivityRow(
                e.template,
                title: e.title,
                onTap: () => openPage(context, DeedDetailPage(e.id)),
              ),
            ],
            const SizedBox(height: 30),
            TextButton.icon(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Delete this reflection?',
                  'This removes your private journal entry.',
                  action: 'Delete',
                )) {
                  store.journals.remove(reflection);
                  store.changed();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete reflection'),
            ),
          ],
        ),
      );
    },
  );
}

class JournalEditor extends StatefulWidget {
  final Reflection? reflection;
  final String? deedId;
  const JournalEditor({super.key, this.reflection, this.deedId});
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, text;
  String? deedId;
  bool dirty = false, saved = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.reflection?.title ?? '');
    text = TextEditingController(text: widget.reflection?.text ?? '');
    deedId = widget.reflection?.deedId ?? widget.deedId;
  }

  @override
  void dispose() {
    title.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty || saved,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await confirm(
        context,
        'Leave this reflection?',
        'Your unsaved words will be lost.',
        action: 'Discard',
      )) {
        setState(() => saved = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: DetailPage(
      title: widget.reflection == null
          ? 'A moment to reflect'
          : 'Edit reflection',
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('Just for you', icon: Icons.lock_outline),
            const SizedBox(height: 25),
            Text('What felt meaningful?', style: editorial(34)),
            const SizedBox(height: 16),
            TextFormField(
              controller: title,
              onChanged: (_) => setState(() => dirty = true),
              maxLength: 100,
              style: editorial(25),
              decoration: const InputDecoration(
                hintText: 'Give this moment a title',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add a title.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: text,
              onChanged: (_) => setState(() => dirty = true),
              minLines: 8,
              maxLines: 20,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 18,
                height: 1.8,
              ),
              decoration: const InputDecoration(
                hintText: 'Let your thoughts find a little space…',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Write a few words before saving.'
                  : null,
            ),
            const FieldLabel('Link to a deed (optional)'),
            DropdownButtonFormField<String>(
              initialValue: deedId ?? '',
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('No linked deed'),
                ),
                ...store.entries.map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${shortDate(e.date)} · ${e.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() {
                deedId = v == '' ? null : v;
                dirty = true;
              }),
            ),
            const SizedBox(height: 25),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final j = widget.reflection;
                if (j == null) {
                  store.journals.add(
                    Reflection(
                      store.nextId(),
                      title.text.trim(),
                      text.text.trim(),
                      today,
                      deedId: deedId,
                    ),
                  );
                } else {
                  j.title = title.text.trim();
                  j.text = text.text.trim();
                  j.deedId = deedId;
                }
                store.changed();
                setState(() => saved = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.pop(context);
                    toast(
                      context,
                      'Your reflection is saved for this session.',
                    );
                  }
                });
              },
              child: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('Save my reflection')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
