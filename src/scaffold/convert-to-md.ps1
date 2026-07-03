#!/usr/bin/env pwsh
# Prepare a single file from raw/ for ingest, placing the result in inbox/.
# Documents -> markdown via markitdown; markdown and images are copied as-is.
# Usage: ./tools/convert-to-md.ps1 <filename-in-raw> [-Force]

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$RawPath       = "$PSScriptRoot\..\raw",
    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

# Resolve how to invoke markitdown: standalone command if on PATH, else 'python -m
# markitdown' (works when pip's Scripts dir isn't on PATH). Returns { Exe; Pre } or $null.
function Resolve-Markitdown {
    if (Get-Command markitdown -ErrorAction SilentlyContinue) {
        return @{ Exe = "markitdown"; Pre = @() }
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($py in @("python", "py", "python3")) {
            $cmd = Get-Command $py -ErrorAction SilentlyContinue
            if ($cmd) {
                & $cmd.Source -c "import markitdown" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { return @{ Exe = $cmd.Source; Pre = @("-m", "markitdown") } }
            }
        }
    } finally { $ErrorActionPreference = $prev }
    return $null
}

if (!(Test-Path $InboxPath)) { New-Item -ItemType Directory -Path $InboxPath | Out-Null }

# Resolve the source: accept either a bare filename or a path.
$src = if (Test-Path $File) { Get-Item $File } else { Get-Item (Join-Path $RawPath $File) }

$isImage = $imageExts -contains $src.Extension.ToLower()
$isMd    = $src.Extension -ieq ".md"
$outName = if ($isImage -or $isMd) { $src.Name } else { "$($src.BaseName).md" }
$outFile = Join-Path $InboxPath $outName

if (((Test-Path $outFile) -or (Test-Path (Join-Path $ProcessedPath $outName))) -and -not $Force) {
    Write-Host "Already queued: $outName (use -Force to redo)" -ForegroundColor Yellow
    exit 0
}

if ($isImage) {
    Copy-Item -Path $src.FullName -Destination $outFile -Force
    Write-Host "Queued image inbox/$outName (Sunny will view it at ingest)" -ForegroundColor Green
} elseif ($isMd) {
    Copy-Item -Path $src.FullName -Destination $outFile -Force
    Write-Host "Copied to inbox/$outName" -ForegroundColor Green
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
    } else {
        Write-Host "markitdown failed (exit $mdExit)" -ForegroundColor Red
        if ($mdOut) { Write-Host "  $(($mdOut | Out-String).Trim())" -ForegroundColor DarkGray }
        if (Test-Path $outFile) { Remove-Item $outFile -Force }
        exit 1
    }
}

Write-Host "Next: ./tools/ingest.ps1" -ForegroundColor Yellow
