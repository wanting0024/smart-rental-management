param(
    [Parameter(Mandatory)][ValidateSet('web', 'apk', 'appbundle')][string]$Target,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$FlutterExecutable = 'flutter',
    [string]$PythonExecutable = 'python'
)

# Developer-controlled release gate. Does not deploy/publish, copy secrets into
# source, print compiler output, or claim a clean scan is a security certificate.
$ErrorActionPreference = 'Stop'
$secureBuildRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
try {
    $secureBuildConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
    Push-Location -LiteralPath $secureBuildRoot
    try {
        Write-Output '1/3: Checking source, reachable local Git history and client-only configuration.'
        & $PythonExecutable tool/security_scan.py --history --config $secureBuildConfig
        if ($LASTEXITCODE -ne 0) { throw 'Preflight blocked.' }

        Write-Output '2/3: Building release. Raw compiler output is withheld from the shared log.'
        & $FlutterExecutable build $Target --release "--dart-define-from-file=$secureBuildConfig" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

        $secureBuildArtifact = switch ($Target) {
            'web' { 'build/web' }
            'apk' { 'build/app/outputs/flutter-apk/app-release.apk' }
            'appbundle' { 'build/app/outputs/bundle/release/app-release.aab' }
        }
        Write-Output '3/3: Inspecting packaged output, including bounded ZIP/APK/AAB member contents.'
        & $PythonExecutable tool/security_scan.py --history --config $secureBuildConfig --artifact $secureBuildArtifact
        if ($LASTEXITCODE -ne 0) { throw 'Artifact scan blocked.' }
        Write-Output 'Local release gate passed. Nothing was uploaded or published.'
    }
    finally { Pop-Location }
}
catch {
    Write-Output 'Release gate failed or was incomplete. No raw exception, credential or build log is printed. Review the redacted scan result and investigate privately.'
    exit 1
}
