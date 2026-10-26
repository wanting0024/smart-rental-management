# Offline regression tests: mock every HTTP call and never read real credentials.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$stagingFixtureState = @{ Case = ''; HttpCalls = 0; Checks = 0 }

function Test-Path {
    param($LiteralPath)
    return $stagingFixtureState.Case -ne 'missing-config'
}

function Get-Content {
    param($LiteralPath, [switch]$Raw)
    $fixture = @{
        APP_ENV = 'staging'
        SUPABASE_PROJECT_REF = 'gqtetdavmrautoojaqrk'
        SUPABASE_URL = 'https://gqtetdavmrautoojaqrk.supabase.co'
        SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_synthetic_fixture'
        ALLOW_PRODUCTION_BACKEND = $false
        AUTH_RECOVERY_REDIRECT_URL = ''
    }
    switch ($stagingFixtureState.Case) {
        'production-env' { $fixture.APP_ENV = 'production' }
        'wrong-project' { $fixture.SUPABASE_PROJECT_REF = 'aaaaaaaaaaaaaaaaaaaa' }
        'wrong-url' { $fixture.SUPABASE_URL = 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co' }
        'production-enabled' { $fixture.ALLOW_PRODUCTION_BACKEND = $true }
        'string-false' { $fixture.ALLOW_PRODUCTION_BACKEND = 'false' }
        'secret-key' { $fixture.SUPABASE_PUBLISHABLE_KEY = 'sb_' + 'secret_' + 'synthetic_fixture' }
        'empty-key' { $fixture.SUPABASE_PUBLISHABLE_KEY = '' }
        'malformed-config' { return '{ invalid fixture' }
    }
    return $fixture | ConvertTo-Json -Compress
}

function Invoke-RestMethod {
    param($Uri, $Method, $Headers, $ContentType, $Body, $TimeoutSec)
    ++$stagingFixtureState.HttpCalls
    if ($Uri -cne 'https://gqtetdavmrautoojaqrk.supabase.co/rest/v1/rpc/get_app_environment' -or
        $Method -cne 'Post' -or $Headers.apikey -cne 'sb_publishable_synthetic_fixture') {
        throw 'Unexpected request in offline test.'
    }
    $marker = @{ environment = 'staging'; project_ref = 'gqtetdavmrautoojaqrk' }
    if ($stagingFixtureState.Case -eq 'wrong-marker') { $marker.environment = 'production' }
    if ($stagingFixtureState.Case -eq 'wrong-marker-ref') { $marker.project_ref = 'aaaaaaaaaaaaaaaaaaaa' }
    return $marker
}

function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $ContentType, $Body, [switch]$SkipHttpErrorCheck, $TimeoutSec)
    ++$stagingFixtureState.HttpCalls
    if ($Uri -cne 'https://gqtetdavmrautoojaqrk.supabase.co/functions/v1/evidence-validate') {
        throw 'Unexpected endpoint in offline test.'
    }
    if ($Method -eq 'Options') {
        if ($Headers.Origin -eq 'http://127.0.0.1:7391') {
            $response = @{
                StatusCode = 200
                Content = '{"code":"PREFLIGHT"}'
                Headers = @{
                    'Access-Control-Allow-Origin' = 'http://127.0.0.1:7391'
                    'Access-Control-Allow-Headers' = 'authorization,apikey,x-client-info,content-type,x-booking-id,x-upload-id'
                    'Access-Control-Allow-Methods' = 'POST,OPTIONS'
                }
            }
            switch ($stagingFixtureState.Case) {
                'allowed-origin-denied' { $response.StatusCode = 403 }
                'wildcard-origin' { $response.Headers['Access-Control-Allow-Origin'] = '*' }
                'missing-upload-header' { $response.Headers['Access-Control-Allow-Headers'] = 'authorization,apikey,content-type' }
                'missing-post-method' { $response.Headers['Access-Control-Allow-Methods'] = 'OPTIONS' }
            }
            return $response
        }
        if ($stagingFixtureState.Case -eq 'unexpected-origin-allowed') {
            return @{ StatusCode = 200; Content = '{"code":"PREFLIGHT"}'; Headers = @{ 'Access-Control-Allow-Origin' = $Headers.Origin } }
        }
        return @{ StatusCode = 403; Content = '{"code":"ORIGIN_NOT_ALLOWED"}'; Headers = @{} }
    }
    if ($Method -eq 'Post') {
        if ($ContentType -cne 'application/octet-stream' -or
            -not $Headers['x-booking-id'] -or -not $Headers['x-upload-id']) {
            throw 'Auth rejection test must send a valid upload protocol.'
        }
        if (($stagingFixtureState.Case -eq 'missing-auth-allowed' -and -not $Headers.Authorization) -or
            ($stagingFixtureState.Case -eq 'invalid-auth-allowed' -and $Headers.Authorization)) {
            return @{ StatusCode = 200; Content = '{"code":"UNSAFE_FIXTURE"}'; Headers = @{} }
        }
        return @{ StatusCode = 401; Content = '{"code":"AUTH_REQUIRED"}'; Headers = @{} }
    }
    throw 'Unexpected method in offline test.'
}

$stagingNegativeCases = @(
    'missing-config', 'malformed-config', 'production-env', 'wrong-project', 'wrong-url',
    'production-enabled', 'string-false', 'secret-key', 'empty-key', 'wrong-marker',
    'wrong-marker-ref', 'allowed-origin-denied', 'wildcard-origin', 'missing-upload-header',
    'missing-post-method', 'unexpected-origin-allowed', 'missing-auth-allowed', 'invalid-auth-allowed'
)
foreach ($stagingFixtureCase in @('valid') + $stagingNegativeCases) {
    $stagingFixtureState.Case = $stagingFixtureCase
    $stagingFixtureState.HttpCalls = 0
    $rejected = $false
    try { & (Join-Path $PSScriptRoot 'verify_staging_connection.ps1') | Out-Null } catch { $rejected = $true }
    if ($stagingFixtureState.Case -eq 'valid') {
        if ($rejected -or $stagingFixtureState.HttpCalls -ne 6) { throw 'Valid fixture failed the full protocol checks.' }
    } elseif (-not $rejected) {
        throw "Unsafe fixture was accepted: $stagingFixtureCase"
    }
    if ($stagingFixtureState.Case -in $stagingNegativeCases[0..8] -and $stagingFixtureState.HttpCalls -ne 0) {
        throw 'Invalid local configuration reached the network.'
    }
    ++$stagingFixtureState.Checks
}
Write-Output "PASS: $($stagingFixtureState.Checks) offline Staging connection regression cases; no real config or HTTP used."
