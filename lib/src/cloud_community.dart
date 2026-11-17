part of '../main.dart';

class CloudCommunityPage extends StatelessWidget {
  const CloudCommunityPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: backend,
    builder: (context, _) => RootPage(
      title: 'Your groups',
      subtitle: 'Private circles, connected across devices',
      child: backend.signedIn
          ? _CloudGroupsList(key: ValueKey(backend.userId))
          : const CloudAccountPanel(),
    ),
  );
}

class _CloudGroupsList extends StatefulWidget {
  const _CloudGroupsList({super.key});
  @override
  State<_CloudGroupsList> createState() => _CloudGroupsListState();
}

class _CloudGroupsListState extends State<_CloudGroupsList> {
  late Future<List<CloudGroup>> loading;
  @override
  void initState() {
    super.initState();
    loading = backend.groups.list();
  }

  void refresh() {
    setState(() => loading = backend.groups.list());
  }

  Future<void> open(Widget page) async {
    await openPage(context, page);
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => open(const CloudGroupEditor()),
            icon: const Icon(Icons.add),
            label: const Text('Create group'),
          ),
          OutlinedButton.icon(
            onPressed: () => open(const CloudJoinPage()),
            icon: const Icon(Icons.login),
            label: const Text('Join with invite'),
          ),
        ],
      ),
      Section('Your circles', link: 'Refresh', onTap: refresh),
      FutureBuilder<List<CloudGroup>>(
        future: loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return CloudLoadError(snapshot.error!, onRetry: refresh);
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!.isEmpty) {
            return const EmptyState(
              'Your circle starts here',
              'Create a private group or accept an invitation.',
              icon: Icons.people_outline,
            );
          }
          return Column(
            children: snapshot.data!
                .map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      onTap: () => open(CloudGroupPage(g.id)),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.people_outline, color: green),
                        title: Text(g.name),
                        subtitle: Text(
                          '${g.memberIds.length} members · ${g.ownerId == backend.userId ? 'Owner' : 'Member'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 24),
      const NoteBox(
        'Private deeds and photos are not uploaded or shared with your group.',
      ),
    ],
  );
}

class CloudLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const CloudLoadError(this.error, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(cloudError(error), style: const TextStyle(color: muted)),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    ],
  );
}

class CloudGroupEditor extends StatefulWidget {
  const CloudGroupEditor({super.key});
  @override
  State<CloudGroupEditor> createState() => _CloudGroupEditorState();
}

class _CloudGroupEditorState extends State<CloudGroupEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), description = TextEditingController();
  final draft = GroupData('', '', '', '', true, ['You']);
  String operationId = newOperationId();
  String? lastPayload, error;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final goal = <String, dynamic>{
      'title': draft.challengeTitle,
      'deed_ids': draft.selectedDeedIds.toList(),
      'targets': {
        for (final entry in draft.targets.entries) entry.key.name: entry.value,
      },
      'per_member': draft.goalPerMember,
      'start': draft.start.toIso8601String().split('T').first,
      'end': draft.end.toIso8601String().split('T').first,
    };
    final payload = jsonEncode([
      name.text.trim(),
      description.text.trim(),
      goal,
    ]);
    if (lastPayload != null && lastPayload != payload) {
      operationId = newOperationId();
    }
    lastPayload = payload;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await backend.groups.create(
        operationId: operationId,
        name: name.text.trim(),
        description: description.text.trim(),
        goal: goal,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CloudGroupPage(id)),
      );
    } catch (e) {
      if (mounted) setState(() => error = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Create a circle',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A little good, together.', style: editorial(33)),
          const SizedBox(height: 12),
          const Text(
            'A private circle for up to 20 members.',
            style: TextStyle(color: muted),
          ),
          const FieldLabel('Group name'),
          TextFormField(
            controller: name,
            readOnly: busy,
            maxLength: 60,
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter at least 3 characters.'
                : null,
          ),
          const FieldLabel('Description'),
          TextFormField(
            controller: description,
            readOnly: busy,
            maxLength: 250,
            maxLines: 3,
          ),
          if (error != null) NoteBox(error!),
          const SizedBox(height: 12),
          AbsorbPointer(
            absorbing: busy,
            child: GroupGoalForm(
              draft,
              buttonLabel: busy ? 'Creating…' : 'Create my circle',
              onSave: save,
            ),
          ),
        ],
      ),
    ),
  );
}

class CloudJoinPage extends StatefulWidget {
  const CloudJoinPage({super.key});
  @override
  State<CloudJoinPage> createState() => _CloudJoinPageState();
}

class _CloudJoinPageState extends State<CloudJoinPage> {
  final code = TextEditingController();
  InvitePreview? preview;
  String? error;
  bool busy = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> find() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      preview = null;
    });
    try {
      final result = await backend.groups.preview(code.text);
      if (mounted) setState(() => preview = result);
    } catch (e) {
      if (mounted) setState(() => error = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> accept() async {
    if (busy || preview == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = preview!.alreadyMember
          ? preview!.groupId
          : await backend.groups.accept(code.text);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CloudGroupPage(id)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Your invitation',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(size: 54),
        const SizedBox(height: 20),
        Text('Good company awaits.', style: editorial(32)),
        const FieldLabel('Invitation code'),
        TextField(
          controller: code,
          readOnly: busy,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 32,
          onChanged: (_) => setState(() {
            preview = null;
            error = null;
          }),
          decoration: const InputDecoration(
            hintText: 'Paste the code shared with you',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : find,
          child: Text(busy ? 'Please wait…' : 'View invitation'),
        ),
        if (error != null) ...[const SizedBox(height: 14), NoteBox(error!)],
        if (preview != null) ...[
          const Section('Your invitation'),
          Surface(
            color: sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preview!.name, style: editorial(27)),
                const SizedBox(height: 10),
                Text(preview!.description),
                const SizedBox(height: 10),
                Text(
                  '${preview!.memberCount} of 20 member spaces used',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy || preview!.full && !preview!.alreadyMember
                      ? null
                      : accept,
                  child: Text(
                    preview!.alreadyMember
                        ? 'Open my group'
                        : preview!.full
                        ? 'Group is full'
                        : 'Accept invitation',
                  ),
                ),
                if (!preview!.alreadyMember)
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Decline'),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class CloudGroupPage extends StatefulWidget {
  final String id;
  const CloudGroupPage(this.id, {super.key});
  @override
  State<CloudGroupPage> createState() => _CloudGroupPageState();
}

class _CloudGroupPageState extends State<CloudGroupPage> {
  late Future<(CloudGroup, List<CloudMember>)> loading;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    loading = load();
  }

  Future<(CloudGroup, List<CloudMember>)> load() async {
    final results = await Future.wait<Object>([
      backend.groups.get(widget.id),
      backend.groups.members(widget.id),
    ]);
    return (results[0] as CloudGroup, results[1] as List<CloudMember>);
  }

  void refresh() {
    setState(() => loading = load());
  }

  Future<void> remove(CloudMember member) async {
    if (busy) return;
    final own = member.id == backend.userId;
    if (!await confirm(
      context,
      own ? 'Leave this group?' : 'Remove ${member.name}?',
      own
          ? 'You can rejoin with a new invitation.'
          : 'They will need a new invitation to return.',
      action: own ? 'Leave' : 'Remove',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await backend.groups.removeMember(widget.id, member.id);
      if (!mounted) return;
      if (own) {
        Navigator.pop(context);
      } else {
        refresh();
      }
    } catch (e) {
      if (mounted) toast(context, cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Your circle',
    actions: [
      IconButton(
        tooltip: 'Refresh group',
        onPressed: refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: FutureBuilder<(CloudGroup, List<CloudMember>)>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CloudLoadError(snapshot.error!, onRetry: refresh);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (g, members) = snapshot.data!;
        final owner = g.ownerId == backend.userId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(size: 54),
            const SizedBox(height: 20),
            Text(g.name, style: editorial(34)),
            const SizedBox(height: 12),
            Text(g.description, style: const TextStyle(color: muted)),
            const SizedBox(height: 18),
            Tag('${members.length} members · ${owner ? 'Owner' : 'Member'}'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: g.closed
                  ? null
                  : () => openPage(
                      context,
                      CloudInvitesPage(g.id, isOwner: owner),
                    ),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Invite someone'),
            ),
            const Section('A shared intention'),
            Surface(
              color: sage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.goal['title'] as String, style: editorial(25)),
                  const SizedBox(height: 10),
                  for (final id in (g.goal['deed_ids'] as List).cast<String>())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        templates.firstWhere((t) => t.id == id).title,
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final entry in (g.goal['targets'] as Map).entries)
                    Text(
                      '${GoalMetric.values.byName(entry.key as String).label}: ${goalNumber(entry.value as num)}',
                    ),
                  const SizedBox(height: 8),
                  Text(
                    g.goal['per_member'] == true
                        ? 'Target per member'
                        : 'Whole-group target',
                  ),
                  Text(
                    '${g.goal['start']} – ${g.goal['end']}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Section('Members'),
            for (final member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: member.id == backend.userId
                    ? const ProfileAvatar()
                    : CircleAvatar(
                        backgroundColor: sage,
                        child: Text(member.name.characters.first),
                      ),
                title: Text(
                  member.id == backend.userId
                      ? '${member.name} (You)'
                      : member.name,
                ),
                subtitle: Text(member.role),
                trailing: owner && member.id != g.ownerId
                    ? IconButton(
                        tooltip: 'Remove member',
                        onPressed: busy ? null : () => remove(member),
                        icon: const Icon(Icons.person_remove_outlined),
                      )
                    : null,
              ),
            if (!owner)
              TextButton(
                onPressed: busy
                    ? null
                    : () => remove(
                        members.firstWhere((m) => m.id == backend.userId),
                      ),
                child: const Text('Leave group'),
              ),
            const SizedBox(height: 20),
            const NoteBox(
              'Your private deeds are not shared with this group. Group contributions will be available in a later update.',
            ),
          ],
        );
      },
    ),
  );
}

class CloudInvitesPage extends StatefulWidget {
  final String groupId;
  final bool isOwner;
  const CloudInvitesPage(this.groupId, {super.key, required this.isOwner});
  @override
  State<CloudInvitesPage> createState() => _CloudInvitesPageState();
}

class _CloudInvitesPageState extends State<CloudInvitesPage> {
  late Future<List<CloudInvite>> loading;
  CloudInvite? created;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    loading = backend.groups.invites(widget.groupId);
  }

  void refresh() {
    setState(() => loading = backend.groups.invites(widget.groupId));
  }

  Future<void> create() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await backend.groups.invite(widget.groupId);
      if (mounted) {
        setState(() => created = result);
        refresh();
      }
    } catch (e) {
      if (mounted) setState(() => error = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revoke(CloudInvite invite) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await backend.groups.revoke(invite.id);
      if (mounted) {
        if (created?.id == invite.id) created = null;
        refresh();
      }
    } catch (e) {
      if (mounted) toast(context, cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> share() async {
    final token = created?.token;
    if (token == null) return;
    final text =
        'Join my DeedWise circle. In the app, open Groups → Join with invite and enter:\n$token';
    if (!kIsWeb) {
      try {
        await const MethodChannel(
          'deedwise/share_card',
        ).invokeMethod<void>('shareText', {'text': text});
        return;
      } on MissingPluginException {
        // Browser/unsupported targets fall back to copying the invitation.
      } on PlatformException {
        if (mounted) toast(context, 'Could not open sharing. Use Copy code.');
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, 'Invitation copied.');
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Invite your circle',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good company grows.', style: editorial(32)),
        const SizedBox(height: 12),
        const Text(
          'Every member can invite someone. Codes expire after 7 days.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : create,
          icon: const Icon(Icons.add),
          label: Text(busy ? 'Please wait…' : 'Create invitation'),
        ),
        if (error != null) ...[const SizedBox(height: 12), NoteBox(error!)],
        if (created?.token != null) ...[
          const Section('Your new invitation'),
          Surface(
            color: sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  created!.token!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Expires ${dateLabel(created!.expiresAt.toLocal())}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: share,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share invitation'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: created!.token!),
                        );
                        if (context.mounted) toast(context, 'Code copied.');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy code'),
                    ),
                  ],
                ),
                const Text(
                  'Copy or share this invitation before leaving this page.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const Section('Recent invitations'),
        FutureBuilder<List<CloudInvite>>(
          future: loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return CloudLoadError(snapshot.error!, onRetry: refresh);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: snapshot.data!
                  .map(
                    (invite) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        invite.revoked
                            ? 'Revoked invitation'
                            : invite.mine
                            ? 'Your invitation'
                            : 'Member invitation',
                      ),
                      subtitle: Text(
                        'Expires ${dateLabel(invite.expiresAt.toLocal())}',
                      ),
                      trailing:
                          !invite.revoked && (widget.isOwner || invite.mine)
                          ? TextButton(
                              onPressed: busy ? null : () => revoke(invite),
                              child: const Text('Revoke'),
                            )
                          : null,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}
