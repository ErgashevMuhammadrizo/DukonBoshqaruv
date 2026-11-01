$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
flutter config --enable-windows-desktop
if ($LASTEXITCODE -ne 0) { throw "Flutter sozlanmadi" }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Paketlar olinmadi" }
flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { throw "Dart xatolarini tuzating" }
flutter build windows --release --dart-define-from-file=config/production.json
if ($LASTEXITCODE -ne 0) { throw "Windows build xatosi" }
$release = "build/windows/x64/runner/Release"
New-Item -ItemType Directory -Force -Path "../dist" | Out-Null
Compress-Archive -Path "$release/*" -DestinationPath "../dist/e-dukon-Windows.zip" -Force
Write-Host "Tayyor: dist/e-dukon-Windows.zip. Faqat EXE emas, butun papkani tarqating."
