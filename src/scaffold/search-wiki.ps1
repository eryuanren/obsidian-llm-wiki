#!/usr/bin/env pwsh
# Search the wiki for one or more terms. This is for YOU, at a prompt - Sunny has its
# own grep and should use that rather than shelling out to a weaker substring search.
#
# Every term must appear in the page (AND, case-insensitive); the matching lines are
# the ones containing any term.
#
# Usage:
#   ./tools/search-wiki.ps1 "machine learning"
#   ./tools/search-wiki.ps1 transformer attention     # pages containing both
#   ./tools/search-wiki.ps1 -Regex "\bGPT-\d"

param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Query,

    [switch]$Regex,                 # treat the terms as regular expressions
    [int]$Context = 0,              # lines of context to show around each hit
    [string]$WikiPath = "$PSScriptRoot\..\wiki"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $WikiPath)) {
    Write-Host "No wiki/ folder at $WikiPath" -ForegroundColor Red
    exit 1
}

# Resolve BEFORE comparing: the default carries a '..' segment, and an unresolved
# prefix never matches a file's full path, which is what mangled the output before.
$WikiPath = (Resolve-Path $WikiPath).Path

$patterns = @($Query | ForEach-Object { if ($Regex) { $_ } else { [regex]::Escape($_) } })

$files = Get-ChildItem -Path $WikiPath -Recurse -Include *.md -File
$results = @()
$pageHits = 0

foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if (-not $content) { continue }

    # Every term must appear somewhere in the page.
    $allPresent = $true
    foreach ($p in $patterns) {
        if ($content -notmatch "(?i)$p") { $allPresent = $false; break }
    }
    if (-not $allPresent) { continue }
    $pageHits++

    $lines = $content -split "`r?`n"
    $relPath = $file.FullName.Substring($WikiPath.Length).TrimStart([char]0x5C, [char]0x2F)
    $relPath = $relPath.Replace([char]0x5C, [char]0x2F)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $hit = $false
        foreach ($p in $patterns) { if ($lines[$i] -match "(?i)$p") { $hit = $true; break } }
        if (-not $hit) { continue }

        $from = [Math]::Max(0, $i - $Context)
        $to   = [Math]::Min($lines.Count - 1, $i + $Context)
        $text = ($lines[$from..$to] -join " / ").Trim()

        $results += [PSCustomObject]@{
            File = $relPath
            Line = $i + 1
            Text = $text
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "No pages match: $($Query -join ' + ')" -ForegroundColor Yellow
    exit 0
}

Write-Host "$($results.Count) line(s) across $pageHits page(s) for: $($Query -join ' + ')`n" -ForegroundColor Cyan
$results | Format-Table -AutoSize -Wrap
