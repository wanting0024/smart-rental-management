# Cleaning evidence photo lifecycle

## Current override: migration 018 (not deployed)

The current app sends bytes to the trusted `evidence-validate` endpoint, not
directly to Storage. Actual decoding/canonicalization and a server-only
attestation are now required before attachment/new completion; metadata alone
is insufficient. Existing unverified photos are retained but no longer readable
through participant access after 018. Review a legacy-data plan before rollout.
See `VERIFIED_EVIDENCE.md` for current behavior and coordinated manual staging
acceptance. The following 014 description is a historical implementation snapshot
and must not be used as the current upload/security specification.

## Implemented locally, not deployed

Migration 014 replaces direct client photo-pointer/remarks writes with provider-scoped RPCs. Apply all preceding migrations first. It does not delete any hosted file when applied. Review and test in the verified staging environment before production. Existing currently referenced photos stay readable; known old paths are registered as retired only when actually replaced. Unknown historical objects are not automatically classified as garbage.

Upload ticket states are separate technical states; they do not add to or rename the six authoritative booking lifecycle states.

1. A selected photo has immutable bytes, a client UUID and SHA-256 retry fingerprint. The Provider's screen retains the selection in memory for retries. Closing/restarting the app does not preserve that draft; the server still retains its registered ticket for cleanup.
2. `begin_evidence_upload` validates the assigned Provider, In Progress booking, JPEG/PNG manifest and 5 MB limit, then reserves an immutable object path. The previous path displayed to the Provider must still match the server, preventing stale screens from silently replacing newer photos even before upload begins. Reusing a UUID for a different booking/kind/size/fingerprint/previous path is denied. The fingerprint guards retry identity; it is not a server-side forensic validation of the actual image bytes.
3. The Storage upload uses `upsert: false`. A retry skips an already stored object. A lost Storage response is followed by an attachment check rather than blindly uploading another filename.
4. `attach_evidence_upload` verifies the object's metadata size/MIME and serializes with booking completion. It compares the photo path observed when the ticket was created with the current photo. A competing replacement is rejected instead of overwriting another device's edit. Replaying a confirmed ticket is idempotent; deleted/expired/superseded tickets cannot resurrect old photos.
5. Only after successful attachment is a replaced object marked retired. Current photos cannot be tombstoned or removed. Remarks use a separate locking RPC with server timestamps and a 1,000-character limit.
6. Provider refresh/upload recovery attempts a bounded cleanup pass. Failure is shown separately from photo-save success. Pending uploads have a 24-hour server-time grace period; an irreversible `deleting` state prevents concurrent reattachment. At most 20 objects are selected per pass. Only the Storage API removes bytes; final acknowledgement verifies disappearance before marking `deleted`.

The ImagePicker resize/quality settings remain 1600 x 1600 / 82 for connected evidence. JPEG/PNG signatures and byte size are checked in the app and size/MIME limits remain on the private bucket. These are not claims of malware scanning, decoded-image validation, guaranteed compression ratio, real-device quality verification or a completed media-retention policy.

## Unattended cleanup tool — not scheduled or run on hosted data

`tool/evidence_cleanup.mjs` provides a server/administrator-only batch worker. This is important when a Provider never reopens an abandoned booking. It calls service-role-only candidate/claim/finish RPCs and the Storage API; no broad bucket deletion or SQL deletion of objects is used.

Required runtime environment variables: `APP_ENV` (`staging` or `production`), `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, and `SUPABASE_SERVICE_ROLE_KEY` (the server-side JWT service-role key supported by this tool). Never put the service-role key in Flutter, a dart-define file, source control, screenshots, command-line arguments or chat. Configure it in the server/scheduler's private secret store.

- Default `node tool/evidence_cleanup.mjs` is **read-only dry run**: verify the server environment marker and count at most 20 candidates. It does not claim/tombstone/delete files.
- `node tool/evidence_cleanup.mjs --execute` explicitly enables deletion of that bounded batch. Production additionally requires `ALLOW_PRODUCTION_CLEANUP=true` in the server environment. Deletion through Storage is permanent; there is no undo guarantee.
- The entire returned batch is path-validated before deletion. Failed/unconfirmed deletion retains the tombstone for retry. Run a later pass if a batch is full. Credentials and raw response bodies are never printed.
- Deployment, hosted dry-run review and a recurring server scheduler still need manual setup. A suggested operational cadence is hourly, but no scheduler was created. Configure failure alerts and check recent successful runs before claiming unattended cleanup is operational.

## Required staging verification

- Use a Provider, its Owner and an unrelated account. Verify all private reads/writes and denied direct photo-pointer edits.
- Upload actual JPEG/PNG bytes through Storage, verify metadata representation, show both photos, replace one and confirm the old object's bytes really disappear while the current object remains.
- Simulate loss after Storage upload and after attachment commit, then retry the same ID. Simulate two devices replacing the same slot and completion racing photo/remarks writes.
- Test the worker's read-only preview first, then a bounded deletion of disposable fixtures. Confirm the current photos never appear as candidates, young pending uploads are retained, terminal bookings preserve current evidence, and failed deletion is retried safely.
- Check phone camera/gallery behavior, compression quality/EXIF handling and app background/restart behavior. Local SQL uses metadata shims and cannot establish those behaviors.

Primary service semantics: [Supabase deletion](https://supabase.com/docs/guides/storage/management/delete-objects), [Storage metadata is not object bytes](https://supabase.com/docs/guides/storage/schema/design), and [Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
