# Laffeh — Supabase setup

Phone + password auth, **no OTP / no SMS**. Accounts are confirmed automatically
so `signUp(phone, password)` returns a session immediately.

> ⚠️ Security note: with phone confirmation disabled the phone number is just a
> unique username — there is **no proof of ownership**. This is a deliberate
> low-friction trade-off. Password recovery is therefore not automatic; the app
> routes "forgot password" to WhatsApp support.

## 1. Dashboard configuration (do this once)

Authentication → Providers → **Phone**:

1. **Enable** the Phone provider.
2. **Turn OFF "Confirm phone"** (a.k.a. phone confirmations). This is what makes
   `signUp` auto-confirm the user without sending an OTP/SMS.
3. Verify a real sign-up works with **no SMS provider** configured. Some Supabase
   versions still expect an SMS provider even when confirmations are off — if
   sign-up is blocked, that is why. Confirm this before relying on the flow.

Do **not** enable Email confirmations for these users, and do not add any social
providers — the app only uses phone + password.

## 2. Run the migrations

Order matters (filenames are timestamp-prefixed):

```bash
supabase db push
```

…or paste each file in `supabase/migrations/` into the SQL editor, in order:

1. `20260723090000_init_schema.sql` — tables, constraints, triggers, indexes
2. `20260723090100_seed_use_cases.sql` — the 11 use-case options (ar/en/fr)
3. `20260723090200_save_onboarding_rpc.sql` — atomic `save_onboarding()` RPC
4. `20260723090300_rls_policies.sql` — Row Level Security
5. `20260725120000_profile_phone_and_onboarding_hardening.sql` — `profiles.phone`
   + `profiles.use_case_codes`, a profile row created at sign-up, strict
   use-case resolution, and the `profiles_overview` view
6. `20260725130000_device_locations_current_only.sql` — last-known-fix table
   (one row per `device_id`), replacing the append-only ping history
7. `20260725140000_delete_my_account_rpc.sql` — `delete_my_account()`, backing
   in-app account deletion
8. `20260727100000_terms_acceptance.sql` — `profiles.terms_version` +
   `terms_accepted_at`, the `record_terms_acceptance()` RPC, and
   `save_onboarding()` gaining `p_terms_version`
9. `20260815100000_require_name_and_company.sql` — `save_onboarding()` rejects a
   blank `full_name` / `company_name` up front (`FULL_NAME_REQUIRED`,
   `COMPANY_REQUIRED`), plus a `not valid` check so no row can be marked
   `onboarding_completed` without both

`supabase/ALL_MIGRATIONS.sql` is all of the above concatenated in order — paste
that one file if you'd rather not run them individually. Everything is
idempotent, so re-running is safe.

## 3. App configuration

Copy `.env.example` → `.env` and fill in:

```
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-public-key>
```

Use the **anon / publishable** key only. **Never** put the `service_role` key in
the Flutter app.

## Schema at a glance

| Table                | Purpose                                                              |
|----------------------|----------------------------------------------------------------------|
| `profiles`           | phone, full name, company, chosen reasons, onboarding flag           |
| `use_cases`          | seeded catalogue of usage reasons (ar/en/fr)                         |
| `user_use_cases`     | which use-cases a user picked (many-to-many, source of truth)        |
| `device_locations`   | last known fix — **one row per `device_id`**, upserted each launch   |
| `profiles_overview`  | view: one row per user with the reasons spelled out in ar/en         |

A `profiles` row is created by a trigger the moment `auth.users` gets a row, so
the phone is in the table right after sign-up — even if the user abandons the
flow before the last step. `full_name` / `company_name` are therefore nullable
until step 4 completes; from then on they are mandatory, enforced by both
`save_onboarding()` and the `profiles_onboarding_needs_name_company` check.

`profiles.phone` mirrors `auth.users.phone` and `profiles.use_case_codes`
mirrors `user_use_cases`; both are read-convenience copies kept in sync by the
trigger and the RPC, in the same transaction as the relational write.

## Policy acceptance

Creating an account requires ticking the consent box on the sign-up step, which
links to the published privacy policy and terms (see `LegalConfig` in the app).
The acceptance is stored twice: on-device, and in `profiles.terms_version` /
`profiles.terms_accepted_at` via `record_terms_acceptance()` — called right after
sign-up so the record exists even if the user abandons the profile steps.
`save_onboarding()` stamps the same columns again at the end of the flow,
preserving the original timestamp while the version is unchanged.

When the published documents change materially, bump `LegalConfig.termsVersion`
(currently the documents' effective date) so acceptances stay attributable to a
specific version.

`save_onboarding(full_name, company_name, use_case_codes[], other_text, terms_version)`
writes a whole onboarding submission in one transaction. A code that isn't in the
catalogue aborts the call (`USE_CASE_UNKNOWN`) instead of being dropped
silently — if reasons ever stop landing, that error tells you the seed
migration never ran.

## Password recovery (current limitation)

There is no automatic reset (no email/OTP channel). "Forgot password" opens
WhatsApp support. The auth layer is structured so a real recovery flow can be
added later (e.g. enabling OTP) as a configuration change, not a rewrite.
