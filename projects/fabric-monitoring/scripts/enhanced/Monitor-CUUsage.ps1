<#
.SYNOPSIS
    Monitors Fabric Capacity Unit (CU) usage
.DESCRIPTION
    Tracks CU consumption, identifies expensive operations, and alerts on high usage
.EXAMPLE
    .\Monitor-CUUsage.ps1
    .\Monitor-CUUsage.ps1 -Hours 24
#>

param(
    [string]$Token = "",
    [int]$Hours = 24,
    [string]$CapacityId = "",
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation",
    [double]$HighUsageThresholdCU = 100,
    [double]$CriticalUsageThresholdCU = 500
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CU Usage Monitor" -ForegroundColor Cyan
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

Write-Host "[INFO] Monitoring CU usage for last $Hours hours" -ForegroundColor Cyan
Write-Host ""

# Get capacity information
try {
    Write-Host "[INFO] Retrieving capacity information..." -ForegroundColor Gray
    
    # Get capacities
    $capacitiesUrl = "https://api.fabric.microsoft.com/v1/capacities"
    $capacities = Invoke-RestMethod -Uri $capacitiesUrl -Headers $headers -Method Get
    
    if ($capacities.value.Count -eq 0) {
        Write-Host "[ERROR] No capacities found" -ForegroundColor Red
        exit 1
    }
    
    # Use first capacity or specified one
    $capacity = if ($CapacityId) {
        $capacities.value | Where-Object { $_.id -eq $CapacityId }
    } else {
        $capacities.value | Select-Object -First 1
    }
    
    if (-not $capacity) {
        Write-Host "[ERROR] Capacity not found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[SUCCESS] Using capacity: $($capacity.displayName)" -ForegroundColor Green
    Write-Host "  SKU: $($capacity.sku)" -ForegroundColor Gray
    Write-Host "  Region: $($capacity.region)" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host "[ERROR] Failed to retrieve capacity info: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[INFO] Capacity metrics API may not be available for your tenant" -ForegroundColor Yellow
    Write-Host "[INFO] Falling back to refresh duration estimates..." -ForegroundColor Yellow
    Write-Host ""
    
    # Fallback to duration-based estimates
    $useDurationEstimate = $true
}

# Analyze refresh history for CU estimation
$historyFile = Join-Path $DocumentationPath "Dataflow-Refresh-History.csv"

if (-not (Test-Path $historyFile)) {
    Write-Host "[WARNING] No refresh history found yet" -ForegroundColor Yellow
    Write-Host "[INFO] CU tracking will begin after first orchestration run" -ForegroundColor Yellow
    exit 0
}

$history = Import-Csv $historyFile

# Filter to time window
$cutoffTime = (Get-Date).AddHours(-$Hours)
$recentHistory = $history | Where-Object {
    [datetime]::Parse($_.Timestamp) -gt $cutoffTime
}

if ($recentHistory.Count -eq 0) {
    Write-Host "[INFO] No refresh activity in last $Hours hours" -ForegroundColor Yellow
    exit 0
}

Write-Host "[INFO] Analyzing $($recentHistory.Count) refresh operations..." -ForegroundColor Cyan
Write-Host ""

# CU Estimation based on duration and complexity
function Estimate-CUUsage {
    param(
        [double]$DurationMinutes,
        [string]$Category
    )
    
    # F4 capacity baseline estimates
    # These are approximations - actual CU varies by query complexity
    $baseRatePerMinute = switch ($Category) {
        "RawSource" { 2.5 }      # Simple data pulls
        "Dimension" { 3.0 }      # Moderate transformations
        "FactTable" { 4.0 }      # Complex aggregations
        "Transformation" { 3.5 } # Medium complexity
        default { 3.0 }
    }
    
    return [math]::Round($DurationMinutes * $baseRatePerMinute, 2)
}

# Calculate estimated CU usage
$cuData = @()

foreach ($refresh in $recentHistory) {
    $estimatedCU = Estimate-CUUsage -DurationMinutes $refresh.DurationMinutes -Category $refresh.Category
    
    $cuData += [PSCustomObject]@{
        Timestamp = $refresh.Timestamp
        DataflowName = $refresh.DataflowName
        Category = $refresh.Category
        DurationMinutes = [double]$refresh.DurationMinutes
        EstimatedCU = $estimatedCU
        Status = $refresh.Status
    }
}

# Analysis
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CU Usage Summary (Last $Hours Hours)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalCU = ($cuData | Measure-Object -Property EstimatedCU -Sum).Sum
$avgCUPerRefresh = ($cuData | Measure-Object -Property EstimatedCU -Average).Average
$maxCU = ($cuData | Measure-Object -Property EstimatedCU -Maximum).Maximum

Write-Host "Total Estimated CU Consumed: $([math]::Round($totalCU, 1)) CU" -ForegroundColor White
Write-Host "Average per Refresh: $([math]::Round($avgCUPerRefresh, 1)) CU" -ForegroundColor White
Write-Host "Peak Single Operation: $([math]::Round($maxCU, 1)) CU" -ForegroundColor White
Write-Host ""

# F4 capacity reference
$f4DailyCU = 96 * 24  # 96 CU per hour * 24 hours = 2,304 CU per day
$usagePercent = ($totalCU / $f4DailyCU) * 100

Write-Host "F4 Capacity Reference:" -ForegroundColor Yellow
Write-Host "  Daily Capacity: $f4DailyCU CU (96 CU/hour)" -ForegroundColor Gray
Write-Host "  Current Usage: $([math]::Round($usagePercent, 1))% of daily capacity" -ForegroundColor $(
    if ($usagePercent -lt 50) { "Green" } 
    elseif ($usagePercent -lt 80) { "Yellow" } 
    else { "Red" }
)
Write-Host ""

# By Category
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CU Usage by Category" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$byCategory = $cuData | Group-Object Category

foreach ($cat in $byCategory | Sort-Object Name) {
    $catTotal = ($cat.Group | Measure-Object -Property EstimatedCU -Sum).Sum
    $catAvg = ($cat.Group | Measure-Object -Property EstimatedCU -Average).Average
    $catPercent = ($catTotal / $totalCU) * 100
    
    Write-Host "$($cat.Name):" -ForegroundColor Yellow
    Write-Host "  Operations: $($cat.Count)" -ForegroundColor White
    Write-Host "  Total CU: $([math]::Round($catTotal, 1)) ($([math]::Round($catPercent, 1))%)" -ForegroundColor White
    Write-Host "  Avg CU: $([math]::Round($catAvg, 1))" -ForegroundColor White
    Write-Host ""
}

# Top 10 CU consumers
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Top 10 CU Consumers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$topConsumers = $cuData | 
    Group-Object DataflowName |
    ForEach-Object {
        [PSCustomObject]@{
            DataflowName = $_.Name
            TotalCU = ($_.Group | Measure-Object -Property EstimatedCU -Sum).Sum
            AvgCU = ($_.Group | Measure-Object -Property EstimatedCU -Average).Average
            Executions = $_.Count
            Category = $_.Group[0].Category
        }
    } |
    Sort-Object TotalCU -Descending |
    Select-Object -First 10

$topConsumers | Format-Table -Property @{
    Label = "Dataflow";
    Expression = {$_.DataflowName};
    Width = 40
}, @{
    Label = "Total CU";
    Expression = {[math]::Round($_.TotalCU, 1)};
    Width = 12
}, @{
    Label = "Avg CU";
    Expression = {[math]::Round($_.AvgCU, 1)};
    Width = 12
}, @{
    Label = "Runs";
    Expression = {$_.Executions};
    Width = 8
}, @{
    Label = "Category";
    Expression = {$_.Category};
    Width = 15
} -AutoSize

# High usage alerts
$highUsage = $cuData | Where-Object { $_.EstimatedCU -gt $HighUsageThresholdCU }
$criticalUsage = $cuData | Where-Object { $_.EstimatedCU -gt $CriticalUsageThresholdCU }

if ($criticalUsage.Count -gt 0) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  CRITICAL: High CU Operations Detected" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "$($criticalUsage.Count) operations consumed over $CriticalUsageThresholdCU CU:" -ForegroundColor Red
    Write-Host ""
    
    foreach ($op in $criticalUsage | Sort-Object EstimatedCU -Descending | Select-Object -First 5) {
        Write-Host "  - $($op.DataflowName): $([math]::Round($op.EstimatedCU, 1)) CU ($($op.DurationMinutes) min)" -ForegroundColor Red
    }
    Write-Host ""
} elseif ($highUsage.Count -gt 0) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  WARNING: Elevated CU Usage" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "$($highUsage.Count) operations consumed over $HighUsageThresholdCU CU" -ForegroundColor Yellow
    Write-Host ""
}

# Recommendations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Optimization Recommendations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$recommendations = @()

# Check for expensive dataflows
$expensive = $topConsumers | Where-Object { $_.AvgCU -gt $HighUsageThresholdCU }
if ($expensive) {
    $recommendations += "High CU Dataflows: Review query complexity for: $($expensive.DataflowName -join ', ')"
}

# Check capacity usage
if ($usagePercent -gt 80) {
    $recommendations += "CRITICAL: Using $([math]::Round($usagePercent, 1))% of F4 capacity - consider upgrading to F8 or F16"
} elseif ($usagePercent -gt 60) {
    $recommendations += "WARNING: Using $([math]::Round($usagePercent, 1))% of F4 capacity - monitor closely"
}

# Check for inefficient scheduling
$hourlyDistribution = $cuData | Group-Object { ([datetime]::Parse($_.Timestamp)).Hour }
$peakHour = $hourlyDistribution | Sort-Object Count -Descending | Select-Object -First 1
if ($peakHour -and $peakHour.Count -gt ($cuData.Count * 0.4)) {
    $recommendations += "Consider spreading refreshes: $($peakHour.Count) operations at hour $($peakHour.Name)"
}

if ($recommendations.Count -gt 0) {
    foreach ($rec in $recommendations) {
        Write-Host "  - $rec" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] CU usage looks healthy!" -ForegroundColor Green
}

Write-Host ""

# Save CU tracking data
$cuFile = Join-Path $DocumentationPath "CU-Usage-History.csv"
$cuData | Export-Csv -Path $cuFile -NoTypeInformation -Append -Encoding UTF8

Write-Host "[SUCCESS] CU usage data saved: $cuFile" -ForegroundColor Green

# Generate markdown report
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("# CU Usage Report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("**Time Period:** Last $Hours hours")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

[void]$sb.AppendLine("## Summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Value |")
[void]$sb.AppendLine("|--------|-------|")
[void]$sb.AppendLine("| Total CU Consumed | $([math]::Round($totalCU, 1)) CU |")
[void]$sb.AppendLine("| Operations | $($cuData.Count) |")
[void]$sb.AppendLine("| Avg per Operation | $([math]::Round($avgCUPerRefresh, 1)) CU |")
[void]$sb.AppendLine("| Peak Operation | $([math]::Round($maxCU, 1)) CU |")
[void]$sb.AppendLine("| F4 Capacity Used | $([math]::Round($usagePercent, 1))% |")
[void]$sb.AppendLine("")

[void]$sb.AppendLine("## Top CU Consumers")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Dataflow | Total CU | Avg CU | Runs |")
[void]$sb.AppendLine("|----------|----------|--------|------|")

foreach ($consumer in $topConsumers) {
    [void]$sb.AppendLine("| $($consumer.DataflowName) | $([math]::Round($consumer.TotalCU, 1)) | $([math]::Round($consumer.AvgCU, 1)) | $($consumer.Executions) |")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Recommendations")
[void]$sb.AppendLine("")

if ($recommendations.Count -gt 0) {
    foreach ($rec in $recommendations) {
        [void]$sb.AppendLine("- $rec")
    }
} else {
    [void]$sb.AppendLine("- No optimization recommendations at this time")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.")

$mdFile = Join-Path $DocumentationPath "CU-USAGE-REPORT.md"
$sb.ToString() | Out-File $mdFile -Encoding UTF8

Write-Host "[SUCCESS] CU usage report created: $mdFile" -ForegroundColor Green
Write-Host ""

# Return status
if ($criticalUsage.Count -gt 0) {
    Write-Host "[ALERT] Critical CU usage detected!" -ForegroundColor Red
    exit 1
} elseif ($usagePercent -gt 80) {
    Write-Host "[WARNING] High capacity usage!" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "[SUCCESS] CU usage within acceptable limits" -ForegroundColor Green
    exit 0
}