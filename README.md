# DeedWise

## 17 November 2026: Supabase accounts/groups foundation

Real Google authentication, profiles, private groups, goals, memberships and
explicit invite-code acceptance are implemented. The project schema and function
permissions are deployed and Google is enabled. Local private data/photos are
separate per account. Server scoring, contributions, cloud deed sync and public
HTTPS invitation links are the next phase. See
[BACKEND_IMPLEMENTATION_STATUS.md](BACKEND_IMPLEMENTATION_STATUS.md) for exact
verification and device-test status, and [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for
build/configuration instructions. Earlier implementation notes are historical.

## 17 November 2026: profile, brand and startup

Profile photos now update every current-user avatar, including cached tab headers.
The original D/check logo is shared by Android launcher/splash, Flutter headers,
intro/account screens, share cards and web icons. Startup displays a cream branded
loading screen before local initialization and a persistent three-page first-use
introduction. See [docs/BACKEND_ROADMAP.md](docs/BACKEND_ROADMAP.md) for the proposed
phased multi-user backend; it has not been deployed.

## 16 November 2026: first-use tour, moderation and local card photos

Tour state and personal deeds now persist locally. Deed entry validates profanity
and explicit harmful actions before saving; the online matcher has a separate
harmful-action decision. Cards support 50 first-person catalog captions, editable
text, optional local profile photos and optional local deed photos. Photos are
not sent to the matcher or a backend. Real invitation links remain integration
work because groups and authentication are still previews.

See [LOCAL_FEATURES_REPORT.md](LOCAL_FEATURES_REPORT.md) for verification, the
Groq-integrated private Android build, exact persistence scope and outstanding work. Older
prototype notes below are historical where superseded by this report.

## Groq primary matching

Groq is now the primary matcher, with Android local inference as fallback.
Paste your key in the gitignored `config/groq.local.json` and follow
[GROQ_SETUP.md](GROQ_SETUP.md) to rebuild. This supersedes the earlier offline-only
deployment notes below. Deed text is sent to Groq when configured; journals and
history are not sent. Live English and Bengali smoke checks passed on 10 November
2026 using the local key; these are functional checks rather than accuracy evidence.

## Seasonal activities

The seasonal browser includes 24 collections across religious festivals, cultural
occasions, weather-related care, environmental projects and learning/service
campaigns. Search and category filters lead to concrete suggestions mapped to the
existing 50-deed catalog. Suggestions open the planner with the correct deed;
seasonal group goals preselect relevant deeds and let users choose dates, metrics
and targets. Participation is optional. This is an idea library rather than a
published calendar; users choose dates for their own local occasion.

## Goal-based circles

Circle creation now requires one or more of the 50 catalog deeds, selected progress
fields with positive targets, dates, and a whole-group or per-member scope. The
creation form previews those fields. Owners can adjust targets; deeds, fields,
scope and dates are locked once contributions exist.

Overview, challenge and shared-impact pages use one aggregation model. Only
accepted, relevant, explicitly shared deeds in range count. Completions use recorded
repetitions; practised days count distinct calendar dates. Money, meals, minutes
and reported people are entered explicitly when sharing, separately from private
personal quantities. Reported people are not a count of unique beneficiaries.
Group events can record separate quantities or reference already shared entries;
linked events never add a second contribution. Points remain separate.

Data remains session-only in this prototype. Ten new goal tests cover aggregation,
validation, narrow-screen creation and explicit sharing. The full suite currently
has 34 passes and the same three existing tour/navigation/sharing failures.

## Latest product revision

Deed logging is now **free text first**: write one completed action, run on-device matching against the supplied 50-deed catalog, and receive points only after a qualifying match or an accepted admin review. Private results retain the nearest deed and show its title and similarity score, including a clearly labelled suggestion below the 0.80 cutoff. Source verse citations stay internal. The activity picker is retained only for planning suggestions.

The selectable library now contains all 50 source deeds. Demo history, plans, goals, daily/group challenges and tour examples use that same catalog. The previous seven generic activities are retained only as internal category styles and sample point values. Seed history is explicitly approved demo content without fabricated model similarity scores.

See [MATCHING_RESULTS.md](MATCHING_RESULTS.md) for the current trained model, measured results, preparation commands and limitations. **A 70.4 MB model is bundled for suggestions. Automatic matching is disabled because evaluation failed its gate.** The bundled model reached 58% top-1 agreement on authored development test positives; this is not production accuracy evidence. Actual device inference has not yet been verified. Web truthfully reports Android matching as unavailable.

This revision supersedes the template-first assumptions in the original prototype description below.

Latest matching/catalog checks: seven Flutter flow/data/layout tests and seven Python data/deployment checks pass; 612 JVM normalization/tokenizer cases agree with Python. Android APK and web compilation succeed. The complete Flutter suite has 20 passes and three existing tour/navigation/sharing test failures; analysis has two existing web-library notices. Model evaluation is documented separately from app-flow tests.

A connected Flutter UI prototype for private good deed tracking, planning, and reflection. Built in a new, isolated folder from the agreed Pillars + Habitify + Day One direction.

## Run

Requires Flutter 3.35.3 / Dart 3.9.2 or a compatible newer SDK.

```powershell
flutter pub get
flutter run -d chrome
```

For Android, start an emulator or attach a device, then run `flutter run`. The Android application label is DeedWise. The package identifier remains a development placeholder.

To serve the compiled browser preview:

```powershell
flutter build web
python -m http.server 5174 --bind 127.0.0.1 --directory build/web
```

Then visit `http://127.0.0.1:5174` in a browser. Do not open the generated HTML directly from the filesystem.

## What is interactive

- Five-destination phone app shell with bottom navigation and a centered preview on wide screens.
- Deed library, search/category filtering, template/reference information, create/edit/delete, and save confirmation.
- Free-text deed logging with a repetition count, plus a private previewable share card. Android opens the native image share sheet; the browser downloads a PNG card and copies deed text.
- Today’s points, deed counts, participation streak, daily challenge accept/replace/complete, and suggestions.
- Date-based planner, one-off/daily/weekly plans, time/reminder preferences, complete/reschedule/skip, and next recurrence after completion.
- History/date filtering, category insights, personal impact, one active goal, journal writing/editing/deletion, linked reflections, and unsaved-writing protection.
- Private groups, create/join by sample code, invitations, member management, occasion challenges with daily/total count goals, challenge joining/progress, a points leaderboard, explicit deed sharing, withdrawal, and group event impact.
- Preferences, privacy explanation, reminder settings, a first-use guided tour (replayable from Settings), first-use/account form previews, and admin screen previews.

Use `GROW26` to preview joining another sample group. Use the profile avatar to open Settings. First-use and admin previews are available under Preview tools; the admin toggle is explicitly a demonstration, not authorization.

## Prototype boundaries

All data is temporary, in memory, and resets when the app restarts or the browser reloads. No private data is sent to a service. There is no live account, database, notification scheduler, payment flow, or published religious content.

Authentication/recovery screens validate input but do not create accounts, send emails, or change passwords. Reminder controls store a preference only. Religious references remain visibly pending approval. Admin template/seasonal editing is a draft preview with no persistence or publishing. Point settings display locked sample rules.

The scoring model demonstrates caps and shared record updates. Group leaderboard points are derived from deeds shared in this local session; showing other users' live scores needs accounts, a shared database, and server-side scoring. Production authorization, authoritative scoring, period closing/snapshots, and duplicate protection must be enforced by the backend. Closed-challenge behavior is not an integrated historical snapshot service. Recommendation fixtures use selected categories and spending preferences; full time/history matching remains integration work.

Group event participant association, the separate personal people-helped measure, account confirmation, real invite lookup, and richer recovery/loading states remain in the next UI/integration pass. Group membership and role behavior use sample data rather than a remote identity system.

## Design

- Compact Android-first screens with smaller sans-serif headings, denser activity rows, and a task-focused Today screen. Large browser windows show the same phone layout, centered at up to 480px; there is no desktop dashboard/sidebar.
- A stable glass header and floating bottom navigation with a fixed-shape, gliding selection indicator.
- Content-only tab fade-through (70ms out / 130ms in), horizontal detail push/pop, ordinary Material tap ripples, native bottom-sheet quick actions, and a brief saved-checkmark reveal.
- Tab subtrees stay mounted. Rapid tab changes preserve planner state and use the latest selection; reduced motion skips custom animation. No page scaling, bouncing, stretching, or warping remains.
- Cream surfaces, deep green actions, muted gold accents, and quiet category colors.
- Bundled open-source DM Sans and Lora fonts; license files are in `assets/fonts`.
- Flutter Material icons and an original botanical illustration drawn with CustomPainter.
- Shared cards, labels, field styles, navigation, activity rows, progress indicators, and privacy notices.

## Source map

| File | Responsibility |
| --- | --- |
| `lib/main.dart` | App entry, responsive navigation shell |
| `lib/src/theme.dart` | Tokens, theme, date formatting |
| `lib/src/data.dart` | Sample models and observable session store |
| `lib/src/components.dart` | Shared UI components and botanical illustration |
| `lib/src/motion.dart` | Floating navbar, content fades, horizontal route transitions, save confirmation |
| `lib/src/home.dart` | Home, daily challenge, suggestions |
| `lib/src/deeds.dart` | Library, deed forms/details, references |
| `lib/src/planner.dart` | Planner and plan lifecycle |
| `lib/src/community.dart` | Groups, challenges, sharing, group impact |
| `lib/src/progress.dart` | Insights, history, impact, goals, journal |
| `lib/src/settings.dart` | Preferences, privacy, account/admin previews |
| `test/widget_test.dart` | Model, navigation, privacy, journal, and layout checks |

Feature files currently share one Dart library through `part` directives. This keeps prototype wiring simple; service integration can separate feature libraries and inject repositories.

## Verification

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --no-pub
```

Verified on 26 October 2026:

- Static analysis: no issues.
- Sixteen tests pass, including daily caps/recalculation, canonical plan/challenge completion, backdating/streaks, sharing eligibility, navigation, deed saving, shared-detail privacy, and unsaved journal protection.
- Thirteen screens render without layout exceptions at 360px and 390px widths. These checks generate PNGs in `preview/`.
- Browser preview compiles successfully and has been visually inspected.
- Android APK build attempted but blocked by this machine’s Java/Gradle error: `java.io.IOException: Unable to establish loopback connection`. Retrying with IPv4 preference produced the same result. No APK is claimed as delivered.

The checks are development verification, not formal device/security/regression QA.
