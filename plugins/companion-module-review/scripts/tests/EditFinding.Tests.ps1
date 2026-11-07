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

    Write-Host "edit-finding.ps1 with the Assumptions table at the end (2026-11 layout)"
    $endFixture = @"
# Review: companion-module-demo v0.2.0

| Field | Value |
| --- | --- |
| **Prior review** | v0.1.0: its CI finding is still open, see [H2](#h2-ci-workflow-differs). |

Intro: the one blocking finding, [H1](#h1-no-feedbacks), was missed before.

## Verdict: ❌ Changes Required

## ❓ Assumptions

Some findings depend on assumptions the reviewers couldn't check. They're listed in [❓ Assumptions to Confirm](#-assumptions-to-confirm) at the end of this review.

## 📋 Issues

### Blocking

- [ ] [H1: No feedbacks](#h1-no-feedbacks)
- [ ] [H2: CI workflow differs](#h2-ci-workflow-differs)

### Non-blocking

- [ ] [L1: Log is noisy](#l1-log-is-noisy)

## 🟠 High

### H1: No feedbacks

Body of H1 (see [A1](#-assumptions-to-confirm)).

### H2: CI workflow differs

Body of H2.

## 🟢 Low

### L1: Log is noisy

Body of L1.

## ❓ Assumptions to Confirm

| # | Assumption | Based on | Affects |
| --- | --- | --- | --- |
| A1 | Only about feedbacks | guess | [H1](#h1-no-feedbacks) |
"@ -replace "`r`n", "`n"
    Set-File $file $endFixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0)                                                   "removing H1 succeeds"
    Ok ($t -match 'still open, see \[H1\]\(#h1-ci-workflow-differs\)')    "…a link in the meta table above the Verdict follows the renumber (H2 -> H1)"
    Ok ($r.Out -match 'line 7: links to removed finding H1')             "…a link in the intro to the removed finding is reported, with its line"
    Ok ($t -notmatch '(?m)^## ❓ Assumptions' -and $t -notmatch 'assumptions-to-confirm') "…the last assumption is dropped, and the short ❓ Assumptions section goes with the table"
    Ok ($r.Out -match 'Assumptions section removed')                     "…and the summary says so"

    Set-File $file $endFixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Move', 'L1', '-To', 'NextRelease')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0 -and $t -match '(?m)^### NR1: Log is noisy$')      "moving L1 to Next Release succeeds"
    Ok ($t.IndexOf('## 🔮 Next Release') -lt $t.IndexOf('## ❓ Assumptions to Confirm') -and $t.IndexOf('## 🔮 Next Release') -gt $t.IndexOf('## 🟠 High')) "…the new section goes before the Assumptions table that closes the review"
    Ok ($t -match '(?m)^## ❓ Assumptions$' -and $t.TrimEnd().EndsWith('| A1 | Only about feedbacks | guess | [H1](#h1-no-feedbacks) |')) "…both Assumptions sections stay, the table still last"

    Write-Host "edit-finding.ps1 with --- dividers between sections"
    $hrFixture = @"
# Review: companion-module-demo v0.3.0

## Verdict: ❌ Changes Required

## 📋 Issues

### Blocking

- [ ] [H1: No feedbacks](#h1-no-feedbacks)
- [ ] [H2: CI workflow differs](#h2-ci-workflow-differs)

### Non-blocking

- [ ] [L1: Log is noisy](#l1-log-is-noisy)
- [ ] [NR1: Plan the v2 move](#nr1-plan-the-v2-move)

### Notes

- [📝 Additional Notes](#-additional-notes)

---

## 🟠 High

### H1: No feedbacks

Body of H1.

### H2: CI workflow differs

Body of H2.

---

## 🟢 Low

### L1: Log is noisy

Body of L1.

---

## 🔮 Next Release

### NR1: Plan the v2 move

Body of NR1.

---

## 📝 Additional Notes

- A note.
"@ -replace "`r`n", "`n"
    Set-File $file $hrFixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0)                                                   "a review with --- dividers can be edited"
    Ok ($t -match '- \[📝 Additional Notes\]\(#-additional-notes\)\n\n---\n\n## 🟠 High\n\n### H1: CI workflow differs') "…the divider after the Issues list stays"
    Ok ($t -match 'Body of H2\.\n\n---\n\n## 🟢 Low' -and $t -match 'Body of L1\.\n\n---\n\n## 🔮 Next Release') "…each section keeps its divider"

    Set-File $file $hrFixture
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Move', 'H2', '-To', 'NextRelease')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0 -and $t -match '(?m)^### NR2: CI workflow differs$') "moving the last High to Next Release succeeds"
    Ok ($t -match 'Body of NR1\.\n\n### NR2: CI workflow differs\n\nBody of H2\.\n\n---\n\n## 📝 Additional Notes') "…no divider between NR1 and NR2, one after the section"
    Ok ($t -match 'Body of H1\.\n\n---\n\n## 🟢 Low')                    "…the High section that is left still ends with its divider"
    Ok (-not ($t -match "---\n\n---"))                                   "…and no doubled dividers"

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
    Write-Host "edit-finding.ps1 keeps one-line notes in the Notes group"
    $noteLine = '- **Commit messages:** the commit messages are in Spanish. Write future commit messages in English.'
    Set-File $file ($fixture -replace "### Notes`n`n", "### Notes`n`n$noteLine`n")
    $r = Invoke-Edit @('-ReviewFile', $rel, '-Remove', 'H1')
    $t = Get-Content -LiteralPath $file -Raw
    Ok ($r.Code -eq 0 -and $t.Contains("### Notes`n`n$noteLine`n- [📝 Additional Notes](#-additional-notes)")) "a one-line note stays in the Notes group, ahead of the Additional Notes link"

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
