# Quick Power BI Export Commit Tool
# Double-click this after exporting CSV files

$GitRepo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"

Write-Host "=== Quick Export Commit - Price Matrix ===" -ForegroundColor Cyan
Write-Host ""

# Run the commit script
& "$GitRepo\scripts\commit-powerbi-exports.ps1" -GitRepoPath $GitRepo -HoursBack 2

Write-Host ""
Write-Host "Done! Your exports have been backed up and committed." -ForegroundColor Green

# Keep window open for 3 seconds
Start-Sleep -Seconds 3
