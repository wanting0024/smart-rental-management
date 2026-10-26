# Offline pure guard tests. No credentials/files or external network needed.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'staging_fixture.ps1')
$fixtureGuardCount=0
function New-GuardModel {
 return @{project_ref='gqtetdavmrautoojaqrk';environment='staging';fixture='isolated-booking-run-v1';
  run_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';fixture_date='2026-10-25';accounts=@(
   @{role='owner';email='owner.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid';password=('OwnerFixtureOnly'+'a'*32);user_id='11111111-1111-4111-8111-111111111111'},
   @{role='provider';email='provider.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@rental-test.invalid';password=('ProviderFixtureOnly'+'b'*32);user_id='22222222-2222-4222-8222-222222222222'})}
}
function Assert-GuardRejects {
 param([scriptblock]$Action,[string]$Case)
 $rejected=$false;try{& $Action}catch{$rejected=$true}
 if(-not $rejected){throw "Guard unexpectedly accepted: $Case"}
 $script:fixtureGuardCount++
}
$model=New-GuardModel;Assert-FixtureModel $model;++$fixtureGuardCount
foreach($case in @('project','environment','fixture','empty-run','malformed-run','date','date-format','roles','real-email','reusable-a','password','same-password','same-id','invalid-id')) {
 $model=New-GuardModel
 switch($case) {
  'project'{$model.project_ref='dvakrwalnqpcmgirmlct'}
  'environment'{$model.environment='production'}
  'fixture'{$model.fixture='reusable-accounts-v1'}
  'empty-run'{$model.run_id=[guid]::Empty.ToString()}
  'malformed-run'{$model.run_id='not-a-run'}
  'date'{$model.fixture_date='2026-02-31'}
  'date-format'{$model.fixture_date='25/10/2026'}
  'roles'{$model.accounts[1].role='owner'}
  'real-email'{$model.accounts[0].email='owner@example.com'}
  'reusable-a'{$model.accounts[0].email='owner.a@rental-test.invalid'}
  'password'{$model.accounts[0].password='short'}
  'same-password'{$model.accounts[1].password=$model.accounts[0].password}
  'same-id'{$model.accounts[1].user_id=$model.accounts[0].user_id}
  'invalid-id'{$model.accounts[0].user_id='invalid'}
 }
 Assert-GuardRejects {Assert-FixtureModel $model} $case
}
$config=@{APP_ENV='staging';SUPABASE_PROJECT_REF='gqtetdavmrautoojaqrk';SUPABASE_URL='https://gqtetdavmrautoojaqrk.supabase.co';
 ALLOW_PRODUCTION_BACKEND=$false;SUPABASE_PUBLISHABLE_KEY='sb_publishable_fixture_only'}
Assert-FixtureConfig $config;++$fixtureGuardCount
foreach($case in @('production','url','ref','opt-in','string-bool','empty-key')) {
 $bad=$config.Clone()
 switch($case) {
  'production'{$bad.APP_ENV='production'}
  'url'{$bad.SUPABASE_URL='https://dvakrwalnqpcmgirmlct.supabase.co'}
  'ref'{$bad.SUPABASE_PROJECT_REF='dvakrwalnqpcmgirmlct'}
  'opt-in'{$bad.ALLOW_PRODUCTION_BACKEND=$true}
  'string-bool'{$bad.ALLOW_PRODUCTION_BACKEND='false'}
  'empty-key'{$bad.SUPABASE_PUBLISHABLE_KEY=''}
 }
 Assert-GuardRejects {Assert-FixtureConfig $bad} $case
}
$model=New-GuardModel;$account=$model.accounts[0]
$user=@{id=$account.user_id;email=$account.email;email_confirmed_at='2026-10-24';
 user_metadata=@{requested_role='owner'};app_metadata=@{test_project_ref=$model.project_ref;
 test_fixture=$model.fixture;test_run_id=$model.run_id;synthetic_test_account=$true}}
Assert-FixtureIdentity $user $account $model.run_id;++$fixtureGuardCount
foreach($field in @('test_project_ref','test_fixture','test_run_id','synthetic_test_account')) {
 $original=$user.app_metadata[$field];$user.app_metadata[$field]='wrong'
 Assert-GuardRejects {Assert-FixtureIdentity $user $account $model.run_id} $field
 $user.app_metadata[$field]=$original
}
$user.email_confirmed_at=$null
Assert-GuardRejects {Assert-FixtureIdentity $user $account $model.run_id} 'unconfirmed'
$user.email_confirmed_at='2026-10-24';$user.app_metadata.synthetic_test_account='true'
Assert-GuardRejects {Assert-FixtureIdentity $user $account $model.run_id} 'string synthetic flag'
Assert-GuardRejects {Assert-FixtureWriteConfirmation 'Setup' '' ''} 'missing write target'
Assert-GuardRejects {Assert-FixtureWriteConfirmation 'Setup' 'dvakrwalnqpcmgirmlct' ''} 'original write target'
Assert-GuardRejects {Assert-FixtureWriteConfirmation 'Cleanup' 'gqtetdavmrautoojaqrk' ''} 'missing cleanup preview'
Assert-GuardRejects {Assert-FixtureWriteConfirmation 'Cleanup' 'gqtetdavmrautoojaqrk' 'wrong'} 'bad cleanup preview'
Assert-FixtureWriteConfirmation 'Plan' '' '';++$fixtureGuardCount
Assert-FixtureWriteConfirmation 'Verify' '' '';++$fixtureGuardCount
Assert-FixtureWriteConfirmation 'Setup' 'gqtetdavmrautoojaqrk' '';++$fixtureGuardCount
# Test path allowlist before any HTTP can be attempted.
foreach($path in @('/auth/v1/admin/users/ordinary','/rest/v1/provider_profile','/storage/v1/object/anything','/rest/v1/rpc/transition_booking','https://other.invalid/')) {
 Assert-GuardRejects {Invoke-FixtureHttp -Path $path -Headers @{}} $path
}
Write-Output "PASS: $fixtureGuardCount offline fixture guard cases; no real credentials, cloud writes or HTTP."
