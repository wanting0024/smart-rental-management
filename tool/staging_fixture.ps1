# Administrator-side synthetic fixture lifecycle. Never imported into the App.
[CmdletBinding()]
param(
 [ValidateSet('Plan','Setup','Verify','PreviewCleanup','Cleanup')][string]$Mode='Plan',
 [string]$ConfirmProject='', [string]$ConfirmFingerprint=''
)
$ErrorActionPreference='Stop'

function Assert-FixtureConfig {
 param($Config)
 if($Config.APP_ENV -cne 'staging' -or $Config.SUPABASE_PROJECT_REF -cne 'gqtetdavmrautoojaqrk' -or
  $Config.SUPABASE_URL -cne 'https://gqtetdavmrautoojaqrk.supabase.co' -or
  $Config.ALLOW_PRODUCTION_BACKEND -isnot [bool] -or $Config.ALLOW_PRODUCTION_BACKEND -or
  [string]::IsNullOrWhiteSpace($Config.SUPABASE_PUBLISHABLE_KEY)) {throw 'Pinned Staging client configuration required.'}
}
function Assert-FixtureModel {
 param($Data)
 $parsedRun=[guid]::Empty
 if($Data.project_ref -cne 'gqtetdavmrautoojaqrk' -or $Data.environment -cne 'staging' -or
  $Data.fixture -cne 'isolated-booking-run-v1' -or -not [guid]::TryParse($Data.run_id,[ref]$parsedRun) -or
  $parsedRun -eq [guid]::Empty -or $parsedRun.ToString() -cne $Data.run_id -or
  $Data.fixture_date -notmatch '^\d{4}-\d{2}-\d{2}$' -or @($Data.accounts).Count -ne 2) {throw 'Invalid private fixture manifest.'}
 $parsedDate=[datetime]::MinValue
 if(-not [datetime]::TryParseExact($Data.fixture_date,'yyyy-MM-dd',[cultureinfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,[ref]$parsedDate)) {throw 'Invalid fixture calendar date.'}
 foreach($fixtureRole in @('owner','provider')) {
  $matched=@($Data.accounts | Where-Object role -CEQ $fixtureRole)
  if($matched.Count -ne 1 -or $matched[0].email -cne "$fixtureRole.$($Data.run_id)@rental-test.invalid" -or
   $matched[0].password -isnot [string] -or $matched[0].password.Length -lt 32) {throw 'Exactly two isolated reserved identities and strong passwords required.'}
  if($matched[0].user_id) {
   $parsedId=[guid]::Empty
   if(-not [guid]::TryParse($matched[0].user_id,[ref]$parsedId) -or $parsedId -eq [guid]::Empty) {throw 'Invalid fixture identity ID.'}
  }
 }
 if($Data.accounts[0].password -ceq $Data.accounts[1].password -or
  ($Data.accounts[0].user_id -and $Data.accounts[0].user_id -ceq $Data.accounts[1].user_id)) {throw 'Fixture identities must be distinct.'}
}
function Assert-FixtureIdentity {
 param($User,$Account,$RunId)
 if($User.email -cne $Account.email -or $User.app_metadata.test_project_ref -cne 'gqtetdavmrautoojaqrk' -or
  $User.app_metadata.test_fixture -cne 'isolated-booking-run-v1' -or
  $User.app_metadata.test_run_id -cne $RunId -or $User.app_metadata.synthetic_test_account -isnot [bool] -or
  $User.app_metadata.synthetic_test_account -ne $true -or
  $User.user_metadata.requested_role -cne $Account.role -or [string]::IsNullOrWhiteSpace($User.email_confirmed_at) -or
  ($Account.user_id -and $Account.user_id -cne $User.id)) {throw 'Auth identity mismatch. No adoption, password reset or approval permitted.'}
}
function Assert-FixtureWriteConfirmation {
 param([string]$Mode,[string]$Project,[string]$Fingerprint)
 if($Mode -in @('Setup','Cleanup') -and $Project -cne 'gqtetdavmrautoojaqrk') {throw 'Explicit matching -ConfirmProject required for cloud writes.'}
 if($Mode -eq 'Cleanup' -and $Fingerprint -notmatch '^[a-f0-9]{32}$') {throw 'Copy the exact fingerprint from a reviewed cleanup preview.'}
}
function Assert-FixturePrivatePath {
 param([string]$Path,[switch]$Directory)
 $item=Get-Item -LiteralPath $Path
 if($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Private fixture paths cannot be links.'}
 $acl=Get-Acl -LiteralPath $Path
 if($Directory -and -not $acl.AreAccessRulesProtected) {throw 'Private directory must not inherit broad permissions.'}
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
 foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
  if($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @($sid,'S-1-5-18')) {throw 'Private fixture data may be readable only by current user and SYSTEM.'}
 }
}
function Save-FixtureManifest {
 param($Data,[string]$Path)
 Assert-FixtureModel $Data
 Assert-FixturePrivatePath -Path (Split-Path -Parent $Path) -Directory
 if(Test-Path -LiteralPath $Path) {Assert-FixturePrivatePath $Path}
 # Runtime-generated credentials/state, not source edits. Persist BEFORE cloud
 # creation; an interrupted operation always retries the same identities/passwords.
 $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
 try {
  [IO.File]::WriteAllText($temporary,($Data|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  Assert-FixturePrivatePath $temporary
  [IO.File]::Move($temporary,$Path,$true)
 } finally {if(Test-Path -LiteralPath $temporary) {Remove-Item -LiteralPath $temporary}}
}
function Invoke-FixtureHttp {
 param([string]$Path,[hashtable]$Headers,[string]$Method='Post',$Body=@{})
 if($Path -notmatch '^/(auth/v1/(admin/users(?:\?page=\d+&per_page=100)?|token\?grant_type=password|logout\?scope=local)|rest/v1/(rpc/(get_app_environment|preview_test_fixture|seed_test_fixture|inspect_test_run|preview_test_fixture_cleanup|cleanup_test_fixture|my_owner_profile|my_provider_profile|page_my_properties|page_my_bookings|find_eligible_providers)|service_type\?select=service_type_id,name&limit=50|booking\?select=booking_id,current_status,requested_start_at,requested_end_at&client_request_id=eq\.[0-9a-f-]{36}&limit=1))$') {
  throw 'Unexpected fixture endpoint refused.'
 }
 $request=@{Uri="https://gqtetdavmrautoojaqrk.supabase.co$Path";Method=$Method;Headers=$Headers;
   ContentType='application/json';TimeoutSec=30;MaximumRedirection=0;SkipHttpErrorCheck=$true}
 if($Method -ne 'Get') {$request.Body=$Body|ConvertTo-Json -Depth 8 -Compress}
 try {$reply=Invoke-WebRequest @request} catch {throw 'Fixture request interrupted. Retry with the SAME private manifest; no server response or credential was logged.'}
 if([int]$reply.StatusCode -lt 200 -or [int]$reply.StatusCode -ge 300) {
  $sqlState='unavailable'
  try {
   $problem=$reply.Content|ConvertFrom-Json
   if($problem.code -cmatch '^[A-Z0-9]{5}$') {$sqlState=$problem.code}
  } catch {}
  $failure=[InvalidOperationException]::new("Fixture request failed (HTTP $([int]$reply.StatusCode), code $sqlState, $Path). No response body or secret is logged.")
  $failure.Data['HttpStatus']=[int]$reply.StatusCode
  $failure.Data['SqlState']=$sqlState
  throw $failure
 }
 if(-not [string]::IsNullOrWhiteSpace($reply.Content)) {return $reply.Content|ConvertFrom-Json}
}
# Dot-source only pure guard functions in offline tests: no filesystem/network work.
if($MyInvocation.InvocationName -eq '.') {return}

$fixtureRoot=Split-Path -Parent $PSScriptRoot
$fixtureRef='gqtetdavmrautoojaqrk'
$fixturePath=Join-Path $fixtureRoot 'output/staging-private/booking-fixture.local.json'
$fixtureDir=Split-Path -Parent $fixturePath
$fixtureConfig=Get-Content -LiteralPath (Join-Path $fixtureRoot 'supabase/backend_config.staging.local.json') -Raw|ConvertFrom-Json
Assert-FixtureConfig $fixtureConfig
Assert-FixturePrivatePath -Path $fixtureDir -Directory
Assert-FixtureWriteConfirmation $Mode $ConfirmProject $ConfirmFingerprint
$fixtureData=$null
if(Test-Path -LiteralPath $fixturePath) {
 Assert-FixturePrivatePath $fixturePath
 $fixtureData=Get-Content -LiteralPath $fixturePath -Raw|ConvertFrom-Json
 Assert-FixtureModel $fixtureData
}
$fixtureClientHeaders=@{apikey=$fixtureConfig.SUPABASE_PUBLISHABLE_KEY}
$fixtureMarker=Invoke-FixtureHttp '/rest/v1/rpc/get_app_environment' $fixtureClientHeaders
if($fixtureMarker.environment -cne 'staging' -or $fixtureMarker.project_ref -cne $fixtureRef) {throw 'Server Staging marker mismatch.'}
if($Mode -eq 'Plan') {
 @{mode='READ_ONLY_PLAN';project_ref=$fixtureRef;existing_private_manifest=($null -ne $fixtureData);
  accounts=2;properties=2;weekly_slots=7;services=2;pending_bookings=1;
  original_accounts_changed=$false;passwords='PRIVATE_LOCAL_FILE_ONLY';deletions=0}|ConvertTo-Json
 return
}
if($null -eq $fixtureData) {
 if($Mode -ne 'Setup') {throw 'No isolated fixture manifest exists. Use Setup first.'}
 $fixtureRun=[guid]::NewGuid().ToString()
 $fixtureData=[pscustomobject]@{fixture='isolated-booking-run-v1';project_ref=$fixtureRef;environment='staging';run_id=$fixtureRun;
  fixture_date=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).Date.AddDays(1).ToString('yyyy-MM-dd');
  accounts=@(foreach($fixtureRole in @('owner','provider')) {[pscustomobject]@{role=$fixtureRole;
   email="$fixtureRole.$fixtureRun@rental-test.invalid";
   password=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32));user_id=$null}})}
 Save-FixtureManifest $fixtureData $fixturePath
}

$fixtureAdminHeaders=$null;$fixtureKeys=$null;$fixtureAdminKey=$null;$fixtureKeyOutput=$null
try {
 $fixtureCli=Join-Path $fixtureRoot 'tool/backend-cli/node_modules/.bin/supabase.cmd'
 $fixtureKeyOutput=& $fixtureCli projects api-keys --project-ref $fixtureRef -o json 2>$null
 if($LASTEXITCODE -ne 0) {throw 'Existing Staging administrator credential unavailable. Log in to the CLI first.'}
 $fixtureKeys=@($fixtureKeyOutput|ConvertFrom-Json)
 $fixtureAdminKey=$fixtureKeys|Where-Object name -CEQ 'service_role'|Select-Object -First 1
 try {
  $parts=$fixtureAdminKey.api_key.Split('.');if($parts.Count -ne 3) {throw 'JWT expected'}
  $payload=$parts[1].Replace('-','+').Replace('_','/')
  $payload=$payload.PadRight([int]([Math]::Ceiling($payload.Length/4.0)*4),'=')
  $claims=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))|ConvertFrom-Json
  if($claims.role -cne 'service_role' -or $claims.ref -cne $fixtureRef) {throw 'Wrong key scope'}
 } catch {throw 'Valid existing Staging server credential required. No key was logged.'}
 $fixtureAdminHeaders=@{apikey=$fixtureAdminKey.api_key;Authorization="Bearer $($fixtureAdminKey.api_key)"}
 # Auth inventory is bounded and kept only in memory. No cloud mutation until
 # every existing matching identity passes exact synthetic app-metadata checks.
 $fixtureUsers=@()
 for($fixturePage=1;$fixturePage -le 10;$fixturePage++) {
  $page=Invoke-FixtureHttp -Path "/auth/v1/admin/users?page=$fixturePage&per_page=100" -Headers $fixtureAdminHeaders -Method Get
  $fixtureUsers+=@($page.users)
  if(@($page.users).Count -lt 100) {break}
  if($fixturePage -eq 10) {throw 'Auth inventory exceeds small Staging scope.'}
 }
 foreach($account in $fixtureData.accounts) {
  $matches=@($fixtureUsers|Where-Object email -CEQ $account.email)
  if($matches.Count -gt 1) {throw 'Duplicate reserved identity. Stop for review.'}
  if($matches.Count -eq 1) {Assert-FixtureIdentity $matches[0] $account $fixtureData.run_id}
  elseif($Mode -ne 'Setup' -or $account.user_id) {throw 'Expected fixture Auth identity missing. No replacement or reset permitted.'}
 }
 foreach($account in $fixtureData.accounts) {
  $user=@($fixtureUsers|Where-Object email -CEQ $account.email)|Select-Object -First 1
  if($null -eq $user) {
   $user=Invoke-FixtureHttp '/auth/v1/admin/users' $fixtureAdminHeaders -Body @{
    email=$account.email;password=$account.password;email_confirm=$true;
    user_metadata=@{requested_role=$account.role;test_label="[TEST] Isolated $($account.role)"};
    app_metadata=@{test_project_ref=$fixtureRef;test_fixture='isolated-booking-run-v1';
      test_run_id=$fixtureData.run_id;synthetic_test_account=$true}}
  }
  Assert-FixtureIdentity $user $account $fixtureData.run_id
  $account.user_id=[guid]::Parse($user.id).ToString()
 }
 if($Mode -eq 'Setup') {Save-FixtureManifest $fixtureData $fixturePath}
 $fixtureOwner=$fixtureData.accounts|Where-Object role -CEQ 'owner'
 $fixtureProvider=$fixtureData.accounts|Where-Object role -CEQ 'provider'
 $fixtureScope=@{p_project_ref=$fixtureRef;p_run_id=$fixtureData.run_id}
 if($Mode -eq 'Setup') {
  try {
   $null=Invoke-FixtureHttp '/rest/v1/rpc/inspect_test_run' $fixtureAdminHeaders -Body $fixtureScope
  } catch {
   if($_.Exception.Data['SqlState'] -ne '22023') {throw}
   # Only an ABSENT registry may receive a new valid date. An existing run,
   # even expired, is never reset/re-dated by Setup. This also recovers a lost
   # cleanup response: credentials stay unchanged and normal seed guards still
   # refuse any unexpected remaining business records.
   $nextDay=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).Date.AddDays(1)
   $storedDay=[datetime]::ParseExact($fixtureData.fixture_date,'yyyy-MM-dd',[cultureinfo]::InvariantCulture)
   if($storedDay -lt $nextDay -or $storedDay -gt $nextDay.AddDays(89)) {
    $fixtureData.fixture_date=$nextDay.ToString('yyyy-MM-dd')
    Save-FixtureManifest $fixtureData $fixturePath
   }
  }
 }
 $fixtureParams=@{p_project_ref=$fixtureRef;p_run_id=$fixtureData.run_id;p_owner_id=$fixtureOwner.user_id;
  p_provider_id=$fixtureProvider.user_id;p_fixture_date=$fixtureData.fixture_date}
 if($Mode -eq 'Setup') {
  $null=Invoke-FixtureHttp '/rest/v1/rpc/preview_test_fixture' $fixtureAdminHeaders -Body $fixtureParams
  $null=Invoke-FixtureHttp '/rest/v1/rpc/seed_test_fixture' $fixtureAdminHeaders -Body $fixtureParams
 }
 if($Mode -in @('PreviewCleanup','Cleanup')) {
  $plan=Invoke-FixtureHttp '/rest/v1/rpc/preview_test_fixture_cleanup' $fixtureAdminHeaders -Body $fixtureScope
  if($Mode -eq 'Cleanup') {
   if(-not $plan.eligible -or $plan.fingerprint -cne $ConfirmFingerprint) {throw 'Reviewed cleanup preview no longer matches. Nothing deleted.'}
   $fixtureScope.p_fingerprint=$ConfirmFingerprint
   $result=Invoke-FixtureHttp '/rest/v1/rpc/cleanup_test_fixture' $fixtureAdminHeaders -Body $fixtureScope
   @{mode='CLEANED_EXACT_TEST_RUN';run_id=$fixtureData.run_id;project_ref=$fixtureRef;
    cleaned=$result.cleaned;removed_business_counts=$result.counts;auth_users_deleted=$false;storage_objects_deleted=$false}|ConvertTo-Json -Depth 5
  } else {$plan|ConvertTo-Json -Depth 5}
  return
 }
 $inventory=Invoke-FixtureHttp '/rest/v1/rpc/inspect_test_run' $fixtureAdminHeaders -Body $fixtureScope
 if([int]$inventory.mixed_account_bookings -ne 0) {throw 'Fixture has mixed-account bookings. Stop for review.'}
 $fixtureChecks=@();$fixtureCandidate=$null
 foreach($account in $fixtureData.accounts) {
  $session=$null;$userHeaders=$null
  try {
   $session=Invoke-FixtureHttp '/auth/v1/token?grant_type=password' $fixtureClientHeaders -Body @{email=$account.email;password=$account.password}
   if($session.user.id -cne $account.user_id -or [string]::IsNullOrWhiteSpace($session.access_token)) {throw 'Fixture password login identity mismatch.'}
   $userHeaders=@{apikey=$fixtureConfig.SUPABASE_PUBLISHABLE_KEY;Authorization="Bearer $($session.access_token)"}
   $bookings=Invoke-FixtureHttp '/rest/v1/rpc/page_my_bookings' $userHeaders -Body @{p_limit=20}
   if(@($bookings.items).Count -lt 1) {throw 'Expected initial Pending fixture booking missing.'}
   foreach($booking in $bookings.items) {
    if($booking.owner_id -cne $fixtureOwner.user_id -or $booking.provider_id -cne $fixtureProvider.user_id) {throw 'Unexpected booking participant in fixture view.'}
   }
   if($account.role -eq 'provider') {
    $profile=Invoke-FixtureHttp '/rest/v1/rpc/my_provider_profile' $userHeaders
    if($profile.provider_id -cne $account.user_id -or $profile.approval_status -cne 'approved' -or
      [decimal]$profile.hourly_rate -ne 40 -or [decimal]$profile.daily_rate -ne 280 -or
      @($profile.weekly_slots).Count -ne 7 -or @($profile.services|Where-Object selected).Count -ne 2) {
     throw 'Synthetic Provider approval/services/slots/rates no longer match the fixture. No automatic overwrite performed.'}
   } else {
    $profile=Invoke-FixtureHttp '/rest/v1/rpc/my_owner_profile' $userHeaders
    if($profile.actor_id -cne $account.user_id -or [int]$profile.property_count -lt 2) {throw 'Expected Owner properties missing.'}
    $properties=Invoke-FixtureHttp '/rest/v1/rpc/page_my_properties' $userHeaders
    $catalogue=@(Invoke-FixtureHttp -Path '/rest/v1/service_type?select=service_type_id,name&limit=50' -Headers $userHeaders -Method Get)
    $standard=@($catalogue|Where-Object name -CEQ 'Standard cleaning')
    if($standard.Count -ne 1) {throw 'Standard cleaning catalogue entry missing.'}
    $property=@($properties.items|Where-Object { $_.unit_name -ceq '[TEST] Unit A' -and $_.building_name -ceq '[TEST] Fixture Building' })|Select-Object -First 1
    if($null -eq $property) {throw 'Original fixture property changed. Review before using this setup.'}
    $malaysiaToday=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).Date
    $firstDay=[datetime]::ParseExact($fixtureData.fixture_date,'yyyy-MM-dd',[cultureinfo]::InvariantCulture)
    if($firstDay -le $malaysiaToday) {$firstDay=$malaysiaToday.AddDays(1)}
    for($dayOffset=0;$dayOffset -lt 7 -and $null -eq $fixtureCandidate;$dayOffset++) {
     foreach($hour in @(10,14)) {
      $start=[DateTimeOffset]::new($firstDay.AddDays($dayOffset).AddHours($hour),[TimeSpan]::FromHours(8))
      $end=$start.AddHours(2)
      $eligible=@(Invoke-FixtureHttp '/rest/v1/rpc/find_eligible_providers' $userHeaders -Body @{
        p_property_id=$property.property_id;p_service_type_id=$standard[0].service_type_id;
        p_start_at=$start.UtcDateTime.ToString('o');p_end_at=$end.UtcDateTime.ToString('o')})
      $match=@($eligible|Where-Object provider_id -CEQ $fixtureProvider.user_id)
      if($match.Count -eq 1) {
       if($match[0].quote_basis -cne 'hourly' -or [decimal]$match[0].quoted_amount -ne 80) {throw 'Server quote does not match fixture expectations.'}
       $fixtureCandidate=@{property_id=$property.property_id;service_type_id=$standard[0].service_type_id;
        provider_id=$fixtureProvider.user_id;start_myt=$start.ToString('yyyy-MM-dd HH:mm zzz');
        end_myt=$end.ToString('yyyy-MM-dd HH:mm zzz');quote_basis='hourly';quoted_amount=80;currency='MYR';reservation_created=$false}
       break
      }
     }
    }
    if($null -eq $fixtureCandidate) {throw 'No eligible slot found. No bookings or existing availability were changed.'}
   }
   $fixtureChecks+=@{role=$account.role;email=$account.email;user_id=$account.user_id;password_login='PASS';own_read='PASS'}
  } finally {
   if($userHeaders) {$null=Invoke-FixtureHttp '/auth/v1/logout?scope=local' $userHeaders}
   $session=$null;$userHeaders=$null
  }
 }
 @{mode='ISOLATED_FIXTURE_READY';project_ref=$fixtureRef;run_id=$fixtureData.run_id;accounts=$fixtureChecks;
   counts=$inventory.counts;eligible_request=$fixtureCandidate;passwords='PRIVATE_LOCAL_FILE_ONLY';
   existing_accounts_changed=$false;completed_work_fabricated=$false;storage_objects_created=0}|ConvertTo-Json -Depth 7
} finally {
 $fixtureAdminHeaders=$null;$fixtureAdminKey=$null;$fixtureKeyOutput=$null;$fixtureKeys=$null;$claims=$null;$payload=$null;$parts=$null
}
