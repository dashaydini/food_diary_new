# Focused pre-launch review — 2026-09-03

Status: the three confirmed data-access blockers were remediated on 2026-09-03.
The compatible web client was deployed to Firebase immediately after the
database restrictions, and the live bundle was verified from the hosting URL.

## Resolved release blocker

Ordinary authenticated users can update sensitive columns on their own
`profiles` row, including `role`, `admin_role`, `is_premium`, and `points`.
The existing own-profile UPDATE policy restricts rows, not columns. Existing
profile triggers do not prohibit those changes. `is_admin()` trusts `role`.

Originally confirmed in a BEGIN/ROLLBACK transaction using a newly generated temporary
auth identity: an ordinary user could update its own role to admin, and
`is_admin()` then returned true. The transaction, temporary identity, profile,
and role update were rolled back. No production user's privileges were changed.

Remediation applied: clients can now write only profile identity/onboarding
fields. Authority, premium state, points, level, referral ownership and email
are no longer client-writable. Trusted server operations remain permitted.

Direct profile email reads and private journal-column reads were also removed.
The journal now obtains private fields through an owner-bound function which
does not accept an owner ID. Existing values stayed in place; no journal data
was deleted or copied.

## Additional focused findings

- Public visits remain visible, but `journal_note`, `with_whom` and
  `favorite_memory` are no longer directly readable by clients.
- Profile email is no longer client-readable. Public identity queries use only
  display name and avatar.
- `check_email_exists` can no longer be called by anonymous or signed-in clients;
  login now returns a generic email-or-password error.
- Leaked-password protection is disabled; enablement/plan availability remains
  to be checked. It does not protect Google-provider passwords.
- PostGIS is in public schema and its reference table lacks RLS. Assess required
  grants without moving the extension blindly or breaking map queries.
- Two GitHub Pages workflows run on main pushes. Consolidation is recommended
  to avoid competing releases but was not changed as part of this read-only audit.

## Acceptance-test limits

38 local Flutter tests, static analysis, rollback SQL attack tests, a release
web build, live REST checks and a Firebase deployment passed after remediation.
These are not a real Google-account or Android upload test. Real
sign-in, invitation points and two-device tagged image upload still require
explicit user participation after a safe deployment. Do not mark them completed
based on mocked tests or rolled-back database checks.
