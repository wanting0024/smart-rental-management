# Read-only connection checks. Never prints keys or creates users/business rows.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$stagingRoot = Split-Path -Parent $PSScriptRoot
$stagingConfigPath = Join-Path $stagingRoot 'supabase/backend_config.staging.local.json'
if (-not (Test-Path -LiteralPath $stagingConfigPath)) {
    throw 'Missing ignored Staging client configuration. Do not copy production credentials.'
}
$stagingConfig = Get-Content -LiteralPath $stagingConfigPath -Raw | ConvertFrom-Json
$stagingRef = 'gqtetdavmrautoojaqrk'
$stagingUrl = "https://$stagingRef.supabase.co"
$stagingOrigin = 'http://127.0.0.1:7391'
if ($stagingConfig.APP_ENV -cne 'staging' -or
    $stagingConfig.SUPABASE_PROJECT_REF -cne $stagingRef -or
    $stagingConfig.SUPABASE_URL -cne $stagingUrl -or
    $stagingConfig.ALLOW_PRODUCTION_BACKEND -isnot [bool] -or
    $stagingConfig.ALLOW_PRODUCTION_BACKEND) {
    throw 'Staging configuration must pin this Staging project and disable production access.'
}
$stagingKey = [string]$stagingConfig.SUPABASE_PUBLISHABLE_KEY
if (-not $stagingKey.StartsWith('sb_publishable_')) {
    try {
        $stagingSegments = $stagingKey.Split('.')
        if ($stagingSegments.Count -ne 3) { throw 'Not a client JWT' }
        $stagingPayload = $stagingSegments[1].Replace('-', '+').Replace('_', '/')
        $stagingPayload = $stagingPayload.PadRight([int]([Math]::Ceiling($stagingPayload.Length / 4.0) * 4), '=')
        $stagingClaims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($stagingPayload)) | ConvertFrom-Json
        if ($stagingClaims.role -cne 'anon' -or $stagingClaims.ref -cne $stagingRef) { throw 'Not this project anon key' }
    } catch {
        throw 'Only a publishable key or this project anon client key is permitted.'
    }
}

$stagingMarker = Invoke-RestMethod -Uri "$stagingUrl/rest/v1/rpc/get_app_environment" -Method Post `
    -Headers @{ apikey = $stagingKey } -ContentType 'application/json' -Body '{}' -TimeoutSec 30
if ($stagingMarker.environment -cne 'staging' -or $stagingMarker.project_ref -cne $stagingRef) {
    throw 'Server environment marker does not match Staging. App must not start.'
}
Write-Output 'PASS: public client key reaches the pinned Staging environment marker.'

$stagingEndpoint = "$stagingUrl/functions/v1/evidence-validate"
foreach ($stagingTestOrigin in @($stagingOrigin, 'http://127.0.0.1:7392', 'https://unapproved.invalid')) {
    $stagingResponse = Invoke-WebRequest -Uri $stagingEndpoint -Method Options -Headers @{
        Origin = $stagingTestOrigin
        'Access-Control-Request-Method' = 'POST'
        'Access-Control-Request-Headers' = 'authorization,apikey,x-client-info,content-type,x-booking-id,x-upload-id'
    } -SkipHttpErrorCheck -TimeoutSec 30
    $stagingCorsOrigin = $stagingResponse.Headers['Access-Control-Allow-Origin'] -join ','
    if ($stagingTestOrigin -ceq $stagingOrigin) {
        $stagingAllowHeaders = $stagingResponse.Headers['Access-Control-Allow-Headers'] -join ','
        $stagingAllowMethods = $stagingResponse.Headers['Access-Control-Allow-Methods'] -join ','
        $stagingPreflight = $stagingResponse.Content | ConvertFrom-Json
        if ([int]$stagingResponse.StatusCode -ne 200 -or $stagingCorsOrigin -cne $stagingOrigin -or
            $stagingPreflight.code -cne 'PREFLIGHT' -or $stagingAllowMethods -notmatch '\bPOST\b') {
            throw 'Expected exact-origin successful photo-service preflight.'
        }
        foreach ($stagingRequiredHeader in @('authorization', 'apikey', 'x-client-info', 'content-type', 'x-booking-id', 'x-upload-id')) {
            if ($stagingAllowHeaders.Split(',').Trim() -notcontains $stagingRequiredHeader) {
                throw "Photo-service preflight is missing header $stagingRequiredHeader."
            }
        }
        Write-Output 'PASS: exact local App origin and upload protocol are permitted.'
    } else {
        $stagingDenial = $stagingResponse.Content | ConvertFrom-Json
        if ([int]$stagingResponse.StatusCode -ne 403 -or $stagingCorsOrigin -ne '' -or
            $stagingDenial.code -cne 'ORIGIN_NOT_ALLOWED') {
            throw 'Unexpected origin was not denied as expected.'
        }
        Write-Output "PASS: unapproved origin denied ($stagingTestOrigin)."
    }
}

# Valid protocol but no user session: must fail before any upload ticket/Storage write.
$stagingRequestHeaders = @{
    apikey = $stagingKey
    Origin = $stagingOrigin
    'x-booking-id' = '00000000-0000-4000-8000-000000000000'
    'x-upload-id' = '00000000-0000-4000-8000-000000000001'
}
foreach ($stagingAuthCase in @('missing', 'invalid')) {
    if ($stagingAuthCase -eq 'invalid') { $stagingRequestHeaders.Authorization = 'Bearer not-a-valid-user-jwt' }
    $stagingAuthResponse = Invoke-WebRequest -Uri $stagingEndpoint -Method Post -Headers $stagingRequestHeaders `
        -ContentType 'application/octet-stream' -Body ([byte[]]::new(0)) -SkipHttpErrorCheck -TimeoutSec 30
    if ([int]$stagingAuthResponse.StatusCode -ne 401) {
        throw "Photo service did not reject $stagingAuthCase user authentication with HTTP 401."
    }
    Write-Output "PASS: $stagingAuthCase user authentication remains denied (HTTP 401)."
}
Write-Output 'Connection checks passed. Signed-in photo upload and account-isolation acceptance are separate tests.'
