#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Self-contained tests for scripts/lib/ReviewState.ps1 — no Pester required.
.DESCRIPTION
    Builds an isolated fixture (temp reviews/ + TRACKER.md + fake review files),
    exercises Get-TrackerRows / Get-ReviewState across every state and the known
    edge cases, and exits non-zero on any failure.

    Run:  pwsh plugins/companion-module-review/scripts/tests/ReviewState.Tests.ps1
#>

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../lib/ReviewState.ps1"

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Because)
    if ($Expected -eq $Actual) {
        $script:pass++
        Write-Host "  PASS  $Because" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "  FAIL  $Because (expected '$Expected', got '$Actual')" -ForegroundColor Red
    }
}

# ── Build fixture ────────────────────────────────────────────────────────────
$root = Join-Path ([System.IO.Path]::GetTempPath()) "reviewstate-test-$([System.IO.Path]::GetRandomFileName())"
$reviews = Join-Path $root "reviews"
$tracker = Join-Path $reviews "TRACKER.md"

function New-ReviewFile {
    param([string]$Module, [string]$Tag, [string]$Stamp)
    $dir = Join-Path $reviews $Module
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $dir "review-$Module-$Tag-$Stamp.md") -Force | Out-Null
}

try {
    New-Item -ItemType Directory -Path $reviews -Force | Out-Null

    # Review files
    New-ReviewFile 'alpha-mod'   'v1.0.0'  '20260101-000000'   # + submitted row  => re-review
    New-ReviewFile 'beta-mod'    'v2.0.0'  '20260201-000000'   # + unsubmitted row => feedback-pending
    New-ReviewFile 'gamma-mod'   'v1.0.0'  '20260301-000000'   # + two submitted rows => re-review
    New-ReviewFile 'epsilon-mod' 'v3.0.0'  '20260401-000000'   # file only, no row => feedback-pending
    New-ReviewFile 'zeta-mod'    'v1.0.0'  '20260501-000000'   # prefix-collision pair
    New-ReviewFile 'zeta-mod'    'v1.0.10' '20260502-000000'

    @'
# Module Review Tracker

| Feedback Submitted | Module | Version | Review Date | Review File |
|:-----------------:|--------|---------|-------------|-------------|
| ✅ | alpha-mod | v1.0.0 | 2026-01-01 | [review](alpha-mod/review-alpha-mod-v1.0.0-20260101-000000.md) |
| ⬜ | beta-mod | v2.0.0 | 2026-02-01 | [review](beta-mod/review-beta-mod-v2.0.0-20260201-000000.md) |
| ✅ | gamma-mod | v1.0.0 | 2026-03-01 | [review](gamma-mod/review-gamma-mod-v1.0.0-20260301-000000.md) |
| ✅ | gamma-mod | v1.0.0 | 2026-03-15 | [review](gamma-mod/review-gamma-mod-v1.0.0-20260315-000000.md) |
| ✅ | delta-mod | v1.2.1 | 2026-04-20 | published.  manual review. |
'@ | Set-Content -LiteralPath $tracker -Encoding utf8

    # ── Tests ────────────────────────────────────────────────────────────────
    Write-Host "Get-TrackerRows"
    $rows = @(Get-TrackerRows -TrackerPath $tracker)
    Assert-Equal 5 $rows.Count "parses 5 data rows (skips header + separator)"
    Assert-Equal $true ($rows | Where-Object { $_.Module -eq 'alpha-mod' }).Submitted "alpha-mod row is submitted"
    Assert-Equal $false ($rows | Where-Object { $_.Module -eq 'beta-mod' }).Submitted "beta-mod row is not submitted"
    Assert-Equal 'delta-mod' ($rows | Where-Object { $_.Version -eq 'v1.2.1' }).Module "freeform-cell row still parses"

    Write-Host "Get-ReviewState"
    function State($m, $t) {
        (Get-ReviewState -ReviewsDir $reviews -TrackerPath $tracker -ModuleName $m -GitTag $t -TrackerRows $rows)
    }

    Assert-Equal 're-review'        (State 'alpha-mod'   'v1.0.0').State  "alpha: file + submitted => re-review"
    Assert-Equal 're-review'        (State 'alpha-mod'   '1.0.0' ).State  "alpha: v-insensitive match"
    Assert-Equal 'feedback-pending' (State 'beta-mod'    'v2.0.0').State  "beta: file + unsubmitted => feedback-pending"
    Assert-Equal 're-review'        (State 'gamma-mod'   'v1.0.0').State  "gamma: two submitted rows => re-review"
    Assert-Equal 'feedback-pending' (State 'epsilon-mod' 'v3.0.0').State  "epsilon: file only, no row => feedback-pending"
    Assert-Equal 're-review'        (State 'delta-mod'   'v1.2.1').State  "delta: submitted row, no file => re-review"
    Assert-Equal 'needs-review'     (State 'omega-mod'   'v9.9.9').State  "omega: unknown => needs-review"
    Assert-Equal 'needs-review'     (State 'beta-mod'    'v9.9.9').State  "beta unknown tag => needs-review"

    # Prefix collision: v1.0.0 must not match v1.0.10
    Assert-Equal 1 (State 'zeta-mod' 'v1.0.0' ).ReviewFiles.Count "zeta v1.0.0 matches exactly 1 file"
    Assert-Equal 1 (State 'zeta-mod' 'v1.0.10').ReviewFiles.Count "zeta v1.0.10 matches exactly 1 file"

    # TrackerSubmitted nullability
    Assert-Equal $null (State 'epsilon-mod' 'v3.0.0').TrackerSubmitted "epsilon: no row => TrackerSubmitted null"
    Assert-Equal $false (State 'beta-mod' 'v2.0.0').TrackerSubmitted "beta: unsubmitted row => TrackerSubmitted false"

    # ── Resolve-CompanionBaseVersion ─────────────────────────────────────────
    # The installed version must win over the declared range, because the API level the
    # module really builds against is what decides which compliance rules apply.
    Write-Host "Resolve-CompanionBaseVersion"
    function New-VerModule {
        param([string]$Name, [string]$Range, [hashtable]$Files = @{})
        $d = Join-Path $root "ver-$Name"
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        $deps = if ($null -ne $Range) { "`"dependencies`":{`"@companion-module/base`":`"$Range`"}" } else { "`"dependencies`":{}" }
        Set-Content -LiteralPath (Join-Path $d 'package.json') -Value "{`"name`":`"$Name`",$deps}" -Encoding utf8
        foreach ($k in $Files.Keys) {
            $p = Join-Path $d $k
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value $Files[$k] -Encoding utf8
        }
        return $d
    }

    $berry = @'
"@companion-module/base@npm:~2.1.3":
  version: 2.1.3
  resolution: "@companion-module/base@npm:2.1.3"
'@
    $r = Resolve-CompanionBaseVersion (New-VerModule 'berry' '~2.1.0' @{ 'yarn.lock' = $berry })
    Assert-Equal '2.1.3'     $r.version  "yarn Berry lockfile: resolved version"
    Assert-Equal 'yarn.lock' $r.source   "yarn Berry lockfile: source"
    Assert-Equal '2.1'       $r.apiLevel "yarn Berry lockfile: apiLevel 2.1"
    Assert-Equal $false      $r.ambiguous "lockfile version is never ambiguous"

    # Lockfile beats a caret range: ^2.0.0 alone would be ambiguous, the lockfile says 2.1.
    $r = Resolve-CompanionBaseVersion (New-VerModule 'berry-caret' '^2.0.0' @{ 'yarn.lock' = "`"@companion-module/base@npm:^2.0.0`":`n  version: 2.1.1`n" })
    Assert-Equal '2.1' $r.apiLevel "caret range + lockfile => lockfile's 2.1"
    Assert-Equal $false $r.ambiguous "caret range resolved by lockfile is not ambiguous"

    # Two resolutions (a transitive copy too): the one matching the package.json range wins.
    $two = "`"@companion-module/base@npm:~1.14.1`":`n  version: 1.14.1`n`n`"@companion-module/base@npm:~2.0.4`":`n  version: 2.0.4`n"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'berry-two' '~2.0.4' @{ 'yarn.lock' = $two })
    Assert-Equal '2.0.4' $r.version "two lockfile entries: the one for the package.json range wins"

    $yarn1 = "`"@companion-module/base@~1.12.1`":`n  version `"1.12.1`"`n  resolved `"https://registry.yarnpkg.com/x`"`n"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'yarn1' '~1.12.1' @{ 'yarn.lock' = $yarn1 })
    Assert-Equal '1.12.1' $r.version  "yarn 1 lockfile: resolved version"
    Assert-Equal '1'      $r.apiLevel "v1 apiLevel is '1'"

    $npm = '{"lockfileVersion":3,"packages":{"":{},"node_modules/@companion-module/base":{"version":"2.0.4"}}}'
    $r = Resolve-CompanionBaseVersion (New-VerModule 'npm' '^2.0.0' @{ 'package-lock.json' = $npm })
    Assert-Equal '2.0.4'             $r.version "package-lock.json: resolved version"
    Assert-Equal 'package-lock.json' $r.source  "package-lock.json: source"

    $pnpm = "lockfileVersion: '9.0'`nimporters:`n  .:`n    dependencies:`n      '@companion-module/base':`n        specifier: ~2.1.3`n        version: 2.1.3`n"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'pnpm' '~2.1.3' @{ 'pnpm-lock.yaml' = $pnpm })
    Assert-Equal '2.1.3'          $r.version "pnpm-lock.yaml: resolved version"
    Assert-Equal 'pnpm-lock.yaml' $r.source  "pnpm-lock.yaml: source"

    # A stub lockfile (no entry) falls through to node_modules.
    $r = Resolve-CompanionBaseVersion (New-VerModule 'nm' '^2.0.0' @{ 'yarn.lock' = '# yarn lockfile'; 'node_modules/@companion-module/base/package.json' = '{"version":"2.1.0"}' })
    Assert-Equal '2.1.0'        $r.version "stub lockfile falls through to node_modules"
    Assert-Equal 'node_modules' $r.source  "node_modules: source"

    # package.json range only
    $r = Resolve-CompanionBaseVersion (New-VerModule 'exact' '2.0.4')
    Assert-Equal '2.0'   $r.apiLevel  "exact range 2.0.4 => 2.0"
    Assert-Equal $false  $r.ambiguous "exact range is not ambiguous"
    Assert-Equal 'package.json range' $r.source "range-only: source"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'tilde' '~2.1.3')
    Assert-Equal '2.1'  $r.apiLevel  "tilde range ~2.1.3 => 2.1"
    Assert-Equal $false $r.ambiguous "tilde range is not ambiguous"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'xrange' '2.1.x')
    Assert-Equal '2.1'  $r.apiLevel  "x-range 2.1.x => 2.1"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'caret' '^2.0.0')
    Assert-Equal '2.0'  $r.apiLevel  "caret range ^2.0.0 => lowest minor, 2.0"
    Assert-Equal $true  $r.ambiguous "caret range on v2 is ambiguous"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'caret1' '^1.12.1')
    Assert-Equal '1'    $r.apiLevel  "caret range ^1.12.1 => 1"
    Assert-Equal $false $r.ambiguous "v1 is never ambiguous (one v1 skill)"
    $r = Resolve-CompanionBaseVersion (New-VerModule 'nodep' $null)
    Assert-Equal '2.0'  $r.apiLevel  "no base dependency keeps the old v2 default"
    Assert-Equal 'none' $r.source    "no base dependency: source none"
    Assert-Equal $true  $r.ambiguous "no base dependency is ambiguous"

    # ── Get-CompanionApiProfile ──────────────────────────────────────────────
    Write-Host "Get-CompanionApiProfile"
    $p = Get-CompanionApiProfile -ApiLevel '1'
    Assert-Equal 'companion-v1-api-compliance' $p.apiSkill "v1 => v1 skill"
    Assert-Equal 0 @($p.apiReferences).Count "v1 => no reference files"
    Assert-Equal $null $p.allowedRuntimes "v1 runtimes stay template-judged"
    $p = Get-CompanionApiProfile -ApiLevel '2.0'
    Assert-Equal 'companion-v2-api-compliance' $p.apiSkill "2.0 => v2 skill"
    Assert-Equal 'references/v2.0.md' (@($p.apiReferences) -join ',') "2.0 => only references/v2.0.md"
    Assert-Equal '4.3' $p.minCompanion "2.0 => Companion 4.3+"
    Assert-Equal 'node22' (@($p.allowedRuntimes) -join ',') "2.0 => node22 only"
    Assert-Equal 1 @($p.allowedRuntimes).Count "2.0 allowedRuntimes stays a list"
    $p = Get-CompanionApiProfile -ApiLevel '2.1'
    Assert-Equal 'references/v2.0.md,references/v2.1.md' (@($p.apiReferences) -join ',') "2.1 => v2.0 + v2.1 references"
    Assert-Equal '5.0' $p.minCompanion "2.1 => Companion 5.0+"
    Assert-Equal 'node22,node26' (@($p.allowedRuntimes) -join ',') "2.1 => node22 + node26"

    $skills = Join-Path $root 'skills'
    New-Item -ItemType Directory -Path (Join-Path $skills 'companion-v2-api-compliance/references') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skills 'companion-v2-api-compliance/references/v2.0.md') -Value 'x'
    Set-Content -LiteralPath (Join-Path $skills 'companion-v2-api-compliance/references/v2.1.md') -Value 'x'
    $p = Get-CompanionApiProfile -ApiLevel '2.2' -SkillsDir $skills
    Assert-Equal 'references/v2.2.md' (@($p.referencesMissing) -join ',') "2.2 with no v2.2.md => reported missing"
    Assert-Equal $null $p.minCompanion "unknown future level => no guessed Companion version"
    $p = Get-CompanionApiProfile -ApiLevel '2.1' -SkillDir (Join-Path $skills 'companion-v2-api-compliance')
    Assert-Equal 0 @($p.referencesMissing).Count "-SkillDir (the plugin's own dir) checks references there"

    # ── Resolve-ReviewWorkspace ──────────────────────────────────────────────
    # The scripts ship in a plugin, so the workspace is wherever they're run from.
    Write-Host "Resolve-ReviewWorkspace"
    $prevRoot = $env:COMPANION_REVIEW_ROOT
    try {
        $env:COMPANION_REVIEW_ROOT = $null
        $ws = Join-Path $root 'ws'
        New-Item -ItemType Directory -Path (Join-Path $ws 'reviews') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ws 'companion-modules-reviewing/companion-module-x/src') -Force | Out-Null
        $wsReal = (Resolve-Path $ws).Path
        Assert-Equal $wsReal (Resolve-ReviewWorkspace -StartDir $ws) "a directory with reviews/ is the workspace"
        Assert-Equal $wsReal (Resolve-ReviewWorkspace -StartDir (Join-Path $ws 'companion-modules-reviewing/companion-module-x/src')) "found from a nested directory (nearest ancestor with reviews/)"

        # A module clone is its own git repo without reviews/: the search continues upward.
        & git -C (Join-Path $ws 'companion-modules-reviewing/companion-module-x') init -q 2>$null
        Assert-Equal $wsReal (Resolve-ReviewWorkspace -StartDir (Join-Path $ws 'companion-modules-reviewing/companion-module-x')) "from inside a module clone (its own git repo) the workspace is still found"

        # Outside the fixture root (which itself holds a reviews/ folder).
        $other = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-workspace-$([System.IO.Path]::GetRandomFileName())"
        New-Item -ItemType Directory -Path $other -Force | Out-Null
        Assert-Equal $null (Resolve-ReviewWorkspace -StartDir $other -Optional) "-Optional returns `$null outside a workspace"
        $msg = try { Resolve-ReviewWorkspace -StartDir $other; '' } catch { $_.Exception.Message }
        Assert-Equal $true ($msg -match 'COMPANION_REVIEW_ROOT' -and $msg -match 'reviews/') "outside a workspace the error says how to fix it"

        $env:COMPANION_REVIEW_ROOT = $ws
        Assert-Equal $wsReal (Resolve-ReviewWorkspace -StartDir $other) "COMPANION_REVIEW_ROOT overrides the current directory"
        $env:COMPANION_REVIEW_ROOT = (Join-Path $root 'missing-dir')
        $msg = try { Resolve-ReviewWorkspace; '' } catch { $_.Exception.Message }
        Assert-Equal $true ($msg -match 'does not exist') "a COMPANION_REVIEW_ROOT that doesn't exist is an error"
    } finally {
        $env:COMPANION_REVIEW_ROOT = $prevRoot
        if ($other -and (Test-Path $other)) { Remove-Item -Recurse -Force $other }
    }

    # ── Resolve-SkillDir ─────────────────────────────────────────────────────
    Write-Host "Resolve-SkillDir"
    $prevSkills = $env:COMPANION_SKILLS_DIR
    try {
        function New-Skill($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value '---' ; (Resolve-Path $dir).Path }
        $fakeClaude = Join-Path $root 'claude'
        $noRoot = Join-Path $root 'nowhere/plugin'   # a PluginRoot whose siblings don't exist
        $env:COMPANION_SKILLS_DIR = $null

        Assert-Equal $null (Resolve-SkillDir -Plugin 'companion-v2-api-compliance' -ClaudeDir $fakeClaude -PluginRoot $noRoot) "not installed anywhere => `$null"

        $cacheBase = Join-Path $fakeClaude 'plugins/cache/bitfocus-companion-skills/companion-v2-api-compliance'
        $old = New-Skill (Join-Path $cacheBase '1.1.2')
        $new = New-Skill (Join-Path $cacheBase '1.1.10')
        New-Item -ItemType Directory -Path (Join-Path $cacheBase '9.9.9') -Force | Out-Null   # no SKILL.md: ignored
        Assert-Equal $new (Resolve-SkillDir -Plugin 'companion-v2-api-compliance' -ClaudeDir $fakeClaude -PluginRoot $noRoot) "plugin cache => highest version with a SKILL.md (1.1.10 > 1.1.2)"

        $installedPath = New-Skill (Join-Path $fakeClaude 'elsewhere/companion-v2-api-compliance')
        $json = @{ version = 2; plugins = @{ 'companion-v2-api-compliance@bitfocus-companion-skills' = @(@{ scope = 'user'; installPath = $installedPath; version = '1.1.3' }) } } | ConvertTo-Json -Depth 6
        New-Item -ItemType Directory -Path (Join-Path $fakeClaude 'plugins') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fakeClaude 'plugins/installed_plugins.json') -Value $json
        Assert-Equal $installedPath (Resolve-SkillDir -Plugin 'companion-v2-api-compliance' -ClaudeDir $fakeClaude -PluginRoot $noRoot) "installed_plugins.json installPath beats the cache scan"

        $checkout = Join-Path $root 'checkout/plugins'
        $sibling = New-Skill (Join-Path $checkout 'companion-v2-api-compliance')
        Assert-Equal $sibling (Resolve-SkillDir -Plugin 'companion-v2-api-compliance' -ClaudeDir $fakeClaude -PluginRoot (Join-Path $checkout 'companion-module-review')) "a sibling plugin in a source checkout beats the installed copy"

        $override = Join-Path $root 'override'
        $envSkill = New-Skill (Join-Path $override 'companion-v2-api-compliance')
        $env:COMPANION_SKILLS_DIR = $override
        Assert-Equal $envSkill (Resolve-SkillDir -Plugin 'companion-v2-api-compliance' -ClaudeDir $fakeClaude -PluginRoot (Join-Path $checkout 'companion-module-review')) "COMPANION_SKILLS_DIR beats everything"
    } finally {
        $env:COMPANION_SKILLS_DIR = $prevSkills
    }
}
finally {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}

Write-Host ""
Write-Host "$($script:pass) passed, $($script:fail) failed" -ForegroundColor ($(if ($script:fail) { 'Red' } else { 'Green' }))
if ($script:fail) { exit 1 }
