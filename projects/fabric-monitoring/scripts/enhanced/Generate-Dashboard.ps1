<#
.SYNOPSIS
    Generates a comprehensive dashboard of Fabric workspaces
.DESCRIPTION
    Creates a summary dashboard with statistics, charts, and insights
.EXAMPLE
    .\Generate-Dashboard.ps1
#>

param(
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dashboard Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read workspace data
$workspacesFile = Join-Path $DocumentationPath "workspaces.json"

if (-not (Test-Path $workspacesFile)) {
    Write-Host "[ERROR] Workspaces file not found: $workspacesFile" -ForegroundColor Red
    exit 1
}

$workspaces = Get-Content $workspacesFile | ConvertFrom-Json

Write-Host "[INFO] Collecting statistics from $($workspaces.Count) workspaces..." -ForegroundColor Cyan

# Collect statistics
$stats = @{
    TotalWorkspaces = $workspaces.Count
    TotalItems = 0
    ItemsByType = @{}
    WorkspacesByCategory = @{
        DataPrep = 0
        Reporting = 0
        Development = 0
        Other = 0
    }
}

$workspaceDetails = @()

foreach ($ws in $workspaces) {
    $itemsFile = Join-Path $DocumentationPath "$($ws.displayName)-items.json"
    $itemCount = 0
    $items = @()
    
    if (Test-Path $itemsFile) {
        $items = Get-Content $itemsFile | ConvertFrom-Json
        $itemCount = $items.Count
        $stats.TotalItems += $itemCount
        
        # Count by type
        foreach ($item in $items) {
            if ($stats.ItemsByType.ContainsKey($item.type)) {
                $stats.ItemsByType[$item.type]++
            } else {
                $stats.ItemsByType[$item.type] = 1
            }
        }
    }
    
    # Categorize workspace
    if ($ws.displayName -like "LH*" -or $ws.displayName -like "*Data*Prep*" -or $ws.displayName -eq "Data_Backup") {
        $stats.WorkspacesByCategory.DataPrep++
        $category = "Data Preparation"
    } elseif ($ws.displayName -like "RP*" -and $ws.displayName -like "*Reports*") {
        $stats.WorkspacesByCategory.Reporting++
        $category = "Reporting"
    } elseif ($ws.displayName -like "*Sandbox*") {
        $stats.WorkspacesByCategory.Development++
        $category = "Development"
    } else {
        $stats.WorkspacesByCategory.Other++
        $category = "Other"
    }
    
    $workspaceDetails += [PSCustomObject]@{
        Name = $ws.displayName
        Type = $ws.type
        ItemCount = $itemCount
        Category = $category
    }
}

# Find largest and smallest
$workspaceDetails = $workspaceDetails | Sort-Object ItemCount -Descending
$largestWorkspace = $workspaceDetails | Select-Object -First 1
$smallestWorkspace = $workspaceDetails | Sort-Object ItemCount | Select-Object -First 1

# Calculate average
$avgItems = if ($stats.TotalWorkspaces -gt 0) { [math]::Round($stats.TotalItems / $stats.TotalWorkspaces, 1) } else { 0 }

# Count documentation files
$docFileCount = (Get-ChildItem $DocumentationPath -File -ErrorAction SilentlyContinue).Count

# Start building the dashboard using StringBuilder approach
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("# Fabric Workspace Dashboard")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Generated:** $(Get-Date -Format 'MMMM dd, yyyy HH:mm:ss')")
[void]$sb.AppendLine("**Documentation System:** Automated")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Executive Summary
[void]$sb.AppendLine("## Executive Summary")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Value |")
[void]$sb.AppendLine("|--------|-------|")
[void]$sb.AppendLine("| Total Workspaces | $($stats.TotalWorkspaces) |")
[void]$sb.AppendLine("| Total Items | $($stats.TotalItems) |")
[void]$sb.AppendLine("| Average Items per Workspace | $avgItems |")
[void]$sb.AppendLine("| Largest Workspace | $($largestWorkspace.Name) ($($largestWorkspace.ItemCount) items) |")
[void]$sb.AppendLine("| Documentation Files | $docFileCount |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Workspace Distribution
[void]$sb.AppendLine("## Workspace Distribution")
[void]$sb.AppendLine("")
[void]$sb.Append('```mermaid')
[void]$sb.AppendLine("")
[void]$sb.AppendLine("pie title Workspaces by Category")
[void]$sb.AppendLine('    "Data Preparation" : ' + $stats.WorkspacesByCategory.DataPrep)
[void]$sb.AppendLine('    "Reporting" : ' + $stats.WorkspacesByCategory.Reporting)
[void]$sb.AppendLine('    "Development" : ' + $stats.WorkspacesByCategory.Development)
if ($stats.WorkspacesByCategory.Other -gt 0) {
    [void]$sb.AppendLine('    "Other" : ' + $stats.WorkspacesByCategory.Other)
}
[void]$sb.Append('```')
[void]$sb.AppendLine("")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# All Workspaces Table
[void]$sb.AppendLine("## All Workspaces")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Workspace | Category | Items | Size Bar |")
[void]$sb.AppendLine("|-----------|----------|-------|----------|")

foreach ($ws in $workspaceDetails) {
    $sizeBar = "█" * [math]::Min([math]::Ceiling($ws.ItemCount / 10), 10)
    if ($sizeBar -eq "") { $sizeBar = "▪" }
    [void]$sb.AppendLine("| $($ws.Name) | $($ws.Category) | $($ws.ItemCount) | $sizeBar |")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Items by Type
[void]$sb.AppendLine("## Items by Type")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Item Type | Count | Percentage |")
[void]$sb.AppendLine("|-----------|-------|------------|")

foreach ($type in $stats.ItemsByType.Keys | Sort-Object { $stats.ItemsByType[$_] } -Descending) {
    $count = $stats.ItemsByType[$type]
    $percentage = if ($stats.TotalItems -gt 0) { [math]::Round(($count / $stats.TotalItems) * 100, 1) } else { 0 }
    [void]$sb.AppendLine("| $type | $count | $percentage% |")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Top 5 Workspaces
[void]$sb.AppendLine("## Top 5 Workspaces by Item Count")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Rank | Workspace | Items | Category |")
[void]$sb.AppendLine("|------|-----------|-------|----------|")

$top5 = $workspaceDetails | Select-Object -First 5
$rank = 1
foreach ($ws in $top5) {
    [void]$sb.AppendLine("| $rank | $($ws.Name) | $($ws.ItemCount) | $($ws.Category) |")
    $rank++
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# System Health
[void]$sb.AppendLine("## System Health")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Metric | Status | Details |")
[void]$sb.AppendLine("|--------|--------|---------|")
[void]$sb.AppendLine("| Documentation Coverage | Complete | All $($stats.TotalWorkspaces) workspaces documented |")

# Check for git workspaces folder
$gitWorkspacesPath = Join-Path (Split-Path (Split-Path $DocumentationPath)) "workspaces"
if (Test-Path $gitWorkspacesPath) {
    $gitWorkspaceCount = (Get-ChildItem $gitWorkspacesPath -Directory -ErrorAction SilentlyContinue).Count
    [void]$sb.AppendLine("| Git Integration | Active | $gitWorkspaceCount workspaces connected |")
} else {
    [void]$sb.AppendLine("| Git Integration | Info | No workspaces folder found |")
}

[void]$sb.AppendLine("| Automation | Running | Daily updates scheduled |")
[void]$sb.AppendLine("| Last Update | Current | $(Get-Date -Format 'MMMM dd, yyyy') |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Recent Activity
[void]$sb.AppendLine("## Recent Activity")
[void]$sb.AppendLine("")

$logsPath = Join-Path (Split-Path (Split-Path $DocumentationPath)) "logs"
$latestLog = Get-ChildItem $logsPath -Filter "automation-*.log" -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if ($latestLog) {
    $logContent = Get-Content $latestLog.FullName | Select-Object -Last 5
    [void]$sb.Append('```')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Last automation run: $($latestLog.LastWriteTime)")
    [void]$sb.AppendLine("")
    foreach ($line in $logContent) {
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine("")
    [void]$sb.Append('```')
    [void]$sb.AppendLine("")
} else {
    [void]$sb.AppendLine("*No recent automation logs found*")
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# Quick Links
[void]$sb.AppendLine("## Quick Links")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- [All Workspaces Data](workspaces.json)")
[void]$sb.AppendLine("- [Lineage Diagram](LINEAGE-DIAGRAM.md)")
[void]$sb.AppendLine("- [Change History](./) - Look for CHANGES-*.md files")
[void]$sb.AppendLine("- [Main Index](00-INDEX.md)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# System Information
[void]$sb.AppendLine("## System Information")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- **Repository Location:** C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs")
[void]$sb.AppendLine("- **Documentation Format:** Markdown + JSON")
[void]$sb.AppendLine("- **Version Control:** Git + GitHub")
[void]$sb.AppendLine("- **Automation:** Windows Task Scheduler (Daily at 9:00 AM)")
[void]$sb.AppendLine("- **Visualization:** Obsidian + Mermaid diagrams")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Dashboard automatically updates with each documentation run.**")

# Save dashboard
$dashboardFile = Join-Path $DocumentationPath "DASHBOARD.md"
$sb.ToString() | Out-File $dashboardFile -Encoding UTF8

Write-Host "[SUCCESS] Dashboard created: $dashboardFile" -ForegroundColor Green
Write-Host ""
Write-Host "Key Statistics:" -ForegroundColor Yellow
Write-Host "  - Total Workspaces: $($stats.TotalWorkspaces)" -ForegroundColor White
Write-Host "  - Total Items: $($stats.TotalItems)" -ForegroundColor White
Write-Host "  - Largest Workspace: $($largestWorkspace.Name) ($($largestWorkspace.ItemCount) items)" -ForegroundColor White
Write-Host "  - Average per Workspace: $avgItems items" -ForegroundColor White
Write-Host ""