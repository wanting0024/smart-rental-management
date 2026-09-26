# Demo Script — 5-Minute Viva Walkthrough

> **Title:** Smart Rental Management Mobile Application
> **Module:** Owner and Cleaning Service Provider
> **Stack:** Flutter 3.24.5, Material 3, hardcoded demo data
> **Status:** Sprint 1 complete — 9-state FSM (Ch 2.4.5 + 2.7.3), 23 screens, 122/122 tests pass, Rounds 7-12 UI polish complete

This is the talking-point script for viva. Each section is **~1 minute** and
maps to one screen. Total = 5 minutes for the demo, leaving 10 minutes for Q&A.

---

## 0. Opening (30 sec)

> "My module covers two roles: the **owner** who manages rental properties and
> schedules cleanings, and the **cleaning service provider** who receives and
> executes those jobs. The full flow is: owner requests → system auto-matches a
> provider → provider accepts and executes → owner reviews proof. Today I'll
> walk you through that loop in 5 screens.
>
> Quick note on the design: I used Material 3 with an Emerald Green primary
> (#2E7D32) and Teal secondary (#26A69A) — clean property-management feel, no
> e-commerce clutter. 16dp canonical radius, 8dp spacing grid, full light +
> dark mode support."

---

## 1. Owner Dashboard (45 sec)

**Open:** http://localhost:xxxxx (default landing)

**Show:** The emerald gradient hero "Welcome back, Oh Wan Ting" with the 4 stat
cards underneath (4 Total / 1 Active / 1 Sched. / 1 Done).

**Talking points:**
- "The owner has 4 bookings in different lifecycle stages — those numbers come
  straight from the FSM states defined in Ch 2.4.5 + 2.7.3 (9 states: requested / accepted / scheduled / rescheduled / inProgress / delayed / completed / rejected / cancelled)."
- "The '1 new request' badge below the stats matches the data in the list —
  b-003 is in *requested* status, waiting to be matched."
- Point to the **FAB** in the bottom right: "Plus icon opens the new booking
  request form, which I'll demo at the end."
- Point to the **bottom nav**: "5 tabs — Home, Schedule, Properties, Browse,
  Spend. The Spend tab opens the owner's cost analytics dashboard."

**App bar icons to mention:** 🌙 Dark mode toggle · 🔔 Notifications (with badge)
  · ≡ Drawer (profile, theme, sign out)

---

## 2. Provider Browse (45 sec)

**Action:** Tap 🔍 in the app bar.

**Show:** Three provider cards ranked top-to-bottom: A (0.93), B (0.81), C (0.74).

**Talking points:**
- "This is the MCDA ranking from ADR-0001. The weights are **availability 0.35,
  distance 0.20, rating 0.25, workload 0.20** — those exact values come from
  the comparison table in my Chapter 2 literature review."
- "Provider A has the lowest workload and is full match → ranked first."
- "Provider C is closest in distance but only Partial match → ranked third."
- "Tap 'View profile' to see the full MCDA score breakdown — that's a
  separate screen with workload bars, services chips, and contact list."

---

## 3. Booking Detail (45 sec)

**Action:** Go back, tap the first booking card (b-001 — InProgress, amber chip).

**Show:** Status gradient hero + lifecycle timeline strip + before/after proof cards.

**Talking points:**
- "The status hero is color-coded by the current FSM state — amber for
  InProgress, green for Completed, red for Delayed, etc."
- "The lifecycle strip below the hero shows which steps are done (filled) vs
  pending (hollow). Right now Provider A is mid-job."
- "The two dashed-border cards at the bottom are the before/after proof. This
  is what gets attached to the FSM transition `inProgress → completed` in
  ADR-0005 — the system requires both photos before allowing the provider to
  mark complete."
- Scroll to the action buttons: "Owner has Approve and Request redo here."

---

## 4. New Booking Request (1 min)

**Action:** Go back, tap the FAB.

**Show:** Multi-step form: property dropdown, 5 service types as radio cards,
date picker, time picker, special instructions, auto-match toggle, live
summary card.

**Talking points:**
- "This is the entry point of the owner flow. They pick a property, choose a
  service type, schedule it, and the system auto-routes to the best provider."
- "The summary card on the right updates live — it shows the estimated cost
  based on service type, and the projected end time based on duration."
- "Auto-match is on by default — but the owner can toggle it off to manually
  pick a provider from the Browse screen."

**Action:** Submit the form.

**Show:** Snackbar "Request submitted" → new card appears at top of list
(Requested status, grey chip).

**Talking point:**
- "Just like that, a new booking is in `requested` state. The next state
  transition would happen on the **provider** side — let me show you that."

---

## 5. Provider View (1 min)

**Action:** Tap 💼 (work icon) in the owner app bar.

**Show:** Provider Inbox with gradient earnings hero (RM 540 / 2 upcoming /
1 new request) + 4 tabs (New / Active / Done / All).

**Talking points:**
- "Same data, different role. The provider sees their earnings, upcoming jobs,
  and incoming requests."
- "The 'New' tab has 1 entry — that's the booking the owner just submitted."

**Action:** Tap Accept on the new request.

**Show:** Snackbar "Accepted", item moves from "New" to "Active" tab.

**Action:** Switch to Active tab, tap the accepted job.

**Show:** Active Job Detail — color-coded status hero, 4 cards (Service /
Location / Before-After / Owner notes), checklist at the bottom.

**Action:** Tap the floating "Update status" button → bottom sheet appears with
the available FSM transitions.

**Talking points:**
- "This is the FSM from Ch 2.4.5 in action. From `accepted` the provider can
  either confirm a schedule or cancel. The bottom sheet only shows the
  **valid** transitions — invalid ones are hidden, so the FSM can't be
  violated by accident."
- "The Before/After upload is required to mark complete — that enforces
  ADR-0005, the proof requirement."

---

## 6. Closing (30 sec)

> "That's the full loop. To summarize what you've seen:
> - **Owner side:** request, browse, schedule, review, approve proof
> - **Provider side:** receive, accept, execute, upload proof, complete
> - **Cross-cutting:** the 9-state FSM (Ch 2.4.5 + 2.7.3), MCDA ranking, and proof enforcement
>   apply throughout.
>
> Sprint 0 ships with 16 screens, 11 reusable widgets, 55 unit tests covering
> FSM, seed data, calendar helpers, earnings/spend aggregations, and the
> design system. Light + dark mode both work. Sprint 1 is the FYP formal
> implementation with Supabase backend — the data model and FSM stay the same,
> only the storage layer changes."

**Optional last-second flex:** tap the moon icon in the app bar to flip to
dark mode. "Material 3 dark theme is wired throughout — surfaces, text,
and inputs all flip automatically. Brand colors stay emerald and teal so
the visual identity is preserved across modes."

---

## Anticipated Q&A

**Q: "Why Flutter instead of native?"**
A: One codebase for Android and iOS. Cross-platform is part of the FYP scope.
ADR-0001 captures the decision with rationale.

**Q: "Why MCDA? Why these weights?"**
A: The weights came from my Chapter 2 comparison of how Jobber, TenantCloud,
and Skedulo rank their providers. Availability dominates because a provider
who can't take the job scores 0 regardless of distance.

**Q: "What if the provider is offline and the owner updates?"**
A: Sprint 1 uses Supabase Realtime to push status changes. Sprint 0 is
polling/refresh only — same UX, just less responsive. (Bonus: there's a
**purple play button** above the new-request FAB that simulates a full
booking lifecycle — requested → accepted → scheduled → inProgress → completed
— in 7 seconds, then auto-triggers the review sheet. Great for the viva.)

**Q: "How do you prevent an owner from approving incomplete work?"**
A: The `completed` transition requires both before/after photos to be
uploaded by the provider (ADR-0005). The owner can then Approve or Request
redo; either way, the FSM advances from `completed` to terminal.

**Q: "Why emerald green and teal as the brand colors?"**
A: Emerald = trust, growth, property/landscape associations — natural for
a property management app. Teal = modern, calm, professional contrast
without competing with the primary. 16dp radius + 8dp grid + soft shadows
gives the Airbnb-clean, non-e-commerce feel that the brief asked for.

**Q: "Does the app support dark mode?"**
A: Yes — both the theme and the entire surface palette are wired. Tap the
moon icon in the app bar to flip. All colors, borders, text, and input
fields adapt automatically. Brand colors stay emerald/teal in both modes
so the visual identity is preserved.

**Q: "What about the other modules — tenant, IoT, billing?"**
A: Per the project agreement, those belong to other team members. My scope is
the Owner and Cleaning Service Provider modules, as defined in Chapter 1.1.

---

## Backup slides (if time permits)

- **Schedule view** (📅 in app bar) — week timeline with color-coded blocks
- **Tests** — `flutter test` shows FSM coverage
- **Architecture** — show `docs/architecture_decisions.md` in the FYP project
- **Gantt chart** — show Figure 1.1 in Chapter 1

---

## Demo timing reference

| Section | Duration | Cumulative |
|---------|----------|------------|
| Opening | 0:30 | 0:30 |
| Owner Dashboard | 0:45 | 1:15 |
| Provider Browse | 0:45 | 2:00 |
| Booking Detail | 0:45 | 2:45 |
| New Booking | 1:00 | 3:45 |
| Provider View | 1:00 | 4:45 |
| Closing | 0:30 | 5:15 |
| **Q&A** | **10:00** | **15:15** |

---

## Visual reference for tutor

Open `C:\Users\yunli\Downloads\rental_app_demo\docs\preview.html` in any
browser — it's a self-contained HTML page showing all 7 phone mockups, the
design token palette, and the component spec. Print to PDF for a 2-page
handout to leave with the tutor.

---

## UI polish highlights (for viva mention)

- **Brand consistency** — 9 hero cards use `AppTheme.primaryGradient` (emerald);
  1 (spend) uses `accentGradient` (orange) for visual distinction
- **Full dark mode** — every screen tested in both modes; `SemanticColors.of(context)`
  resolves light vs dark tokens automatically
- **Localized date formatting** — `intl.DateFormat` throughout (no hand-rolled
  month arrays); respects locale
- **No hardcoded hex colors** — every `Color(0xFF...)` replaced with theme tokens
- **Form safety** — new_booking has PopScope unsaved-changes guard, sticky submit
  button that shows "Ready to submit" / "Fill in the required fields" status
- **Provider privacy** — `showPhoneToOwners` toggle (Round 7) actually honored by
  `provider_profile_screen` (Round 10)
- **9-state FSM** — all transitions enforced in `BookingStatusX.canTransitionTo`
  (Ch 2.4.5 + 2.7.3); reject/reschedule flows with optional/required reasons
  (Round 6); tested in 27 dedicated cases
- **Animated feedback** — typing indicator (chat, Round 9), read receipts,
  animated counter (hero numbers), onboarding background tints with page
