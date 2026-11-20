#!/usr/bin/env pwsh
# Prepare every source in raw/ for ingest, placing the result in inbox/ (the queue).
# - raw/ is searched RECURSIVELY, so Web Clipper folders and other nested sources are
#   picked up. raw/assets/ is excluded: those are images referenced by other sources.
# - Non-markdown documents are converted to markdown with markitdown.
# - Markdown and image files are copied as-is (Sunny views images directly - it is
#   multimodal).
# - raw/ is never modified (it is the immutable source of truth).
# - Items are skipped by CONTENT HASH, not filename: renaming a source does not make it
#   look new, and editing one does not make it look already-done.
# Usage: ./tools/convert-all.ps1 [-Force]

param(
    [string]$WikiRoot      = "$PSScriptRoot\..",
    [string]$RawPath       = "$PSScriptRoot\..\raw",
    [string]$InboxPath     = "$PSScriptRoot\..\inbox",
    [string]$ProcessedPath = "$PSScriptRoot\..\processed",
    [switch]$Force   # re-queue even if the content was already ingested
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot = (Resolve-Path $WikiRoot).Path
$RawPath  = (Resolve-Path $RawPath).Path

$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

if (!(Test-Path $InboxPath)) { New-Item -ItemType Directory -Path $InboxPath | Out-Null }

# Resolve how to invoke markitdown. Prefer the standalone 'markitdown' command; if it
# isn't on PATH (common when pip's Scripts dir isn't on PATH, e.g. after 'pip install
# --user'), fall back to 'python -m markitdown', which works whenever the package is
# importable by a Python that IS on PATH. Returns a hashtable { Exe; Pre } or $null.
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
# markitdown is only required if there are documents (non-md, non-image) to convert.
$markitdown     = Resolve-Markitdown
$haveMarkitdown = $null -ne $markitdown

<#
Queue name for a raw source. A file at the top of raw/ keeps its own name; one in a
subfolder is flattened with '__' so inbox/ stays a flat work queue while the folder it
came from is still visible. The true path is recorded in .llm-wiki/queue.json either way.
#>
function Get-QueueName {
    param([string]$RelPath, [bool]$KeepExtension)
    $dir  = [System.IO.Path]::GetDirectoryName($RelPath)
    $name = if ($KeepExtension) {
        [System.IO.Path]::GetFileName($RelPath)
    } else {
        [System.IO.Path]::GetFileNameWithoutExtension($RelPath) + ".md"
    }
    if ($dir) { return (($dir -replace '[\\/]', '__') + "__" + $name) }
    return $name
}

# Source files = everything under raw/ except raw/assets/ and .gitkeep.
$assetsPath = Join-Path $RawPath "assets"
$files = Get-ChildItem -Path $RawPath -File -Recurse |
         Where-Object { $_.Name -ne ".gitkeep" } |
         Where-Object { -not $_.FullName.StartsWith($assetsPath, [StringComparison]::OrdinalIgnoreCase) }

if (!$files -or $files.Count -eq 0) {
    Write-Host "No source files in raw/ to process." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($files.Count) file(s) under raw/`n" -ForegroundColor Cyan

$done = 0; $skipped = 0; $failed = 0

foreach ($file in $files) {
    $isImage = $imageExts -contains $file.Extension.ToLower()
    $isMd    = $file.Extension -ieq ".md"
    $relPath = Get-RelativePath -Root $RawPath -Path $file.FullName
    $hash    = Get-ContentHash -Path $file.FullName

    # Already ingested? Decided by content, so an edited source comes back round again.
    if ((Test-HashIngested -WikiRoot $WikiRoot -Hash $hash) -and -not $Force) {
        Write-Host "Skip (already ingested): raw/$relPath" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    $outName = Get-QueueName -RelPath $relPath -KeepExtension ($isImage -or $isMd)
    $outFile = Join-Path $InboxPath $outName

    if ((Test-Path $outFile) -and -not $Force) {
        Write-Host "Skip (already queued): raw/$relPath" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    # Same name already archived but different content: this is a revision of an
    # ingested source. Queue it under a new name so both copies survive in processed/
    # and the agent can see it supersedes the earlier one.
    if (Test-Path (Join-Path $ProcessedPath $outName)) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($outName)
        $ext  = [System.IO.Path]::GetExtension($outName)
        $rev  = 2
        while ((Test-Path (Join-Path $ProcessedPath "$base.r$rev$ext")) -or
               (Test-Path (Join-Path $InboxPath "$base.r$rev$ext"))) { $rev++ }
        $outName = "$base.r$rev$ext"
        $outFile = Join-Path $InboxPath $outName
        Write-Host "Revision detected: raw/$relPath -> inbox/$outName" -ForegroundColor Cyan
    }

    Write-Host "Processing: raw/$relPath" -NoNewline

    try {
        if ($isImage -or $isMd) {
            Copy-Item -LiteralPath $file.FullName -Destination $outFile -Force
            Write-Host $(if ($isImage) { "  (image queued)" } else { "  (copied)" }) -ForegroundColor Green
            Set-QueueEntry -WikiRoot $WikiRoot -InboxName $outName -SourceRelPath "raw/$relPath" -Hash $hash
            $done++
        } else {
            if (-not $haveMarkitdown) { throw "markitdown not found on PATH and not importable via 'python -m markitdown'. Install with: pip install 'markitdown[all]'" }
            # Run markitdown without letting its stderr warnings (Python deprecation
            # notices, ffmpeg/pkg_resources chatter, etc.) trip ErrorActionPreference=Stop
            # and masquerade as a failure. Capture stderr instead of nulling it, and judge
            # success by whether a NON-EMPTY output file was produced - not the exit code.
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $mdPre  = $markitdown.Pre
            $mdOut  = & $markitdown.Exe @mdPre $file.FullName -o $outFile 2>&1
            $mdExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP

            if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 0)) {
                Write-Host "  OK" -ForegroundColor Green
                Set-QueueEntry -WikiRoot $WikiRoot -InboxName $outName -SourceRelPath "raw/$relPath" -Hash $hash
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
    Write-Host "  markitdown `"raw\<file>.pdf`" -o test.md" -ForegroundColor Gray
}

if ($done -gt 0) {
    Write-Host "`nQueued in inbox/. Next: ./tools/ingest.ps1" -ForegroundColor Yellow
}
