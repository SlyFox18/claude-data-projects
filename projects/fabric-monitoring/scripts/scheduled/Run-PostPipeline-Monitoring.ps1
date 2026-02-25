<#
.SYNOPSIS
    Post-pipeline monitoring and documentation update.
    Scheduled to run at 6:00 AM weekdays, after the 3:30 AM pipeline finishes.

.DESCRIPTION
    Runs after the Fabric Pipeline_Master_Orchestrator completes (~5:00 AM) to:
      1. Get a fresh API token
      2. Refresh dataflow inventory (current IDs from Fabric API)
      3. Log refresh history from the Fabric API
      4. Monitor data freshness (flag stale tables)
      5. Update CU usage tracking
      6. Detect workspace changes
      7. Generate monitoring dashboard
      8. Commit and push updated docs to the 'dev' branch
      9. Send Teams notification (if $TeamsWebhookUrl is set)

    Each step is independent - a failure in one step is logged but does NOT
    stop the remaining steps. Failures are written to the log file and exit
    code is non-zero if any step failed, so Task Scheduler can report it.

.NOTES
    PREREQUISITE: Run Get-FreshToken.ps1 interactively once to verify auth works.
    BRANCH: Pushes to 'dev' - review and PR to main as part of normal workflow.
#>

[CmdletBinding()]
param(
    [string]$LogPath = "$PSScriptRoot\..\..\logs\post-pipeline-$(Get-Date -Format 'yyyy-MM-dd').log"
)

$ErrorActionPreference = "SilentlyContinue"
$ScriptDir   = $PSScriptRoot
$RepoRoot    = Resolve-Path "$ScriptDir\..\.."
$ScriptsDir  = Resolve-Path "$ScriptDir\.."
$EnhancedDir = Resolve-Path "$ScriptsDir\enhanced"
$DocDir      = Resolve-Path "$RepoRoot\documentation"
$FailedSteps = @()
$script:startTime = Get-Date

# Teams notification via Microsoft.Graph module.
# Run once interactively to cache credentials:
#   Connect-MgGraph -Scopes "ChannelMessage.Send" -UseDeviceCode -TenantId $TenantId
# Then set $TeamsEnabled = $true below.
$TeamsEnabled   = $true
$TenantId       = "8a02a2b8-0092-4de5-8f76-4700d099feb1"
$TeamsTeamId    = "75d69eaf-2d57-4c84-a71a-0d3822bb60c4"
$TeamsChannelId = "19:ldjrYoLypYQcH6H4pg4TGYTzQEfcN1xHXXXd6HDcHkc1@thread.tacv2"

# ── Logging helper ──────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Log "START: $Name"
    try {
        & $Action
        Write-Log "OK:    $Name"
    } catch {
        Write-Log "FAIL:  $Name - $($_.Exception.Message)" -Level "ERROR"
        $script:FailedSteps += $Name
    }
}

# ── Begin ────────────────────────────────────────────────────────────────────
Write-Log "========================================"
Write-Log "Post-Pipeline Monitoring - Start"
Write-Log "Repo: $RepoRoot"
Write-Log "========================================"

# ── Step 1: Get fresh token ──────────────────────────────────────────────────
$token = $null
Invoke-Step "Get fresh Fabric API token" {
    $script:token = & "$ScriptDir\Get-FreshToken.ps1"
    if ([string]::IsNullOrEmpty($script:token)) { throw "Token is empty" }
    Write-Log "   Token length: $($script:token.Length) chars"
}

if (-not $token) {
    Write-Log "Cannot proceed without a valid token. Check Azure credentials." -Level "ERROR"
    exit 1
}

$headers = @{ Authorization = "Bearer $token" }

# ── Step 2: Refresh dataflow inventory ──────────────────────────────────────
# Discover-Dataflows.ps1 accepts -Token and updates Dataflow-Inventory-Discovered.csv
# with current IDs. Must run before freshness check and history log so they use valid IDs.
Invoke-Step "Refresh dataflow inventory" {
    $discoverScript = Join-Path $EnhancedDir "Discover-Dataflows.ps1"
    if (Test-Path $discoverScript) {
        & $discoverScript -Token $token -ErrorAction Stop
    } else {
        Write-Log "   Discover-Dataflows.ps1 not found - skipping"
    }
}

# ── Step 3: Log refresh history ───────────────────────────────────────────────
# Backfill-RefreshHistory.ps1 fetches per-dataflow refresh history from the Fabric API
# and appends results to Dataflow-Refresh-History.csv. It reads the token from a .token
# file rather than accepting it as a parameter, so we write it temporarily and clean up.
Invoke-Step "Log refresh history from Fabric API" {
    $backfillScript = Join-Path $EnhancedDir "Backfill-RefreshHistory.ps1"
    if (Test-Path $backfillScript) {
        $tempToken = Join-Path $ScriptsDir ".token"
        try {
            $token | Out-File $tempToken -Encoding ASCII -NoNewline
            & $backfillScript -DaysBack 1 -ErrorAction Stop
        } finally {
            Remove-Item $tempToken -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "   Backfill-RefreshHistory.ps1 not found - skipping"
    }
}

# ── Step 4: Monitor data freshness ───────────────────────────────────────────
Invoke-Step "Monitor data freshness" {
    $freshScript = Join-Path $EnhancedDir "Monitor-DataFreshness.ps1"
    if (Test-Path $freshScript) {
        & $freshScript -Token $token -ErrorAction Stop
    } else {
        Write-Log "   Monitor-DataFreshness.ps1 not found - skipping"
    }
}

# ── Step 5: Update CU usage tracking ────────────────────────────────────────
Invoke-Step "Update CU usage tracking" {
    $cuScript = Join-Path $EnhancedDir "Monitor-CUUsage.ps1"
    if (Test-Path $cuScript) {
        & $cuScript -Token $token -ErrorAction Stop
    } else {
        Write-Log "   Monitor-CUUsage.ps1 not found - skipping"
    }
}

# ── Step 6: Detect workspace changes ────────────────────────────────────────
Invoke-Step "Detect workspace changes" {
    $detectScript = Join-Path $EnhancedDir "Detect-WorkspaceChanges.ps1"
    if (Test-Path $detectScript) {
        & $detectScript -Token $token -ErrorAction Stop
    } else {
        Write-Log "   Detect-WorkspaceChanges.ps1 not found - skipping"
    }
}

# ── Step 7: Generate dashboard ───────────────────────────────────────────────
Invoke-Step "Generate monitoring dashboard" {
    $dashScript = Join-Path $EnhancedDir "Generate-Dashboard.ps1"
    if (Test-Path $dashScript) {
        & $dashScript -ErrorAction Stop
    } else {
        Write-Log "   Generate-Dashboard.ps1 not found - skipping"
    }
}

# ── Step 8: Commit and push to dev ──────────────────────────────────────────
Invoke-Step "Commit and push documentation updates to dev branch" {
    Push-Location $RepoRoot

    # Ensure we are on dev - never push to main from automation
    $branch = git branch --show-current 2>$null
    if ($branch -ne "dev") {
        git checkout dev 2>$null
        $branch = git branch --show-current 2>$null
        if ($branch -ne "dev") {
            throw "Could not switch to dev branch (currently on '$branch'). Aborting git push."
        }
    }

    # Stage documentation and log changes only (not scripts or workspace items)
    git add documentation/ logs/ 2>$null

    $status = git status --porcelain 2>$null
    if ($status) {
        $date = Get-Date -Format "yyyy-MM-dd"
        $commitMsg = "Auto-update: post-pipeline monitoring $date

Scheduled task: Run-PostPipeline-Monitoring
- Refresh history logged
- Data freshness checked
- CU usage updated
- Dashboard regenerated"
        git commit -m $commitMsg 2>$null
        git push origin dev 2>$null
        Write-Log "   Pushed documentation updates to origin/dev"
    } else {
        Write-Log "   No documentation changes to commit"
    }

    Pop-Location
}

# ── Step 9: Send Teams notification ─────────────────────────────────────────
if ($TeamsEnabled) {
    Invoke-Step "Send Teams notification" {
        $statusText = if ($FailedSteps.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $statusIcon = if ($FailedSteps.Count -eq 0) { "&#x2705;" } else { "&#x274C;" }
        $elapsed    = [math]::Round(((Get-Date) - $script:startTime).TotalSeconds)
        $date       = Get-Date -Format "yyyy-MM-dd"

        # Pull freshness stats from the report written by Step 4
        $freshnessLine = ""
        $criticalLine  = ""
        $pipelineLine  = ""
        $freshnessFile = Join-Path $DocDir "Dataflow-Freshness-Report.csv"
        if (Test-Path $freshnessFile) {
            $fr           = Import-Csv $freshnessFile
            $freshCount   = ($fr | Where-Object { $_.Status -eq "Fresh" }).Count
            $staleCount   = ($fr | Where-Object { $_.Status -eq "Stale" }).Count
            $criticalCount= ($fr | Where-Object { $_.Status -eq "Critical" -or $_.Status -eq "Never Refreshed" }).Count
            $freshnessLine = "<br><b>Freshness:</b> &#x1F7E2; $freshCount Fresh &nbsp; &#x1F7E1; $staleCount Stale &nbsp; &#x1F534; $criticalCount Critical"
            if ($criticalCount -gt 0) {
                $names = ($fr | Where-Object { $_.Status -eq "Critical" -or $_.Status -eq "Never Refreshed" } |
                    Select-Object -ExpandProperty DataflowName | Sort-Object) -join ", "
                $criticalLine = "<br><b>Critical:</b> $names"
            }

        }

        # Check Pipeline_Master_Orchestrator run status via Fabric Pipeline API
        $masterWorkspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"
        $masterPipelineId  = "52f5270a-4ac9-9f33-4a70-56fd291983ff"
        $pipelineJobsUrl   = "https://api.fabric.microsoft.com/v1/workspaces/$masterWorkspaceId/items/$masterPipelineId/jobs/instances?jobType=Pipeline"
        try {
            $pipelineRuns = Invoke-RestMethod -Uri $pipelineJobsUrl -Headers $headers -Method Get -ErrorAction Stop
            $todayStart   = (Get-Date).Date
            $todayRuns    = $pipelineRuns.value |
                Where-Object { $_.startTimeUtc -and [datetime]$_.startTimeUtc -gt $todayStart } |
                Sort-Object { [datetime]$_.startTimeUtc } -Descending
            if ($todayRuns -and $todayRuns.Count -gt 0) {
                $latestRun = $todayRuns[0]
                $runStart  = ([datetime]$latestRun.startTimeUtc).ToLocalTime()
                $pIcon = switch ($latestRun.status) {
                    "Succeeded"  { "&#x2705;" }
                    "Failed"     { "&#x274C;" }
                    "InProgress" { "&#x23F3;" }
                    "Cancelled"  { "&#x26A0;" }
                    default      { "&#x26A0;" }
                }
                $pText = switch ($latestRun.status) {
                    "Succeeded"  { "Succeeded (started $($runStart.ToString('HH:mm')) CST)" }
                    "Failed"     { "FAILED &#x2014; check Pipeline_Master_Orchestrator run history" }
                    "InProgress" { "Still running (started $($runStart.ToString('HH:mm')) CST)" }
                    "Cancelled"  { "Cancelled" }
                    default      { "Unknown status: $($latestRun.status)" }
                }
            } else {
                $pIcon = "&#x274C;"
                $pText = "Did NOT run today &#x2014; no pipeline runs found"
            }
        } catch {
            $pIcon = "&#x26A0;"
            $pText = "Could not check pipeline status: $($_.Exception.Message)"
        }
        $pipelineLine = "<br><b>Pipeline:</b> $pIcon $pText"

        # Failed steps line
        $failedLine = if ($FailedSteps.Count -gt 0) {
            "<br><b>Failed steps:</b> $($FailedSteps -join ', ')"
        } else { "" }

        $html = "$statusIcon <b>Fabric Monitoring &mdash; $date</b>" +
                "<br>Monitoring: $statusText &nbsp;&nbsp; Duration: ${elapsed}s" +
                $pipelineLine + $freshnessLine + $criticalLine + $failedLine

        Connect-MgGraph -TenantId $TenantId -NoWelcome -ErrorAction Stop
        $body = @{ body = @{ contentType = "html"; content = $html } }
        New-MgTeamChannelMessage -TeamId $TeamsTeamId -ChannelId $TeamsChannelId -BodyParameter $body -ErrorAction Stop
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Log "========================================"
if ($FailedSteps.Count -eq 0) {
    Write-Log "Post-Pipeline Monitoring - COMPLETED SUCCESSFULLY"
} else {
    Write-Log "Post-Pipeline Monitoring - COMPLETED WITH $($FailedSteps.Count) FAILURE(S)" -Level "ERROR"
    Write-Log "Failed steps: $($FailedSteps -join ', ')" -Level "ERROR"
}
Write-Log "========================================"

# Exit non-zero if any step failed (Task Scheduler sees this as a failure)
if ($FailedSteps.Count -gt 0) { exit 1 }
exit 0
