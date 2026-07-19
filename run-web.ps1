# Run ThirstTrApp on the web with data that ACTUALLY persists.
#
# Two things are required, and this script does both:
#   1. Stable origin: browser storage (IndexedDB, where Hive keeps
#      rooms/plants/windows/heat sources/floorplan/watered-status) is scoped
#      per origin *including the port* — so the port is pinned to 5353.
#   2. A browser Flutter does NOT manage: `flutter run -d chrome` gives Chrome
#      a throwaway profile and shuffles it around on every start/stop — data
#      written there gets lost even on the right port (verified 2026-07-19).
#      So we serve with `-d web-server` and open your normal browser, whose
#      profile survives anything, including killing the terminal mid-run.
#
# Usage:  ./run-web.ps1        (from the project root, in PowerShell)
#         hot reload: press r in this terminal; refresh the browser tab.
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

# Open the user's default browser once the dev server is listening.
Start-Job -ScriptBlock {
    param($port)
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Date) -lt $deadline) {
        if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
            Start-Process "http://localhost:$port"
            return
        }
        Start-Sleep -Seconds 2
    }
} -ArgumentList $webPort | Out-Null

Write-Host "Serving app on http://localhost:$webPort (persistent storage, opens in your browser)" -ForegroundColor Green
flutter run -d web-server --web-port=$webPort
