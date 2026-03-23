<#
.SYNOPSIS
    Post-pipeline monitoring and documentation update.
    Scheduled to run at 8:00 AM weekdays, after the 6:30 AM SM pipeline finishes (~7:20 AM).

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

# Teams notification via Incoming Webhook — no auth required, works unattended.
# To regenerate: Teams channel > ... > Connectors > Incoming Webhook > Manage > Regenerate.
$TeamsEnabled = $true
$WebhookUrl   = "https://spitractor.webhook.office.com/webhookb2/75d69eaf-2d57-4c84-a71a-0d3822bb60c4@8a02a2b8-0092-4de5-8f76-4700d099feb1/IncomingWebhook/b66524e16e83467ab86db70f3bbf2ede/b9c4be2c-3707-4cdd-a7db-59751caa90d2/V2ORIHJNoD2MRxLAOTFgWkxDHey_dkvlSKH5MDa9SneJU1"

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
        $isSuccess = $FailedSteps.Count -eq 0
        $elapsed   = [math]::Round(((Get-Date) - $script:startTime).TotalSeconds)
        $date      = Get-Date -Format "yyyy-MM-dd"
        $color     = if ($isSuccess) { "00B050" } else { "FF0000" }
        $icon      = if ($isSuccess) { "[OK]" } else { "[FAIL]" }

        # Build facts list for the Teams card
        $facts = [System.Collections.Generic.List[hashtable]]::new()

        # Master pipeline status — look up ID dynamically by name so it survives recreation
        $masterWorkspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"
        try {
            $allItems     = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$masterWorkspaceId/items" -Headers $headers -Method Get -ErrorAction Stop
            $masterItem   = $allItems.value | Where-Object { $_.displayName -eq "Pipeline_Master_Orchestrator" -and $_.type -eq "DataPipeline" }
            if ($masterItem) {
                $jobsUrl      = "https://api.fabric.microsoft.com/v1/workspaces/$masterWorkspaceId/items/$($masterItem.id)/jobs/instances?jobType=Pipeline"
                $pipelineRuns  = Invoke-RestMethod -Uri $jobsUrl -Headers $headers -Method Get -ErrorAction Stop
                $todayStartUtc = (Get-Date).ToUniversalTime().Date   # midnight UTC — avoids local/UTC Kind mismatch
                $todayRuns     = $pipelineRuns.value |
                    Where-Object { $_.startTimeUtc -and [datetime]::Parse($_.startTimeUtc).ToUniversalTime() -gt $todayStartUtc } |
                    Sort-Object { [datetime]::Parse($_.startTimeUtc) } -Descending
                if ($todayRuns -and $todayRuns.Count -gt 0) {
                    $latestRun = $todayRuns[0]
                    $runStart  = ([datetime]$latestRun.startTimeUtc).ToLocalTime()
                    $pText = switch ($latestRun.status) {
                        "Succeeded"  { "Succeeded (started $($runStart.ToString('HH:mm')) CST)" }
                        "Failed"     { "FAILED - check Pipeline_Master_Orchestrator in Fabric Monitor" }
                        "InProgress" { "Still running (started $($runStart.ToString('HH:mm')) CST)" }
                        "Cancelled"  { "Cancelled" }
                        default      { "Status: $($latestRun.status)" }
                    }
                } else {
                    $pText = "Did NOT run today - no pipeline runs found"
                }
            } else {
                $pText = "Pipeline_Master_Orchestrator not found in workspace items"
            }
        } catch {
            $pText = "Could not query pipeline: $($_.Exception.Message)"
        }
        $facts.Add(@{ name = "Master Orchestrator"; value = $pText })

        # Freshness summary — only count scheduled categories; AdHoc/Transformation run manually
        $scheduledCategories = @("RawSource", "Dimension", "FactTable")
        $freshnessFile = Join-Path $DocDir "Dataflow-Freshness-Report.csv"
        if (Test-Path $freshnessFile) {
            $fr            = Import-Csv $freshnessFile | Where-Object { $_.Category -in $scheduledCategories }
            $freshCount    = ($fr | Where-Object { $_.Status -eq "Fresh" }).Count
            $staleCount    = ($fr | Where-Object { $_.Status -eq "Stale" }).Count
            $criticalItems = @($fr | Where-Object { $_.Status -in "Critical","Never Refreshed" })
            $criticalCount = $criticalItems.Count
            $facts.Add(@{ name = "Freshness (scheduled DFs)"; value = "$freshCount Fresh  |  $staleCount Stale  |  $criticalCount Critical" })
            if ($criticalCount -gt 0) {
                $names = ($criticalItems | Select-Object -ExpandProperty DataflowName | Sort-Object) -join ", "
                $facts.Add(@{ name = "Critical tables"; value = $names })
            }
        }

        # Dataflow failures in last 24 hours
        $historyFile = Join-Path $DocDir "Dataflow-Refresh-History.csv"
        if (Test-Path $historyFile) {
            $hist        = Import-Csv $historyFile
            $since       = (Get-Date).AddHours(-24)
            $recentFails = @($hist | Where-Object {
                $_.Status -in "Failed","Failure","failed" -and
                $_.StartTime -and
                [datetime]::TryParse($_.StartTime, [ref]([datetime]::MinValue)) -and
                ([datetime]$_.StartTime) -gt $since
            })
            if ($recentFails.Count -gt 0) {
                $failNames = ($recentFails | Select-Object -ExpandProperty DataflowName -Unique | Sort-Object) -join ", "
                $facts.Add(@{ name = "Dataflow failures (24h)"; value = "$($recentFails.Count) failures - $failNames" })
            } else {
                $facts.Add(@{ name = "Dataflow failures (24h)"; value = "None" })
            }
        }

        # Failed monitoring steps
        if ($FailedSteps.Count -gt 0) {
            $facts.Add(@{ name = "Monitoring steps failed"; value = $FailedSteps -join ", " })
        }

        $card = @{
            "@type"      = "MessageCard"
            "@context"   = "http://schema.org/extensions"
            "themeColor" = $color
            "summary"    = "Fabric Monitoring - $date"
            "sections"   = @(
                @{
                    "activityTitle"    = "$icon Fabric Monitoring - $date"
                    "activitySubtitle" = "Monitoring script completed in ${elapsed}s"
                    "facts"            = @($facts)
                }
            )
        }

        $body = $card | ConvertTo-Json -Depth 6 -Compress
        Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType "application/json" -Body $body -ErrorAction Stop | Out-Null
        Write-Log "   Teams notification sent via webhook"
    }
}

# ── Step 10: Windows toast notification ─────────────────────────────────────
Invoke-Step "Send desktop toast notification" {
    $date = Get-Date -Format "yyyy-MM-dd"

    # Build summary line from CSVs (same sources as Teams card)
    $scheduledCategories = @("RawSource", "Dimension", "FactTable")
    $freshnessFile = Join-Path $DocDir "Dataflow-Freshness-Report.csv"
    $historyFile   = Join-Path $DocDir "Dataflow-Refresh-History.csv"

    $freshLine = ""
    if (Test-Path $freshnessFile) {
        $fr            = Import-Csv $freshnessFile | Where-Object { $_.Category -in $scheduledCategories }
        $freshCount    = ($fr | Where-Object { $_.Status -eq "Fresh" }).Count
        $criticalCount = ($fr | Where-Object { $_.Status -in "Critical","Never Refreshed" }).Count
        $freshLine     = "$freshCount Fresh | $criticalCount Critical"
    }

    $failLine = ""
    if (Test-Path $historyFile) {
        $hist        = Import-Csv $historyFile
        $since       = (Get-Date).AddHours(-24)
        $failCount   = @($hist | Where-Object {
            $_.Status -in "Failed","Failure","failed" -and
            $_.StartTime -and
            [datetime]::TryParse($_.StartTime, [ref]([datetime]::MinValue)) -and
            ([datetime]$_.StartTime) -gt $since
        }).Count
        $failLine = "$failCount DF failures (24h)"
    }

    $titleIcon = if ($FailedSteps.Count -eq 0) { "[OK]" } else { "[FAIL]" }
    $title     = "$titleIcon Fabric Monitoring - $date"
    $body      = (@($freshLine, $failLine) | Where-Object { $_ }) -join " | "

    New-BurntToastNotification -Text $title, $body -ErrorAction Stop
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
