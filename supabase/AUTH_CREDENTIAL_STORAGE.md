# Auth credential storage — task 1 (23 October 2026)

## Scope and behavior

Connected builds now pass explicit `LocalStorage` and `GotrueAsyncStorage`
adapters to the installed Supabase SDK. The existing anonymous environment
probe still runs **before** creating/opening any credential store or restoring
saved login. Missing/unassigned/mismatched backends still fail closed.

| Platform | New session/PKCE location | Important boundary |
| --- | --- | --- |
| Android | `flutter_secure_storage` AES-GCM storage, RSA-OAEP key wrapping with Android Keystore; environment/project namespace; automatic reset disabled | Not a promise of StrongBox/hardware backing, rooted-device protection or verified OEM backup behavior |
| iOS | Keychain, `unlocked_this_device`, synchronizable=false, app-specific account/key names | Does not require a biometric prompt. Locked-device failures do not fall back to preferences. Actual signed entitlement/device behavior is unverified here |
| Web | Namespaced `window.sessionStorage`, not long-term localStorage or the Web secure-storage plugin | Accessible to same-origin JavaScript; **not** HttpOnly, an OS vault, encryption, or XSS protection. Browser session restore/duplicated tabs may retain/copy it |

The native factory also configures the plugin's macOS options, but desktop
secure-vault behavior is **not certified/tested on actual desktop OSes**. Main
release targets remain Android/iOS; do not infer Windows/Linux/macOS readiness.

Keys use `rental.auth.v1.<environment>.<projectRef>`. Session and PKCE are
separate keys in that namespace. No private photos/chat are added to disk by
this task. No password, server secret or service-role key is stored here.

Web users normally stay signed in across reloads in the same tab, but should
expect to sign in again in a new/closed-tab session. This task does not add a
cross-tab logout broadcast or claim all tabs/devices are revoked. Browser restore
is not a cryptographic boundary. HTTPS is required except loopback development.
Cookies/BFF/XSS/CSP hardening are separate architectural/release work, not claims
made by switching to sessionStorage.

## Migration and failure handling

1. Read the exact previous `sb-<projectRef>-auth-token` entry only for the
   configured, server-verified project. Web also recognises the previous
   SharedPreferences `flutter.` spelling. Never enumerate/delete other projects.
2. Prefer an existing protected copy. Validate bounded JSON/session shape,
   user/subject consistency and the expected hosted issuer. These local checks
   do **not** verify JWT signatures or grant permission; the backend remains
   authoritative. Expired, structurally valid sessions can still be refreshed.
3. Write the candidate into the new store and read it back. Commit/read back
   the migration marker, then remove/read back the old plaintext entry.
   If protection is unavailable or writes/deletes fail, stop rather than use
   plaintext. Retry can complete a partially committed migration.
4. After migration is marked, an empty/corrupt protected store never reimports
   stale plaintext. Invalid legacy sessions are removed and require login.
5. Old global `supabase.auth.token-code-verifier` values cannot be attributed
   safely to a project, so they are discarded, not migrated. Request a **new**
   recovery/confirmation link after upgrading if a previous PKCE flow was open.
   Full recovery/callback UI remains task 3.

Preferences/localStorage retain only **non-secret** installation/logout intent
markers, not tokens. A completed Keychain migration whose app-install marker
has disappeared discards surviving credentials rather than silently restoring
an account after reinstall/preferences reset. This heuristic requires actual
iOS install/uninstall testing; it is not an assertion that all platform backups
behave identically or a reason to copy private preferences between devices.

## Logout, races and SDK integration

- One queue orders session, PKCE and migration operations. A generation counter
  synchronously blocks old queued persistence writes on logout. Writes also
  compare the event's access token to the current SDK session. A delayed SDK
  signedOut callback cannot clear a newer live session.
- A deliberate logout writes and verifies a **non-secret intent tombstone before
  deleting encrypted credentials**. It remains until an explicit new login/
  signup/recovery operation finishes cleanup and reopens writes. If deletion
  fails, next startup finishes cleanup instead of restoring a surviving token.
- Local logout cleanup is attempted before the remote request; the SDK is still
  asked to clear its in-memory session even on vault failure. PKCE cleanup must
  not suppress its signedOut event when full logout already owns cleanup.
- SDK Auth event persistence is asynchronous and its errors are internally
  caught. The app therefore explicitly awaits/reads back login persistence
  before reporting successful login, checks the session identity again, and
  signs that same session out if secure persistence fails. It does not sign
  another newly active account out to clean up an older failed operation.
- A partial SDK startup is disposed on failure, so Retry cannot silently reuse
  a partially initialized client/storage/listener set.
- Error messages from the storage boundary are sanitized; they contain no
  token, filename or raw plugin exception. Startup shows an unlock/retry/help
  message rather than opening a mock account. Broader existing logs elsewhere
  in the app are still task 2 and are **not** claimed fixed.

Local logout is **not** proof of immediate remote token revocation. It cannot
erase credentials already copied elsewhere or guarantee an issued JWT stops
working before its server-enforced expiry/revocation rules. Verify server Auth
behavior and account-disable rules separately in staging.

## Platform configuration and build limits

- Pinned `flutter_secure_storage: 10.3.1`: compatible with the current Dart 3.5
  SDK. Version 11.x requires newer Dart. No broad Dart/Flutter/Gradle/AGP
  upgrade or encryption implementation was invented in application code.
- Android compile SDK is 36 as required by the plugin; minimum SDK remains 23.
  The local Android build installed Platform 36 using existing SDK licensing.
  `allowBackup=false` plus explicit cloud/transfer rules exclude private app
  root/files/databases/preferences/external app data. This also excludes local
  settings, not just credentials; users reauthenticate/resync instead of
  transferring private app state. It does not delete gallery originals or
  change existing cloud backups retroactively.
- iOS Debug/Release (also used by Profile) xcconfigs reference app-only
  `Runner/Runner.entitlements`; no shared app access group or iCloud sync is
  enabled. Windows cannot perform Xcode signing/Keychain device verification.
- First dependency preparation reported Windows plugin symlink permissions;
  no Developer Mode/global Flutter setting was changed. A subsequent `pub get`
  completed and Android/Web builds passed, but Windows desktop plugin setup/
  execution was not verified and may still require Developer Mode on that host.

## Local verification

- **23** coordinator tests: checked migration/deletion, lost writes, failures,
  retries, corrupt/wrong-project sessions, expired-token preservation, queue
  races, logout tombstones, stale SDK callbacks, reinstall, scoped PKCE and
  namespace independence. Only synthetic unsigned sessions are used.
- **7** actual-installed-SDK tests against a local loopback protocol fixture:
  login/restore/logout, encrypted-store failure, failed deletion with signedOut
  notification, remote logout outage and protected PKCE generation. These are
  real SDK calls but **not** real Supabase Auth or cryptographic JWT validation.
- **4** native-adapter/config/UI tests use a mocked plugin/preferences. They
  verify the adapter's options/wiring, backup rules and no-bypass error UI,
  **not** actual Android encryption/iOS Keychain behavior.
- All **380** native Flutter regression tests passed; **26** Chrome HTML-renderer
  storage tests passed (23 core + 3 actual browser-storage checks). The release
  Web build and Android debug APK build passed. A debug APK is not a signed
  production release or security certification.

## Manual device/staging acceptance still required

1. On Android/iOS, sign in using dedicated staging test accounts, close/reopen
   the app, refresh tokens, then log out and restart. No old private route/photo/
   conversation may remain accessible. Check different Owner/Provider accounts.
2. Upgrade from the old preferences build with a test account. Inspect app
   storage using controlled developer tools; verify the legacy session/verifier
   is gone and protected values exist. Never put token dumps into screenshots.
3. Test device lock/unlock, unavailable Keychain/Keystore, interrupted migration/
   logout and next-start recovery. No plaintext fallback or login bypass.
4. Test actual backup/device transfer and iOS reinstall; verify old credentials
   do not reauthenticate the restored/new installation unexpectedly.
5. In Web, reload, new tabs, duplicate tabs, browser restart/session restoration,
   logout and storage-blocked modes. Document per-tab behavior without promising
   XSS protection. Verify new recovery flows separately when task 3 is built.
6. Verify remote signout/revocation/refresh expiry using actual Supabase Auth,
   including network loss. Do not interpret a local success or a 204 fixture
   reply as proof that copied remote credentials were invalidated immediately.

No hosted configuration, migration, account or real credential was changed by
this implementation. No full account/data deletion or privacy-policy promise
was added. See `SECURITY_AND_PRIVACY_TASKS.md` for the remaining six tasks.

References: [plugin documentation](https://pub.dev/packages/flutter_secure_storage/versions/10.3.1),
[Supabase initialization](https://supabase.com/docs/reference/dart/initializing),
[OWASP MASVS-STORAGE-1](https://mas.owasp.org/MASVS/controls/MASVS-STORAGE-1/).
