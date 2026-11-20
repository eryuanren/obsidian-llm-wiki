#!/usr/bin/env pwsh
# Front door for the LLM Wiki. Install it as the `sunny` command with
# ./tools/install-alias.ps1, then:
#   sunny -Build                 # convert raw/ -> ingest -> archive what succeeded
#   sunny -Ingest                # ingest everything queued in inbox/
#   sunny -Query "question"      # ask the wiki, with fallback to the cited sources
#   sunny -Lint                  # health-check the wiki
#   sunny -Status                # wiki stats + recent activity
#   sunny -Prompt "..."          # send a free-form prompt to Sunny
#
# The `sunny` function shadows the sunny CLI inside your shell, which is fine: the tool
# scripts resolve the CLI as an executable (Resolve-SunnyCli), never by name lookup.

param(
    [switch]$Build,
    [switch]$Ingest,
    [switch]$Lint,
    [switch]$Status,
    [string]$Query,
    [string]$Prompt,
    [switch]$Auto,
    [string]$SunnyCmd = ""      # explicit CLI path or name; auto-detected when empty
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (!$Build -and !$Ingest -and !$Lint -and !$Status -and !$Query -and !$Prompt) {
    Write-Host @"
=== LLM Wiki — Sunny CLI ===

  sunny -Build                   Full pipeline: convert raw/ -> ingest -> archive
  sunny -Ingest                  Ingest everything queued in inbox/
  sunny -Query "<question>"      Ask the wiki (falls back to the cited sources)
  sunny -Lint                    Health-check the wiki and report
  sunny -Status                  Show wiki stats and recent activity
  sunny -Prompt "<message>"      Send a free-form prompt to Sunny

  -Auto                          Auto-approve Sunny's file edits (unattended runs)

Examples:
  sunny -Build
  sunny -Query "what did Smith 2024 say about attention?"
"@
    exit 0
}

if ($Build) {
    $buildArgs = @{}
    if ($SunnyCmd) { $buildArgs["SunnyCmd"] = $SunnyCmd }
    if ($Auto)     { $buildArgs["Auto"] = $true }
    & "$PSScriptRoot\build.ps1" @buildArgs
    exit $LASTEXITCODE
}

if ($Ingest) {
    $ingestArgs = @{}
    if ($SunnyCmd) { $ingestArgs["SunnyCmd"] = $SunnyCmd }
    if ($Auto)     { $ingestArgs["Auto"] = $true }
    & "$PSScriptRoot\ingest.ps1" @ingestArgs
    exit $LASTEXITCODE
}

if ($Status) {
    Write-Host "=== LLM Wiki Status ===" -ForegroundColor Cyan
    Write-Host ""

    # Wiki page counts.
    $folders = [ordered]@{
        "Entities"  = "wiki/entities"
        "Concepts"  = "wiki/concepts"
        "Sources"   = "wiki/sources"
        "Synthesis" = "wiki/synthesis"
    }
    foreach ($kv in $folders.GetEnumerator()) {
        $path = Join-Path $WikiRoot $kv.Value
        $count = if (Test-Path $path) { (Get-ChildItem $path -Filter *.md -File).Count } else { 0 }
        Write-Host ("{0,-10}: {1} pages" -f $kv.Key, $count) -ForegroundColor Green
    }
    Write-Host ""

    # Queue state.
    $inbox = Join-Path $WikiRoot "inbox"
    $proc  = Join-Path $WikiRoot "processed"
    $inboxCount = if (Test-Path $inbox) { (Get-ChildItem $inbox -File | Where-Object { $_.Name -ne ".gitkeep" }).Count } else { 0 }
    $procCount  = if (Test-Path $proc)  { (Get-ChildItem $proc  -File | Where-Object { $_.Name -ne ".gitkeep" }).Count } else { 0 }
    Write-Host "Inbox (awaiting ingest): $inboxCount" -ForegroundColor Yellow
    Write-Host "Processed (archived):    $procCount" -ForegroundColor Gray

    # Anything ingested but not yet archived?
    $status = Read-IngestStatus -WikiRoot $WikiRoot
    if ($status.Count -gt 0) {
        $done = @($status.Keys | Where-Object { $status[$_].status -eq "done" })
        if ($done.Count -gt 0) {
            Write-Host "Marked done, awaiting archive: $($done.Count)" -ForegroundColor Cyan
        }
    }
    Write-Host ""

    # Recent log entries (parseable by the documented prefix).
    $logPath = Join-Path $WikiRoot "wiki/log.md"
    if (Test-Path $logPath) {
        Write-Host "Recent activity:" -ForegroundColor Cyan
        $recent = Select-String -Path $logPath -Pattern '^## \[' | Select-Object -Last 5
        if ($recent) { $recent | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Gray } }
        else { Write-Host "  No activity yet" -ForegroundColor Gray }
    }
    exit 0
}

# --- Everything below drives the CLI directly. -------------------------------

$cli = Resolve-SunnyCli -Preferred $SunnyCmd
if (-not $cli) {
    Write-NoSunnyHelp -Preferred $(if ($SunnyCmd) { $SunnyCmd } else { "sunny" })
    exit 1
}

<#
Run one of the wiki's custom commands from .opencode/commands/, falling back to a
plain prompt when that command file isn't in the vault.
#>
function Invoke-WikiCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$Arguments = "",
        [Parameter(Mandatory)][string]$Fallback,
        [Parameter(Mandatory)][string]$Title
    )

    $commandFile = Join-Path $WikiRoot ".opencode/commands/$Command.md"
    if (Test-Path $commandFile) {
        $cliArgs = @("run", $Arguments, "--command", $Command)
    } else {
        Write-Host "No .opencode/commands/$Command.md - sending a plain prompt." -ForegroundColor Yellow
        $cliArgs = @("run", $Fallback)
    }
    $cliArgs += @("--title", $Title)
    if ($Auto) { $cliArgs += "--auto" }

    Push-Location $WikiRoot
    try { & $cli @cliArgs } finally { Pop-Location }
    return $LASTEXITCODE
}

if ($Lint) {
    Write-Host "=== Linting the wiki ===" -ForegroundColor Cyan
    $code = Invoke-WikiCommand -Command "wiki-lint" -Title "Lint the wiki" `
        -Fallback "Lint the wiki, following the LINT workflow in the LLM Wiki schema. Health-check and report only - do not auto-fix unless I ask."
    exit $code
}

if ($Query) {
    Write-Host "=== Asking the wiki ===" -ForegroundColor Cyan
    Write-Host "Question: $Query`n" -ForegroundColor Yellow
    $code = Invoke-WikiCommand -Command "wiki-query" -Arguments $Query -Title "Query: $Query" `
        -Fallback "Answer this question from the wiki, following the QUERY workflow in the LLM Wiki schema. Open the cited source pages and the files in processed/ before quoting any figure, date or quotation.`n`nQuestion: $Query"
    exit $code
}

if ($Prompt) {
    Write-Host "=== Sending to Sunny ($cli) ===" -ForegroundColor Cyan
    Write-Host "Prompt: $Prompt`n" -ForegroundColor Yellow
    $cliArgs = @("run", $Prompt)
    if ($Auto) { $cliArgs += "--auto" }
    Push-Location $WikiRoot
    try { & $cli @cliArgs } finally { Pop-Location }
    exit $LASTEXITCODE
}
