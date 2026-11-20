#!/usr/bin/env pwsh
# DEPRECATED: kept for backward compatibility. Use ./tools/ingest.ps1 instead.
# This shim forwards to ingest.ps1, which ingests what is queued in inbox/.

param(
    [switch]$All,           # accepted but ignored; ingest.ps1 always processes the queue
    [string]$File,
    [string]$SunnyCmd = ""
)

Write-Host "invoke-sunny.ps1 is deprecated -> forwarding to ingest.ps1" -ForegroundColor Yellow

$forward = @{}
if ($File)     { $forward["File"] = $File }
if ($SunnyCmd) { $forward["SunnyCmd"] = $SunnyCmd }

& "$PSScriptRoot\ingest.ps1" @forward
exit $LASTEXITCODE
