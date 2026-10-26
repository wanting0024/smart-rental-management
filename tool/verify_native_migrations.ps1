# Optional Docker-free local verification using trusted PostgreSQL binaries.
# No Windows service is installed; only a new synthetic loopback-only cluster.
param(
    [Parameter(Mandatory)][string]$PostgresBin,
    [ValidateSet('legacy','disabled')][string]$PrivilegeProfile = 'legacy'
)
$ErrorActionPreference = 'Stop'
$nativeRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$nativeBin = (Resolve-Path -LiteralPath $PostgresBin).Path
foreach ($nativeExe in @('initdb.exe','pg_ctl.exe','psql.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $nativeBin $nativeExe))) { throw 'PostgreSQL binaries are incomplete.' }
}
$nativeOutput = Join-Path $nativeRepo 'output'
New-Item -ItemType Directory -Path $nativeOutput -Force | Out-Null
$nativeData = Join-Path $nativeOutput ('pg-verify-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $nativeData | Out-Null
$nativeLog = Join-Path $nativeData 'server.log'
$nativePasswordFile = Join-Path $nativeData 'init-password.tmp'
$nativeListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$nativeListener.Start()
$nativePort = $nativeListener.LocalEndpoint.Port
$nativeListener.Stop()
$nativePassword = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$nativePriorPassword = $env:PGPASSWORD
$nativeStarted = $false
function Invoke-NativeSql {
    param([string]$Path)
    $nativeBroad = if ($PrivilegeProfile -eq 'legacy') { 'true' } else { 'false' }
    Get-Content -LiteralPath $Path -Raw | & (Join-Path $nativeBin 'psql.exe') -X -q `
        -h 127.0.0.1 -p $nativePort -U postgres -d postgres -v ON_ERROR_STOP=1 -v broad_defaults=$nativeBroad
    if ($LASTEXITCODE -ne 0) { throw "Local SQL check failed: $Path" }
}
try {
    # Windows initdb reads passwords from a file, not redirected stdin. The
    # randomly generated LOCAL TEST password is never a hosted credential.
    # Keep its temporary file outside the initially empty data directory and
    # remove it immediately, including on failure. Never print its content.
    $nativePasswordFile = $nativeData + '-init-password.tmp'
    try {
        [IO.File]::WriteAllText($nativePasswordFile, $nativePassword, [Text.UTF8Encoding]::new($false))
        & (Join-Path $nativeBin 'initdb.exe') -D $nativeData -U postgres `
            --pwfile=$nativePasswordFile --auth-host=scram-sha-256 --auth-local=scram-sha-256 --encoding=UTF8 --locale=C
        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize synthetic local cluster.' }
    }
    finally {
        if (Test-Path -LiteralPath $nativePasswordFile) { Remove-Item -LiteralPath $nativePasswordFile }
    }
    $env:PGPASSWORD = $nativePassword
    # Do not attach the long-lived server's inherited pipes to PowerShell's
    # native command pipeline: that can wait forever after pg_ctl has exited.
    $nativeStart = Start-Process -FilePath (Join-Path $nativeBin 'pg_ctl.exe') -WindowStyle Hidden -PassThru `
        -ArgumentList @('-D',"`"$nativeData`"",'-l',"`"$nativeLog`"",'-w','-t','30','start',
            '-o',"`"-h 127.0.0.1 -p $nativePort -c wal_level=logical`"") `
        -RedirectStandardOutput (Join-Path $nativeData 'start.log') -RedirectStandardError (Join-Path $nativeData 'start-error.log')
    if (-not $nativeStart.WaitForExit(40000) -or $nativeStart.ExitCode -ne 0) { throw 'Could not start loopback-only PostgreSQL.' }
    $nativeStarted = $true
    Invoke-NativeSql (Join-Path $nativeRepo 'supabase/tests/local_supabase_shim.sql')
    Invoke-NativeSql (Join-Path $nativeRepo 'supabase/reviews/2026-10-23_staging_auto_rls_setup.sql')
    & (Join-Path $PSScriptRoot 'build_staging_migration_bundle.ps1')
    Invoke-NativeSql (Join-Path $nativeRepo 'output/staging-migration-package/fresh_staging_001_to_029.sql')
    foreach ($nativeTest in @('explicit_app_privileges','verified_evidence_fixture','booking_messages_rls',
        'booking_lifecycle_evidence_rls','booking_acceptance_approval','deployment_environment','evidence_upload_lifecycle',
        'verified_evidence','cursor_pagination','test_data_management','test_fixture_cleanup','booking_communication_limits','provider_earnings','provider_profile_editor','booking_notifications','conversation_inbox','message_read_receipts','owner_workspace','owner_uat_identity_portfolio','owner_navigation_pages')) {
        Write-Output "Checking $nativeTest / $PrivilegeProfile"
        Invoke-NativeSql (Join-Path $nativeRepo "supabase/tests/$nativeTest.sql")
    }
    & python (Join-Path $PSScriptRoot 'verify_rate_limit_concurrency.py') --native-bin $nativeBin --native-data $nativeData --native-port $nativePort
    if ($LASTEXITCODE -ne 0) { throw 'Native concurrent SQL tests failed.' }
    & python (Join-Path $PSScriptRoot 'verify_fixture_cleanup_concurrency.py') --native-bin $nativeBin --native-data $nativeData --native-port $nativePort
    if ($LASTEXITCODE -ne 0) { throw 'Native concurrent fixture cleanup tests failed.' }
    Write-Output "PASSED: native PostgreSQL / $PrivilegeProfile defaults; atomic 001-029 bundle, ACL/RLS/defaults, lifecycle, evidence, paging, owner navigation/directory/search, earnings/profile/notifications/conversations/message-receipts/owner-workspace/registration-name/portfolio reports, test-data/cleanup and concurrent rate/lease tests."
    Write-Output 'Synthetic local SQL only; no hosted Auth/Storage/Realtime approval.'
}
finally {
    if ($nativeStarted) {
        & (Join-Path $nativeBin 'pg_ctl.exe') -D $nativeData -m fast -w -t 30 stop
        if ($LASTEXITCODE -ne 0) { Write-Warning "Local test cluster stop needs attention: $nativeData" }
    }
    $env:PGPASSWORD = $nativePriorPassword
    $nativePassword = $null
}
