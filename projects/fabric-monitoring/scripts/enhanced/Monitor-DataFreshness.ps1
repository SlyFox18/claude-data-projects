<#
.SYNOPSIS
    Monitors data freshness for all dataflows
.DESCRIPTION
    Checks when each dataflow was last refreshed and flags stale data
.EXAMPLE
    .\Monitor-DataFreshness.ps1
    .\Monitor-DataFreshness.ps1 -AlertThresholdHours 48
#>

param(
    [string]$Token = "",
    [string]$WorkspaceName = "LH_Master_Data",
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation",
    [int]$AlertThresholdHours = 36,
    [int]$CriticalThresholdHours = 72
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Data Freshness Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get token
if ([string]::IsNullOrEmpty($Token)) {
    $tokenFile = Join-Path $PSScriptRoot "..\\.token"
    if (Test-Path $tokenFile) {
        $Token = Get-Content $tokenFile -Raw
        $Token = $Token.Trim().Replace("`r","").Replace("`n","")
    } else {
        Write-Host "[ERROR] No token found" -ForegroundColor Red
        exit 1
    }
}

# Setup headers
$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

# Get workspace
$workspacesFile = Join-Path $DocumentationPath "workspaces.json"
$workspaces = Get-Content $workspacesFile | ConvertFrom-Json
$targetWorkspace = $workspaces | Where-Object { $_.displayName -eq $WorkspaceName }

if (-not $targetWorkspace) {
    Write-Host "[ERROR] Workspace not found: $WorkspaceName" -ForegroundColor Red
    exit 1
}

$workspaceId = $targetWorkspace.id

Write-Host "[INFO] Workspace: $WorkspaceName" -ForegroundColor Cyan
Write-Host "[INFO] Alert Threshold: $AlertThresholdHours hours" -ForegroundColor Gray
Write-Host "[INFO] Critical Threshold: $CriticalThresholdHours hours" -ForegroundColor Gray
Write-Host ""

# Load inventory
$inventoryFile = Join-Path $DocumentationPath "Dataflow-Inventory-Discovered.csv"
if (-not (Test-Path $inventoryFile)) {
    Write-Host "[ERROR] Inventory not found. Run Discover-Dataflows.ps1 first" -ForegroundColor Red
    exit 1
}

$inventory = Import-Csv $inventoryFile
$activeDataflows = $inventory | Where-Object { $_.Status -eq "Active" }

Write-Host "[INFO] Checking freshness for $($activeDataflows.Count) active dataflows..." -ForegroundColor Cyan
Write-Host ""

# Check each dataflow
$freshnessData = @()
$staleDataflows = @()
$criticalDataflows = @()

foreach ($df in $activeDataflows) {
    Write-Host "Checking: $($df.DataflowName)" -ForegroundColor Gray
    
    try {
        # Get refresh history for this dataflow (jobs/instances endpoint works for Dataflow Gen2)
        $refreshUrl = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$($df.DataflowId)/jobs/instances?jobType=Refresh"
        $refreshHistory = Invoke-RestMethod -Uri $refreshUrl -Headers $headers -Method Get

        # Handle paged response (.value array) — Fabric returns startTimeUtc/endTimeUtc
        $refreshItems = if ($null -ne $refreshHistory.value) { $refreshHistory.value } else { @() }
        # Sort descending to get the most recent first
        $refreshItems = $refreshItems | Where-Object { $_.startTimeUtc } | Sort-Object { [datetime]$_.startTimeUtc } -Descending

        if ($refreshItems -and $refreshItems.Count -gt 0) {
            $lastRefresh = $refreshItems[0]
            $lastRefreshTime = [datetime]::Parse($lastRefresh.endTimeUtc)
            $hoursAgo = [math]::Round(((Get-Date) - $lastRefreshTime).TotalHours, 1)
            
            # Determine status
            $status = "Fresh"
            $statusColor = "Green"
            
            if ($hoursAgo -gt $CriticalThresholdHours) {
                $status = "Critical"
                $statusColor = "Red"
                $criticalDataflows += $df.DataflowName
            } elseif ($hoursAgo -gt $AlertThresholdHours) {
                $status = "Stale"
                $statusColor = "Yellow"
                $staleDataflows += $df.DataflowName
            }
            
            Write-Host "  Last Refresh: $lastRefreshTime ($hoursAgo hours ago) - $status" -ForegroundColor $statusColor
            
            $freshnessData += [PSCustomObject]@{
                DataflowName = $df.DataflowName
                Category = $df.Category
                RefreshFrequency = $df.RefreshFrequency
                LastRefreshTime = $lastRefreshTime.ToString('yyyy-MM-dd HH:mm:ss')
                HoursAgo = $hoursAgo
                Status = $status
                LastRefreshStatus = $lastRefresh.status
            }
            
        } elseif ($refreshItems.Count -eq 0) {
            Write-Host "  Never refreshed" -ForegroundColor Red
            
            $freshnessData += [PSCustomObject]@{
                DataflowName = $df.DataflowName
                Category = $df.Category
                RefreshFrequency = $df.RefreshFrequency
                LastRefreshTime = "Never"
                HoursAgo = 999999
                Status = "Never Refreshed"
                LastRefreshStatus = "N/A"
            }
            
            $criticalDataflows += $df.DataflowName
        }
        
    } catch {
        Write-Host "  [ERROR] Failed to check: $($_.Exception.Message)" -ForegroundColor Red
        
        $freshnessData += [PSCustomObject]@{
            DataflowName = $df.DataflowName
            Category = $df.Category
            RefreshFrequency = $df.RefreshFrequency
            LastRefreshTime = "Error"
            HoursAgo = 0
            Status = "Error"
            LastRefreshStatus = "Error"
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Freshness Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$freshCount = ($freshnessData | Where-Object { $_.Status -eq "Fresh" }).Count
$staleCount = ($freshnessData | Where-Object { $_.Status -eq "Stale" }).Count
$criticalCount = ($freshnessData | Where-Object { $_.Status -eq "Critical" -or $_.Status -eq "Never Refreshed" }).Count

Write-Host "Fresh: $freshCount" -ForegroundColor Green
Write-Host "Stale: $staleCount" -ForegroundColor Yellow
Write-Host "Critical: $criticalCount" -ForegroundColor Red
Write-Host ""

# Save to CSV
$freshnessFile = Join-Path $DocumentationPath "Dataflow-Freshness-Report.csv"
$freshnessData | Export-Csv -Path $freshnessFile -NoTypeInformation -Encoding UTF8
Write-Host "[SUCCESS] Freshness report saved: $freshnessFile" -ForegroundColor Green

# Generate markdown report
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("# Data Freshness Report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("**Workspace:** $WorkspaceName")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Summary
[void]$sb.AppendLine("## Summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Status | Count | Percentage |")
[void]$sb.AppendLine("|--------|-------|------------|")
[void]$sb.AppendLine("| Fresh | $freshCount | $([math]::Round(($freshCount / $activeDataflows.Count) * 100, 1))% |")
[void]$sb.AppendLine("| Stale | $staleCount | $([math]::Round(($staleCount / $activeDataflows.Count) * 100, 1))% |")
[void]$sb.AppendLine("| Critical | $criticalCount | $([math]::Round(($criticalCount / $activeDataflows.Count) * 100, 1))% |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Alert Threshold:** $AlertThresholdHours hours")
[void]$sb.AppendLine("**Critical Threshold:** $CriticalThresholdHours hours")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Critical dataflows
if ($criticalCount -gt 0) {
    [void]$sb.AppendLine("## Critical - Immediate Attention Required")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("The following dataflows need immediate attention:")
    [void]$sb.AppendLine("")
    
    $critical = $freshnessData | Where-Object { $_.Status -eq "Critical" -or $_.Status -eq "Never Refreshed" } | Sort-Object HoursAgo -Descending
    
    foreach ($df in $critical) {
        if ($df.LastRefreshTime -eq "Never") {
            [void]$sb.AppendLine("- **$($df.DataflowName)** ($($df.Category)) - Never refreshed!")
        } else {
            [void]$sb.AppendLine("- **$($df.DataflowName)** ($($df.Category)) - Last refreshed: $($df.LastRefreshTime) ($($df.HoursAgo) hours ago)")
        }
    }
    
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

# Stale dataflows
if ($staleCount -gt 0) {
    [void]$sb.AppendLine("## Stale - Monitor Closely")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("The following dataflows are approaching staleness:")
    [void]$sb.AppendLine("")
    
    $stale = $freshnessData | Where-Object { $_.Status -eq "Stale" } | Sort-Object HoursAgo -Descending
    
    foreach ($df in $stale) {
        [void]$sb.AppendLine("- **$($df.DataflowName)** ($($df.Category)) - Last refreshed: $($df.LastRefreshTime) ($($df.HoursAgo) hours ago)")
    }
    
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
}

# All dataflows by category
[void]$sb.AppendLine("## Freshness by Category")
[void]$sb.AppendLine("")

$byCategory = $freshnessData | Group-Object Category | Sort-Object Name

foreach ($cat in $byCategory) {
    [void]$sb.AppendLine("### $($cat.Name)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Dataflow | Last Refresh | Hours Ago | Status |")
    [void]$sb.AppendLine("|----------|--------------|-----------|--------|")
    
    foreach ($df in $cat.Group | Sort-Object HoursAgo -Descending) {
        $statusIcon = switch ($df.Status) {
            "Fresh" { "[OK]" }
            "Stale" { "[WARN]" }
            "Critical" { "[CRIT]" }
            "Never Refreshed" { "[NEVER]" }
            default { "[?]" }
        }
        
        [void]$sb.AppendLine("| $($df.DataflowName) | $($df.LastRefreshTime) | $($df.HoursAgo) | $statusIcon $($df.Status) |")
    }
    
    [void]$sb.AppendLine("")
}

[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**CSV Report:** ``Dataflow-Freshness-Report.csv``")

$mdFile = Join-Path $DocumentationPath "FRESHNESS-REPORT.md"
$sb.ToString() | Out-File $mdFile -Encoding UTF8

Write-Host "[SUCCESS] Markdown report created: $mdFile" -ForegroundColor Green
Write-Host ""

# Alert summary
if ($criticalCount -gt 0) {
    Write-Host "[ALERT] $criticalCount dataflows require immediate attention!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Critical Dataflows:" -ForegroundColor Red
    foreach ($df in $criticalDataflows) {
        Write-Host "  - $df" -ForegroundColor Red
    }
    Write-Host ""
}

if ($staleCount -gt 0) {
    Write-Host "[WARNING] $staleCount dataflows are stale" -ForegroundColor Yellow
    Write-Host ""
}

if ($criticalCount -eq 0 -and $staleCount -eq 0) {
    Write-Host "[SUCCESS] All dataflows are fresh!" -ForegroundColor Green
    Write-Host ""
}

# Return status for automation
if ($criticalCount -gt 0) {
    exit 1  # Critical issues found
} else {
    exit 0  # All good
}