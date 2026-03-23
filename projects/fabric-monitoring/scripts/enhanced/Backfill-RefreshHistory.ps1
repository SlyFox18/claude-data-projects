<#
.SYNOPSIS
    Backfills refresh history from Fabric API
.DESCRIPTION
    Queries Fabric API for actual refresh history and updates local CSV
#>

param(
    [string]$WorkspaceName = "LH_Master_Data",
    [int]$DaysBack = 1,
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backfill Refresh History" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get token
$tokenFile = Join-Path $PSScriptRoot "..\\.token"
$token = Get-Content $tokenFile -Raw
$token = $token.Trim()

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Get workspace
$workspacesFile = Join-Path $DocumentationPath "workspaces.json"
$workspaces = Get-Content $workspacesFile | ConvertFrom-Json
$workspace = $workspaces | Where-Object { $_.displayName -eq $WorkspaceName }
$workspaceId = $workspace.id

# Load inventory
$inventoryFile = Join-Path $DocumentationPath "Dataflow-Inventory-Discovered.csv"
$inventory = Import-Csv $inventoryFile

Write-Host "[INFO] Pulling refresh history for last $DaysBack days..." -ForegroundColor Cyan
Write-Host "[INFO] Checking $($inventory.Count) dataflows..." -ForegroundColor Gray
Write-Host ""

$cutoffDate = (Get-Date).AddDays(-$DaysBack)
$allRefreshes = @()
$checked = 0

foreach ($df in $inventory) {
    $checked++
    Write-Progress -Activity "Checking dataflows" -Status "$checked of $($inventory.Count)" -PercentComplete (($checked / $inventory.Count) * 100)
    
    try {
        # Get refresh history
        $url = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/items/$($df.DataflowId)/jobs/instances?jobType=Refresh"
        $refreshes = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        if ($refreshes.value) {
            foreach ($refresh in $refreshes.value) {
                if ($refresh.startTimeUtc) {
                    $startTime = [datetime]::Parse($refresh.startTimeUtc)

                    if ($startTime -ge $cutoffDate) {
                        $endTime = if ($refresh.endTimeUtc) { [datetime]::Parse($refresh.endTimeUtc) } else { Get-Date }
                        $duration = ($endTime - $startTime).TotalMinutes
                        
                        $status = switch ($refresh.status) {
                            "Completed" { "Success" }
                            "Succeeded" { "Success" }
                            "Failed" { "Failed" }
                            default { $refresh.status }
                        }
                        
                        # Extract error message — Fabric API returns errors in failureReason, not error
                        $errorMsg = ""
                        if ($refresh.failureReason) {
                            $errorMsg = if ($refresh.failureReason.message) { $refresh.failureReason.message }
                                        elseif ($refresh.failureReason.errorCode) { $refresh.failureReason.errorCode }
                                        else { $refresh.failureReason | ConvertTo-Json -Compress -Depth 2 }
                        } elseif ($refresh.error) {
                            $errorMsg = if ($refresh.error.message) { $refresh.error.message }
                                        elseif ($refresh.error.errorCode) { $refresh.error.errorCode }
                                        else { "$($refresh.error)" }
                        }

                        $endTimeStr = if ($refresh.endTimeUtc) { ([datetime]::Parse($refresh.endTimeUtc)).ToString('yyyy-MM-dd HH:mm:ss') } else { "" }

                        $allRefreshes += [PSCustomObject]@{
                            Timestamp       = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                            DataflowName    = $df.DataflowName
                            DataflowId      = $df.DataflowId
                            WorkspaceName   = $WorkspaceName
                            Category        = $df.Category
                            Status          = $status
                            StartTime       = $startTime.ToString('yyyy-MM-dd HH:mm:ss')
                            EndTime         = $endTimeStr
                            DurationMinutes = [math]::Round($duration, 1)
                            ErrorMessage    = $errorMsg
                        }
                    }
                }
            }
        }
        
        # Rate limit protection
        Start-Sleep -Milliseconds 200
        
    } catch {
        Write-Host "[WARNING] Failed to get history for $($df.DataflowName): $($_.Exception.Message)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Write-Progress -Activity "Checking dataflows" -Completed

Write-Host ""
Write-Host "Found $($allRefreshes.Count) refresh operations in last $DaysBack days" -ForegroundColor Green
Write-Host ""

if ($allRefreshes.Count -gt 0) {
    # Sort by timestamp
    $allRefreshes = $allRefreshes | Sort-Object Timestamp
    
    # Show summary
    $byDate = $allRefreshes | Group-Object { ([datetime]::Parse($_.Timestamp)).Date }
    
    Write-Host "By Date:" -ForegroundColor Yellow
    foreach ($date in $byDate) {
        $dateStr = ([datetime]$date.Name).ToString('yyyy-MM-dd')
        $success = ($date.Group | Where-Object { $_.Status -eq "Success" }).Count
        $failed = ($date.Group | Where-Object { $_.Status -eq "Failed" }).Count
        
        Write-Host "  $dateStr : $($date.Count) total ($success success, $failed failed)" -ForegroundColor White
    }
    
    Write-Host ""
    
    # Save to history file
    $historyFile = Join-Path $DocumentationPath "Dataflow-Refresh-History.csv"
    
    # Load existing history
    if (Test-Path $historyFile) {
        $existingHistory = Import-Csv $historyFile
        
        # Merge and deduplicate on DataflowName + StartTime (not Timestamp, which is collection time)
        $combined = $existingHistory + $allRefreshes
        $seen = @{}
        $unique = @($combined | Sort-Object StartTime | Where-Object {
            $key = "$($_.DataflowName)|$($_.StartTime)"
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $true } else { $false }
        })
        
        Write-Host "[INFO] Merging with existing history..." -ForegroundColor Cyan
        Write-Host "  Old records: $($existingHistory.Count)" -ForegroundColor Gray
        Write-Host "  New records: $($allRefreshes.Count)" -ForegroundColor Gray
        Write-Host "  Total unique: $($unique.Count)" -ForegroundColor Gray
        
        $unique | Export-Csv -Path $historyFile -NoTypeInformation -Encoding UTF8
        
    } else {
        $allRefreshes | Export-Csv -Path $historyFile -NoTypeInformation -Encoding UTF8
    }
    
    Write-Host ""
    Write-Host "[SUCCESS] History file updated: $historyFile" -ForegroundColor Green
    
} else {
    Write-Host "[WARNING] No refresh history found in last $DaysBack days" -ForegroundColor Yellow
}

Write-Host ""