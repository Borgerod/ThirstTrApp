# Run ThirstTrApp on the web with a STABLE origin so saved data persists.
#
# Browser storage (IndexedDB, where Hive keeps rooms/plants/windows/heat
# sources/floorplan/watered-status) is scoped per origin *including the port*.
# A plain `flutter run -d chrome` picks a random port each launch and opens an
# empty database every time. Pinning the port keeps one persistent database.
#
# Usage:  ./run-web.ps1        (from the project root, in PowerShell)
#
# Also starts the local CORS proxy in the background so Mestergrønn search and
# plant images load on web. Native builds don't need any of this — just run
# `flutter run -d windows` (or `-d <phone>`); those persist to disk directly.

$ErrorActionPreference = 'Stop'
$webPort = 5353
$proxyPort = 8787

# Start the CORS proxy only if nothing is already listening on its port.
$proxyUp = Get-NetTCPConnection -LocalPort $proxyPort -State Listen -ErrorAction SilentlyContinue
if (-not $proxyUp) {
    Write-Host "Starting CORS proxy on :$proxyPort ..." -ForegroundColor Cyan
    Start-Process -WindowStyle Minimized powershell `
        -ArgumentList '-NoExit', '-Command', "dart run tool/cors_proxy.dart"
    Start-Sleep -Seconds 2
} else {
    Write-Host "CORS proxy already running on :$proxyPort." -ForegroundColor DarkGray
}

Write-Host "Launching app on http://localhost:$webPort (persistent storage)" -ForegroundColor Green
flutter run -d chrome --web-port=$webPort
