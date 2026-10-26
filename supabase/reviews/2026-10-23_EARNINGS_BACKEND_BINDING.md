# Original Earnings + real backend — 23 October 2026

## Delivered contract

- Provider Inbox Earnings navigation now opens the original EarningsHistoryScreen
  through a lifecycle-owned WorkspaceEarnings route. Existing light/dark design,
  period chips, hero, optional horizontal trend, job cards and detail sheet remain.
- Migration 020 adds only two reporting indexes and a read-only provider_earnings
  RPC. It was applied to linked Staging gqtetdavmrautoojaqrk after a dry run and
  synthetic PostgreSQL verification. Original dvakrwalnqpcmgirmlct is untouched.
- Identity comes from auth.uid(), with a database Provider-role check. There is no
  caller-selected Provider ID. Anonymous/service-role EXECUTE is denied. The
  SECURITY DEFINER function has an empty search_path and explicit own-row filters;
  no table privileges/RLS were widened. No properties, jobs, approval or cash
  records were written to hosted business tables.

## Amounts and dates

- The authoritative existing money field is booking.quoted_amount (MYR), frozen
  when a request is created. The report never recomputes it using current rates;
  this supports hourly and daily quotes without treating daily quotes as hourly.
- There is no fee ledger, payment processor or payout record. The old preview's
  15% calculation is NOT adopted as a real financial policy. Connected UI uses
  "Completed job value", shows saved gross quotes with two decimal places and
  explicitly marks platform fees/net payouts unavailable. It does not confirm
  payment, export a pretend statement or label gross as paid net earnings.
- Only currently Completed jobs count. Recognition uses the first Completed
  status-history timestamp, not scheduled service time, booking creation time,
  device timezone or payment time. Period boundaries use Asia/Kuala_Lumpur:
  last30 = today plus previous 29 calendar days; thisMonth = first day to as-of;
  allTime = all dated completions through the server as-of.
- Missing quotes are visible as unavailable and excluded from monetary sums, not
  silently repriced. Missing completion dates are separately disclosed and
  excluded from dated totals; no history is fabricated or backfilled.

## Reporting and lifecycle

- One SQL snapshot returns WHOLE-RANGE totals and trend buckets plus at most
  20 history items. Loading history pages cannot shrink totals to the first page.
- Completion timestamp + UUID keyset cursor preserves microseconds and handles
  ties. Later pages use the first response's as-of. Inconsistent aggregates or
  overlapping page items fail visibly and require refreshing. This is an as-of
  application report, not a multi-request PostgreSQL MVCC transaction/settlement.
- Last30 uses consecutive 7-day buckets; thisMonth calendar-week buckets; allTime
  monthly buckets (yearly for histories longer than ten years). Trend is summary
  only; actual job details are in the paginated history, not an incomplete bucket
  popup. Server numeric sums are authoritative; no client fee arithmetic.
- Session change clears data; route/background departure cancels Realtime;
  returning refreshes. Generation guards reject stale range/page responses.
  Network failures do not become zero/sample data. Live interruption is explicit.
- Small-screen/200% text tests found and repaired the date/amount row overflow.
  Original preview behavior remains isolated from connected repositories.

## Verification evidence

- Full Flutter suite: 515 passed (including new repository, race/session, paging,
  light/dark, narrow/200% text, empty-period and original-preview regressions).
- Synthetic PostgreSQL 17: complete migrations 001–020 and existing SQL/security/
  concurrency suites passed with both legacy broad defaults and disabled defaults.
  Earnings assertions cover whole-range totals beyond 20 rows, UUID timestamp ties,
  leap-day/MYT midnight, missing quote/date, daily quote, invalid cursor/period,
  Provider isolation and Owner/anonymous denial. Fixtures are rolled back locally.
- Hosted SDK smoke: both reusable accounts login/read paths passed; Provider reads
  all three earnings periods, Owner is denied (42501). Tests use local sign-out,
  not global session revocation. This proves real RPC connectivity/role behavior,
  not a populated hosted earnings or end-to-end payment acceptance.
- Android Staging debug APK compiled. Widget-render screenshots were inspected;
  they use explicitly synthetic local records and are not emulator screenshots.
- Targeted analysis contains style infos only; not a zero-lint claim. Scoped
  secret-pattern check is not a whole-repository security certification.

## Still pending

- Full original Profile binding is the next requested screen, not part of this task.
- Real cash settlements, fee policy/version snapshots, refunds and statements
  require their own trusted accounting/payment implementation and decisions.
- User emulator visual acceptance/populated booking completion flow remains to
  be performed; no production rollout or production-readiness claim is made.
