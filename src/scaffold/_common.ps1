#!/usr/bin/env pwsh
# Shared helpers for the LLM Wiki tool scripts. Dot-source it:
#     . "$PSScriptRoot\_common.ps1"
#
# Holds three things the rest of the pipeline depends on:
#   * Resolve-SunnyCli   - find the real sunny/opencode executable (never a shell alias)
#   * the queue manifest - .llm-wiki/queue.json, maps a queued inbox file back to the
#     raw source it came from and that source's content hash
#   * the ingest status  - .llm-wiki/ingest-status.json, written by Sunny so the archive
#     step only files away what was actually ingested

# --- CLI resolution -----------------------------------------------------------

<#
.SYNOPSIS
Resolve the sunny (or opencode) executable.

.DESCRIPTION
Only an *application* on PATH can satisfy this lookup. That matters: install-alias.ps1
defines a PowerShell function called `sunny` for driving this wiki, and PowerShell
resolves functions ahead of executables. A plain Get-Command would hand back that
function, and the tool scripts would invoke the wrapper instead of the agent CLI -
sending it the literal word "run" and nothing else. Restricting the lookup to
CommandType Application is what lets the alias and the CLI share a name safely.

Returns the full path to the executable, or $null when none is installed.
#>
function Resolve-SunnyCli {
    param([string]$Preferred = "")

    $candidates = @()
    if ($Preferred) { $candidates += $Preferred }
    $candidates += @("sunny", "opencode")

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }

        # An explicit path to an executable (e.g. -SunnyCmd "C:\path\to\sunny.exe").
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }

        $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

# Print the standard "no CLI found" guidance.
function Write-NoSunnyHelp {
    param([string]$Preferred = "sunny")
    Write-Host "Error: couldn't find an agent CLI on PATH." -ForegroundColor Red
    Write-Host "  Looked for: $Preferred, sunny, opencode (as executables)." -ForegroundColor Gray
    Write-Host "  If 'sunny' works in your shell but not here, it is a function or alias," -ForegroundColor Gray
    Write-Host "  not the CLI. Pass the real path:  -SunnyCmd 'C:\path\to\sunny.exe'" -ForegroundColor Gray
}

# --- State directory ----------------------------------------------------------

# .llm-wiki/ holds pipeline state. It is a dot-folder, so Obsidian ignores it.
function Get-StateDir {
    param([Parameter(Mandatory)][string]$WikiRoot)
    $dir = Join-Path $WikiRoot ".llm-wiki"
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        if (-not $raw -or -not $raw.Trim()) { return $null }
        return $raw | ConvertFrom-Json
    } catch {
        Write-Host "Warning: couldn't parse $Path ($($_.Exception.Message))." -ForegroundColor Yellow
        return $null
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )
    $parent = Split-Path $Path -Parent
    if ($parent -and !(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $json = $Object | ConvertTo-Json -Depth 8
    $enc  = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $enc)
}

# --- Content hashing ----------------------------------------------------------

<#
.SYNOPSIS
Short SHA-256 of a file's contents - tells an edited source from an unchanged one.

.DESCRIPTION
16 hex characters (64 bits): short enough to read in the processed.md audit table,
wide enough that an accidental collision across a personal wiki is not a real risk.
#>
function Get-ContentHash {
    param([Parameter(Mandatory)][string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    $full = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
    return $full.Substring(0, 16)
}

# --- Queue manifest (.llm-wiki/queue.json) ------------------------------------
#
# { "foo.md": { "source": "raw/reports/foo.pdf", "hash": "a1b2c3d4e5f60718",
#               "queued": "2026-11-20" }, ... }
#
# Keyed by the file's name inside inbox/. convert-all.ps1 writes it; mark-processed.ps1
# reads it to record real provenance; check-duplicate.ps1 reads it to compare hashes.

function Get-QueuePath {
    param([Parameter(Mandatory)][string]$WikiRoot)
    return (Join-Path (Get-StateDir -WikiRoot $WikiRoot) "queue.json")
}

function Read-Queue {
    param([Parameter(Mandatory)][string]$WikiRoot)
    $obj = Read-JsonFile -Path (Get-QueuePath -WikiRoot $WikiRoot)
    $map = @{}
    if ($obj) {
        foreach ($prop in $obj.PSObject.Properties) { $map[$prop.Name] = $prop.Value }
    }
    return $map
}

function Set-QueueEntry {
    param(
        [Parameter(Mandatory)][string]$WikiRoot,
        [Parameter(Mandatory)][string]$InboxName,
        [Parameter(Mandatory)][string]$SourceRelPath,
        [Parameter(Mandatory)][string]$Hash
    )
    $map = Read-Queue -WikiRoot $WikiRoot
    $map[$InboxName] = [PSCustomObject]@{
        source = $SourceRelPath
        hash   = $Hash
        queued = (Get-Date -Format "yyyy-MM-dd")
    }
    Write-JsonFile -Path (Get-QueuePath -WikiRoot $WikiRoot) -Object ([PSCustomObject]$map)
}

function Remove-QueueEntry {
    param(
        [Parameter(Mandatory)][string]$WikiRoot,
        [Parameter(Mandatory)][string]$InboxName
    )
    $map = Read-Queue -WikiRoot $WikiRoot
    if ($map.ContainsKey($InboxName)) {
        $map.Remove($InboxName)
        Write-JsonFile -Path (Get-QueuePath -WikiRoot $WikiRoot) -Object ([PSCustomObject]$map)
    }
}

# Relative path of a file under the wiki root, with forward slashes.
function Get-RelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd([char]0x5C, [char]0x2F)
    $full     = (Resolve-Path -LiteralPath $Path).Path
    if ($full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($rootFull.Length).TrimStart([char]0x5C, [char]0x2F)
    } else {
        $rel = $full
    }
    return ($rel.Replace([char]0x5C, [char]0x2F))
}

# --- The processed.md audit table ---------------------------------------------
#
# | Date | File | Source | Hash | Status | Notes |
#
# Older wikis carry the original four-column table (Date/File/Status/Notes); the
# archive step upgrades it in place the first time it writes a row.

function Get-ProcessedPath {
    param([Parameter(Mandatory)][string]$WikiRoot)
    return (Join-Path $WikiRoot "wiki/processed.md")
}

<#
.SYNOPSIS
Has this exact content already been ingested?

.DESCRIPTION
Matches on the content hash, not the filename. Renaming a source must not make it
look new, and editing one must not make it look already-done.
#>
function Test-HashIngested {
    param(
        [Parameter(Mandatory)][string]$WikiRoot,
        [Parameter(Mandatory)][string]$Hash
    )
    if (-not $Hash) { return $false }
    $path = Get-ProcessedPath -WikiRoot $WikiRoot
    if (!(Test-Path -LiteralPath $path)) { return $false }
    $content = Get-Content -LiteralPath $path -Raw
    return ($content -match [regex]::Escape($Hash))
}

# --- Ingest status (.llm-wiki/ingest-status.json) -----------------------------
#
# Written by Sunny during INGEST, one entry per queued file:
#   { "items": { "foo.md": { "status": "done", "note": "..." } } }
#
# The archive step files away only the entries marked "done". A clean CLI exit code
# means the agent finished its turn - not that every file was ingested - so the exit
# code must never be the archive signal on its own.

function Get-StatusPath {
    param([Parameter(Mandatory)][string]$WikiRoot)
    return (Join-Path (Get-StateDir -WikiRoot $WikiRoot) "ingest-status.json")
}

function Read-IngestStatus {
    param([Parameter(Mandatory)][string]$WikiRoot)
    $obj = Read-JsonFile -Path (Get-StatusPath -WikiRoot $WikiRoot)
    $map = @{}
    if ($obj -and $obj.items) {
        foreach ($prop in $obj.items.PSObject.Properties) { $map[$prop.Name] = $prop.Value }
    }
    return $map
}

# Clear the status file before a run so a stale "done" mark can't archive anything.
function Reset-IngestStatus {
    param([Parameter(Mandatory)][string]$WikiRoot)
    Write-JsonFile -Path (Get-StatusPath -WikiRoot $WikiRoot) -Object ([PSCustomObject]@{
        started = (Get-Date -Format "o")
        items   = [PSCustomObject]@{}
    })
}
