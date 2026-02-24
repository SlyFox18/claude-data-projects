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

# Teams webhook URL (Power Automate HTTP trigger). Set to "" to disable.
# Setup: flow.microsoft.com → New flow → "When an HTTP request is received" trigger
#        → "Post message in a chat or channel" (Teams) → Save → copy URL here.
$TeamsWebhookUrl = ""

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
if (-not [string]::IsNullOrEmpty($TeamsWebhookUrl)) {
    Invoke-Step "Send Teams notification" {
        $statusText = if ($FailedSteps.Count -eq 0) { "SUCCESS" } else { "FAILED" }
        $elapsed    = [math]::Round(((Get-Date) - $script:startTime).TotalSeconds)
        $payload    = @{
            date        = (Get-Date -Format "yyyy-MM-dd")
            status      = $statusText
            failedCount = $FailedSteps.Count
            failedSteps = ($FailedSteps -join ", ")
            duration    = "${elapsed}s"
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $TeamsWebhookUrl -Method Post -ContentType "application/json" -Body $payload -ErrorAction Stop
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
