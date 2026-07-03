#!/usr/bin/env pwsh
# Archive one ingested markdown file: move it from inbox/ to processed/ and record it
# in wiki/processed.md. Call after Sunny has ingested the file and you've reviewed it.
# (Sunny owns wiki/log.md — this script does not touch it.)
# Usage: ./tools/mark-processed.ps1 <filename> [notes]

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$Notes = "",

    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed",
    [string]$ProcessedFile = "$PSScriptRoot\..\wiki\processed.md"
)

$ErrorActionPreference = "Stop"

$fileName = [System.IO.Path]::GetFileName($File)
$date = Get-Date -Format "yyyy-MM-dd"

if (!(Test-Path $ProcessedPath)) { New-Item -ItemType Directory -Path $ProcessedPath | Out-Null }

# Move the converted markdown from the queue to the archive (if still in inbox/).
$src = Join-Path $InboxPath $fileName
if (Test-Path $src) {
    Move-Item -Path $src -Destination (Join-Path $ProcessedPath $fileName) -Force
    Write-Host "Archived inbox/$fileName -> processed/$fileName" -ForegroundColor Green
} else {
    Write-Host "Note: inbox/$fileName not found (already archived?). Recording anyway." -ForegroundColor Yellow
}

# Record in the audit table.
if (!(Test-Path $ProcessedFile)) { Write-Host "Error: wiki/processed.md not found" -ForegroundColor Red; exit 1 }

$tableHeader = "| Date | File | Status | Notes |"
$lines = (Get-Content $ProcessedFile -Raw) -split "`r?`n"
$out = @(); $inserted = $false
foreach ($line in $lines) {
    $out += $line
    if (-not $inserted -and $line.Trim() -eq $tableHeader.Trim()) {
        # Skip the separator row, then insert.
        continue
    }
    if (-not $inserted -and $line -match '^\|[-\s|]+\|$') {
        $out += "| $date | $fileName | Completed | $Notes |"
        $inserted = $true
    }
}
if (-not $inserted) { $out += "| $date | $fileName | Completed | $Notes |" }

($out -join "`n") | Out-File -FilePath $ProcessedFile -Encoding utf8
Write-Host "Recorded '$fileName' in wiki/processed.md" -ForegroundColor Green
