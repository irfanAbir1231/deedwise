# Supabase implementation — first delivery

17 November 2026. Project `mvzciwiurhyqhumchlyx`. Free-plan scope; no paid services
or add-ons were enabled by the agent.

## Implemented

- Official Supabase Flutter SDK and pure Dart repositories. Public configuration
  is in gitignored `config/supabase.local.json`; no database password, secret key,
  service-role key or Google client secret is in the app configuration.
- Google OAuth with PKCE, Android callback `deedwise://login-callback/`, restored
  sessions and device-local sign-out. SDK logs are disabled.
- Connected builds show Google login at startup after the first-time introduction.
  Restored sessions open Home directly; Profile contains Log out, which returns
  to the entry login screen.
- Profile-name repository and an account panel in Settings. Connected builds use
  the real groups UI and hide demo administration/local contribution controls.
- Private local deeds, preferences, review records and photo references are scoped separately
  for guest and each account. Switching accounts saves the previous scope, blocks
  access to old-account screens during the transition and restores the selected
  scope. Guest records are preserved; they are not silently uploaded/imported.
- Repository-backed group list/create/details, persistent goals, member names,
  owner-controlled removal and member leaving. The owner must remain in the group.
- Ordinary members can create invite codes. Codes are cryptographically random,
  stored only as SHA-256 hashes, expire after seven days, and can be revoked by
  their creator or the owner. Leaving/removal revokes that member's outstanding
  invitations. Preview does not join. Accept is explicit and repeat-safe.
- Membership cap is enforced while locking the group row. Group creation retries
  use a per-owner operation UUID. Creation and invite attempts are rate limited.
- All group writes go through permission-checked functions. RLS protects profiles,
  groups and member lists. Anonymous callers cannot invoke group RPCs. Private
  invitation/rate-limit tables have no client grants.
- Android native text sharing for invitation codes, plus copy fallback. This is
  a real cross-device invite-code flow, not a published HTTPS invitation link.

## Deployment confirmed

The user ran the reviewed migration files in the project SQL Editor:

1. `supabase/migrations/202611170001_accounts_groups.sql`
2. `supabase/migrations/202611170002_explicit_function_permissions.sql`

The second migration explicitly revokes direct anonymous function grants that
Supabase default privileges can otherwise retain. Authentication checks already
blocked private data in the first migration; the second narrows the RPC surface.

Live checks through the SDK returned:

```json
{"schema_version":1,"security_revision":2,"google_enabled":true,
 "auth_settings_status":200,"anonymous_group_rpc_blocked":true}
```

Browser automation was stopped when it could not verify the current browser URL.
It was not used to change the project. Direct management tools were not exposed;
the user completed SQL/provider setup manually. Only public status/settings APIs
were used for the live checks; no private user records were downloaded.

## Verification and artifact

- 34 targeted Flutter tests passed, including startup login, restored-session
  routing, profile logout visibility and narrow-screen login layout: repositories, account separation, preserved
  navigator during account transitions, startup/profile, moderation and sharing.
- Full Flutter suite: 61 passed, the same 3 existing tour/navigation/legacy-sharing
  failures remain. No new full-suite failures were observed.
- Embedded PostgreSQL workflow test passed with Supabase-like default function
  grants: real SQL RLS/permissions, non-member access, ownership escalation,
  duplicate create/accept, member invites, revoke/leave, capacity and rate limits.
  This single-connection test does not prove hosted multi-connection race behavior.
- Analysis: only the same three informational notices from existing web/CLI code.
- Supabase-connected Android ARM64 debug and web release builds succeeded.
- Compiled Android artifact was checked for the supplied public Supabase project
  configuration and the user's already-authorized Groq configuration without
  printing key values.

APK: `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.
Build: `./tools/build_backend_android.ps1`.
Readiness: `dart run tools/check_supabase.dart`.
Database tests: `npm test --prefix tools/backend-tests`.

The updated startup-login APK was installed successfully on the connected Redmi
phone. A cold launch restored the existing session and displayed Home. Entry
login/session routing and Profile Log out visibility pass widget tests. Manual
phone logout/re-login and the real two-account group flow still need verification;
Android blocks injected taps, so the agent could not navigate Profile on the phone.

## Not yet implemented

- Server deed moderation/Groq, authoritative public points, group contributions,
  competition snapshots and remote admin reviews. Existing private matching still
  uses the explicitly authorized direct Groq path; local points are not uploaded
  as trusted public points.
- Private deed/journal/planner cloud sync, guest import and a durable SQLite
  outbox. Local data stays on the device; existing prototype session-only features
  are not claimed to be cloud-persistent.
- Account deletion with ownership transfer, full production abuse/backup recovery
  verification, and multi-connection hosted concurrency tests.
- HTTPS invite landing site, verified App Links, Play Store fallback and deferred
  invitation recovery. No placeholder link is presented as a working public link.
- Cross-device profile photos. All deed/profile photos remain local; only an
  explicitly exported card includes selected photos outside the app.

See `SUPABASE_SETUP.md` for configuration and `docs/BACKEND_ROADMAP.md` for the
remaining rollout. The current delivery is the real accounts/groups foundation,
not a claim that every planned backend feature is complete.
