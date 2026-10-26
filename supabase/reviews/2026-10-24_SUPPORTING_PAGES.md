# P2-2 — supporting pages and clearly non-final review drafts

24 October 2026. Prototype code / automated checks PASS. Not legal approval,
public policy publication, real support delivery or manual device acceptance.

## Scope and boundaries

Original About & help brand card, navigation and FAQ appearance stay in place.
Terms and Privacy use the existing theme, a readable sectioned article and
selectable body text. One immutable content module owns version, notice, section
text and unresolved checklist; clipboard serialization includes all notices and
release gaps. No user data is included in copied static review text. Copy uses
the device clipboard only; it does not send the document or record acceptance.

Only exact `staging`, or an explicitly enabled local preview, offers drafts.
Production/unknown labels use a not-published explanation. The reader repeats
the environment check even on direct construction. These are client labeling
rules, not a security boundary or an authorization mechanism. No legal text is
secret, and no App role is granted new permissions.

Existing Contact support behavior remains: local/Staging own-session memory-only
test requests, explicit simulation, no mail/HTTP/cloud tickets, no real agent.
Production/unknown About never opens that simulation. Configured real-email copy
still only copies; absent contact explicitly reports nothing sent. No formal
contact address was supplied and none has been invented.

## Review of content against implementation

| Topic | Result / reason |
|---|---|
| Booking rules | Pending does not reserve; eligibility/conflicts are rechecked. Owner revision keeps duration/quote rules; different duration requires new request. Existing protected lifecycle unchanged. |
| Clock policy | Early/late start/completion remains unresolved. Draft does not promise that start is locked to scheduled clock time. |
| Interrupted requests | Timeout is not proof of commit/failure. Help directs readback before retry; no blanket promise that arbitrary duplicate writes are safe. |
| Messages | Only received displayed IDs count read for own account; list entry is not whole-thread acknowledgement. Quiet foreground counts poll about 30 seconds, not instant push; closed history readable, new send limited to active supported states. |
| Property privacy | Participants can access booking property context/address before acceptance. Private Provider origin not a directory field. No incorrect address-unlock-at-acceptance claim. |
| Evidence | Image re-encoding / validation is technical, not proof of service quality. Private storage / participant access does not equal E2EE or exclusive two-person access. |
| Sessions and retention | Native secure storage differs from browser session storage. Sign-out clears App session/memory, not cloud records. No invented retention period, instant deletion or completed export workflow. |
| Support | Memory-only simulation clears on session change/restart. Not a real support team or a privacy-rights request channel. |
| Money and missing integrations | Saved completed job value is not payment received. Fees/payouts, recurring appointments and device push remain clearly unavailable. |
| Approval | No effective date, consent checkbox/write, policy approval, verified operator, statutory compliance certification or launch readiness asserted. |

Implementation references: existing backend booking/message/review repositories,
auth_storage_native.dart / auth_storage_web.dart, evidence photo preparation and
validation flow, prototype_support_store.dart. No backend contract was changed.

## Verification

- 15 new `test/prototype_legal_drafts_test.dart` cases: static content/copy/version,
  fail-closed visibility, About routing/back, direct production/unknown denial,
  local preview, updated Help, both documents at 320px / 200% light and dark.
- `output/p2-support-focused.log`: 36 passed, includes existing notifications /
  Help / support creation, simulated reply, close/reopen, discard/reset and
  identity change tests.
- `output/p2-support-regression.log`: 688 default Flutter tests passed.
- `output/p2-support-android-build.log`: Staging debug APK built.
- `output/p2-support-analysis.log`: no errors/warnings; style infos remain.
- `output/p2-support-security.log`: 151 lib files PASS, no secret-pattern finding.

No hosted fixture write or security-policy deployment needed for static content.
No cloud deletion, production change, new dependency or PDF generated. Existing
dirty repository changes preserved. Automated widget layout is not physical
camera, accessibility screen-reader, hardware or emulator UAT.

## Remaining before public launch

Actual operator/contact, approved purposes and recipients/hosting/cross-border
handling, retention and backup deletion, usable access/correction/export/deletion
process, service timing/disputes/future money rules, incident handling and reviewed
published languages/documents. Current draft discloses these gaps; it does not
resolve them merely by displaying a notice. Obtain qualified review before
publication or real-person data processing/public rollout.

Reference: Supabase's shared responsibility model explains that App data/access
security remains a developer responsibility; hosting setup does not approve App
policies: https://supabase.com/docs/guides/deployment/shared-responsibility-model

Next P2-3: cross-page small-screen/theme/text/loading/error/keyboard/back-stack
checks. User postponed manual phone/emulator acceptance to P2-4; leave it pending.
