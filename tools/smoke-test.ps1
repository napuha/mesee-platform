$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$prototype = Join-Path (Split-Path $root -Parent) 'mesee-prototype'

Write-Host 'Checking prototype JavaScript...'
node --check (Join-Path $prototype 'app.js')
node --check (Join-Path $PSScriptRoot 'serve-prototype.js')

Write-Host 'Checking Flutter foundation...'
foreach ($path in @('pubspec.yaml','lib\main.dart')) {
  if (-not (Test-Path (Join-Path $root $path))) { throw "Missing required file: $path" }
}
$repositoryCode = Get-Content (Join-Path $root 'lib\post_repository.dart') -Raw
foreach ($method in @('recordImpression','blockUser','fetchUserSettings','updateUserSettings','createLivePost','fetchCreatorAnalytics','requestAccountDeletion','cancelAccountDeletion')) {
  if ($repositoryCode -notmatch "Future[^\r\n]*\b$method\b") { throw "Missing repository capability: $method" }
}
$mainCode = Get-Content (Join-Path $root 'lib\main.dart') -Raw
if ($mainCode -notmatch '動画を再生できませんでした') { throw 'Missing video playback failure feedback.' }
if ($repositoryCode -notmatch '500 \* 1024 \* 1024') { throw 'Missing upload size guard.' }

Write-Host 'Checking Supabase migration sequence...'
$migrations = Get-ChildItem (Join-Path $root 'supabase') -Filter '*.sql' | Sort-Object Name
$expected = 1
foreach ($migration in $migrations) {
  if ($migration.Name -notmatch '^(\d{3})_') { throw "Invalid migration filename: $($migration.Name)" }
  if ([int]$Matches[1] -ne $expected) { throw "Migration sequence must start at ${expected}: $($migration.Name)" }
  $expected++
}
if ($migrations.Count -lt 13) { throw 'Expected core migrations 001 through 013.' }

$requiredSql = @('profiles','posts','post_reactions','follows','notifications','reports','post_view_events','messages','blocked_users','user_settings')
$sql = ($migrations | Get-Content -Raw) -join "`n"
foreach ($name in $requiredSql) {
  if ($sql -notmatch "public\.$name") { throw "Missing SQL definition reference: $name" }
}
$requiredSqlPatterns = @(
  'alter table public\.posts add column if not exists updated_at',
  'create or replace function public\.can_view_post',
  'create or replace function public\.handle_new_user_profile',
  "bucket_id = 'mesee-media'",
  'create policy "users upload own media"',
  'create trigger on_auth_user_created_profile',
  'supabase_realtime',
  'replica identity full',
  'creators read own revenue ledger',
  'admins manage revenue ledger'
  'create or replace function public\.get_recommended_posts'
  'admins read reports'
  'admins moderate posts'
  'request_account_deletion'
  'cancel_account_deletion'
  'interval ''30 days'''
)
foreach ($pattern in $requiredSqlPatterns) {
  if ($sql -notmatch $pattern) { throw "Missing required SQL safeguard: $pattern" }
}

Write-Host 'MeSee smoke test passed.' -ForegroundColor Green
