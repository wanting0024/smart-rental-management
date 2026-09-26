# Sprint Plan — Smart Rental Management FYP

> **Program:** Bachelor of Software Engineering
> **Approach:** Agile SDLC — Scrum-style 2-week sprints
> **Total duration:** 6 sprints × 2 weeks = 12 weeks (Mar 18 - Jun 10 2026 per Gantt)
> **Module scope:** Owner + Cleaning Service Provider
> **Sprint 0:** UX prototype (this demo) — done
> **Sprint 1:** FYP formal implementation with Supabase backend
> **Sprint 2:** Integration testing + Chapter 5 report

---

## Status at a glance

| Sprint | Focus | Status | Deliverable |
|--------|-------|--------|-------------|
| 0 | UX prototype (this demo) | ✅ **DONE** | 7 screens, FSM rules, MCDA ranking, hardcoded data |
| 1 | Design + Develop (FYP formal) | ⏳ NEXT | Supabase schema, repository layer, real screens |
| 2 | Integration + Report | ⏸ PENDING | End-to-end test, Chapter 5, final viva |

---

## Sprint 0 — UX Prototype (✅ DONE)

**Goal:** Validate the full UX before writing real backend code.

**Scope:**
- Hardcoded data — no Supabase, no auth
- 7 screens covering Owner + Provider flow
- Reusable widget library
- FSM transition rules (ADR-0004)
- MCDA ranking with tutor-spec weights (ADR-0001)
- Unit tests for FSM and seed consistency

**Deliverable:** `C:\Users\yunli\Downloads\rental_app_demo\` (this folder)

### Sprint 0 backlog

| ID | Task | Status | File |
|----|------|--------|------|
| S0-01 | Install Flutter 3.24.5 | ✅ | `C:\src\flutter\` |
| S0-02 | Scaffold Flutter project | ✅ | `lib/main.dart` |
| S0-03 | Design system + theme tokens | ✅ | `lib/theme/app_theme.dart` |
| S0-04 | Demo data model (3 providers, 4 bookings) | ✅ | `lib/models/demo_data.dart` |
| S0-05 | StatusChip widget | ✅ | `lib/widgets/status_chip.dart` |
| S0-06 | BookingCard widget | ✅ | `lib/widgets/booking_card.dart` |
| S0-07 | ProviderCard widget | ✅ | `lib/widgets/provider_card.dart` |
| S0-08 | Owner Home screen (hero + stat cards) | ✅ | `lib/screens/owner_home_screen.dart` |
| S0-09 | Provider Browse screen (MCDA ranking) | ✅ | `lib/screens/provider_browse_screen.dart` |
| S0-10 | Booking Detail screen (lifecycle + proof) | ✅ | `lib/screens/booking_detail_screen.dart` |
| S0-11 | New Booking form | ✅ | `lib/screens/new_booking_screen.dart` |
| S0-12 | Schedule view (week timeline) | ✅ | `lib/screens/schedule_screen.dart` |
| S0-13 | Provider Inbox | ✅ | `lib/screens/provider_inbox_screen.dart` |
| S0-14 | Active Job Detail (FSM action sheet) | ✅ | `lib/screens/provider_job_detail_screen.dart` |
| S0-15 | Section header, empty state, form field widgets | ✅ | `lib/widgets/` |
| S0-16 | Calendar week view widget | ✅ | `lib/widgets/calendar_week_view.dart` |
| S0-17 | Navigation wiring (app bar + FAB) | ✅ | `lib/screens/owner_home_screen.dart` |
| S0-18 | FSM unit tests | ✅ | `test/booking_status_test.dart` |
| S0-19 | Seed data consistency tests | ✅ | `test/demo_data_test.dart` |
| S0-20 | Calendar helper tests | ✅ | `test/calendar_test.dart` |
| S0-21 | README + DEMO script + Sprint plan | ✅ | `README.md`, `DEMO.md`, `SPRINT_PLAN.md` |

### Sprint 0 retrospective (✅)

**What went well:**
- Locked scope early (Owner + CSP only) per tutor direction
- Built 4 screens in one session without re-planning
- Caught the `withValues` vs `withOpacity` issue quickly (3.24.5 API)
- Caught the `CardThemeData` vs `CardTheme` issue before viva (3.27 vs 3.24)

**What to improve:**
- Should have written the FSM transitions test first — would have caught the
  stub `CardThemeData` sooner
- Demo data was scattered; consolidated at the end

---

## Sprint 1 — Design + Develop FYP formal (⏳ NEXT)

**Goal:** Replace the demo's hardcoded data with real Supabase backend while
keeping the same UX. Start Chapter 4 (System Design).

**Scope:**
- Supabase project: auth, database, storage, realtime
- 7-feature folder restructure (auth, owner, provider_matching, cleaning_booking, service_tracking, ...)
- Repository pattern with `BackendProvider` abstraction (already drafted)
- Real image upload to Supabase Storage
- Realtime status push (subscribe to `bookings` table)
- Basic auth (email/password, magic link)

**Deliverable:** `C:\Users\yunli\.minimax-agent\projects\rental_app\` + Chapter 4 draft

### Sprint 1 backlog (proposed)

| ID | Task | Status | Notes |
|----|------|--------|-------|
| S1-01 | Create Supabase project + env config | ⬜ | Need Supabase URL + anon key |
| S1-02 | Schema migration (0001_init.sql) | ✅ drafted | Review with team |
| S1-03 | Seed data SQL (0001_demo_data.sql) | ✅ drafted | Same numbers as demo |
| S1-04 | BackendProvider abstraction | ✅ drafted | `supabase_backend_provider.dart` |
| S1-05 | Auth repository (sign in / sign out) | ⬜ | Email + password |
| S1-06 | Owner repository (read dashboard stats) | ⬜ | |
| S1-07 | Provider matching repository (MCDA query) | ⬜ | Use SQL function for ranking |
| S1-08 | Cleaning booking repository (CRUD) | ⬜ | |
| S1-09 | Service tracking repository (FSM transitions) | ⬜ | Server-side validation |
| S1-10 | Wire screens to repositories (replace DemoBooking) | ⬜ | |
| S1-11 | Supabase Storage upload for before/after | ⬜ | |
| S1-12 | Realtime subscription on bookings table | ⬜ | |
| S1-13 | Draw Chapter 4 diagrams (architecture, ER, sequence) | ⬜ | |
| S1-14 | Update FSM tests to use real repository | ⬜ | |
| S1-15 | Sprint 1 demo to tutor | ⬜ | |

### Sprint 1 risks

| Risk | Mitigation |
|------|------------|
| Supabase free tier quota exceeded | Use local Postgres for dev, push to Supabase weekly |
| Realtime quota exceeded | Polling fallback (5-second interval) |
| Network blocks during demo (Malaysia) | Demo Sprint 0 instead, fall back to screenshots |
| Other modules (tenant/IoT) delayed | Document scope boundary clearly in Chapter 1 |

---

## Sprint 2 — Integration + Report (⏸ PENDING)

**Goal:** End-to-end test, polish, finalize Chapters 4-5.

**Scope:**
- Integration tests (3+ flows)
- Chapter 4 (System Design) finalized
- Chapter 5 (Implementation & Testing) drafted
- Final viva rehearsal

**Deliverable:** Final report PDF + final demo

### Sprint 2 backlog (proposed)

| ID | Task | Status | Notes |
|----|------|--------|-------|
| S2-01 | End-to-end integration tests | ⬜ | 3+ scenarios |
| S2-02 | Performance check (cold start < 2s) | ⬜ | |
| S2-03 | Accessibility audit (WCAG AA) | ⬜ | |
| S2-04 | Chapter 4 finalize (with diagrams) | ⬜ | |
| S2-05 | Chapter 5 draft (implementation walkthrough) | ⬜ | Reuse demo code as evidence |
| S2-06 | Chapter 6 (Conclusion + Future Work) | ⬜ | |
| S2-07 | Final viva rehearsal (record + review) | ⬜ | |
| S2-08 | Submission package | ⬜ | |

---

## Cross-cutting: Reports

| Report chapter | Status | Notes |
|----------------|--------|-------|
| 1. Introduction | ✅ | v2 delivered, tutor comments addressed |
| 2. Literature Review | ⏸ Deferred | Outlined 2.1-2.8; waiting for go-ahead |
| 3. Methodology | ⬜ | Agile + Scrum; reuse Chapter 1.7 SDLC section |
| 4. System Design | ⬜ | Architecture, ERD, sequence diagrams, 6 ADRs already drafted |
| 5. Implementation & Testing | ⬜ | Reuse demo + Sprint 1 code as evidence |
| 6. Conclusion | ⬜ | Final sprint |

---

## How to read this plan with the Gantt chart

The Gantt in Figure 1.1 of Chapter 1 shows 6 phases × ~45 days each:

```
Sprint 0 (UX prototype)         ████████░░░░░░░░░░░░░░░░  (this demo)
Sprint 1 (Design + Develop)     ░░░░░░░░░░████████████░░░░  (FYP formal)
Sprint 2 (Integration + Report) ░░░░░░░░░░░░░░░░░░░░░████  (final)
```

Phase boundaries are checkpoints with the tutor. After Sprint 0 (this demo),
the next checkpoint is the end of Sprint 1 with the real Supabase implementation.
