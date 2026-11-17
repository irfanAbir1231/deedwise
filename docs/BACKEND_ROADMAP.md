# DeedWise backend rollout

17 November 2026. This is a proposed plan; no cloud project was created, no data
was uploaded, and no subscription, hosting purchase or production deployment was
performed in this change.

## Budget constraint: free for as long as practical

The user prioritised keeping backend hosting free on 17 November 2026. Start on
Supabase Free; do not provision a VPS, upgrade plans or enable paid add-ons as
part of implementation without a new user decision. Develop locally and use one
hosted pilot project initially. Free quotas are operating limits, not a promise
of supporting a fixed number of active users indefinitely.

Current published Free inclusions checked on that date: 500 MB database,
50,000 monthly active users, 5 GB egress, 1 GB file storage and 500,000 Edge
Function invocations. Free projects can pause after one week of inactivity;
two active free projects are allowed. Recheck pricing before deployment.

Revise the initial email-OTP proposal: prefer Google sign-in for the pilot so it
does not depend on SMS or transactional email delivery. The built-in Supabase
email sender is restricted and is not a public-user production email service.
Email OTP can be added with an appropriate SMTP provider and its own quota.

Keep photos/card generation on-device; paginate history, cache catalog data and
assessments, use realtime only on the open group, and avoid repeated whole-group
reads. Rate-limit Groq by account and globally; when quota is exhausted, keep
entries pending instead of silently activating paid usage or awarding unverified
public points. Groq limits are separate from Supabase limits. An invitation
landing site can initially use a suitable free hosting subdomain; a purchased
custom domain is optional and has a separate cost. Verified Android App Links
still require control of the selected host and its association file.

For comparison, Firebase Spark has free Auth/Firestore usage, but the proposed
Firebase Cloud Functions deployment requires Blaze billing. Blaze includes free
allowances, so it does not imply an immediate charge; it is nevertheless a
billing-enabled setup rather than the initial zero-budget default chosen here.

Sources: https://supabase.com/pricing ;
https://supabase.com/docs/guides/auth/auth-smtp ;
https://firebase.google.com/pricing ;
https://console.groq.com/docs/rate-limits

## Recommended starting architecture

Use managed Supabase for PostgreSQL, authentication, row-level access policies
and realtime updates. Use authenticated server functions for invite acceptance,
moderation/matching and authoritative points. The Flutter app keeps an offline
cache; shared membership and progress come from the server.

Managed hosting is the initial recommendation to keep database/auth operations
small while the product is evolving. Choose a project region near the actual
users after checking available regions and latency. Use separate development
and production projects. The invite website needs an owned HTTPS domain.

Supabase also supports Docker self-hosting. If owning the server becomes a firm
requirement, a VPS deployment is possible, but then database upgrades, TLS,
backups/restores, monitoring, email delivery and incident recovery become our
responsibility. Keep SQL migrations and repository contracts portable from day
one; moving managed Auth/functions/storage still requires a planned migration.

## Stage 1: identity and real shared groups

1. Separate `DeedStore` from repositories. Provide a local implementation and a
   remote implementation behind the same interfaces; preserve the current UI.
2. Add real email OTP login and session restoration. Introduce `profiles` with a
   stable auth user ID and display name. Replace sample member names with IDs.
3. Add persistent groups, memberships, goal definitions and member roles.
4. Enforce member-only reads, owner-only management, a transactional 20-person
   membership cap and unique `(group_id, user_id)` membership.
5. Implement invitation creation for ordinary members as well as owners. Store
   opaque token hashes with expiry/revocation and check permissions server-side.
6. Deploy the invitation landing route and Android verified App Links, followed
   by Play Install Referrer recovery. Preserve a pending invitation through
   login/onboarding. Accept is explicit and idempotent.

Deliverable: user A creates a group and user B, on a different phone, joins it
from the invitation and sees the same members and goals after reopening the app.
Full details: `INVITE_INTEGRATION.md`.

## Stage 2: personal records, matching and trustworthy group progress

- Tables: `deeds`, `deed_assessments`, `review_requests`, `point_ledger`,
  `group_contributions`, `group_events` and `group_goals`.
- Deeds and journals belong to their authenticated author. RLS prevents other
  members from reading private narratives, quantities, photos and reflections.
- A group reads only explicitly shared contribution data: approved activity,
  selected caption/label, points and quantities the user chooses to share.
  Preserve a separate private record; never make group membership grant access
  to the private deed table.
- Run moderation and Groq from an authenticated server function. Validate the
  exact deed revision; keep the Groq key in server secrets when this endpoint
  goes live. The currently authorized embedded-key build remains as it is until
  that migration; switching to the backend is a separate release.
- The client must not be able to set awarded points, approval flags or roles.
  Server-side operations award/revoke points transactionally, enforce day caps,
  and ensure old edited revisions cannot leave duplicate awards. Use a unique
  operation ID plus deed revision for retries and keep an auditable ledger.
- Relevant, accepted, explicitly shared deeds alone count towards group goals.
  Linked events reference contributions instead of adding their quantities a
  second time. Freeze closed competitions with defined historical snapshots.
- Private offline entries remain writable. Public/leaderboard points are only
  confirmed after server processing; a local optimistic result is not authority.
- Admin approval uses server-managed roles and an audit trail. The demo admin
  toggle is never an authorization mechanism.

Deliverable: two different accounts see consistent contributions/progress, and
editing/retrying a deed cannot multiply public points.

## Stage 3: offline reliability and local-data migration

- Move the growing shared-preferences snapshot to a local SQLite repository.
  Use stable UUIDs, an account-scoped outbox, tombstones and revision/version
  checks for create/update/delete sync. Retry safely after disconnections.
- Ask before attaching existing guest data to the first real account. Import
  only real user records, excluding sample/demo entries. Keep an export/rollback
  path and do not delete the original cache until the server acknowledges it.
- Account switches must not upload one person's pending records to another
  account. Public membership/points conflicts use server authority; concurrent
  private text edits retain a recoverable copy instead of silent overwrite.
- Deed photos stay on the original device under the user's existing requirement.
  They do not enter the database, API payload, object storage or Groq request.
  A synced deed on another device can therefore have no local attachment.
- The current profile photo also stays local. If members later need to see each
  other's avatars or users want cross-device avatars, add a separate opt-in
  profile-photo upload with storage policies; do not silently upload old photos.

## Production readiness

Before inviting real users: test access with two accounts, remove demo data from
the production experience, verify expired/revoked/full invites and concurrency,
rate-limit matching/invite endpoints, configure email delivery, and validate
backup restoration and account deletion. Avoid secrets and deed text in routine
logs. Set usage/spend alerts. Pick a paid capacity tier from measured concurrent
users, database load and Groq usage rather than guessing a fixed monthly cost.

## Inputs needed when Stage 1 is authorized

- Supabase project ownership/connection and chosen hosting approach.
- Production invite domain and DNS/hosting access.
- Final Android package ID, Play Store listing and signing certificate hash.
- Authentication choice confirmation and email-delivery configuration.

The current work implements local avatar/branding/startup improvements only.
It does not pretend local sample groups are a working multi-user service.

## Official references

- Flutter setup: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Auth: https://supabase.com/docs/guides/auth
- RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Authenticated functions: https://supabase.com/docs/guides/functions/auth
- Self-hosting: https://supabase.com/docs/guides/self-hosting
- Docker self-hosting: https://supabase.com/docs/guides/self-hosting/docker
