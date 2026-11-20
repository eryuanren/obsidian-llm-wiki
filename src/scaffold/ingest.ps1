#!/usr/bin/env pwsh
# Ingest the items queued in inbox/ into the wiki by invoking Sunny (the opencode CLI).
#
# One source per session by default: each queued file gets its own `sunny run`, so a
# long batch can't let context bloat and compaction degrade quality halfway through.
# Use -Batch for the old behaviour (one session for the whole queue).
#
# Sunny is driven through the `wiki-ingest` custom command in .opencode/commands/, so
# the procedure lives next to the wiki rather than inside this script. -Inline sends the
# full prompt instead, for a vault whose commands folder is missing.
#
# Nothing is archived here. Sunny records per-file results in
# .llm-wiki/ingest-status.json, and ./tools/mark-all-processed.ps1 files away only what
# is marked done.
#
# Usage:
#   ./tools/ingest.ps1                 # ingest everything in inbox/, one session each
#   ./tools/ingest.ps1 -File foo.md    # ingest a single queued file
#   ./tools/ingest.ps1 -Batch          # whole queue in one session
#   ./tools/ingest.ps1 -Auto           # auto-approve Sunny's file edits (unattended)
#   ./tools/ingest.ps1 -DryRun         # print what would run, don't call Sunny
#   ./tools/ingest.ps1 -SunnyCmd opencode

param(
    [string]$File,
    [switch]$Batch,
    [switch]$Inline,
    [switch]$Attach,
    [switch]$Auto,
    [switch]$DryRun,
    [string]$SunnyCmd  = "",        # explicit CLI path or name; auto-detected when empty
    [string]$WikiRoot  = "$PSScriptRoot\..",
    [string]$InboxPath = "$PSScriptRoot\..\inbox"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$WikiRoot  = (Resolve-Path $WikiRoot).Path
$InboxPath = (Resolve-Path $InboxPath).Path
$imageExts = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tif", ".tiff")

Write-Host "=== LLM Wiki - Ingest ===" -ForegroundColor Cyan

# 1. Determine which queued items to ingest.
if ($File) {
    $items = @(Get-Item -LiteralPath (Join-Path $InboxPath ([System.IO.Path]::GetFileName($File))))
} else {
    if (!(Test-Path $InboxPath)) { Write-Host "No inbox/ folder found." -ForegroundColor Red; exit 1 }
    $items = Get-ChildItem -Path $InboxPath -File | Where-Object { $_.Name -ne ".gitkeep" }
}

if (!$items -or $items.Count -eq 0) {
    Write-Host "inbox/ is empty - nothing to ingest. Run ./tools/convert-all.ps1 first." -ForegroundColor Green
    exit 0
}

Write-Host "Files to ingest ($($items.Count)):" -ForegroundColor Cyan
foreach ($i in $items) {
    $tag = if ($imageExts -contains $i.Extension.ToLower()) { "  [image]" } else { "" }
    Write-Host "  - inbox/$($i.Name)$tag"
}
Write-Host ""

# 2. Is the wiki-ingest command available? Fall back to an inline prompt if not.
$commandFile = Join-Path $WikiRoot ".opencode/commands/wiki-ingest.md"
$useCommand  = (-not $Inline) -and (Test-Path $commandFile)
if ($Inline -and (Test-Path $commandFile)) {
    Write-Host "-Inline set: sending the full prompt instead of /wiki-ingest." -ForegroundColor DarkGray
} elseif (-not $useCommand) {
    Write-Host "No .opencode/commands/wiki-ingest.md - sending the full prompt inline." -ForegroundColor Yellow
}

<#
The inline prompt, used when the custom command isn't available. It deliberately
restates only the essentials: the detailed procedure lives in the schema that Sunny
loads from the wiki root.
#>
function Get-InlinePrompt {
    param([string[]]$Names, [string[]]$ImageNames)

    $lines = @()
    foreach ($n in $Names)      { $lines += "- inbox/$n" }
    foreach ($n in $ImageNames) { $lines += "- inbox/$n (image)" }
    $fileLines = $lines -join "`n"

    $imgNote = ""
    if ($ImageNames.Count -gt 0) {
        $imgNote = "`n`nThe image item(s) above are image files in inbox/. Open each one by its" +
                   " path with your read tool to view it (you are multimodal). Treat each standalone" +
                   " image as its own source: write a source page describing what it shows (text," +
                   " data, diagram contents, key values), and embed the original with ![[filename]]" +
                   " so it can be re-examined later."
    }

    return @"
Ingest the following items into the wiki, following the INGEST workflow in the LLM Wiki
schema (.opencode/llm-wiki/schema.md, loaded from AGENTS.md).

Items:
$fileLines

For each: read it (or view it, if an image), check wiki/processed.md, write a source
page, create or update the relevant entity and concept pages, add [[links]] both ways,
update wiki/index.md, and append an entry to wiki/log.md using the documented prefix
format. Do not modify raw/.

When you finish each item, record its outcome in .llm-wiki/ingest-status.json under
items["<inbox filename>"] as {"status":"done"|"failed"|"skipped","note":"..."}, keeping
the entries already in that file. Only files you mark "done" will be archived.

Report pages created, pages updated, contradictions found, and any suggested synthesis
pages.$imgNote
"@
}

# 3. Resolve the CLI. Only a real executable will do - the `sunny` shell function from
#    install-alias.ps1 must never satisfy this lookup, or we'd call the wrapper instead
#    of the agent and hand it the literal word "run".
if (-not $DryRun) {
    $cli = Resolve-SunnyCli -Preferred $SunnyCmd
    if (-not $cli) {
        Write-NoSunnyHelp -Preferred $(if ($SunnyCmd) { $SunnyCmd } else { "sunny" })
        exit 1
    }
    Write-Host "Using CLI: $cli" -ForegroundColor DarkGray
    Write-Host ""
}

# 4. Start from a clean status file so a stale "done" can't archive anything.
if (-not $DryRun) { Reset-IngestStatus -WikiRoot $WikiRoot }

# Build the run list: one entry per session.
if ($Batch) {
    $runs = @([PSCustomObject]@{
        Title = "Ingest $($items.Count) item(s)"
        Names = @($items | ForEach-Object { $_.Name })
    })
} else {
    $runs = @($items | ForEach-Object {
        [PSCustomObject]@{ Title = "Ingest $($_.Name)"; Names = @($_.Name) }
    })
}

$failures = 0
$runIndex = 0

foreach ($run in $runs) {
    $runIndex++
    $imageNames = @($run.Names | Where-Object { $imageExts -contains ([System.IO.Path]::GetExtension($_).ToLower()) })
    $docNames   = @($run.Names | Where-Object { $imageExts -notcontains ([System.IO.Path]::GetExtension($_).ToLower()) })

    # Positional message first, flags after. `--file` takes an array, so a message
    # placed after it would be swallowed into the file list.
    if ($useCommand) {
        $message = ($run.Names -join ", ")
        $cliArgs = @("run", $message, "--command", "wiki-ingest")
    } else {
        $message = Get-InlinePrompt -Names $docNames -ImageNames $imageNames
        $cliArgs = @("run", $message)
    }

    $cliArgs += @("--title", $run.Title)
    if ($Auto) { $cliArgs += "--auto" }
    if ($Attach) {
        foreach ($img in $imageNames) { $cliArgs += @("--file", (Join-Path $InboxPath $img)) }
    }

    if ($DryRun) {
        Write-Host "----- RUN $runIndex/$($runs.Count) (dry run) -----" -ForegroundColor DarkGray
        Write-Host "sunny $($cliArgs -join ' ')"
        Write-Host ""
        continue
    }

    Write-Host "[$runIndex/$($runs.Count)] $($run.Title)" -ForegroundColor Yellow
    Push-Location $WikiRoot
    try {
        & $cli @cliArgs
        $exit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($exit -ne 0) {
        Write-Host "  Sunny exited with code $exit" -ForegroundColor Red
        $failures++
    }
    Write-Host ""
}

if ($DryRun) { exit 0 }

# 5. Report what Sunny actually recorded. The exit code alone says nothing about
#    whether a given file made it into the wiki.
$status = Read-IngestStatus -WikiRoot $WikiRoot
$doneCount = 0; $missing = @()
foreach ($item in $items) {
    $entry = $status[$item.Name]
    if ($entry -and $entry.status -eq "done") {
        $doneCount++
    } else {
        $label = if ($entry) { $entry.status } else { "no status recorded" }
        $missing += "$($item.Name) ($label)"
    }
}

Write-Host "=== Ingest finished ===" -ForegroundColor $(if ($failures -eq 0) { "Green" } else { "Yellow" })
Write-Host "Marked done by Sunny: $doneCount of $($items.Count)" -ForegroundColor White
if ($missing.Count -gt 0) {
    Write-Host "Not marked done (will NOT be archived):" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}
Write-Host ""
Write-Host "1. Review the new/updated pages in Obsidian." -ForegroundColor White
Write-Host "2. Archive what succeeded:  ./tools/mark-all-processed.ps1" -ForegroundColor White

exit $(if ($failures -gt 0) { 1 } else { 0 })
