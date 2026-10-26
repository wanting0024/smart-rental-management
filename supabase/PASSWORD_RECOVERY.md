# Password recovery: implementation and manual acceptance

Updated 23 October 2026. This is local implementation evidence, not hosted
Supabase, mail delivery, device-link or launch approval. No hosted settings,
accounts, messages, credentials or database rows were changed for this task.

## Implemented contract

- An unauthenticated user requests a PKCE email with an explicit configured
  redirect. No Supabase Site URL fallback is used. Missing configuration disables
  the request action with an explanation rather than pretending mail was sent.
- Exactly the configured scheme/host/port/path and one bounded `code` parameter
  are accepted. URL-supplied recovery types, arbitrary redirects, implicit token
  fragments, duplicate parameters and unrelated links do not authorize recovery.
- Forgot-password requests start while signed out. Unsolicited reset callbacks
  while normally signed in are ignored, not used to force a logout. Sign out and
  request a fresh link when recovery is needed for a different account.
- The installed SDK's protected verifier must identify `passwordRecovery`. The
  server must successfully exchange that code/verifier pair. A local parameter,
  unsigned JWT decode or UI route alone is not verification.
- SDK broad URL auto-detection is disabled. One AppLinks listener owns native
  callbacks; the root route remains `/`. Login/signup/email initiation are
  serialized against callback exchange. Existing signup email confirmation is
  **verify email, then sign in with the password**, not automatic callback login.
- A durable project/environment-namespaced recovery marker precedes exchange.
  Recovery sessions cannot be read as ordinary persisted logins. Interrupted
  recovery is discarded before SDK restore and presents a new-link instruction.
- The app gates and unmounts private routes during recovery, clears in-memory
  account/image caches, and never loads Owner/Provider identity from this flow.
  This UI gate does not replace server Auth, JWT validation or RLS.
- The light/dark new-password form validates at least eight characters and exact
  confirmation, supports password visibility/autofill and larger text, suppresses
  repeated submission and clears its text controllers after terminal outcomes.
  Password values are not saved to app preferences or diagnostic logs; no claim
  is made that immutable Dart strings can be securely zeroized in RAM.
- Successful update clears local recovery credentials and requires a fresh
  password login. Weak/same-password errors allow correction with fixed messages.
  Invalid/expired/used links require a new link. An unknown update outcome explains
  that the password may have changed rather than blindly repeating the update.
- Failed vault cleanup retains a durable marker and blocks the workspace until
  cleanup can be retried. Remote logout failure does not restore local credentials
  or prove that every previously issued token/session was immediately revoked.
- Web captures a callback once and removes its URL fields before asynchronous
  backend initialization. Other Auth URL fields are scrubbed without granting
  recovery. `no-referrer` reduces URL leakage through browser referrers; it cannot
  erase prior hosting/proxy/email-provider logs or protect against same-origin XSS.

## Configuration boundary — do this together, manually

The new **public** client setting is `AUTH_RECOVERY_REDIRECT_URL`. It is not a
password, secret key, database URL, or service-role key.

| Build | Allowed callback | Still required |
| --- | --- | --- |
| Debug Web with staging backend | Exact current origin plus `/auth/recovery`; HTTPS, or loopback HTTP for development | Fixed port, same origin, staging Auth allow-list |
| Debug Android with staging backend | `smartrental://auth/recovery` | Exact staging Auth allow-list; physical device validation |
| Release Web | Actual HTTPS app origin plus `/auth/recovery` | Root-deployed SPA fallback, allow-list, hosting/privacy headers/log handling |
| Release Android/iOS | Chosen HTTPS callback | Domain ownership, verified Android App Links/iOS Universal Links, real signing identity, allow-list and device tests |

The development custom scheme is registered only in the Android **debug**
manifest. It is not a verified link and must not become the production fallback.
No iOS URL-scheme/associated-domain entitlement or release Android verified-link
host was invented: the real domain, bundle/package identity and signing
certificates must be chosen and configured together first. Windows/macOS native
URL association is also not implemented or claimed by these mobile builds.

Debug builds can leave the setting empty while unrelated work continues, but
recovery is then unavailable. Runtime release validation and the optional secure
release-build wrapper reject missing/non-HTTPS recovery settings, even in staging.
An HTTPS string passing validation does **not** prove domain ownership, its
association files, the hosted allow-list, or mail configuration is correct.

Manual sequence, when resuming Supabase setup:

1. Verify which account owns the intended project and create/confirm a genuinely
   separate staging environment. Do not change production to unblock testing.
2. Choose the platform and actual callback domain/origin. Enter its exact public
   URL in the ignored local build configuration; do not put secrets in that file.
3. In that staging project's Auth URL configuration, add the exact callback to
   allowed redirects. Avoid broad production wildcards; verify the Site URL too.
4. Check password rules (the form minimum is eight characters; stricter server
   rules still win), reset template, expiry, rate limits, secure-password-change
   behavior and sender/SMTP configuration. Confirm the email template uses the
   intended confirmation URL rather than discarding the redirect destination.
   CAPTCHA/abuse protection and production sender delivery still need review.
5. Configure real platform association files/entitlements and signed builds for
   release links. For Web, serve `/auth/recovery` through the same app's SPA
   fallback; this implementation assumes a root deployment, not a subdirectory.
6. Use explicitly provisioned staging accounts to request actual emails and run
   the acceptance cases below. Do not test with arbitrary real customer emails.

## Important Web limitation

Task 1 deliberately uses **per-tab sessionStorage**, including the PKCE verifier.
On Web, keep the requesting tab open and open/paste the newest email link in
**that same tab**. A new tab, another browser/device or cleared tab storage has
no verifier and must request a new link. Browsers can sometimes clone opener tab
storage; this is not a supported cross-tab guarantee. The screen explains the
constraint. A future cross-tab handoff/OTP design would need its own security and
UX review; persistent bearer-token localStorage was not reintroduced here.

Mobile recovery uses the same app installation's protected store. App restart
before opening a requested link is different from interruption *after* entering
recovery: the latter deliberately requires a fresh link.

## Acceptance cases not yet performed online

- Registered/unregistered email responses do not expose account existence.
- Real delivery, correct callback in both cold-start and warm-app conditions.
- Expired, reused, older-than-newest, modified and wrong-device/tab links.
- Opening a link while logged in, logging in, or holding a pushed private route.
- Weak/reused password, password-policy changes, loss of network during update.
- Cleanup while the device is locked, app termination and reopening afterward.
- New password works; old password fails; separately verify server session
  revocation behavior without claiming immediate invalidation of all old JWTs.
- Real Android Keystore/iOS Keychain, verified domain association and signed
  device builds; browser history/referrer/console and hosting log review.

## Local verification

- 20 recovery tests use the installed SDK and loopback-only HTTP with unsigned,
  explicitly synthetic sessions. They send no email or hosted network request.
- Four redirect/config tests, seven new-password widget/routing/preview tests and
  browser-only URL-scrubbing tests cover their respective layers. UI fakes are
  not evidence that Supabase accepted a real recovery link.
- Source/history/release-pattern checks are still bounded, conservative scans,
  not an independent security audit. All hosted/manual requirements above remain.

References: [Supabase Flutter reset API](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail),
[PKCE flow](https://supabase.com/docs/guides/auth/sessions/pkce-flow),
[redirect URL configuration](https://supabase.com/docs/guides/auth/redirect-urls),
[mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking).
