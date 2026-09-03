# Google registration completion

New Google accounts receive `profiles.registration_completed = false` from the
existing auth-user creation trigger. Existing accounts retain `true`, as do new
email registrations. The provider comes from server-managed app metadata;
user-supplied metadata is used only for the initial display name, never roles.

After authentication, AuthGate checks the profile before showing app content.
Incomplete profiles must confirm a display name and may enter an invitation
code; signing out is available. A refresh/relogin still requires completion.
Completed profiles and guest browsing keep their existing flow. This onboarding
flag is not an authorization boundary or a replacement for the existing RLS.

The invoker RPC `complete_google_registration` locks the caller's profile and
atomically applies the invitation and saves the name/completion flag. Invalid
codes roll back completion. Retrying a completed request does not award points
again. The frontend no longer applies pending invitations to incomplete users.
Invitation URLs are captured before auth initialization, and the OAuth `code`
parameter is not interpreted as a referral code.

Migration applied with approval:
`20260903162352_google_registration_completion`.

Verified: `flutter analyze lib test`; 35 Flutter tests; 7 Chrome registration
tests; rollback-only SQL tests before and after migration. Security-advisor
comparison found no new findings. Existing unrelated findings remain.

To manually test the new screen, use a Google account never registered in this
project. Existing accounts intentionally skip completion. No real Google OAuth
login was performed by the agent; auth events were mocked in frontend tests,
and temporary auth records in SQL tests were rolled back.

No Git push or Firebase deployment was performed for this change.
