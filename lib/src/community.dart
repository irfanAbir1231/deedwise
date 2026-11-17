part of '../main.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) => backend.configured
      ? const CloudCommunityPage()
      : RootPage(
          title: 'Your groups',
          subtitle: 'Private groups and shared activities',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: tourCommunityCreateKey,
                      onPressed: () => openPage(context, const GroupEditor()),
                      icon: const Icon(Icons.add),
                      label: const Text('Create group'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: tourCommunityJoinKey,
                      onPressed: () => openPage(context, const JoinGroupPage()),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Join by code'),
                    ),
                  ),
                ],
              ),
              const Section('Your circles'),
              AnimatedBuilder(
                animation: store,
                builder: (context, _) => store.groups.isEmpty
                    ? const EmptyState(
                        'Your circle starts here',
                        'Create a group or join friends with an invite code.',
                        icon: Icons.people_outline,
                      )
                    : Column(
                        children: [
                          for (final g in store.groups)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GroupCard(g),
                            ),
                        ],
                      ),
              ),
              const Section('More activities'),
              Surface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined, color: green),
                  title: const Text(
                    'Seasonal activities',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Festivals, seasons and community causes',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPage(context, const SeasonalPage()),
                ),
              ),
              const SizedBox(height: 24),
              const NoteBox(
                'Groups see only the completions you explicitly share.',
              ),
            ],
          ),
        );
}

class GroupCard extends StatelessWidget {
  final GroupData group;
  const GroupCard(this.group, {super.key});
  @override
  Widget build(BuildContext context) => Surface(
    onTap: () => openPage(context, GroupDetailPage(group)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sage,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.people_outline, color: green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.members.length} members · ${group.owner ? 'Owner' : 'Member'}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: muted),
          ],
        ),
        if (group.challengeTitle != null) ...[
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 16, color: green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.challengeTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Tag(group.closed ? 'Closed' : 'Active'),
            ],
          ),
        ],
      ],
    ),
  );
}

class GroupEditor extends StatefulWidget {
  final SeasonalActivity? seasonalActivity;
  const GroupEditor({super.key, this.seasonalActivity});
  @override
  State<GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<GroupEditor> {
  final draft = GroupData('', '', '', '', true, ['You']);
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      description = TextEditingController();
  @override
  void initState() {
    super.initState();
    final activity = widget.seasonalActivity;
    if (activity != null) {
      name.text = activity.title;
      description.text = activity.description;
      draft.challengeTitle = activity.title;
      draft.goalDeedIds = activity.actions
          .map((a) => catalogDeed(a.deedNumber).id)
          .toSet();
      draft.goalTargets = {GoalMetric.completions: 5};
      draft.challengeAction = activity.actions
          .map((a) => catalogDeed(a.deedNumber).title)
          .join('\n');
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Create a circle',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A little good, together.', style: editorial(34)),
          const SizedBox(height: 15),
          const Text(
            'An invite-only space for up to 20 people.',
            style: TextStyle(color: muted),
          ),
          const FieldLabel('Group name'),
          TextFormField(
            controller: name,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'e.g. Our Friday circle',
            ),
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter at least 3 characters.'
                : null,
          ),
          const FieldLabel('A few words about your group'),
          TextFormField(
            controller: description,
            maxLines: 3,
            maxLength: 250,
            decoration: const InputDecoration(
              hintText: 'What brings you together?',
            ),
          ),
          const SizedBox(height: 20),
          const NoteBox(
            'As the owner, you can invite members, create a challenge, and record group events. Private deeds and journals remain private.',
          ),
          const SizedBox(height: 28),
          GroupGoalForm(
            draft,
            buttonLabel: 'Create my circle',
            onSave: () {
              if (!form.currentState!.validate()) return;
              final id = store.nextId();
              draft.id = id;
              draft.name = name.text.trim();
              draft.description = description.text.trim();
              draft.code = 'DW${id.substring(id.length - 5)}';
              store.groups.add(draft);
              store.changed();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => GroupDetailPage(draft)),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});
  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final code = TextEditingController();
  String? error;
  bool preview = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Join a circle',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good company awaits.', style: editorial(34)),
        const SizedBox(height: 14),
        const Text(
          'Enter the invite code shared by your group owner.',
          style: TextStyle(color: muted),
        ),
        const FieldLabel('Invite code'),
        TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {
            preview = false;
            error = null;
          }),
          decoration: InputDecoration(hintText: 'Enter code', errorText: error),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            final c = code.text.trim().toUpperCase();
            final existing = store.groups.where((g) => g.code == c).firstOrNull;
            if (existing != null) {
              openPage(context, GroupDetailPage(existing));
            } else if (c == 'GROW26') {
              setState(() {
                preview = true;
                error = null;
              });
            } else {
              setState(
                () => error =
                    'No group found for this code. Check and try again.',
              );
            }
          },
          child: const Text('Find group'),
        ),
        const SizedBox(height: 22),
        const NoteBox(
          'Preview code: GROW26. Connected group lookup will replace sample invites during backend integration.',
          icon: Icons.info_outline,
        ),
        if (preview) ...[
          const Section('Your invitation'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Everyday good', style: editorial(27)),
                const SizedBox(height: 10),
                const Text(
                  'A small circle for everyday acts of care.\n3 members · Private group',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    final g = GroupData(
                      store.nextId(),
                      'Everyday good',
                      'A small circle for everyday acts of care.',
                      'GROW26',
                      false,
                      ['You', 'Maryam', 'Ali', 'Hasan'],
                      challengeTitle: catalogDeed(18).title,
                    )..challengeAction = catalogDeed(18).title;
                    store.groups.add(g);
                    store.changed();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => GroupDetailPage(g)),
                    );
                  },
                  child: const Text('Join this group'),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class GroupDetailPage extends StatelessWidget {
  final GroupData group;
  const GroupDetailPage(this.group, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Your circle',
      actions: [
        IconButton(
          tooltip: 'Members and invitations',
          onPressed: () => openPage(context, MembersPage(group)),
          icon: const Icon(Icons.group_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 54),
          const SizedBox(height: 20),
          Text(group.name, style: editorial(36)),
          const SizedBox(height: 12),
          Text(group.description, style: const TextStyle(color: muted)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              Tag(
                '${group.members.length} members',
                icon: Icons.people_outline,
              ),
              Tag(
                group.owner ? 'You’re the owner' : 'Private circle',
                icon: Icons.lock_outline,
              ),
            ],
          ),
          const Section('A shared intention'),
          if (group.challengeTitle == null)
            EmptyState(
              'Start something good',
              'Your group has no active challenge.',
              action: group.owner
                  ? FilledButton(
                      onPressed: () =>
                          openPage(context, GroupChallengeEditor(group)),
                      child: const Text('Create a challenge'),
                    )
                  : null,
            )
          else
            Surface(
              color: sage,
              onTap: () => openPage(context, GroupChallengePage(group)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(
                    group.closed
                        ? 'Closed · Frozen snapshot'
                        : 'Group challenge',
                    background: Colors.white,
                  ),
                  const SizedBox(height: 18),
                  Text(group.challengeTitle!, style: editorial(28)),
                  const SizedBox(height: 10),
                  Text(
                    '${shortDate(group.start)} – ${shortDate(group.end)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.optedIn
                              ? 'View your shared progress'
                              : 'Take part at your own pace',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          Section(
            'Your shared impact',
            link: 'View all',
            onTap: () => openPage(context, GroupImpactPage(group)),
          ),
          GroupGoalStats(group),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => openPage(context, MembersPage(group)),
            icon: const Icon(Icons.person_add_alt_outlined),
            label: const Text('Members and invite code'),
          ),
          if (group.owner && group.challengeTitle != null && !group.closed)
            TextButton(
              onPressed: () => openPage(context, GroupChallengeEditor(group)),
              child: const Text('Manage challenge'),
            ),
          const SizedBox(height: 24),
          const NoteBox(
            'Only explicitly shared completions appear here. Group owners cannot read private notes or journals.',
          ),
          if (!group.owner)
            TextButton(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Leave this circle?',
                  'This preview removes the group from your circles.',
                  action: 'Leave group',
                )) {
                  store.groups.remove(group);
                  store.changed();
                  if (context.mounted) {
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                }
              },
              child: const Text('Leave group'),
            ),
        ],
      ),
    ),
  );
}

class MembersPage extends StatelessWidget {
  final GroupData group;
  const MembersPage(this.group, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Your circle’s people',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Better, together.', style: editorial(34)),
          const SizedBox(height: 22),
          Surface(
            color: sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Invite code'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        group.code,
                        style: const TextStyle(
                          fontSize: 29,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy invite code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: group.code));
                        toast(context, 'Invite code copied.');
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${group.members.length} of 20 member spaces used',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const Section('Members'),
          for (final member in group.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: member == 'You'
                  ? const ProfileAvatar()
                  : CircleAvatar(
                      backgroundColor: sage,
                      child: Text(
                        member[0],
                        style: const TextStyle(color: green),
                      ),
                    ),
              title: Text(member),
              subtitle: Text(
                member == 'You' && group.owner ? 'Owner' : 'Member',
              ),
              trailing: group.owner && member != 'You'
                  ? IconButton(
                      tooltip: 'Remove $member',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Remove $member?',
                          'They will no longer be a member of this group.',
                          action: 'Remove',
                        )) {
                          group.members.remove(member);
                          store.changed();
                        }
                      },
                    )
                  : null,
            ),
        ],
      ),
    ),
  );
}

class GroupChallengePage extends StatelessWidget {
  final GroupData group;
  const GroupChallengePage(this.group, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final shared = GroupProgress(group, store.entries).shared;
      final scoreByMember = <String, int>{};
      for (final e in shared) {
        final member = group.sharedBy[e.id] ?? 'You';
        scoreByMember[member] =
            (scoreByMember[member] ?? 0) + store.pointsFor(e);
      }
      final rankedMembers = [...group.members]
        ..sort(
          (a, b) => (scoreByMember[b] ?? 0).compareTo(scoreByMember[a] ?? 0),
        );
      final joined =
          group.optedIn || group.challengeParticipants.contains('You');
      return DetailPage(
        title: 'Group challenge',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag(
              group.closed ? 'Closed · Frozen snapshot' : 'A shared intention',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 23),
            Text(
              group.challengeTitle ?? 'A little good together',
              style: editorial(35),
            ),
            const SizedBox(height: 8),
            Tag(group.challengeOccasion, icon: Icons.celebration_outlined),
            const SizedBox(height: 12),
            Text(
              '${dateLabel(group.start)} – ${dateLabel(group.end)}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            const Text(
              'Join the goal, record relevant deeds, then choose which eligible completions to share with your group.',
            ),
            const SizedBox(height: 20),
            if (!joined && !group.closed)
              FilledButton(
                key: tourChallengeJoinKey,
                onPressed: () {
                  group.optedIn = true;
                  group.challengeParticipants.add('You');
                  store.changed();
                },
                child: const Text('Join this challenge'),
              ),
            if (joined && !group.closed)
              FilledButton.icon(
                onPressed: () => openPage(context, ShareDeedPage(group)),
                icon: const Icon(Icons.add),
                label: const Text('Add progress'),
              ),
            const Section('Challenge goal'),
            Text(group.challengeAction),
            GroupGoalStats(group),
            Section('Leaderboard · challenge points', key: tourLeaderboardKey),
            Surface(
              child: Column(
                children: [
                  for (var i = 0; i < rankedMembers.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 27,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          if (rankedMembers[i] == 'You')
                            const ProfileAvatar(radius: 17)
                          else
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: rankedMembers[i] == 'You'
                                  ? sage
                                  : peach,
                              child: Text(
                                rankedMembers[i][0],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: green,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rankedMembers[i],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${scoreByMember[rankedMembers[i]] ?? 0} pts',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Section('Your shared completions'),
            if (shared.isEmpty)
              const Text(
                'Nothing shared yet. Private entries never appear automatically.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            for (final e in shared)
              ActivityRow(
                e.template,
                title: group.shared[e.id],
                subtitle: '${shortDate(e.date)} · ${e.repetitions}×',
                trailing: Tag('+${store.pointsFor(e)} pts'),
                onTap: () => openPage(context, SharedDeedPage(group, e.id)),
              ),
            const SizedBox(height: 25),
            const NoteBox(
              'Shared visibility: deed label, points and the quantities you confirm. Private notes and reflections stay private.',
            ),
          ],
        ),
      );
    },
  );
}

void chooseShareGroup(BuildContext context, String id) {
  final eligible = store.groups
      .where(
        (g) =>
            (g.optedIn || g.challengeParticipants.contains('You')) &&
            !g.closed &&
            g.challengeTitle != null,
      )
      .toList();
  if (eligible.isEmpty) {
    toast(context, 'Opt in to an active group challenge from Community first.');
    return;
  }
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your circle', style: editorial(27)),
            const SizedBox(height: 16),
            for (final g in eligible)
              ListTile(
                title: Text(g.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  openPage(context, ShareDeedPage(g, selectedId: id));
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class ShareDeedPage extends StatefulWidget {
  final GroupData group;
  final String? selectedId;
  const ShareDeedPage(this.group, {super.key, this.selectedId});
  @override
  State<ShareDeedPage> createState() => _ShareDeedPageState();
}

class _ShareDeedPageState extends State<ShareDeedPage> {
  String? selected;
  final quantityForm = GlobalKey<FormState>();
  final quantities = {
    for (final m in GoalMetric.values) m: TextEditingController(),
  };
  @override
  void dispose() {
    for (final c in quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    selected = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final eligible = store.entries
        .where((e) => g.accepts(e) && !g.shared.containsKey(e.id))
        .toList();
    final entry = eligible.where((e) => e.id == selected).firstOrNull;
    return DetailPage(
      title: 'Choose what to share',
      child: Form(
        key: quantityForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your good. Your choice.', style: editorial(34)),
            const SizedBox(height: 12),
            Text(
              'Sharing with ${g.name}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            if (eligible.isEmpty)
              const EmptyState(
                'No eligible deeds yet',
                'Record a deed within this challenge’s dates. Only accepted, unshared entries are eligible.',
              )
            else ...[
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setState(() {
                  selected = v;
                  for (final c in quantities.values) {
                    c.clear();
                  }
                }),
                child: Column(
                  children: [
                    for (final e in eligible)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: e.id,
                        title: Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${shortDate(e.date)} · ${store.pointsFor(e)} pts',
                        ),
                      ),
                  ],
                ),
              ),
              const Section('What your group will see'),
              Surface(
                color: sage,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry?.title ?? 'Select a completion above',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (entry != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Done ${entry.repetitions} ${entry.repetitions == 1 ? 'time' : 'times'}',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      entry == null
                          ? 'Activity points appear here'
                          : '${store.pointsFor(entry)} participation points',
                      style: const TextStyle(color: green),
                    ),
                  ],
                ),
              ),
              if (entry != null)
                for (final metric in g.targets.keys.where(
                  (m) =>
                      m != GoalMetric.completions &&
                      m != GoalMetric.days &&
                      metricsForDeed(entry.template.id).contains(m),
                )) ...[
                  FieldLabel('${metric.label} to share'),
                  TextFormField(
                    controller: quantities[metric],
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !metric.whole,
                    ),
                    decoration: const InputDecoration(hintText: '0 (optional)'),
                    validator: (v) => validateGoalQuantity(v, metric),
                  ),
                ],
              const SizedBox(height: 18),
              const NoteBox(
                'Your deed label, points and quantities entered above will be shared. Your original private amounts, notes and journal remain private. Blank quantities count as zero.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed:
                    entry == null ||
                        g.closed ||
                        !(g.optedIn || g.challengeParticipants.contains('You'))
                    ? null
                    : () {
                        if (!quantityForm.currentState!.validate()) return;
                        g.sharedQuantities[entry.id] = {
                          for (final m in g.targets.keys.where(
                            (m) =>
                                m != GoalMetric.completions &&
                                m != GoalMetric.days &&
                                metricsForDeed(entry.template.id).contains(m),
                          ))
                            m: double.tryParse(quantities[m]!.text) ?? 0,
                        };
                        g.shared[entry.id] = entry.title;
                        g.sharedBy[entry.id] = 'You';
                        store.changed();
                        Navigator.pop(context);
                        toast(
                          context,
                          'Completion shared. Your private details stay private.',
                        );
                      },
                child: const SizedBox(
                  width: double.infinity,
                  child: Center(child: Text('Confirm and share')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SharedDeedPage extends StatelessWidget {
  final GroupData group;
  final String id;
  const SharedDeedPage(this.group, this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final e = store.entries.where((e) => e.id == id).firstOrNull;
    return DetailPage(
      title: 'Shared completion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('Visible to your circle', icon: Icons.people_outline),
          const SizedBox(height: 24),
          Text(group.shared[id] ?? 'Completion removed', style: editorial(34)),
          const SizedBox(height: 16),
          Text(
            '${e == null ? 0 : store.pointsFor(e)} participation points · You',
          ),
          for (final item
              in (group.sharedQuantities[id] ?? <GoalMetric, double>{}).entries)
            Text('${item.key.label}: ${goalNumber(item.value)}'),
          const SizedBox(height: 24),
          const NoteBox(
            'This is the group-facing view. Only the quantities you explicitly confirmed are shared. Private notes and journal text stay private.',
          ),
          const SizedBox(height: 24),
          if (!group.closed)
            OutlinedButton(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Stop sharing this completion?',
                  'Your personal deed will stay in your history.',
                  action: 'Stop sharing',
                )) {
                  group.shared.remove(id);
                  group.sharedBy.remove(id);
                  group.sharedQuantities.remove(id);
                  store.changed();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Stop sharing'),
            ),
        ],
      ),
    );
  }
}

class GroupChallengeEditor extends StatefulWidget {
  final GroupData group;
  const GroupChallengeEditor(this.group, {super.key});
  @override
  State<GroupChallengeEditor> createState() => _GroupChallengeEditorState();
}

class _GroupChallengeEditorState extends State<GroupChallengeEditor> {
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Group challenge settings',
    child: !widget.group.owner
        ? const NoteBox('Only the owner can manage the goal.')
        : GroupGoalForm(
            widget.group,
            onSave: () {
              store.changed();
              Navigator.pop(context);
            },
          ),
  );
}

class GroupImpactPage extends StatelessWidget {
  final GroupData group;
  const GroupImpactPage(this.group, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Our shared impact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What we made possible.', style: editorial(34)),
          const SizedBox(height: 20),
          const NoteBox(
            'Accepted shared deeds and relevant group events count toward your selected goal. Linked events reference existing shares without counting them again.',
            icon: Icons.people_outline,
          ),
          const Section('Together, so far'),
          GroupGoalStats(group),
          const Section('Group events'),
          if (group.events.isEmpty)
            const EmptyState(
              'Good things ahead',
              'Your group’s events will appear here.',
            ),
          for (final event in group.events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: Text(event.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPage(context, GroupEventPage(group, event)),
            ),
          if (group.owner)
            FilledButton.icon(
              onPressed: () => openPage(context, EventEditor(group)),
              icon: const Icon(Icons.add),
              label: const Text('Record a group event'),
            ),
        ],
      ),
    ),
  );
}

class GroupEventPage extends StatelessWidget {
  final GroupData group;
  final ImpactEvent event;
  const GroupEventPage(this.group, this.event, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Group event',
      actions: [
        if (group.owner)
          IconButton(
            tooltip: 'Edit event',
            onPressed: () =>
                openPage(context, EventEditor(group, event: event)),
            icon: const Icon(Icons.edit_outlined),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: editorial(34)),
          const SizedBox(height: 22),
          Text(shortDate(event.date)),
          if (event.linkedEntryIds.isNotEmpty)
            Text(
              '${event.linkedEntryIds.length} linked completions. Already included in shared progress.',
            )
          else
            for (final m in group.targets.keys.where(
              (m) =>
                  event.deedId != null &&
                  metricsForDeed(event.deedId!).contains(m),
            ))
              ListTile(
                title: Text(m.label),
                trailing: Text(goalNumber(event.value(m))),
              ),
          const SizedBox(height: 20),
          const NoteBox(
            'This event is counted once in group impact. It is not copied into members’ personal totals.',
            icon: Icons.people_outline,
          ),
        ],
      ),
    ),
  );
}

class EventEditor extends StatefulWidget {
  final GroupData group;
  final ImpactEvent? event;
  const EventEditor(this.group, {super.key, this.event});
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final Map<GoalMetric, TextEditingController> amounts;
  late String deedId;
  String? member;
  late DateTime date;
  late Set<String> linked;
  @override
  void initState() {
    super.initState();
    final e = widget.event;
    title = TextEditingController(text: e?.title ?? '');
    deedId = e?.deedId ?? widget.group.selectedDeedIds.first;
    member = e?.member ?? 'You';
    date =
        e?.date ??
        (today.isBefore(widget.group.start)
            ? widget.group.start
            : today.isAfter(widget.group.end)
            ? widget.group.end
            : today);
    linked = {...?e?.linkedEntryIds};
    amounts = {
      for (final m in widget.group.targets.keys)
        m: TextEditingController(text: e == null ? '' : goalNumber(e.value(m))),
    };
  }

  @override
  void dispose() {
    title.dispose();
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final shared = GroupProgress(g, store.entries).shared;
    return DetailPage(
      title: 'Record shared impact',
      child: !g.owner
          ? const NoteBox('Only the owner can record group events.')
          : Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Event name'),
                  TextFormField(
                    controller: title,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter an event name.'
                        : null,
                  ),
                  const FieldLabel('Selected deed'),
                  DropdownButtonFormField<String>(
                    initialValue: deedId,
                    isExpanded: true,
                    items: templates
                        .where((t) => g.selectedDeedIds.contains(t.id))
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => deedId = v!),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: g.start,
                        lastDate: g.end,
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Text(shortDate(date)),
                  ),
                  const Section('Already shared by members?'),
                  const Text(
                    'Link existing completions below, or leave them unselected and record a separate event. Linked events add no extra quantities.',
                  ),
                  for (final e in shared)
                    CheckboxListTile(
                      value: linked.contains(e.id),
                      title: Text(e.title),
                      onChanged: (v) => setState(() {
                        v == true ? linked.add(e.id) : linked.remove(e.id);
                      }),
                    ),
                  if (linked.isEmpty) ...[
                    if (g.goalPerMember)
                      DropdownButtonFormField<String>(
                        initialValue: member,
                        decoration: const InputDecoration(
                          labelText: 'Contributing member',
                        ),
                        items: g.members
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => member = v),
                      ),
                    for (final m in g.targets.keys.where(
                      (m) =>
                          m != GoalMetric.days &&
                          metricsForDeed(deedId).contains(m),
                    )) ...[
                      FieldLabel(m.label),
                      TextFormField(
                        controller: amounts[m],
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !m.whole,
                        ),
                        validator: (v) => validateGoalQuantity(v, m),
                      ),
                    ],
                    if (g.targets.containsKey(GoalMetric.days))
                      const Text(
                        'This event records one practised day. Multiple records on the same date count as one day.',
                      ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: g.closed
                        ? null
                        : () {
                            if (!form.currentState!.validate()) return;
                            final values = {
                              for (final m in g.targets.keys.where(
                                (m) => metricsForDeed(deedId).contains(m),
                              ))
                                m: double.tryParse(amounts[m]!.text) ?? 0,
                            };
                            if (linked.isEmpty &&
                                !g.targets.containsKey(GoalMetric.days) &&
                                values.values.every((v) => v == 0)) {
                              toast(context, 'Add at least one contribution.');
                              return;
                            }
                            final e = widget.event ?? ImpactEvent('');
                            e.title = title.text.trim();
                            e.deedId = deedId;
                            e.date = date;
                            e.member = member;
                            e.linkedEntryIds = {...linked};
                            e.completions = values[GoalMetric.completions] ?? 0;
                            e.donation = values[GoalMetric.donation] ?? 0;
                            e.minutes = values[GoalMetric.minutes] ?? 0;
                            e.meals = values[GoalMetric.meals] ?? 0;
                            e.people = values[GoalMetric.people] ?? 0;
                            if (widget.event == null) g.events.add(e);
                            store.changed();
                            Navigator.pop(context);
                          },
                    child: const Text('Save event'),
                  ),
                ],
              ),
            ),
    );
  }
}
