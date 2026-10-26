# Secret and log protection — task 2 (23 October 2026)

## What changed locally

- Eighteen raw exception log calls in connected booking, chat, evidence,
  property, review and Provider setup screens now use `SafeDiagnostics`.
  The allow-listed fields are enum operation, enum failure category and a
  process-local sequence reference. No arbitrary message, runtimeType, stack,
  request/response, account ID, email, address, photo link or chat body is
  rendered. Unknown errors remain `unknown`; the original object is never
  converted to a string by this logger. Sink failures do not fall back to raw
  output. App diagnostics are disabled by default outside debug builds.
- Connected Supabase initialization explicitly uses `debug: false` so the SDK
  does not install its default raw-error console forwarding subscription.
- Framework/uncaught-dispatcher boundaries use the same safe diagnostics;
  ErrorWidget displays fixed guidance instead of exception details. This is
  not a promise that every native plugin/browser/OS diagnostic is filtered,
  and it does not add remote crash reporting or an analytics service.
- Login/registration errors map typed codes to fixed UI guidance. A typed role
  mismatch retains the useful Owner/Provider selection instruction; raw server
  messages and arbitrary StateError strings are no longer shown to users.
- Existing key/environment guards remain. No server secret was added to App
  configuration, and no business state/permission/pricing rule was rewritten.

These protections run automatically when the App executes. They do not mean
developers should stop running regressions or inspecting release artifacts.

## Scanner scope and honest limits

`tool/security_scan.py` uses Python's standard library, reads locally, makes
no network requests and writes no report file or matched credential. Output
contains only status, counts, safe location, rule and approximate line. Paths
that themselves look sensitive are withheld. Exit codes:

- `0`: no covered pattern found in the selected readable scope;
- `1`: blocked finding/configuration;
- `2`: incomplete/error/unsupported or over-budget input — never success.

The worktree pass includes recognized text/config suffixes and ignored local
JSON/environment files, while excluding build/cache/dependency directories.
It also guards common raw log calls and raw `$error` interpolation in `lib/`.
This is a conservative syntax guard, not a full Dart AST/data-flow analysis.
Unrecognized file types, split/constructed/obfuscated secrets and new provider
formats require independent review; a clean result is not proof of absence.

`--history` reads objects reachable from **all current local Git refs**,
including previously deleted content. It does not scan remote-only branches,
unfetched repos, reflogs, dangling objects or secrets stored outside this
checkout. History is not rewritten. Ignore rules do not remove tracked history
or revoke a leaked credential.

Covered patterns include recognizable Supabase server secrets, service-role
and authenticated-user JWTs, refresh-token JSON, Stripe secrets/webhook keys,
GitHub token formats and complete private-key PEM material. Public Supabase
publishable/anon keys are allowed; their presence is not itself a secret leak.
An apparently expired private session is not silently exempted. The scanner
does not cryptographically verify keys or probe their validity online.

`--config` additionally parses the selected JSON, including JSON escapes,
checks client-only build fields, environment/project/HTTPS consistency and
production opt-in, and rejects private/unknown configuration fields. It does
not validate the hosted marker or test live authentication.

`--artifact` scans all selected Web files and bounded ZIP/APK/AAB/JAR members,
including decoded compressed contents and common UTF-8/UTF-16 representations.
It never extracts archives. Private signing containers, private .env files and
local backend-config files inside artifacts are blocked by name as well.
Unreadable, encrypted, corrupt or over-budget inputs fail closed; default
limits are 256 MiB/file, 2 GiB processed total, 20,000 Git objects/archive
members, nested ZIP depth two and 32 MiB nested-container size. This is not an
APK decompiler or a generic deobfuscator. Oversized legitimate builds need a
reviewed limit/scope adjustment, not a blanket ignore rule.

### Investigated debug-Kernel false positive

The actual debug APK's `kernel_blob.bin` raw pass reported a server-key-shaped
144-character sequence. A read-only review using Dart 3.5.4 Kernel format 119
string-table end offsets confirmed that `sb_secret_` is a separate complete
10-byte string and the raw match spans **ten separate strings**, rather than
one complete key. No matched value was printed, copied into a report or
allow-listed. The conservative scanner continues to block this debug-byte
pattern; future hits still require review. The independently built release/AOT
APK and Web outputs passed. Do not treat a debug binary byte match as proof
of a live key, or use this one review to waive unrelated findings.

Format reference: [Dart 3.5.4 Kernel binary format](https://raw.githubusercontent.com/dart-lang/sdk/3.5.4/pkg/kernel/binary.md).

## Release gate: reusable, not automatically imposed on every Flutter command

`tool/secure_build.ps1` performs:

1. worktree + reachable local history + selected client-config preflight;
2. release build, withholding raw compiler output from the shared log;
3. packaged-artifact scan, followed by success only when every stage passed.

It does not deploy/publish. Failed/incomplete scans or a nonzero compiler exit
block success. The script supports `web`, `apk` and `appbundle`, uses no private
credential command-line argument, and accepts executable paths for a developer
toolchain not on PATH. For example, from a trusted PowerShell 7 developer
terminal, after the staging/production configuration has actually been prepared:

```powershell
./tool/secure_build.ps1 -Target web -ConfigPath ./supabase/backend_config.staging.local.json -FlutterExecutable C:/src/flutter/bin/flutter.bat
```

Use your production config only in the intentional production release workflow.
Do not put server/admin keys, signing passwords or user tokens into this config.
Use process environment/appropriate protected secret stores for separate admin
tools. No machine-wide execution policy was changed; classic Windows PowerShell
may refuse unsigned scripts under its current policy. Use your organization's
approved developer terminal/policy rather than disabling system safeguards.

**Direct `flutter build` commands bypass this wrapper.** No GitHub/other CI
service or remote repository settings were configured. Wire the wrapper or
equivalent preflight/artifact steps into the actual release pipeline before
relying on it as an enforced gate. A developer who can edit source/scripts can
also bypass a local check; this is not an authorization boundary.

This gate covers secret/logging patterns, **not complete release readiness**.
Android's existing debug-signing fallback for a release APK is still a task-7
issue. A locally built release-mode APK is not approved for publication merely
because the secret scan passes. AAB/real signing and hosted environment checks
remain separate. CI should also add an independently maintained secret scanner
and dependency auditing rather than relying solely on this bounded local tool.

## What to do if a real secret is found

Stop publication. Privately verify the location/type without pasting the value
into chat, screenshots, tickets or logs. Coordinate credential revocation/
rotation with the project owner. Removing current source or adding .gitignore
is not revocation. Existing distributed artifacts/history may still contain
the old value. No rotation, remote deletion, history rewrite or private-key
recovery was automatically performed by this task.

## Verification evidence and remaining checks

- Eight new Flutter tests cover allow-listed output, no error stringification,
  default disabled production logging, sink failure, fixed categories/Auth UI,
  sanitized framework/async/ErrorWidget paths and explicit SDK logging disable.
  All **388** Flutter regression tests passed. Seven portable logging/boundary
  tests also passed in Chrome HTML renderer; the filesystem source check is
  intentionally VM-only.
- Thirteen Python tests (ten scanner, three gate tests) use temporary synthetic
  fixtures. They cover redacted output, public/private JWT distinction, UTF-16/
  chunk boundaries, ZIP members/private containers, escaped configs, corrupted/
  over-budget data, deleted Git-history content, source logging guards, and
  clean/preflight/compiler/artifact gate paths. Gate orchestration uses a fake
  compiler in an isolated temporary Git repo — not the user's repo/history or
  real production credentials.
- Actual release Web and Android debug/release-mode APK builds succeeded. Source,
  the 307 objects reachable in the current local history and actual **release**
  Web/APK content passed the covered checks. No production-connected signed
  release gate was run, no AAB/device log certification is claimed, and no
  actual sensitive key or token was printed during investigation.
- New diagnostics/boundary/Auth-message helper and test files pass targeted
  analysis. Existing legacy UI style warnings are not a security certification
  or a claim that the entire repository is lint-clean.

Remaining: controlled Android logcat/iOS Console and browser-console review
under real staging failures, native-plugin logging, independent secret scanning,
CI enforcement and final release signing. Safe diagnostics do not replace
RLS, upload checks, privacy notices, retention or account deletion.

References: [OWASP production logging guidance](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0022/),
[Flutter debugPrint behavior](https://docs.flutter.dev/testing/code-debugging),
[Supabase key guidance](https://supabase.com/docs/guides/getting-started/api-keys).
