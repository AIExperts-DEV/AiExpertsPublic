# cdp-relay-finish.ps1
# Run AFTER cdp-relay-setup.ps1 + the three `cloudflared tunnel ...` commands.
# Writes config.yml and starts the tunnel.
#
# Usage:
#   irm https://raw.githubusercontent.com/AIExperts-DEV/AiExpertsPublic/main/cdp-relay-finish.ps1 | iex

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===== finishing CDP relay setup =====" -ForegroundColor Cyan
Write-Host ""

$cfDir = Join-Path $env:USERPROFILE ".cloudflared"
if (-not (Test-Path $cfDir)) {
  Write-Host "$cfDir does not exist — run 'cloudflared tunnel login' first." -ForegroundColor Red
  exit 1
}

# Find tunnel credentials json (the UUID-named file from `tunnel create`)
$creds = Get-ChildItem $cfDir -Filter "*.json" |
  Where-Object { $_.Name -match "^[0-9a-fA-F-]{36}\.json$" } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $creds) {
  Write-Host "No tunnel credentials found in $cfDir." -ForegroundColor Red
  Write-Host "Run 'cloudflared tunnel create cdp' first."
  exit 1
}

$uuid = $creds.BaseName
Write-Host "Using tunnel credentials: $($creds.FullName)" -ForegroundColor Green

# Write config.yml
$cfg = @"
tunnel: cdp
credentials-file: $($creds.FullName)

ingress:
  - hostname: cdp.crissie.com.au
    service: http://localhost:9222
    originRequest:
      noTLSVerify: true
      connectTimeout: 30s
      httpHostHeader: localhost
  - service: http_status:404
"@

$cfgPath = Join-Path $cfDir "config.yml"
Set-Content -Path $cfgPath -Value $cfg -Encoding UTF8
Write-Host "Wrote $cfgPath" -ForegroundColor Green
Write-Host ""
Get-Content $cfgPath | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "===== running tunnel (foreground) =====" -ForegroundColor Cyan
Write-Host "Leave this window open. Test from another machine:"
Write-Host "   curl https://cdp.crissie.com.au/json/version" -ForegroundColor Yellow
Write-Host ""
Write-Host "(Ctrl+C to stop. Later we'll register it as a Windows service.)"
Write-Host ""

cloudflared tunnel run cdp
