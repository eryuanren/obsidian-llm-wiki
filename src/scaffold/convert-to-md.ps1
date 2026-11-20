#!/usr/bin/env pwsh
# Prepare a single file from raw/ for ingest, placing the result in inbox/.
# Documents -> markdown via markitdown; markdown and images are copied as-is.
# Accepts a bare filename, or a path relative to raw/ (e.g. "reports/q3.pdf").
# Usage: ./tools/convert-to-md.ps1 <file-in-raw> [-Force]

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$WikiRoot      = "$PSScriptRoot\..",
    [string]$RawPath       = "$PSScriptRoot\..\raw",
    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot = (Resolve-Path $WikiRoot).Path
$RawPath  = (Resolve-Path $RawPath).Path

$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

# Resolve how to invoke markitdown: standalone command if on PATH, else 'python -m
# markitdown' (works when pip's Scripts dir isn't on PATH). Returns { Exe; Pre } or $null.
function Resolve-Markitdown {
    if (Get-Command markitdown -CommandType Application -ErrorAction SilentlyContinue) {
        return @{ Exe = "markitdown"; Pre = @() }
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($py in @("python", "py", "python3")) {
            $cmd = Get-Command $py -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) {
                & $cmd.Source -c "import markitdown" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { return @{ Exe = $cmd.Source; Pre = @("-m", "markitdown") } }
            }
        }
    } finally { $ErrorActionPreference = $prev }
    return $null
}

if (!(Test-Path $InboxPath)) { New-Item -ItemType Directory -Path $InboxPath | Out-Null }

# Resolve the source: accept either a path or a name/subpath under raw/.
$src = if (Test-Path -LiteralPath $File) { Get-Item -LiteralPath $File } else { Get-Item -LiteralPath (Join-Path $RawPath $File) }

$isImage = $imageExts -contains $src.Extension.ToLower()
$isMd    = $src.Extension -ieq ".md"
$relPath = Get-RelativePath -Root $RawPath -Path $src.FullName
$hash    = Get-ContentHash -Path $src.FullName

# A subfolder is flattened into the queue name; the real path goes in the manifest.
$dir  = [System.IO.Path]::GetDirectoryName($relPath)
$leaf = if ($isImage -or $isMd) { $src.Name } else { "$($src.BaseName).md" }
$outName = if ($dir) { (($dir -replace '[\\/]', '__') + "__" + $leaf) } else { $leaf }
$outFile = Join-Path $InboxPath $outName

if ((Test-HashIngested -WikiRoot $WikiRoot -Hash $hash) -and -not $Force) {
    Write-Host "Already ingested (same content): raw/$relPath" -ForegroundColor Yellow
    Write-Host "Use -Force to queue it again." -ForegroundColor Gray
    exit 0
}

if (((Test-Path $outFile) -or (Test-Path (Join-Path $ProcessedPath $outName))) -and -not $Force) {
    Write-Host "Already queued: $outName (use -Force to redo)" -ForegroundColor Yellow
    exit 0
}

if ($isImage) {
    Copy-Item -LiteralPath $src.FullName -Destination $outFile -Force
    Write-Host "Queued image inbox/$outName (Sunny will view it at ingest)" -ForegroundColor Green
    Set-QueueEntry -WikiRoot $WikiRoot -InboxName $outName -SourceRelPath "raw/$relPath" -Hash $hash
} elseif ($isMd) {
    Copy-Item -LiteralPath $src.FullName -Destination $outFile -Force
    Write-Host "Copied to inbox/$outName" -ForegroundColor Green
    Set-QueueEntry -WikiRoot $WikiRoot -InboxName $outName -SourceRelPath "raw/$relPath" -Hash $hash
} else {
    $markitdown = Resolve-Markitdown
    if (-not $markitdown) {
        Write-Host "Error: markitdown not found on PATH and not importable via 'python -m markitdown'. Install with: pip install 'markitdown[all]'" -ForegroundColor Red
        exit 1
    }

    # Capture stderr (don't null it) and relax EAP so markitdown's warnings don't get
    # treated as a terminating error. Success = a non-empty output file was produced.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $mdPre  = $markitdown.Pre
    $mdOut  = & $markitdown.Exe @mdPre $src.FullName -o $outFile 2>&1
    $mdExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 0)) {
        Write-Host "Converted to inbox/$outName" -ForegroundColor Green
        Set-QueueEntry -WikiRoot $WikiRoot -InboxName $outName -SourceRelPath "raw/$relPath" -Hash $hash
    } else {
        Write-Host "markitdown failed (exit $mdExit)" -ForegroundColor Red
        if ($mdOut) { Write-Host "  $(($mdOut | Out-String).Trim())" -ForegroundColor DarkGray }
        if (Test-Path $outFile) { Remove-Item $outFile -Force }
        exit 1
    }
}

Write-Host "Next: ./tools/ingest.ps1" -ForegroundColor Yellow
