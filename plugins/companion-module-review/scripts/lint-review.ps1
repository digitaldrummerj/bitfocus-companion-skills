#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Lint one or more review markdown files with markdownlint, safely.
.DESCRIPTION
    Step 7a of the review orchestrator. Runs a PINNED markdownlint-cli2 with this plugin's own
    config (config/.markdownlint.jsonc) on review files, and only on review files:

      - every -ReviewFile must be an existing .md file under the workspace's reviews/ directory
        (a path inside a module clone, the templates, or anywhere else is refused);
      - the review file's folders (up to the workspace root) must not contain an executable
        markdownlint config (.markdownlint-cli2.cjs/.mjs, .markdownlint.cjs/.mjs), because
        markdownlint-cli2 would run it as code;
      - files are passed as literal paths (':' prefix) with --no-globs, so nothing is expanded.

    Because the workspace already allows `pwsh */companion-module-review/scripts/*`, this script
    lets Step 7a run without a permission prompt, without a broad `npx` allow rule.

    Exit codes: markdownlint's own (0 = clean, 1 = lint errors), 2 = refused or bad input.
.PARAMETER ReviewFile
    One or more review markdown paths, e.g. reviews/biamp-tesira/review-biamp-tesira-v4.0.0-20261006-202001.md
.PARAMETER Fix
    Also apply markdownlint's automatic fixes (blank lines, table spacing, ...).
.PARAMETER DryRun
    Validate the paths and print the command that would run, without running it.
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/lint-review.ps1 -ReviewFile reviews/foo/review-foo-v1.0.0-20261008-120000.md
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/lint-review.ps1 -ReviewFile reviews/foo/review-foo-v1.0.0-20261008-120000.md -Fix
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$ReviewFile,
    [switch]$Fix,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/lib/ReviewState.ps1"

# Pinned on purpose: `npx --yes <pkg>` without a version runs whatever is newest on npm.
$MarkdownlintPackage = 'markdownlint-cli2@0.23.3'
$ConfigFile = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' 'config' '.markdownlint.jsonc')).Path

function Get-RealPath([string]$Path) {
    # Canonical path with every symlink resolved (macOS: /tmp and /var are links into /private),
    # so the inside-reviews/ check compares like with like. Falls back to GetFullPath where
    # `realpath` is unavailable (Windows).
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $IsWindows) {
        $real = & realpath -- $full 2>$null
        if ($LASTEXITCODE -eq 0 -and $real) { return ($real | Select-Object -First 1).Trim() }
    }
    return $full
}

$workspace = Resolve-ReviewWorkspace
$reviewsDir = Get-RealPath (Resolve-ReviewsDir $workspace)
$workspaceFull = Get-RealPath $workspace
$sep = [IO.Path]::DirectorySeparatorChar
$executableConfigs = @('.markdownlint-cli2.cjs', '.markdownlint-cli2.mjs', '.markdownlint.cjs', '.markdownlint.mjs')

function Fail([string]$Message) { Write-Error $Message -ErrorAction Continue; exit 2 }

$literalArgs = [System.Collections.Generic.List[string]]::new()
foreach ($f in $ReviewFile) {
    $candidate = if ([IO.Path]::IsPathRooted($f)) { $f } else { Join-Path (Get-Location).Path $f }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Fail "Not a file: $f" }

    # Real path with symlinks resolved, so a link inside reviews/ can't point somewhere else.
    $full = Get-RealPath $candidate

    if (-not $full.StartsWith($reviewsDir.TrimEnd($sep) + $sep, [StringComparison]::Ordinal)) {
        Fail "Refusing to lint a file outside the workspace's reviews/ directory: $f"
    }
    if ([IO.Path]::GetExtension($full) -ne '.md') { Fail "Not a .md file: $f" }

    # No executable markdownlint config anywhere between the file and the workspace root.
    $dir = Split-Path -Parent $full
    while ($dir -and $dir.StartsWith($workspaceFull, [StringComparison]::Ordinal)) {
        foreach ($name in $executableConfigs) {
            if (Test-Path -LiteralPath (Join-Path $dir $name)) {
                Fail "Refusing to lint: executable markdownlint config found at $(Join-Path $dir $name)"
            }
        }
        if ($dir -eq $workspaceFull) { break }
        $dir = Split-Path -Parent $dir
    }

    $literalArgs.Add(':' + $full)
}

$npxArgs = @('--yes', $MarkdownlintPackage, '--no-globs', '--config', $ConfigFile)
if ($Fix) { $npxArgs += '--fix' }
$npxArgs += $literalArgs

if ($DryRun) {
    Write-Output ("npx " + ($npxArgs -join ' '))
    exit 0
}

Push-Location $workspaceFull
try {
    & npx @npxArgs
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $code
