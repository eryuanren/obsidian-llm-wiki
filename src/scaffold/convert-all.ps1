#!/usr/bin/env pwsh
# Prepare every source in raw/ for ingest, placing the result in inbox/ (the queue).
# - Non-markdown documents are converted to markdown with markitdown.
# - Markdown files are copied as-is.
# - Image files are copied as-is (Sunny views them directly at ingest — it is multimodal).
# - raw/ is never modified (it is the immutable source of truth).
# - Items already queued (in inbox/ or processed/) are skipped.
# Usage: ./tools/convert-all.ps1 [-Force]

param(
    [string]$RawPath       = "$PSScriptRoot\..\raw",
    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed",
    [switch]$Force   # re-process even if an output already exists
)

$ErrorActionPreference = "Stop"

$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

if (!(Test-Path $InboxPath)) { New-Item -ItemType Directory -Path $InboxPath | Out-Null }

# Resolve how to invoke markitdown. Prefer the standalone 'markitdown' command; if it
# isn't on PATH (common when pip's Scripts dir isn't on PATH, e.g. after 'pip install
# --user'), fall back to 'python -m markitdown', which works whenever the package is
# importable by a Python that IS on PATH. Returns a hashtable { Exe; Pre } or $null.
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
# markitdown is only required if there are documents (non-md, non-image) to convert.
$markitdown     = Resolve-Markitdown
$haveMarkitdown = $null -ne $markitdown

# Source files = everything in raw/ except the assets folder and .gitkeep.
$files = Get-ChildItem -Path $RawPath -File | Where-Object { $_.Name -ne ".gitkeep" }

if (!$files -or $files.Count -eq 0) {
    Write-Host "No source files in raw/ to process." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($files.Count) file(s) in raw/`n" -ForegroundColor Cyan

$done = 0; $skipped = 0; $failed = 0

foreach ($file in $files) {
    $isImage = $imageExts -contains $file.Extension.ToLower()
    $isMd    = $file.Extension -ieq ".md"

    # Images and markdown keep their original name; documents become <base>.md.
    $outName = if ($isImage -or $isMd) { $file.Name } else { "$($file.BaseName).md" }
    $outFile = Join-Path $InboxPath $outName
    $already = (Test-Path $outFile) -or (Test-Path (Join-Path $ProcessedPath $outName))

    if ($already -and -not $Force) {
        Write-Host "Skip (already queued): $($file.Name)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    Write-Host "Processing: $($file.Name)" -NoNewline

    try {
        if ($isImage) {
            Copy-Item -Path $file.FullName -Destination $outFile -Force
            Write-Host "  (image queued)" -ForegroundColor Green
            $done++
        } elseif ($isMd) {
            Copy-Item -Path $file.FullName -Destination $outFile -Force
            Write-Host "  (copied)" -ForegroundColor Green
            $done++
        } else {
            if (-not $haveMarkitdown) { throw "markitdown not found on PATH and not importable via 'python -m markitdown'. Install with: pip install 'markitdown[all]'" }
            # Run markitdown without letting its stderr warnings (Python deprecation
            # notices, ffmpeg/pkg_resources chatter, etc.) trip ErrorActionPreference=Stop
            # and masquerade as a failure. Capture stderr instead of nulling it, and judge
            # success by whether a NON-EMPTY output file was produced — not the exit code.
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $mdPre  = $markitdown.Pre
            $mdOut  = & $markitdown.Exe @mdPre $file.FullName -o $outFile 2>&1
            $mdExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP

            if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 0)) {
                Write-Host "  OK" -ForegroundColor Green
                $done++
            } else {
                Write-Host "  FAILED (markitdown exit $mdExit)" -ForegroundColor Red
                if ($mdOut) { Write-Host "    $(($mdOut | Out-String).Trim())" -ForegroundColor DarkGray }
                if (Test-Path $outFile) { Remove-Item $outFile -Force }  # drop empty/partial output
                $failed++
            }
        }
    } catch {
        Write-Host "  FAILED ($($_.Exception.Message))" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Done: $done queued, $skipped skipped, $failed failed" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "`nSome conversions failed. markitdown needs format extras for PDF/DOCX/etc." -ForegroundColor Yellow
    Write-Host "Install them with:  pip install 'markitdown[all]'" -ForegroundColor Yellow
    Write-Host "Then re-run. To see the real error on one file:" -ForegroundColor Yellow
    Write-Host "  markitdown `"raw\\<file>.pdf`" -o test.md" -ForegroundColor Gray
}

if ($done -gt 0) {
    Write-Host "`nQueued in inbox/. Next: ./tools/ingest.ps1" -ForegroundColor Yellow
}
