#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Lint one or more review markdown files with markdownlint, safely.
.DESCRIPTION
    Step 7a of the review orchestrator. Runs a PINNED markdownlint-cli2 with this plugin's own
    config (config/.markdownlint.jsonc) on review files, and only on review files.

    Isolation, not a denylist. markdownlint-cli2 executes code from its surroundings: any
    .markdownlint-cli2.* (even .jsonc/.yaml, via customRules / markdownItPlugins /
    outputFormatters), .markdownlint.cjs/.mjs, or a package.json "markdownlint-cli2" key in the
    folders it lints. And `npx` prefers a local node_modules/.bin or .npmrc in its working
    directory. So the script never runs in the workspace:

      1. every -ReviewFile must be an existing .md file under the workspace's reviews/ directory
         (real paths, symlinks resolved, so ../ or a link can't escape);
      2. each file is COPIED into a fresh, empty temp directory created by this script;
      3. the pinned npx runs there, with --no-globs, our --config, and literal (':') paths;
         nothing from the workspace or the review folders is visible to it;
      4. output paths are mapped back to the original file names, and with -Fix the fixed
         copies are written back over the originals;
      5. the temp directory is deleted.

    Because the workspace already allows `pwsh */companion-module-review/scripts/*`, Step 7a runs
    without a permission prompt and without any `npx` allow rule.

    Exit codes: markdownlint's own (0 = clean, 1 = lint errors), 2 = refused or bad input.
.PARAMETER ReviewFile
    One or more review markdown paths, e.g. reviews/biamp-tesira/review-biamp-tesira-v4.0.0-20261006-202001.md
.PARAMETER Fix
    Also apply markdownlint's automatic fixes (blank lines, table spacing, ...) and write them back.
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

function Fail([string]$Message) { Write-Error $Message -ErrorAction Continue; exit 2 }

$workspace = Resolve-ReviewWorkspace
$reviewsDir = Get-RealPath (Resolve-ReviewsDir $workspace)
$sep = [IO.Path]::DirectorySeparatorChar

# 1. Validate every path before touching anything.
$files = [System.Collections.Generic.List[object]]::new()
foreach ($f in $ReviewFile) {
    $candidate = if ([IO.Path]::IsPathRooted($f)) { $f } else { Join-Path (Get-Location).Path $f }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Fail "Not a file: $f" }
    $full = Get-RealPath $candidate
    if (-not $full.StartsWith($reviewsDir.TrimEnd($sep) + $sep, [StringComparison]::Ordinal)) {
        Fail "Refusing to lint a file outside the workspace's reviews/ directory: $f"
    }
    if ([IO.Path]::GetExtension($full) -ne '.md') { Fail "Not a .md file: $f" }
    $files.Add([pscustomobject]@{ Given = $f; Full = $full; SandboxRel = "$($files.Count)/$([IO.Path]::GetFileName($full))" })
}

$npxArgs = @('--yes', $MarkdownlintPackage, '--no-globs', '--config', $ConfigFile)
if ($Fix) { $npxArgs += '--fix' }
$npxArgs += @($files | ForEach-Object { ':' + $_.SandboxRel })

if ($DryRun) {
    Write-Output "(in a fresh, empty temp directory holding copies of the review files)"
    Write-Output ("npx " + ($npxArgs -join ' '))
    exit 0
}

# 2. Fresh sandbox holding only copies of the review files.
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("lint-review-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null
$sandbox = Get-RealPath $sandbox
try {
    foreach ($file in $files) {
        $dest = Join-Path $sandbox $file.SandboxRel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $file.Full -Destination $dest
    }

    # 3. Run the pinned linter inside the sandbox (no workspace config, node_modules or .npmrc).
    Push-Location $sandbox
    try {
        $output = & npx @npxArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    # 4. Report with the original file names; write -Fix results back.
    foreach ($line in $output) {
        $text = "$line"
        foreach ($file in $files) { $text = $text.Replace($file.SandboxRel, $file.Given) }
        Write-Output $text.Replace($sandbox, '<sandbox>')
    }
    if ($Fix) {
        foreach ($file in $files) {
            $fixed = Join-Path $sandbox $file.SandboxRel
            if ((Get-FileHash -LiteralPath $fixed).Hash -ne (Get-FileHash -LiteralPath $file.Full).Hash) {
                Copy-Item -LiteralPath $fixed -Destination $file.Full -Force
                Write-Output "Fixed and wrote back: $($file.Given)"
            }
        }
    }
} finally {
    # 5. Always clean up.
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
exit $code
