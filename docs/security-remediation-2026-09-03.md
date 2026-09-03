# Security remediation report — 2026-09-03

## Result

Three confirmed access-control flaws were fixed in the hosted Supabase project
and in the Flutter client:

1. A normal user can no longer promote their own profile to administrator,
   premium, or alter points and level.
2. Profile email addresses can no longer be selected by other clients. The
   account-existence RPC was disabled to prevent email enumeration.
3. Private journal fields can no longer be selected from public visits. The
   journal reads only the signed-in owner's private fields through a guarded
   function. Existing journal data was preserved in its original rows.

## Compatibility

- Display-name and avatar editing still use direct client permissions.
- Registration completion and trusted referral/points awards still work.
- Public experiences remain readable, including guest relation queries.
- Journal favorite updates remain owner-only.
- Public author labels now use display name and fall back to `משתמש`; email is
  never used as a public display-name fallback.

## Verification completed

- SQL attack tests passed after the hosted migrations, inside rollback-only
  transactions: protected profile writes rejected, direct private reads
  rejected, cross-user private access rejected, owner reads/updates accepted,
  trusted service permissions retained, registration/referral flow retained.
- Live REST check: public experience fields returned HTTP 200; requesting
  `journal_note` returned HTTP 401; guest public-profile relation query returned
  HTTP 200.
- `flutter analyze lib test`: no issues.
- `flutter test`: 38/38 passed.
- Flutter release web build passed.
- Firebase hosting deployment succeeded and the live bundle contains the new
  owner-only journal call.

## Remaining review items

Supabase still reports pre-existing advisory items around PostGIS placement,
leaked-password protection and several intentional privileged RPCs. They are
not the three vulnerabilities fixed here and should be reviewed separately.
Real-device Google sign-in, invitation, and tagged-photo flows still require a
manual test with actual user accounts.
