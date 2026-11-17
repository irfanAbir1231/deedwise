part of '../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Your space',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ProfileAvatar(radius: 34),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: editorial(30)),
                    const SizedBox(height: 5),
                    const Text(
                      'A little good, at your own pace.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CloudAccountPanel(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              localData.profilePhoto == null
                  ? 'Add profile photo'
                  : 'Change profile photo',
            ),
            onPressed: () async {
              final path = await chooseLocalPhoto(context);
              if (path == null) return;
              try {
                await localData.setProfilePhoto(path);
              } catch (_) {
                await local_media.remove(path);
                if (context.mounted) {
                  toast(context, 'Could not save your profile photo.');
                }
              }
            },
          ),
          if (localData.profilePhoto != null)
            TextButton(
              onPressed: () async {
                try {
                  await localData.setProfilePhoto(null);
                } catch (_) {
                  if (context.mounted) {
                    toast(context, 'Could not remove the photo.');
                  }
                }
              },
              child: const Text('Remove profile photo'),
            ),
          NoteBox(
            backend.configured
                ? 'Your connected groups are stored online. Private deeds and photos stay on this device for now. Device reminders are not connected.'
                : 'Deeds, local photos and tour preferences stay on this device. Groups, plans and other preview features remain session-only. Authentication and shared groups require a connected build.',
            icon: Icons.science_outlined,
          ),
          const Section('Make it yours'),
          reviewLink(
            context,
            Icons.rate_review_outlined,
            'My review requests',
            'Track decisions and participation points',
            const MyReviewsPage(),
          ),
          reviewLink(
            context,
            Icons.phonelink_lock_outlined,
            'Offline activity review',
            'Groq matching and local fallback',
            const OfflineModelPage(),
          ),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                reviewLink(
                  context,
                  Icons.tune_rounded,
                  'Personal preferences',
                  'Your interests, time, and spending',
                  const PreferencesPage(),
                ),
                reviewLink(
                  context,
                  Icons.notifications_none,
                  'Reminders',
                  'Gentle nudges for your plans',
                  const ReminderSettingsPage(),
                ),
                reviewLink(
                  context,
                  Icons.shield_outlined,
                  'Privacy and participation points',
                  'Understand what is shared',
                  const PrivacyPage(),
                ),
              ],
            ),
          ),
          Section(backend.configured ? 'Help' : 'Preview tools'),
          KeyedSubtree(
            key: tourSettingsKey,
            child: Surface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: reviewLink(
                context,
                Icons.explore_outlined,
                'Take the app tour',
                'Replay the guide to deeds, groups, challenges, and sharing',
                const AppTourLauncher(),
              ),
            ),
          ),
          if (!backend.configured)
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  reviewLink(
                    context,
                    Icons.login_rounded,
                    'Preview first-use journey',
                    'Welcome, account forms, and onboarding',
                    const WelcomePage(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Preview admin role',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: const Text(
                      'UI demonstration only; not real authorization',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: store.demoAdmin,
                    onChanged: (v) {
                      store.demoAdmin = v;
                      store.changed();
                    },
                  ),
                  if (store.demoAdmin)
                    reviewLink(
                      context,
                      Icons.admin_panel_settings_outlined,
                      'Content administration',
                      'Templates, points, and seasonal dates',
                      const AdminPage(),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          const Center(child: Brand()),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'VERSION 1 · UI PROTOTYPE',
              style: TextStyle(fontSize: 9, color: muted, letterSpacing: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class PreferencesPage extends StatefulWidget {
  final bool onboarding;
  const PreferencesPage({super.key, this.onboarding = false});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late final TextEditingController name;
  late Set<String> interests;
  late String time, budget;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: store.name);
    interests = {...store.interests};
    time = store.availableTime;
    budget = store.budget;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Your preferences',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('A path that feels like you'),
        const SizedBox(height: 15),
        Text('Start where you are.', style: editorial(35)),
        const SizedBox(height: 12),
        const Text(
          'We’ll use these choices to suggest manageable acts of good.',
          style: TextStyle(color: muted),
        ),
        const FieldLabel('What should we call you?'),
        TextField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Your first name'),
        ),
        const FieldLabel('What matters to you?'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: templates
              .map((t) => t.category)
              .toSet()
              .map(
                (c) => FilterChip(
                  label: Text(c),
                  selected: interests.contains(c),
                  onSelected: (v) => setState(() {
                    if (v) {
                      interests.add(c);
                    } else {
                      interests.remove(c);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        const FieldLabel('Time you can make'),
        DropdownButtonFormField<String>(
          initialValue: time,
          items: [
            '5 minutes',
            '15 minutes',
            '30 minutes',
            'No preference',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => time = v!,
        ),
        const FieldLabel('Spending preference'),
        DropdownButtonFormField<String>(
          initialValue: budget,
          items: [
            'No-spend only',
            'A little to give',
            'No preference',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => budget = v!,
        ),
        const SizedBox(height: 30),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) {
              toast(context, 'Please enter a first name.');
              return;
            }
            if (backend.signedIn) {
              try {
                await backend.profiles.ensure(name: name.text.trim());
              } catch (e) {
                if (context.mounted) toast(context, cloudError(e));
                return;
              }
              if (!context.mounted) return;
            }
            store.name = name.text.trim();
            store.interests = interests;
            store.availableTime = time;
            store.budget = budget;
            store.changed();
            if (widget.onboarding) {
              openPage(context, const PrivacyPage(onboarding: true));
            } else {
              Navigator.pop(context);
            }
          },
          child: SizedBox(
            width: double.infinity,
            child: Center(
              child: Text(widget.onboarding ? 'Continue' : 'Save preferences'),
            ),
          ),
        ),
      ],
    ),
  );
}

class ReminderSettingsPage extends StatelessWidget {
  const ReminderSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Gentle reminders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_none, color: green, size: 50),
          const SizedBox(height: 24),
          Text('A nudge, when you need it.', style: editorial(34)),
          const SizedBox(height: 22),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prefer reminders for new plans'),
            value: store.reminders,
            onChanged: (v) {
              store.reminders = v;
              store.changed();
            },
          ),
          const SizedBox(height: 18),
          const NoteBox(
            'Device notification permission and scheduled local reminders are not available in this UI preview. These controls demonstrate saved preferences for the current session.',
            icon: Icons.info_outline,
          ),
          const Section('Your reminder-enabled plans'),
          for (final p in store.plans.where(
            (p) => p.reminder && p.completionId == null && !p.skipped,
          ))
            ActivityRow(
              p.template,
              subtitle: '${shortDate(p.date)} · ${p.time.format(context)}',
              onTap: () => openPage(context, PlanDetailPage(p)),
            ),
        ],
      ),
    ),
  );
}

class PrivacyPage extends StatelessWidget {
  final bool onboarding;
  const PrivacyPage({super.key, this.onboarding = false});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'A space you can trust',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, color: green, size: 52),
        const SizedBox(height: 24),
        Text('Good can grow quietly.', style: editorial(35)),
        const SizedBox(height: 24),
        const PrivacyItem(
          Icons.lock_outline,
          'Private from the beginning',
          'Deeds, notes, donation amounts, and reflections are personal. Groups do not receive them automatically.',
        ),
        const PrivacyItem(
          Icons.people_outline,
          'Sharing is always your choice',
          'After you opt in to a group challenge, you choose each completion to share. The preview shows its label and points.',
        ),
        const PrivacyItem(
          Icons.auto_awesome_outlined,
          'Points track participation',
          'They track accepted activities, not personal worth. Unmatched entries receive no points unless a review is accepted.',
        ),
        const PrivacyItem(
          Icons.calendar_today_outlined,
          'A consistent day boundary',
          'The pilot uses Asia/Dhaka time. Backdated entries update history but do not restore streaks or alter closed competitions.',
        ),
        const PrivacyItem(
          Icons.cloud_outlined,
          'Privacy and storage',
          'The planned service uses account-based access controls, not end-to-end encryption. This preview uses temporary in-memory data.',
        ),
        if (onboarding) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.popUntil(context, (r) => r.isFirst);
              toast(context, 'Welcome. Your little good starts here.');
            },
            child: const SizedBox(
              width: double.infinity,
              child: Center(child: Text('Begin my journey')),
            ),
          ),
        ],
      ],
    ),
  );
}

class PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const PrivacyItem(this.icon, this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 25),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: green, size: 23),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Welcome to DeedWise',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        const Brand(),
        const SizedBox(height: 35),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: CustomPaint(painter: BotanicalPainter(color: green)),
        ),
        const SizedBox(height: 30),
        Text('A little good.\nA more meaningful day.', style: editorial(40)),
        const SizedBox(height: 18),
        const Text(
          'Record your good deeds, nurture your habits, and make room for what matters.',
          style: TextStyle(color: muted, fontSize: 15),
        ),
        const SizedBox(height: 35),
        FilledButton(
          onPressed: () => openPage(context, const AuthPage(signUp: true)),
          child: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Begin your journey')),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => openPage(context, const AuthPage()),
          child: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('I already have an account')),
          ),
        ),
        const SizedBox(height: 20),
        const NoteBox(
          'Account screens are a UI preview. No account is created and no credentials are stored.',
          icon: Icons.science_outlined,
        ),
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  final bool signUp, reset;
  const AuthPage({super.key, this.signUp = false, this.reset = false});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: widget.reset
        ? 'Password recovery'
        : widget.signUp
        ? 'Create your account'
        : 'Welcome back',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Brand(),
          const SizedBox(height: 35),
          Text(
            widget.reset
                ? 'A fresh start.'
                : widget.signUp
                ? 'Your good starts here.'
                : 'A little good awaits.',
            style: editorial(35),
          ),
          const SizedBox(height: 14),
          const Text(
            'Account connection will be added with Supabase.',
            style: TextStyle(color: muted),
          ),
          const FieldLabel('Email address'),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com'),
            validator: (v) =>
                v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                ? 'Enter a valid email address.'
                : null,
          ),
          if (!widget.reset) ...[
            const FieldLabel('Password'),
            TextFormField(
              controller: password,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: 'At least 8 characters',
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
          ],
          if (!widget.signUp && !widget.reset)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => openPage(context, const AuthPage(reset: true)),
                child: const Text('Forgot password?'),
              ),
            ),
          const SizedBox(height: 25),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              password.clear();
              if (widget.reset) {
                toast(context, 'Preview only: no reset email was sent.');
                openPage(context, const ResetPasswordPage());
              } else if (widget.signUp) {
                openPage(context, const PreferencesPage(onboarding: true));
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
                toast(
                  context,
                  'Preview opened. No authentication request was made.',
                );
              }
            },
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  widget.reset
                      ? 'Preview password recovery'
                      : widget.signUp
                      ? 'Continue to preferences'
                      : 'Explore the preview',
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const NoteBox(
            'Demo form only. Do not enter a real password. No account or email action is performed.',
            icon: Icons.info_outline,
          ),
        ],
      ),
    ),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final form = GlobalKey<FormState>(), password = TextEditingController();
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Reset password preview',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Begin again.', style: editorial(34)),
          const FieldLabel('New password'),
          TextFormField(
            controller: password,
            obscureText: true,
            validator: (v) =>
                v == null || v.length < 8 ? 'Use at least 8 characters.' : null,
          ),
          const FieldLabel('Confirm password'),
          TextFormField(
            obscureText: true,
            validator: (v) =>
                v != password.text ? 'Passwords must match.' : null,
          ),
          const SizedBox(height: 25),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                password.clear();
                Navigator.pop(context);
                toast(context, 'Preview only: no password was changed.');
              }
            },
            child: const Text('Preview reset'),
          ),
        ],
      ),
    ),
  );
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Content administration',
    child: !store.demoAdmin
        ? const NoteBox(
            'Enable the preview admin role in Settings to inspect these screens.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A thoughtful foundation.', style: editorial(34)),
              const SizedBox(height: 22),
              const NoteBox(
                'Admin UI preview only. A production build requires server-enforced roles. No private journal content is available here.',
                icon: Icons.admin_panel_settings_outlined,
              ),
              const Section('Manage content'),
              reviewLink(
                context,
                Icons.rule_outlined,
                'Offline matching rules',
                'Internal criteria and similarity cutoff',
                const MatchingRulesPage(),
              ),
              reviewLink(
                context,
                Icons.rate_review_outlined,
                'Activity review queue',
                'Accept requests and add matching rules',
                const AdminReviewQueue(),
              ),
              reviewLink(
                context,
                Icons.menu_book_outlined,
                'Activity templates and references',
                '${templates.length} activities from the supplied catalog',
                const AdminTemplatesPage(),
              ),
              reviewLink(
                context,
                Icons.auto_awesome_outlined,
                'Participation point settings',
                'Fixed template rules and daily cap',
                const AdminPointsPage(),
              ),
              reviewLink(
                context,
                Icons.date_range_outlined,
                'Seasonal challenges',
                'Manage approved publication dates',
                const SeasonalEditor(),
              ),
            ],
          ),
  );
}

class AdminTemplatesPage extends StatelessWidget {
  const AdminTemplatesPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Activity templates',
    child: Column(
      children: [
        const NoteBox(
          'These 50 activities use the supplied deed catalog. Draft edits here are previews and do not change the catalog.',
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 15),
        for (final t in templates)
          ActivityRow(
            t,
            subtitle: '${t.category} · ${t.points} sample points',
            onTap: () => openPage(context, AdminTemplateEditor(t)),
          ),
      ],
    ),
  );
}

class AdminTemplateEditor extends StatefulWidget {
  final DeedTemplate template;
  const AdminTemplateEditor(this.template, {super.key});
  @override
  State<AdminTemplateEditor> createState() => _AdminTemplateEditorState();
}

class _AdminTemplateEditorState extends State<AdminTemplateEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description;
  final source = TextEditingController();
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.template.title);
    description = TextEditingController(text: widget.template.description);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Template draft preview',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('Not verified', color: gold, background: peach),
          const FieldLabel('Activity title'),
          TextFormField(
            controller: title,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a title.' : null,
          ),
          const FieldLabel('Description'),
          TextFormField(controller: description, maxLines: 4),
          const FieldLabel('Source reference'),
          TextFormField(
            controller: source,
            decoration: const InputDecoration(
              hintText: 'Client-approved citation',
            ),
          ),
          const SizedBox(height: 22),
          const NoteBox(
            'Publishing is unavailable until approved content and backend administration are connected. Draft edits here are not persisted.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                toast(
                  context,
                  'Draft preview checked. Publishing is not connected.',
                );
              }
            },
            child: const Text('Check draft preview'),
          ),
        ],
      ),
    ),
  );
}

class AdminPointsPage extends StatelessWidget {
  const AdminPointsPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Point settings',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Participation, simply.', style: editorial(34)),
        const SizedBox(height: 20),
        NoteBox(
          'Daily cap: ${store.dailyCap} points. Rules are locked for the sample pilot challenge.',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 20),
        for (final t in templates)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.title, style: const TextStyle(fontSize: 13)),
            trailing: Tag('${t.points} pts'),
          ),
        const SizedBox(height: 20),
        const Text(
          'These are sample values awaiting client approval. Point controls will be editable only outside active pilot challenges.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class SeasonalEditor extends StatefulWidget {
  const SeasonalEditor({super.key});
  @override
  State<SeasonalEditor> createState() => _SeasonalEditorState();
}

class _SeasonalEditorState extends State<SeasonalEditor> {
  DateTimeRange? dates;
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Seasonal content draft',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good in its own season.', style: editorial(34)),
        const FieldLabel('Challenge title'),
        const TextField(
          decoration: InputDecoration(hintText: 'Seasonal intention'),
        ),
        const FieldLabel('Description'),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(hintText: 'Client-approved content'),
        ),
        const FieldLabel('Publication dates'),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDateRangePicker(
              context: context,
              firstDate: today,
              lastDate: today.add(const Duration(days: 730)),
            );
            if (d != null) setState(() => dates = d);
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(
            dates == null
                ? 'Choose date range'
                : '${shortDate(dates!.start)} – ${shortDate(dates!.end)}',
          ),
        ),
        const SizedBox(height: 24),
        const NoteBox(
          'This is an unpublished draft preview. Approved seasonal content and publishing require backend integration.',
          icon: Icons.info_outline,
        ),
      ],
    ),
  );
}
