# Runs the complete SQL chain in a newly created, network-isolated container.
# It never connects to the user's Supabase project or edits local app data.
param(
    [ValidateSet('legacy','disabled')][string]$PrivilegeProfile = 'legacy',
    [ValidateSet('16','17')][string]$PostgresVersion = '17'
)
$ErrorActionPreference = 'Stop'
$verifyRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$verifyName = 'rental-migration-check-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$verifyContainerId = $null

function Invoke-VerifySql {
    param([Parameter(Mandatory)][string]$Path)
    $verifySql = Get-Content -LiteralPath $Path -Raw
    $verifyBroad = if ($PrivilegeProfile -eq 'legacy') { 'true' } else { 'false' }
    $verifyAtomic = if ($Path -like '*migrations*' -and $Path -notlike '*local_supabase_shim*') { @('--single-transaction') } else { @() }
    $verifySql | & docker exec -i $verifyContainerId psql -X -q @verifyAtomic `
        -v ON_ERROR_STOP=1 -v broad_defaults=$verifyBroad -U postgres -d postgres
    if ($LASTEXITCODE -ne 0) {
        throw "SQL check failed: $Path"
    }
}

try {
    & docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker engine is not available. Start Docker Desktop, then rerun this script.'
    }

    $verifyContainerId = (& docker run --rm --network none --pull missing `
        --name $verifyName --label rental.verify=network-isolated -e POSTGRES_HOST_AUTH_METHOD=trust -d "postgres:$PostgresVersion" `
        postgres -c wal_level=logical).Trim()
    if ($LASTEXITCODE -ne 0 -or $verifyContainerId -notmatch '^[0-9a-f]{64}$') {
        throw 'Could not create the isolated PostgreSQL test container.'
    }

    $verifyReady = $false
    for ($verifyAttempt = 0; $verifyAttempt -lt 40; $verifyAttempt++) {
        & docker exec $verifyContainerId pg_isready -U postgres -d postgres | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $verifyReady = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $verifyReady) {
        throw 'PostgreSQL did not become ready in the isolated container.'
    }

    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/local_supabase_shim.sql')
    $verifyMigrations = Get-ChildItem -LiteralPath (Join-Path $verifyRepo 'supabase/migrations') `
        -Filter '*.sql' -File | Sort-Object Name
    foreach ($verifyMigration in $verifyMigrations) {
        Write-Output "Checking $($verifyMigration.Name)"
        Invoke-VerifySql $verifyMigration.FullName
    }
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/explicit_app_privileges.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/verified_evidence_fixture.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/booking_messages_rls.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/booking_lifecycle_evidence_rls.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/deployment_environment.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/evidence_upload_lifecycle.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/verified_evidence.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/evidence_photo_removal.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/cursor_pagination.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/test_data_management.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/booking_communication_limits.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/provider_earnings.sql')
    Invoke-VerifySql (Join-Path $verifyRepo 'supabase/tests/provider_profile_editor.sql')
    & python (Join-Path $verifyRepo 'tool/verify_rate_limit_concurrency.py') --container $verifyContainerId
    if ($LASTEXITCODE -ne 0) { throw 'Local rate-limit concurrency check failed.' }
    Write-Output "Passed: PostgreSQL $PostgresVersion / $PrivilegeProfile defaults; $($verifyMigrations.Count) migrations, explicit object/column/default privileges, booking-message, lifecycle/evidence, photo-upload/cleanup, cursor-pagination, deployment-environment, test-data-management and communication-rate checks in isolated PostgreSQL."
    Write-Output 'This does not replace Supabase Storage, Auth, Realtime or hosted cross-account tests.'
}
finally {
    if ($verifyContainerId -match '^[0-9a-f]{64}$') {
        & docker stop $verifyContainerId | Out-Null
    }
}
