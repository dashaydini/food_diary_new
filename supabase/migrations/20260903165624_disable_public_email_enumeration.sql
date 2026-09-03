-- Authentication must not reveal whether an arbitrary email owns an account.
-- Timestamp matches the applied hosted migration.
revoke all on function public.check_email_exists(text) from public, anon, authenticated;
