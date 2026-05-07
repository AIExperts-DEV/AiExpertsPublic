# cdp-relay-setup.ps1
# One-shot setup for the Caterpillar CDP relay on the Windows VPS.
# Run as Administrator.
#
# Usage:
#   irm https://raw.githubusercontent.com/AIExperts-DEV/AiExpertsPublic/main/cdp-relay-setup.ps1 | iex

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===== CDP relay setup =====" -ForegroundColor Cyan
Write-Host ""

# 1. Find Chrome
$chromePaths = @(
  "C:\Program Files\Google\Chrome\Application\chrome.exe",
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chrome = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
  Write-Host "Chrome not found." -ForegroundColor Red
  Write-Host "Install it from https://www.google.com/chrome/ then re-run this script."
  exit 1
}

Write-Host "Chrome found: $chrome" -ForegroundColor Green

# 2. Verify cloudflared is installed
$cloudflared = (Get-Command cloudflared -ErrorAction SilentlyContinue)?.Source
if (-not $cloudflared) {
  Write-Host "cloudflared not in PATH." -ForegroundColor Red
  Write-Host "Install the Windows MSI from https://github.com/cloudflare/cloudflared/releases/latest"
  exit 1
}
Write-Host "cloudflared found: $cloudflared" -ForegroundColor Green

# 3. Kill any stale Chrome/cloudflared from previous runs
Write-Host ""
Write-Host "Stopping any old Chrome / cloudflared processes from previous runs..."
Get-Process chrome -ErrorAction SilentlyContinue | Where-Object {
  $_.MainWindowTitle -eq "" -or $_.Path -eq $chrome
} | Stop-Process -Force -ErrorAction SilentlyContinue

# 4. Launch Chrome with CDP enabled
Write-Host ""
Write-Host "Launching Chrome with CDP on port 9222..." -ForegroundColor Cyan
$profileDir = "C:\chrome-cdp-profile"
$null = New-Item -ItemType Directory -Force -Path $profileDir
Start-Process $chrome -ArgumentList @(
  "--remote-debugging-port=9222",
  "--remote-allow-origins=*",
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--no-default-browser-check",
  "--disable-features=Translate"
)

Start-Sleep -Seconds 4

# 5. Verify CDP is reachable
try {
  $resp = Invoke-RestMethod http://localhost:9222/json/version -TimeoutSec 8
  Write-Host ""
  Write-Host "Chrome CDP is up:" -ForegroundColor Green
  Write-Host "  Browser:   $($resp.Browser)"
  Write-Host "  WebSocket: $($resp.webSocketDebuggerUrl)"
} catch {
  Write-Host "FAILED to reach localhost:9222 — Chrome did not start cleanly." -ForegroundColor Red
  Write-Host "Try running this script again from a fresh PowerShell."
  exit 1
}

Write-Host ""
Write-Host "===== STEP 1 DONE =====" -ForegroundColor Green
Write-Host ""
Write-Host "Now do these three commands one at a time, in this same window:"
Write-Host ""
Write-Host "   cloudflared tunnel login" -ForegroundColor Yellow
Write-Host "       (opens browser, click Authorize for crissie.com.au)"
Write-Host ""
Write-Host "   cloudflared tunnel create cat-cdp" -ForegroundColor Yellow
Write-Host "       (note the UUID it prints)"
Write-Host ""
Write-Host "   cloudflared tunnel route dns cat-cdp cat-cdp.crissie.com.au" -ForegroundColor Yellow
Write-Host ""
Write-Host "When all three are done, run the second-half script:"
Write-Host "   irm https://raw.githubusercontent.com/AIExperts-DEV/AiExpertsPublic/main/cdp-relay-finish.ps1 | iex" -ForegroundColor Cyan
Write-Host ""
