# Administrator-only developer tool; never imported into Flutter or Web assets.
# Creates only two fixed synthetic Auth identities and their self-managed profiles.
# No password rotation, user deletion, provider approval, property or booking seed.
[CmdletBinding()]
param([switch]$Execute, [string]$ConfirmProject = '')

$ErrorActionPreference = 'Stop'
$stagingAccountRoot = Split-Path -Parent $PSScriptRoot
$stagingAccountRef = 'gqtetdavmrautoojaqrk'
$stagingAccountUrl = "https://$stagingAccountRef.supabase.co"
$stagingAccountPath = Join-Path $stagingAccountRoot 'output/staging-private/accounts.local.json'
$stagingAccountDir = Split-Path -Parent $stagingAccountPath
if (-not (Test-Path -LiteralPath $stagingAccountPath)) {
    throw 'Missing private credential file. Do not invent replacement passwords or reset existing accounts.'
}
foreach ($stagingPrivateItem in @($stagingAccountDir, $stagingAccountPath)) {
    if ((Get-Item -LiteralPath $stagingPrivateItem).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Private credential paths must not be links.'
    }
    $stagingAccess = Get-Acl -LiteralPath $stagingPrivateItem
    $stagingCurrentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($stagingRule in $stagingAccess.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($stagingRule.AccessControlType -eq 'Allow' -and
            $stagingRule.IdentityReference.Value -notin @($stagingCurrentSid, 'S-1-5-18')) {
            throw 'Credential permissions must allow only the current Windows user and SYSTEM.'
        }
    }
}
if (-not (Get-Acl -LiteralPath $stagingAccountDir).AreAccessRulesProtected) {
    throw 'The private credential directory must not inherit broad permissions.'
}
$stagingCredentials = Get-Content -LiteralPath $stagingAccountPath -Raw | ConvertFrom-Json
$stagingClientConfig = Get-Content -LiteralPath (Join-Path $stagingAccountRoot 'supabase/backend_config.staging.local.json') -Raw | ConvertFrom-Json
if ($stagingCredentials.project_ref -cne $stagingAccountRef -or
    $stagingCredentials.environment -cne 'staging' -or $stagingCredentials.fixture -cne 'reusable-accounts-v1' -or
    $stagingClientConfig.APP_ENV -cne 'staging' -or $stagingClientConfig.SUPABASE_PROJECT_REF -cne $stagingAccountRef -or
    $stagingClientConfig.SUPABASE_URL -cne $stagingAccountUrl -or
    $stagingClientConfig.ALLOW_PRODUCTION_BACKEND -isnot [bool] -or $stagingClientConfig.ALLOW_PRODUCTION_BACKEND) {
    throw 'Only the pinned Staging environment is permitted.'
}
if (@($stagingCredentials.accounts).Count -ne 2 -or
    @($stagingCredentials.accounts | Where-Object role -CEQ 'owner').Count -ne 1 -or
    @($stagingCredentials.accounts | Where-Object role -CEQ 'provider').Count -ne 1) {
    throw 'Exactly one Owner A and one Provider A are required.'
}
foreach ($stagingAccount in $stagingCredentials.accounts) {
    if ($stagingAccount.email -cne "$($stagingAccount.role).a@rental-test.invalid" -or
        $stagingAccount.password -isnot [string] -or $stagingAccount.password.Length -lt 24) {
        throw 'Use only the fixed reserved test addresses and strong generated passwords.'
    }
}
if ($stagingCredentials.accounts[0].password -ceq $stagingCredentials.accounts[1].password) {
    throw 'The two test passwords must be different.'
}

function Invoke-StagingAccountRequest {
    param([string]$Path, [string]$Method = 'Get', [hashtable]$Headers, $Body = $null)
    if ($Path -notmatch '^/(auth/v1/(admin/users(?:\?page=\d+&per_page=100)?|token\?grant_type=password|logout\?scope=local)|rest/v1/(rpc/get_app_environment|user_account(?:\?.*)?|provider_profile(?:\?.*)?))$') {
        throw 'Unexpected endpoint refused.'
    }
    $stagingRequest = @{
        Uri = "$stagingAccountUrl$Path"; Method = $Method; Headers = $Headers
        ContentType = 'application/json'; TimeoutSec = 30; MaximumRedirection = 0; SkipHttpErrorCheck = $true
    }
    if ($null -ne $Body) { $stagingRequest.Body = $Body | ConvertTo-Json -Depth 8 -Compress }
    try { $stagingReply = Invoke-WebRequest @stagingRequest } catch {
        throw 'Staging request interrupted. Keep the same credential file; retry without creating alternate accounts.'
    }
    if ([int]$stagingReply.StatusCode -lt 200 -or [int]$stagingReply.StatusCode -ge 300) {
        throw "Staging account request failed (HTTP $([int]$stagingReply.StatusCode)). No credential or response body is logged."
    }
    if (-not [string]::IsNullOrWhiteSpace($stagingReply.Content)) { return $stagingReply.Content | ConvertFrom-Json }
}

$stagingClientHeaders = @{ apikey = $stagingClientConfig.SUPABASE_PUBLISHABLE_KEY }
$stagingMarker = Invoke-StagingAccountRequest -Path '/rest/v1/rpc/get_app_environment' -Method Post -Headers $stagingClientHeaders -Body @{}
if ($stagingMarker.environment -cne 'staging' -or $stagingMarker.project_ref -cne $stagingAccountRef) {
    throw 'Hosted marker mismatch; no account access permitted.'
}
if (-not $Execute) {
    @{ mode = 'READ_ONLY_PLAN'; project_ref = $stagingAccountRef; accounts = @($stagingCredentials.accounts | Select-Object label,role,email) } | ConvertTo-Json -Depth 4
    return
}
if ($ConfirmProject -cne $stagingAccountRef) { throw 'Execution requires explicit matching -ConfirmProject.' }

# Existing CLI authentication retrieves a legacy server key into memory only.
# No --reveal, key rotation, environment persistence, browser or App config write.
$stagingCli = Join-Path $stagingAccountRoot 'tool/backend-cli/node_modules/.bin/supabase.cmd'
$stagingKeyReply = & $stagingCli projects api-keys --project-ref $stagingAccountRef -o json
if ($LASTEXITCODE -ne 0) { throw 'Could not retrieve the existing administrator credential.' }
$stagingAdminKey = @($stagingKeyReply | ConvertFrom-Json) | Where-Object name -CEQ 'service_role' | Select-Object -First 1
try {
    $stagingAdminParts = $stagingAdminKey.api_key.Split('.')
    if ($stagingAdminParts.Count -ne 3) { throw 'Not a legacy administrator JWT' }
    $stagingAdminPayload = $stagingAdminParts[1].Replace('-', '+').Replace('_', '/')
    $stagingAdminPayload = $stagingAdminPayload.PadRight([int]([Math]::Ceiling($stagingAdminPayload.Length / 4.0) * 4), '=')
    $stagingAdminClaims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($stagingAdminPayload)) | ConvertFrom-Json
    if ($stagingAdminClaims.role -cne 'service_role' -or $stagingAdminClaims.ref -cne $stagingAccountRef) { throw 'Wrong administrator role/project' }
} catch { throw 'A valid existing Staging service credential is required; no secret was logged.' }
$stagingAdminHeaders = @{ apikey = $stagingAdminKey.api_key; Authorization = "Bearer $($stagingAdminKey.api_key)" }
$stagingExistingUsers = @()
for ($stagingPage = 1; $stagingPage -le 10; $stagingPage++) {
    $stagingUserPage = Invoke-StagingAccountRequest -Path "/auth/v1/admin/users?page=$stagingPage&per_page=100" -Headers $stagingAdminHeaders
    $stagingExistingUsers += @($stagingUserPage.users)
    if (@($stagingUserPage.users).Count -lt 100) { break }
    if ($stagingPage -eq 10) { throw 'User inventory exceeds this small Staging tool scope.' }
}
$stagingResults = @()
foreach ($stagingAccount in $stagingCredentials.accounts) {
    $stagingMatches = @($stagingExistingUsers | Where-Object email -CEQ $stagingAccount.email)
    if ($stagingMatches.Count -gt 1) { throw 'Unexpected duplicate test identity; stop for review.' }
    $stagingCreated = $false
    if ($stagingMatches.Count -eq 0) {
        $stagingMetadata = @{ requested_role = $stagingAccount.role; test_label = $stagingAccount.label }
        if ($stagingAccount.role -eq 'provider') {
            $stagingMetadata.requested_service_area = 'Kuala Lumpur'
            $stagingMetadata.requested_service_origin = '[TEST] Synthetic origin - no real address'
            $stagingMetadata.requested_hourly_rate = 40
            $stagingMetadata.requested_daily_rate = 280
        }
        $stagingUser = Invoke-StagingAccountRequest -Path '/auth/v1/admin/users' -Method Post -Headers $stagingAdminHeaders -Body @{
            email = $stagingAccount.email; password = $stagingAccount.password; email_confirm = $true
            user_metadata = $stagingMetadata
            app_metadata = @{ test_project_ref = $stagingAccountRef; test_fixture = 'reusable-accounts-v1'; synthetic_test_account = $true }
        }
        $stagingCreated = $true
    } else { $stagingUser = $stagingMatches[0] }
    if ($stagingUser.email -cne $stagingAccount.email -or
        $stagingUser.app_metadata.test_project_ref -cne $stagingAccountRef -or
        $stagingUser.app_metadata.test_fixture -cne 'reusable-accounts-v1' -or
        $stagingUser.app_metadata.synthetic_test_account -ne $true -or
        $stagingUser.user_metadata.requested_role -cne $stagingAccount.role -or
        [string]::IsNullOrWhiteSpace($stagingUser.email_confirmed_at)) {
        throw 'Existing/created identity does not match the expected confirmed synthetic test identity; no reset permitted.'
    }
    $stagingSession = Invoke-StagingAccountRequest -Path '/auth/v1/token?grant_type=password' -Method Post -Headers $stagingClientHeaders -Body @{
        email = $stagingAccount.email; password = $stagingAccount.password
    }
    if ($stagingSession.user.id -cne $stagingUser.id -or [string]::IsNullOrWhiteSpace($stagingSession.access_token)) {
        throw 'Password login did not return the expected test identity.'
    }
    $stagingUserHeaders = @{ apikey = $stagingClientConfig.SUPABASE_PUBLISHABLE_KEY; Authorization = "Bearer $($stagingSession.access_token)"; Prefer = 'return=representation' }
    try {
        $stagingId = [guid]::Parse($stagingUser.id).ToString()
        $stagingRows = @(Invoke-StagingAccountRequest -Path "/rest/v1/user_account?user_id=eq.$stagingId&select=user_id,email,role" -Headers $stagingUserHeaders)
        if ($stagingRows.Count -eq 0) {
            $stagingRows = @(Invoke-StagingAccountRequest -Path '/rest/v1/user_account' -Method Post -Headers $stagingUserHeaders -Body @{
                user_id = $stagingId; email = $stagingAccount.email; role = $stagingAccount.role
            })
        }
        if ($stagingRows.Count -ne 1 -or $stagingRows[0].role -cne $stagingAccount.role -or
            $stagingRows[0].email -cne $stagingAccount.email -or $stagingRows[0].user_id -cne $stagingId) {
            throw 'App account does not match the signed-in Auth identity and intended role.'
        }
        $stagingProfileStatus = $null
        if ($stagingAccount.role -eq 'provider') {
            $stagingProfiles = @(Invoke-StagingAccountRequest -Path "/rest/v1/provider_profile?provider_id=eq.$stagingId&select=provider_id,approval_status" -Headers $stagingUserHeaders)
            if ($stagingProfiles.Count -eq 0) {
                $stagingProfiles = @(Invoke-StagingAccountRequest -Path '/rest/v1/provider_profile' -Method Post -Headers $stagingUserHeaders -Body @{
                    provider_id = $stagingId; bio = '[TEST] Reusable staging Provider A - not a real business'
                    service_area = 'Kuala Lumpur'; service_origin_address = '[TEST] Synthetic origin - no real address'
                    hourly_rate = 40; daily_rate = 280
                })
            }
            if ($stagingProfiles.Count -ne 1 -or $stagingProfiles[0].provider_id -cne $stagingId) { throw 'Provider profile verification failed.' }
            $stagingProfileStatus = $stagingProfiles[0].approval_status
        }
        $stagingResults += @{ role = $stagingAccount.role; email = $stagingAccount.email; user_id = $stagingId
            auth_created = $stagingCreated; password_login = 'PASS'; app_role = $stagingRows[0].role; provider_approval = $stagingProfileStatus }
    } finally {
        $null = Invoke-StagingAccountRequest -Path '/auth/v1/logout?scope=local' -Method Post -Headers $stagingUserHeaders
        $stagingSession = $null
        $stagingUserHeaders = $null
    }
}
@{ mode = 'STAGING_TEST_ACCOUNTS'; project_ref = $stagingAccountRef; accounts = $stagingResults; passwords = 'LOCAL_PRIVATE_FILE_ONLY'; business_seeded = $false } | ConvertTo-Json -Depth 5
