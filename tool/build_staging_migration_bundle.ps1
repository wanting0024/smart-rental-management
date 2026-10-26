# Generates LOCAL artifacts only. Never reads credentials or runs remote SQL.
param([string]$OutputDirectory = 'output/staging-migration-package')
$ErrorActionPreference = 'Stop'
$bundleRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundleOutput = [IO.Path]::GetFullPath((Join-Path $bundleRepo $OutputDirectory))
if (-not $bundleOutput.StartsWith($bundleRepo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Generated package must stay inside this repository.'
}
$bundleFiles = @(Get-ChildItem -LiteralPath (Join-Path $bundleRepo 'supabase/migrations') -Filter '*.sql' -File | Sort-Object Name)
if ($bundleFiles.Count -ne 29) { throw 'Review the package contract when adding a migration.' }
$bundleChunks = [Collections.Generic.List[string]]::new()
$bundleChunks.Add(@'
-- FRESH smart-rental-staging / gqtetdavmrautoojaqrk ONLY.
-- Generated local artifact, NOT executed by its generator.
-- Confirm the project URL, inspect preflight, then run the ENTIRE file.
-- Never apply to dvakrwalnqpcmgirmlct or an existing/shared schema.
begin;
do $fresh_guard$
begin
  if current_user <> 'postgres' then raise exception 'postgres migration role required'; end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p','v','m','f','S')
      and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e'))
    or exists(select 1 from pg_namespace where nspname='app_private') then
    raise exception 'Expected fresh Staging: STOP and reconcile existing schema';
  end if;
end;
$fresh_guard$;
'@)
$bundleManifest = for ($bundleIndex = 0; $bundleIndex -lt $bundleFiles.Count; $bundleIndex++) {
    $bundleFile = $bundleFiles[$bundleIndex]
    if ($bundleFile.Name -notmatch '^\d{8}(\d{4})_' -or [int]$Matches[1] -ne ($bundleIndex + 1)) {
        throw "Non-contiguous migration sequence: $($bundleFile.Name)"
    }
    $bundleSource = Get-Content -LiteralPath $bundleFile.FullName -Raw
    if ($bundleSource -match '(?im)^\s*(begin|commit|rollback)\s*;') {
        throw "Unexpected transaction boundary in $($bundleFile.Name)"
    }
    $bundleChunks.Add("`n-- BEGIN $($bundleFile.Name)`n$bundleSource`n-- END $($bundleFile.Name)`n")
    [ordered]@{ order=$bundleIndex+1; file=$bundleFile.Name; sha256=(Get-FileHash -LiteralPath $bundleFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$bundleChunks.Add("`ncommit;`n")
New-Item -ItemType Directory -Path $bundleOutput -Force | Out-Null
$bundleEncoding = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $bundleOutput 'fresh_staging_001_to_029.sql'),($bundleChunks -join "`n"),$bundleEncoding)
[IO.File]::WriteAllText((Join-Path $bundleOutput 'manifest.json'),(ConvertTo-Json -Depth 5 -InputObject ([ordered]@{
    target_project='gqtetdavmrautoojaqrk'; target_name='smart-rental-staging';
    mode='fresh-staging-only'; migrations=@($bundleManifest)
})), $bundleEncoding)
Copy-Item -LiteralPath (Join-Path $bundleRepo 'supabase/reviews/staging_migration_preflight.sql') -Destination $bundleOutput
Copy-Item -LiteralPath (Join-Path $bundleRepo 'supabase/reviews/staging_migration_postflight.sql') -Destination $bundleOutput
Write-Output "Generated 29-migration atomic Staging package at $bundleOutput. NO remote SQL executed."
