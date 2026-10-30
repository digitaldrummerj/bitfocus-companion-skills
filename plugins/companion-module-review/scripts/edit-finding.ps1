#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Remove findings from a review, or move one to another severity, and fix everything that
    depends on the finding IDs.
.DESCRIPTION
    Use it when the reviewer drops a finding ("remove H1") or changes its severity ("make H1 a
    Next Release item") in a review that is already written. By hand, that edit has to touch
    many places, and each one is easy to miss. This script does all of them in one pass:

      - deletes the finding's section (or moves it to the end of the target severity section,
        creating that section in the standard order when it doesn't exist yet);
      - drops a severity section that is left with no findings;
      - renumbers every finding so each section runs 1..n (H3 -> H2, ...), and rewrites every
        link that points at a renumbered finding (link text and #anchor);
      - in ❓ Assumptions to Confirm, removes links to removed findings from the "Affects"
        column, drops an assumption that no longer affects any finding, renumbers the rest
        (A1..An, including [A2](#-assumptions-to-confirm) links in the text), and drops the
        section when no assumption is left;
      - rebuilds the 📋 Issues list (Blocking / Non-blocking / Notes) from the findings,
        keeping each item's [x] state;
      - sets the Verdict from what is left: ❌ Changes Required while any Critical/High remains,
        ✅ Approved otherwise.

    It never touches bare mentions of an ID in prose ("see H2", "Prior review H1"), because
    those can refer to another review. It lists them as warnings with line numbers instead.
    A moved finding's text may still argue for its old severity; reread it.

    Only files under the workspace's reviews/ directory are accepted. Run lint-review.ps1
    afterwards.

    Exit codes: 0 = done (or dry run), 2 = refused or bad input (nothing written).
.PARAMETER ReviewFile
    The review markdown, e.g. reviews/foo/review-foo-v1.0.0-20261030-090507.md
.PARAMETER Remove
    One or more finding IDs to delete, e.g. H1 or H1,H2. IDs are the ones in the file now.
.PARAMETER Move
    One finding ID to move to another severity (with -To).
.PARAMETER To
    The target severity for -Move: Critical, High, Medium, Low, NiceToHave or NextRelease.
.PARAMETER Title
    Optional new title for the moved finding (the text after "NR1: ").
.PARAMETER DryRun
    Print the summary without writing the file.
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/edit-finding.ps1 -ReviewFile reviews/foo/review-foo-v1.0.0-20261030-090507.md -Remove H1,H2
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/edit-finding.ps1 -ReviewFile reviews/foo/review-foo-v0.1.0-20261030-090507.md -Move H1 -To NextRelease -Title "Add feedbacks before 1.0.0"
#>
[CmdletBinding(DefaultParameterSetName = 'Remove')]
param(
    [Parameter(Mandatory)][string]$ReviewFile,
    [Parameter(Mandatory, ParameterSetName = 'Remove')][string[]]$Remove,
    [Parameter(Mandatory, ParameterSetName = 'Move')][string]$Move,
    [Parameter(Mandatory, ParameterSetName = 'Move')]
    [ValidateSet('Critical', 'High', 'Medium', 'Low', 'NiceToHave', 'NextRelease')][string]$To,
    [Parameter(ParameterSetName = 'Move')][string]$Title,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/lib/ReviewState.ps1"

function Fail([string]$Message) { Write-Error $Message -ErrorAction Continue; exit 2 }

function Get-RealPath([string]$Path) {
    # Same canonicalisation as lint-review.ps1, so ../ or a symlink can't escape reviews/.
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $IsWindows) {
        $real = & realpath -- $full 2>$null
        if ($LASTEXITCODE -eq 0 -and $real) { return ($real | Select-Object -First 1).Trim() }
    }
    return $full
}

function Get-Anchor([string]$Heading) {
    # GitHub's heading anchors: lowercase, drop everything but letters, digits, marks, spaces,
    # '_' and '-', then each space becomes '-'. Emoji are dropped but the space after them stays,
    # which is why "❓ Assumptions to Confirm" is #-assumptions-to-confirm.
    $a = $Heading.ToLowerInvariant() -replace '[^\p{L}\p{N}\p{M} _-]', ''
    return $a -replace ' ', '-'
}

# Severity sections in report order. NR before N in the ID pattern so "NR1" isn't read as N.
$Severities = [ordered]@{
    C  = @{ Heading = '## 🔴 Critical'; Blocking = $true; Name = 'Critical' }
    H  = @{ Heading = '## 🟠 High'; Blocking = $true; Name = 'High' }
    M  = @{ Heading = '## 🟡 Medium'; Blocking = $false; Name = 'Medium' }
    L  = @{ Heading = '## 🟢 Low'; Blocking = $false; Name = 'Low' }
    N  = @{ Heading = '## 💡 Nice to Have'; Blocking = $false; Name = 'NiceToHave' }
    NR = @{ Heading = '## 🔮 Next Release'; Blocking = $false; Name = 'NextRelease' }
}
$Prefixes = @($Severities.Keys)
$FindingHeading = '^### (NR|C|H|M|L|N)(\d+): (.+)$'
$IdPattern = '^(NR|C|H|M|L|N)(\d+)$'
$AssumptionsHeading = '## ❓ Assumptions to Confirm'
$AssumptionsAnchor = '-assumptions-to-confirm'

# Rank of every known ## section, used to place a newly created severity section.
function Get-SectionRank([string]$Heading) {
    switch -Regex ($Heading) {
        '^## Verdict' { return 1 }
        '^## ❓' { return 2 }
        '^## 📋' { return 3 }
        '^## 🔴' { return 10 }
        '^## 🟠' { return 11 }
        '^## 🟡' { return 12 }
        '^## 🟢' { return 13 }
        '^## 💡' { return 14 }
        '^## 🔮' { return 15 }
        '^## ⚠️' { return 20 }
        '^## 📝' { return 30 }
        default { return $null }
    }
}

# --- Validate input ---------------------------------------------------------------------------

$workspace = Resolve-ReviewWorkspace
$reviewsDir = Get-RealPath (Resolve-ReviewsDir $workspace)
$sep = [IO.Path]::DirectorySeparatorChar
$candidate = if ([IO.Path]::IsPathRooted($ReviewFile)) { $ReviewFile } else { Join-Path (Get-Location).Path $ReviewFile }
if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Fail "Not a file: $ReviewFile" }
$path = Get-RealPath $candidate
if (-not $path.StartsWith($reviewsDir.TrimEnd($sep) + $sep, [StringComparison]::Ordinal)) {
    Fail "Refusing to edit a file outside the workspace's reviews/ directory: $ReviewFile"
}
if ([IO.Path]::GetExtension($path) -ne '.md') { Fail "Not a .md file: $ReviewFile" }

$requested = @(if ($PSCmdlet.ParameterSetName -eq 'Remove') { $Remove | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ } } else { $Move.Trim().ToUpperInvariant() })
foreach ($id in $requested) { if ($id -notmatch $IdPattern) { Fail "Not a finding ID: $id (expected e.g. C1, H2, M3, L1, N1, NR1)" } }
if (@($requested | Select-Object -Unique).Count -ne $requested.Count) { Fail "An ID is listed twice: $($requested -join ', ')" }

$text = [IO.File]::ReadAllText($path) -replace "`r`n", "`n"
$lines = $text.TrimEnd("`n").Split("`n")

# --- Parse: head + ## sections; findings inside severity sections ----------------------------

$head = [System.Collections.Generic.List[string]]::new()
$sections = [System.Collections.Generic.List[object]]::new()
$inFence = $false
foreach ($i in 0..($lines.Count - 1)) {
    $line = $lines[$i]
    if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence }
    if (-not $inFence -and $line -match '^## ') {
        $sections.Add([pscustomobject]@{ Heading = $line; Lines = [System.Collections.Generic.List[object]]::new() })
        continue
    }
    $entry = [pscustomobject]@{ Text = $line; LineNo = $i + 1; InFence = ($inFence -or $line -match '^\s*(```|~~~)') }
    if ($sections.Count -eq 0) { $head.Add($line) } else { $sections[$sections.Count - 1].Lines.Add($entry) }
}

$findings = [System.Collections.Generic.List[object]]::new()
foreach ($s in $sections) {
    $prefix = @($Prefixes | Where-Object { $Severities[$_].Heading -eq $s.Heading.TrimEnd() }) | Select-Object -First 1
    $s | Add-Member -NotePropertyName Prefix -NotePropertyValue $prefix
    $s | Add-Member -NotePropertyName Findings -NotePropertyValue ([System.Collections.Generic.List[object]]::new())
    if (-not $prefix) { continue }
    $current = $null
    foreach ($e in $s.Lines) {
        if (-not $e.InFence -and $e.Text -match $FindingHeading) {
            if ($Matches[1] -ne $prefix) { Fail "Line $($e.LineNo): $($Matches[1])$($Matches[2]) sits in the '$($s.Heading)' section" }
            $current = [pscustomobject]@{
                OldId = "$($Matches[1])$($Matches[2])"; Prefix = $prefix; Title = $Matches[3]
                OldAnchor = Get-Anchor "$($Matches[1])$($Matches[2]): $($Matches[3])"
                Body = [System.Collections.Generic.List[object]]::new(); NewId = $null; NewAnchor = $null; Removed = $false
            }
            $s.Findings.Add($current); $findings.Add($current)
        } elseif ($current) {
            $current.Body.Add($e)
        } elseif ($e.Text.Trim()) {
            Fail "Line $($e.LineNo): text between '$($s.Heading)' and its first finding; edit this review by hand"
        }
    }
}

foreach ($id in $requested) {
    $hits = @($findings | Where-Object OldId -eq $id)
    if ($hits.Count -eq 0) { Fail "No finding $id in $ReviewFile (found: $(($findings.OldId) -join ', '))" }
    if ($hits.Count -gt 1) { Fail "Finding $id appears more than once in $ReviewFile" }
}

$issues = @($sections | Where-Object { $_.Heading -match '^## 📋' })
if ($issues.Count -ne 1) { Fail "Expected one '## 📋 Issues' section, found $($issues.Count)" }
$checked = @{}
foreach ($e in $issues[0].Lines) {
    $t = $e.Text
    if (-not $t.Trim() -or $t -match '^### (Blocking|Non-blocking|Notes)\s*$' -or $t -match '^- \[📝 Additional Notes\]') { continue }
    if ($t -match '^- \[([ xX])\] \[(NR|C|H|M|L|N)(\d+): ') { $checked["$($Matches[2])$($Matches[3])"] = ($Matches[1] -ne ' '); continue }
    Fail "Line $($e.LineNo): the 📋 Issues list has a layout this script doesn't know ('$t'); edit this review by hand"
}

$verdict = @($sections | Where-Object { $_.Heading -match '^## Verdict' })
if ($verdict.Count -ne 1) { Fail "Expected one '## Verdict' line, found $($verdict.Count)" }

# --- Apply the edit ---------------------------------------------------------------------------

$summary = [System.Collections.Generic.List[string]]::new()
if ($PSCmdlet.ParameterSetName -eq 'Remove') {
    foreach ($id in $requested) {
        $f = $findings | Where-Object OldId -eq $id
        $f.Removed = $true
        ($sections | Where-Object { $_.Findings -contains $f }).Findings.Remove($f) | Out-Null
    }
    $summary.Add("Removed: $($requested -join ', ')")
} else {
    $target = @($Prefixes | Where-Object { $Severities[$_].Name -eq $To })[0]
    $f = $findings | Where-Object OldId -eq $requested[0]
    if ($f.Prefix -eq $target) { Fail "$($f.OldId) is already in $To" }
    ($sections | Where-Object { $_.Findings -contains $f }).Findings.Remove($f) | Out-Null
    $f.Prefix = $target
    if ($Title) { $f.Title = $Title.Trim() }
    $dest = $sections | Where-Object Prefix -eq $target | Select-Object -First 1
    if (-not $dest) {
        $dest = [pscustomobject]@{ Heading = $Severities[$target].Heading; Lines = $null; Prefix = $target; Findings = [System.Collections.Generic.List[object]]::new() }
        $rank = Get-SectionRank $dest.Heading
        $at = $sections.Count
        for ($k = 0; $k -lt $sections.Count; $k++) {
            $r = Get-SectionRank $sections[$k].Heading
            if ($null -ne $r -and $r -gt $rank) { $at = $k; break }
        }
        $sections.Insert($at, $dest)
    }
    $dest.Findings.Add($f)
    $summary.Add("Moved: $($f.OldId) to $To")
}

# Renumber every severity section 1..n and work out the new anchors.
foreach ($s in $sections) {
    if (-not $s.Prefix) { continue }
    for ($k = 0; $k -lt $s.Findings.Count; $k++) {
        $f = $s.Findings[$k]
        $f.NewId = "$($s.Prefix)$($k + 1)"
        $f.NewAnchor = Get-Anchor "$($f.NewId): $($f.Title)"
    }
}
$renamed = @($findings | Where-Object { -not $_.Removed -and $_.NewId -ne $_.OldId } | ForEach-Object { "$($_.OldId) -> $($_.NewId)" })
if ($renamed) { $summary.Add("Renumbered: $($renamed -join ', ')") }

$byOldAnchor = @{}
foreach ($f in $findings) { $byOldAnchor[$f.OldAnchor] = $f }
$removedAnchors = @($findings | Where-Object Removed | ForEach-Object OldAnchor)

# Assumptions: drop links to removed findings, then rows that affect nothing, then renumber.
$assumptionMap = @{}
$droppedAssumptions = [System.Collections.Generic.List[string]]::new()
$assumptions = $sections | Where-Object { $_.Heading.TrimEnd() -eq $AssumptionsHeading } | Select-Object -First 1
if ($assumptions) {
    $kept = [System.Collections.Generic.List[object]]::new()
    $n = 0
    foreach ($e in $assumptions.Lines) {
        if ($e.Text -match '^\|\s*A(\d+)\s*\|' -and $e.Text -match '^(.*\|)([^|]*)\|\s*$') {
            $oldA = "A$([regex]::Match($e.Text, '^\|\s*A(\d+)').Groups[1].Value)"
            $prefix = $Matches[1]; $cell = $Matches[2]
            $links = @([regex]::Matches($cell, '\[[^\]]*\]\(#([^)]+)\)'))
            $keep = @($links | Where-Object { $removedAnchors -notcontains $_.Groups[1].Value } | ForEach-Object Value)
            if ($links.Count -gt 0 -and $keep.Count -eq 0) { $droppedAssumptions.Add($oldA); $assumptionMap[$oldA] = $null; continue }
            $n++
            $assumptionMap[$oldA] = "A$n"
            $newCell = if ($links.Count -gt 0) { ' ' + ($keep -join ', ') + ' ' } else { $cell }
            $row = ($prefix -replace '^\|\s*A\d+\s*\|', "| A$n |") + $newCell + '|'
            $kept.Add([pscustomobject]@{ Text = $row; LineNo = $e.LineNo; InFence = $false })
        } else {
            $kept.Add($e)
        }
    }
    $assumptions.Lines = $kept
    if ($droppedAssumptions.Count) { $summary.Add("Assumptions dropped (affected only removed findings): $($droppedAssumptions -join ', ')") }
    $aRenamed = @($assumptionMap.GetEnumerator() | Where-Object { $_.Value -and $_.Value -ne $_.Key } | Sort-Object Key | ForEach-Object { "$($_.Key) -> $($_.Value)" })
    if ($aRenamed) { $summary.Add("Assumptions renumbered: $($aRenamed -join ', ')") }
    if ($n -eq 0) { [void]$sections.Remove($assumptions); $summary.Add("Assumptions section removed (none left)") }
}

# --- Rewrite links, collect warnings ---------------------------------------------------------

$warnings = [System.Collections.Generic.List[string]]::new()
$changedIds = @($findings | Where-Object { $_.Removed -or $_.NewId -ne $_.OldId } | ForEach-Object OldId) + @($assumptionMap.GetEnumerator() | Where-Object { $_.Value -ne $_.Key } | ForEach-Object Key)

function Update-Line($Entry) {
    if ($Entry.InFence) { return $Entry.Text }
    $t = [regex]::Replace($Entry.Text, '\[([^\]]*)\]\(#([^)]+)\)', {
            param($m)
            $label = $m.Groups[1].Value; $anchor = $m.Groups[2].Value
            if ($anchor -eq $AssumptionsAnchor -and $label -match '^A\d+$' -and $assumptionMap.ContainsKey($label)) {
                if (-not $assumptionMap[$label]) { $warnings.Add("line $($Entry.LineNo): links to dropped assumption $label"); return $m.Value }
                return "[$($assumptionMap[$label])](#$anchor)"
            }
            $f = $byOldAnchor[$anchor]
            if (-not $f) { return $m.Value }
            if ($f.Removed) { $warnings.Add("line $($Entry.LineNo): links to removed finding $($f.OldId)"); return $m.Value }
            $newLabel = if ($label -eq $f.OldId) { $f.NewId } elseif ($label.StartsWith("$($f.OldId):")) { $f.NewId + $label.Substring($f.OldId.Length) } else { $label }
            return "[$newLabel](#$($f.NewAnchor))"
        })
    # Bare IDs in prose may point at another review: warn, never rewrite.
    $prose = [regex]::Replace($Entry.Text, '\[[^\]]*\]\([^)]*\)', '') -replace '^\|\s*A\d+\s*\|', '|' -replace '`[^`]*`', ''
    foreach ($m in [regex]::Matches($prose, '\b(NR\d+|[CHMLN]\d+|A\d+)\b')) {
        if ($changedIds -contains $m.Value) { $warnings.Add("line $($Entry.LineNo): mentions $($m.Value) outside a link; check it by hand") }
    }
    return $t
}

$out = [System.Collections.Generic.List[string]]::new()
foreach ($l in $head) { $out.Add($l) }
$hasNotes = [bool]($sections | Where-Object { $_.Heading -match '^## 📝' })
$remaining = @($sections | Where-Object Prefix | ForEach-Object { $_.Findings } | Where-Object { $_ })
$blocking = @($remaining | Where-Object { $Severities[$_.Prefix].Blocking })
$nonBlocking = @($remaining | Where-Object { -not $Severities[$_.Prefix].Blocking })
$oldVerdict = $verdict[0].Heading
$newVerdict = if ($blocking.Count) { '## Verdict: ❌ Changes Required' } else { '## Verdict: ✅ Approved' }
if ($oldVerdict.TrimEnd() -ne $newVerdict) { $summary.Add("Verdict: $($newVerdict -replace '^## Verdict: ', '') (was $($oldVerdict -replace '^## Verdict: ', ''))") }

function Format-Item($f) {
    $box = if ($checked[$f.OldId]) { 'x' } else { ' ' }
    return "- [$box] [$($f.NewId): $($f.Title)](#$($f.NewAnchor))"
}

foreach ($s in $sections) {
    if ($s.Prefix -and $s.Findings.Count -eq 0) { continue }
    if ($s.Heading -match '^## Verdict') { $out.Add($newVerdict); $out.Add(''); continue }
    $out.Add($s.Heading); $out.Add('')
    if ($s.Heading -match '^## 📋') {
        if ($blocking.Count) { $out.Add('### Blocking'); $out.Add(''); $blocking | ForEach-Object { $out.Add((Format-Item $_)) }; $out.Add('') }
        if ($nonBlocking.Count) { $out.Add('### Non-blocking'); $out.Add(''); $nonBlocking | ForEach-Object { $out.Add((Format-Item $_)) }; $out.Add('') }
        if ($hasNotes) { $out.Add('### Notes'); $out.Add(''); $out.Add('- [📝 Additional Notes](#-additional-notes)'); $out.Add('') }
        continue
    }
    if ($s.Prefix) {
        foreach ($f in $s.Findings) {
            $out.Add("### $($f.NewId): $($f.Title)")
            $body = @($f.Body | ForEach-Object { Update-Line $_ })
            while ($body.Count -and -not $body[-1].Trim()) { $body = @($body | Select-Object -SkipLast 1) }
            foreach ($b in $body) { $out.Add($b) }
            $out.Add('')
        }
        continue
    }
    $body = @($s.Lines | ForEach-Object { Update-Line $_ })
    while ($body.Count -and -not $body[0].Trim()) { $body = @($body | Select-Object -Skip 1) }
    foreach ($b in $body) { $out.Add($b) }
    $out.Add('')
}

# No double blank lines outside code fences (MD012); exactly one trailing newline (MD047).
$final = [System.Collections.Generic.List[string]]::new()
$inFence = $false
foreach ($l in $out) {
    if ($l -match '^\s*(```|~~~)') { $inFence = -not $inFence }
    if (-not $inFence -and -not $l.Trim() -and $final.Count -and -not $final[$final.Count - 1].Trim()) { continue }
    $final.Add($l)
}
while ($final.Count -and -not $final[$final.Count - 1].Trim()) { $final.RemoveAt($final.Count - 1) }
$result = ($final -join "`n") + "`n"

$summary | ForEach-Object { Write-Output $_ }
$warnings | Select-Object -Unique | ForEach-Object { Write-Output "Warning: $_" }
if ($PSCmdlet.ParameterSetName -eq 'Move') { Write-Output "Reread the moved finding: its text may still argue for its old severity." }
if ($DryRun) { Write-Output '(dry run: file not changed)'; exit 0 }
[IO.File]::WriteAllText($path, $result, [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $ReviewFile. Run lint-review.ps1 on it next."
exit 0
