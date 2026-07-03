#!/usr/bin/env pwsh
# Add a `sunny` function to your PowerShell profile so you can run wiki commands
# from anywhere (e.g. `sunny -Ingest`, `sunny -Status`).
# Usage: ./tools/install-alias.ps1

$ErrorActionPreference = "Stop"

$wrapper = (Resolve-Path "$PSScriptRoot\sunny.ps1").Path
$marker  = "# >>> llm-wiki sunny alias >>>"
$block   = @"
$marker
function sunny { & "$wrapper" @args }
# <<< llm-wiki sunny alias <<<
"@

if (!(Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created profile: $PROFILE" -ForegroundColor Gray
}

$current = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($current -and $current.Contains($marker)) {
    Write-Host "sunny alias already installed in $PROFILE" -ForegroundColor Yellow
    exit 0
}

Add-Content -Path $PROFILE -Value "`n$block`n"
Write-Host "Added 'sunny' function to $PROFILE" -ForegroundColor Green
Write-Host "Reload with:  . `$PROFILE   (or open a new terminal)" -ForegroundColor Yellow
Write-Host "Then use:     sunny -Ingest | sunny -Status | sunny -Prompt 'lint the wiki'" -ForegroundColor Gray
