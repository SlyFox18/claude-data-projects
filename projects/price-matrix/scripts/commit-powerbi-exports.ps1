# Power BI Export Commit Script - Price Matrix Project
# Purpose: Backup and commit already-exported CSV files to Git
# Usage: Run this after you export CSV files to data\info-exports

param(
    [string]$GitRepoPath = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix",
    [int]$HoursBack = 4
)

$ExportPath = Join-Path $GitRepoPath "data\info-exports"
$BackupPath = Join-Path $GitRepoPath "artifacts\exports\$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host "=== Price Matrix Export Commit Tool ===" -ForegroundColor Cyan
Write-Host "Export folder: $ExportPath" -ForegroundColor Yellow
Write-Host "Looking for files modified in last $HoursBack hours..." -ForegroundColor Yellow
Write-Host ""

# Create backup directory
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

# Find recently modified CSV files in the export folder
$cutoffTime = (Get-Date).AddHours(-$HoursBack)
$csvFiles = Get-ChildItem -Path $ExportPath -Filter "*.csv" | Where-Object { 
    $_.LastWriteTime -gt $cutoffTime 
}

Write-Host "Found $($csvFiles.Count) recently modified CSV files:" -ForegroundColor Green

if ($csvFiles.Count -gt 0) {
    $processedFiles = @()
    
    foreach ($file in $csvFiles) {
        $timeDiff = (Get-Date) - $file.LastWriteTime
        $timeAgo = if ($timeDiff.TotalMinutes -lt 60) { 
            "$([Math]::Round($timeDiff.TotalMinutes)) minutes ago" 
        } else { 
            "$([Math]::Round($timeDiff.TotalHours, 1)) hours ago" 
        }
        
        Write-Host "  - $($file.Name) (modified $timeAgo)" -ForegroundColor White
        
        # Copy to backup location
        $backupDestPath = Join-Path $BackupPath $file.Name
        Copy-Item $file.FullName -Destination $backupDestPath -Force
        
        Write-Host "    -> Backed up to artifacts/exports" -ForegroundColor Green
        $processedFiles += $file.Name
    }
    
    # Commit to Git
    Write-Host ""
    Write-Host "Committing to Git..." -ForegroundColor Yellow
    
    Set-Location $GitRepoPath
    
    try {
        # Check if there are any changes to commit
        $gitStatus = git status --porcelain "data/info-exports/*.csv"
        
        if ($gitStatus) {
            # Add the files
            git add "data/info-exports/*.csv"
            git add "artifacts/exports/*"
            
            # Create commit message
            $fileList = $processedFiles -join ", "
            $commitMessage = "auto: Update Power BI exports ($fileList) - $DateStamp"
            
            # Commit and push
            git commit -m $commitMessage
            git push origin main
            
            Write-Host "SUCCESS: Committed and pushed to Git!" -ForegroundColor Green
            Write-Host "Files: $fileList" -ForegroundColor White
            Write-Host "Backup: $BackupPath" -ForegroundColor White
            
        } else {
            Write-Host "No changes detected in Git - files already committed" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "WARNING: Git operation failed" -ForegroundColor Yellow
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "No recently modified CSV files found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current files in export folder:" -ForegroundColor Cyan
    
    $allFiles = Get-ChildItem -Path $ExportPath -Filter "*.csv" -ErrorAction SilentlyContinue
    if ($allFiles.Count -gt 0) {
        foreach ($file in $allFiles) {
            $age = (Get-Date) - $file.LastWriteTime
            $ageText = if ($age.TotalDays -lt 1) {
                "$([Math]::Round($age.TotalHours, 1)) hours ago"
            } else {
                "$([Math]::Round($age.TotalDays, 1)) days ago"
            }
            Write-Host "  - $($file.Name) (modified $ageText)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "To commit older files, use: -HoursBack 24 (or higher)" -ForegroundColor Yellow
    } else {
        Write-Host "  No CSV files found in export folder" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Export commit complete! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Enter to close..."
Read-Host