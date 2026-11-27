# Lisancom - one-shot setup & build for Windows (PowerShell).
# Usage: right-click > "Run with PowerShell", or run scripts\setup.bat
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

Step 'Checking Flutter'
flutter --version

Step 'Generating missing platform files (existing files are kept)'
flutter create --org com.lisancom --project-name lisancom --platforms=android,ios .

Step 'Setting Android minSdk 24 (required by record / sherpa-onnx / ML Kit)'
foreach ($g in @('android/app/build.gradle.kts', 'android/app/build.gradle')) {
  if (Test-Path $g) {
    $c = Get-Content $g -Raw
    $c = $c -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24'
    $c = $c -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24'
    Set-Content $g $c -NoNewline
  }
}

Step 'Installing packages'
flutter pub get

Step 'Formatting & analysing'
dart format lib test
flutter analyze

Step 'Running tests'
flutter test

Step 'Building debug APK'
flutter build apk --debug

Write-Host "`nDone. APK: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
Write-Host 'Install on a phone with USB debugging:  flutter install   (or copy the APK to the phone)'
