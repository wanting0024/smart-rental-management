# Stable origin must match the server-side EVIDENCE_ALLOWED_ORIGINS allow-list.
# No keys are embedded in command arguments; only the ignored config path is passed.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$stagingRoot = Split-Path -Parent $PSScriptRoot
if (Get-NetTCPConnection -LocalPort 7391 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Port 7391 is occupied. Inspect the existing App process; this script will not stop it.'
}
& (Join-Path $PSScriptRoot 'verify_staging_connection.ps1')
$stagingFlutter = (Get-Command flutter -ErrorAction Stop).Source
Push-Location $stagingRoot
try {
    & $stagingFlutter run -d web-server --web-hostname 127.0.0.1 --web-port 7391 `
        '--dart-define-from-file=supabase/backend_config.staging.local.json'
    if ($LASTEXITCODE -ne 0) { throw 'Staging App exited unsuccessfully.' }
} finally {
    Pop-Location
}
