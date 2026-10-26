# Report-to-app implementation tracker

Source of truth: `RSW_OhWanTing_SmartRentalManagementMobileApplication_OwnerAndCleaningServiceProviderModules.pdf`, especially pp. 17–23, 93–100, 117–130, and 148–156 (PDF page numbers). This tracker covers the individual Owner and Cleaning Service Provider scope. A visible screen is not counted as a complete feature when its data or server behaviour is still simulated.

Status key: **Local** = usable in one running demo but no secure shared persistence; **Partial** = some behaviour or UI exists; **Missing** = no working implementation; **External** = requires an agreed group service or project configuration. No requirement below is production complete yet.

Implementation-to-report alignment note (22 October 2026): the newly agreed
8-hour daily package and Booking price snapshot are implementation decisions
not yet stated in the supplied report. Before final submission, add the
pricing rule to Chapter 3's business/functional requirements and update
Chapter 4's Booking data model, request sequence and payment description.
Do not describe Stripe as implemented merely because a quote is stored.

## Owner functional requirements (report pp. 93–94)

| ID | Required behaviour | Status | Evidence / remaining work |
| --- | --- | --- | --- |
| FR1.1 | Register with email, password and contact | Missing | Registration button is a placeholder; Supabase Auth and owner profile needed. |
| FR1.2 | Sign in with valid credentials | Partial | `login_screen.dart` accepts a demo identity; credentials are not authenticated. |
| FR1.3 | Browse providers, ratings, service area and types | Partial | Browse and profile screens exist; matching context and provider data are fixtures. |
| FR1.4 | View bio, rate and reviews | Partial | Profile exists; review/stat data are local or hard-coded. |
| FR1.5 | Submit unit, service, date/time, duration, instructions | Partial | Connected Owner form now reviews a server quote and calls the protected Pending-creation RPC with an idempotency token. Migrations 001–009 still require deployment and live account testing; the local preview remains separate. |
| FR1.6 | Four eligibility filters, then equal-weight distance/rating/workload | Partial | Connected search has a drafted server-side hard-filter RPC; route-distance/rating/workload ranking remains unconnected. No ranked recommendation is claimed. |
| FR1.7 | Only Accepted/In Progress block; dynamic alternatives | Partial | Status rule and same-day alternatives read editable provider availability and property cleaning windows locally; broader windows and authoritative data remain. |
| FR1.8 | Current booking status and transition history | Local | Booking detail shows actual in-session transition events. Seeded bookings without history are labelled honestly; server persistence remains outstanding. |
| FR1.9 | Booking-linked owner/provider chat | Partial | Connected booking chat now uses participant-scoped Realtime reads and an idempotent send RPC for Accepted/In Progress bookings; migration 010 and cross-account checks remain unverified in PostgreSQL. |
| FR1.10 | View before/after photos and remarks | Partial | Connected Owner Completed card now opens private downloaded photos and remarks; staging RLS and on-device verification remain. Local preview still uses separate temporary data. |
| FR1.11 | Rate completed booking 1–5, optional text | Partial | Connected Owner screen and migration 011 now support one review per Completed booking, an optional comment, later updates, and a transactionally recomputed Provider average. Local PostgreSQL tests pass; hosted migration and two-account checks remain. |
| FR1.12 | Edit/cancel before acceptance | Local | Pending edits now revalidate future time, property cleaning window, provider availability and Accepted/In Progress overlap before saving; no backend enforcement or shared persistence. |
| FR1.13 | Register/manage own Property records | Local | Owner can add/edit local unit, address and cleaning window records; new units enter the booking picker. Seeded units have no real address; authenticated ownership and persistence remain. |
| FR1.14 | Vacant unit monthly management fee payer becomes Owner | External | Requires contract with teammate's billing module; no integration exists. |
| FR1.15 | Stripe cleaning payment after Completed only | Missing | No Stripe checkout; displayed spend is estimated from bookings. |
| FR1.16 | Payment Pending/Succeeded/Failed + gateway reference | Missing | No payment entity/service or event handling. |

## Cleaning Service Provider functional requirements (report pp. 94–95)

| ID | Required behaviour | Status | Evidence / remaining work |
| --- | --- | --- | --- |
| FR2.1 | Register with service type, area and rate | Partial | Connected registration accepts hourly and/or 8-hour daily rate and service area; service capabilities are selected in the connected setup screen. Backend migrations and approval flow remain unverified. |
| FR2.2 | Sign in with valid credentials | Partial | Demo identity only. |
| FR2.3 | Edit weekly slots and unavailable dates | Local | `provider_availability_screen.dart` edits multiple weekly slots and blocked dates; provider matching and alternatives use them. Data reset on restart. |
| FR2.4 | Pending accept/decline; atomic latest availability/conflict validation | Partial | Local acceptance rechecks current provider hours, rental window and overlap. A Supabase migration now drafts the protected acceptance transaction, but it is not deployed or connected. |
| FR2.5 | Six-state lifecycle | Local | State policy exists locally; actor permissions and persisted history need backend enforcement. |
| FR2.6 | Upload before/after and remarks | Partial | Connected Provider In Progress form uploads validated JPEG/PNG images (5 MB max) to private storage and saves remarks before the server-authoritative completion transition. Live Storage/RLS and device checks remain. |
| FR2.7 | Current day and next seven days assigned schedule | Partial | Week view exists; data are local and seven-day requirement needs direct validation. |
| FR2.8 | Realtime request/schedule/chat notifications | Missing | Notification screen uses static content; no FCM/realtime subscriptions. |
| FR2.9 | Booking-linked chat | Partial | Connected Provider uses the same booking-only chat, with completed conversations read-only; real RLS, Realtime and on-device checks remain. |
| FR2.10 | Cumulative rating/reviews/completed count | Partial | Reviews screen exists; profile contains hard-coded lifetime stats. |
| FR2.11 | Cleaning payment statuses | Missing | No actual payment records. |

## Nonfunctional requirements (report pp. 95–98)

| IDs | Required outcome | Current verification gap |
| --- | --- | --- |
| NFR1.1–1.4 | Booking, matching and realtime latency at stated 95th-percentile targets; 500 sessions | Missing: no production backend or load/performance measurements. |
| NFR2.1–2.2 | Documented supported Android/iOS versions; 5.0–6.7-inch portrait layout | Partial: Flutter UI exists; device matrix and layout tests not complete. |
| NFR3.1–3.4 | Material 3; first booking usability; contrast/touch; English localization | Partial: UI/theme exist; usability, accessibility and externalized strings not fully checked. |
| NFR4.1–4.3 | Measured uptime; atomic backend consistency/RLS; honest offline state | Partial design only: core migration drafts RLS/atomic acceptance, but there is no deployed service, database integration test, or offline/persistence behaviour. |
| NFR5.1–5.6 | Auth, TLS/encryption, bcrypt policy, chat privacy, JPEG/PNG ≤5 MB, hosted Stripe | Missing or partial: only local UI/fields are present. |
| NFR6.1–6.3 | Feature separation, one authoritative FSM, ≥70% line coverage for core areas | Partial: FSM and some feature folders/tests exist; coverage target not measured. |
| NFR7.1–7.2 | Shared Dart Android/iOS and tested devices/emulators | Partial: shared Flutter code exists; platform device evidence is outstanding. |

## Implementation order

1. Review and test the drafted Supabase schema/RLS/acceptance RPC in a disposable project, then add Auth, other lifecycle RPCs and the live Flutter adapter (FR1.1–1.2, FR1.8, FR2.1–2.5, NFR4–5). Project configuration and group schema reconciliation are needed before connection.
2. Connect live route distance, evidence, chat, notifications and aggregate reviews (FR1.3–1.4, FR1.9–1.11, FR2.6–2.10).
3. Integrate Stripe cleaning payments and the separately owned monthly-fee flow after agreeing the group interface (FR1.14–1.16, FR2.11).
4. Measure and document all nonfunctional thresholds on supported devices.
