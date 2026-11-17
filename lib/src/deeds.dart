part of '../main.dart';

class LibraryPage extends StatefulWidget {
  final bool forPlan;
  const LibraryPage({super.key, this.forPlan = false});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String search = '', category = 'All';
  @override
  Widget build(BuildContext context) {
    if (!widget.forPlan) return const DeedEditor();
    final filtered = templates
        .where(
          (t) =>
              (category == 'All' || t.category == category) &&
              '${t.title} ${t.category}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return DetailPage(
      title: widget.forPlan ? 'Choose an activity' : 'Record a good deed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.forPlan
                ? 'Good starts with intention.'
                : 'What good did you do?',
            style: editorial(34),
          ),
          const SizedBox(height: 12),
          const Text(
            'Every small act deserves a little space.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              hintText: 'Find a good deed…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', ...templates.map((t) => t.category).toSet()]
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: category == c,
                        onSelected: (_) => setState(() => category = c),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const EmptyState(
              'Nothing here yet',
              'Try another word or choose a different category.',
              icon: Icons.search,
            )
          else
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final t in filtered)
                    ActivityRow(
                      t,
                      subtitle: '${t.category} · ${t.points} pts',
                      onTap: () => openPage(
                        context,
                        widget.forPlan
                            ? PlanEditor(template: t)
                            : TemplateDetailPage(t),
                      ),
                    ),
                ],
              ),
            ),
          if (!widget.forPlan) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () =>
                  openPage(context, const DeedEditor(custom: true)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record something else'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Custom deeds are private and receive 0 points until mapped to an approved template.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class TemplateDetailPage extends StatelessWidget {
  final DeedTemplate template;
  const TemplateDetailPage(this.template, {super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'A good deed',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TemplateIcon(template, size: 82),
        const SizedBox(height: 24),
        Tag(template.category),
        const SizedBox(height: 16),
        Text(template.title, style: editorial(36)),
        const SizedBox(height: 16),
        Text(
          template.description,
          style: const TextStyle(fontSize: 16, color: muted),
        ),
        const SizedBox(height: 24),
        Surface(
          onTap: () => openPage(context, const ReferencePage()),
          child: const Row(
            children: [
              Icon(Icons.menu_book_outlined, color: green),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How activity review works',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Private, on-device activity matching',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const SizedBox(height: 18),
        NoteBox(
          '${template.points} sample participation points per completion, within the daily ${store.dailyCap}-point cap. These values require client approval.',
          icon: Icons.auto_awesome_outlined,
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => openPage(context, DeedEditor(template: template)),
          icon: const Icon(Icons.check_rounded),
          label: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('I did this · Record deed')),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openPage(context, PlanEditor(template: template)),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Plan for another day')),
          ),
        ),
      ],
    ),
  );
}

class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});
  @override
  Widget build(BuildContext context) => const OfflineModelPage();
}

class DeedEditor extends StatefulWidget {
  final DeedTemplate? template;
  final DeedEntry? entry;
  final DeedPlan? plan;
  final DateTime? date;
  final bool custom, dailyChallenge;
  const DeedEditor({
    super.key,
    this.template,
    this.entry,
    this.plan,
    this.date,
    this.custom = false,
    this.dailyChallenge = false,
  });
  @override
  State<DeedEditor> createState() => _DeedEditorState();
}

class _DeedEditorState extends State<DeedEditor> {
  @override
  Widget build(BuildContext context) => FreeTextDeedEditor(
    entry: widget.entry,
    plan: widget.plan,
    date: widget.date,
    dailyChallenge: widget.dailyChallenge,
  );
}

class DeedDetailPage extends StatelessWidget {
  final String id;
  final bool justSaved;
  const DeedDetailPage(this.id, {super.key, this.justSaved = false});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final e = store.entries.where((e) => e.id == id).firstOrNull;
      if (e == null) {
        return const DetailPage(
          title: 'Deed removed',
          child: EmptyState(
            'This entry was removed',
            'Your personal totals have been updated.',
          ),
        );
      }
      final reflections = store.journals.where((j) => j.deedId == id).toList();
      return DetailPage(
        title: 'Your good deed',
        actions: [
          IconButton(
            tooltip: 'Share card',
            onPressed: () => openPage(context, ShareCardPage(e)),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Edit deed',
            onPressed: () => openPage(context, DeedEditor(entry: e)),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (justSaved) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: green, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Deed saved',
                    style: TextStyle(color: green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            TemplateIcon(e.template, size: 74),
            const SizedBox(height: 22),
            Text(
              e.title,
              style: e.title.length > 80
                  ? const TextStyle(fontSize: 21, height: 1.7)
                  : editorial(34),
            ),
            const SizedBox(height: 12),
            Text(dateLabel(e.date), style: const TextStyle(color: muted)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Tag('Private', icon: Icons.lock_outline_rounded),
                Tag(
                  '+${store.pointsFor(e)} pts',
                  background: peach,
                  color: gold,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: tourShareCardKey,
              onPressed: () => openPage(context, ShareCardPage(e)),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share as a card'),
            ),
            const SizedBox(height: 16),
            AssessmentCard(e),
            if (!e.eligibleForPoints && e.reviewState != ReviewState.pending)
              TextButton.icon(
                onPressed: () => openPage(context, ReviewRequestPage(e.id)),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Request a review'),
              ),
            if (e.reviewState == ReviewState.pending)
              TextButton(
                onPressed: () => openPage(context, const MyReviewsPage()),
                child: const Text('Track my review'),
              ),
            const Section('Your contribution'),
            Text(
              'Done ${e.repetitions} ${e.repetitions == 1 ? 'time' : 'times'}',
              style: editorial(27),
            ),
            if (e.quantity > 0) ...[
              const SizedBox(height: 14),
              Text(
                '${e.quantity.toStringAsFixed(e.quantity % 1 == 0 ? 0 : 1)} ${e.template.unit ?? ''}',
                style: editorial(22),
              ),
            ],
            if (e.note.isNotEmpty) ...[
              const Section('A note to remember'),
              Surface(
                child: SizedBox(width: double.infinity, child: Text(e.note)),
              ),
            ],
            const Section('Private reflections'),
            if (reflections.isEmpty)
              const Text(
                'A few words can help you remember how this felt.',
                style: TextStyle(color: muted),
              ),
            for (final j in reflections)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(j.title),
                leading: const Icon(Icons.edit_note_rounded),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPage(context, JournalDetailPage(j)),
              ),
            TextButton.icon(
              onPressed: () => openPage(context, JournalEditor(deedId: id)),
              icon: const Icon(Icons.add),
              label: const Text('Write a reflection'),
            ),
            const SizedBox(height: 18),
            if (!backend.configured)
              OutlinedButton.icon(
                onPressed: () => chooseShareGroup(context, id),
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Share to a group challenge'),
              ),
            TextButton(
              onPressed: () => openPage(context, const ReferencePage()),
              child: const Text('How activity review works'),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9B413C),
              ),
              onPressed: () async {
                if (await confirm(
                  context,
                  'Delete this deed?',
                  'Personal totals and open challenge progress will update. Closed challenge snapshots stay unchanged.',
                  action: 'Delete',
                )) {
                  store.delete(e);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete deed'),
            ),
          ],
        ),
      );
    },
  );
}
