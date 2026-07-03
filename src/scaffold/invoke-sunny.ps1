#!/usr/bin/env pwsh
# DEPRECATED: kept for backward compatibility. Use ./tools/ingest.ps1 instead.
# This shim now forwards to ingest.ps1, which ingests everything queued in inbox/.

param(
    [switch]$All,           # accepted but ignored; ingest.ps1 always processes the whole inbox
    [string]$File,
    [string]$SunnyCmd = "sunny"
)

Write-Host "invoke-sunny.ps1 is deprecated -> forwarding to ingest.ps1" -ForegroundColor Yellow

if ($File) {
    & "$PSScriptRoot\ingest.ps1" -File $File -SunnyCmd $SunnyCmd
} else {
    & "$PSScriptRoot\ingest.ps1" -SunnyCmd $SunnyCmd
}
exit $LASTEXITCODE
