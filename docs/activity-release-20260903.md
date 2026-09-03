# Activity and participant invitation update

- Personal activity uses a people icon and an unread dot; the activity screen
  includes Home and keeps notification cards tappable without chevrons.
- Home search is immediately to the right of AI, on desktop and mobile.
- Shared-response authors cannot add participants when creating or editing their
  experience. Their own notes, images, hashtags and ratings remain independent.
- Supabase migration `20260903115719_restrict_participant_invitations` is applied.
  The server assigns an immutable `is_shared_response` flag, preserved after
  deletion of the original experience. Restrictive tag policies cover direct
  writes and both sync RPC overloads; original-author invitations and self-untag
  remain supported.

Verification: 28 Flutter tests passed; `flutter analyze lib test` clean. SQL
regressions in `supabase/tests/shared_visit_experiences.sql` passed inside a
rolled-back transaction before and after applying the migration. No new
Supabase security-advisor findings relative to the existing baseline.

Hosting remains Firebase project `foodiary-91a6b`, public directory `build/web`,
base href `/`. No Git push or Hosting deployment was performed by the agent.
GitHub Pages builds use their own `/food_diary_new/` base href; do not deploy
that build directory to Firebase.
