# Reusable Staging test accounts — 23 October 2026

User explicitly approved provisioning fixed Owner A and Provider A identities.
Target: smart-rental-staging / gqtetdavmrautoojaqrk only. The original project
dvakrwalnqpcmgirmlct was not queried or modified in this task.

## Created identities

| Label | Reserved synthetic email | Auth ID | Application role |
| --- | --- | --- | --- |
| Owner A | owner.a@rental-test.invalid | d04b8af2-d567-47c0-a39e-e6f115fb38d4 | owner |
| Provider A | provider.a@rental-test.invalid | 49dbedc2-1d45-4b29-b412-f6a8d95af34f | provider |

These undeliverable addresses are for password-based Staging testing only; they
cannot receive confirmation or password-recovery messages. Auth Admin created
each with email_confirm=true and server-owned synthetic fixture/project metadata.
This is not evidence of real mailbox ownership, email delivery or public signup
acceptance. Normal email confirmation remains enabled (mailer_autoconfirm=false).
See the official server-only createUser mechanism:
https://supabase.com/docs/reference/javascript/auth-admin-createuser

## Credential handling

- Different cryptographically generated passwords (24 random bytes each plus
  character-class prefix), stored only in ignored
  output/staging-private/accounts.local.json on this computer.
- The private folder has inheritance disabled. File ACL inspection confirmed
  only the current Windows user and SYSTEM can access it through the DACL.
- No password, administrator key or user JWT is included in this review, source,
  Flutter assets, command-line arguments, printed output or test fixtures.
- Existing CLI login retrieves the existing Staging service credential only into
  the child process memory. No new API keys, password rotations or global Auth
  setting changes were made.

## Actual verification

- Both users successfully authenticated with their generated passwords using
  the real hosted password-grant endpoint and the App's publishable client key.
- Each authenticated user created/read its own user_account through normal
  authenticated Data API/RLS permissions, not through raw administrator table
  grants. Roles and Auth IDs match exactly.
- Provider A has a self-managed synthetic profile, Kuala Lumpur service area,
  explicit non-real origin, and test prices RM40/hour and RM280/day. These are
  fixture inputs, not a new pricing business rule or real provider details.
- Provider approval remains pending; no capability/availability/approval was
  fabricated. The provider is not yet eligible for Owner search or booking.
- All temporary API verification sessions were signed out with scope=local;
  sessions/tokens were never saved in the credential file. Browser login is a
  user hands-on checkpoint, not claimed as completed by these HTTP tests.
- Executed provisioning a second time with the same file: both auth_created=false,
  password logins still passed, no duplicate accounts or password resets.
- Independent read-only database counts: 2 Auth users, 2 confirmed marked fixture
  users, 2 application accounts, 1 pending provider, 0 properties, 0 bookings.
- 19 offline safety-guard tests passed; configuration/ACL/project/identity inputs
  and HTTP are mocked. Scoped secret-pattern scan of the two scripts: no findings.

## Tool behavior / boundaries

tool/provision_staging_accounts.ps1 defaults to a read-only plan. Execution needs
-Execute -ConfirmProject gqtetdavmrautoojaqrk and the private credential file.
It reuses only identities with matching reserved email/server fixture metadata,
verifies passwords without resetting them, and stops on unexpected identity or
project state. It does not delete users or seed/approve business records. If the
private file is lost, do not invent another password and claim it is the existing
one; perform a separately authorized recovery/reset workflow.

These reusable human-testing identities are separate from the existing strict
UUID-address test-data-run seeder. No test_data_run, property or booking fixture
was created by this provisioning action. No complete E2E/permissions-isolation
sign-off is implied. Next: user logs in with Owner A, then Provider A, followed by
guided Provider approval/setup and the real booking workflow.
