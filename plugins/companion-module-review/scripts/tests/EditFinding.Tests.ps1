#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Self-contained tests for scripts/edit-finding.ps1 (no Pester, no network).
.DESCRIPTION
    Builds a small review in a temp workspace and checks that removing or moving findings
    renumbers IDs and anchors, keeps the Issues list, the Assumptions table and the Verdict in
    step, leaves code fences and prose IDs alone, and refuses bad input without writing.

    Run:  pwsh plugins/companion-module-review/scripts/tests/EditFinding.Tests.ps1
#>

$ErrorActionPreference = 'Stop'
$edit = Join-Path $PSScriptRoot '..' 'edit-finding.ps1'

$script:pass = 0; $script:fail = 0
function Ok($cond, $msg) {
    if ($cond) { $script:pass++; Write-Host "  PASS  $msg" -ForegroundColor Green }
    else       { $script:fail++; Write-Host "  FAIL  $msg" -ForegroundColor Red }
}
function Set-File($Path, $Content) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8 -NoNewline
}
function Invoke-Edit([string[]]$EditArgs) {
    $out = & pwsh -NoProfile -File $edit @EditArgs 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out | Out-String) }
}

$fixture = @'
# Review: companion-module-demo v0.1.0

| Field | Value |
| --- | --- |
| **Version** | v0.1.0 |

## Verdict: ❌ Changes Required

## ❓ Assumptions to Confirm

| # | Assumption | Based on | Affects |
| --- | --- | --- | --- |
| A1 | Only about the CI workflow | guess | [H1](#h1-ci-workflow-differs) |
| A2 | About feedbacks and M1 | guess | [H3](#h3-no-feedbacks), [M1](#m1-blank-key-hangs) |

## 📋 Issues

### Blocking

- [ ] [H1: CI workflow differs](#h1-ci-workflow-differs)
- [x] [H2: Release workflow differs](#h2-release-workflow-differs)
- [ ] [H3: No feedbacks](#h3-no-feedbacks)

### Non-blocking

- [ ] [M1: Blank key hangs](#m1-blank-key-hangs)

### Notes

- [📝 Additional Notes](#-additional-notes)

## 🟠 High

### H1: CI workflow differs

Body of H1 (see [A1](#-assumptions-to-confirm)).

### H2: Release workflow differs

Body of H2. Related to [H3](#h3-no-feedbacks).

### H3: No feedbacks

Body of H3 (see [A2](#-assumptions-to-confirm)).

```ts
// H1 inside a fence stays as is


setFeedbackDefinitions({})
```

## 🟡 Medium

### M1: Blank key hangs

Body of M1. Prior review H2 is still open. See also [H2](#h2-release-workflow-differs).

## 📝 Additional Notes

- A note.
'@

$root = Join-Path ([System.IO.Path]::GetTempPath()) "editfinding-$([System.IO.Path]::GetRandomFileName())"
$prevRoot = $env:COMPANION_REVIEW_ROOT
$prevCwd = $null
try {
    $ws = Join-Path $root 'workspace'
    $rel = 'reviews/demo/review-demo-v0.1.0-20261030-000000.md'
    $file = Join-Path $ws $rel
    New-Item -ItemType Directory -Path (Join-Path $ws 'companion-modules-reviewing') -Force | Out-Null
    $env:COMPANION_REVIEW_ROOT = $ws
    Push-Location $ws
    $prevCwd = [Environment]::CurrentDirectory
    [Environment]::CurrentDirectory = $ws

    Write-Host "edit-finding.ps1 -Remove"
    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1,H2')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0)                                                   "removing H1 and H2 succeeds"
    Ok ($t -notmatch 'CI workflow differs' -and $t -notmatch 'Release workflow differs') "…both findings are gone"
    Ok ($t -match '(?m)^### H1: No feedbacks$')                          "…H3 is renumbered H1"
    Ok ($t -match '- \[ \] \[H1: No feedbacks\]\(#h1-no-feedbacks\)')    "…the Issues item points at the new ID and anchor"
    Ok ($t -match '\| A1 \| About feedbacks and M1 \| guess \| \[H1\]\(#h1-no-feedbacks\), \[M1\]\(#m1-blank-key-hangs\) \|') "…the assumption that only affected H1 is dropped, A2 becomes A1 with the new link"
    Ok ($t -notmatch 'Only about the CI workflow')                       "…the dropped assumption's row is gone"
    Ok ($t -match '\(see \[A1\]\(#-assumptions-to-confirm\)\)')          "…[A2] links in the text become [A1]"
    Ok ($t -match '(?m)^## Verdict: ❌ Changes Required$')               "…the verdict stays Changes Required (H1 is left)"
    Ok ($t -match '// H1 inside a fence stays as is\n\n\nsetFeedback')   "…code fences are untouched, blank lines included"
    Ok ($t -match 'Prior review H2 is still open')                       "…bare IDs in prose are not rewritten"
    Ok ($r.Out -match 'mentions H2 outside a link')                      "…but they are reported as a warning"
    Ok ($t -notmatch "`n`n`n(?!setFeedback)" -and $t.EndsWith("- A note.`n")) "…no double blank lines outside fences, one trailing newline"

    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1,H2', '-DryRun')
    Ok ($r.Code -eq 0 -and $r.Out -match 'Renumbered: H3 -> H1' -and (Get-Content -LiteralPath $file -Raw) -eq $fixture) "a dry run prints the summary but doesn't write the file"

    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H2')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($t -match '- \[ \] \[H2: No feedbacks\]\(#h2-no-feedbacks\)')    "removing H2: H3 becomes H2 in Issues"
    Ok ($r.Out -match 'line \d+: links to removed finding H2')               "…a link left pointing at the removed finding is reported"
    Ok ($t -match '\[H2\]\(#h2-no-feedbacks\), \[M1\]')                   "…the Affects column follows the renumber"

    Write-Host "edit-finding.ps1 -Remove every blocking finding"
    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1,H2,H3')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($t -match '(?m)^## Verdict: ✅ Approved$')                       "the verdict becomes Approved"
    Ok ($t -notmatch '### Blocking' -and $t -notmatch '## 🟠 High')     "…the Blocking group and the empty High section are gone"
    Ok ($t -match '\| A1 \| About feedbacks and M1 \| guess \| \[M1\]\(#m1-blank-key-hangs\) \|') "…an assumption still affecting M1 is kept, minus the removed link"
    Ok ($r.Out -match 'Verdict: ✅ Approved \(was ❌ Changes Required\)')  "…and the summary says so"

    Write-Host "edit-finding.ps1 -Move"
    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Move', 'H3', '-To', 'NextRelease', '-Title', 'Add feedbacks before 1.0.0')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0)                                                   "moving H3 to Next Release succeeds"
    Ok ($t -match '(?m)^## 🔮 Next Release\n\n### NR1: Add feedbacks before 1\.0\.0$') "…it becomes NR1 with the new title"
    Ok ($t.IndexOf('## 🟡 Medium') -lt $t.IndexOf('## 🔮 Next Release') -and $t.IndexOf('## 🔮 Next Release') -lt $t.IndexOf('## 📝 Additional Notes')) "…in a new section placed after Medium and before Additional Notes"
    Ok ($t -match '### Non-blocking\n\n- \[ \] \[M1: Blank key hangs\]\(#m1-blank-key-hangs\)\n- \[ \] \[NR1: Add feedbacks before 1\.0\.0\]\(#nr1-add-feedbacks-before-100\)') "…and is listed as non-blocking with the right anchor"
    Ok ($t -match '- \[x\] \[H2: Release workflow differs\]')            "…other items keep their [x] state"
    Ok ($t -match 'Related to \[NR1\]\(#nr1-add-feedbacks-before-100\)') "…links to it elsewhere follow the move"
    Ok ($t -match '(?m)^## Verdict: ❌ Changes Required$')               "…the verdict stays Changes Required (H1 and H2 are left)"
    Ok ($r.Out -match 'Reread the moved finding')                        "…and the summary asks to reread the moved text"

    Write-Host "edit-finding.ps1 refusals"
    Set-File $file $fixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H9')
    Ok ($r.Code -eq 2 -and $r.Out -match 'No finding H9')                 "an unknown ID is refused (exit 2)"
    Ok ((Get-Content -LiteralPath $file -Raw) -eq $fixture)              "…and nothing is written"
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'X1')
    Ok ($r.Code -eq 2 -and $r.Out -match 'Not a finding ID')             "a malformed ID is refused"
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Move', 'M1', '-To', 'Medium')
    Ok ($r.Code -eq 2 -and $r.Out -match 'already in Medium')            "moving to the same severity is refused"
    Set-File (Join-Path $ws 'companion-modules-reviewing/x/review.md') $fixture
    $r = Invoke-Edit @('-ReviewFile', 'companion-modules-reviewing/x/review.md', '-Remove', 'H1')
    Ok ($r.Code -eq 2 -and $r.Out -match 'outside')                      "a file outside reviews/ is refused"
    Set-File $file ($fixture -replace '### Notes', '### Something else')
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1')
    Ok ($r.Code -eq 2 -and $r.Out -match 'layout')                       "an Issues list with an unknown layout is refused"
}
finally {
    if ($prevCwd) { [Environment]::CurrentDirectory = $prevCwd }
    Pop-Location -ErrorAction SilentlyContinue
    $env:COMPANION_REVIEW_ROOT = $prevRoot
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("{0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail) { exit 1 }
