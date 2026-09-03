# Shared experiences and tag notifications — 2026-09-03

## Scope and deployment

- Approved Supabase migrations: `20260903104726_shared_visit_experiences` and
  `20260903105515_preserve_removed_participant_tags`.
- No Git commit/push or Firebase/GitHub Pages deployment in this task.
- In-app notifications only: refresh on entering/resuming the home screen,
  every 30 seconds while active, and after returning from notifications.
  The notifications list also supports pull-to-refresh and paginated history.
- Existing tags are discoverable; unchanged tags retain their read status.

## Data and authorization

- An outing groups independently owned `visits`; one experience per author per
  outing. The server derives the group and initial visit date from a valid source
  experience and checks the participant's tag and matching place.
- Deleting a source sets the source reference to null, preserving the other
  experiences and their outing. Deleting a tag removes its read receipt only.
- Recipient read receipts are protected by RLS. Only recipients may mark their
  own notifications read or remove their own tags.
- Ordinary users cannot modify another user's experience. The experience UI
  presents edit/delete/favorite controls only to the author. Existing database
  administrator moderation privileges are retained, not silently removed.
- Group queries explicitly select public experience fields, excluding private
  journal notes. Personal recommendation queries remain scoped to each user's
  own visits/feedback; tagging alone creates no taste preference or rating.
- Participant edits use an original-selection snapshot: saving a stale editor
  cannot restore a tag removed by its recipient.

## Verification

- `flutter analyze lib test`.
- `flutter test`: includes existing hashtag tests and notification navigation,
  blank personal form, independent save, own edit/delete controls, linked display,
  self-untagging, mobile header, unread badge, error/retry, and RPC scoping tests.
- Result: all 25 tests passed; the 6 shared-experience flow tests also passed in
  Chrome. Browser tests disable session persistence and auth deep-link handling
  for the mocked session; production authentication settings are unchanged.
- SQL regression test: `supabase/tests/shared_visit_experiences.sql`, always run
  inside `BEGIN`/`ROLLBACK`. All fixtures and points awarded by existing triggers
  roll back; no test experiences or user notifications persist.
- SQL checks cover unauthorized joins, mismatched place, duplicate membership,
  ownership/group reassignment, cross-user edit/delete, private receipts,
  stable tag IDs, self-removal, stale edits, source deletion, and own deletion.
- Public REST query with the new embedded experience fields returned HTTP 200.
- Security-advisor comparison before/after: no new findings introduced.

## Existing security findings, outside this feature

The project already has findings concerning the PostGIS public-schema extension,
publicly callable privileged functions (including `check_email_exists`), and
disabled leaked-password protection. This task does not constitute a full
security audit or resolve those existing findings. Review before a broad launch:

- [Public privileged functions](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
- [Extensions in the public schema](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)
- [Leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

## Manual acceptance

1. Run the local app and sign in as an experience author; tag another user.
2. Sign in as that participant in another browser profile. Open the home-screen
   notification and confirm it identifies the author and place.
3. Choose “החוויה שלי מהביקור”. Add personal ratings, notes, hashtags and photos;
   save. Verify the personal journal entry and “חוויות מאותו ביקור”.
4. Confirm that the author's edit/delete controls are absent, while the
   participant can edit/delete their own experience.
5. Remove the participant's tag, then save an author editor opened before the
   removal. The tag must stay removed and the personal experience must survive.
6. Delete the original experience and confirm the participant's entry survives.

Actual image picking/upload and acceptance with two independently signed-in
devices remain manual checks; automated UI tests use a mocked network.
