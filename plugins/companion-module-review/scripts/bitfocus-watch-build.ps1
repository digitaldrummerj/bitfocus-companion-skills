#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    Watches an approved module version until its build publishes it, fails, or times out.
    Read-only — never changes anything in the portal.
.DESCRIPTION
    Approving a version in the developer portal starts a build (a GitHub Actions run in
    bitfocus/companion-bundled-modules); the version is published once that run succeeds.
    This polls the version's entry in /public/modules/companion-connection/<name>/versions
    (status, published, buildLogUrl) and, once there is a run, `gh run view` for its result.

    The version's own status is the authority: a real build failure sets it to FAILED, while
    a run can fail after publishing (only its "Report to api" step) and still leave the
    version published. That case exits 0 with a note to check the log.

    Run it in the background right after clicking Approve (review-submit skill). Anything
    other than exit 0 must be flagged to the user with the build log URL.

    Exit codes:
      0  published — the version is published (a note is added if the run itself failed)
      1  build failed — status FAILED, or the run finished without succeeding and nothing published
      2  timed out — still not published after -TimeoutMinutes
      3  the version is rejected, or not found
.PARAMETER ModuleName
    The module name without the "companion-module-" prefix (e.g. "biamp-tesira").
.PARAMETER GitTag
    The approved version's tag (e.g. "v4.0.1" or "4.0.1").
.PARAMETER TimeoutMinutes
    How long to wait for the version to publish (default 30).
.PARAMETER PollSeconds
    Seconds between checks (default 30).
.PARAMETER Json
    Emit the final result as JSON instead of console text.
.EXAMPLE
    pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/bitfocus-watch-build.ps1 -ModuleName biamp-tesira -GitTag v4.0.1
#>

param(
    [Parameter(Mandatory)][string]$ModuleName,
    [Parameter(Mandatory)][string]$GitTag,
    [int]$TimeoutMinutes = 30,
    [int]$PollSeconds = 30,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/ReviewState.ps1"

$token = gh auth token
if (-not $token) {
    Write-Error "Could not get GitHub token. Run: gh auth login"
    exit 3
}
$headers     = @{ Authorization = "Bearer $token" }
$versionsUrl = "https://developer.bitfocus.io/api/v1/public/modules/companion-connection/$ModuleName/versions"
$wantedTag   = ConvertTo-NormalizedTag $GitTag
$deadline    = [DateTimeOffset]::UtcNow.AddMinutes($TimeoutMinutes)

function Write-Status {
    param([string]$Message, [string]$Color = 'DarkGray')
    if (-not $Json) { Write-Host $Message -ForegroundColor $Color }
}

function Complete {
    param([string]$Outcome, [int]$Code, [string]$BuildLogUrl, [string]$Message, [string]$Color)
    if ($Json) {
        [pscustomobject]@{
            module      = $ModuleName
            gitTag      = $GitTag
            outcome     = $Outcome
            buildLogUrl = $BuildLogUrl
            message     = $Message
        } | ConvertTo-Json
    } else {
        Write-Host $Message -ForegroundColor $Color
        if ($BuildLogUrl) { Write-Host "Build log: $BuildLogUrl" -ForegroundColor $Color }
    }
    exit $Code
}

Write-Status "Watching the build of $ModuleName @ $GitTag (timeout $TimeoutMinutes min)..."
$lastState = $null

while ($true) {
    $versions = @((Invoke-RestMethod -Uri $versionsUrl -Headers $headers).versions)
    # A tag can be resubmitted; the newest entry is the one that was approved.
    $version = $versions |
        Where-Object { (ConvertTo-NormalizedTag $_.gitTag) -eq $wantedTag } |
        Sort-Object { [DateTimeOffset]$_.createdAt } -Descending |
        Select-Object -First 1

    if (-not $version) {
        Complete 'not-found' 3 $null "No version $GitTag found for $ModuleName." 'Red'
    }

    $runId = Get-BuildRunId $version.buildLogUrl
    $runStatus = $null
    $runConclusion = $null
    if ($runId) {
        $run = gh run view $runId -R bitfocus/companion-bundled-modules --json status,conclusion | ConvertFrom-Json
        $runStatus = $run.status
        $runConclusion = $run.conclusion
    }

    $outcome = Get-BuildOutcome -Version $version -RunStatus $runStatus -RunConclusion $runConclusion
    $state = "status=$($version.status) published=$($version.published) run=$(if ($runId) { "$runStatus/$runConclusion" } else { 'none' })"
    if ($state -ne $lastState) { Write-Status "  $state"; $lastState = $state }

    switch ($outcome) {
        'published' {
            $note = if ($runStatus -eq 'completed' -and $runConclusion -ne 'success') { " Note: the build run itself ended '$runConclusion' after publishing — worth a look at the log." } else { '' }
            Complete 'published' 0 $version.buildLogUrl "$ModuleName $GitTag built and published.$note" 'Green'
        }
        'failed'    { Complete 'failed'    1 $version.buildLogUrl "BUILD FAILED: $ModuleName $GitTag (status $($version.status), run $(if ($runId) { "$runStatus/$runConclusion" } else { 'none' })) — needs the reviewer's attention." 'Red' }
        'rejected'  { Complete 'rejected'  3 $null "$ModuleName $GitTag is rejected — there is no build to watch." 'Red' }
    }

    if ([DateTimeOffset]::UtcNow -ge $deadline) {
        Complete 'timeout' 2 $version.buildLogUrl "TIMED OUT after $TimeoutMinutes min: $ModuleName $GitTag is not published yet ($state) — needs the reviewer's attention." 'Yellow'
    }
    Start-Sleep -Seconds $PollSeconds
}
