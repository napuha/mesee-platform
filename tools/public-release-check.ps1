$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pass = 0
$pending = 0
function Check($label, $condition, $pendingLabel) {
  if ($condition) { Write-Host "PASS $label" -ForegroundColor Green; $script:pass++ }
  else { Write-Host "PENDING $pendingLabel" -ForegroundColor Yellow; $script:pending++ }
}

Check 'Flutter Android platform' (Test-Path (Join-Path $root 'android')) 'Generate android platform'
Check 'Flutter iOS platform' (Test-Path (Join-Path $root 'ios')) 'Generate iOS platform'
Check 'Camera permissions' ((Get-Content (Join-Path $root 'android\app\src\main\AndroidManifest.xml') -Raw) -match 'android.permission.CAMERA') 'Add Android camera permission'
Check 'iOS camera usage text' ((Get-Content (Join-Path $root 'ios\Runner\Info.plist') -Raw) -match 'NSCameraUsageDescription') 'Add iOS camera usage text'
Check 'Supabase migrations 001-015' ((Get-ChildItem (Join-Path $root 'supabase') -Filter '*.sql').Count -ge 15) 'Apply all Supabase migrations'
Check 'Release CI workflow' (Test-Path (Join-Path $root '.github\workflows\flutter-release.yml')) 'Add release CI workflow'
Check 'Debug APK' (Test-Path (Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk')) 'Build debug APK'
Check 'Release AAB' (Test-Path (Join-Path $root 'build\app\outputs\bundle\release\app-release.aab')) 'Build release app bundle'
Check 'Android signing configuration' (Test-Path (Join-Path $root 'android\key.properties')) 'Configure release signing outside source control'
$androidGradle = Get-Content (Join-Path $root 'android\app\build.gradle.kts') -Raw
$placeholderId = $androidGradle -match 'applicationId\s*=\s*"com\.example\.mesee"'
Check 'Store application id selected' (-not $placeholderId) 'Replace development application id before store submission'
$iosProject = Get-Content (Join-Path $root 'ios\Runner.xcodeproj\project.pbxproj') -Raw
$iosPlaceholderId = $iosProject -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.example\.mesee;'
Check 'iOS bundle id selected' (-not $iosPlaceholderId) 'Replace development iOS bundle id before store submission'
Check 'Supabase URL provided' (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_URL)) 'Set SUPABASE_URL in release environment'
Check 'Supabase publishable key provided' (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_ANON_KEY)) 'Set SUPABASE_ANON_KEY in release environment'

Write-Host "`nPassed: $pass  Pending: $pending"
if ($pending -gt 0) { exit 2 }
