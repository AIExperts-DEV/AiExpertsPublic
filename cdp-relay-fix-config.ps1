# cdp-relay-fix-config.ps1
# Overwrites config.yml with correct hostname (cdp.crissie.com.au)
# and the Host-header rewrite Chrome's CDP requires.
#
# Usage:
#   irm https://raw.githubusercontent.com/AIExperts-DEV/AiExpertsPublic/main/cdp-relay-fix-config.ps1 | iex

$ErrorActionPreference = "Stop"

$cfDir = Join-Path $env:USERPROFILE ".cloudflared"

# Find the most recent UUID-named credentials JSON
$creds = Get-ChildItem $cfDir -Filter "*.json" |
  Where-Object { $_.Name -match "^[0-9a-fA-F-]{36}\.json$" } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $creds) {
  Write-Host "No tunnel credentials found in $cfDir" -ForegroundColor Red
  exit 1
}

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

Write-Host ""
Write-Host "Wrote $cfgPath" -ForegroundColor Green
Write-Host "----- new content -----" -ForegroundColor Cyan
Get-Content $cfgPath | ForEach-Object { Write-Host "  $_" }
Write-Host "-----------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now go to the cloudflared window:" -ForegroundColor Yellow
Write-Host "  1. Press Ctrl+C until the tunnel shuts down"
Write-Host "  2. Run: cloudflared tunnel run cdp"
Write-Host "  3. Wait for the 4 'Registered tunnel connection' lines"
Write-Host ""
