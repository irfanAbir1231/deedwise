part of '../main.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  DateTime selected = today;
  @override
  Widget build(BuildContext context) => RootPage(
    title: 'Your plans',
    subtitle: 'Upcoming activities and reminders',
    action: IconButton.filled(
      key: tourPlannerAddKey,
      tooltip: 'Add a plan',
      onPressed: () => openPage(context, const LibraryPage(forPlan: true)),
      icon: const Icon(Icons.add),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${monthNames[selected.month - 1]} ${selected.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => setState(
                () => selected = selected.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => setState(
                () => selected = selected.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: tourPlannerDateKey,
              tooltip: 'Choose date',
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2020),
                  lastDate: today.add(const Duration(days: 730)),
                );
                if (d != null) setState(() => selected = d);
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (i) {
            final d = selected
                .subtract(Duration(days: selected.weekday - 1))
                .add(Duration(days: i));
            final active = sameDay(d, selected);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => setState(() => selected = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: active ? green : Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: active ? green : line),
                    ),
                    child: Column(
                      children: [
                        Text(
                          weekNames[i][0],
                          style: TextStyle(
                            color: active ? Colors.white70 : muted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: active ? Colors.white : ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: store.plans.any((p) => sameDay(p.date, d))
                                ? (active ? Colors.white : gold)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Section(
          sameDay(selected, today) ? 'Today’s intentions' : shortDate(selected),
        ),
        AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final plans =
                store.plans.where((p) => sameDay(p.date, selected)).toList()
                  ..sort(
                    (a, b) => (a.time.hour * 60 + a.time.minute).compareTo(
                      b.time.hour * 60 + b.time.minute,
                    ),
                  );
            return plans.isEmpty
                ? EmptyState(
                    'A little space for good',
                    'Choose a small activity to make time for.',
                    icon: Icons.calendar_today_outlined,
                    action: FilledButton.icon(
                      onPressed: () => openPage(
                        context,
                        PlanEditor(template: templates.first, date: selected),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Plan a deed'),
                    ),
                  )
                : Column(
                    children: [
                      for (final p in plans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Surface(
                            padding: const EdgeInsets.all(16),
                            onTap: () => openPage(context, PlanDetailPage(p)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      p.time.format(context),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (p.reminder)
                                      const Icon(
                                        Icons.notifications_none,
                                        size: 15,
                                        color: muted,
                                      ),
                                  ],
                                ),
                                ActivityRow(
                                  p.template,
                                  subtitle: p.recurrence,
                                  trailing: Icon(
                                    p.completionId != null
                                        ? Icons.check_circle
                                        : p.skipped
                                        ? Icons.remove_circle_outline
                                        : Icons.radio_button_unchecked,
                                    color: p.completionId != null
                                        ? green
                                        : muted,
                                  ),
                                ),
                                if (p.completionId != null || p.skipped)
                                  Tag(
                                    p.completionId != null
                                        ? 'Completed'
                                        : 'Skipped',
                                    background: p.skipped ? peach : sage,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 20),
        const NoteBox(
          'An intention is a lovely beginning. Points are added only when you complete and record the deed.',
          icon: Icons.spa_outlined,
        ),
      ],
    ),
  );
}

class PlannerStandalonePage extends StatelessWidget {
  const PlannerStandalonePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      flexibleSpace: const FrostedPanel(child: SizedBox.expand()),
      title: const Text('Your planner'),
    ),
    body: const PlannerPage(),
  );
}

class PlanEditor extends StatefulWidget {
  final DeedTemplate template;
  final DateTime? date;
  final DeedPlan? plan;
  const PlanEditor({super.key, required this.template, this.date, this.plan});
  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  late DateTime date;
  late String recurrence;
  late TimeOfDay time;
  late bool reminder;
  late DeedTemplate template;
  @override
  void initState() {
    super.initState();
    date = widget.plan?.date ?? widget.date ?? today;
    recurrence = widget.plan?.recurrence ?? 'Once';
    time = widget.plan?.time ?? const TimeOfDay(hour: 9, minute: 0);
    reminder = widget.plan?.reminder ?? false;
    template = widget.plan?.template ?? widget.template;
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: widget.plan == null ? 'Plan a little good' : 'Edit your plan',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('An intention for later.', style: editorial(34)),
        const SizedBox(height: 12),
        const Text(
          'Keep it small. Make it meaningful.',
          style: TextStyle(color: muted),
        ),
        const FieldLabel('Activity'),
        DropdownButtonFormField<DeedTemplate>(
          key: tourPlanFormKey,
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
          onChanged: (t) => setState(() => template = t!),
        ),
        const FieldLabel('Date'),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: today.subtract(const Duration(days: 365)),
              lastDate: today.add(const Duration(days: 730)),
            );
            if (d != null) setState(() => date = d);
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(dateLabel(date)),
        ),
        const FieldLabel('Time'),
        OutlinedButton.icon(
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t != null) setState(() => time = t);
          },
          icon: const Icon(Icons.access_time_rounded, size: 18),
          label: Text(time.format(context)),
        ),
        const FieldLabel('Repeat'),
        Wrap(
          spacing: 8,
          children: ['Once', 'Daily', 'Weekly']
              .map(
                (r) => ChoiceChip(
                  label: Text(r),
                  selected: recurrence == r,
                  onSelected: (_) => setState(() => recurrence = r),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me gently'),
          subtitle: const Text(
            'Save a reminder preference',
            style: TextStyle(fontSize: 12),
          ),
          value: reminder,
          onChanged: (v) => setState(() => reminder = v),
        ),
        if (reminder)
          const NoteBox(
            'Preview: reminder preferences are saved for this session. Device notification scheduling will be connected in the Android integration.',
            icon: Icons.notifications_none,
          ),
        const SizedBox(height: 30),
        FilledButton(
          key: tourPlanSaveKey,
          onPressed: () {
            final p = widget.plan;
            if (p == null) {
              store.plans.add(
                DeedPlan(
                  id: store.nextId(),
                  template: template,
                  date: date,
                  recurrence: recurrence,
                  time: time,
                  reminder: reminder,
                ),
              );
            } else {
              p.template = template;
              p.date = date;
              p.recurrence = recurrence;
              p.time = time;
              p.reminder = reminder;
            }
            store.changed();
            Navigator.pop(context);
            toast(context, 'Your intention has a place in the planner.');
          },
          child: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Save my plan')),
          ),
        ),
      ],
    ),
  );
}

class PlanDetailPage extends StatelessWidget {
  final DeedPlan plan;
  const PlanDetailPage(this.plan, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Your intention',
      actions: [
        IconButton(
          tooltip: 'Edit plan',
          onPressed: () => openPage(
            context,
            PlanEditor(template: plan.template, plan: plan),
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TemplateIcon(plan.template, size: 80),
          const SizedBox(height: 24),
          Text(plan.template.title, style: editorial(35)),
          const SizedBox(height: 15),
          Text(plan.template.description),
          const SizedBox(height: 22),
          Surface(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(dateLabel(plan.date)),
                  subtitle: Text(
                    '${plan.time.format(context)} · ${plan.recurrence}',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none),
                  title: Text(
                    plan.reminder
                        ? 'Reminder preference enabled'
                        : 'No reminder',
                  ),
                  subtitle: const Text(
                    'Device scheduling pending integration',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          if (plan.completionId != null)
            FilledButton.icon(
              onPressed: () =>
                  openPage(context, DeedDetailPage(plan.completionId!)),
              icon: const Icon(Icons.check),
              label: const Text('Completed · View deed'),
            )
          else if (plan.skipped)
            const NoteBox(
              'Skipped for this occurrence. There is always another opportunity.',
              icon: Icons.spa_outlined,
            )
          else ...[
            FilledButton.icon(
              onPressed: plan.date.isAfter(today)
                  ? null
                  : () => openPage(
                      context,
                      DeedEditor(template: plan.template, plan: plan),
                    ),
              icon: const Icon(Icons.check_rounded),
              label: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('I did this · Mark complete')),
              ),
            ),
            if (plan.date.isAfter(today))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This plan is for a future day.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openPage(
                context,
                PlanEditor(template: plan.template, plan: plan),
              ),
              icon: const Icon(Icons.event_repeat_outlined),
              label: const Text('Reschedule'),
            ),
            TextButton(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Skip this occurrence?',
                  'No deed or points will be recorded.',
                  action: 'Skip',
                )) {
                  plan.skipped = true;
                  store.changed();
                }
              },
              child: const Text('Skip for now'),
            ),
          ],
          const SizedBox(height: 20),
          TextButton(
            onPressed: () =>
                openPage(context, TemplateDetailPage(plan.template)),
            child: const Text('Read about this activity'),
          ),
        ],
      ),
    ),
  );
}
