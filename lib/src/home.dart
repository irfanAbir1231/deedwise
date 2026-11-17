part of '../main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final entries = store.onDay(today).reversed.toList();
    final upcoming = store.plans
        .where(
          (p) => sameDay(p.date, today) && p.completionId == null && !p.skipped,
        )
        .toList();
    final pending = store.reviewRequests
        .where((r) => r.state == RequestState.pending)
        .length;
    final challenge = templates[store.challengeIndex];
    return RootPage(
      title: 'Today',
      botanicalTitle: true,
      subtitle: '${weekNames[today.weekday - 1]}, ${dateLabel(today)}',
      headerAction: IconButton(
        tooltip: 'Quick actions',
        onPressed: () => showHomeActions(context),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Surface(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCF4), Color(0xFFF0F4EA), Color(0xFFD7E5DA)],
              stops: [0, .48, 1],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -25,
                  bottom: -25,
                  width: 150,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: .065,
                        child: CustomPaint(
                          painter: BotanicalPainter(color: green),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Metric(
                      '${store.pointsOn(today)}',
                      'Points',
                      Icons.auto_awesome_outlined,
                      onTap: () => openPage(context, HistoryPage(day: today)),
                    ),
                    Container(width: 1, height: 38, color: line),
                    Metric(
                      '${entries.length}',
                      'Deeds',
                      Icons.check_circle_outline,
                      onTap: () => openPage(context, HistoryPage(day: today)),
                    ),
                    Container(width: 1, height: 38, color: line),
                    Metric(
                      '${store.streak} days',
                      'Streak',
                      Icons.local_fire_department_outlined,
                      onTap: () => openPage(context, const StreakPage()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: double.infinity,
              color: green,
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    top: 8,
                    bottom: -16,
                    width: 130,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(painter: BotanicalPainter()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(
                          'Your daily intention',
                          color: Color(0xFFCCD8CB),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Small acts.\nLasting change.',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 26,
                            height: 1.25,
                            letterSpacing: -.7,
                            color: Color(0xFFFFFCF3),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.only(right: 65),
                          child: Text(
                            'There is always a little good\nyou can bring into today.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Color(0xFFD5E0D4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: tourHomeWriteKey,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF7F2E7),
                            foregroundColor: green,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () =>
                              openPage(context, const DeedEditor()),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Write a deed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Section(
            'Today’s deeds',
            link: 'History',
            onTap: () => openPage(context, const HistoryPage()),
          ),
          if (entries.isEmpty)
            Surface(
              child: const Text(
                'Nothing recorded yet. Write your first deed for today.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            )
          else
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  for (final e in entries.take(3))
                    ActivityRow(
                      e.template,
                      title: e.title,
                      subtitle: '${e.repetitions}× · ${reviewLabel(e)}',
                      trailing: Text(
                        '+${store.pointsFor(e)}',
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => openPage(context, DeedDetailPage(e.id)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Surface(
            color: sage,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.rate_review_outlined,
                color: green,
                size: 22,
              ),
              title: Text(
                pending > 0
                    ? '$pending review${pending == 1 ? '' : 's'} pending'
                    : 'Review requests',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                pending > 0
                    ? 'Waiting for an admin decision'
                    : 'Track requests and accepted activities',
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => openPage(context, const MyReviewsPage()),
            ),
          ),
          Section(
            'Planned today',
            link: 'Planner',
            onTap: () => openPage(context, const PlannerStandalonePage()),
          ),
          if (upcoming.isEmpty)
            const Text(
              'No plans for today.',
              style: TextStyle(color: muted, fontSize: 13),
            )
          else
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  for (final p in upcoming.take(3))
                    ActivityRow(
                      p.template,
                      subtitle: p.time.format(context),
                      trailing: const Icon(
                        Icons.radio_button_unchecked,
                        color: muted,
                        size: 21,
                      ),
                      onTap: () => openPage(context, PlanDetailPage(p)),
                    ),
                ],
              ),
            ),
          const Section('Daily challenge'),
          Surface(
            color: peach,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ActivityRow(
              challenge,
              subtitle: store.challengeEntryId != null
                  ? 'Completed'
                  : 'Optional activity · check after completion',
              onTap: () => openPage(context, const DailyChallengePage()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openPage(context, const JournalEditor()),
            icon: const Icon(Icons.edit_note_rounded),
            label: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('Write a reflection')),
            ),
          ),
        ],
      ),
    );
  }
}

void showHomeActions(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Quick actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        for (final item in <(IconData, String, Widget)>[
          (Icons.history, 'Deed history', const HistoryPage()),
          (
            Icons.rate_review_outlined,
            'My review requests',
            const MyReviewsPage(),
          ),
          (Icons.edit_note, 'Private journal', const JournalPage()),
          (
            Icons.lightbulb_outline,
            'Activity suggestions',
            const SuggestionsPage(),
          ),
        ])
          ListTile(
            leading: Icon(item.$1, color: green),
            title: Text(item.$2),
            onTap: () {
              Navigator.pop(sheetContext);
              openPage(context, item.$3);
            },
          ),
      ],
    ),
  ),
);

// Reserve the tallest catalog copy at this width and text scale so changing
// suggestions never moves the points card or actions. Keep every word visible.
class DailyChallengeCopy extends StatelessWidget {
  final DeedTemplate template;
  const DailyChallengeCopy(this.template, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inherited = DefaultTextStyle.of(context).style;
      final titleStyle = inherited.merge(editorial(36));
      final descriptionStyle = inherited;
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final locale = Localizations.maybeLocaleOf(context);
      double tallest(String Function(DeedTemplate) text, TextStyle style) {
        double height = 0;
        for (final deed in templates) {
          final painter = TextPainter(
            text: TextSpan(text: text(deed), style: style),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
          )..layout(maxWidth: constraints.maxWidth);
          height = math.max(height, painter.height);
          painter.dispose();
        }
        return height.ceilToDouble();
      }

      return Column(
        key: const ValueKey('daily-challenge-copy'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: tallest((t) => t.title, titleStyle),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(template.title, style: titleStyle),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: tallest((t) => t.description, descriptionStyle),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(template.description, style: descriptionStyle),
            ),
          ),
        ],
      );
    },
  );
}

class DailyChallengePage extends StatelessWidget {
  const DailyChallengePage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final template = templates[store.challengeIndex];
      return DetailPage(
        title: 'Today’s challenge',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Tag('A LITTLE GOOD FOR TODAY', icon: Icons.wb_sunny_outlined),
            const SizedBox(height: 25),
            TemplateIcon(template, size: 76),
            const SizedBox(height: 24),
            DailyChallengeCopy(template),
            const SizedBox(height: 24),
            Surface(
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, color: gold),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Up to ${template.points} participation points\nAfter activity review and within the daily cap.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const NoteBox(
              'Your completion is private. You decide if you want to share it with a group.',
            ),
            const SizedBox(height: 28),
            if (store.challengeEntryId == null) ...[
              FilledButton(
                onPressed: () {
                  if (!store.challengeAccepted) {
                    store.challengeAccepted = true;
                    store.changed();
                  } else {
                    openPage(
                      context,
                      DeedEditor(template: template, dailyChallenge: true),
                    );
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      store.challengeAccepted
                          ? 'Complete this challenge'
                          : 'Accept today’s challenge',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    store.challengeIndex =
                        (store.challengeIndex + 1) % templates.length;
                    store.challengeAccepted = false;
                    store.changed();
                  },
                  child: const Text('Try a different suggestion'),
                ),
              ),
            ] else
              FilledButton.icon(
                onPressed: () {
                  final e = store.entries
                      .where((e) => e.id == store.challengeEntryId)
                      .firstOrNull;
                  if (e != null) openPage(context, DeedDetailPage(e.id));
                },
                icon: const Icon(Icons.check),
                label: const Text('Completed · View your deed'),
              ),
            TextButton.icon(
              onPressed: () => openPage(context, TemplateDetailPage(template)),
              icon: const Icon(Icons.info_outline, size: 17),
              label: const Text('About this activity'),
            ),
          ],
        ),
      );
    },
  );
}

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});
  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  String horizon = 'Tomorrow';
  int offset = 0;
  @override
  Widget build(BuildContext context) {
    final filtered = templates
        .where(
          (t) =>
              (store.interests.isEmpty ||
                  store.interests.contains(t.category)) &&
              (store.budget != 'No-spend only' || t.unit != 'BDT donated'),
        )
        .toList();
    final choices = filtered.isEmpty ? templates : filtered;
    final t = choices[offset % choices.length];
    return DetailPage(
      title: 'A little inspiration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Make room for good.', style: editorial(34)),
          const SizedBox(height: 12),
          const Text(
            'Simple ideas shaped by your interests, time, and spending preferences.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: ['Tomorrow', 'This week', 'This month']
                .map(
                  (s) => ChoiceChip(
                    label: Text(s),
                    selected: horizon == s,
                    onSelected: (_) => setState(() => horizon = s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Surface(
            color: t.tint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemplateIcon(t, size: 64),
                const SizedBox(height: 20),
                Text(t.title, style: editorial(30)),
                const SizedBox(height: 12),
                Text(t.description),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => openPage(
                    context,
                    horizon == 'Tomorrow'
                        ? PlanEditor(
                            template: t,
                            date: today.add(const Duration(days: 1)),
                          )
                        : GoalEditor(
                            template: t,
                            days: horizon == 'This week' ? 7 : 30,
                          ),
                  ),
                  child: Text(
                    horizon == 'Tomorrow'
                        ? 'Add to my planner'
                        : 'Set a personal goal',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => offset++),
                  child: const Text('Show another idea'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const NoteBox(
            'Suggestions come from the 50-deed catalog and your preferences. Completed activities are checked privately for point eligibility.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}
