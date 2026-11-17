# Supabase phase-one setup

Project: `mvzciwiurhyqhumchlyx` (`https://mvzciwiurhyqhumchlyx.supabase.co`).
Stay on the Free plan. No database password, service-role key, Groq key or Google
client secret belongs in chat or in the Flutter public configuration.

## Current project status — setup completed

The user has applied migrations 001 and 002 and enabled Google. Live SDK checks
confirmed schema version 1, security revision 2 and blocked anonymous group RPCs.
Do not rerun the initial CREATE migration on this configured project. The setup
steps below are retained for reference; phone login and the two-account group
flow are the remaining verification steps. See `BACKEND_IMPLEMENTATION_STATUS.md`.

## Prepared locally

- The supplied project URL and publishable key are saved in gitignored
  `config/supabase.local.json`. The Auth settings endpoint accepted this public
  key (HTTP 200). The OpenAPI schema listing requires a secret key and was not
  used to read records.
- `supabase/migrations/202611170001_accounts_groups.sql` creates the profiles,
  groups, memberships and private invitation tables, row-level policies and RPCs.
- Local PostgreSQL tests verified account isolation, ownership protection,
  retry-safe creation, preview-before-join, revocation, departed-member invites,
  the 20-member cap and invalid-code rate limiting.
- The Flutter build supports Google OAuth, the mobile callback, account-separated
  local records and real group/invitation API calls.

## Manual action 1: run the tested migration

Direct Supabase management tools are not exposed in this chat. Browser automation
also stopped because it could not reliably verify the current browser URL, so it
was not used to change the project. A publishable key intentionally cannot create
tables, change policies or configure authentication.

1. Open https://supabase.com/dashboard/project/mvzciwiurhyqhumchlyx/sql/new .
2. Open the local file `supabase/migrations/202611170001_accounts_groups.sql`.
3. Copy its complete contents into a new SQL query and click **Run** once.
4. Confirm the query completed successfully. If a table already exists or any
   error appears, stop and share the error text; do not drop existing tables.

The migration is transactional and non-destructive to existing user records.
It is an initial migration, not an idempotent script to rerun after success.
Deployment was verified with `backend_status()`. Migration 002 (`202611170002_explicit_function_permissions.sql`) must follow migration 001 for explicit function permissions; both have already been applied to this project.
If later switching to Supabase CLI migration management, mark this already-run
migration as applied before `db push`; do not run its CREATE statements twice.

## Manual action 2: enable Google login

The project’s public Auth settings now report Google enabled. These are the setup steps used.

1. In Google Cloud, create/select an OAuth project and configure the consent
   screen for the DeedWise application, using only the basic name/email/profile
   scopes. Add intended testers if the app is in Testing mode.
2. Create a **Web application OAuth client** for the browser-based OAuth flow.
3. Add this Google authorized redirect URI:
   `https://mvzciwiurhyqhumchlyx.supabase.co/auth/v1/callback`.
4. In Supabase → Authentication → Sign In / Providers → Google, enable Google
   and enter the Google client ID and client secret there. Keep the secret in
   that dashboard; do not put it in Flutter or chat.
5. In Authentication → URL Configuration → Redirect URLs, add:
   `deedwise://login-callback/`.
6. Save the settings. No SMS or email-OTP provider is needed for this first pass.

The app already declares that custom Android callback and uses PKCE. This does
not implement HTTPS invitation links or Play Store deferred invitations yet.

## Build and test after the manual actions

```powershell
./tools/build_backend_android.ps1
```

This embeds only Supabase's public configuration. It retains the user's already
authorized direct Groq configuration until phase-two server matching is ready.
It does not embed a Supabase secret/service-role key or Google client secret.

On two devices, use two different Google accounts:

1. A signs in, creates a group and a goal, then creates and shares an invite code.
2. B signs in, pastes the code, views the preview, then explicitly accepts.
3. A refreshes the group; both devices must show the same members and goal.
4. Check duplicate acceptance, revoked/expired invites and owner-only removal.
5. Sign out and use the other account; private local records/photos must not
   cross over. The guest device data is preserved and is not uploaded.

Google login end-to-end and hosted concurrency still need this real-project
test. Local SQL tests do not substitute for provider login or multi-connection
hosted concurrency tests.

## Scope of this first pass

Connected now in code: accounts/profile names, group creation/listing/membership,
goals, invite codes, explicit acceptance, revocation, removal and leaving.

Still next: server deed moderation/Groq, authoritative public points and group
contributions, private deed sync/import, account deletion/owner transfer,
HTTPS invitation landing page/App Links/Play Install Referrer and optional avatar
uploads. Deed photos remain on-device. Existing local/demo groups are not
silently uploaded or turned into real memberships.

References:
- https://supabase.com/docs/guides/auth/social-sign-in/auth-google
- https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- https://supabase.com/docs/guides/database/postgres/row-level-security
