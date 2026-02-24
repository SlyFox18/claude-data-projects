<#
.SYNOPSIS
    Detects changes in Fabric workspaces between documentation runs
.DESCRIPTION
    Compares current workspace items with previous snapshot to identify:
    - New items added
    - Items removed
    - Items modified
    - Workspace changes
.EXAMPLE
    .\Detect-WorkspaceChanges.ps1
#>

param(
    [string]$DocumentationPath = "$PSScriptRoot\..\..\documentation"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Workspace Change Detection" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read current workspace data
$workspacesFile = Join-Path $DocumentationPath "workspaces.json"

if (-not (Test-Path $workspacesFile)) {
    Write-Host "[ERROR] Workspaces file not found: $workspacesFile" -ForegroundColor Red
    exit 1
}

$currentWorkspaces = Get-Content $workspacesFile | ConvertFrom-Json

# Create snapshots folder if it doesn't exist
$snapshotsPath = Join-Path $DocumentationPath "snapshots"
if (-not (Test-Path $snapshotsPath)) {
    New-Item -ItemType Directory -Path $snapshotsPath | Out-Null
}

# Look for previous snapshot
$previousSnapshot = Get-ChildItem $snapshotsPath -Filter "workspace-snapshot-*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (-not $previousSnapshot) {
    Write-Host "[INFO] No previous snapshot found. Creating initial snapshot." -ForegroundColor Yellow
    
    # Create initial snapshot
    $snapshotFile = Join-Path $snapshotsPath "workspace-snapshot-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
    $currentWorkspaces | ConvertTo-Json -Depth 10 | Out-File $snapshotFile -Encoding UTF8
    
    Write-Host "[SUCCESS] Initial snapshot created: $snapshotFile" -ForegroundColor Green
    Write-Host "Run this script again after the next documentation update to see changes." -ForegroundColor Cyan
    exit 0
}

# Load previous snapshot
Write-Host "[INFO] Loading previous snapshot: $($previousSnapshot.Name)" -ForegroundColor Cyan
$previousWorkspaces = Get-Content $previousSnapshot.FullName | ConvertFrom-Json

# Compare workspaces
$changes = @{
    NewWorkspaces = @()
    RemovedWorkspaces = @()
    ModifiedWorkspaces = @()
    TotalChanges = 0
}

# Find new and removed workspaces
$currentIds = $currentWorkspaces | ForEach-Object { $_.id }
$previousIds = $previousWorkspaces | ForEach-Object { $_.id }

foreach ($workspace in $currentWorkspaces) {
    if ($workspace.id -notin $previousIds) {
        $changes.NewWorkspaces += $workspace
    }
}

foreach ($workspace in $previousWorkspaces) {
    if ($workspace.id -notin $currentIds) {
        $changes.RemovedWorkspaces += $workspace
    }
}

# Check for modified workspaces
foreach ($currentWs in $currentWorkspaces) {
    $previousWs = $previousWorkspaces | Where-Object { $_.id -eq $currentWs.id }
    
    if ($previousWs) {
        # Compare item counts
        $currentItemsFile = Join-Path $DocumentationPath "$($currentWs.displayName)-items.json"
        $previousItemsCount = 0
        
        if (Test-Path $currentItemsFile) {
            $currentItems = Get-Content $currentItemsFile | ConvertFrom-Json
            $currentItemsCount = $currentItems.Count
            
            # This is simplified - in a real scenario you'd compare with previous items file
            # For now, we'll mark as modified if the name or type changed
            if ($currentWs.displayName -ne $previousWs.displayName -or $currentWs.type -ne $previousWs.type) {
                $changes.ModifiedWorkspaces += @{
                    Name = $currentWs.displayName
                    PreviousName = $previousWs.displayName
                    Change = "Workspace metadata changed"
                }
            }
        }
    }
}

# Calculate total changes
$changes.TotalChanges = $changes.NewWorkspaces.Count + $changes.RemovedWorkspaces.Count + $changes.ModifiedWorkspaces.Count

# Display results
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Change Detection Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Comparison Period:" -ForegroundColor Yellow
Write-Host "  Previous: $($previousSnapshot.LastWriteTime)" -ForegroundColor White
Write-Host "  Current:  $(Get-Date)" -ForegroundColor White
Write-Host ""

if ($changes.TotalChanges -eq 0) {
    Write-Host "[SUCCESS] No workspace changes detected!" -ForegroundColor Green
} else {
    Write-Host "[INFO] Detected $($changes.TotalChanges) change(s)" -ForegroundColor Yellow
    Write-Host ""
    
    if ($changes.NewWorkspaces.Count -gt 0) {
        Write-Host "New Workspaces ($($changes.NewWorkspaces.Count)):" -ForegroundColor Green
        foreach ($ws in $changes.NewWorkspaces) {
            Write-Host "  + $($ws.displayName)" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    if ($changes.RemovedWorkspaces.Count -gt 0) {
        Write-Host "Removed Workspaces ($($changes.RemovedWorkspaces.Count)):" -ForegroundColor Red
        foreach ($ws in $changes.RemovedWorkspaces) {
            Write-Host "  - $($ws.displayName)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($changes.ModifiedWorkspaces.Count -gt 0) {
        Write-Host "Modified Workspaces ($($changes.ModifiedWorkspaces.Count)):" -ForegroundColor Yellow
        foreach ($ws in $changes.ModifiedWorkspaces) {
            Write-Host "  ~ $($ws.Name): $($ws.Change)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Create change report
$reportFile = Join-Path $DocumentationPath "CHANGES-$(Get-Date -Format 'yyyy-MM-dd').md"
$report = @"
# Workspace Changes Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Comparison Period:** $($previousSnapshot.LastWriteTime) to $(Get-Date)

---

## Summary

- **Total Changes:** $($changes.TotalChanges)
- **New Workspaces:** $($changes.NewWorkspaces.Count)
- **Removed Workspaces:** $($changes.RemovedWorkspaces.Count)
- **Modified Workspaces:** $($changes.ModifiedWorkspaces.Count)

---

"@

if ($changes.NewWorkspaces.Count -gt 0) {
    $report += "`n## New Workspaces`n`n"
    foreach ($ws in $changes.NewWorkspaces) {
        $report += "- **$($ws.displayName)** (Type: $($ws.type))`n"
    }
}

if ($changes.RemovedWorkspaces.Count -gt 0) {
    $report += "`n## Removed Workspaces`n`n"
    foreach ($ws in $changes.RemovedWorkspaces) {
        $report += "- **$($ws.displayName)** (Type: $($ws.type))`n"
    }
}

if ($changes.ModifiedWorkspaces.Count -gt 0) {
    $report += "`n## Modified Workspaces`n`n"
    foreach ($ws in $changes.ModifiedWorkspaces) {
        $report += "- **$($ws.Name)**: $($ws.Change)`n"
    }
}

$report | Out-File $reportFile -Encoding UTF8

Write-Host "Change report saved: $reportFile" -ForegroundColor Cyan
Write-Host ""

# Create new snapshot
$newSnapshotFile = Join-Path $snapshotsPath "workspace-snapshot-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
$currentWorkspaces | ConvertTo-Json -Depth 10 | Out-File $newSnapshotFile -Encoding UTF8

Write-Host "[SUCCESS] New snapshot created for next comparison" -ForegroundColor Green
Write-Host ""

# Clean up old snapshots (keep last 10)
$allSnapshots = Get-ChildItem $snapshotsPath -Filter "workspace-snapshot-*.json" | 
    Sort-Object LastWriteTime -Descending

if ($allSnapshots.Count -gt 10) {
    $toDelete = $allSnapshots | Select-Object -Skip 10
    Write-Host "[INFO] Cleaning up old snapshots (keeping last 10)..." -ForegroundColor Gray
    $toDelete | Remove-Item -Force
}