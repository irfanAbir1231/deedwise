part of '../main.dart';

enum ReviewState {
  unchecked,
  matched,
  unmatched,
  unavailable,
  pending,
  approved,
  rejected,
}

enum RequestState { pending, approved, rejected, superseded }

class MatchingRule {
  final String id, label, internalSource, sourceNote;
  final List<String> examples;
  final DeedTemplate category;
  final int points;
  MatchingRule(
    this.id,
    this.label,
    this.internalSource,
    this.examples,
    this.category,
    this.points, {
    this.sourceNote = '',
  });
}

class DeedReviewRequest {
  final String id, deedId, narrative, reason;
  final int revision;
  final DateTime date;
  RequestState state = RequestState.pending;
  String response = '';
  DeedReviewRequest(
    this.id,
    this.deedId,
    this.revision,
    this.narrative,
    this.reason,
    this.date,
  );
}

class LocalAssessment {
  final ReviewState state;
  final MatchingRule? rule;
  final double? score;
  final String message;
  const LocalAssessment(this.state, {this.rule, this.score, this.message = ''});
}

class DeviceDeedMatcher {
  static const channel = MethodChannel('deedwise/offline_matcher');
  final GroqDeedClassifier groq;
  DeviceDeedMatcher({GroqDeedClassifier? groq})
    : groq = groq ?? GroqDeedClassifier();
  Future<LocalAssessment> assess(String text) async {
    await DeedModeration.load();
    final issue = DeedModeration.check(text);
    if (issue != null) {
      return LocalAssessment(ReviewState.rejected, message: issue);
    }
    final targets = sourceDeedRules();
    final result = await groq.classify(
      text,
      targets
          .map(
            (r) => {
              'id': r.id,
              'title': r.label,
              'description': r.internalSource,
            },
          )
          .toList(),
    );
    if (result != null) {
      if (result.harmful) {
        return const LocalAssessment(
          ReviewState.rejected,
          message: DeedModeration.harmMessage,
        );
      }
      final rule = targets.where((r) => r.id == result.ruleId).firstOrNull;
      final matched =
          result.completed &&
          rule != null &&
          result.confidence >= store.matchThreshold;
      return LocalAssessment(
        matched ? ReviewState.matched : ReviewState.unmatched,
        rule: rule,
        score: result.confidence,
        message: matched
            ? 'Groq identified this activity from the 50-deed catalog.'
            : 'Groq could not confirm a completed catalog activity with enough confidence. You can add more detail or request a review.',
      );
    }
    final local = await assessLocally(text);
    if (!groq.configured) return local;
    return LocalAssessment(
      local.state,
      rule: local.rule,
      score: local.score,
      message:
          'Online matching is unavailable; the local fallback was used. ${local.message}',
    );
  }

  Future<LocalAssessment> assessLocally(String text) async {
    await DeedModeration.load();
    final issue = DeedModeration.check(text);
    if (issue != null) {
      return LocalAssessment(ReviewState.rejected, message: issue);
    }
    if (DeedModeration.needsContextCheck(text)) {
      return const LocalAssessment(
        ReviewState.unavailable,
        message:
            'This description needs a context review. Automatic points are disabled until it is checked.',
      );
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const LocalAssessment(
        ReviewState.unavailable,
        message:
            'On-device matching runs in the Android app. This browser preview saves your words without awarding automatic points.',
      );
    }
    final targets = sourceDeedRules();
    try {
      final response = await channel.invokeMapMethod<String, dynamic>('match', {
        'text': text,
        'rules': targets
            .map(
              (r) => {
                'id': r.id,
                'phrases': [r.label, ...r.examples],
              },
            )
            .toList(),
      });
      final id = response?['ruleId'];
      final score = (response?['score'] as num?)?.toDouble();
      final rule = targets.where((r) => r.id == id).firstOrNull;
      if (score == null ||
          !score.isFinite ||
          score < -1 ||
          score > 1 ||
          rule == null) {
        return const LocalAssessment(
          ReviewState.unavailable,
          message:
              'The offline review could not be completed. Your deed can still be saved and submitted for review.',
        );
      }
      return LocalAssessment(
        score >= store.matchThreshold &&
                response?['automaticMatchingEnabled'] == true
            ? ReviewState.matched
            : ReviewState.unmatched,
        rule: rule,
        score: score,
        message: response?['automaticMatchingEnabled'] == true
            ? ''
            : 'This is the closest suggested activity. Request a review to confirm it and receive points.',
      );
    } on MissingPluginException {
      return const LocalAssessment(
        ReviewState.unavailable,
        message:
            'The offline model is not installed in this build. Your entry will be saved with no automatic points.',
      );
    } on PlatformException catch (error) {
      return LocalAssessment(
        ReviewState.unavailable,
        message: error.code == 'TEXT_TOO_LONG'
            ? 'Please describe one deed more briefly so it fits the offline model.'
            : 'The offline model is not ready. Save your deed now and retry or request a review.',
      );
    }
  }
}

String reviewLabel(DeedEntry e) => switch (e.reviewState) {
  ReviewState.matched => 'Activity matched',
  ReviewState.approved => 'Review accepted',
  ReviewState.pending => 'Review requested',
  ReviewState.rejected => 'Review not accepted',
  ReviewState.unavailable => 'Check unavailable',
  ReviewState.unmatched => 'No match yet',
  ReviewState.unchecked => 'Not checked yet',
};

class FreeTextDeedEditor extends StatefulWidget {
  final DeedEntry? entry;
  final DeedPlan? plan;
  final DateTime? date;
  final bool dailyChallenge;
  const FreeTextDeedEditor({
    super.key,
    this.entry,
    this.plan,
    this.date,
    this.dailyChallenge = false,
  });
  @override
  State<FreeTextDeedEditor> createState() => _FreeTextDeedEditorState();
}

class _FreeTextDeedEditorState extends State<FreeTextDeedEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController words;
  late final TextEditingController repetitions;
  late DateTime date;
  bool checking = false;
  String? photo;
  bool photoBusy = false;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    words = TextEditingController(text: widget.entry?.title ?? '');
    repetitions = TextEditingController(
      text: '${widget.entry?.repetitions ?? 1}',
    );
    date = widget.entry?.date ?? widget.date ?? today;
    photo = widget.entry?.localPhoto;
  }

  @override
  void dispose() {
    if (!saved && photo != null && photo != widget.entry?.localPhoto) {
      unawaited(local_media.remove(photo!));
    }
    words.dispose();
    repetitions.dispose();
    super.dispose();
  }

  Future<void> save({bool check = true}) async {
    if (checking || photoBusy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => checking = true);
    final text = words.text.trim();
    try {
      await DeedModeration.load();
    } catch (_) {
      if (mounted) {
        setState(() => checking = false);
        toast(context, 'Language check unavailable. Please try again.');
      }
      return;
    }
    final issue = DeedModeration.check(text);
    if (issue != null) {
      if (mounted) {
        setState(() => checking = false);
        toast(context, issue);
      }
      return;
    }
    final assessment = check
        ? await DeviceDeedMatcher().assess(text)
        : const LocalAssessment(ReviewState.unchecked);
    if (!mounted) return;
    if (assessment.state == ReviewState.rejected) {
      setState(() => checking = false);
      toast(context, assessment.message);
      return;
    }
    final matched = assessment.state == ReviewState.matched;
    final old = widget.entry;
    final e = DeedEntry(
      id: old?.id ?? store.nextId(),
      title: text,
      template: matched ? assessment.rule!.category : unclassifiedTemplate,
      date: date,
      note: old?.note ?? '',
      quantity: old?.quantity ?? 0,
      repetitions: int.parse(repetitions.text.trim()),
      custom: !matched,
      reviewState: assessment.state,
      similarity: assessment.score,
      nearestRuleId: assessment.rule?.id,
      matchingNote: assessment.message,
      matchedRuleId: matched ? assessment.rule!.id : null,
      reviewedPoints: matched ? assessment.rule!.points : 0,
      revision: old == null ? 1 : old.revision + 1,
      localPhoto: photo,
    );
    store.save(e, plan: widget.plan, dailyChallenge: widget.dailyChallenge);
    saved = true;
    final persisted = await localData.flush().catchError((Object _) => false);
    if (old?.localPhoto != null && old!.localPhoto != photo) {
      await local_media.remove(old.localPhoto!);
    }
    if (!mounted) return;
    if (!persisted) {
      toast(
        context,
        'Saved for this session only. Device storage is full or unavailable.',
      );
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DeedDetailPage(e.id, justSaved: true)),
    );
  }

  @override
  Widget build(BuildContext context) => DetailPage(
    title: widget.entry == null ? 'Record your day' : 'Edit your words',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('In your own words', icon: Icons.edit_note_rounded),
          const SizedBox(height: 22),
          Text('What good did you do?', style: editorial(35)),
          const SizedBox(height: 12),
          const Text(
            'One deed at a time. No categories to choose—just tell your story.',
            style: TextStyle(color: muted),
          ),
          const FieldLabel('Your deed'),
          TextFormField(
            key: tourDeedTextKey,
            controller: words,
            readOnly: checking,
            minLines: 5,
            maxLines: 10,
            maxLength: 600,
            style: const TextStyle(fontSize: 17, height: 1.7),
            decoration: const InputDecoration(
              hintText:
                  'My friend was stuck in a problem, and I explained a way to solve it…',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.trim().runes.length < 3
                ? 'Tell us what deed you completed.'
                : DeedModeration.check(v),
          ),
          const FieldLabel('Deed photo · optional'),
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LocalPhoto(photo!, height: 170, width: double.infinity),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: checking || photoBusy
                    ? null
                    : () async {
                        setState(() => photoBusy = true);
                        final selected = await chooseLocalPhoto(context);
                        if (!mounted) {
                          if (selected != null) {
                            await local_media.remove(selected);
                          }
                          return;
                        }
                        if (selected != null) {
                          if (photo != null &&
                              photo != widget.entry?.localPhoto) {
                            await local_media.remove(photo!);
                          }
                          if (!mounted) return;
                          setState(() => photo = selected);
                        }
                        setState(() => photoBusy = false);
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  photoBusy
                      ? 'Preparing photo…'
                      : photo == null
                      ? 'Add photo'
                      : 'Replace photo',
                ),
              ),
              if (photo != null)
                TextButton(
                  onPressed: checking || photoBusy
                      ? null
                      : () {
                          if (photo != widget.entry?.localPhoto) {
                            unawaited(local_media.remove(photo!));
                          }
                          setState(() => photo = null);
                        },
                  child: const Text('Remove photo'),
                ),
            ],
          ),
          const Text(
            'Stored on this device. Never sent for deed matching.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const FieldLabel('How many times did you do this?'),
          TextFormField(
            key: tourDeedCountKey,
            controller: repetitions,
            readOnly: checking,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '1',
              helperText:
                  'Count the times you did this deed. It does not multiply points.',
            ),
            validator: (v) {
              final count = int.tryParse(v?.trim() ?? '');
              return count == null || count < 1 || count > 999
                  ? 'Enter a number from 1 to 999.'
                  : null;
            },
          ),
          const FieldLabel('Which day?'),
          OutlinedButton.icon(
            onPressed: checking
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: today,
                    );
                    if (d != null) setState(() => date = d);
                  },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(dateLabel(date)),
          ),
          const SizedBox(height: 22),
          const NoteBox(
            'Checking sends this deed text to Groq when online matching is configured. Your journal is not sent. If the service is unavailable, the local model is used.',
          ),
          if (widget.entry != null) ...[
            const SizedBox(height: 12),
            const NoteBox(
              'Editing starts a fresh check. Earlier points and pending review requests are recalculated.',
              icon: Icons.refresh_rounded,
            ),
          ],
          const SizedBox(height: 25),
          FilledButton.icon(
            onPressed: checking ? null : save,
            icon: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  checking ? 'Checking your deed…' : 'Save and check my deed',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: checking ? null : () => save(check: false),
              child: const Text('Just save for now'),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Groq matching with an on-device fallback.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class MatchResultPage extends StatelessWidget {
  final String id, message;
  const MatchResultPage(this.id, {super.key, this.message = ''});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final e = store.entries.where((e) => e.id == id).firstOrNull;
      if (e == null) {
        return const DetailPage(
          title: 'Entry removed',
          child: EmptyState(
            'This entry was removed',
            'Return to your day to record another moment.',
          ),
        );
      }
      return DetailPage(
        title: 'Saved entry',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            const SaveConfirmationMark(),
            const SizedBox(height: 16),
            Text('Deed saved', style: editorial(34)),
            const SizedBox(height: 14),
            Text(
              e.eligibleForPoints
                  ? 'This activity qualifies for participation points.'
                  : 'Saved privately. No participation points have been added for this entry yet.',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 23),
            Surface(
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  e.title,
                  style: const TextStyle(fontSize: 17, height: 1.7),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AssessmentCard(e, message: message),
            const SizedBox(height: 24),
            if (!e.eligibleForPoints && e.reviewState != ReviewState.pending)
              FilledButton.icon(
                onPressed: () => openPage(context, ReviewRequestPage(e.id)),
                icon: const Icon(Icons.rate_review_outlined),
                label: const SizedBox(
                  width: double.infinity,
                  child: Center(child: Text('Request a review')),
                ),
              ),
            if (e.reviewState == ReviewState.pending)
              FilledButton(
                onPressed: () => openPage(context, const MyReviewsPage()),
                child: const Text('Track my review'),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => DeedEditor(date: e.date)),
              ),
              icon: const Icon(Icons.add),
              label: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('Write another deed')),
              ),
            ),
            TextButton(
              onPressed: () => openPage(context, DeedDetailPage(id)),
              child: const Text('View this entry'),
            ),
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Back to my day'),
            ),
          ],
        ),
      );
    },
  );
}

class AssessmentCard extends StatelessWidget {
  final DeedEntry entry;
  final String message;
  const AssessmentCard(this.entry, {super.key, this.message = ''});
  @override
  Widget build(BuildContext context) => Surface(
    color: entry.eligibleForPoints ? sage : peach,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                reviewLabel(entry),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Tag('+${store.pointsFor(entry)} pts', background: Colors.white),
          ],
        ),
        const SizedBox(height: 10),
        if (entry.nearestRuleId != null && entry.similarity != null) ...[
          Text(
            entry.reviewState == ReviewState.matched
                ? 'Matched activity: ${store.matchingRules.where((r) => r.id == entry.nearestRuleId).firstOrNull?.label ?? entry.nearestRuleId}'
                : 'Closest suggestion: ${store.matchingRules.where((r) => r.id == entry.nearestRuleId).firstOrNull?.label ?? entry.nearestRuleId}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Match score: ${entry.similarity!.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          (entry.reviewState == ReviewState.unmatched ||
                      entry.reviewState == ReviewState.unavailable) &&
                  (message.isNotEmpty || entry.matchingNote.isNotEmpty)
              ? (message.isNotEmpty ? message : entry.matchingNote)
              : switch (entry.reviewState) {
                  ReviewState.matched =>
                    'The check found an eligible activity. Daily point caps still apply.',
                  ReviewState.approved =>
                    'An accepted review makes this entry eligible for points, within the daily cap.',
                  ReviewState.pending =>
                    'Your request is waiting for admin review. Points stay at zero until it is accepted.',
                  ReviewState.rejected =>
                    'This review was not accepted. Your deed stays in your private history.',
                  ReviewState.unmatched =>
                    'No qualifying match was found. That does not decide the value of your action. You can ask for a review.',
                  ReviewState.unchecked =>
                    'Saved without a check. No points are awarded until matching or admin review accepts the activity.',
                  ReviewState.unavailable =>
                    'The offline check is unavailable in this preview. Retry in a configured Android build or request a review.',
                },
          style: const TextStyle(fontSize: 12, color: muted, height: 1.65),
        ),
      ],
    ),
  );
}

class ReviewRequestPage extends StatefulWidget {
  final String id;
  const ReviewRequestPage(this.id, {super.key});
  @override
  State<ReviewRequestPage> createState() => _ReviewRequestPageState();
}

class _ReviewRequestPageState extends State<ReviewRequestPage> {
  final form = GlobalKey<FormState>(), reason = TextEditingController();
  bool consent = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = store.entries.where((e) => e.id == widget.id).firstOrNull;
    if (entry == null) {
      return const DetailPage(
        title: 'Request review',
        child: Text('This deed is no longer available.'),
      );
    }
    return DetailPage(
      title: 'Give this deed another look',
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Some good needs context.', style: editorial(34)),
            const SizedBox(height: 15),
            const Text(
              'Ask an admin to review this activity and its context.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            Surface(child: Text(entry.title)),
            const FieldLabel('Why do you think it should qualify?'),
            TextFormField(
              controller: reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Add any context that helps the reviewer…',
              ),
              validator: (v) => v == null || v.trim().length < 5
                  ? 'Add a little context for the reviewer.'
                  : null,
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: consent,
              onChanged: (v) => setState(() => consent = v!),
              title: const Text(
                'Share this deed and explanation with the review team.',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: const Text(
                'Your journal and other private entries are not included.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 15),
            const NoteBox(
              'Groq matching needs internet; a local fallback is available. Admin requests in this preview remain in this session.',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: entry.reviewState == ReviewState.pending || !consent
                  ? null
                  : () {
                      if (!form.currentState!.validate()) return;
                      if (!consent) {
                        toast(context, 'Confirm what you want to share first.');
                        return;
                      }
                      store.requestReview(entry, reason.text.trim());
                      Navigator.pop(context);
                      toast(
                        context,
                        'Review requested in this preview. No points added yet.',
                      );
                    },
              child: const SizedBox(
                width: double.infinity,
                child: Center(child: Text('Submit review request')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'My review requests',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A little more understanding.', style: editorial(33)),
          const SizedBox(height: 20),
          if (store.reviewRequests.isEmpty)
            const EmptyState(
              'No reviews requested',
              'Your requests and decisions will appear here.',
              icon: Icons.rate_review_outlined,
            )
          else
            for (final r in store.reviewRequests.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Surface(
                  onTap: () => openPage(context, DeedDetailPage(r.deedId)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag(r.state.name),
                      const SizedBox(height: 12),
                      Text(
                        r.narrative,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (r.response.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          r.response,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class AdminReviewQueue extends StatelessWidget {
  const AdminReviewQueue({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Activity review queue',
      child: !store.demoAdmin
          ? const NoteBox(
              'Enable the admin preview role to inspect the review workflow.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review the action, thoughtfully.', style: editorial(33)),
                const SizedBox(height: 18),
                const NoteBox(
                  'Preview role only. Real decisions require authenticated admin access and an audit trail.',
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const Section('Requests'),
                if (store.reviewRequests.isEmpty)
                  const EmptyState(
                    'Nothing waiting',
                    'Requests from unmatched deeds will appear here.',
                  ),
                for (final r in store.reviewRequests.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.narrative,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${r.state.name} · ${shortDate(r.date)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPage(context, AdminReviewEditor(r)),
                  ),
              ],
            ),
    ),
  );
}

class AdminReviewEditor extends StatefulWidget {
  final DeedReviewRequest request;
  const AdminReviewEditor(this.request, {super.key});
  @override
  State<AdminReviewEditor> createState() => _AdminReviewEditorState();
}

class _AdminReviewEditorState extends State<AdminReviewEditor> {
  final form = GlobalKey<FormState>(),
      criterion = TextEditingController(),
      response = TextEditingController(),
      points = TextEditingController(text: '15');
  DeedTemplate category = catalogDeed(19);
  @override
  void dispose() {
    criterion.dispose();
    response.dispose();
    points.dispose();
    super.dispose();
  }

  Future<void> decide(bool accept) async {
    if (!store.demoAdmin || widget.request.state != RequestState.pending) {
      return;
    }
    if (response.text.trim().isEmpty) {
      toast(context, 'Add a decision note.');
      return;
    }
    if (accept && !form.currentState!.validate()) return;
    if (!await confirm(
      context,
      accept ? 'Accept this activity?' : 'Decline this request?',
      accept
          ? 'This creates an activity rule and makes the current entry eligible for capped points.'
          : 'The entry stays private with zero points.',
      action: accept ? 'Accept' : 'Decline',
    )) {
      return;
    }
    final success = store.resolveReview(
      widget.request,
      accept: accept,
      response: response.text,
      category: category,
      points: int.tryParse(points.text) ?? 0,
      criterion: criterion.text,
    );
    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        toast(
          context,
          'This entry changed or the request is no longer pending.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => DetailPage(
      title: 'Review this activity',
      child: !store.demoAdmin
          ? const NoteBox('Admin preview access required.')
          : Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(widget.request.state.name),
                  const Section('Submitted deed'),
                  Surface(child: Text(widget.request.narrative)),
                  const Section('User’s explanation'),
                  Text(widget.request.reason),
                  if (widget.request.state == RequestState.pending) ...[
                    const FieldLabel('Review criterion'),
                    TextFormField(
                      controller: criterion,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe the underlying action, without copying personal details.',
                      ),
                      validator: (v) => v == null || v.trim().length < 10
                          ? 'Describe the activity criterion for this review.'
                          : null,
                    ),
                    const FieldLabel('Catalog deed'),
                    DropdownButtonFormField<DeedTemplate>(
                      initialValue: category,
                      isExpanded: true,
                      items: templates
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                    const FieldLabel('Participation points'),
                    TextFormField(
                      controller: points,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > store.dailyCap
                            ? 'Choose 1–${store.dailyCap} points.'
                            : null;
                      },
                    ),
                    const FieldLabel('Decision note visible to user'),
                    TextFormField(
                      controller: response,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => decide(true),
                      child: const Text('Accept and add activity rule'),
                    ),
                    TextButton(
                      onPressed: () => decide(false),
                      child: const Text('Decline request'),
                    ),
                  ] else ...[
                    const Section('Decision'),
                    Text(
                      widget.request.response.isEmpty
                          ? 'This version of the entry is no longer current.'
                          : widget.request.response,
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}

class OfflineModelPage extends StatelessWidget {
  const OfflineModelPage({super.key});
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Offline activity review',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.phonelink_lock_outlined, size: 50, color: green),
        const SizedBox(height: 22),
        Text('How your deed is checked.', style: editorial(34)),
        const SizedBox(height: 12),
        Tag(
          GroqDeedClassifier().configured
              ? 'Groq primary · Local fallback'
              : 'Local only · Groq not configured',
        ),
        const SizedBox(height: 15),
        const Text(
          'When Groq is configured, checking sends your deed text and the 50-deed catalog to Groq. Your journal and other entries are not included. A missing key or unavailable service uses the Android local fallback.',
        ),
        const SizedBox(height: 20),
        const NoteBox(
          'Groq requires internet and a configured API key. The bundled local model provides suggestions when Groq is unavailable. The browser cannot run the Android fallback.',
          icon: Icons.info_outline,
        ),
        const Section('How points work'),
        const Text(
          'A qualifying match makes the deed eligible for fixed participation points. If it does not qualify, the entry still stays in your history. You may request an admin review.',
        ),
        const SizedBox(height: 18),
        const Text(
          'Sending a review request to an admin is separate from offline matching and requires connectivity in the connected app.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class MatchingRulesPage extends StatefulWidget {
  const MatchingRulesPage({super.key});
  @override
  State<MatchingRulesPage> createState() => _MatchingRulesPageState();
}

class _MatchingRulesPageState extends State<MatchingRulesPage> {
  double cutoff = store.matchThreshold;
  @override
  Widget build(BuildContext context) => DetailPage(
    title: 'Internal activity rules',
    child: !store.demoAdmin
        ? const NoteBox('Admin preview access required.')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recognise the underlying action.', style: editorial(33)),
              const SizedBox(height: 20),
              const NoteBox(
                'Similarity is not a probability or proof that an action happened. The initial cutoff is uncalibrated. Validate English, Bengali, Banglish, negations, and unrelated statements before real rewards.',
                icon: Icons.science_outlined,
              ),
              const Section('Pilot similarity cutoff'),
              Text('${(cutoff * 100).round()} / 100', style: editorial(32)),
              Slider(
                value: cutoff,
                min: .5,
                max: .99,
                divisions: 49,
                label: '${(cutoff * 100).round()}',
                onChanged: (v) => setState(() => cutoff = v),
              ),
              OutlinedButton(
                onPressed: () {
                  store.matchThreshold = cutoff;
                  store.changed();
                  toast(
                    context,
                    'Pilot cutoff updated for future checks in this session.',
                  );
                },
                child: const Text('Save pilot cutoff'),
              ),
              const Section('Internal reference-backed rules'),
              for (final rule in store.matchingRules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Tag('${rule.points} participation points'),
                        if (rule.internalSource.isNotEmpty) ...[
                          const FieldLabel('Internal source text'),
                          Text(
                            rule.internalSource,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const FieldLabel('Behavioral matching examples'),
                        for (final example in rule.examples)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              example,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ),
                        Text(
                          rule.sourceNote,
                          style: const TextStyle(fontSize: 11, color: gold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );
}
