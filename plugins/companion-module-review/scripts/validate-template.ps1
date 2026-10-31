#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Deterministic template-compliance validator for a Companion module.
.DESCRIPTION
    Performs the mechanical portion of the companion-template-compliance review against
    the official JS/TS template: required files, config-file parity, package.json /
    manifest.json field rules, HELP.md stub detection, husky (TS), no package-lock.json,
    and "gitignored files must not be committed". Optionally runs the build and lint.

    This is the part of a review that does NOT need an LLM — it is exact, repeatable, and
    cheap. The reviewer is left only with judgment calls (is HELP.md meaningful). tsconfig
    differences are reported as Info TSCONFIG-DIFF notes, never blocking.

    The official template repo is the authoritative reference, selected by API version ×
    language, via Get-TemplateSuffix: API 2.1+ modules use companion-module-template-{js|ts}
    (main), API 2.0 modules the "-v2.0.4"-suffixed clone, and v1 modules the "-v1"-suffixed
    clone. A missing pinned clone is an error (exit 2), never a silent fallback to main.
    Templates are auto-detected under COMPANION_TEMPLATES_DIR
    (default companion-module-templates/ inside the repo), or passed via -TemplateDir.

    BEFORE comparing anything, the local template clone is verified against its upstream
    with a read-only `git ls-remote` — no fetch, no pull, nothing written. A clone that is
    behind upstream would judge the module against outdated expectations and produce false
    findings, so it is a blocking TEMPLATE-STALE. Templates are NEVER auto-updated here:
    concurrent review sessions share these clones, so refreshing is a separate, deliberate
    act (scripts/update-templates.ps1). The pinned clones ("-v1", "-v2.0.4") sit in detached
    HEAD by design and are exempt.

    Which files get compared is derived from the template's own tracked files
    (`git ls-files`) minus module-owned paths, so a file newly added upstream is compared
    automatically instead of waiting for someone to edit a list in this script. A template
    file matching no rule still gets compared, and raises an informational
    TEMPLATE-COVERAGE so the gap can't go silent.

    One exception: .yarnrc.yml is repo tooling rather than API surface, and Bitfocus only
    updates it on main, so it is always compared against the main (unsuffixed) template when
    one exists — and by parsed key, not raw text (key order, quote style, and blank lines are
    not divergences; a missing/extra key or a conflicting value is).
.PARAMETER ModuleDir
    Path to the cloned module under review.
.PARAMETER TemplateDir
    Path to the matching template repo. Auto-detected by API version × language if omitted.
.PARAMETER ExpectedVersion
    The git tag under review (with or without leading 'v'). Enables the package.json
    version-match check. Skipped if omitted.
.PARAMETER RunBuild
    Also run `yarn install --immutable` + `yarn package` (and `yarn lint` for TS) and gate
    on success. Slow and requires network; off by default.
.PARAMETER SkipTemplateFreshness
    Skip the upstream freshness check (deliberate offline runs). Equivalent to setting
    COMPANION_SKIP_TEMPLATE_FRESHNESS=1.
.PARAMETER Json
    Emit findings as JSON instead of a console report.
.OUTPUTS
    Exit codes: 0 clean · 1 one or more Critical findings · 2 unusable -ModuleDir or no
    template found · 3 the template clone is stale or could not be verified.
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/validate-template.ps1 -ModuleDir ../companion-modules-reviewing/companion-module-foo
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/validate-template.ps1 -ModuleDir ./mod -ExpectedVersion v1.2.0 -RunBuild -Json
#>

param(
    [Parameter(Mandatory)][string]$ModuleDir,
    [string]$TemplateDir,
    [string]$ExpectedVersion,
    [switch]$RunBuild,
    [switch]$SkipTemplateFreshness,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/lib/ReviewState.ps1"

if (-not (Test-Path $ModuleDir)) { Write-Error "ModuleDir not found: $ModuleDir" -ErrorAction Continue; exit 2 }
$ModuleDir = (Resolve-Path $ModuleDir).Path

# ── Findings accumulator ─────────────────────────────────────────────────────
$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param(
        [string]$Id,
        [ValidateSet('Critical','High','Medium','Info')][string]$Severity,
        [string]$File,
        [string]$Message
    )
    $findings.Add([pscustomobject]@{ id = $Id; severity = $Severity; file = $File; message = $Message })
}

# ── Detect JS vs TS ──────────────────────────────────────────────────────────
$pkgPath = Join-Path $ModuleDir 'package.json'
$pkg = $null
if (Test-Path $pkgPath) {
    try { $pkg = Get-Content -Raw -LiteralPath $pkgPath | ConvertFrom-Json }
    catch { Add-Finding 'PKG-PARSE' 'Critical' 'package.json' "Not valid JSON: $($_.Exception.Message)" }
}

function Has-Prop { param($Obj, [string]$Name) $Obj -and ($Obj.PSObject.Properties.Name -contains $Name) }

# Language detection lives in lib/ReviewState.ps1 (Test-ModuleIsTypeScript) so this script
# and module-facts.ps1 share one rule: TS = tsconfig.json OR .ts sources — NOT a `typescript`
# devDependency (a typescript-eslint peer on plain-JS modules) and NOT package.json "type": "module".
$isTs = Test-ModuleIsTypeScript $ModuleDir
$lang = if ($isTs) { 'TS' } else { 'JS' }
$langLower = $lang.ToLower()

# Detect the @companion-module/base version. The API LEVEL picks the template (Get-TemplateSuffix):
# 1.x → the pinned "-v1" clone, 2.0 → the pinned "-v2.0.4" clone (base 2.0.4 / node22), 2.1+ →
# main (base 2.1 / node26 since 2026-10-08). The runtime check below also uses the level: each
# API level allows only its own template's runtime (2.0 -> node22, 2.1+ -> node26).
$baseInfo   = Resolve-CompanionBaseVersion $ModuleDir
$apiMajor   = $baseInfo.major
$apiVer     = "v$apiMajor"
$apiProfile = Get-CompanionApiProfile -ApiLevel $baseInfo.apiLevel

# The module's manifest runtime is needed before §2 (the tsconfig allowance depends on it),
# so it's read here; §5 still owns parsing errors and all MAN-* findings.
$modRuntimeType = $null
try {
    $mp = Join-Path $ModuleDir 'companion/manifest.json'
    if (Test-Path $mp) {
        $mj = Get-Content -Raw -LiteralPath $mp | ConvertFrom-Json
        if ((Has-Prop $mj 'runtime') -and (Has-Prop $mj.runtime 'type')) { $modRuntimeType = [string]$mj.runtime.type }
    }
} catch { }

# ── Resolve template dir by version × language ───────────────────────────────
# Templates live in companion-module-templates/ inside the repo (override:
# COMPANION_TEMPLATES_DIR). Pinned API generations use a suffix ("-v1", "-v2.0.4"); main has none.
$tplSuffix = Get-TemplateSuffix -ApiLevel $baseInfo.apiLevel
$tplName   = "companion-module-template-$langLower$tplSuffix"
if (-not $TemplateDir) {
    # The scripts live in the companion-module-review plugin, so the templates are found
    # relative to the WORKSPACE (the repo this is run from), unless COMPANION_TEMPLATES_DIR is set.
    $ws = Resolve-ReviewWorkspace -Optional
    $base = if ($env:COMPANION_TEMPLATES_DIR) { $env:COMPANION_TEMPLATES_DIR } elseif ($ws) { Resolve-TemplatesDir $ws } else { $null }
    if ($base) {
        $candidate = Join-Path $base $tplName
        if (Test-Path $candidate) { $TemplateDir = $candidate }
    }
}
if (-not $TemplateDir -or -not (Test-Path $TemplateDir)) {
    # Never fall back to main for a pinned generation: the wrong template means false findings.
    Write-Error "Template '$tplName' ($lang, API $($baseInfo.apiLevel)) not found. Run setup.ps1 in your companion-module-review workspace to create the template clones in companion-module-templates/ (pinned ones included), or set COMPANION_REVIEW_ROOT / COMPANION_TEMPLATES_DIR, or pass -TemplateDir." -ErrorAction Continue
    exit 2
}
$TemplateDir = (Resolve-Path $TemplateDir).Path

# .yarnrc.yml is repo tooling, not API-versioned — Bitfocus updates it on main only, so a
# module judged against a pinned template ("-v1", "-v2.0.4") still gets the current (main)
# template's yarnrc rather than the pinned clone's stale copy. Falls back to $TemplateDir
# when there's no sibling to use.
$yarnrcTemplateDir = $TemplateDir
if ($TemplateDir -match '-v\d[\d.]*$') {
    $sibling = $TemplateDir -replace '-v\d[\d.]*$',''
    if (Test-Path (Join-Path $sibling '.yarnrc.yml')) { $yarnrcTemplateDir = $sibling }
}

# ── 0. Template freshness — MUST run before any comparison ───────────────────
# Ordering is load-bearing: a clone that is behind upstream produces false CONFIG-DIFF /
# FILE-MISSING / PKG-DEVDEP findings against a module that is actually correct (this has
# happened — see reviews/roland-v1-4k, where a pre-hardening .yarnrc.yml clone flagged the
# module's correct `enableScripts: false` as an extra line). Establishing "the reference is
# current" first is what makes every finding below trustworthy.
#
# Strictly read-only: `git ls-remote` against the configured origin. Nothing is fetched,
# pulled, or written — several review sessions share these clones and an automatic update
# would change the reference underneath a review already in progress.
$freshnessChecks = [System.Collections.Generic.List[object]]::new()
$seenTplDirs = [System.Collections.Generic.HashSet[string]]::new()

# The check set is every clone whose contents feed an expectation:
#   - the matched template;
#   - the yarnrc source, which for a pinned (v1 / 2.0) module is the main sibling (see above);
#   - one hop through a pinned clone's local origin, since setup.ps1 clones the pinned
#     folders from the main clone — that parent is the thing that can actually fall behind GitHub.
$freshnessTargets = @($TemplateDir, $yarnrcTemplateDir)
$tplInfo = Get-GitRepoInfo -Dir $TemplateDir
if ($tplInfo.IsRepo -and $tplInfo.Detached -and $tplInfo.OriginIsLocalDir) {
    $freshnessTargets += $tplInfo.OriginLocalPath
}
foreach ($dir in $freshnessTargets) {
    if (-not $dir) { continue }
    $key = try { (Resolve-Path -LiteralPath $dir -ErrorAction Stop).Path } catch { $dir }
    if (-not $seenTplDirs.Add($key)) { continue }

    $fr = Test-TemplateFreshness -TemplateDir $dir -SkipCheck:$SkipTemplateFreshness

    # A directory that isn't a git clone can't be verified. That only matters for the
    # templates this script resolved itself — an explicitly passed -TemplateDir pointing at a
    # plain copy or a test fixture is a deliberate choice, not an unverifiable production
    # reference, so it stays silent.
    if ($fr.status -eq 'unmanaged' -and -not $PSBoundParameters.ContainsKey('TemplateDir')) {
        $fr.status = 'unverified'
    }
    $freshnessChecks.Add($fr)

    if ($fr.status -eq 'stale') {
        Add-Finding 'TEMPLATE-STALE' 'Critical' $fr.leaf (
            "Local template clone is behind upstream — this review would be judged against an " +
            "outdated template. $($fr.message) Refresh explicitly (templates are NEVER " +
            "auto-updated): pwsh $PSScriptRoot/update-templates.ps1 — do this between review " +
            "sessions, not during one, then re-run the review.")
    } elseif ($fr.status -eq 'unverified') {
        Add-Finding 'TEMPLATE-UNVERIFIED' 'Critical' $fr.leaf (
            "Could not verify the template clone against upstream ($($fr.message)). A review " +
            "must attest which template revision it judged against. For a deliberate offline " +
            "run pass -SkipTemplateFreshness or set COMPANION_SKIP_TEMPLATE_FRESHNESS=1.")
    }
}
$freshnessStatuses = @($freshnessChecks | ForEach-Object { $_.status })
$freshnessOverall =
    if ($freshnessStatuses -contains 'stale')       { 'stale' }
    elseif ($freshnessStatuses -contains 'unverified') { 'unverified' }
    elseif ($freshnessStatuses -contains 'skipped')    { 'skipped' }
    elseif ($freshnessStatuses -contains 'fresh')      { 'fresh' }
    elseif ($freshnessStatuses -contains 'pinned')     { 'pinned' }
    else                                               { 'unmanaged' }

# Load the template's package.json + manifest so expectations are derived from the
# actual matched template (version-correct) rather than hardcoded.
$tplPkg = $null; $tplMan = $null
$tplPkgPath = Join-Path $TemplateDir 'package.json'
if (Test-Path $tplPkgPath) { try { $tplPkg = Get-Content -Raw -LiteralPath $tplPkgPath | ConvertFrom-Json } catch { } }
$tplManPath = Join-Path $TemplateDir 'companion/manifest.json'
if (Test-Path $tplManPath) { try { $tplMan = Get-Content -Raw -LiteralPath $tplManPath | ConvertFrom-Json } catch { } }

# The Node major the template runs on (manifest runtime.type "node26" -> 26). Every place a module
# names its Node version must follow it: manifest runtime.type, package.json engines.node and
# @types/node, the tsconfig.build.json preset and node-version in the workflows. §5b reports every
# place that is off in ONE NODE-VERSION finding, so §2 and §5 don't also report those lines. A
# runtime NEWER than the template's (node26 on an API 2.0 module) is a different problem (the base
# is too old for it): MAN-RUNTIME says so, and the NODE-VERSION check is skipped.
function Get-NodeMajor { param([string]$Text) if ("$Text" -match '(\d+)') { return [int]$Matches[1] } return $null }
$nodeTarget = $null
if ($tplMan -and (Has-Prop $tplMan 'runtime') -and (Has-Prop $tplMan.runtime 'type') -and "$($tplMan.runtime.type)" -match '^node(\d+)$') {
    $nodeTarget = [int]$Matches[1]
    if ("$modRuntimeType" -match '^node(\d+)$' -and [int]$Matches[1] -gt $nodeTarget) { $nodeTarget = $null }
}
$nodeVersionRe = '^(\s*#?\s*-?\s*)node-version:\s*(.*)$'
$nodeStepNameRe = '^(\s*#?\s*-?\s*name:\s*Use Node\.js\s+)(\S+)\s*$'   # the template's "- name: Use Node.js 26.x" step
$tsPresetRe    = '"@companion-module/tools/tsconfig/node(\d+)/[^"]*"'
function Get-TemplateTsPreset {
    $f = Join-Path $TemplateDir 'tsconfig.build.json'
    if (-not (Test-Path $f)) { return $null }
    $m = [regex]::Match((Get-Content -Raw -LiteralPath $f), $tsPresetRe)
    if ($m.Success) { return $m.Value } else { return $null }
}
$tplTsPreset = Get-TemplateTsPreset

# ── 1. Required files ────────────────────────────────────────────────────────
# Only files that are required REGARDLESS of what the template happens to track live here.
# Everything else (.gitattributes, .gitignore, .prettierignore, .yarnrc.yml, and the TS-only
# eslint.config.mjs / tsconfig*.json / .husky/pre-commit) is derived from the template's own
# file list in §2 — which also gets the JS-vs-TS split right for free, since the JS template
# genuinely tracks no .husky/ or tsconfig.
#
# yarn.lock is the reason this list can't just be "whatever the template tracks": the v2
# templates deliberately don't commit one, but every module must ship one. The remaining four
# ARE template-tracked, but their contents are judged by their own dedicated sections below
# (LICENSE-DIFF, PKG-*, MAN-*, HELP-STUB), so they appear here for the presence check only.
#
# Entry-point filename is NOT hard-required — it may differ from the template (e.g. src/index.js).
# Its validity is enforced by the package.json main / manifest runtime.entrypoint checks below
# (existence + consistency) plus the -RunBuild build step.
$requiredExtra = @('yarn.lock','LICENSE','package.json','companion/manifest.json','companion/HELP.md')
foreach ($rel in $requiredExtra) {
    if (-not (Test-Path (Join-Path $ModuleDir $rel))) {
        Add-Finding 'FILE-MISSING' 'Critical' $rel 'Required file is missing'
    }
}

# package-lock.json must NOT exist
if (Test-Path (Join-Path $ModuleDir 'package-lock.json')) {
    Add-Finding 'NPM-LOCK' 'Critical' 'package-lock.json' 'Present — module must use yarn, not npm (automatic rejection)'
}

# ── 2. Config-file parity vs template (normalized) ───────────────────────────
function Read-NormalizedLines {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    $text = Get-Content -Raw -LiteralPath $Path
    if ($null -eq $text) { return @() }
    $lines = @($text -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
    # drop trailing empty lines
    $i = $lines.Count - 1
    while ($i -ge 0 -and $lines[$i] -eq '') { $i-- }
    if ($i -lt 0) { return @() }
    return @($lines[0..$i])
}

function Get-FirstLineDiff {
    # Describe the first line where two normalized files diverge, in the phrasing the
    # config-parity and LICENSE checks both report. Returns '' if they are identical.
    param([string[]]$ModuleLines, [string[]]$TemplateLines)
    $max = [math]::Max($ModuleLines.Count, $TemplateLines.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $m = if ($i -lt $ModuleLines.Count) { $ModuleLines[$i] } else { '<missing>' }
        $t = if ($i -lt $TemplateLines.Count) { $TemplateLines[$i] } else { '<missing>' }
        if ($m -ne $t) { return "line $($i+1): found '$m', template '$t'" }
    }
    return ''
}

function Normalize-TsconfigLine {
    # The template ships a commented-out jest hint in the compilerOptions "types"
    # array: ["node" /* , "jest" ] // uncomment this if using jest */]. Deleting that
    # dead comment (leaving ["node"]) is an accepted divergence, not a CONFIG-DIFF — so
    # strip inline comments and normalize bracket spacing before comparing tsconfig lines.
    #
    # Comments are only stripped OUTSIDE string literals: a glob like "src/**/*.ts" contains
    # "/**/" and a URL contains "//", and neither is a comment.
    param([string]$Line)
    $sb = [System.Text.StringBuilder]::new()
    $inString = $false
    $i = 0
    while ($i -lt $Line.Length) {
        $ch = $Line[$i]
        $next = if ($i + 1 -lt $Line.Length) { $Line[$i + 1] } else { [char]0 }
        if ($inString) {
            [void]$sb.Append($ch)
            if ($ch -eq '\' -and $i + 1 -lt $Line.Length) { [void]$sb.Append($next); $i += 2; continue }
            if ($ch -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($ch -eq '"') { $inString = $true; [void]$sb.Append($ch); $i++; continue }
        if ($ch -eq '/' -and $next -eq '*') {           # inline block comment (incl. the jest hint)
            $end = $Line.IndexOf('*/', $i + 2)
            if ($end -lt 0) { break }                    # unterminated on this line: drop the rest
            $i = $end + 2
            continue
        }
        if ($ch -eq '/' -and $next -eq '/') { break }   # trailing line comment
        [void]$sb.Append($ch)
        $i++
    }
    $l = $sb.ToString() -replace '\s*\]', ']'           # collapse whitespace before a closing bracket
    return $l.TrimEnd()
}

function ConvertTo-CanonicalJson {
    # Key-order-independent JSON text for deep comparison of parsed tsconfig values.
    param($Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $sorted = [ordered]@{}
        foreach ($k in @($Value.Keys | Sort-Object)) { $sorted[$k] = ConvertTo-CanonicalJson $Value[$k] }
        return ($sorted | ConvertTo-Json -Compress -Depth 20)
    }
    if ($Value -is [System.Collections.IList]) {
        return '[' + ((@($Value) | ForEach-Object { ConvertTo-CanonicalJson $_ }) -join ',') + ']'
    }
    return ($Value | ConvertTo-Json -Compress -Depth 20)
}

function Test-TsconfigDevScope {
    <# Is tsconfig.json's divergence from the template ONLY the accepted dev-scope widening?

       tsconfig.json is the editor/typecheck config; the build uses tsconfig.build.json, which
       stays an exact match. Modules that ship tests (vitest/jest) legitimately widen
       tsconfig.json so the tests and the test-runner config are type-checked too:
         - extra `include` entries (tests/**/*.ts, scripts/**/*.ts, vitest.config.ts, …)
         - extra `exclude` entries
         - extra `compilerOptions.types` entries (vitest/globals, jest, …)
         - `compilerOptions.rootDir` (widened to ./ so tests/ sit inside it) and `noEmit`
       Everything the template sets must still be present with the same value. Anything else
       — a different `extends`, a changed or new compiler option, an extra top-level key — is
       a real divergence and stays a CONFIG-DIFF.

       Returns Acceptable, Extras (what was widened, for the Info note), Reason (why not). #>
    param([Parameter(Mandatory)][string]$ModuleFile, [Parameter(Mandatory)][string]$TemplateFile)

    $res = [pscustomobject]@{ Acceptable = $false; Extras = @(); Reason = $null }
    try {
        $mod = Get-Content -Raw -LiteralPath $ModuleFile | ConvertFrom-Json -AsHashtable
        $tpl = Get-Content -Raw -LiteralPath $TemplateFile | ConvertFrom-Json -AsHashtable
    } catch {
        $res.Reason = "could not parse as JSON ($($_.Exception.Message))"
        return $res
    }
    if ($mod -isnot [System.Collections.IDictionary] -or $tpl -isnot [System.Collections.IDictionary]) {
        $res.Reason = 'not a JSON object'
        return $res
    }

    $extras = [System.Collections.Generic.List[string]]::new()
    $listKeys = @('include', 'exclude')
    $allowedExtraCompilerOptions = @('rootDir', 'noEmit')

    foreach ($k in @($mod.Keys)) {
        if (-not $tpl.Contains($k)) { $res.Reason = "extra top-level key '$k'"; return $res }
    }
    foreach ($k in @($tpl.Keys)) {
        if (-not $mod.Contains($k)) { $res.Reason = "missing template key '$k'"; return $res }
        if ($listKeys -contains $k) {
            $have = @($mod[$k] | ForEach-Object { "$_" })
            $want = @($tpl[$k] | ForEach-Object { "$_" })
            $missing = @($want | Where-Object { $have -notcontains $_ })
            if ($missing.Count -gt 0) { $res.Reason = "$k is missing template entries: $($missing -join ', ')"; return $res }
            foreach ($e in @($have | Where-Object { $want -notcontains $_ })) { $extras.Add("$k += $e") }
            continue
        }
        if ($k -eq 'compilerOptions' -and $mod[$k] -is [System.Collections.IDictionary] -and $tpl[$k] -is [System.Collections.IDictionary]) {
            $mco = $mod[$k]; $tco = $tpl[$k]
            foreach ($ok in @($tco.Keys)) {
                if (-not $mco.Contains($ok)) { $res.Reason = "compilerOptions.$ok is missing"; return $res }
                if ($ok -eq 'types') {
                    $have = @($mco[$ok] | ForEach-Object { "$_" })
                    $want = @($tco[$ok] | ForEach-Object { "$_" })
                    $missing = @($want | Where-Object { $have -notcontains $_ })
                    if ($missing.Count -gt 0) { $res.Reason = "compilerOptions.types is missing: $($missing -join ', ')"; return $res }
                    foreach ($e in @($have | Where-Object { $want -notcontains $_ })) { $extras.Add("types += $e") }
                    continue
                }
                if ((ConvertTo-CanonicalJson $mco[$ok]) -ne (ConvertTo-CanonicalJson $tco[$ok])) {
                    $res.Reason = "compilerOptions.$ok differs"; return $res
                }
            }
            foreach ($ok in @($mco.Keys | Where-Object { -not $tco.Contains($_) })) {
                if ($allowedExtraCompilerOptions -notcontains $ok) { $res.Reason = "extra compilerOptions.$ok"; return $res }
                $extras.Add("compilerOptions.$ok = $(ConvertTo-CanonicalJson $mco[$ok])")
            }
            continue
        }
        if ((ConvertTo-CanonicalJson $mod[$k]) -ne (ConvertTo-CanonicalJson $tpl[$k])) {
            $res.Reason = "'$k' differs"; return $res
        }
    }
    $res.Acceptable = $true
    $res.Extras = @($extras)
    return $res
}

function Remove-JsComments {
    # Strip // and /* */ comments from JS source while leaving string contents alone, so the
    # eslint-config comparison below isn't thrown by explanatory comments in an override.
    param([string]$Text)
    $sb = [System.Text.StringBuilder]::new()
    $i = 0; $n = $Text.Length; $quote = $null
    while ($i -lt $n) {
        $c = $Text[$i]
        if ($quote) {
            [void]$sb.Append($c)
            if ($c -eq '\' -and $i + 1 -lt $n) { [void]$sb.Append($Text[$i + 1]); $i += 2; continue }
            if ($c -eq $quote) { $quote = $null }
            $i++; continue
        }
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') { $quote = $c; [void]$sb.Append($c); $i++; continue }
        if ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '/') {
            while ($i -lt $n -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '*') {
            $end = $Text.IndexOf('*/', $i + 2)
            $i = if ($end -lt 0) { $n } else { $end + 2 }
            continue
        }
        [void]$sb.Append($c); $i++
    }
    return $sb.ToString()
}

function Hide-JsStrings {
    # Replace the contents of JS string literals with spaces, keeping every index the same,
    # so pattern searches only ever match real code.
    param([string]$Text)
    $chars = $Text.ToCharArray()
    $quote = $null
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $c = $chars[$i]
        if ($quote) {
            if ($c -eq '\' -and $i + 1 -lt $chars.Length) { $chars[$i] = ' '; $chars[$i + 1] = ' '; $i++; continue }
            if ($c -eq $quote) { $quote = $null; continue }
            if ($c -ne "`n") { $chars[$i] = ' ' }
            continue
        }
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') { $quote = $c }
    }
    return -join $chars
}

function Split-JsTopLevel {
    # Split the inside of a JS array/object literal on commas at nesting depth 0.
    param([string]$Text)
    $parts = [System.Collections.Generic.List[string]]::new()
    $depth = 0; $quote = $null; $start = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($quote) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq $quote) { $quote = $null }
            continue
        }
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') { $quote = $c; continue }
        if ('([{'.Contains($c)) { $depth++; continue }
        if (')]}'.Contains($c)) { $depth--; continue }
        if ($c -eq ',' -and $depth -eq 0) { $parts.Add($Text.Substring($start, $i - $start).Trim()); $start = $i + 1 }
    }
    $last = $Text.Substring($start).Trim()
    if ($last) { $parts.Add($last) }
    return @($parts | Where-Object { $_ })
}

function Get-JsBracketBody {
    # Given text and the index of an opening bracket, return what lies between it and its
    # matching close (string-aware), or $null if unbalanced.
    param([string]$Text, [int]$OpenIndex)
    $open = $Text[$OpenIndex]
    $close = switch ($open) { '[' { ']' } '{' { '}' } '(' { ')' } }
    $depth = 0; $quote = $null
    for ($i = $OpenIndex; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($quote) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq $quote) { $quote = $null }
            continue
        }
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') { $quote = $c; continue }
        if ($c -eq $open) { $depth++ }
        elseif ($c -eq $close) { $depth--; if ($depth -eq 0) { return $Text.Substring($OpenIndex + 1, $i - $OpenIndex - 1) } }
    }
    return $null
}

function Test-EslintTestScope {
    <# Is eslint.config.mjs's divergence from the template ONLY test-scoped overrides?

       Modules that ship tests usually relax a couple of rules for test files (e.g.
       n/no-unpublished-import for vitest imports, unbound-method for vi.fn() assertions).
       Doing that requires turning the template's

           export default generateEslintConfig({ …options… })

       into

           const baseConfig = await generateEslintConfig({ …same options… })
           export default [ ...baseConfig, { files: ['tests/**/*.ts'], rules: { … } } ]

       Accepted ONLY when: the template's import lines are all present and no others are added;
       the generateEslintConfig options are identical; the base config is spread first; and every
       extra entry is an object whose `files` globs are all test/tooling paths, using only the
       keys files / rules / languageOptions / name. So nothing can change how the module's own
       src/ code is linted. Anything else stays a CONFIG-DIFF. #>
    param([Parameter(Mandatory)][string]$ModuleFile, [Parameter(Mandatory)][string]$TemplateFile)

    $res = [pscustomobject]@{ Acceptable = $false; Extras = @(); Reason = $null }
    $mod = Remove-JsComments (Get-Content -Raw -LiteralPath $ModuleFile)
    $tpl = Remove-JsComments (Get-Content -Raw -LiteralPath $TemplateFile)
    $squash = { param($s) ($s -replace '\s+', ' ').Trim() -replace ',\s*([}\]])', '$1' }

    # Template must be the plain `export default generateEslintConfig({...})` shape.
    $tplCall = [regex]::Match($tpl, 'export\s+default\s+generateEslintConfig\s*\(')
    if (-not $tplCall.Success) { $res.Reason = 'template eslint config has an unexpected shape'; return $res }
    $tplOpts = Get-JsBracketBody $tpl ($tplCall.Index + $tplCall.Length - 1)

    # Imports: exactly the template's.
    $importsOf = { param($s) @([regex]::Matches($s, '(?m)^\s*import\s[^\n]*') | ForEach-Object { & $squash $_.Value } | Sort-Object) }
    $tplImports = & $importsOf $tpl
    $modImports = & $importsOf $mod
    if (($tplImports -join "`n") -ne ($modImports -join "`n")) { $res.Reason = 'imports differ from the template'; return $res }

    # const <name> = await generateEslintConfig({ same options })
    $modCall = [regex]::Match($mod, '(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:await\s+)?generateEslintConfig\s*\(')
    if (-not $modCall.Success) { $res.Reason = 'generateEslintConfig result is not assigned to a variable'; return $res }
    $baseVar = $modCall.Groups[1].Value
    $modOpts = Get-JsBracketBody $mod ($modCall.Index + $modCall.Length - 1)
    if ($null -eq $modOpts -or (& $squash $modOpts) -ne (& $squash $tplOpts)) { $res.Reason = 'generateEslintConfig options differ from the template'; return $res }

    # export default [ ...<name>, {test-scoped override}, … ]  — or the equivalent
    # `const <cfg> = [ … ]` + `export default <cfg>`.
    $spans = [System.Collections.Generic.List[object]]::new()
    $constOpen = $modCall.Index + $modCall.Length - 1
    $spans.Add(@($modCall.Index, ($constOpen + $modOpts.Length + 2)))
    $exp = [regex]::Match($mod, 'export\s+default\s*\[')
    if ($exp.Success) {
        $arrOpen = $exp.Index + $exp.Length - 1
        $arr = Get-JsBracketBody $mod $arrOpen
        if ($null -eq $arr) { $res.Reason = 'unbalanced export default array'; return $res }
        $spans.Add(@($exp.Index, ($arrOpen + $arr.Length + 2)))
    } else {
        $expId = [regex]::Match($mod, 'export\s+default\s+([A-Za-z_$][\w$]*)\s*;?')
        if (-not $expId.Success) { $res.Reason = 'export default is not an array'; return $res }
        $decl = [regex]::Match($mod, "(?:const|let)\s+$([regex]::Escape($expId.Groups[1].Value))\s*=\s*\[")
        if (-not $decl.Success) { $res.Reason = "export default $($expId.Groups[1].Value) is not an array literal"; return $res }
        $arrOpen = $decl.Index + $decl.Length - 1
        $arr = Get-JsBracketBody $mod $arrOpen
        if ($null -eq $arr) { $res.Reason = 'unbalanced exported array'; return $res }
        $spans.Add(@($decl.Index, ($arrOpen + $arr.Length + 2)))
        $spans.Add(@($expId.Index, ($expId.Index + $expId.Length)))
    }

    # Nothing else may sit at the top level besides the imports, the base config and the
    # exported array: cut those spans out by position (later first) and require only
    # whitespace/';' to remain.
    $rest = $mod
    foreach ($span in @($spans | Sort-Object { $_[0] } -Descending)) {
        $rest = $rest.Substring(0, $span[0]) + $rest.Substring([math]::Min($span[1], $rest.Length))
    }
    $rest = [regex]::Replace($rest, '(?m)^\s*import\s[^\n]*', '')
    if (($rest -replace '[\s;]', '') -ne '') { $res.Reason = 'extra top-level code besides the base config and overrides'; return $res }

    $items = @(Split-JsTopLevel $arr)
    if ($items.Count -lt 1 -or $items[0] -ne "...$baseVar") { $res.Reason = "the base config (...$baseVar) is not spread first"; return $res }

    $testGlob = '^(\./)?((tests?|__tests__|__mocks__|spec|specs|scripts)/|[^/]*\.config\.(c|m)?(js|ts)$)|\.(test|spec)\.(c|m)?(js|ts)x?$'
    $allowedKeys = @('files', 'rules', 'languageOptions', 'name')
    $extras = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($items | Select-Object -Skip 1)) {
        if (-not $item.StartsWith('{')) { $res.Reason = "override '$((& $squash $item))' is not an object literal"; return $res }
        $body = Get-JsBracketBody $item 0
        $props = @(Split-JsTopLevel $body)
        $keys = @($props | ForEach-Object { if ($_ -match '^[''"]?([A-Za-z_$][\w$]*)[''"]?\s*:') { $Matches[1] } else { '<' + (& $squash $_) + '>' } })
        $bad = @($keys | Where-Object { $allowedKeys -notcontains $_ })
        if ($bad.Count -gt 0) { $res.Reason = "override uses non-test-scoped key(s): $($bad -join ', ')"; return $res }
        $filesProp = @($props | Where-Object { $_ -match '^[''"]?files[''"]?\s*:' }) | Select-Object -First 1
        if (-not $filesProp) { $res.Reason = 'override has no files: scope, so it would apply to src/'; return $res }
        $globs = @([regex]::Matches($filesProp, '''([^'']*)''|"([^"]*)"') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } })
        if ($globs.Count -eq 0) { $res.Reason = 'override files: has no string globs'; return $res }
        $notTest = @($globs | Where-Object { $_ -notmatch $testGlob })
        if ($notTest.Count -gt 0) { $res.Reason = "override targets non-test files: $($notTest -join ', ')"; return $res }
        $extras.Add("files [$($globs -join ', ')]")
    }
    $res.Acceptable = $true
    $res.Extras = @($extras)
    return $res
}

function Test-EslintExtendsTemplate {
    <# Does eslint.config.mjs still build on the template's config, only ADDING to it?

       Reviewers accept a module that keeps the template's generateEslintConfig call and layers
       its own setup on top: extra imports (typescript-eslint, a plugin such as
       simple-import-sort), extra options passed to generateEslintConfig (ignores, …), and extra
       config blocks before or after the base config (disableTypeChecked for vitest.config.ts,
       parserOptions.project, plugin rules, src/ overrides). Those are the module's choice.

       Still a CONFIG-DIFF: the template's imports are not all there; generateEslintConfig is not
       called; one of the template's own options is missing or changed (enableTypescript: false);
       or the generated config is not part of what is exported. #>
    param([Parameter(Mandatory)][string]$ModuleFile, [Parameter(Mandatory)][string]$TemplateFile)

    $res = [pscustomobject]@{ Acceptable = $false; Extras = @(); Reason = $null }
    $mod = Remove-JsComments (Get-Content -Raw -LiteralPath $ModuleFile)
    $tpl = Remove-JsComments (Get-Content -Raw -LiteralPath $TemplateFile)
    $squash = { param($s) ($s -replace '\s+', ' ').Trim() -replace ',\s*([}\]])', '$1' }
    # Same text with string contents blanked (same length), so a call, spread or export that
    # only appears inside a string literal can't satisfy the checks below.
    $modCode = Hide-JsStrings $mod

    $tplCall = [regex]::Match($tpl, 'generateEslintConfig\s*\(')
    if (-not $tplCall.Success) { $res.Reason = 'template eslint config has an unexpected shape'; return $res }
    $tplArgs = Get-JsBracketBody $tpl ($tplCall.Index + $tplCall.Length - 1)

    # Imports: every template import must still be there; extra ones are the module's own.
    $importsOf = { param($s) @([regex]::Matches($s, '(?m)^\s*import\s[^\n]*') | ForEach-Object { & $squash $_.Value }) }
    $tplImports = @(& $importsOf $tpl)
    $modImports = @(& $importsOf $mod)
    $missingImports = @($tplImports | Where-Object { $modImports -notcontains $_ })
    if ($missingImports.Count -gt 0) { $res.Reason = "template import missing: $($missingImports -join '; ')"; return $res }
    $extraImports = @($modImports | Where-Object { $tplImports -notcontains $_ } |
        ForEach-Object { if ($_ -match 'from\s+[''"]([^''"]+)[''"]') { $Matches[1] } else { $_ } })

    $modCalls = [regex]::Matches($modCode, '\bgenerateEslintConfig\s*\(')
    if ($modCalls.Count -eq 0) { $res.Reason = "does not use the template's generateEslintConfig"; return $res }
    if ($modCalls.Count -gt 1) { $res.Reason = 'calls generateEslintConfig more than once'; return $res }
    $modCall = $modCalls[0]
    $modArgs = Get-JsBracketBody $mod ($modCall.Index + $modCall.Length - 1)
    if ($null -eq $modArgs) { $res.Reason = 'unbalanced generateEslintConfig call'; return $res }

    # Options: every option the template passes must be passed unchanged; extra options are fine.
    $propsOf = {
        param($argText)
        $t = $argText.Trim()
        if (-not $t.StartsWith('{')) { return @() }
        @(Split-JsTopLevel (Get-JsBracketBody $t 0) | ForEach-Object { & $squash $_ })
    }
    $keyOf = { param($p) if ($p -match '^[''"]?([A-Za-z_$][\w$]*)[''"]?\s*:') { $Matches[1] } else { $p } }
    $tplProps = @(& $propsOf $tplArgs)
    $modProps = @(& $propsOf $modArgs)
    if ($modArgs.Trim() -and -not $modArgs.Trim().StartsWith('{')) { $res.Reason = 'generateEslintConfig options are not an object literal'; return $res }
    # A spread or a repeated key could override a template option after the checked copy.
    $spreadProps = @($modProps | Where-Object { $_.StartsWith('...') })
    if ($spreadProps.Count -gt 0) { $res.Reason = "generateEslintConfig options use a spread ($($spreadProps -join ', '))"; return $res }
    $dupKeys = @($modProps | ForEach-Object { & $keyOf $_ } | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($dupKeys.Count -gt 0) { $res.Reason = "generateEslintConfig options repeat a key ($($dupKeys -join ', '))"; return $res }
    $changed = @($tplProps | Where-Object { $modProps -notcontains $_ })
    if ($changed.Count -gt 0) { $res.Reason = "changes the template's generateEslintConfig options ($($changed -join ', '))"; return $res }
    $tplKeys = @($tplProps | ForEach-Object { & $keyOf $_ })
    $extraOptions = @($modProps | ForEach-Object { & $keyOf $_ } | Where-Object { $tplKeys -notcontains $_ })

    # The generated config must be what is exported, or spread into it.
    $direct = [regex]::IsMatch($modCode, 'export\s+default\s+(?:await\s+)?generateEslintConfig\s*\(')
    $blocks = $false
    # Spread straight into the exported array: `export default [ ...(await generateEslintConfig({…})), {…} ]`.
    # The call must sit inside that array, and its whole result must be spread (nothing such as
    # `.slice(0, 0)` applied to it after the call).
    $inline = $false
    if (-not $direct -and [regex]::IsMatch($modCode.Substring(0, $modCall.Index), '\.\.\.\s*(\(\s*)?(?:await\s+)?$')) {
        $exp = [regex]::Match($modCode, 'export\s+default\s+\[')
        if ($exp.Success) {
            $arrOpen = $exp.Index + $exp.Length - 1
            $arrBody = Get-JsBracketBody $modCode $arrOpen
            $callClose = $modCall.Index + $modCall.Length + $modArgs.Length
            $inArray = ($null -ne $arrBody) -and ($modCall.Index -gt $arrOpen) -and ($callClose -lt $arrOpen + 1 + $arrBody.Length)
            $after = $modCode.Substring($callClose + 1)
            $inline = $inArray -and [regex]::IsMatch($after, '^\s*\)?\s*[,\]]')
        }
    }
    if ($inline) { $blocks = $true }
    elseif (-not $direct) {
        $assign = [regex]::Match($modCode.Substring(0, $modCall.Index + $modCall.Length), '(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:await\s+)?generateEslintConfig\s*\($')
        if (-not $assign.Success) { $res.Reason = 'generateEslintConfig result is neither exported nor assigned'; return $res }
        $name = [regex]::Escape($assign.Groups[1].Value)
        # The whole config must be spread or exported: `...base.slice(0, 0)` or
        # `export default base.filter(…)` would keep the name but drop its contents.
        $spread = [regex]::IsMatch($modCode, "\.\.\.\s*$name\b(?!\s*[.\[(])")
        $exported = [regex]::IsMatch($modCode, "export\s+default\s+$name\b(?!\s*[.\[(])")
        if (-not ($spread -or $exported)) { $res.Reason = "the generated config ($($assign.Groups[1].Value)) is not part of the exported config"; return $res }
        $blocks = $spread
    }

    $extras = [System.Collections.Generic.List[string]]::new()
    if ($extraImports.Count -gt 0) { $extras.Add("imports $($extraImports -join ', ')") }
    if ($extraOptions.Count -gt 0) { $extras.Add("generateEslintConfig options $($extraOptions -join ', ')") }
    if ($blocks) { $extras.Add('extra config blocks') }
    $res.Acceptable = $true
    $res.Extras = @($extras)
    return $res
}

function Read-YarnrcMap {
    # .yarnrc.yml is a flat, two-level file in practice (scalars plus the occasional
    # block sequence such as npmPreapprovedPackages), so a small hand-rolled parser is
    # enough and keeps this script dependency-free. Comparing parsed keys instead of raw
    # text means key order, quote style, and blank lines never produce a CONFIG-DIFF.
    param([string]$Path)
    $map = [ordered]@{}
    if (-not (Test-Path $Path)) { return $map }
    $text = Get-Content -Raw -LiteralPath $Path
    if ($null -eq $text) { return $map }

    function Get-Scalar {
        param([string]$Value)
        $v = $Value.Trim()
        if ($v.Length -ge 2) {
            $q = $v[0]
            if (($q -eq '"' -or $q -eq "'") -and $v[-1] -eq $q) { $v = $v.Substring(1, $v.Length - 2) }
        }
        return $v
    }

    $seq = @{}          # key -> list of sequence items
    $currentKey = $null
    foreach ($raw in ($text -split "`r?`n")) {
        $line = $raw -replace '\s+#.*$', ''      # trailing comment
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }
        if ($line -match '^\s+-\s*(.+)$') {
            if ($currentKey -and $seq.ContainsKey($currentKey)) { $seq[$currentKey] += ,(Get-Scalar $Matches[1]) }
            continue
        }
        if ($line -match '^(\S[^:]*):\s*(.*)$') {
            $currentKey = $Matches[1].Trim()
            $value = $Matches[2]
            if ($value.Trim() -eq '') {
                $seq[$currentKey] = @()          # block key; items follow
                $map[$currentKey] = ''
            } else {
                $map[$currentKey] = Get-Scalar $value
            }
        }
    }
    # Sequences compare as a sorted set, so item order doesn't matter either.
    foreach ($k in @($seq.Keys)) {
        $map[$k] = '[' + ((@($seq[$k]) | Sort-Object) -join ', ') + ']'
    }
    return $map
}

function Get-TemplateTrackedFiles {
    # The set of files to compare is the template's own tracked file list, not a list
    # maintained by hand in this script — so a config file Bitfocus adds upstream is compared
    # on the next review instead of silently going unchecked until someone notices.
    param([Parameter(Mandatory)][string]$Dir)

    $tracked = Invoke-GitRead @('-C', $Dir, 'ls-files')
    if ($null -ne $tracked -and $tracked -ne '') {
        return @($tracked -split "`r?`n" | Where-Object { $_ } | Sort-Object -Unique)
    }
    # Not a git clone (a plain copy, or a test fixture): fall back to walking the tree.
    $root = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
    $files = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName.Substring($root.Length + 1) -replace '\\', '/' } |
        Where-Object { $_ -notlike '.git/*' -and $_ -notlike 'node_modules/*' })
    return @($files | Sort-Object -Unique)
}

# How each template-tracked path is judged. FIRST MATCH WINS, so order matters.
#   exact             byte-for-byte after whitespace normalization
#   workflow          exact, except that companion-module-checks.yaml may enable upload-artifact
#   tsconfig          compared after stripping comments (the template's jest hint is optional), but a
#                     difference is only an Info TSCONFIG-DIFF note — any tsconfig is fine as long as the
#                     module builds (-RunBuild reports a failed build). A MISSING tsconfig stays Critical.
#   gitignore-subset  every template entry must be present; module extras are fine
#   yarnrc            parsed key/value comparison, sourced from the v2 template
#   covered-elsewhere a dedicated section below owns this file's content
#   module-owned      legitimately differs per module; never compared
#   presence          must exist (FILE-MISSING when absent), but its content is the module's own
#   skip-binary       not text; a line diff would be meaningless
# Optional per-row flags:
#   MissingSeverity   severity of FILE-MISSING when it differs from a content CONFIG-DIFF
#   IgnoreComments    drop '#' comment lines (and blank lines) from both sides before comparing
#   IgnoreIndent      compare with leading whitespace stripped, so re-indenting alone is clean
# A path matching NO row is still compared (as 'exact') but raises TEMPLATE-COVERAGE, so a
# newly-added template file can never slip through unjudged.
$templateFileRules = @(
    @{ Pattern = '.yarnrc.yml';             Kind = 'yarnrc';           Severity = 'Critical'; Source = 'yarnrc' }
    @{ Pattern = '.gitignore';              Kind = 'gitignore-subset'; Severity = 'Critical' }
    @{ Pattern = 'tsconfig*.json';          Kind = 'tsconfig';         Severity = 'Critical' }
    # Comment lines explaining the rule are fine, and so are extra `<pattern> binary` rules that
    # mark file types as binary; only the template's rule itself must match.
    @{ Pattern = '.gitattributes';          Kind = 'exact';            Severity = 'Critical'; IgnoreComments = $true }
    # Extra entries for generated files are fine, but only the reviewer can tell what is
    # generated: when the module keeps every template entry and only adds some, the finding
    # lists the extras so the reviewer can drop it (see review-template-check).
    @{ Pattern = '.prettierignore';         Kind = 'exact';            Severity = 'Critical' }
    # Extending the template's generateEslintConfig is accepted (see Test-EslintExtendsTemplate).
    @{ Pattern = 'eslint.config.mjs';       Kind = 'exact';            Severity = 'Critical' }
    @{ Pattern = '.husky/*';                Kind = 'exact';            Severity = 'Critical' }
    # A .github file the module HAS must match the template: a content difference is High
    # (blocking), because a drifted workflow confuses later troubleshooting. A MISSING .github
    # file is a lesser gap and stays Medium. Re-indenting alone is not a difference, and neither
    # is adding, removing or rewording comments. Enabling anything the template ships commented
    # out (the node.yaml `test:` job, `with: upload-artifact: true` in
    # companion-module-checks.yaml) is accepted too (see Test-WorkflowMatchesTemplate).
    @{ Pattern = '.github/workflows/*';     Kind = 'workflow';         Severity = 'High'; MissingSeverity = 'Medium'; IgnoreIndent = $true }
    # Issue templates are the maintainer's to customise for their module (labels, questions,
    # links), so only their presence is checked: a missing one is still Medium, a different one
    # is never reported.
    @{ Pattern = '.github/ISSUE_TEMPLATE/*'; Kind = 'presence';        Severity = 'Medium'; MissingSeverity = 'Medium' }
    # Anything else under .github follows the workflow rule.
    @{ Pattern = '.github/*';               Kind = 'exact';            Severity = 'High'; MissingSeverity = 'Medium'; IgnoreIndent = $true }
    @{ Pattern = 'LICENSE';                 Kind = 'covered-elsewhere' }   # §3b LICENSE-DIFF
    @{ Pattern = 'package.json';            Kind = 'covered-elsewhere' }   # §4 PKG-*
    @{ Pattern = 'companion/manifest.json'; Kind = 'covered-elsewhere' }   # §5 MAN-*
    @{ Pattern = 'companion/HELP.md';       Kind = 'covered-elsewhere' }   # §6 HELP-STUB
    @{ Pattern = 'README.md';               Kind = 'module-owned' }
    @{ Pattern = 'src/*';                   Kind = 'module-owned' }
    @{ Pattern = 'yarn.lock';               Kind = 'module-owned' }        # js-v1 tracks it; per-module by nature
    @{ Pattern = '*.png';                   Kind = 'skip-binary' }
    @{ Pattern = '*.jpg';                   Kind = 'skip-binary' }
    @{ Pattern = '*.ico';                   Kind = 'skip-binary' }
    @{ Pattern = '*.gif';                   Kind = 'skip-binary' }
    @{ Pattern = '*.webp';                  Kind = 'skip-binary' }
    @{ Pattern = '*.zip';                   Kind = 'skip-binary' }
)

function Remove-UploadArtifactOption {
    # companion-module-checks.yaml ships `with:` / `upload-artifact: true` commented out and tells
    # the maintainer to uncomment it. Dropping those two lines (commented or not) from both sides
    # makes that the only accepted difference; any other `with:` input is still a divergence.
    param([string[]]$Lines)
    return @($Lines | Where-Object {
        $_ -notmatch '^\s*#?\s*with:\s*(#.*)?$' -and $_ -notmatch '^\s*#?\s*upload-artifact:\s*true\s*(#.*)?$'
    })
}

function Remove-YamlComment {
    # Strip a whole-line or trailing `# ...` comment from a trimmed YAML line. A `#` that is not
    # preceded by whitespace (e.g. inside a URL or an anchor) is left alone.
    param([string]$Line)
    $t = $Line.Trim()
    if ($t.StartsWith('#')) { return '' }
    return ($t -replace '\s+#(\s.*)?$', '').TrimEnd()
}

function Test-WorkflowMatchesTemplate {
    <# Comments are not part of the CI a workflow runs, so adding, removing or rewording them is
       not a divergence. The template also ships optional parts commented out, such as the
       node.yaml `test:` job under "# Uncomment this to enable running unit tests" and
       `with: upload-artifact: true` in companion-module-checks.yaml. Enabling those is accepted.
       So the module's non-comment lines must be exactly the template's non-comment lines, in
       order, where any of the template's commented-out lines may also appear uncommented in its
       place. Indentation is ignored (the caller has already trimmed it). #>
    param([string[]]$ModuleLines, [string[]]$TemplateLines)
    $mod = @($ModuleLines | ForEach-Object { Remove-YamlComment $_ } | Where-Object { $_ -ne '' })
    $items = @(foreach ($l in $TemplateLines) {
        $t = $l.Trim()
        if ($t -eq '') { continue }
        if ($t.StartsWith('#')) {
            $u = Remove-YamlComment ($t -replace '^#\s?', '')
            if ($u -ne '') { [pscustomobject]@{ Text = $u; Optional = $true } }
        } else {
            [pscustomobject]@{ Text = (Remove-YamlComment $t); Optional = $false }
        }
    })
    $n = $items.Count; $m = $mod.Count
    # ok[i,j]: template items i.. can produce exactly module lines j..
    $ok = New-Object 'bool[,]' ($n + 1), ($m + 1)
    for ($i = $n; $i -ge 0; $i--) {
        for ($j = $m; $j -ge 0; $j--) {
            if ($i -eq $n) { $ok[$i, $j] = ($j -eq $m); continue }
            $it = $items[$i]
            $v = $false
            if ($j -lt $m -and $mod[$j] -ceq $it.Text -and $ok[($i + 1), ($j + 1)]) { $v = $true }
            elseif ($it.Optional -and $ok[($i + 1), $j]) { $v = $true }
            $ok[$i, $j] = $v
        }
    }
    return $ok[0, 0]
}

function Get-CommentedOutWorkflowCode {
    <# Comments are ignored only while they are prose. A comment that is really commented-out
       code (a YAML key such as `runs-on: ...`, a `- uses: ...` list item, an expression) and
       is not one of the template's own commented-out lines is still a divergence: it either
       disables a template line or parks new code in the file. Keys in workflow YAML are
       lowercase, so a prose comment such as "Note: ..." is not mistaken for code. #>
    param([string[]]$ModuleLines, [string[]]$TemplateLines)
    $tplCommented = @($TemplateLines | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('#') } |
        ForEach-Object { Remove-YamlComment ($_ -replace '^#\s?', '') } | Where-Object { $_ -ne '' })
    return @($ModuleLines | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('#') } | ForEach-Object {
        $u = Remove-YamlComment ($_ -replace '^#\s?', '')
        $isCode = ($u -cmatch '^-\s+\S') -or ($u -cmatch '^[a-z_][\w.-]*:(\s|$)') -or ($u -cmatch '^\$\{\{')
        if ($u -ne '' -and $isCode -and ($tplCommented -cnotcontains $u)) { $_ }
    })
}

function Resolve-TemplateFileRule {
    param([Parameter(Mandatory)][string]$Rel)
    foreach ($r in $templateFileRules) {
        if ($Rel -like $r.Pattern) {
            $sev = if ($r.ContainsKey('Severity')) { $r.Severity } else { 'Critical' }
            return [pscustomobject]@{
                Kind            = $r.Kind
                Severity        = $sev
                MissingSeverity = if ($r.ContainsKey('MissingSeverity')) { $r.MissingSeverity } else { $sev }
                IgnoreComments  = $r.ContainsKey('IgnoreComments') -and $r.IgnoreComments
                IgnoreIndent    = $r.ContainsKey('IgnoreIndent') -and $r.IgnoreIndent
                Source          = if ($r.ContainsKey('Source'))   { $r.Source }   else { 'template' }
                Defaulted       = $false
            }
        }
    }
    return [pscustomobject]@{ Kind = 'exact'; Severity = 'Critical'; MissingSeverity = 'Critical'; IgnoreComments = $false; IgnoreIndent = $false; Source = 'template'; Defaulted = $true }
}

foreach ($rel in (Get-TemplateTrackedFiles -Dir $TemplateDir)) {
    $rule = Resolve-TemplateFileRule $rel
    if ($rule.Kind -in @('module-owned', 'covered-elsewhere', 'skip-binary')) { continue }

    # .yarnrc.yml comes from the main template even for v1 modules (see $yarnrcTemplateDir).
    $tplFile = if ($rule.Source -eq 'yarnrc') { Join-Path $yarnrcTemplateDir $rel } else { Join-Path $TemplateDir $rel }
    if (-not (Test-Path $tplFile)) { continue }   # template lacks it; nothing to compare

    $modFile = Join-Path $ModuleDir $rel
    if (-not (Test-Path $modFile)) {
        # Presence and content are decided in one pass so a missing file is reported once,
        # as FILE-MISSING, and never also as a CONFIG-DIFF against an empty file.
        Add-Finding 'FILE-MISSING' $rule.MissingSeverity $rel 'Required file is missing (tracked by the template)'
        continue
    }
    if ($rule.Kind -eq 'presence') { continue }
    if ($rule.Defaulted) {
        Add-Finding 'TEMPLATE-COVERAGE' 'Info' $rel (
            "Template tracks this file but validate-template.ps1 has no explicit rule for it — " +
            "compared by exact normalized text as a fallback. Add a row to `$templateFileRules " +
            "in scripts/validate-template.ps1 (companion-module-review plugin) and a row to the finding table in its review-template-check skill.")
    }
    if ($rule.Kind -eq 'yarnrc') {
        # Key-level comparison: the module must carry exactly the template's keys with
        # matching values. Missing keys drop the template's supply-chain hardening;
        # conflicting values and extra keys change install behaviour for everyone.
        $modMap = Read-YarnrcMap $modFile
        $tplMap = Read-YarnrcMap $tplFile
        if ($modMap.Count -eq 0 -and (Read-NormalizedLines $modFile).Count -gt 0) {
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel 'Could not parse .yarnrc.yml as YAML key/value pairs'
            continue
        }
        $missingKeys = @($tplMap.Keys | Where-Object { -not $modMap.Contains($_) })
        if ($missingKeys.Count -gt 0) {
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Missing template keys: $($missingKeys -join ', ')"
        }
        $mismatches = @($tplMap.Keys | Where-Object { $modMap.Contains($_) -and $modMap[$_] -ne $tplMap[$_] } |
            ForEach-Object { "$_ = '$($modMap[$_])' (template '$($tplMap[$_])')" })
        if ($mismatches.Count -gt 0) {
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Value mismatch: $($mismatches -join '; ')"
        }
        $extraKeys = @($modMap.Keys | Where-Object { -not $tplMap.Contains($_) })
        if ($extraKeys.Count -gt 0) {
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Extra keys not in template: $($extraKeys -join ', ')"
        }
        continue
    }
    $modLines = @(Read-NormalizedLines $modFile)
    $tplLines = @(Read-NormalizedLines $tplFile)
    if ($rule.Kind -eq 'tsconfig') {
        $modLines = @($modLines | ForEach-Object { Normalize-TsconfigLine $_ })
        $tplLines = @($tplLines | ForEach-Object { Normalize-TsconfigLine $_ })
    }
    if ($rel -eq 'tsconfig.build.json' -and $null -ne $nodeTarget -and $tplTsPreset) {
        # A preset for another Node major is reported by NODE-VERSION (§5b), not as a TSCONFIG-DIFF.
        $modLines = @($modLines | ForEach-Object {
            $pm = [regex]::Match($_, $tsPresetRe)
            if ($pm.Success -and [int]$pm.Groups[1].Value -ne $nodeTarget) { $_.Replace($pm.Value, $tplTsPreset) } else { $_ }
        })
    }
    if ($rule.Kind -eq 'workflow' -and [IO.Path]::GetFileName($rel) -eq 'companion-module-checks.yaml') {
        $modLines = Remove-UploadArtifactOption $modLines
        $tplLines = Remove-UploadArtifactOption $tplLines
    }
    if ($rule.IgnoreComments) {
        $modLines = @($modLines | Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' })
        $tplLines = @($tplLines | Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' })
    }
    if ($rel -eq '.gitattributes') {
        # Extra rules that only mark file types as binary (e.g. `*.png binary`) make git detect
        # those files correctly and are accepted; the template's own rule must still be there.
        $modLines = @($modLines | Where-Object { ($tplLines -ccontains $_) -or ($_ -notmatch '^\S+\s+binary\s*$') })
    }
    if ($rule.IgnoreIndent) {
        $modLines = @($modLines | ForEach-Object { $_.TrimStart() })
        $tplLines = @($tplLines | ForEach-Object { $_.TrimStart() })
    }
    if ($rule.Kind -eq 'workflow' -and $null -ne $nodeTarget) {
        # node-version values are reported by NODE-VERSION (§5b), so they are not a CONFIG-DIFF too.
        $tplNode = @($tplLines | Where-Object { $_ -match $nodeVersionRe } | ForEach-Object { ([regex]::Match($_, $nodeVersionRe)).Groups[2].Value.Trim() }) | Select-Object -First 1
        if ($tplNode) {
            $modLines = @($modLines | ForEach-Object {
                $mm = [regex]::Match($_, $nodeVersionRe)
                if ($mm.Success -and $null -ne (Get-NodeMajor $mm.Groups[2].Value)) { "$($mm.Groups[1].Value)node-version: $tplNode" } else { $_ }
            })
        }
        $tplStep = @($tplLines | Where-Object { $_ -match $nodeStepNameRe } | ForEach-Object { ([regex]::Match($_, $nodeStepNameRe)).Groups[2].Value }) | Select-Object -First 1
        if ($tplStep) {
            $modLines = @($modLines | ForEach-Object {
                $mm = [regex]::Match($_, $nodeStepNameRe)
                if ($mm.Success -and $null -ne (Get-NodeMajor $mm.Groups[2].Value)) { "$($mm.Groups[1].Value)$tplStep" } else { $_ }
            })
        }
    }
    if ($rule.Kind -eq 'gitignore-subset') {
        # Subset rule: every template entry must be present in the module's .gitignore.
        # Extra module entries are allowed and not flagged. Blank and comment lines in
        # the template are not entries, so they're skipped.
        $missing = @($tplLines | Where-Object {
            $_ -ne '' -and -not $_.StartsWith('#') -and ($modLines -notcontains $_)
        })
        if ($missing.Count -gt 0) {
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Missing template .gitignore entries: $($missing -join ', ')"
        }
        continue
    }
    if (($modLines -join "`n") -ne ($tplLines -join "`n")) {
        # Accepted deviation: tsconfig.json (NOT tsconfig.build.json, which drives the build)
        # may be widened so tests and the test-runner config are type-checked — extra
        # include/exclude/types entries plus rootDir/noEmit. See Test-TsconfigDevScope.
        if ($rule.Kind -eq 'tsconfig' -and $rel -eq 'tsconfig.json') {
            $dev = Test-TsconfigDevScope -ModuleFile $modFile -TemplateFile $tplFile
            if ($dev.Acceptable) {
                if ($dev.Extras.Count -gt 0) {
                    Add-Finding 'TSCONFIG-DEV-SCOPE' 'Info' $rel (
                        "Widens the editor/typecheck config beyond the template ($($dev.Extras -join '; ')) — " +
                        "an accepted deviation for type-checking tests; the build config is compared separately.")
                }
                continue
            }
            Add-Finding 'TSCONFIG-DIFF' 'Info' $rel "Differs from template ($($dev.Reason); $(Get-FirstLineDiff $modLines $tplLines))"
            continue
        }
        # Accepted deviations: eslint.config.mjs may add rule overrides scoped to test/tooling
        # files (Test-EslintTestScope), or more generally extend the template's
        # generateEslintConfig with its own imports, options and blocks (Test-EslintExtendsTemplate).
        if ($rel -eq 'eslint.config.mjs') {
            $es = Test-EslintTestScope -ModuleFile $modFile -TemplateFile $tplFile
            if ($es.Acceptable) {
                if ($es.Extras.Count -gt 0) {
                    Add-Finding 'ESLINT-TEST-SCOPE' 'Info' $rel (
                        "Adds lint overrides scoped to test/tooling files only ($($es.Extras -join '; ')) — " +
                        "an accepted deviation; the template's base config and options are unchanged.")
                }
                continue
            }
            $ext = Test-EslintExtendsTemplate -ModuleFile $modFile -TemplateFile $tplFile
            if ($ext.Acceptable) {
                Add-Finding 'ESLINT-EXTENDS' 'Info' $rel (
                    "Extends the template's generateEslintConfig ($($ext.Extras -join '; ')) — " +
                    "an accepted deviation; the template's own imports and options are unchanged.")
                continue
            }
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Differs from template ($($ext.Reason); $(Get-FirstLineDiff $modLines $tplLines))"
            continue
        }
        if ($rule.Kind -eq 'tsconfig') {
            # Not blocking: maintainers may tune their tsconfig freely as long as the module builds.
            # Surfaced as a note so the reviewer can still mention it (📝 Additional Notes).
            Add-Finding 'TSCONFIG-DIFF' 'Info' $rel "Differs from template ($(Get-FirstLineDiff $modLines $tplLines))"
            continue
        }
        if ($rule.Kind -eq 'workflow') {
            if (Test-WorkflowMatchesTemplate -ModuleLines $modLines -TemplateLines $tplLines) {
                $parked = @(Get-CommentedOutWorkflowCode -ModuleLines $modLines -TemplateLines $tplLines)
                if ($parked.Count -eq 0) { continue }
                Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Comments out code that is not in the template: $($parked -join '; ')"
                continue
            }
            # Report the first difference between the lines that actually run, not a comment.
            $modCode = @($modLines | ForEach-Object { Remove-YamlComment $_ } | Where-Object { $_ -ne '' })
            $tplCode = @($tplLines | ForEach-Object { Remove-YamlComment $_ } | Where-Object { $_ -ne '' })
            Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Differs from template ($(Get-FirstLineDiff $modCode $tplCode))"
            continue
        }
        if ($rel -eq '.prettierignore') {
            $missingEntries = @($tplLines | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') -and $modLines -cnotcontains $_ })
            $extraEntries = @($modLines | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') -and $tplLines -cnotcontains $_ })
            if ($missingEntries.Count -eq 0 -and $extraEntries.Count -gt 0) {
                Add-Finding 'CONFIG-DIFF' $rule.Severity $rel ("Extra entries not in template: $($extraEntries -join ', ') " +
                    "(drop this finding if every extra entry is a generated file)")
                continue
            }
            if ($missingEntries.Count -eq 0) { continue }   # only comments or blank lines differ
        }
        Add-Finding 'CONFIG-DIFF' $rule.Severity $rel "Differs from template ($(Get-FirstLineDiff $modLines $tplLines))"
    }
}

# ── 3. Gitignored files must not be committed ────────────────────────────────
function Test-PathMatchesIgnore {
    param([string]$RelPath, [string]$Pattern)
    $p = $Pattern.Trim()
    if (-not $p -or $p.StartsWith('#')) { return $false }
    $anchored = $p.StartsWith('/')
    $p = $p.TrimStart('/').TrimEnd('/')
    if (-not $p) { return $false }
    $escaped = [regex]::Escape($p).Replace('\*','[^/]*')
    if ($anchored) {
        # Anchored to repo root: whole path or a directory prefix.
        return $RelPath -match ('^' + $escaped + '(/|$)')
    }
    # Unanchored: match any path segment (e.g. node_modules/, DEBUG-*, package-lock.json).
    return @(($RelPath -split '/') | Where-Object { $_ -match ('^' + $escaped + '$') }).Count -gt 0
}

$tplGitignore = @(Read-NormalizedLines (Join-Path $TemplateDir '.gitignore'))
if ($tplGitignore -and (Test-Path (Join-Path $ModuleDir '.git'))) {
    $tracked = & git -C $ModuleDir ls-files 2>$null
    foreach ($f in $tracked) {
        foreach ($pat in $tplGitignore) {
            if (Test-PathMatchesIgnore $f $pat) {
                Add-Finding 'GITIGNORED-COMMITTED' 'Critical' $f "Committed but template .gitignore excludes it (pattern '$pat')"
                break
            }
        }
    }
}

# ── 3b. LICENSE must carry the template's licence text ───────────────────────
# The template's LICENSE is the MIT licence. Its copyright line belongs to the module author:
# with an MIT licence you never replace the holder, and the year is the year the module was
# created. So the copyright line(s) are not compared at all. What must match is the licence
# itself, compared word by word so line wrapping is not a difference, and with the
# "The MIT License" spelling of the title accepted. A different licence, or changed licence
# text, is a divergence. Line endings and trailing whitespace never matter.
function Get-LicenseWords {
    param([string[]]$Lines)
    $body = @($Lines | Where-Object { $_ -notmatch '^\s*copyright\b' })
    $words = @((($body -join ' ') -split '\s+') | Where-Object { $_ -ne '' })
    if ($words.Count -ge 3 -and $words[0] -eq 'The' -and $words[1] -eq 'MIT' -and $words[2] -eq 'License') {
        $words = @($words[1..($words.Count - 1)])
    }
    return ,$words
}
function Get-FirstWordDiff {
    param([string[]]$ModuleWords, [string[]]$TemplateWords)
    $max = [math]::Max($ModuleWords.Count, $TemplateWords.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $m = if ($i -lt $ModuleWords.Count) { $ModuleWords[$i] } else { $null }
        $t = if ($i -lt $TemplateWords.Count) { $TemplateWords[$i] } else { $null }
        if ($m -cne $t) {
            $mText = if ($i -lt $ModuleWords.Count) { ($ModuleWords[$i..([math]::Min($i + 7, $ModuleWords.Count - 1))] -join ' ') } else { '<missing>' }
            $tText = if ($i -lt $TemplateWords.Count) { ($TemplateWords[$i..([math]::Min($i + 7, $TemplateWords.Count - 1))] -join ' ') } else { '<missing>' }
            return "found '$mText', template '$tText'"
        }
    }
    return ''
}
$modLicense = Join-Path $ModuleDir 'LICENSE'
$tplLicense = Join-Path $TemplateDir 'LICENSE'
if ((Test-Path $modLicense) -and (Test-Path $tplLicense)) {
    $modW = Get-LicenseWords @(Read-NormalizedLines $modLicense)
    $tplW = Get-LicenseWords @(Read-NormalizedLines $tplLicense)
    if (($modW -join ' ') -cne ($tplW -join ' ')) {
        Add-Finding 'LICENSE-DIFF' 'High' 'LICENSE' "Licence text differs from the template ($(Get-FirstWordDiff $modW $tplW))"
    }
}

# ── 3c. Source files must live in src/ (none at the module root) ──────────────
# Tool config files (vitest.config.ts, vite.config.ts, jest.config.js, prettier.config.js, …)
# are not module source: the tools look for them at the repo root, so that is where they must
# live. Anything named <tool>.config.<js|ts> is exempt; every other root .js/.ts is flagged.
$rootSrc = @(Get-ChildItem -LiteralPath $ModuleDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.js', '.ts') -and $_.Name -notmatch '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*\.config\.(js|ts)$' })
foreach ($f in $rootSrc) {
    Add-Finding 'SRC-AT-ROOT' 'Critical' $f.Name "Source file at module root — all source must be under src/"
}

# ── 4. package.json rules ────────────────────────────────────────────────────
if ($pkg) {
    $moduleName = (Split-Path $ModuleDir -Leaf) -replace '^companion-module-',''
    $expectedRepo = "git+https://github.com/bitfocus/companion-module-$moduleName.git"

    if ($ExpectedVersion) {
        $want = ConvertTo-NormalizedTag $ExpectedVersion
        if ((Has-Prop $pkg 'version') -and $pkg.version -ne $want) {
            Add-Finding 'PKG-VERSION' 'Critical' 'package.json' "version '$($pkg.version)' != git tag '$want'"
        }
    }
    # main need not match the template filename, but if present it must reference an existing
    # entry file. Build outputs under dist/ are absent in a source checkout (the build step
    # validates those), so they are not existence-checked here.
    if ((Has-Prop $pkg 'main') -and "$($pkg.main)" -notmatch '(^|/)dist/') {
        if (-not (Test-Path (Join-Path $ModuleDir $pkg.main))) {
            Add-Finding 'PKG-MAIN' 'Critical' 'package.json' "main '$($pkg.main)' references a file that does not exist"
        }
    }
    if ((Has-Prop $pkg 'repository') -and (Has-Prop $pkg.repository 'url') -and $pkg.repository.url -ne $expectedRepo) {
        Add-Finding 'PKG-REPO' 'Critical' 'package.json' "repository.url '$($pkg.repository.url)' should be '$expectedRepo'"
    }
    # Required top-level fields = those present in the matched template (version-correct).
    $candidateFields = @('engines','prettier','packageManager','license','main','scripts','dependencies')
    foreach ($field in $candidateFields) {
        if ($tplPkg -and (Has-Prop $tplPkg $field) -and -not (Has-Prop $pkg $field)) {
            Add-Finding 'PKG-FIELD' 'Critical' 'package.json' "Missing required field '$field' (present in template)"
        }
    }
    # packageManager: must match the template's package manager + major (e.g. yarn@4).
    if ($tplPkg -and (Has-Prop $tplPkg 'packageManager') -and (Has-Prop $pkg 'packageManager')) {
        $wantPrefix = if ("$($tplPkg.packageManager)" -match '^([^@]+@\d+)') { $Matches[1] } else { "$($tplPkg.packageManager)" }
        if ($pkg.packageManager -notmatch ('^' + [regex]::Escape($wantPrefix))) {
            Add-Finding 'PKG-YARN' 'Critical' 'package.json' "packageManager '$($pkg.packageManager)' should start with '$wantPrefix'"
        }
    }
    # Required scripts = the template's script names.
    $reqScripts = if ($tplPkg -and (Has-Prop $tplPkg 'scripts')) {
        @($tplPkg.scripts.PSObject.Properties.Name)
    } elseif ($isTs) {
        @('format','package','build','build:main','dev','lint','lint:raw','postinstall')
    } else {
        @('format','package')
    }
    foreach ($s in $reqScripts) {
        if (-not ((Has-Prop $pkg 'scripts') -and (Has-Prop $pkg.scripts $s))) {
            Add-Finding 'PKG-SCRIPT' 'Critical' 'package.json' "Missing required script '$s'"
        }
    }
    if (-not ((Has-Prop $pkg 'dependencies') -and (Has-Prop $pkg.dependencies '@companion-module/base'))) {
        Add-Finding 'PKG-DEP' 'Critical' 'package.json' "Missing dependency '@companion-module/base'"
    }
    # devDependencies = every dev dep present in the matched template (version-correct).
    if ($tplPkg -and (Has-Prop $tplPkg 'devDependencies')) {
        foreach ($dd in @($tplPkg.devDependencies.PSObject.Properties.Name)) {
            if (-not ((Has-Prop $pkg 'devDependencies') -and (Has-Prop $pkg.devDependencies $dd))) {
                Add-Finding 'PKG-DEVDEP' 'Critical' 'package.json' "Missing devDependency '$dd' (present in template)"
            }
        }
    }
    # lint-staged section required if the template has it (TS).
    if ($tplPkg -and (Has-Prop $tplPkg 'lint-staged') -and -not (Has-Prop $pkg 'lint-staged')) {
        Add-Finding 'PKG-LINTSTAGED' 'Critical' 'package.json' "Missing 'lint-staged' section (present in template)"
    }
}

# ── 5. manifest.json rules ───────────────────────────────────────────────────
$manifestPath = Join-Path $ModuleDir 'companion/manifest.json'
if (Test-Path $manifestPath) {
    $man = $null
    try { $man = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json }
    catch { Add-Finding 'MAN-PARSE' 'Critical' 'companion/manifest.json' "Not valid JSON: $($_.Exception.Message)" }
    if ($man) {
        # NOTE: manifest `name` is the human-facing module name and is *expected* to differ
        # from the slug `id` (e.g. id "fblab-bpm2osc" / name "BPM2OSC"). Do not reinstate an
        # id == name check here — it is not a Bitfocus requirement.
        $moduleName = (Split-Path $ModuleDir -Leaf) -replace '^companion-module-',''
        if (-not (Has-Prop $man 'maintainers') -or @($man.maintainers).Count -eq 0) {
            Add-Finding 'MAN-MAINT' 'Critical' 'companion/manifest.json' 'maintainers is empty'
        } else {
            foreach ($m in $man.maintainers) {
                $badName  = (Has-Prop $m 'name')  -and ($m.name  -match '^(Your name)?$')
                # An empty email is allowed: a contact is nice to have but not required. Only the
                # template's literal "Your email" placeholder is flagged (2026-10-30).
                $badEmail = (Has-Prop $m 'email') -and ($m.email -eq 'Your email')
                if ($badName -or $badEmail) {
                    Add-Finding 'MAN-PLACEHOLDER' 'Critical' 'companion/manifest.json' "Placeholder maintainer: name='$($m.name)' email='$($m.email)'"
                }
            }
        }
        # Only the fixed list. A keyword that repeats part of the module name (manufacturer or
        # product, e.g. 'switch' in goalake-switch) is NOT flagged: the review maintainer
        # decided it isn't worth a finding (2026-10-10).
        $banned = @('companion','module','stream deck','streamdeck','bitfocus')
        if (Has-Prop $man 'keywords') {
            foreach ($kw in $man.keywords) {
                $low = "$kw".ToLower()
                if ($banned -contains $low) {
                    Add-Finding 'MAN-KEYWORD' 'Critical' 'companion/manifest.json' "Banned/low-value keyword '$kw'"
                }
            }
        }
        # manifest.type: required only if the matched template has it (v2 'connection'; absent in v1).
        if ($tplMan -and (Has-Prop $tplMan 'type')) {
            if (-not (Has-Prop $man 'type')) {
                Add-Finding 'MAN-TYPE' 'Critical' 'companion/manifest.json' "Missing 'type' (template requires '$($tplMan.type)')"
            } elseif ($man.type -ne $tplMan.type) {
                Add-Finding 'MAN-TYPE' 'Critical' 'companion/manifest.json' "type '$($man.type)' should be '$($tplMan.type)'"
            }
        }
        # runtime.type / runtime.api must match the template (lang+version specific).
        # For v2, runtime.type is judged against the API level's allowed runtime (plus whatever
        # the template pins, for an explicit -TemplateDir): a 2.1 module must be on node26 like
        # the 2.1 template, and node22 there is a Critical; a 2.0 module is judged against the
        # -v2.0.4 template (node22), and node26 there is a Critical whose message says why
        # (node26 needs base >= 2.1, Companion 5.0+).
        # v1 keeps the plain template comparison (allowedRuntimes is $null for v1).
        if ($tplMan -and (Has-Prop $tplMan 'runtime') -and (Has-Prop $man 'runtime')) {
            foreach ($rp in @('type','api')) {
                if (-not ((Has-Prop $tplMan.runtime $rp) -and (Has-Prop $man.runtime $rp))) { continue }
                $have = "$($man.runtime.$rp)"; $want = "$($tplMan.runtime.$rp)"
                if ($rp -eq 'type' -and $null -ne $apiProfile.allowedRuntimes) {
                    $allowed = @(@($apiProfile.allowedRuntimes) + $want | Sort-Object -Unique)
                    if ($allowed -contains $have) { continue }
                    $msg = if ($have -eq 'node26') {
                        "runtime.type 'node26' requires @companion-module/base >= 2.1 (Companion 5.0+); this module resolves to $($baseInfo.version) (API $($baseInfo.apiLevel)). Use 'node22' or upgrade base to ~2.1.x"
                    } elseif ($null -ne $nodeTarget -and $have -match '^node\d+$' -and $allowed -contains "node$nodeTarget") {
                        continue   # an older Node runtime: NODE-VERSION (§5b) lists it with every other place to update
                    } elseif ($allowed.Count -eq 1) {
                        "runtime.type '$have' should be '$($allowed[0])' to match the API $($baseInfo.apiLevel) template"
                    } else {
                        "runtime.type '$have' should be one of: $($allowed -join ', ') (API $($baseInfo.apiLevel))"
                    }
                    Add-Finding 'MAN-RUNTIME' 'Critical' 'companion/manifest.json' $msg
                    continue
                }
                if ($have -ne $want) {
                    if ($rp -eq 'type' -and $null -ne $nodeTarget -and $have -match '^node\d+$' -and $want -eq "node$nodeTarget") { continue }   # NODE-VERSION (§5b)
                    Add-Finding 'MAN-RUNTIME' 'Critical' 'companion/manifest.json' "runtime.$rp '$have' should be '$want'"
                }
            }
        }
        # runtime.entrypoint need NOT match the template filename. It must reference an existing
        # file (dist/ build outputs are skipped — absent until built) and resolve to the same
        # file as package.json main.
        if ((Has-Prop $man 'runtime') -and (Has-Prop $man.runtime 'entrypoint')) {
            $entryRel  = "$($man.runtime.entrypoint)"
            $entryFull = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $ModuleDir 'companion') $entryRel))
            if ($entryRel -notmatch '(^|/)dist/' -and -not (Test-Path $entryFull)) {
                Add-Finding 'MAN-RUNTIME' 'Critical' 'companion/manifest.json' "runtime.entrypoint '$entryRel' references a file that does not exist"
            }
            if (Has-Prop $pkg 'main') {
                $mainFull = [System.IO.Path]::GetFullPath((Join-Path $ModuleDir "$($pkg.main)"))
                if ($mainFull -ne $entryFull) {
                    Add-Finding 'ENTRY-MISMATCH' 'Critical' 'companion/manifest.json' "runtime.entrypoint '$entryRel' and package.json main '$($pkg.main)' resolve to different files"
                }
            }
        }
    }
}

# ── 5b. Node version: every place must name the template's Node major ─────────
# Upgrading Node (e.g. node22 -> node26 for API 2.1) touches several files, and a review must list
# all of them every time, so one finding names every place that is still on another version:
#   companion/manifest.json  runtime.type
#   package.json             engines.node, devDependencies @types/node (when the template has them)
#   tsconfig.build.json      the @companion-module/tools/tsconfig/node<N>/ preset (TS)
#   .github/workflows/*      every node-version line and "Use Node.js <N>" step name, commented-out ones included
#   .nvmrc / .node-version   when the module has one
# Critical when the manifest runtime is behind (it decides what Companion runs), otherwise High.
if ($null -ne $nodeTarget) {
    $nodeItems = [System.Collections.Generic.List[string]]::new()
    $nodeFiles = [System.Collections.Generic.List[string]]::new()
    $runtimeBehind = $false
    if ("$modRuntimeType" -match '^node(\d+)$' -and [int]$Matches[1] -ne $nodeTarget) {
        $runtimeBehind = $true
        $nodeItems.Add("companion/manifest.json runtime.type '$modRuntimeType' -> 'node$nodeTarget'"); $nodeFiles.Add('companion/manifest.json')
    }
    if ($pkg -and $tplPkg -and (Has-Prop $tplPkg 'engines') -and (Has-Prop $tplPkg.engines 'node') -and (Has-Prop $pkg 'engines')) {
        $want = "$($tplPkg.engines.node)"
        if (-not (Has-Prop $pkg.engines 'node')) {
            $nodeItems.Add("package.json engines.node missing -> '$want'"); $nodeFiles.Add('package.json')
        } elseif ((Get-NodeMajor $pkg.engines.node) -ne $nodeTarget) {
            $nodeItems.Add("package.json engines.node '$($pkg.engines.node)' -> '$want'"); $nodeFiles.Add('package.json')
        }
    }
    if ($pkg -and $tplPkg -and (Has-Prop $tplPkg 'devDependencies') -and (Has-Prop $tplPkg.devDependencies '@types/node') -and
        (Has-Prop $pkg 'devDependencies') -and (Has-Prop $pkg.devDependencies '@types/node')) {
        $have = "$($pkg.devDependencies.'@types/node')"
        if ((Get-NodeMajor $have) -ne $nodeTarget) {
            $nodeItems.Add("package.json devDependencies @types/node '$have' -> '$($tplPkg.devDependencies.'@types/node')'"); $nodeFiles.Add('package.json')
        }
    }
    $modTsBuild = Join-Path $ModuleDir 'tsconfig.build.json'
    if ($tplTsPreset -and (Test-Path $modTsBuild)) {
        $pm = [regex]::Match((Get-Content -Raw -LiteralPath $modTsBuild), $tsPresetRe)
        if ($pm.Success -and [int]$pm.Groups[1].Value -ne $nodeTarget) {
            $nodeItems.Add("tsconfig.build.json extends $($pm.Value) -> $tplTsPreset"); $nodeFiles.Add('tsconfig.build.json')
        }
    }
    $wfDir = Join-Path $ModuleDir '.github/workflows'
    if (Test-Path $wfDir) {
        foreach ($wf in @(Get-ChildItem -LiteralPath $wfDir -File | Where-Object { $_.Extension -in '.yml', '.yaml' } | Sort-Object Name)) {
            $rel = ".github/workflows/$($wf.Name)"
            $tplWf = Join-Path $TemplateDir $rel
            $tplNode = if (Test-Path $tplWf) {
                @(Get-Content -LiteralPath $tplWf | Where-Object { $_ -match $nodeVersionRe } | ForEach-Object { ([regex]::Match($_, $nodeVersionRe)).Groups[2].Value.Trim() }) | Select-Object -First 1
            } else { $null }
            if (-not $tplNode) { $tplNode = "$nodeTarget.x" }
            $lineNo = 0
            foreach ($line in @(Get-Content -LiteralPath $wf.FullName)) {
                $lineNo++
                $mm = [regex]::Match($line, $nodeVersionRe)
                $isStep = $false
                if (-not $mm.Success) { $mm = [regex]::Match($line, $nodeStepNameRe); $isStep = $mm.Success }
                if (-not $mm.Success) { continue }
                $val = $mm.Groups[2].Value.Trim()
                $maj = Get-NodeMajor $val
                if ($null -eq $maj -or $maj -eq $nodeTarget) { continue }
                $note = if ($mm.Groups[1].Value -match '#') { ' (commented out)' } else { '' }
                if ($isStep) {
                    $nodeItems.Add("$rel line $lineNo step name 'Use Node.js $val' -> 'Use Node.js $tplNode'$note"); $nodeFiles.Add($rel)
                } else {
                    $nodeItems.Add("$rel line $lineNo node-version $val -> $tplNode$note"); $nodeFiles.Add($rel)
                }
            }
        }
    }
    foreach ($vf in @('.nvmrc', '.node-version')) {
        $vp = Join-Path $ModuleDir $vf
        if (Test-Path $vp) {
            $val = (Get-Content -Raw -LiteralPath $vp).Trim()
            $maj = Get-NodeMajor $val
            if ($null -ne $maj -and $maj -ne $nodeTarget) { $nodeItems.Add("$vf '$val' -> '$nodeTarget'"); $nodeFiles.Add($vf) }
        }
    }
    if ($nodeItems.Count -gt 0) {
        $sev = if ($runtimeBehind) { 'Critical' } else { 'High' }
        $apiText = if ($baseInfo.apiLevel) { "API $($baseInfo.apiLevel) " } else { '' }
        Add-Finding 'NODE-VERSION' $sev $nodeFiles[0] ("The ${apiText}template runs on Node $nodeTarget; update every place still on another version: " + ($nodeItems -join '; '))
    }
}

# ── 6. HELP.md stub detection ────────────────────────────────────────────────
$helpPath = Join-Path $ModuleDir 'companion/HELP.md'
if (Test-Path $helpPath) {
    $help = Get-Content -Raw -LiteralPath $helpPath
    $meaningful = @($help -split "`r?`n" | Where-Object { $_.Trim() }).Count
    if ($help -match 'Write some help for your users here' -or $meaningful -lt 5) {
        Add-Finding 'HELP-STUB' 'Critical' 'companion/HELP.md' 'Looks like a stub — needs real user documentation'
    }
}

# ── 6b. Everything must be written in English ────────────────────────────────
# Everything in the module must be written in English: code comments, the text users see
# (labels, tooltips, log messages), companion/HELP.md, README.md and every other file. The
# next maintainer, the reviewers, and anyone troubleshooting the module must be able to read
# it. This check reads every tracked text file line by line and finds text in a non-Latin
# script (Chinese, Japanese, Korean, Cyrillic, Arabic, Hebrew, Thai, …): one Chinese, Japanese
# or Korean character (each is a word on its own), or a run of two or more letters from another
# script outside the Latin and Greek blocks. Greek is left out because single Greek letters
# (Δ, Ω, λ) are common in English technical text. The author's own name is theirs to write:
# LICENSE copyright lines and the name/author/email lines of package.json and the manifest are
# skipped. Test files (under test/, tests/ or __tests__/, or named *.test.* / *.spec.*) are
# checked for comments only: a test may use non-English text on purpose, e.g. to test sorting
# of a Cyrillic label. Text in a Latin-script language (German, Spanish, Dutch, …) can't be told apart from
# English by its letters, so the companion-compliance-reviewer reports those.
$nonLatinRunRe  = [regex]::new('[\p{IsCJKUnifiedIdeographs}\p{IsHiragana}\p{IsKatakana}\p{IsHangulSyllables}]|[\p{L}-[\p{IsBasicLatin}\p{IsLatin-1Supplement}\p{IsLatinExtended-A}\p{IsLatinExtended-B}\p{IsLatinExtendedAdditional}\p{IsIPAExtensions}\p{IsSpacingModifierLetters}\p{IsGreekandCoptic}\p{IsGreekExtended}]]{2,}')
$langSkipDirRe  = '(^|/)(node_modules|dist|pkg|build|out|coverage|\.yarn|\.git)/'
$langTestFileRe = '(^|/)(tests?|__tests__)/|\.(test|spec)\.[cm]?[jt]sx?$'
$commentTokenRe = [regex]::new('''(?:\\.|[^''\\\n])*''|"(?:\\.|[^"\\\n])*"|`(?:\\.|[^`\\])*`|(?<c>//[^\n]*|/\*[\s\S]*?\*/)')
$langSkipFileRe = '(^|/)(yarn\.lock|package-lock\.json|pnpm-lock\.yaml)$|\.(tgz|gz|zip|png|jpe?g|gif|ico|svg|webp|bmp|pdf|woff2?|ttf|otf|eot|mp3|wav|mp4|mov)$'
function Get-NonEnglishLines {
    param([string]$RelPath, [string]$Text)
    $lines = [System.Collections.Generic.List[int]]::new()
    $ownerRe = if ($RelPath -eq 'LICENSE' -or $RelPath -like 'LICENSE.*') { '^\s*copyright\b' }
        elseif ($RelPath -in 'package.json', 'companion/manifest.json') { '"(name|author|email)"\s*:' }
        else { $null }
    if ($RelPath -match $langTestFileRe) {
        # Comments only: blank out everything else, keeping the line breaks so line numbers hold.
        $kept = [System.Text.StringBuilder]::new()
        $pos = 0
        foreach ($m in $commentTokenRe.Matches($Text)) {
            $c = $m.Groups['c']
            if (-not $c.Success) { continue }
            [void]$kept.Append(($Text.Substring($pos, $c.Index - $pos) -replace '[^\n]', ' ')).Append($c.Value)
            $pos = $c.Index + $c.Length
        }
        [void]$kept.Append(($Text.Substring($pos) -replace '[^\n]', ' '))
        $Text = $kept.ToString()
    }
    $n = 0
    foreach ($line in $Text.Split("`n")) {
        $n++
        if ($ownerRe -and $line -match $ownerRe) { continue }
        if ($nonLatinRunRe.IsMatch($line)) { $lines.Add($n) }
    }
    return ,([int[]]$lines.ToArray())
}
function Format-LineRanges {
    param([int[]]$Lines, [int]$Max = 12)
    $ranges = [System.Collections.Generic.List[string]]::new()
    $i = 0
    while ($i -lt $Lines.Count) {
        $j = $i
        while ($j + 1 -lt $Lines.Count -and $Lines[$j + 1] -eq $Lines[$j] + 1) { $j++ }
        $ranges.Add($(if ($j -gt $i) { "$($Lines[$i])-$($Lines[$j])" } else { "$($Lines[$i])" }))
        $i = $j + 1
    }
    $text = ($ranges | Select-Object -First $Max) -join ', '
    if ($ranges.Count -gt $Max) { $text += ', …' }
    return $text
}
$langFilesAll = if (Test-Path (Join-Path $ModuleDir '.git')) {
    @(& git -C $ModuleDir ls-files 2>$null)
} else {
    @(Get-ChildItem -LiteralPath $ModuleDir -File -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { [System.IO.Path]::GetRelativePath($ModuleDir, $_.FullName).Replace('\', '/') })
}
$langFilesAll = @($langFilesAll | Where-Object { "/$_" -notmatch $langSkipDirRe -and $_ -notmatch $langSkipFileRe } | Sort-Object)
$langItems = [System.Collections.Generic.List[string]]::new()
$langFiles = [System.Collections.Generic.List[string]]::new()
$langTotal = 0
foreach ($rel in $langFilesAll) {
    $full = Join-Path $ModuleDir $rel
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    if ([System.IO.FileInfo]::new($full).Length -gt 2MB) { continue }
    $bytes = [System.IO.File]::ReadAllBytes($full)
    if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { continue }   # binary
    $hits = Get-NonEnglishLines $rel (([System.Text.Encoding]::UTF8.GetString($bytes)) -replace "`r`n", "`n")
    if ($hits.Count -eq 0) { continue }
    $langTotal += $hits.Count
    $langFiles.Add($rel)
    $langItems.Add("$rel ($($hits.Count) line$(if ($hits.Count -ne 1) { 's' }): $(Format-LineRanges $hits))")
}
if ($langItems.Count -gt 0) {
    Add-Finding 'NOT-ENGLISH' 'High' $langFiles[0] ("Everything in the module must be written in English (code comments, user-facing text, HELP.md, README.md, …). $langTotal line$(if ($langTotal -ne 1) { 's are' } else { ' is' }) in another language: " + ($langItems -join '; '))
}

# ── 6c. Commit messages should be in English (note) ──────────────────────────
# Commit messages are part of the module's history that the next maintainer reads, so they
# belong in English too. History can't be fixed in this release without rewriting it, so this is
# an Info note, not a finding: the review puts it in the 📋 Issues "Notes" group and asks for
# future commits in English. Checked: the commits since the previous tag before HEAD (all of
# them on a first release), for the same non-Latin scripts as NOT-ENGLISH. Commit messages in a
# Latin-script language (Spanish, German, …) are the compliance reviewer's to note.
if (Test-Path (Join-Path $ModuleDir '.git')) {
    $prevTag = (& git -C $ModuleDir describe --tags --abbrev=0 'HEAD^' 2>$null)
    $prevSha = $null
    if ($LASTEXITCODE -eq 0 -and $prevTag) {
        # The tag name comes from the module's repo: resolve it to a SHA so it is never parsed as an option.
        $prevTag = $prevTag.Trim()
        $prevSha = (& git -C $ModuleDir rev-parse --verify --quiet --end-of-options "$prevTag^{commit}" 2>$null)
        if ($LASTEXITCODE -ne 0 -or $prevSha -notmatch '^[0-9a-f]{40,64}$') { $prevSha = $null }
    }
    $range = if ($prevSha) { "$prevSha..HEAD" } else { 'HEAD' }
    $log = (& git -C $ModuleDir log --no-merges --format='%h%x1f%B%x1e' --end-of-options $range 2>$null) -join "`n"
    $commits = @($log -split "\x1e" | Where-Object { $_.Trim() })
    $bad = @($commits | Where-Object { $nonLatinRunRe.IsMatch(($_ -split "\x1f", 2)[1]) })
    if ($bad.Count -gt 0) {
        $first = $bad[0].Trim() -split "\x1f", 2
        $subject = (($first[1] -split "`n")[0]).Trim()
        $since = if ($prevSha) { "since $prevTag" } else { 'in the history' }
        Add-Finding 'COMMIT-LANGUAGE' 'Info' '' ("$($bad.Count) of $($commits.Count) commit messages $since are not in English (e.g. $($first[0]) '$subject'). Future commit messages must be written in English.")
    }
}

# ── 7. husky (TS) ────────────────────────────────────────────────────────────
# The hook is now also content-compared in §2 (the template tracks it), so a hook that
# diverges *and* drops lint-staged would otherwise be reported twice for the same line.
# The CONFIG-DIFF is the more actionable of the two, so it wins.
if ($isTs) {
    $hook = Join-Path $ModuleDir '.husky/pre-commit'
    $alreadyReported = @($findings | Where-Object { $_.id -eq 'CONFIG-DIFF' -and $_.file -eq '.husky/pre-commit' }).Count -gt 0
    if ((Test-Path $hook) -and -not $alreadyReported) {
        if ((Get-Content -Raw -LiteralPath $hook) -notmatch 'lint-staged') {
            Add-Finding 'HUSKY' 'Critical' '.husky/pre-commit' "Hook should run 'lint-staged'"
        }
    }
}

# ── 8. Optional build / lint ─────────────────────────────────────────────────
if ($RunBuild) {
    Push-Location $ModuleDir
    try {
        & yarn install --immutable *>$null
        if ($LASTEXITCODE -ne 0) { Add-Finding 'BUILD-INSTALL' 'Critical' 'package.json' 'yarn install --immutable failed' }
        & yarn package *>$null
        if ($LASTEXITCODE -ne 0) { Add-Finding 'BUILD-PACKAGE' 'Critical' 'package.json' 'yarn package (build) failed' }
        if ($isTs) {
            & yarn lint *>$null
            if ($LASTEXITCODE -ne 0) { Add-Finding 'LINT' 'High' 'package.json' 'yarn lint reported problems' }
        }
    } finally { Pop-Location }
}

# ── Output ───────────────────────────────────────────────────────────────────
function Get-RevisionRecord {
    # Which template revision this verdict was rendered against — recorded so a finished
    # review is self-attesting and a disputed finding can be re-checked at that exact commit.
    param([Parameter(Mandatory)][string]$Dir)
    $i = Get-GitRepoInfo -Dir $Dir
    return [pscustomobject]@{
        dir         = $Dir
        leaf        = (Split-Path $Dir -Leaf)
        sha         = $i.Sha
        shortSha    = $i.ShortSha
        committedAt = if ($i.CommittedAt) { ($i.CommittedAt -split 'T')[0] } else { $null }
        branch      = $i.Branch
        pinned      = [bool]$i.Detached
    }
}

$result = [pscustomobject]@{
    moduleDir         = $ModuleDir
    templateDir       = $TemplateDir
    language          = $lang
    apiVersion        = $apiVer
    apiLevel          = $baseInfo.apiLevel
    baseVersion       = $baseInfo.version
    baseVersionSource = $baseInfo.source
    templateFreshness = [pscustomobject]@{ status = $freshnessOverall; checks = @($freshnessChecks) }
    templateRevision  = Get-RevisionRecord -Dir $TemplateDir
    yarnrcTemplate    = if ($yarnrcTemplateDir -ne $TemplateDir) { Get-RevisionRecord -Dir $yarnrcTemplateDir } else { $null }
    findings          = $findings
    counts            = [pscustomobject]@{
        critical = @($findings | Where-Object severity -eq 'Critical').Count
        high     = @($findings | Where-Object severity -eq 'High').Count
        medium   = @($findings | Where-Object severity -eq 'Medium').Count
        info     = @($findings | Where-Object severity -eq 'Info').Count
    }
}

if ($Json) {
    # Depth 8: templateFreshness.checks[] nests a level deeper than the old shape, and
    # ConvertTo-Json silently stringifies anything past the limit.
    $result | ConvertTo-Json -Depth 8
} else {
    $frColor = switch ($freshnessOverall) { 'fresh' { 'Green' } 'pinned' { 'Green' } 'skipped' { 'DarkYellow' } default { 'Red' } }
    Write-Host ""
    Write-Host "validate-template — $lang module ($apiVer, API $($baseInfo.apiLevel); base $($baseInfo.version) from $($baseInfo.source))" -ForegroundColor Cyan
    Write-Host "  module:   $ModuleDir"
    Write-Host "  template: $TemplateDir"
    foreach ($c in $freshnessChecks) {
        $cColor = switch ($c.status) { 'fresh' { 'Green' } 'pinned' { 'Green' } 'skipped' { 'DarkYellow' } 'unmanaged' { 'DarkGray' } default { 'Red' } }
        Write-Host ("    {0,-38} {1}" -f $c.leaf, $c.message) -ForegroundColor $cColor
    }
    if ($freshnessOverall -in @('stale','unverified')) {
        Write-Host "  >> Refresh first:  pwsh $PSScriptRoot/update-templates.ps1  (templates are never auto-updated)" -ForegroundColor $frColor
    }
    Write-Host ("─" * 70)
    if ($findings.Count -eq 0) {
        Write-Host "No deterministic template violations found." -ForegroundColor Green
    } else {
        foreach ($f in $findings) {
            $c = switch ($f.severity) { 'Critical' { 'Red' } 'High' { 'DarkYellow' } default { 'Gray' } }
            Write-Host ("  [{0}] {1}  {2} — {3}" -f $f.severity, $f.id, $f.file, $f.message) -ForegroundColor $c
        }
    }
    Write-Host ("─" * 70)
    Write-Host ("Critical: {0}  High: {1}  Medium: {2}  Info: {3}" -f $result.counts.critical, $result.counts.high, $result.counts.medium, $result.counts.info)
    Write-Host ""
    Write-Host "Reviewer judgment still required: is HELP.md meaningful. (TSCONFIG-DIFF notes go to the review's Additional Notes — never blocking.)" -ForegroundColor DarkGray
}

# A stale or unverifiable template outranks the findings: nothing below it can be trusted,
# so callers get a distinct code rather than having to tell "module is broken" (1) apart
# from "our reference is wrong" (3).
exit ($(
    if ($freshnessOverall -in @('stale','unverified')) { 3 }
    elseif ($result.counts.critical -gt 0) { 1 }
    else { 0 }
))
