# Owner / Provider usability sessions

Status: preparation ready; no human sessions have been conducted or supplied by this kit.

Open `index.html` in a browser, or serve this directory locally. The recorder is a facilitator tool. It is separate from the rental app and does not connect to Supabase. It makes no network requests and stores no passwords. CSV and JSON export contain only the attempts you explicitly save.

## What can be evaluated now

| Activity | Current boundary |
| --- | --- |
| Review existing local screenshots and component layouts | Available for formative UI feedback; label LOCAL_UI_REVIEW. The debug preview uses a separate local-data route and is not proof of the connected workflow. |
| Facilitator rehearsal | Available; leave the observed-session checkbox off. Records are FACILITATOR_DRY_RUN, never participant findings. |
| Timed real first-booking task | Pending hosted setup and a verified connected build with separate accounts and working fixtures. |
| Full Owner-Provider booking, chat, private evidence and rating session | Pending real Auth/Storage/Realtime and separate-account checks. Local PostgreSQL and Flutter tests are supporting engineering checks, not human observations. |
| Weighted matching / dynamic alternatives / payment / push / full schedule and profile evaluation | Deferred until their connected implementations exist. Do not count an unavailable feature as a successful task. |

The current release app without backend configuration shows its configuration message. A successful release build alone is not a runnable connected test environment. The session-ready checkbox is a facilitator declaration, not an automatic backend audit.

## Report alignment

Read-only source reviewed: `C:/Users/yunli/Downloads/RSW_OhWanTing_SmartRentalManagementMobileApplication_OwnerAndCleaningServiceProviderModules.pdf`, PDF pages 93-98, especially page 96, Section 3.4.2, NFR3.2.

- NFR3.2 requires a first-time Property Owner to submit a valid cleaning booking in 5 minutes without external guidance, excluding email verification and external payment delays.
- Timed O02 starts on authenticated Owner Home with the unit prepared in O01. Stop at the acknowledged server Pending result. Describe this pre-created-unit condition explicitly in the evaluation report; it does not measure registration or adding the first unit. If the supervisor requires those activities inside the five-minute interval, revise the protocol before collecting data and report the changed start point.
- Do not replace the five-minute target with a new score or claim. Any external task guidance makes an otherwise completed attempt Assisted and fails the unguided condition. Failure also fails an eligible attempt. Backend/environment blockers are not evaluated; retain and report their count rather than hiding them.
- A local review, rehearsal, non-first-time attempt, unverified environment or repeated O02 by the same anonymous participant cannot establish NFR3.2. The tool preserves elapsed milliseconds, so 300.001 seconds does not pass a 300-second threshold.
- NFR1.1 (submission response within 3 seconds for 95% of executions) and NFR1.3 (receiving UI update latency) require separate instrumented technical measurements. The full-task timer here does not measure those requirements.
- NFR2.2 physical screen sizes and NFR3.3 device accessibility still require hands-on checks. Logical-pixel widget tests alone do not establish physical device coverage.

Current implementation decisions also allow cancellation of Accepted work before it starts and use an 8-hour daily package. The supplied report retains the older before-acceptance cancellation statement in FR1.12. Resolve/report that difference separately; O06 deliberately uses Pending to avoid assuming that the report was updated.

## Before inviting users

1. Use the evaluation environment and record the exact build, device/OS, physical screen size, text/display scale, theme and connection. Ask for consent before observing or recording a screen. Store identity/consent separately from anonymous codes such as P01.
2. Verify two different authenticated Owner and Provider accounts. Confirm provider approval, supported service types, time windows, private storage, status history, chat delivery and review saving in the exact connected build. Follow the existing manual Supabase setup process; this kit does not apply migrations or change accounts.
3. Prepare isolated fixtures. Do not use real tenant addresses, occupant schedules, personal photographs or live payment cards.
4. Rehearse the sequence as FACILITATOR_DRY_RUN. An engineering rehearsal is useful for removing environment failures before user time is spent, and remains separate from participant evidence.
5. Recruit actual people appropriate to each role. A small formative round can start with 3 Owners and 3 Providers as a practical project plan, not as a statistical sufficiency claim or university-mandated sample. Record their relevant experience and actual numbers separately. Do not reuse the earlier synthetic questionnaire dataset as usability evidence.

## Fixture and paired-session sequence

Use a future Malaysian date D and an agreed standard cleaning service. Example operational test data: Unit UX-01, Usability Test Building; 2 bedrooms, 800 sqft; a clearly marked fictional address; unit cleaning window 09:00-17:00; Provider weekly availability 08:00-18:00, supporting Standard cleaning, hourly rate RM40 and daily rate RM280. A two-hour 10:00-12:00 request should quote RM80. These are test fixtures, not fabricated participant identities or observations. Do not use the fictional address to claim route-distance correctness.

Use non-identifying JPEG/PNG photos smaller than 5 MB. Retain the server Booking ID as an evidence reference if permitted. Start/completion tasks must satisfy actual server time rules; schedule a suitable session or prepare a separate valid In Progress fixture. Never disable a backend rule just to complete an observation.

| Order | Session action | Dependency |
| --- | --- | --- |
| 1 | Provider P01 services/hours; Owner O01 unit | Prepare D before a confirmed booking depends on it. |
| 2 | Owner O02 first request | This is the timed first-booking attempt; no booking walkthrough first. |
| 3 | Provider P02 acceptance; Owner O03 status/history | Retain the same Booking ID in both records. |
| 4 | Owner O04 message; Provider P03 reply | Accepted/In Progress booking. |
| 5 | Provider P04 start/evidence/completion | Use a valid service time and the real lifecycle rules. |
| 6 | Owner O05 evidence/rating; Provider P05 feedback | Completed booking, then saved Owner review. |
| 7 | Owner O06 cancellation; Provider P06 decline | Separate disposable Pending requests. |

P05 evaluates the booking-linked review view only. It does not establish FR2.10's full profile aggregates/history. Successful acceptance by a user does not prove transaction atomicity, RLS or concurrency safety; retain the separate technical tests.

## Facilitation script

Before the session: "We are testing the application. Please work as you normally would. You can stop at any time. I will ask you to do several tasks and observe where the app is clear or confusing. Please do not enter personal information."

Read only the task prompt in the recorder. Keep facilitator setup/expected results collapsed. Do not explain control names, click locations or the required sequence while an unguided attempt is running. If assistance becomes necessary, record what was said and the guidance count. Do not silently pause the timer to remove hesitations or network delays. Record interruptions and blockers.

For the timed O02 measurement, avoid requiring continuous think-aloud commentary, which can change completion time. Ask retrospective questions afterwards: "What did you expect to happen?", "What was unclear?", "What does Pending mean to you?" and "Was there any moment you did not know what to do next?"

After each task ask the optional task-ease question shown in the tool. It is a project-specific 1-5 question, not the System Usability Scale. Do not report it as a validated SUS score.

## Recording and interpretation

- Independent: correct goal reached without external task guidance. Assisted: goal reached with hints. Failed: attempted but not completed. Blocked: environment, unavailable feature or invalid fixture prevented an interpretable task attempt.
- Record the actual outcome, guidance, elapsed time, comments and evidence reference. For O02, manually confirm the intended server Pending result. The recorder cannot inspect the app or database; the checkbox does not itself prove persistence.
- PASS/FAIL is calculated only for an eligible O02 observation. A missing server confirmation yields UNVERIFIED; other exclusions yield NOT_EVALUATED. Only the first saved observed O02 per anonymous participant can be eligible, even if the first record was a local review. Do not relabel a retry as first-time.
- Export CSV and JSON after the session. The CSV quotes commas/newlines and neutralises spreadsheet formula prefixes. Keep source exports unchanged; analyse a copy. Participant names, contact details, passwords and payment data do not belong in these records.
- Summaries must state the role, observed attempt count, distinct participant count, environment, exclusions and denominators. Independent completion rate = Independent / (Independent + Assisted + Failed) for the specified task and environment; report Blocked separately. Report assisted completions separately, not as independent success. These small formative samples do not establish population-wide effectiveness.
- For O02 report eligible first attempts and their individual times/assistance, then how many met the five-minute condition. Do not pool local reviews or dry runs into that denominator. List blocked/unverified attempts and explain them.
- This kit contains no results section. Write actual findings and report amendments only after observation records exist.

## Issue log and follow-up

Create one issue per distinct problem. Merge repeated observations under the same issue while retaining the participant/task evidence.

| Issue ID | Task / requirement | Build / mode | Observed action and exact difficulty | Impact | Proposed change | Retest evidence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | |

Impact: Critical = blocks the core task or causes an incorrect booking/evidence outcome; Major = requires help or a significant detour; Minor = momentary confusion with recovery; Preference = subjective styling request without an observed task impact. Prioritise Critical/Major issues, implement a focused change, then observe the affected task on the new build. First-time booking timing requires a new first-time person, rather than timing a now-trained user as first-time.

Suggested final write-up structure: participants and consent; device/build/setup; tasks and measurement endpoints; actual outcomes and exclusions; observed problems with evidence; changes made; retest outcomes; remaining limitations. Preserve acceptable report content unless the observations establish a factual inconsistency or justify a requirement/design change.

Task 7 completion requires actual observed sessions, reviewed issues, fixes where needed and retest evidence. A prepared recorder, an automated test pass or a browser walkthrough does not complete human usability validation.
