# Backend environment protection

## What is protected

- `local`: no Supabase configuration is allowed. Only non-release builds may use local preview data. A permanent header says no cloud data is saved.
- `staging`: a separate hosted test project, explicitly configured with its Project ID. A permanent header says changes ARE saved to staging, including on pushed pages/dialogs. Release staging builds are permitted for device testing.
- `production`: real users' project. Only release builds with `ALLOW_PRODUCTION_BACKEND=true` are permitted. No preview bypass is available.
- Before initializing persistent Supabase Auth, a temporary anonymous client calls `get_app_environment`. Both administrator-owned environment and Project ID must match the build. Missing migration, an unassigned marker, mismatched settings, network failure or timeout blocks startup; it never falls back to mock data. The probe exposes only the non-secret environment name and Project ID.

The client key is not a security boundary. RLS and server-side business rules remain necessary. Environment markers are administrator declarations, not automatic evidence that two databases are independent. Never label a real-users project as staging merely to unblock a build.

## Manual hosted work — not performed by these code changes

1. Open the existing project and confirm its actual Project ID and contents. Decide explicitly whether it is the production project or a disposable test project. The code does not classify or modify `dvakrwalnqpcmgirmlct` automatically.
2. For true isolation, use distinct Supabase Project IDs for staging and production. A second project may require checking the account's current free-project allowance. Do not pay for or create resources without reviewing the plan.
3. Review/apply migrations to staging first using the existing migration process. Migration 013 deliberately starts as `unassigned`; migrations alone cannot enable access.
4. In that project's SQL Editor, an authorized administrator assigns the marker. Replace both placeholders only after checking the Dashboard URL. This is a write and must not be executed blindly:

```sql
update public.app_deployment_environment
set environment = '<staging-or-production>',
    project_ref = '<actual-20-letter-project-id>',
    configured_at = now()
where singleton;
select public.get_app_environment();
```

5. Copy `backend_config.example.json` to `backend_config.staging.local.json` and fill in that same staging Project ID, URL and publishable/anon key. Keep production in a separate ignored `backend_config.production.local.json` copied from its own example. Do not include any secret/service-role key. The prior `backend_config.local.json` is NOT silently upgraded; it will fail closed until the operator explicitly selects an environment and matching server marker.
6. Start staging with:

```powershell
flutter run -d chrome --dart-define-from-file=supabase/backend_config.staging.local.json
```

Production is an intentional release workflow, not a normal development command:

```powershell
flutter build web --release --dart-define-from-file=supabase/backend_config.production.local.json
```

7. Verify staging records do not appear in production and vice versa. Verify pointing the staging build at a production-marked backend blocks login. Repeat with different test accounts and after sign-out/session restoration. Local unit tests do not replace these hosted checks.

## Preview and limits

Running a debug build with no backend defines still opens the existing local preview. The header distinguishes it from the real connected workflow. Build flags cannot be switched by a URL parameter or an ordinary app user.

Environment guards alone do not seed or delete data. Migration 016 and
`TEST_DATA_MANAGEMENT.md` now provide a separately invoked staging-only fixture
and review workflow, using fresh explicitly provisioned test Auth accounts.
It defaults to dry run and does not implement full business/account deletion.
No hosted setup is implied. Do not reuse real personal data, weaken RLS or
relabel a real-users project merely to enable testing. Retired-upload cleanup
has separate, narrower rules in `PHOTO_UPLOAD_LIFECYCLE.md`.
