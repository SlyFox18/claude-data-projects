<#
.SYNOPSIS
    Tracks real CU consumption for specific named Fabric items over time.
.DESCRIPTION
    Queries the Microsoft Fabric Capacity Metrics semantic model directly via DAX
    (Power BI Execute Queries REST API) for a configured list of tracked item names,
    and appends a timestamped snapshot of each item's CU (s), Duration (s), and
    Operations to a running CSV log.

    Unlike Monitor-CUUsage.ps1 (which estimates CU from dataflow refresh duration
    using a made-up per-category rate), this pulls the exact numbers shown in the
    Fabric Capacity Metrics app itself, and covers every item kind (notebooks,
    pipelines, datasets, SQLDb, dataflows, etc.) - not just dataflows.

    Uses the 'Metrics By Item' table (a rolling-window total matching the app's
    "Items (14 days)" view) rather than the day/operation-level breakdown tables,
    which were found to have real data gaps for some operation types (e.g. Dataset
    On-Demand Refresh showed 0 CU there despite real consumption). Item name -> Item
    Id resolution and CU lookup are done as two separate raw-table queries and joined
    in PowerShell, rather than relying on the model's Items <-> Metrics relationship,
    since that relationship was found not to propagate filters correctly.

    Also logs capacity-wide average/peak utilization (from the 'CU Detail' table)
    to a separate Capacity-Utilization-Tracking.csv, so per-item numbers can be
    read against actual capacity headroom rather than in isolation.
.EXAMPLE
    .\Track-ItemCU.ps1
    .\Track-ItemCU.ps1 -TrackedItems @("Bin Location Report","Inspections")
    .\Track-ItemCU.ps1 -TopN 30   # widen auto-discovery beyond the default top 20

.NOTES
    Added 2026-08-05: -TopN auto-discovery. In addition to the explicitly named
    $TrackedItems (things we always want a continuous trend line for, even on a
    quiet day when they're not a big consumer), this also pulls the top $TopN
    CU consumers overall straight from 'Metrics By Item', by name, regardless
    of whether anyone remembered to add them to the list. This is deliberate -
    a hardcoded list of every dataflow/report in the tenant would go stale the
    moment a new one is added, and defeats the actual goal (quickly seeing
    what's burning capacity, including things nobody expected). The two sets
    are merged and deduped before the CU lookup step, so nothing is tracked
    twice. CSV column schema is unchanged from before this change, so existing
    history in Item-CU-Tracking.csv stays valid - only which rows get added
    changed, not the shape of each row.
#>

param(
    [string]$Token = "",
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation",
    [string]$CapacityMetricsWorkspaceId = "412a3d0a-73b6-4314-8134-c65c89209fd6",
    [string]$CapacityMetricsDatasetId = "235b264c-203b-4425-9686-94589a67127a",
    [int]$WindowDays = 14,   # matches Metrics By Item's rolling window
    [int]$TopN = 20,         # also auto-track the top N CU consumers overall, by name, regardless of whether they're in $TrackedItems
    [string[]]$TrackedItems = @(
        "Universal_SemanticModel_Refresh_WithPolling",
        "Pipeline_SM_Refresh_TEST",
        "Pipeline_SemanticModels_V2",
        "Bin Location Report",
        "Inspections",
        "parts-lookup-app",
        # The 20 individual semantic models covered by the SM Refresh migration
        # (real current names, confirmed live against the Power BI API 2026-08-05 -
        # a few differ from the stale pipeline JSON's names, e.g. "Open Parts
        # Tickets" not "Parts on Open Orders" - see docs/superpowers/plans/2026-08-04-sm-refresh-spn-migration.md)
        "Parts Promo",
        "Customer Anatomy V2",
        "Inventory Analysis",
        "Part Sales with Low Margin",
        "Parts Adjustments",
        "First Pass Fill",
        "Open Work Orders",
        "Open Parts Tickets",
        "60+ Days Past Due",
        "Negative On Hand-On Hand No Bin",
        "Planter Inspection Part Sales",
        "Transfers",
        "Pin Capture",
        "Price Matrix",
        "Physical Inventory",
        "Combine Vault Sales",
        "MD Invoices With No Freight",
        "Labor Performance",
        "Unique Parts Customers"
    )
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Item CU Tracker" -ForegroundColor Cyan
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

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
}

$executeQueriesUrl = "https://api.powerbi.com/v1.0/myorg/groups/$CapacityMetricsWorkspaceId/datasets/$CapacityMetricsDatasetId/executeQueries"

function Invoke-DaxQuery {
    param([string]$Query)
    $body = @{
        queries             = @(@{ query = $Query })
        serializerSettings  = @{ includeNulls = $true }
    } | ConvertTo-Json -Depth 6

    $response = Invoke-RestMethod -Uri $executeQueriesUrl -Headers $headers -Method Post -Body $body -ContentType "application/json"
    return $response.results[0].tables[0].rows
}

# Step 1: Resolve tracked item names to their current Item Id / kind / workspace
$nameList   = ($TrackedItems | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }) -join ","
$itemsQuery = "EVALUATE FILTER('Items', 'Items'[Item name] IN {$nameList})"

Write-Host "[INFO] Resolving $($TrackedItems.Count) tracked item names..." -ForegroundColor Cyan
try {
    $itemRows = Invoke-DaxQuery -Query $itemsQuery
} catch {
    Write-Host "[ERROR] Failed to query Capacity Metrics model: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not $itemRows -or $itemRows.Count -eq 0) {
    Write-Host "[ERROR] None of the tracked item names resolved. Check exact spelling against the 'Items' table." -ForegroundColor Red
    exit 1
}

$resolvedNames = $itemRows | ForEach-Object { $_.'Items[Item name]' }
$missingNames  = $TrackedItems | Where-Object { $_ -notin $resolvedNames }
if ($missingNames) {
    Write-Host "[WARNING] Not found in Items table (check spelling): $($missingNames -join ', ')" -ForegroundColor Yellow
}

$itemLookup = @{}
foreach ($row in $itemRows) {
    $itemLookup[$row.'Items[Item Id]'] = [PSCustomObject]@{
        ItemName      = $row.'Items[Item name]'
        ItemKind      = $row.'Items[Item kind]'
        WorkspaceName = $row.'Items[Workspace name]'
    }
}

Write-Host "[SUCCESS] Resolved $($itemLookup.Count) item(s)" -ForegroundColor Green
Write-Host ""

# Step 1b: Auto-discover the top N CU consumers overall (regardless of name),
# so anything new or unexpected shows up without needing to be added to
# $TrackedItems by hand first. DAX TOPN's order parameter: 0 = descending.
Write-Host "[INFO] Auto-discovering top $TopN CU consumers..." -ForegroundColor Cyan
$explicitIds = @($itemLookup.Keys)
try {
    $topNQuery = "EVALUATE TOPN($TopN, 'Metrics By Item', 'Metrics By Item'[CU (s)], 0)"
    $topNRows  = Invoke-DaxQuery -Query $topNQuery
    $topNIds   = @($topNRows | ForEach-Object { $_.'Metrics By Item[Item Id]' })

    $newIds = $topNIds | Where-Object { $_ -notin $explicitIds }
    if ($newIds) {
        $newIdList     = ($newIds | ForEach-Object { '"' + $_ + '"' }) -join ","
        $newItemsQuery = "EVALUATE FILTER('Items', 'Items'[Item Id] IN {$newIdList})"
        $newItemRows   = Invoke-DaxQuery -Query $newItemsQuery
        foreach ($row in $newItemRows) {
            $itemLookup[$row.'Items[Item Id]'] = [PSCustomObject]@{
                ItemName      = $row.'Items[Item name]'
                ItemKind      = $row.'Items[Item kind]'
                WorkspaceName = $row.'Items[Workspace name]'
            }
        }
        Write-Host "[SUCCESS] Auto-discovery added $($newItemRows.Count) new item(s) not already in the named list" -ForegroundColor Green
    } else {
        Write-Host "[INFO] All top $TopN consumers were already in the named list" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[WARNING] Top-N auto-discovery query failed, continuing with named items only: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Pull real CU (s) / Duration (s) / Operations from the raw Metrics By Item table
$idList       = ($itemLookup.Keys | ForEach-Object { '"' + $_ + '"' }) -join ","
$metricsQuery = "EVALUATE FILTER('Metrics By Item', 'Metrics By Item'[Item Id] IN {$idList})"

Write-Host "[INFO] Pulling CU metrics..." -ForegroundColor Cyan
try {
    $metricRows = Invoke-DaxQuery -Query $metricsQuery
} catch {
    Write-Host "[ERROR] Failed to query CU metrics: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Join in PowerShell and build snapshot rows (join, not model relationship - see .DESCRIPTION)
$snapshotDate      = Get-Date -Format "yyyy-MM-dd"
$snapshotTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results           = @()
$metricItemIds     = @($metricRows | ForEach-Object { $_.'Metrics By Item[Item Id]' })

foreach ($row in $metricRows) {
    $itemId = $row.'Metrics By Item[Item Id]'
    $info   = $itemLookup[$itemId]
    if (-not $info) { continue }

    $results += [PSCustomObject]@{
        SnapshotDate      = $snapshotDate
        SnapshotTimestamp = $snapshotTimestamp
        ItemName          = $info.ItemName
        ItemKind          = $info.ItemKind
        WorkspaceName     = $info.WorkspaceName
        "CU(s)"           = [math]::Round([double]$row.'Metrics By Item[CU (s)]', 2)
        "Duration(s)"     = [math]::Round([double]$row.'Metrics By Item[Duration (s)]', 2)
        Operations        = $row.'Metrics By Item[Operations]'
    }
}

# Items that resolved an Id but have zero activity in the current rolling window
foreach ($id in $itemLookup.Keys) {
    if ($id -notin $metricItemIds) {
        $info = $itemLookup[$id]
        $results += [PSCustomObject]@{
            SnapshotDate      = $snapshotDate
            SnapshotTimestamp = $snapshotTimestamp
            ItemName          = $info.ItemName
            ItemKind          = $info.ItemKind
            WorkspaceName     = $info.WorkspaceName
            "CU(s)"           = 0
            "Duration(s)"     = 0
            Operations        = 0
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Snapshot ($snapshotDate)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$results | Sort-Object -Property "CU(s)" -Descending | Format-Table -Property ItemName, ItemKind, "CU(s)", "Duration(s)", Operations -AutoSize

# Append to running CSV log
$logFile = Join-Path $DocumentationPath "Item-CU-Tracking.csv"
$results | Export-Csv -Path $logFile -NoTypeInformation -Append -Encoding UTF8

Write-Host ""
Write-Host "[SUCCESS] Snapshot appended to: $logFile" -ForegroundColor Green

# Step 4: Capacity-wide average/peak utilization, for context (not per-item).
# Formula verified 2026-08-03 against the app's own reported figures: avg came
# back 39.29% vs. the app's 39.30% (near-exact match). Peak came back 200% vs.
# the app's 251.69% - close but not exact, likely because the app's peak
# accounts for something (burst multiplier headroom / autoscale) this simple
# per-30-second-window formula doesn't fully capture. Treat peak as directional,
# not authoritative - the render script labels it as such.
Write-Host ""
Write-Host "[INFO] Pulling capacity-wide utilization (last $WindowDays days)..." -ForegroundColor Cyan
$cutoff = (Get-Date).AddDays(-$WindowDays)
$cutoffDax = "DATE({0},{1},{2})" -f $cutoff.Year, $cutoff.Month, $cutoff.Day
$utilQuery = @"
EVALUATE
VAR CutoffDate = $cutoffDax
RETURN ROW(
  "AvgUtilPct", DIVIDE(CALCULATE(SUM('CU Detail'[CU (s)]), 'CU Detail'[Window start time] >= CutoffDate), CALCULATE(SUM('CU Detail'[Base capacity units]), 'CU Detail'[Window start time] >= CutoffDate) * 30) * 100,
  "PeakUtilPct", CALCULATE(MAXX('CU Detail', DIVIDE('CU Detail'[CU (s)], 'CU Detail'[Base capacity units] * 30)), 'CU Detail'[Window start time] >= CutoffDate) * 100
)
"@

try {
    $utilRows = Invoke-DaxQuery -Query $utilQuery
    $avgUtil  = [math]::Round([double]$utilRows[0].'[AvgUtilPct]', 2)
    $peakUtil = [math]::Round([double]$utilRows[0].'[PeakUtilPct]', 2)

    $utilResult = [PSCustomObject]@{
        SnapshotDate      = $snapshotDate
        SnapshotTimestamp = $snapshotTimestamp
        WindowDays        = $WindowDays
        AvgUtilizationPct = $avgUtil
        PeakUtilizationPct = $peakUtil
    }

    $utilLogFile = Join-Path $DocumentationPath "Capacity-Utilization-Tracking.csv"
    $utilResult | Export-Csv -Path $utilLogFile -NoTypeInformation -Append -Encoding UTF8

    Write-Host "[SUCCESS] Capacity utilization: Avg $avgUtil% | Peak $peakUtil% (logged to $utilLogFile)" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not pull capacity-wide utilization: $($_.Exception.Message)" -ForegroundColor Yellow
}

exit 0
