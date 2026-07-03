#!/usr/bin/env pwsh
# Search wiki pages for a query string
# Usage: ./search-wiki.ps1 "<search term>"

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    
    [string]$WikiPath = "$PSScriptRoot\..\wiki"
)

$files = Get-ChildItem -Path $WikiPath -Recurse -Include *.md -File

$results = @()
foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match [regex]::Escape($Query)) {
        $lines = $content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match [regex]::Escape($Query)) {
                $relPath = $file.FullName.Replace($WikiPath, "").TrimStart("\")
                $results += [PSCustomObject]@{
                    File = $relPath
                    Line = $i + 1
                    Content = $lines[$i].Trim()
                }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "No matches found for '$Query'"
} else {
    Write-Host "Found $($results.Count) matches for '$Query':`n"
    $results | Format-Table -AutoSize -Wrap
}
