<#
.SYNOPSIS
    Discovers all dataflows in LH_Master_Data workspace
.DESCRIPTION
    Queries Fabric API to get all dataflows and their metadata
.EXAMPLE
    .\Discover-Dataflows.ps1
#>

param(
    [string]$Token = "",
    [string]$WorkspaceName = "LH_Master_Data",
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation"
)

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

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dataflow Discovery" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Setup headers
$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

# Get workspace ID
$workspacesFile = Join-Path $DocumentationPath "workspaces.json"
$workspaces = Get-Content $workspacesFile | ConvertFrom-Json
$targetWorkspace = $workspaces | Where-Object { $_.displayName -eq $WorkspaceName }

if (-not $targetWorkspace) {
    Write-Host "[ERROR] Workspace '$WorkspaceName' not found" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Found workspace: $WorkspaceName" -ForegroundColor Cyan
Write-Host "[INFO] Workspace ID: $($targetWorkspace.id)" -ForegroundColor Gray
Write-Host ""

# Get all items in workspace
$itemsUrl = "https://api.fabric.microsoft.com/v1/workspaces/$($targetWorkspace.id)/items"
$items = Invoke-RestMethod -Uri $itemsUrl -Headers $headers -Method Get

# Filter to dataflows
$dataflows = $items.value | Where-Object { $_.type -eq "Dataflow" }

Write-Host "[INFO] Found $($dataflows.Count) dataflows" -ForegroundColor Green
Write-Host ""

# Categorize by name pattern
$categorized = @()

foreach ($df in $dataflows | Sort-Object displayName) {
    $name = $df.displayName
    
    # Determine category based on naming convention
    $status = "Active"
    
    if ($name -like "*_Raw") {
        $category = "RawSource"
        $priority = "High"
        $freq = "Daily"
    } elseif ($name -like "df_Dim*" -or $name -like "*Dim_*") {
        $category = "Dimension"
        $priority = "High"
        $freq = "Daily"
    } elseif ($name -like "df_Fact*" -or $name -like "*Fact_*") {
        $category = "FactTable"
        $priority = "High"
        $freq = "Daily"
    } elseif ($name -like "*Transform*") {
        $category = "Transformation"
        $priority = "Low"
        $freq = "Manual"
        $status = "Testing"
    } else {
        $category = "AdHoc"
        $priority = "Low"
        $freq = "Manual"
        $status = "AdHoc"
    }
    
    Write-Host "  - $name" -ForegroundColor White
    Write-Host "    Category: $category" -ForegroundColor Gray
    
    $categorized += [PSCustomObject]@{
        DataflowName = $name
        Workspace = $WorkspaceName
        Category = $category
        RefreshFrequency = $freq
        RefreshTime = "NEEDS_SCHEDULING"
        Priority = $priority
        DependsOn = "NEEDS_MAPPING"
        EstimatedDurationMinutes = "NEEDS_BASELINE"
        CUProfile = "NEEDS_BASELINE"
        Status = $status
        Notes = ""
        DataflowId = $df.id
    }
}

# Merge with existing inventory — preserve manually-set Status values
$csvFile = Join-Path $DocumentationPath "Dataflow-Inventory-Discovered.csv"
if (Test-Path $csvFile) {
    $existing = @{}
    Import-Csv $csvFile | ForEach-Object { $existing[$_.DataflowName] = $_ }

    $categorized = $categorized | ForEach-Object {
        $prev = $existing[$_.DataflowName]
        # Keep manually-set Status (e.g. "Inactive") — only override if previously auto-assigned
        if ($prev -and $prev.Status -notin @("Active", "Testing", "AdHoc", "")) {
            $_.Status = $prev.Status
        }
        $_
    }
}
$categorized | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "[SUCCESS] Dataflow inventory saved: $csvFile" -ForegroundColor Green
Write-Host ""
Write-Host "Summary by Category:" -ForegroundColor Yellow
$categorized | Group-Object Category | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) dataflows" -ForegroundColor White
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open the CSV in Excel: start $csvFile" -ForegroundColor White
Write-Host "2. Fill in: RefreshTime, DependsOn, EstimatedDurationMinutes" -ForegroundColor White
Write-Host "3. Classify any 'Unknown' category dataflows" -ForegroundColor White
Write-Host "4. Update CUProfile based on complexity (Low/Medium/High)" -ForegroundColor White
Write-Host ""