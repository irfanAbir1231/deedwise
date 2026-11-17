# Local feature implementation report

Updated 17 November 2026 (Asia/Dhaka).

## 17 November follow-up: immediate sharing and compact cards

Save and check now replaces the editor with the deed details page, including a
saved confirmation, points/review details and a prominent Share as a card button.
A share icon is also always available in the details app bar. The intermediate
result page and extra View this entry tap are no longer part of the save flow.

Cards remain 430 logical pixels high with or without photos. A deed photo is
center-cropped with BoxFit.cover into a 108px rounded strip. Its right edge blends
into a softly blurred, sage-tinted fade; only the image is blurred. Profile photos
remain opt-in in the upper-right corner. A portrait fixture was rendered and
visually inspected to verify cropping and unchanged card dimensions.

Verification: 20 targeted tests passed, including direct save-to-details routing,
sharing after an awarded match, retained unmatched assessment details and fixed
card size after enabling both photos. Analysis has only the same 3 informational
notices. The authorized Groq-integrated ARM64 debug APK rebuilt successfully.

## 17 November follow-up: profile, splash and app introduction

Current-user avatars now share one reactive `ProfileAvatar` in persistent tab
headers, Settings, group member lists and the leaderboard. Saving a profile photo
notifies the mounted header without reopening the app. Card photo inclusion
remains separately opt-in.

The original geometric D/check mark replaces the old generic leaf branding in
app headers, account/first-use screens, cards, group join branding, Android
launcher/adaptive icons, Android splash and browser icons/loading screen. Its
editable source is `assets/brand/deedwise-mark.svg`; `tools/build_brand.py`
reproducibly generates all platform variants from the same vector geometry.
No image-generation service was used for this code-native logo.

Android light/dark startup themes now use cream backgrounds; Android 12+
splash attributes use the same logo. Flutter draws a branded loading screen
before reading preferences, and the browser shows its own loading background
until the first Flutter frame. Initialization errors offer retry.

Three first-use introduction pages explain recording, habits/progress and
optional sharing/privacy. Continue, Back, swipe and Skip are supported. Completion
is persisted independently of guided-tour state; returning users bypass the
introduction. It does not force fake account creation.

25 targeted tests passed, including first-use/returning startup, intro persistence,
all intro screens at 360px with larger text, live avatar refresh in a cached Home
header, photo-card sizing and the deed save/share path. Native Android and web
builds succeeded; analysis reports only the same three informational notices.
Full regression suite: 55 passed with the same 3 existing failures. The backend
proposal is in `docs/BACKEND_ROADMAP.md`; no cloud resources were created or user
data uploaded. The first phone installation attempt was rejected with
`INSTALL_FAILED_USER_RESTRICTED`. After the user confirmed readiness and approved
the device prompt, retry installation succeeded. A cold start of
`com.example.deedwise/.MainActivity` returned `Status: ok`, and the app process
was verified running. Existing app data was preserved by installing with `-r`.

## Completed

1. **First-use tour:** `tour_seen_v1` persists before the tour starts. Startup
   waits for local preferences; Skip does not cause a later automatic replay.
   Settings replay remains available. Clearing app data resets first-use state.
2. **Language validation:** 52 curated English/Bengali source entries plus
   supplementary English inflections/Bengali/Banglish variants. Case, common
   substitutions, zero-width characters and separated English letters are handled.
   Whole-word matching avoids innocent substrings. Both Save and Just save, edits,
   store saves and card captions enforce checks. Existing blocked entries cannot
   earn points. Attribution/licenses are in `assets/moderation/`.
3. **Harmful deed detection:** explicit local harmful-action checks reject the
   supplied English/Bengali/Banglish examples before any network request. Groq
   now requires a boolean harmful decision for the whole narrative, overriding
   even a high-confidence positive catalog match. Offline descriptions needing
   context cannot earn automatic points. This is an initial rule layer plus a
   semantic classifier, not exhaustive or proven production detection accuracy.
4. **First-person cards:** 50 authored completed-action captions, including
   “I gave voluntary charity from my wealth.” Free-text personal narratives are
   preserved instead of inventing a claim from a nearest prediction. Captions
   are editable; preview, exported PNG and copied text use the same caption.
5. **Local profile photo:** choose/change/remove in Settings. Cards have an
   opt-in toggle, initially off, and place the photo in the top-right corner.
6. **Local deed photo:** camera/gallery on Android, gallery on web. Deed editor
   supports add/replace/remove; card inclusion is separately opt-in and off by
   default. Photos resize to at most 1400px, re-encode to JPEG, and strip source
   EXIF/GPS. Selection limits are 20MB / 40 megapixels. Android camera permissions
   are handled by delegating to the external camera application; no broad storage
   permission is requested.
7. **Persistence:** deed records, review requests, participation dates, profile
   photo reference and deed-photo references persist locally. Android photo
   files use app-private support storage; web embeds processed image data in
   browser-local storage. No photo bytes are included in Groq requests or a
   backend request. Android application backup is disabled. Removing/replacing
   photos and discarding editor drafts clean up their owned local files.

Groups, planners, journals and other prototype features still use session data.
Only the listed data is persisted; there is no account/cloud synchronization.

## Verification

- Targeted tests: **20 passed**, including 9 new local feature tests.
- Full suite: **50 passed, 3 existing failures** in
  `test/widget_test.dart`: rapid-tab navigation under the first-use tour,
  navigation under the tour, and the older neutral-label group-sharing expectation.
  The new failures found during implementation were corrected. No unrelated
  group-sharing behavior was changed to make the legacy test pass.
- Analysis: no errors/warnings; 3 existing informational notices (`dart:html`,
  web-only library usage and the older `tools/check_groq.dart` relative import).
- Android debug and ARM64 debug APKs built successfully. Kotlin plugin cache
  warnings about different C:/D: roots fell back to non-incremental compilation.
- Browser release build succeeded.
- Card rendered and visually inspected at 360px with real fonts and synthetic
  images. `preview/share-card-with-photos.png` is the resulting layout preview.
- Existing configured Groq service checked with five synthetic examples:
  ordinary help, harmful English help, harmful Bengali help, assault without
  the “kill” keyword, and preventing a killing. All produced the intended harm
  classification; the prevention case needed one retry after an unavailable
  response. These are smoke checks, not an accuracy benchmark.
- Physical-device camera/gallery, Android interruption/recreation and install
  upgrade testing still need device QA. The native handlers compile; this
  report does not claim those flows were exercised on a physical phone.

## Installable build

`build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`

On 17 November, the user explicitly requested direct Groq integration after
being informed that an embedded key can be extracted from an APK. The current
ARM64 debug APK includes the existing key from the gitignored local configuration.
No backend or user-entered key is needed for matching in this build. Online
matching requires internet access and a valid key/provider quota; offline fallback
remains available.

The APK built successfully and its compiled kernel was checked for the configured
key in memory, printing only a boolean verification result. The key was not printed
or copied into source files. Live HTTP 200 smoke checks confirmed ordinary help
matches quran-19 and harmful help is rejected. This verifies service access from
the developer machine, not the phone network or general classifier accuracy.

The earlier key-free build has been superseded at this path. Automatic approval
review had rejected embedding the key before the user's explicit authorization;
the newly authorized build subsequently succeeded. Keep this credential-bearing
build private.

## Remaining: real shareable invitation links

Not implemented as a fake link: groups are sample/session-only and the app has
no real authentication, group API, owned invite domain or Play Store identity.
No link can currently join a group on a second phone.

`docs/INVITE_INTEGRATION.md` specifies the API contract, regular-member invite
permissions, Accept/Decline flow, pending-token persistence, verified App Links,
website-to-Play fallback and Install Referrer recovery after installation.

Needed: persistent backend + authentication, HTTPS domain/hosting, final Android
application ID, Play Store listing and Play app-signing SHA-256 fingerprint.
Once available, the app UI, incoming-link routing and deferred invitation flow
still need implementation and end-to-end verification.

## Reproducible checks

```powershell
flutter test --no-pub test/local_features_test.dart test/catalog_matching_test.dart test/groq_matching_test.dart
flutter analyze --no-pub
flutter build web --no-pub
```

For this Windows machine, Java's sandbox temp directory is too long for its local
socket paths. Use Android Studio's Java 21 runtime and a workspace temp directory:

```powershell
$env:JAVA_HOME = 'D:/app2/androidStudio/jbr'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$taskTemp = (Resolve-Path '.build-tmp').Path
$env:JAVA_TOOL_OPTIONS = '-Djava.io.tmpdir="' + $taskTemp + '" -Djdk.net.unixdomain.tmpdir="' + $taskTemp + '"'
flutter build apk --debug --split-per-abi --target-platform android-arm64 --no-pub
```

These environment overrides apply to that shell; system Java settings were not
changed. The command above makes a key-free APK. To reproduce the specifically
authorized Groq-integrated private build, use `./tools/build_groq_android.ps1`
with the existing gitignored configuration. That script applies the workspace
temporary-directory workaround and adds a fresh build revision to prevent stale
compiled configuration. Do not share this credential-bearing APK publicly.
