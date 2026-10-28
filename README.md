# Smart Rental Management

Flutter application for the **Property Owner** and **Cleaning Service Provider** modules of the FYP *Smart Rental Management Mobile Application*.

Owners manage rental units and request cleaning. Providers manage services and availability, receive requests, and record completed work. Both participants follow the same booking through role-specific interfaces.

## Current status — 28 October 2026

- Source version: **0.1.8+9**, as declared in `pubspec.yaml`.
- The original Owner/Provider UI is connected to independent **Supabase Staging**. The dataset is synthetic, but authenticated actions save real cloud records.
- Latest local verification: **892 Flutter tests passed**; lib/test analysis had **no errors or warnings**, with informational style findings remaining.
- Migrations **001–030** passed disposable PostgreSQL checks under both legacy and disabled default grants. Migration 030 is deployed to Staging; a subsequent dry-run found no pending migrations, seeds or role changes.
- Paired phone/emulator UAT and remaining release checks are pending. Automated tests and Staging deployment do not establish public-launch readiness.
- Recent fixes, including uploaded-photo removal, have not been packaged into a new APK. The version number alone does not establish installer freshness.

This README describes the current connected implementation. Older dated documents are historical checkpoints; see [development progress](DEVELOPMENT_PROGRESS.md) for later changes and validation boundaries.

## Main features

| Area | Current behaviour |
| --- | --- |
| Owner Home | One Request cleaning primary action, status shortcuts and pending/upcoming bookings. |
| My properties | Building-grouped rental units; Add/Edit forms with building suggestions, bedroom choices and a required cleaning window. |
| Providers | Browse approved public profiles, services, area and rates. Browsing does not reserve availability. |
| Request cleaning | Four steps: unit/service, date/time, eligible Provider, review/send. The server checks ownership, capability, approval, availability, cleaning-window compatibility and conflicts. |
| Bookings and details | Search, status tabs, conditional History dropdown, authorised Pending edits/cancellation and a recorded status timeline. |
| Provider work and Schedule | Receive requests, accept/decline, start cleaning and inspect scheduled work; manage weekly availability and unavailable dates. |
| Completion evidence | Private Before/After photos and remarks. The assigned Provider may replace/remove a photo while In Progress; removal requires confirmation and both photos are required for completion. |
| Booking messages | Persistent participant-only text conversations. Sending is allowed while Accepted/In Progress; closed conversations are read-only. |
| Notifications | Stored in-app booking updates/read state. Preferences control supported on-device indicators; background push delivery is not enabled. |
| Earnings, statistics and reviews | Connected own-account summaries and completed-service reviews. Earnings show completed booking quote amounts before platform fees, not settled payouts or money received. |
| Profile and settings | Account/profile editing, Provider services/rates/privacy, System/Light/Dark appearance, notification preferences and Help centre. |

The interface uses **Material 3 with a Navy / Sky Blue theme**, with separate light and dark palettes. Local preview stores remain available for offline UI inspection; they are separate from connected repositories and cannot prove cloud persistence or multi-account behaviour.

## Report objective mapping

| Objective | App flow | Current boundary |
| --- | --- | --- |
| **1.3.1 Integrated cleaning-service coordination** | Owner → My properties → Request cleaning → Bookings. | Connected unit-linked requests and management implemented; paired-device acceptance pending. |
| **1.3.2 Provider matching and scheduling** | Request cleaning → date/time → Find eligible providers; Provider availability/Schedule. | Mandatory service, availability, window and conflict checks implemented. Route distance, automatic geographic compatibility and WSM/MCDA comparative ranking incomplete. A displayed service area/rating is not a ranking score. |
| **1.3.3 Service fulfilment and monitoring** | Booking details → history/messages → photos/remarks → completion/review. | Controlled lifecycle, evidence and connected outcome records implemented. Device acceptance, background push and payment integration remain separate outstanding work. |

### Booking lifecycle

```text
Pending → Accepted → In Progress → Completed
Pending → Declined
Pending / Accepted → Cancelled, when authorised by the server
```

Completed, Declined and Cancelled are terminal. Pending does not reserve Provider time. Acceptance rechecks eligibility/conflicts transactionally; overlapping Accepted/In Progress bookings are blocked. The backend owns allowed role/state transitions and completion requirements.

## Run the App

### Prerequisites

- Flutter **3.22+** and Dart **3.4+**, within `pubspec.yaml` constraints. Check its package-specific toolchain compatibility notes before upgrading.
- Android SDK and an emulator, or a USB-debugging-enabled Android phone.
- For connected runs: Internet, an authorised Staging project with migrations/environment marker and required Edge function configured, plus Owner/Provider accounts.

Open the **repository root**, not just `android/`, in Android Studio. Run from the repository root:

```powershell
flutter pub get
flutter devices
```

### Connected Staging configuration

Create the ignored local configuration only if it does not already exist:

```powershell
if (-not (Test-Path 'supabase/backend_config.staging.local.json')) {
    Copy-Item 'supabase/backend_config.example.json' 'supabase/backend_config.staging.local.json'
}
```

Edit that local file with your authorised values:

| Setting | Value |
| --- | --- |
| `APP_ENV` | `staging` |
| `SUPABASE_PROJECT_REF`, `SUPABASE_URL` | Matching Staging project reference and HTTPS URL |
| `SUPABASE_PUBLISHABLE_KEY` | Client publishable key; never a secret/service-role key |
| `ALLOW_PRODUCTION_BACKEND` | `false` |
| `AUTH_RECOVERY_REDIRECT_URL` | Configured recovery destination; see [recovery setup/build restrictions](supabase/PASSWORD_RECOVERY.md) |

Startup verifies an administrator-owned server environment marker. Missing/mismatched settings fail explicitly instead of substituting preview data. Follow [environment setup](supabase/ENVIRONMENTS.md) before connecting a new project. Never apply a fresh-schema bundle to an existing/shared database.

Use an Android device ID returned by `flutter devices`:

```powershell
$androidDeviceId = 'replace-with-your-android-device-id'
flutter run -d $androidDeviceId --dart-define-from-file=supabase/backend_config.staging.local.json
```

In Android Studio, select the Android emulator/phone and add this to the Flutter run configuration's **Additional run args**:

```text
--dart-define-from-file=supabase/backend_config.staging.local.json
```

Selecting `Windows (desktop)` requires a separate Windows build toolchain. Native development sessions support Hot Reload/Hot Restart; an installed APK does not receive source-code updates automatically.

Optional connected Web development: `tool/run_staging_web.ps1`. Its fixed origin must match the evidence-validator origin allow-list. Web does not replace native device/permission checks.

### Offline UI preview

Without backend settings, a debug run opens the separate local preview:

```powershell
flutter run -d chrome
```

Preview sample data is for UI inspection only and does not persist to Supabase. Release builds require an explicit backend and valid recovery setup.

## Two-role demonstration and UAT

Use **Owner on the phone** and **Provider on an Android emulator or another phone**, with distinct accounts on the same Staging project. Keep the relevant pages in the foreground. Internet is required; the same Wi-Fi network is not.

1. Briefly introduce both roles' main pages.
2. Owner chooses a unit, service, interval and the Provider account used on the other device, then submits a Pending request.
3. Provider receives/accepts it; verify the Owner's status.
4. Exchange messages while Accepted/In Progress, then start cleaning.
5. Provider uploads Before/After photos, adds remarks and completes the job.
6. Owner opens the same completed booking, reviews evidence and submits a review. Relate the flow to Objectives 1.3.1–1.3.3.

Booking feeds/status subscriptions and open booking conversations use **Supabase Realtime**. Message-list/unread indicators also use bounded foreground revalidation. Not every screen subscribes to every change: photos, profiles and reports may require reload/re-entry. Background push is not configured. Rehearse cross-device delivery before presenting it as verified; manual refresh is recovery, not proof of Realtime delivery.

Use synthetic data. Staging requests/messages/files remain after closing the App. Do not reseed accounts or delete shared fixtures as a normal demonstration step. Supply credentials privately, never in this README.

## Verification

```powershell
flutter test
flutter analyze lib test --no-fatal-infos
```

The latest **892 passing tests** cover role/state handling, navigation, forms, responsive UI, retry/readback, private evidence, caching and photo removal. This count describes the dated checkpoint, not a guarantee for future edits.

Local SQL checks use disposable databases, not Staging:

```powershell
# Requires Docker Desktop; exercise both default-privilege profiles.
.\tool\verify_local_migrations.ps1 -PrivilegeProfile legacy
.\tool\verify_local_migrations.ps1 -PrivilegeProfile disabled
```

`tool/verify_native_migrations.ps1` is the alternative for a separately installed PostgreSQL runtime. The latest native 001–030 checks passed both profiles, including ACL/RLS, lifecycle, evidence, pagination and concurrency scenarios. Auth/Storage shims verify database rules, not hosted JWT, Storage API, Realtime or camera behaviour. Earlier hosted acceptance results are in the dated progress notes; the latest photo-removal change still needs device UAT.

## Known gaps and release boundaries

- Route-distance integration, WSM/MCDA ranking and automated alternative-time recommendations are incomplete. Eligibility filtering is not ranking.
- Background push, cleaning-payment collection and Provider payout are not complete. Earnings charts are not payment settlement evidence.
- Help centre is available; no operational support mailbox/ticket team is configured. Simulated support tickets are no longer exposed in the user flow.
- Terms/Privacy remain unpublished review drafts. Account deletion/export, password-recovery delivery/callback acceptance and production privacy/release operations are not accepted as complete.
- Paired Android UAT, camera/gallery permissions, reconnect behaviour, real file cleanup, signing/distribution and production deployment require remaining acceptance work. Current code is not public-release approval.

## Repository and security notes

| Location | Purpose |
| --- | --- |
| `lib/screens/`, `lib/widgets/` | Existing UI, navigation and shared components |
| `lib/services/backend/` | Connected repositories, bindings, caching and subscriptions |
| `supabase/migrations/`, `supabase/functions/` | Versioned database changes and Edge functions |
| `test/`, `supabase/tests/` | Flutter and database verification |
| `tool/` | Development, verification and guarded operational tools |

Local backend configuration, credentials, signing material, downloaded runtimes, generated outputs and installers are excluded from Git. Never put secret/service-role keys in the App. Updating this README does not push GitHub, deploy a backend or build/distribute an APK.

Operational references:

- [Backend checkpoint and historical notes](supabase/README.md)
- [Environment separation](supabase/ENVIRONMENTS.md)
- [Photo lifecycle](supabase/PHOTO_UPLOAD_LIFECYCLE.md) and [trusted validation](supabase/VERIFIED_EVIDENCE.md)
- [Subscriptions](supabase/SUBSCRIPTION_LIFECYCLE.md), [pagination](supabase/PAGINATION.md) and [caching/compression](supabase/CACHING_AND_COMPRESSION.md)
- [Message/upload limits](supabase/BOOKING_COMMUNICATION_LIMITS.md) and [secret/log protection](supabase/SECRET_AND_LOG_PROTECTION.md)
- [Current UI implementation](docs/2026-10-28_APPROVED_UI_IMPLEMENTATION.md) and [user-facing content](docs/2026-10-28_USER_FACING_CONTENT.md)

Dated documents describe their own checkpoints. Use current progress and actual test/deployment results when assessing later changes.
