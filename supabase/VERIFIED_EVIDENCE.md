# Trusted photo validation — hosted acceptance pending

2026-10-23 checkpoint: new smart-rental-staging has migrations 001–019 deployed
and postflight metadata verified. The user assigned its environment marker;
an independent read confirmed staging / gqtetdavmrautoojaqrk. User subsequently
deployed evidence-validate with --use-api. Independent hosted metadata confirmed
ACTIVE version 1, verify_jwt=true and matching entrypoint/import map. Unauthenticated
GET returned 401; an unapproved-origin OPTIONS request reached the handler and
returned 403 ORIGIN_NOT_ALLOWED. This is only a deployment/auth-denial smoke test,
not actual user upload or decoding/resource acceptance. Web allowed origins,
App configuration and real-account photo acceptance remain pending.
Original-project rollout is excluded. Gateway JWT verification is explicitly
true in local config.toml. Planned fixed Staging Web test address is
http://127.0.0.1:7391; do not use a wildcard origin or silently allow future domains.

## Trust boundary

The app still prepares/compresses photographs for usability. It reserves an
immutable upload ID with the existing quota/CAS RPC, then sends bounded binary
bytes to `evidence-validate`. It no longer writes directly to Storage.

The server verifies the bearer with Auth `/user`, claims the assigned provider's
registered ticket and obtains the path/size/SHA-256 from the database. It checks
the actual bytes, decodes pixels, copies only pixel data and re-encodes. Only the
canonical bytes enter private `cleaning-evidence` Storage. No raw staging bucket,
public URL, client-supplied destination, upsert or SQL blob deletion is used.

Migration 018 removes authenticated Storage INSERT permission, hides pending
objects, and requires a private server attestation for attachment and for a new
Completed transition. Existing permission, status, remarks, quota, replacement
CAS and cleanup rules remain. A verified upload is not automatically attached.

## Bounds and failure handling

- Input/output <=5 MiB; prepared dimensions <=1600 per edge /2.56 MP.
- JPEG: strict decoding with 64 MiB decoder budget. PNG: CRC-checked,
  non-interlaced 8-bit RGB/RGBA still images only, bounded preflight dimensions.
  Other variants/APNG are rejected. The app normally sends normalized JPEG.
- Fresh output excludes source EXIF/GPS/comments/text/ICC/thumbnail metadata.
  Pixels are not anonymized. The app must normalize orientation before sending;
  this endpoint does not claim to preserve arbitrary raw-file EXIF orientation.
- Source and canonical digests/sizes are separate; re-encoding changes bytes.
- One active request per isolate; cross-worker database lease is eight minutes,
  with at most three decoding attempts per ticket. A crashed worker can leave a
  temporary busy state; retry manually later. Same-ID verified retries do not
  re-encode or charge another reservation. Unknown failures never bypass attach.
- A claim is refused within ten minutes of the existing 24-hour pending cleanup
  boundary. This margin assumes hosted requests end within the platform's
  documented 150s Free /400s paid wall-clock limits. Reassess if runtime changes.
- Storage objects are immutable. After a lost write response the worker compares
  actual existing bytes to the canonical digest before attesting; it never trusts
  only metadata or overwrites a different object. Late/stale lease tokens fail.
- Definitive invalid-photo rejection asks for another photo. Busy/network errors
  retain the selection for reconciliation/manual retry. No auto-submit loop.

This is neither antivirus nor proof of cleaning quality, and it is not a global
traffic/billing cap. Request authentication/CPU costs still need gateway/global
abuse protection. Do not claim unlimited capacity or OWASP certification.

## Existing data / coordinated manual staging rollout

**Staging database and validator code are deployed; matching Web-origin/App
configuration and acceptance remain pending. Deployment is not usability approval.**

1. Together with the developer, confirm a separate staging project, backup and
   migration history. Inventory existing attached photographs before migration.
2. Unverified legacy records/objects are NOT erased, certified or silently
   reprocessed. They become unreadable through the new participant-photo policy
   and cannot support a new completion. Existing Completed records are retained.
   If real historical evidence exists, agree a supervised backfill/access plan
   before deploying 018. Do not simply mark it verified.
3. Deploy matching migration 018, `evidence-validate` and app as a coordinated
   staging change. Keep gateway JWT checks enabled; the handler also verifies
   Auth itself. Do not disable checks to work around a deployment error.
4. Function-only environment: platform `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY`; never put the server key into Flutter, defines,
   browser storage, committed files or logs. Configure `EVIDENCE_ALLOWED_ORIGINS`
   as exact comma-separated Web origins, including the exact development port
   if needed; no wildcard. Native bearer requests have no browser Origin.
5. Test Owner, assigned Provider, unrelated Provider and logged-out roles:
   normal upload/completion, forbidden direct Storage/attestation RPC attempts,
   wrong hash/size, corrupted files, large dimensions, interrupted upload,
   duplicate ID, competing replacements/leases, expiry and tombstoned cleanup.
6. Measure real Edge CPU/memory/latency with maximum prepared photographs.
   Local Windows/Deno passes do not prove the hosted 2s CPU budget. Do not raise
   limits or turn validation off if hosted performance fails; revise the worker.

## Reproducible local checks

From `supabase/functions/evidence-validate`: `npm ci --ignore-scripts`, `npm test`;
`node node_modules/deno/bin.cjs check index.ts`; and
`node node_modules/deno/bin.cjs test --allow-read codec.test.mjs handler.test.mjs backend.test.mjs`.
Dependencies and both lockfiles are pinned; production code imports only the
codec packages, not the development Deno binary. Never deploy node_modules or
test fixtures as app assets. Re-run dependency advisory checks before release.

From repository root: `pwsh -NoProfile -File tool/verify_local_migrations.ps1`
runs the complete chain/role checks and actual concurrent SQL sessions in its
own labelled, network-disabled disposable container. `local_test` is a shim-only
trusted-worker fixture, NOT a migration or hosted API. SQL metadata fixtures do
not pretend to decode files; byte tests run separately under Node and Deno.
Flutter SDK tests use a loopback HTTP server, not the real project.

Primary implementation references:
- https://supabase.com/docs/guides/functions/limits
- https://supabase.com/docs/reference/dart/functions-invoke
- https://github.com/jpeg-js/jpeg-js
- https://github.com/pngjs/pngjs
