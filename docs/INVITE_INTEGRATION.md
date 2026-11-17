# Group invitation integration remaining

16 November 2026. The app still uses session-only sample groups and invite codes.
No public invite links or cross-device memberships are claimed as working.

## Required service contract

- Authenticated `POST /groups/:id/invites`: authorize current membership (regular
  members can invite), create a cryptographically random opaque token, and return
  an HTTPS invitation URL. Persist token hash, group, creator, expiry and revocation.
- `GET /invites/:token`: return a minimal preview, expiry, available capacity and
  whether the authenticated person is already a member. Do not expose the private
  member list or private deeds to unauthenticated visitors.
- Authenticated `POST /invites/:token/accept`: validate token and availability and
  join transactionally. Enforce the 20-member cap; repeated accepts are idempotent.
- Owner-controlled invite revocation/rotation. Rate limit invalid token lookups.

## App and hosting work after configuration exists

1. Replace sample group identity/membership with the authenticated repository.
2. Add Share/Copy invite link after creation and on Members for regular members.
3. Receive cold-start and foreground HTTPS App Links for `/invite/:token`.
4. Persist pending tokens across login and first-use tour. Show preview with
   Accept / Decline; never join merely because a link was opened.
5. Deploy `/.well-known/assetlinks.json` using the final application ID and Play
   app-signing SHA-256 certificate; configure `android:autoVerify` for the domain.
6. The website fallback routes Android visitors to the real Play Store listing
   with the opaque token in its encoded `referrer`. Offer an install/open fallback.
7. Integrate Play Install Referrer; consume and validate the token on first app
   open after Play installation. If unavailable, opening the original link again
   must recover the invitation. Website clicks cannot detect installation reliably.
8. Handle expired/revoked invites, deleted/full groups, existing membership,
   cancelled login, offline retries and duplicate taps.

Needed deployment values: HTTPS domain + hosting, final package ID, Play listing,
Play signing fingerprint, backend + real authentication. They are not present in
this prototype. Firebase Dynamic Links must not be used (retired August 2025).

Device acceptance matrix: installed/uninstalled, cold/warm app, logged in/out,
fresh tour/already seen tour, valid/invalid/revoked/expired token, capacity race,
and installation outside Play (original-link fallback).
