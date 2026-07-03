#!/usr/bin/env pwsh
# Check whether a file has already been ingested (recorded in wiki/processed.md or
# present in processed/). Exit 0 = new, exit 1 = duplicate.
# Usage: ./tools/check-duplicate.ps1 <filename>

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$ProcessedFile   = "$PSScriptRoot\..\wiki\processed.md",
    [string]$ProcessedFolder = "$PSScriptRoot\..\processed"
)

# A queued item keeps its name (images, .md) or becomes <base>.md (documents),
# so check both the original filename and the .md variant.
$orig = [System.IO.Path]::GetFileName($File)
$base = [System.IO.Path]::GetFileNameWithoutExtension($File)
$mdName = "$base.md"

$inFolder = (Test-Path (Join-Path $ProcessedFolder $mdName)) -or (Test-Path (Join-Path $ProcessedFolder $orig))
$inTable  = $false
if (Test-Path $ProcessedFile) {
    $content = Get-Content $ProcessedFile -Raw
    if ($content -match [regex]::Escape($mdName) -or $content -match [regex]::Escape($orig)) {
        $inTable = $true
    }
}

if ($inFolder -or $inTable) {
    Write-Host "DUPLICATE: '$base' has already been ingested." -ForegroundColor Red
    if ($inFolder) { Write-Host "  Found in processed/$mdName" -ForegroundColor Gray }
    if ($inTable)  { Write-Host "  Recorded in wiki/processed.md" -ForegroundColor Gray }
    Write-Host "Skip it, or remove the record/file to re-ingest intentionally." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "OK: '$base' has not been ingested yet." -ForegroundColor Green
    exit 0
}
