# Smart Rental Management — Sprint 0 Demo

Standalone Flutter demo of the **Owner Module + Cleaning Service Provider Module**
for the FYP *"Smart Rental Management Mobile Application"*.

All data is hardcoded — no Supabase, no auth, no backend. Runs fully offline so
tutors and stakeholders can preview the full UX without setting anything up.

---

## 1. What you get

### 23 screens (12 Owner + 9 Provider + 2 shared)

**Owner side (12)**

| # | Screen | File | Purpose |
|---|--------|------|---------|
| 1 | Login | `lib/screens/login_screen.dart` | Role select + login |
| 2 | Onboarding | `lib/screens/onboarding_screen.dart` | First-run intro |
| 3 | Owner Dashboard | `lib/screens/owner_home_screen.dart` | Hero summary + 4 stat cards + booking list + FAB |
| 4 | Provider Browse | `lib/screens/provider_browse_screen.dart` | Provider A/B/C ranked by MCDA |
| 5 | Booking Detail | `lib/screens/booking_detail_screen.dart` | Status strip + lifecycle timeline + before/after proof |
| 6 | New Booking | `lib/screens/new_booking_screen.dart` | Multi-field form to create a `requested` booking |
| 7 | Schedule | `lib/screens/schedule_screen.dart` | Week timeline + today strip + per-day legend |
| 8 | Property List | `lib/screens/property_list_screen.dart` | All properties |
| 9 | Property Detail | `lib/screens/property_detail_screen.dart` | Single property + bookings |
| 10 | Owner Spend | `lib/screens/owner_spend_screen.dart` | Cost analytics dashboard |
| 11 | Chat List | `lib/screens/chat_list_screen.dart` | All chat threads |
| 12 | Chat | `lib/screens/chat_screen.dart` | Inbox + send messages |
| 13 | Notifications | `lib/screens/notifications_screen.dart` | Recent events |
| 14 | About | `lib/screens/about_screen.dart` | App info + theme toggle |
| 15 | Reschedule | `lib/screens/reschedule_screen.dart` | Owner reschedules a booking |

**Provider side (9)** — `provider_inbox`, `provider_job_detail`, `provider_profile`, `provider_edit_profile`, `provider_schedule`, `provider_stats`, `provider_reviews`, plus the two `chat_*` screens shared with Owner.

### 13 reusable widgets

- `booking_card.dart` — compact booking row with status chip
- `provider_card.dart` — provider row with score badge + tag cloud
- `status_chip.dart` — colored status pill
- `app_text_field.dart` — outlined form input with validation states
- `empty_state.dart` — icon + title + subtitle + CTA empty pattern
- `section_header.dart` — bold title with subtitle and trailing action
- `calendar_week_view.dart` — week timeline with positioning by time

### Demo data (hardcoded in `lib/models/demo_data.dart`)

- **3 providers** (A: 2.0km, 4.8★, Low workload, 0.93 / B: 5.0km, 4.9★, High workload, 0.81 / C: 1.0km, 4.5★, Medium workload, 0.74)
- **4 sample bookings** covering each lifecycle stage (Requested / Scheduled / InProgress / Completed)
- **5 properties** under management (Menara Suria + Vista Bayu)
- **5 service types** with duration and base price (Standard / Deep / Move-in / Move-out / Window)

### FSM transitions (ADR-0004)

```
requested → accepted, cancelled
accepted → scheduled, cancelled
scheduled → inProgress, delayed, cancelled
inProgress → completed, delayed
delayed → inProgress, cancelled
completed → (terminal)
cancelled → (terminal)
```

---

## 2. Architecture

```
lib/
├── main.dart                      MaterialApp + theme toggle + entry
├── theme/
│   └── app_theme.dart             Design tokens + light + dark ThemeData
├── models/
│   └── demo_data.dart             Hardcoded providers, bookings, properties, services
├── screens/
│   ├── owner_home_screen.dart     Entry — owner dashboard (5 tabs + drawer + bottom nav)
│   ├── provider_browse_screen.dart
│   ├── booking_detail_screen.dart
│   ├── new_booking_screen.dart    Owner: create new request
│   ├── schedule_screen.dart       Owner: week timeline
│   ├── provider_inbox_screen.dart Provider: jobs list (4 tabs + drawer + bottom nav)
│   ├── provider_job_detail_screen.dart  Provider: FSM actions
│   ├── provider_profile_screen.dart    Full provider profile (MCDA breakdown)
│   ├── provider_schedule_screen.dart   Provider: own schedule
│   ├── earnings_history_screen.dart    Provider: earnings dashboard
│   ├── owner_spend_screen.dart         Owner: spend analytics
│   ├── notifications_screen.dart       Activity feed (owner + provider)
│   ├── property_list_screen.dart       Owner's 5 properties
│   └── property_detail_screen.dart     Single property detail
└── widgets/
    ├── booking_card.dart
    ├── provider_card.dart
    ├── status_chip.dart
    ├── app_text_field.dart
    ├── empty_state.dart
    ├── section_header.dart
    ├── calendar_week_view.dart
    ├── app_bottom_nav.dart       Bottom navigation (4 tabs)
    ├── app_drawer.dart           Drawer with profile + theme switch
    ├── auto_demo_button.dart     Play auto-demo button (viva wow)
    └── review_submission_sheet.dart  Rate provider bottom sheet
```

---

## 3. Design system

The app uses **Material 3** with a custom **Emerald + Teal** palette inspired by
Airbnb's clean property-management aesthetic.

### Color tokens

| Token | Light | Dark | Usage |
|---|---|---|---|
| `primary` | `#2E7D32` (Emerald 800) | `#4CAF50` (Green 500) | Brand actions, links, active states |
| `primaryLight` | `#4CAF50` | — | Gradient endpoint |
| `primarySurface` | `#E8F5E9` | `#1B3320` | Tinted backgrounds, chips |
| `primaryBorder` | `#C8E6C9` | `#2D5234` | Borders on tinted elements |
| `primaryDark` | `#1B5E20` | — | Hover/pressed states |
| `secondary` | `#26A69A` (Teal 400) | `#80CBC4` (Teal 200) | Provider-side accents |
| `secondarySurface` | `#E0F2F1` | `#0F2A2A` | Provider tinted backgrounds |
| `background` | `#FAFAFA` | `#0F1419` | Page background |
| `surface` | `#FFFFFF` | `#1A1F2E` | Cards, sheets, app bar |
| `border` | `#E5E7EB` | `#2D3548` | Hairlines, input borders |
| `textPrimary` | `#1F2937` | `#F1F5F9` | Headings, body |
| `textSecondary` | `#6B7280` | `#94A3B8` | Captions, helper text |

### Spacing & radius

- **Spacing**: 8dp grid (4 / 8 / 12 / 16 / 20 / 24 / 32 / 48) — see `AppSpacing`
- **Radius**:
  - `8dp` for buttons and inputs
  - **`16dp` is canonical** for cards, dialogs, sheets
  - `999` for status pills
  - `24` for hero sections
- **Elevation**: 1 (cards), 4 (FAB), 8 (sheets) — soft shadows, never sharp

### Typography

Material 3 defaults, with key sizes:
- Display 24/700 · H1 20/700 · H2 18/600 · H3 16/600
- Body 14/400 · Caption 12/500 · Overline 11/600 (letter-spacing 0.5)

### Components delivered

- AppBar (surface-tinted, no shadow)
- Cards (16dp radius, 1px border, 1 elevation)
- Filled / Outlined / Text / Icon buttons
- Outlined text fields (filled bg, 8dp radius)
- Status chips (pill, tinted bg + colored text)
- Bottom navigation (5 tabs, M3 surface)
- Floating action button (16dp radius, 4 elevation)
- Bottom sheet (24dp top radius, drag handle)
- Snackbars (8dp radius, floating)
- Search bar (filled, no border)
- Calendar picker (week view with day labels + grid)
- Notification badges (8dp dot, error red)
- Image carousel placeholder (in Before/After proof cards)

### Dark mode

- Toggle via the **moon/sun icon in the app bar** (top right of every screen)
- Or via the **Dark mode switch in the drawer footer**
- All surfaces flip: `background` `#FAFAFA → #0F1419`, `surface` `#FFFFFF → #1A1F2E`
- Text inverts: `textPrimary` `#1F2937 → #F1F5F9`
- Brand colors stay emerald/teal but the primary brightens to `#4CAF50` for contrast
- Hero gradients do NOT change — they stay emerald/teal in both modes

---

## 4. How to run

### Prerequisites
- Flutter SDK **3.22+** (tested on 3.24.5)
- Chrome (web) or Android emulator (mobile)

### Web (fastest — no Gradle needed)
```powershell
cd C:\Users\yunli\Downloads\rental_app_demo
flutter run -d chrome
```
The app opens on `http://localhost:xxxxx` (Flutter picks a port). Hot reload works
on file save.

### Android (for emulator or physical device)
```powershell
cd C:\Users\yunli\Downloads\rental_app_demo
flutter run -d <device-id>
```
To list devices: `flutter devices`.

### Android Studio
1. **File → Open** → select `C:\Users\yunli\Downloads\rental_app_demo`
2. Wait for Gradle sync.
3. **Pub get** if not auto-triggered.
4. Pick a device in the device dropdown (top right).
5. **Run** (green triangle) or `Shift+F10`.

---

## 4. Demo flow (5-minute walkthrough)

Use this order when presenting:

1. **Owner Dashboard** (1 min) — "Welcome back Oh Wan Ting" hero; 4 stat cards
   (4 Total / 1 Active / 1 Sched. / 1 Done); 4 booking cards below.
2. **Provider Browse** (1 min) — Tap 🔍 in app bar. Show Provider A scored 0.93
   (Full match) and Provider C scored 0.74 (Partial match). Explain MCDA weights.
3. **Booking Detail** (1 min) — Tap b-001 (InProgress, amber). Show status strip
   and before/after proof cards. Highlight FSM compliance.
4. **New Booking** (1 min) — Tap FAB. Pick a property, service type, date, time.
   Toggle auto-match. Submit → snackbar "Request submitted" → new card at top
   of list (Requested, grey).
5. **Provider view** (1 min) — Back to home, tap 💼 in app bar. Provider Inbox
   opens with gradient earnings hero. Accept a new request → it moves to
   "Active" tab → tap it → Active Job Detail with FSM action sheet.

See [DEMO.md](DEMO.md) for the full viva script with talking points.

---

## 5. Tests

```powershell
cd C:\Users\yunli\Downloads\rental_app_demo
flutter test
```

Coverage (see `test/`, 95 cases total):
- `booking_status_test.dart` — FSM transition rules (9 states × 17 valid + invalid transitions)
- `booking_store_test.dart` — in-memory pub/sub
- `calendar_test.dart` — `mondayOf()` week-start helper
- `demo_data_test.dart` — seed consistency (3 providers, 5 bookings, 5 properties, 5 services)
- `earnings_spend_test.dart` — earnings + spend aggregations
- `messaging_reviews_test.dart` — chat + review flow
- `provider_store_test.dart` — provider CRUD
- `theme_test.dart` — light + dark theme tokens

---

## 6. What is NOT included (intentionally)

| Out of scope | Why | Where it lives in the FYP project |
|---|---|---|
| Supabase / cloud sync | Sprint 0 only | `lib/services/backend/supabase_backend_provider.dart` |
| Real authentication | Demo runs offline | `lib/features/auth/` |
| Real image upload | Placeholders only | `lib/features/service_tracking/` |
| Real-time status push | Polling-only for now | `lib/services/realtime/` |
| Tenant module | Different team member | (out of FYP scope) |
| IoT / utility monitoring | Different team member | (out of FYP scope) |
| Payment / billing | Different team member | (out of FYP scope) |
| Admin module | Different team member | (out of FYP scope) |

See the FYP project's [docs/architecture_decisions.md](../rental_app/docs/architecture_decisions.md)
for the 6 ADRs (Flutter for cross-platform, Supabase backend, MCDA weighted ranking,
FSM 9-state (Ch 2.4.5 + 2.7.3), before/after image + owner confirmation, Gantt chart-driven planning).

---

## 7. Cross-reference to the FYP project

| Demo screen | FYP code (TODO = not yet implemented in Sprint 1) |
|---|---|
| Owner Dashboard | `lib/features/owner/presentation/owner_dashboard.dart` |
| Provider Browse | `lib/features/provider_matching/presentation/provider_list.dart` |
| Booking Detail | `lib/features/service_tracking/presentation/booking_detail.dart` |
| New Booking | `lib/features/cleaning_booking/presentation/new_booking.dart` |
| Schedule | `lib/features/owner/presentation/schedule.dart` |
| Provider Inbox | `lib/features/provider_matching/presentation/inbox.dart` |
| Active Job Detail | `lib/features/service_tracking/presentation/active_job.dart` |
| Demo data | FYP: `supabase/seed/0001_demo_data.sql` |
| FSM rules | FYP: `lib/core/models/booking_model.dart` |
| Ranking weights | FYP: `lib/core/config/app_config.dart` |

---

## 8. Roadmap

See [SPRINT_PLAN.md](SPRINT_PLAN.md) for the full Sprint 0/1/2 breakdown and status.

---

## 3. UI Polish History (Rounds 7–12)

After Sprint 1, every screen was passed through 6 rounds of polish to reach
**/ui-ux-designer** standard. **122/122 tests pass · Web build OK · 0 hardcoded
hex colors in any screen · full light + dark mode.**

| Round | Focus | Screens touched |
|---|---|---|
| 7 | Edit profile polish (privacy toggle) | 1 |
| 8 | Provider stats + earnings history | 2 |
| 9 | 5 high-traffic screens (owner home, new booking, browse, chat×2) | 5 |
| 10 | 6 mid-tier screens (owner spend, property×2, schedule, provider×2) | 6 |
| 11 | 6 remaining screens (booking detail, notifications, schedule, reviews, about, login) | 6 |
| 12 | Onboarding final touch + animated accent tint | 1 |
| 13 | Touch-up of 2 Round 6 screens without explicit headers (reschedule + provider_job_detail modal sheets themed) | 2 |

### Key polish patterns applied
- **Theme tokens** — every `Color(0xFF...)` replaced with `AppColors.*` or `SemanticColors.of(context).*`
- **`AppTheme.primaryGradient`** — used on all hero cards (owner home, owner spend, earnings, stats, profile, login, about, property detail, provider inbox)
- **`intl.DateFormat`** — consistent date display across 8 screens
- **`SectionHeader` widget** — uniform section typography in 6 screens
- **Sticky submit / CTA** — `bottomNavigationBar` with "Ready to submit" hint on 3 screens
- **`PopScope` unsaved-guard** — new_booking warns before discarding in-progress form
- **Privacy respect** — `provider.showPhoneToOwners` honored in `provider_profile_screen`
- **Animated onboarding background** — accent-tinted bg that follows current page
