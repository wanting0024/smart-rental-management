# Offline guard tests: no real passwords, administrator keys or HTTP requests.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$stagingProvisionFixture = @{ Case = 'valid'; Calls = 0; Checks = 0 }
function Test-Path { param($LiteralPath) return $stagingProvisionFixture.Case -ne 'missing-file' }
function Get-Item {
    param($LiteralPath)
    return @{ Attributes = $(if ($stagingProvisionFixture.Case -eq 'linked-path') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Normal }) }
}
function Get-Acl {
    param($LiteralPath)
    $acl = [pscustomobject]@{ AreAccessRulesProtected = $stagingProvisionFixture.Case -ne 'inherited-permissions' }
    $acl | Add-Member -MemberType ScriptMethod -Name GetAccessRules -Value {
        param($explicitRules, $inheritedRules, $sidType)
        if ($stagingProvisionFixture.Case -eq 'broad-permissions') {
            return [pscustomobject]@{ AccessControlType = 'Allow'; IdentityReference = [pscustomobject]@{ Value = 'S-1-1-0' } }
        }
        return @()
    }
    return $acl
}
function Get-Content {
    param($LiteralPath, [switch]$Raw)
    if ($LiteralPath.EndsWith('backend_config.staging.local.json')) {
        $config = @{ APP_ENV = 'staging'; SUPABASE_PROJECT_REF = 'gqtetdavmrautoojaqrk'; SUPABASE_URL = 'https://gqtetdavmrautoojaqrk.supabase.co'; SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_synthetic_fixture'; ALLOW_PRODUCTION_BACKEND = $false }
        switch ($stagingProvisionFixture.Case) {
            'production-client' { $config.APP_ENV = 'production' }
            'wrong-client-project' { $config.SUPABASE_PROJECT_REF = 'aaaaaaaaaaaaaaaaaaaa' }
            'wrong-client-url' { $config.SUPABASE_URL = 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co' }
            'production-opt-in' { $config.ALLOW_PRODUCTION_BACKEND = $true }
        }
        return $config | ConvertTo-Json -Compress
    }
    $credentials = @{ project_ref = 'gqtetdavmrautoojaqrk'; environment = 'staging'; fixture = 'reusable-accounts-v1'; accounts = @(
        @{ label = 'Owner A'; role = 'owner'; email = 'owner.a@rental-test.invalid'; password = ('OwnerFixtureOnly' + 'a' * 20) },
        @{ label = 'Provider A'; role = 'provider'; email = 'provider.a@rental-test.invalid'; password = ('ProviderFixtureOnly' + 'b' * 20) }
    ) }
    switch ($stagingProvisionFixture.Case) {
        'production-credentials' { $credentials.environment = 'production' }
        'wrong-credential-project' { $credentials.project_ref = 'aaaaaaaaaaaaaaaaaaaa' }
        'wrong-fixture' { $credentials.fixture = 'unknown' }
        'one-account' { $credentials.accounts = @($credentials.accounts[0]) }
        'duplicate-role' { $credentials.accounts[1].role = 'owner' }
        'real-email' { $credentials.accounts[0].email = 'not-a-fixture@example.com' }
        'short-password' { $credentials.accounts[0].password = 'fixture' }
        'same-password' { $credentials.accounts[1].password = $credentials.accounts[0].password }
    }
    return $credentials | ConvertTo-Json -Depth 5 -Compress
}
function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $ContentType, $TimeoutSec, $MaximumRedirection, [switch]$SkipHttpErrorCheck, $Body)
    ++$stagingProvisionFixture.Calls
    if ($Uri -cne 'https://gqtetdavmrautoojaqrk.supabase.co/rest/v1/rpc/get_app_environment' -or $Method -cne 'Post') {
        throw 'Offline guard test refuses all account or other network endpoints.'
    }
    $marker = @{ environment = 'staging'; project_ref = 'gqtetdavmrautoojaqrk' }
    if ($stagingProvisionFixture.Case -eq 'wrong-marker') { $marker.environment = 'production' }
    return @{ StatusCode = 200; Content = ($marker | ConvertTo-Json -Compress) }
}
$stagingRejectedCases = @('missing-file','linked-path','inherited-permissions','broad-permissions',
    'production-client','wrong-client-project','wrong-client-url','production-opt-in',
    'production-credentials','wrong-credential-project','wrong-fixture','one-account',
    'duplicate-role','real-email','short-password','same-password','wrong-marker','missing-confirmation')
foreach ($stagingGuardCase in @('valid') + $stagingRejectedCases) {
    $stagingProvisionFixture.Case = $stagingGuardCase
    $stagingProvisionFixture.Calls = 0
    $stagingRejected = $false
    try {
        if ($stagingGuardCase -eq 'missing-confirmation') {
            & (Join-Path $PSScriptRoot 'provision_staging_accounts.ps1') -Execute | Out-Null
        } else {
            & (Join-Path $PSScriptRoot 'provision_staging_accounts.ps1') | Out-Null
        }
    } catch { $stagingRejected = $true }
    if (($stagingGuardCase -eq 'valid' -and ($stagingRejected -or $stagingProvisionFixture.Calls -ne 1)) -or
        ($stagingGuardCase -ne 'valid' -and -not $stagingRejected)) { throw "Unexpected guard result: $stagingGuardCase" }
    if ($stagingGuardCase -notin @('valid','wrong-marker','missing-confirmation') -and $stagingProvisionFixture.Calls -ne 0) {
        throw 'Invalid local inputs reached the network.'
    }
    ++$stagingProvisionFixture.Checks
}
Write-Output "PASS: $($stagingProvisionFixture.Checks) offline account-provisioning guard cases; no real credentials or HTTP used."
