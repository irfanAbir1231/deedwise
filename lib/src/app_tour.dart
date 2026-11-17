part of '../main.dart';

final tourHomeWriteKey = GlobalKey();
final tourNavAddDeedKey = GlobalKey();
final tourDeedTextKey = GlobalKey();
final tourDeedCountKey = GlobalKey();
final tourDeedDateKey = GlobalKey();
final tourDeedSaveKey = GlobalKey();
final tourResultInfoKey = GlobalKey();
final tourRequestReviewKey = GlobalKey();
final tourReviewReasonKey = GlobalKey();
final tourReviewConsentKey = GlobalKey();
final tourReviewSubmitKey = GlobalKey();
final tourReviewStatusKey = GlobalKey();
final tourPlannerDateKey = GlobalKey();
final tourPlannerAddKey = GlobalKey();
final tourPlanFormKey = GlobalKey();
final tourPlanSaveKey = GlobalKey();
final tourCommunityCreateKey = GlobalKey();
final tourCommunityJoinKey = GlobalKey();
final tourChallengeOccasionKey = GlobalKey();
final tourChallengeTitleKey = GlobalKey();
final tourChallengeActionKey = GlobalKey();
final tourChallengeTargetKey = GlobalKey();
final tourChallengeDateKey = GlobalKey();
final tourChallengeJoinKey = GlobalKey();
final tourLeaderboardKey = GlobalKey();
final tourShareCardKey = GlobalKey();
final tourShareActionKey = GlobalKey();
final tourProgressKey = GlobalKey();
final tourProgressDetailsKey = GlobalKey();
final tourSettingsKey = GlobalKey();

class AppTourStep {
  final IconData icon;
  final String phase, title, description;
  final GlobalKey target;
  final List<GlobalKey> additionalTargets;
  final int tab;
  final Widget Function()? page;

  const AppTourStep({
    required this.icon,
    required this.phase,
    required this.title,
    required this.description,
    required this.target,
    required this.tab,
    this.page,
    this.additionalTargets = const [],
  });

  List<GlobalKey> get targets => [target, ...additionalTargets];
}

GroupData _tourGroup() =>
    GroupData(
        'tour-group',
        'Walkthrough circle',
        'A sample group used only to explain the tour.',
        'TOUR',
        true,
        ['You', 'Sara', 'Omar'],
        challengeTitle: catalogDeed(14).title,
      )
      ..challengeOccasion = 'Ramadan'
      ..challengeAction = catalogDeed(14).title
      ..challengeTarget = 5
      ..challengeUnit = 'meals'
      ..challengeFrequency = 'daily'
      ..start = today
      ..end = today.add(const Duration(days: 29));

final appTourSteps = <AppTourStep>[
  // Phase 1 · Record a deed and request a review (9 steps).
  AppTourStep(
    icon: Icons.edit_note_rounded,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Deed কোথা থেকে লিখবেন',
    description:
        'Home-এর Write a deed অথবা navbar-এর Add deed থেকে শুরু করুন। Next চাপলে tour demo deed form দেখাবে।',
    target: tourHomeWriteKey,
    additionalTargets: [tourNavAddDeedKey],
    tab: 0,
  ),
  AppTourStep(
    icon: Icons.edit_note_rounded,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'কাজটি নিজের ভাষায় লিখুন',
    description:
        'Your deed ঘরে কী ভালো কাজ করেছেন লিখবেন। এটি tour-এর নমুনা form; এখানে কিছু লিখতে বা save করতে হবে না।',
    target: tourDeedTextKey,
    tab: 0,
    page: () => const TourDeedDemoPage(),
  ),
  AppTourStep(
    icon: Icons.calendar_month_outlined,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Count ও deed-এর দিন দিন',
    description:
        'কাজটি কয়বার করেছেন এবং কোন দিনে করেছেন সেটি বাছুন। Count points গুণ করে না; এটি শুধু deed-এর সংখ্যা রাখে।',
    target: tourDeedCountKey,
    additionalTargets: [tourDeedDateKey],
    tab: 0,
    page: () => const TourDeedDemoPage(),
  ),
  AppTourStep(
    icon: Icons.auto_awesome_outlined,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Save and check my deed',
    description:
        'এই button চাপলে deed save হয় এবং device-এর approved activity rules-এর সঙ্গে check হয়। Tour-এ চাপার দরকার নেই—Next-ই পরের ধাপ দেখাবে।',
    target: tourDeedSaveKey,
    tab: 0,
    page: () => const TourDeedDemoPage(),
  ),
  AppTourStep(
    icon: Icons.info_outline_rounded,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Result-এ point-এর ব্যাখ্যা',
    description:
        'মিলে গেলে deed point পাওয়ার যোগ্য হয়, daily cap প্রযোজ্য। না মিললে deed private থাকে এবং point যোগ হয় না—এটি আপনার কাজের মূল্য বিচার নয়।',
    target: tourResultInfoKey,
    tab: 0,
    page: () => const TourResultDemoPage(),
  ),
  AppTourStep(
    icon: Icons.rate_review_outlined,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'আরেকবার review চাইতে পারেন',
    description:
        'System match না পেলে Request a review চাপুন। Review team deed-টি দেখে decision দেবে। Tour-এ request পাঠানো হবে না।',
    target: tourRequestReviewKey,
    tab: 0,
    page: () => const TourResultDemoPage(),
  ),
  AppTourStep(
    icon: Icons.edit_note_rounded,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'কারণ ও share consent দিন',
    description:
        'কেন deed-টি qualify করা উচিত, তার context লিখুন। তারপর deed ও explanation review team-এর সঙ্গে share করতে consent দিন।',
    target: tourReviewReasonKey,
    additionalTargets: [tourReviewConsentKey],
    tab: 0,
    page: () => const TourReviewDemoPage(),
  ),
  AppTourStep(
    icon: Icons.send_outlined,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Submit review request',
    description:
        'এই button-এ request পাঠানো হয়। আসল app-এ review service যুক্ত থাকলে team এটি পরীক্ষা করবে; এই walkthrough কোনো request submit করে না।',
    target: tourReviewSubmitKey,
    tab: 0,
    page: () => const TourReviewDemoPage(),
  ),
  AppTourStep(
    icon: Icons.inbox_outlined,
    phase: 'Deed লেখা ও review চাওয়া',
    title: 'Request-এর status দেখুন',
    description:
        'Submit-এর পর My reviews-এ pending বা decision status দেখবেন। Review approve না হওয়া পর্যন্ত ওই deed-এ point যোগ হয় না।',
    target: tourReviewStatusKey,
    tab: 0,
    page: () => const TourReviewStatusDemoPage(),
  ),

  // Phase 2 · Planner (3 steps).
  AppTourStep(
    icon: Icons.calendar_month_outlined,
    phase: 'Planner-এ কাজ সাজান',
    title: 'দিন বেছে নিন',
    description:
        'Planner tab-এ সপ্তাহের দিন বা calendar picker থেকে কাজের তারিখ বেছে নিন।',
    target: tourPlannerDateKey,
    tab: 1,
  ),
  AppTourStep(
    icon: Icons.add_circle_outline,
    phase: 'Planner-এ কাজ সাজান',
    title: 'একটি plan যোগ করুন',
    description:
        'উপরের + button চাপলে activity বেছে নেওয়া যায়। এরপর কাজের সময়, repeat এবং reminder ঠিক করুন।',
    target: tourPlannerAddKey,
    tab: 1,
  ),
  AppTourStep(
    icon: Icons.notifications_none_rounded,
    phase: 'Planner-এ কাজ সাজান',
    title: 'Plan save ও complete করুন',
    description:
        'Save my plan চাপলে intention calendar-এ আসে। নির্ধারিত দিনে plan খুলে Mark complete করুন, অথবা দরকার হলে reschedule করুন।',
    target: tourPlanSaveKey,
    additionalTargets: [tourPlanFormKey],
    tab: 1,
    page: () => PlanEditor(template: catalogDeed(19)),
  ),

  // Phase 3 · Groups and challenges (6 steps).
  AppTourStep(
    icon: Icons.people_outline,
    phase: 'Group ও challenge',
    title: 'Community-তে যান',
    description:
        'Community tab-এ নিজের group দেখবেন। Create group বা invite code দিয়ে join করা যায়।',
    target: tourCommunityCreateKey,
    additionalTargets: [tourCommunityJoinKey],
    tab: 2,
  ),
  AppTourStep(
    icon: Icons.group_add_outlined,
    phase: 'Group ও challenge',
    title: 'Group তৈরি বা join করুন',
    description:
        'Create group দিয়ে নিজের circle খুলুন, অথবা Join by code দিয়ে বন্ধুর group-এ যোগ দিন। এরপর owner challenge তৈরি করতে পারেন।',
    target: tourCommunityCreateKey,
    additionalTargets: [tourCommunityJoinKey],
    tab: 2,
  ),
  AppTourStep(
    icon: Icons.celebration_outlined,
    phase: 'Group ও challenge',
    title: 'Occasion ও challenge title দিন',
    description:
        'Owner occasion যেমন Ramadan বাছেন, challenge-এর নাম দেন, তারপর কী কাজ করবেন তা নির্দিষ্ট করেন।',
    target: tourChallengeOccasionKey,
    additionalTargets: [tourChallengeTitleKey],
    tab: 2,
    page: () => GroupChallengeEditor(_tourGroup()),
  ),
  AppTourStep(
    icon: Icons.flag_outlined,
    phase: 'Group ও challenge',
    title: 'Target ও সময়সীমা ঠিক করুন',
    description:
        'কাজের বিবরণ, target, unit, প্রতিদিন নাকি মোট target, এবং start/end date দিন। উদাহরণ: ৩০ দিন প্রতিদিন ৫ জনকে সাহায্য করা।',
    target: tourChallengeActionKey,
    additionalTargets: [tourChallengeTargetKey, tourChallengeDateKey],
    tab: 2,
    page: () => GroupChallengeEditor(_tourGroup()),
  ),
  AppTourStep(
    icon: Icons.group_add_outlined,
    phase: 'Group ও challenge',
    title: 'Member challenge-এ join করে',
    description:
        'Member Join this challenge চাপলে অংশ নিতে শুরু করেন। যোগ দেওয়া ঐচ্ছিক; deed share না করা পর্যন্ত group সেটি দেখে না।',
    target: tourChallengeJoinKey,
    tab: 2,
    page: () => GroupChallengePage(_tourGroup()),
  ),
  AppTourStep(
    icon: Icons.leaderboard_outlined,
    phase: 'Group ও challenge',
    title: 'Progress ও leaderboard দেখুন',
    description:
        'Shared eligible deed-এর progress এবং member-দের shared points rank-এ দেখায়। ব্যক্তিগত deed নিজে থেকে group-এ যায় না।',
    target: tourLeaderboardKey,
    tab: 2,
    page: () => GroupChallengePage(_tourGroup()),
  ),

  // Phase 4 · Share a deed card (2 steps).
  AppTourStep(
    icon: Icons.ios_share_rounded,
    phase: 'Deed card share করুন',
    title: 'Deed detail খুলুন',
    description:
        'আপনার deed detail-এ Share as a card বেছে নিন। Card-এ deed, count, date ও DeedWise branding থাকে।',
    target: tourShareCardKey,
    tab: 0,
    page: () => const DeedDetailPage('seed1'),
  ),
  AppTourStep(
    icon: Icons.ios_share_rounded,
    phase: 'Deed card share করুন',
    title: 'Card share করুন',
    description:
        'Share card চাপলে phone-এর share menu খুলবে। সেখান থেকে Instagram, Facebook, WhatsApp বা অন্য app বেছে নিন।',
    target: tourShareActionKey,
    tab: 0,
    page: () => ShareCardPage(store.entries.first),
  ),

  // Phase 5 · Progress and settings (3 steps).
  AppTourStep(
    icon: Icons.bar_chart_rounded,
    phase: 'Progress ও settings',
    title: 'নিজের progress দেখুন',
    description:
        'Progress tab-এ points, current streak এবং সময় অনুযায়ী activity summary পাবেন।',
    target: tourProgressKey,
    tab: 3,
  ),
  AppTourStep(
    icon: Icons.history_rounded,
    phase: 'Progress ও settings',
    title: 'Goal, history ও journal',
    description:
        'Progress-এর Details অংশে goal, deed history, category insight, personal impact এবং private journal খুলতে পারবেন.',
    target: tourProgressDetailsKey,
    tab: 3,
  ),
  AppTourStep(
    icon: Icons.shield_outlined,
    phase: 'Progress ও settings',
    title: 'Privacy ও tour replay',
    description:
        'Settings-এ privacy ও participation point-এর ব্যাখ্যা পাবেন। Take the app tour থেকে পরে walkthrough আবার চালাতে পারবেন।',
    target: tourSettingsKey,
    tab: 0,
    page: () => const SettingsPage(),
  ),
];

class AppTourController {
  final ValueNotifier<int?> stepIndex = ValueNotifier(null);
  Future<void> start() => goTo(0);

  Future<void> goTo(int index) async {
    if (index < 0 || index >= appTourSteps.length) return;
    stepIndex.value = null;
    final navigation = rootNavigatorKey.currentState;
    if (navigation?.canPop() ?? false) {
      navigation!.popUntil((route) => route.isFirst);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    appShellKey.currentState?.setTabForTour(appTourSteps[index].tab);
    await WidgetsBinding.instance.endOfFrame;
    final page = appTourSteps[index].page;
    if (page != null && rootNavigatorKey.currentState != null) {
      unawaited(
        rootNavigatorKey.currentState!.push<void>(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => page(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    await _revealTarget(index);
    stepIndex.value = index;
  }

  Future<void> _revealTarget(int index) async {
    await WidgetsBinding.instance.endOfFrame;
    for (final key in appTourSteps[index].targets) {
      final context = key.currentContext;
      if (context != null && context.mounted) {
        await Scrollable.ensureVisible(
          context,
          alignment: .42,
          duration: const Duration(milliseconds: 180),
        );
      }
    }
  }

  Future<void> next() async {
    final current = stepIndex.value;
    if (current == null) return;
    if (current == appTourSteps.length - 1) {
      await finish();
    } else {
      await goTo(current + 1);
    }
  }

  Future<void> back() async {
    final current = stepIndex.value;
    if (current != null && current > 0) await goTo(current - 1);
  }

  Future<void> finish() async {
    stepIndex.value = null;
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    appShellKey.currentState?.setTabForTour(0);
    await WidgetsBinding.instance.endOfFrame;
  }
}

final appTour = AppTourController();

Future<void> showAppTour(BuildContext context) async {
  store.tourSeen = true;
  await localData.markTourSeen();
  store.changed();
  await appTour.start();
}

class AppTourLauncher extends StatelessWidget {
  const AppTourLauncher({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'App tour',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('এক ধাপ করে শিখুন', style: editorial(32)),
        const SizedBox(height: 12),
        const Text(
          '৫টি phase-এ deed লেখা, review, planner, group challenge, sharing এবং progress দেখুন। শুধু Next চাপলেই tour এগোবে; কোনো sample deed বা review submit হবে না.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => showAppTour(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Start the tour')),
          ),
        ),
      ],
    ),
  );
}

class TourDeedDemoPage extends StatelessWidget {
  const TourDeedDemoPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Record your day · tour preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('Sample only · nothing will be saved'),
        const SizedBox(height: 18),
        Text('What good did you do?', style: editorial(32)),
        const SizedBox(height: 12),
        const Text(
          'A practice example to show where each part of a deed goes.',
          style: TextStyle(color: muted),
        ),
        const FieldLabel('Your deed'),
        TextFormField(
          key: tourDeedTextKey,
          initialValue: sourceDeedRules()[17].examples.first,
          readOnly: true,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(alignLabelWithHint: true),
        ),
        const FieldLabel('How many times did you do this?'),
        TextFormField(key: tourDeedCountKey, initialValue: '1', readOnly: true),
        const FieldLabel('Which day?'),
        OutlinedButton.icon(
          key: tourDeedDateKey,
          onPressed: null,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(dateLabel(today)),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: tourDeedSaveKey,
          onPressed: null,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Save and check my deed')),
          ),
        ),
        const SizedBox(height: 14),
        const NoteBox(
          'Tour preview only. Next explains what happens after this button in the real app.',
        ),
      ],
    ),
  );
}

class TourResultDemoPage extends StatelessWidget {
  const TourResultDemoPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Saved deed · tour preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('Sample result'),
        const SizedBox(height: 18),
        Text('Deed saved', style: editorial(34)),
        const SizedBox(height: 14),
        Surface(
          key: tourResultInfoKey,
          color: peach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Closest suggestion · 0 pts',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              Text(catalogDeed(18).title),
              const SizedBox(height: 9),
              const Text(
                'The deed remains private. The suggested activity comes from the 50-deed catalog. A review is needed before points can be added.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: tourRequestReviewKey,
          onPressed: null,
          icon: const Icon(Icons.rate_review_outlined),
          label: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Request a review')),
          ),
        ),
        const SizedBox(height: 12),
        const NoteBox(
          'This sample is not a real saved deed. Next shows how to explain your deed to the review team.',
        ),
      ],
    ),
  );
}

class TourReviewDemoPage extends StatelessWidget {
  const TourReviewDemoPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Request review · tour preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Some good needs context.', style: editorial(32)),
        const SizedBox(height: 14),
        Text('Sample deed: ${sourceDeedRules()[17].examples.first}'),
        const FieldLabel('Why do you think it should qualify?'),
        TextFormField(
          key: tourReviewReasonKey,
          initialValue:
              'I checked on my elderly neighbour and helped them with groceries.',
          readOnly: true,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: tourReviewConsentKey,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_box_outlined, color: green),
            title: Text(
              'Share this deed and explanation with the review team.',
            ),
            subtitle: Text(
              'Your journal and other private entries are not included.',
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: tourReviewSubmitKey,
          onPressed: null,
          child: const SizedBox(
            width: double.infinity,
            child: Center(child: Text('Submit review request')),
          ),
        ),
        const SizedBox(height: 12),
        const NoteBox('Tour preview only. No review request is submitted.'),
      ],
    ),
  );
}

class TourReviewStatusDemoPage extends StatelessWidget {
  const TourReviewStatusDemoPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'My reviews · tour preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A little more understanding.', style: editorial(32)),
        const SizedBox(height: 16),
        Surface(
          key: tourReviewStatusKey,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.hourglass_top_rounded, color: gold),
            title: Text('Sample deed review'),
            subtitle: Text('Pending · waiting for admin review'),
          ),
        ),
        const SizedBox(height: 14),
        const NoteBox(
          'This is an example status, not a real request. Points stay at zero until the review is accepted.',
        ),
      ],
    ),
  );
}

class AppTourOverlay extends StatefulWidget {
  final int step;
  const AppTourOverlay({super.key, required this.step});
  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> {
  final overlayKey = GlobalKey();
  List<Rect> targetRects = const [];

  @override
  void initState() {
    super.initState();
    _measureTarget();
  }

  @override
  void didUpdateWidget(covariant AppTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) _measureTarget();
  }

  void _measureTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlayObject = overlayKey.currentContext?.findRenderObject();
      final rects = <Rect>[];
      if (overlayObject is RenderBox && overlayObject.hasSize) {
        for (final key in appTourSteps[widget.step].targets) {
          final renderObject = key.currentContext?.findRenderObject();
          if (renderObject is RenderBox && renderObject.hasSize) {
            final origin = overlayObject.globalToLocal(
              renderObject.localToGlobal(Offset.zero),
            );
            rects.add(origin & renderObject.size);
          }
        }
      }
      setState(() => targetRects = rects);
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = appTourSteps[widget.step];
    final phaseSteps = appTourSteps
        .where((s) => s.phase == step.phase)
        .toList();
    final phaseStep = phaseSteps.indexOf(step) + 1;
    final phaseNumber = appTourSteps
        .take(widget.step + 1)
        .map((s) => s.phase)
        .toSet()
        .length;
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final showTop = targetRects.any(
      (rect) => rect.center.dy > screen.height * .52,
    );
    return Stack(
      key: overlayKey,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            child: CustomPaint(painter: _TourSpotlightPainter(targetRects)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: showTop ? padding.top + 18 : null,
          bottom: showTop ? null : padding.bottom + 18,
          child: Material(
            elevation: 18,
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, color: green, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.phase,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                      Text(
                        'Phase $phaseNumber/5 · $phaseStep/${phaseSteps.length}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.step + 1}/${appTourSteps.length}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (widget.step + 1) / appTourSteps.length,
                    color: green,
                    backgroundColor: sage,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton(
                        onPressed: appTour.finish,
                        child: const Text('Exit'),
                      ),
                      const Spacer(),
                      if (widget.step > 0)
                        TextButton(
                          onPressed: appTour.back,
                          child: const Text('Back'),
                        ),
                      const SizedBox(width: 5),
                      FilledButton(
                        onPressed: appTour.next,
                        child: Text(
                          widget.step == appTourSteps.length - 1
                              ? 'Finish'
                              : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourSpotlightPainter extends CustomPainter {
  final List<Rect> targets;
  const _TourSpotlightPainter(this.targets);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final target in targets) {
      path.addRRect(
        RRect.fromRectAndRadius(target.inflate(7), const Radius.circular(14)),
      );
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .63));
    for (final target in targets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target.inflate(7), const Radius.circular(14)),
        Paint()
          ..color = const Color(0xFFE8C778)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TourSpotlightPainter oldDelegate) =>
      oldDelegate.targets != targets;
}
