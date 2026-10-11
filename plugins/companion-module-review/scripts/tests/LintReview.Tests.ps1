#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Self-contained tests for scripts/lint-review.ps1 (no Pester, no network).
.DESCRIPTION
    Only the path guards and the command shape are tested here, using -DryRun so markdownlint
    itself never runs: files must be .md under the workspace's reviews/ directory, and the
    pinned linter runs on sandbox copies with literal, no-glob arguments. (That a hostile
    .markdownlint-cli2.* beside a review is never executed was verified by hand: the linter
    only ever sees a fresh temp directory.)

    Run:  pwsh plugins/companion-module-review/scripts/tests/LintReview.Tests.ps1
#>

$ErrorActionPreference = 'Stop'
$lint = Join-Path $PSScriptRoot '..' 'lint-review.ps1'

$script:pass = 0; $script:fail = 0
function Ok($cond, $msg) {
    if ($cond) { $script:pass++; Write-Host "  PASS  $msg" -ForegroundColor Green }
    else       { $script:fail++; Write-Host "  FAIL  $msg" -ForegroundColor Red }
}
function Set-File($Path, $Content) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8 -NoNewline
}
function Invoke-Lint([string[]]$LintArgs) {
    $out = & pwsh -NoProfile -File $lint @LintArgs 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out | Out-String) }
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) "lintreview-$([System.IO.Path]::GetRandomFileName())"
$prevRoot = $env:COMPANION_REVIEW_ROOT
$prevCwd = $null
try {
    $ws = Join-Path $root 'workspace'
    Set-File (Join-Path $ws 'reviews/mod-a/review-mod-a-v1.0.0-20261008-000000.md') "# Review`n"
    Set-File (Join-Path $ws 'companion-modules-reviewing/companion-module-mod-a/README.md') "# Readme`n"
    Set-File (Join-Path $ws 'reviews/mod-a/notes.txt') "x"
    Set-File (Join-Path $ws 'reviews/mod-b/review-mod-b-v1.0.0-20261008-000000.md') "# Review`n"
    Set-File (Join-Path $ws 'reviews/mod-b/.markdownlint-cli2.cjs') "module.exports = {}"
    $env:COMPANION_REVIEW_ROOT = $ws
    Push-Location $ws
    # Child processes inherit the PROCESS working directory, not PowerShell's location.
    $prevCwd = [Environment]::CurrentDirectory
    [Environment]::CurrentDirectory = $ws

    Write-Host "lint-review.ps1 path guards"
    $good = Invoke-Lint @('-ReviewFile', 'reviews/mod-a/review-mod-a-v1.0.0-20261008-000000.md', '-DryRun')
    Ok ($good.Code -eq 0)                                         "a review under reviews/ is accepted"
    Ok ($good.Out -match 'markdownlint-cli2@\d+\.\d+\.\d+ ')      "…and runs a pinned markdownlint-cli2 version"
    Ok ($good.Out -match '--no-globs')                            "…with --no-globs"
    Ok ($good.Out -match ' :0/review-mod-a')                       "…passing a sandbox copy as a literal (':') path"
    Ok ($good.Out -match 'temp directory')                          "…from a fresh temp directory, not the workspace"
    Ok ($good.Out -match '--config \S*config[\\/]\.markdownlint\.jsonc') "…with the plugin's own .jsonc config"

    $fix = Invoke-Lint @('-ReviewFile', 'reviews/mod-a/review-mod-a-v1.0.0-20261008-000000.md', '-Fix', '-DryRun')
    Ok ($fix.Code -eq 0 -and $fix.Out -match '--fix')              "-Fix adds --fix"

    $clone = Invoke-Lint @('-ReviewFile', 'companion-modules-reviewing/companion-module-mod-a/README.md', '-DryRun')
    Ok ($clone.Code -eq 2 -and $clone.Out -match 'outside')        "a file inside a module clone is refused (exit 2)"

    $trav = Invoke-Lint @('-ReviewFile', 'reviews/../companion-modules-reviewing/companion-module-mod-a/README.md', '-DryRun')
    Ok ($trav.Code -eq 2)                                          "a ../ path escaping reviews/ is refused"

    $txt = Invoke-Lint @('-ReviewFile', 'reviews/mod-a/notes.txt', '-DryRun')
    Ok ($txt.Code -eq 2 -and $txt.Out -match 'Not a \.md file')    "a non-.md file is refused"

    $missing = Invoke-Lint @('-ReviewFile', 'reviews/mod-a/nope.md', '-DryRun')
    Ok ($missing.Code -eq 2)                                       "a missing file is refused"

    $exec = Invoke-Lint @('-ReviewFile', 'reviews/mod-b/review-mod-b-v1.0.0-20261008-000000.md', '-DryRun')
    Ok ($exec.Code -eq 0 -and $exec.Out -notmatch 'mod-b[\\/]\.markdownlint') "a .markdownlint-cli2.cjs beside the review doesn't matter: only the sandbox copy is linted"
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    if ($prevCwd) { [Environment]::CurrentDirectory = $prevCwd }
    $env:COMPANION_REVIEW_ROOT = $prevRoot
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}

Write-Host ""
Write-Host "$($script:pass) passed, $($script:fail) failed" -ForegroundColor ($(if ($script:fail) { 'Red' } else { 'Green' }))

if ($script:fail) { exit 1 }
