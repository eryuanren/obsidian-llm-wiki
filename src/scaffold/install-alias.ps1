#!/usr/bin/env pwsh
# Add a `sunny` function to your PowerShell profile so you can drive the wiki from
# anywhere (e.g. `sunny -Ingest`, `sunny -Status`).
#
# Note on the name: PowerShell resolves functions ahead of executables, so this function
# shadows the sunny CLI inside your shell. That used to break the pipeline, because the
# tool scripts call the CLI to do the real work and would reach this wrapper instead.
# They no longer look the command up that way - Resolve-SunnyCli in _common.ps1 accepts
# only an actual executable - so the function and the CLI coexist safely.
#
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
Write-Host "The sunny CLI itself stays reachable to the tool scripts." -ForegroundColor Gray
