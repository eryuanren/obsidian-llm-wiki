#!/usr/bin/env pwsh
# Archive one ingested file: move it from inbox/ to processed/ and record it in
# wiki/processed.md with the content hash of the raw source it came from.
# (Sunny owns wiki/log.md - this script does not touch it.)
#
# The hash is what makes dedupe honest: a renamed source is still recognised as
# ingested, and an edited one is recognised as new.
#
# Usage: ./tools/mark-processed.ps1 <filename> [notes]

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$Notes = "",
    [string]$Status = "Completed",

    [string]$WikiRoot      = "$PSScriptRoot\..",
    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot      = (Resolve-Path $WikiRoot).Path
$ProcessedFile = Get-ProcessedPath -WikiRoot $WikiRoot

$fileName = [System.IO.Path]::GetFileName($File)
$date     = Get-Date -Format "yyyy-MM-dd"

if (!(Test-Path $ProcessedPath)) { New-Item -ItemType Directory -Path $ProcessedPath | Out-Null }

# Provenance recorded at queue time: which raw file this came from, and its hash.
$queue  = Read-Queue -WikiRoot $WikiRoot
$entry  = $queue[$fileName]
$source = if ($entry -and $entry.source) { $entry.source } else { "" }
$hash   = if ($entry -and $entry.hash)   { $entry.hash }   else { "" }

if (-not $hash) {
    # No manifest entry (queued by an older version of the tools, or hand-dropped into
    # inbox/). Hash what we are archiving so future runs still have something to match.
    $queued = Join-Path $InboxPath $fileName
    if (Test-Path -LiteralPath $queued) { $hash = Get-ContentHash -Path $queued }
}

# Move the queued file from the queue to the archive (if still in inbox/).
$src = Join-Path $InboxPath $fileName
if (Test-Path -LiteralPath $src) {
    Move-Item -LiteralPath $src -Destination (Join-Path $ProcessedPath $fileName) -Force
    Write-Host "Archived inbox/$fileName -> processed/$fileName" -ForegroundColor Green
} else {
    Write-Host "Note: inbox/$fileName not found (already archived?). Recording anyway." -ForegroundColor Yellow
}

if (!(Test-Path $ProcessedFile)) { Write-Host "Error: wiki/processed.md not found" -ForegroundColor Red; exit 1 }

$newHeader    = "| Date | File | Source | Hash | Status | Notes |"
$newSeparator = "|------|------|--------|------|--------|-------|"

$lines = (Get-Content -LiteralPath $ProcessedFile -Raw) -split "`r?`n"
$out = @()
$inserted = $false
$upgraded = $false
$sawHeader = $false

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    # The audit table's header. Older wikis have the four-column form; widen it once.
    if (-not $sawHeader -and $trimmed -match '^\|\s*Date\s*\|\s*File\s*\|') {
        $sawHeader = $true
        if ($trimmed -notmatch '\|\s*Hash\s*\|') {
            $out += $newHeader
            $upgraded = $true
        } else {
            $out += $line
        }
        continue
    }

    # The separator row directly under the header: emit it, then insert the new record
    # at the top of the table so the newest entry reads first.
    if ($sawHeader -and -not $inserted -and $trimmed -match '^\|[-\s|:]+\|$') {
        $out += $(if ($upgraded) { $newSeparator } else { $line })
        $out += "| $date | $fileName | $source | $hash | $Status | $Notes |"
        $inserted = $true
        continue
    }

    # Existing four-column rows need two empty cells so the table stays well-formed.
    if ($upgraded -and $inserted -and $trimmed.StartsWith("|") -and $trimmed -notmatch '^\|[-\s|:]+\|$') {
        $cells = $trimmed.Trim([char]0x7C) -split '\|'
        if ($cells.Count -eq 4) {
            $out += "|$($cells[0])|$($cells[1])|  |  |$($cells[2])|$($cells[3])|"
            continue
        }
    }

    $out += $line
}

if (-not $inserted) {
    # No table found - append one rather than silently dropping the record.
    $out += ""
    $out += $newHeader
    $out += $newSeparator
    $out += "| $date | $fileName | $source | $hash | $Status | $Notes |"
}

$enc = New-Object System.Text.UTF8Encoding $false   # no BOM: Obsidian and git both prefer it
[System.IO.File]::WriteAllText($ProcessedFile, ($out -join "`n"), $enc)

Remove-QueueEntry -WikiRoot $WikiRoot -InboxName $fileName

if ($upgraded) { Write-Host "Upgraded wiki/processed.md to the Source/Hash table." -ForegroundColor Cyan }
Write-Host "Recorded '$fileName' in wiki/processed.md (hash $hash)" -ForegroundColor Green
