# UI implementation status

## 9 November 2026: document-backed deed matching catalog

The 50 deeds supplied in `50 Good Deeds Directed in the Holy Quran.doc` now
replace the one sample matching rule. Stable source IDs, references and authored
English/Bengali/Banglish matching phrases are generated from a single JSON
catalog. A provisional 0.80 highest-score threshold retains the explicit
Request a review path for non-matches. Added reproducible synthetic seed splits,
fine-tuning/evaluation tooling and catalog/flow checks. Actual training remains
blocked by package-index DNS resolution; model assets and real device accuracy
are still outstanding. See `OFFLINE_MATCHING.md` for commands and exact limits.

## Latest update: free-text logging and offline review

The user replaced template-first logging with free-text deeds, Android on-device semantic matching, zero points for non-matches, and an admin request/acceptance flow. The new UI, session-state review lifecycle, point eligibility rules, and Android ONNX adapter source are implemented. Actual model assets, device inference validation, persistence, and remote admin synchronization remain outstanding. See `OFFLINE_MATCHING.md` for the current scope and limits; the first-pass notes below are historical.

26 October 2026 — first connected UI prototype.

## Completed for this pass

- Flutter project isolated in `deedwise_app` with Android and web targets.
- Shared visual tokens, bundled fonts, components, responsive navigation, and original botanical artwork.
- Connected main destinations and personal deed/planner/journal/goal workflows.
- Sample-data groups, challenges, explicit sharing, invitation preview, and owner event controls.
- Profile/preferences/privacy and account/admin presentation.
- Nine passing tests and compact-phone screen previews.
- Successful web build and local preview server.

## Next implementation pass

1. Collect visual feedback on the anchor screens before further styling changes.
2. Complete personal people-helped input and group event participant association.
3. Add integrated account confirmation, session recovery, and sign out after Supabase setup.
4. Replace the in-memory store with persisted, repository-backed data and enforce access policies.
5. Move point calculation, idempotency, participation-day rules, and closed challenge snapshots to authoritative backend operations.
6. Complete rule-based recommendations using time, spending preferences, and history.
7. Connect Android notification permission, local scheduling, and reminder deep links.
8. Connect approved templates/references and role-protected admin publishing.
9. Implement service-driven loading, retry, stale-data, permission-denied, invalid/full-group, and account-error states.
10. Resolve the Java/Gradle loopback issue, build an APK, and inspect real Android devices and large text settings.

## Review path

Home → Add deed → Template → Record → Confirmation → Private detail → Reflection.

Planner → Plan → Detail → Complete → Same deed/history pipeline.

Community → Group → Challenge → Opt in → Share a completion → Visibility preview → Ranking.

Progress → History / Insights / Personal impact / Goal / Private journal.

Settings → First-use preview / Preferences / Reminders / Privacy / Admin preview.

## Important distinction

This is an interactive UI implementation, not a production-complete V1. Authentication, durable storage, real notifications, content publishing, and backend access/scoring verification are outstanding. The parent implementation plan remains the full target scope.
