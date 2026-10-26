# Caching and photo preparation — local checks complete; staging/device checks pending

## What is cached, and what is not

One `AuthenticatedMemoryCache` belongs to one backend client/project. It stores
only immutable values in application memory; there is no file, preferences or
database persistence and no new offline mode.

| Data | Policy |
| --- | --- |
| Private evidence image bytes | Two-minute TTL, keyed by immutable object path; fresh access check required before every hit |
| Service type ID/name reference list | Five-minute TTL; shared helper for Owner/Provider repositories; explicit force refresh API |
| Booking/status/history, availability, eligibility/ranking, quotes, payment decisions | Not put into this cache; existing server checks and page reads remain authoritative |
| Decoded Flutter image cache | Connected app: maximum 64 retained entries / 20 MiB; evidence display decode width bounded to 320–1200px |

The encoded/reference cache is bounded to **12 MiB and 24 entries** using LRU
eviction. At most four cache-owned loads may run simultaneously, with same-key
requests coalesced into one load. A value larger than the cache budget can be
returned but is not retained. Failed loads are never cached. Already-running old
loads still count against the in-flight limit after invalidation until they end.

TTL is checked on lookup; expired entries are pruned on cache activity, not by a
background timer. These are cache limits, **not** a cap on all app RAM, HTTP
authorization queries, explicit page state, displayed/live images, selected
files or temporary decoder buffers. Images currently displayed can retain live
references independently of Flutter's cache limits.

## Authorization and invalidation

`forBooking` remains a fresh server read. Before `download(path)` can use a byte
cache hit it fetches booking evidence again under the current authenticated
session and checks that the requested path is still the current before/after
photo. A missing row, revoked access, an authorization/network failure or an old
path does not fall back to cached private bytes. This adds a small metadata read
to each photo access while avoiding the repeated large image transfer.

Replacing a photo changes its immutable upload path. A fresh metadata result
evicts obsolete image entries/in-flight cache work for that booking. The cache
does not insert the selected local photo as if it were a verified download after
an uncertain upload; the existing ticket/attachment/read-back process remains.

Confirmed auth boundaries clear the cache and increment a session generation,
including A → signed-out → A. Late work cannot refill the new session's cache or
return a result after its generation changed. Sign-out/account changes also
clear Flutter decoded-image entries and private navigation. Memory-pressure
events and connected app disposal clear retained caches. Same-user token refresh
does not discard valid data or invent a logout.

Framework cache eviction is not secure erasure of process RAM. In-flight HTTP
reads/codecs may finish after invalidation; their results are ignored and new
accounts do not receive the old byte objects. Browser/network/OS caches are not
the application's memory cache. New uploads set Storage cache-control freshness
to zero, but that is not a promise of `no-store` or deletion of browser history.
Shared-device behavior remains a manual privacy check.

## Actual image preparation before upload

The file chooser's resize/quality settings are optimization hints, not proof of
the final file. The application now verifies/processes its returned bytes:

1. Accept JPEG/PNG selections up to 20 MiB, at most 24 megapixels and 10,000px on
   either input edge. Reject unsupported, damaged and multi-frame inputs.
2. Decode the actual pixels and normalize orientation without rotating twice.
3. Resize without cropping/upscaling to a maximum 1600px output edge. Preserve
   aspect ratio; transparent areas are flattened onto white for the JPEG photo.
4. Produce fresh RGB JPEG output without copying source EXIF/GPS, text/comments,
   thumbnails or source metadata profiles.
5. Use quality levels 82/74/66 as needed; if necessary make a 1280px fallback at
   quality 74. Reject if a supported result still exceeds **1 MiB**. Do not lower
   quality indefinitely until any input is accepted.
6. Keep the prepared bytes, upload UUID, hash and expected previous path stable
   through retries. Preparation failure makes no upload/attachment/uncertain-write
   verification call. The source file is not modified.

The 20 MiB input limit applies to bytes returned by the chooser, which may already
have resized/converted the original. HEIC/other unsupported outputs require export
as JPEG/PNG; camera/gallery behavior needs real iOS/Android checks. Tiny/simple
PNG images can be smaller than their prepared JPEG, so the app displays actual
output dimensions/size rather than promising a percentage reduction for every file.
Original client encoding may differ between platforms even with the same policy.

Large native preparation runs in a Flutter isolate. Very small native selections
use the same synchronous validator/encoder without isolate overhead. Web uses
browser-native image decoding, canvas resizing and asynchronous JPEG encoding,
not Dart's synchronous pixel loop via web `compute`. Temporary browser Blob URLs,
image listeners and canvases are released. Only one expensive preparation runs at
a time across routes, including while a disposed route's job is finishing. No
image is sent to an external processing service.

The existing server/bucket limit remains 5 MiB for JPEG/PNG, including compatible
older records; new client-prepared photos are below that limit. Client validation
is not a security boundary against a modified client. Hosted Storage still needs
server-side inspection/quarantine policy if actual decoded-content validation is
required against malicious uploads. This step does not deploy such a scanner or
claim that photographs independently prove cleaning quality.

## Verification evidence

- All **346 native Flutter tests** passed. New cases cover LRU/TTL, byte/entry/
  in-flight budgets, read coalescing, failure retry, identity epochs, stale work,
  decoded output dimensions, size limits, orientation, metadata removal,
  transparency, invalid/animated input and preparation concurrency.
- **12 Chrome HTML-renderer tests** passed against the image code. Both the native
  and Web asynchronous paths produce real decodable JPEGs within the same policy;
  their output bytes are not asserted identical. The default CanvasKit test
  bootstrap did not complete in this environment; that is not claimed as a pass.
  The release Web build succeeds, but visual testing of the deployed renderer and
  other browsers remains outstanding.
- A deterministic **synthetic** textured JPEG fixture was 772,926 bytes; an observed
  native output was 180,795 bytes and Chrome output 175,134 bytes. Those are fixture
  checks, not population results, a universal compression ratio or a real-device
  performance/cleaning-detail benchmark. The browser's native codec avoids the
  slow pure-Dart debug pixel-processing path found during testing.
- SDK loopback responses verify private cache hits still perform metadata checks,
  403/empty-record denial prevents cached reads, replacement paths invalidate old
  data, account changes re-download, and reference results are immutable and
  explicitly refreshable. These are **not hosted RLS/Storage certification**.
- Existing upload tests now verify JPEG payloads and the same prepared byte object/
  ID on retry. Root fixtures verify account cleanup and memory-pressure eviction.
  The inspected retry golden `test/goldens/evidence_photo_retry.png` is a synthetic
  widget preview, not a real uploaded cleaning record.

No SQL migration, hosted account, real evidence file, bucket policy, project key
or production data was changed. The image codec and Web interop dependencies were
added to the local locked dependency set without upgrading the existing stack.

## Before production sign-off

1. Manually configure/deploy the existing schema in staging, then test distinct
   Owner/Provider/outsider accounts against real private Storage/RLS. Reopen the
   same evidence twice and inspect network requests: metadata must be fresh while
   a valid image byte cache hit avoids another large body transfer. Revoke access,
   replace the path, expire the TTL and repeat from another account/device.
2. Verify JPEG/PNG/HEIC camera/gallery behavior, orientation, dark/bright rooms,
   text labels, damaged/large images and before/after cleaning detail on actual
   Android/iOS devices and target browsers. Establish acceptable evidence quality
   from real images, not just file-size tests.
3. Profile preparation latency, interaction responsiveness and peak RAM on low-end
   devices. Test background/back navigation during processing, memory pressure,
   interrupted upload, retained-selection retry and private-image logout behavior.
4. Confirm server-side file-validation requirements, logging without photo/token
   exposure, and the already-pending cleanup worker/staging setup. Decide any
   minimum useful photo resolution/quality rule explicitly; no new business rule
   for minimum image resolution was silently introduced here.

Reference behavior: [Flutter decoded-image cache](https://api.flutter.dev/flutter/painting/ImageCache/clear.html),
[Flutter compute](https://api.flutter.dev/flutter/foundation/compute.html),
[image codec package](https://pub.dev/packages/image),
[Supabase private downloads](https://supabase.com/docs/guides/storage/serving/downloads).

Next separate item: labelled test-data fixtures and narrowly scoped test-data
cleanup; hosted Supabase setup and real two-account/device verification remain.
