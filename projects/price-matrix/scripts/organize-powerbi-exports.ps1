# Power BI Export Organizer - Price Matrix Project
# Purpose: Automatically organize CSV exports into Git repository
# Author: bfox

param(
    [string]$SourceFolder = "$env:USERPROFILE\Downloads",
    [string]$GitRepoPath = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix",
    [int]$HoursBack = 4
)

$ExportPath = Join-Path $GitRepoPath "data\info-exports"
$BackupPath = Join-Path $GitRepoPath "artifacts\exports\$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm"

Write-Host "=== Price Matrix Export Organizer ===" -ForegroundColor Cyan
Write-Host "Source: $SourceFolder" -ForegroundColor Yellow
Write-Host "Target: $ExportPath" -ForegroundColor Yellow
Write-Host "Looking for files from last $HoursBack hours..." -ForegroundColor Yellow
Write-Host ""

# Create backup directory
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Host "Created backup folder: $BackupPath" -ForegroundColor Green
}

# Look for recent CSV files
$cutoffTime = (Get-Date).AddHours(-$HoursBack)
$csvFiles = Get-ChildItem -Path $SourceFolder -Filter "*.csv" | Where-Object { 
    $_.LastWriteTime -gt $cutoffTime 
}

Write-Host "Found $($csvFiles.Count) recent CSV files:" -ForegroundColor Green

if ($csvFiles.Count -gt 0) {
    $processedFiles = @()
    
    foreach ($file in $csvFiles) {
        $timeDiff = (Get-Date) - $file.LastWriteTime
        $timeAgo = if ($timeDiff.TotalMinutes -lt 60) { 
            "$([Math]::Round($timeDiff.TotalMinutes)) minutes ago" 
        } else { 
            "$([Math]::Round($timeDiff.TotalHours, 1)) hours ago" 
        }
        
        Write-Host "  - $($file.Name) ($timeAgo)" -ForegroundColor White
        
        # Determine file type and new name
        $destName = Get-FileType $file.Name $file.FullName
        
        if ($destName) {
            $destPath = Join-Path $ExportPath $destName
            $backupDestPath = Join-Path $BackupPath $destName
            
            # Copy to both locations
            Copy-Item $file.FullName -Destination $destPath -Force
            Copy-Item $file.FullName -Destination $backupDestPath -Force
            
            Write-Host "    -> Organized as: $destName" -ForegroundColor Green
            $processedFiles += $destName
        } else {
            Write-Host "    -> Skipped (not a Power BI export)" -ForegroundColor Yellow
        }
    }
    
    if ($processedFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "Committing to Git..." -ForegroundColor Yellow
        
        Set-Location $GitRepoPath
        
        try {
            # Add the files
            git add "data/info-exports/*.csv"
            git add "artifacts/exports/*"
            
            # Create commit message
            $fileList = $processedFiles -join ", "
            $commitMessage = "auto: Update Power BI exports ($fileList) - $DateStamp"
            
            # Commit
            git commit -m $commitMessage
            
            # Push
            git push origin main
            
            Write-Host "SUCCESS: Committed and pushed to Git!" -ForegroundColor Green
            Write-Host "Files: $fileList" -ForegroundColor White
            Write-Host "Backup: $BackupPath" -ForegroundColor White
            
        } catch {
            Write-Host "WARNING: Git operation failed, but files were organized" -ForegroundColor Yellow
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
} else {
    Write-Host "No recent CSV files found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To use this automation:" -ForegroundColor Cyan
    Write-Host "1. Export your Power BI data to CSV files" -ForegroundColor White
    Write-Host "2. Save them to Downloads folder" -ForegroundColor White
    Write-Host "3. Run this script within $HoursBack hours" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Export organization complete! ===" -ForegroundColor Cyan

# Function to identify Power BI export files
function Get-FileType($fileName, $filePath) {
    try {
        # Read first few lines to identify file type
        $content = Get-Content $filePath -First 3 -ErrorAction SilentlyContinue
        $contentText = $content -join " "
        
        # Check for Power BI export patterns
        if ($contentText -match "Name.*Table.*Expression" -or $contentText -match "ID.*Name.*Table.*Description.*DataType.*Expression") {
            return "current-measures.csv"
        }
        elseif ($contentText -match "Name.*Model.*DataCategory" -or $contentText -match "ID.*Name.*Model.*DataCategory") {
            return "current-tables.csv"
        }
        elseif ($contentText -match "Name.*Table.*DataType.*DataCategory" -or $contentText -match "ID.*Name.*Table.*DataType.*DataCategory") {
            return "current-columns.csv"
        }
        elseif ($contentText -match "FromTable.*ToTable" -or $contentText -match "ID.*Name.*Relationship") {
            return "current-relationships.csv"
        }
        # Check filename as backup
        elseif ($fileName -match "measure") {
            return "current-measures.csv"
        }
        elseif ($fileName -match "table") {
            return "current-tables.csv"
        }
        elseif ($fileName -match "column") {
            return "current-columns.csv"
        }
        elseif ($fileName -match "relationship") {
            return "current-relationships.csv"
        }
        else {
            return $null
        }
    } catch {
        return $null
    }
}

Write-Host ""
Write-Host "Press Enter to close..."
Read-Host