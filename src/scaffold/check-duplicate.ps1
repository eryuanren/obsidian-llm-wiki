#!/usr/bin/env pwsh
# Check whether a source has already been ingested.
#
# The answer is decided by CONTENT, not filename: a renamed source is still a duplicate,
# and an edited one is not. The filename is still reported, as a weaker signal.
#
# Exit 0 = new (or changed since it was ingested), exit 1 = already ingested.
# Usage: ./tools/check-duplicate.ps1 <file>        # a path, or a name/subpath under raw/

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$WikiRoot        = "$PSScriptRoot\..",
    [string]$RawPath         = "$PSScriptRoot\..\raw",
    [string]$ProcessedFolder = "$PSScriptRoot\..\processed"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot = (Resolve-Path $WikiRoot).Path

# Resolve the file: an explicit path, or something under raw/.
$target = $null
if (Test-Path -LiteralPath $File -PathType Leaf) {
    $target = (Resolve-Path -LiteralPath $File).Path
} elseif (Test-Path -LiteralPath (Join-Path $RawPath $File) -PathType Leaf) {
    $target = (Resolve-Path -LiteralPath (Join-Path $RawPath $File)).Path
}

$orig   = [System.IO.Path]::GetFileName($File)
$base   = [System.IO.Path]::GetFileNameWithoutExtension($File)
$mdName = "$base.md"

$hash = if ($target) { Get-ContentHash -Path $target } else { "" }
$hashIngested = $hash -and (Test-HashIngested -WikiRoot $WikiRoot -Hash $hash)

$inFolder = (Test-Path (Join-Path $ProcessedFolder $mdName)) -or
            (Test-Path (Join-Path $ProcessedFolder $orig))

if ($hashIngested) {
    Write-Host "DUPLICATE: this exact content has already been ingested." -ForegroundColor Red
    Write-Host "  Content hash $hash is recorded in wiki/processed.md" -ForegroundColor Gray
    Write-Host "Remove that row to re-ingest it intentionally." -ForegroundColor Yellow
    exit 1
}

if (-not $target) {
    Write-Host "Warning: couldn't find '$File' to hash - falling back to the filename." -ForegroundColor Yellow
    $content = ""
    $processedMd = Get-ProcessedPath -WikiRoot $WikiRoot
    if (Test-Path $processedMd) { $content = Get-Content -LiteralPath $processedMd -Raw }
    $inTable = $content -and (($content -match [regex]::Escape($mdName)) -or ($content -match [regex]::Escape($orig)))
    if ($inFolder -or $inTable) {
        Write-Host "DUPLICATE (by name): '$base' has already been ingested." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: '$base' has not been ingested yet." -ForegroundColor Green
    exit 0
}

if ($inFolder) {
    Write-Host "CHANGED: a file named '$mdName' is in processed/, but this content is new." -ForegroundColor Yellow
    Write-Host "  Content hash: $hash" -ForegroundColor Gray
    Write-Host "Queue it to ingest the revision - convert-all.ps1 files it as a new revision." -ForegroundColor Gray
    exit 0
}

Write-Host "OK: '$base' has not been ingested yet (hash $hash)." -ForegroundColor Green
exit 0
