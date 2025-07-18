# Power BI Performance Monitor - Price Matrix Project
# Purpose: Collect performance metrics and detect issues automatically

$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"
$workspaceId = "ba9d8de4-ef13-44e6-9156-e23a2511f3ad"
$datasetId = "bdecebfa-be8a-4cb6-8fa0-554316c8a1c9"

Write-Host "=== Power BI Performance Monitor ===" -ForegroundColor Cyan
Write-Host "Testing your model performance..." -ForegroundColor Yellow

$monitoringPath = "$repo\monitoring"
if (!(Test-Path $monitoringPath)) {
    New-Item -ItemType Directory -Path $monitoringPath -Force | Out-Null
}

$performancePath = "$monitoringPath\performance-data"
if (!(Test-Path $performancePath)) {
    New-Item -ItemType Directory -Path $performancePath -Force | Out-Null
}

Write-Host ""
Write-Host "Testing dataset connectivity..." -ForegroundColor Yellow
$connectStart = Get-Date

try {
    Connect-PowerBIServiceAccount
    $datasetInfo = Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$datasetId" -Method Get
    $connectTime = (Get-Date) - $connectStart
    
    Write-Host "  Success: $($connectTime.TotalMilliseconds)ms" -ForegroundColor Green
    $connectivityResult = "Success"
    $connectivityTime = $connectTime.TotalMilliseconds
    
} catch {
    $connectTime = (Get-Date) - $connectStart
    Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
    $connectivityResult = "Failed"
    $connectivityTime = -1
}

Write-Host ""
Write-Host "Checking refresh status..." -ForegroundColor Yellow

try {
    $refreshInfo = Invoke-PowerBIRestMethod -Url "groups/$workspaceId/datasets/$datasetId/refreshes?`$top=1" -Method Get
    $refreshData = $refreshInfo | ConvertFrom-Json
    
    if ($refreshData.value.Count -gt 0) {
        $lastRefresh = $refreshData.value[0]
        Write-Host "  Last refresh: $($lastRefresh.status)" -ForegroundColor Green
        $refreshStatus = $lastRefresh.status
    } else {
        Write-Host "  No refresh history" -ForegroundColor Yellow
        $refreshStatus = "Unknown"
    }
} catch {
    Write-Host "  Could not get refresh status" -ForegroundColor Red
    $refreshStatus = "Error"
}

$timestamp = Get-Date
$dateStamp = $timestamp.ToString("yyyy-MM-dd")
$timeStamp = $timestamp.ToString("HHmm")

# FIX: Use Get-Date -Format directly to avoid DateTime conversion issues
$timeString = Get-Date -Format "HH:mm:ss"
$performanceRecord = [PSCustomObject]@{
    Time = $timeString
    ConnectivityResult = $connectivityResult
    ConnectivityTime = $connectivityTime
    RefreshStatus = $refreshStatus
}

$csvFile = "$performancePath\daily-summary-$dateStamp.csv"
if (Test-Path $csvFile) {
    $performanceRecord | Export-Csv $csvFile -Append -NoTypeInformation
} else {
    $performanceRecord | Export-Csv $csvFile -NoTypeInformation
}

Write-Host ""
Write-Host "Performance data saved!" -ForegroundColor Green

$alerts = @()
if ($connectivityResult -eq "Failed") {
    $alerts += "CRITICAL: Dataset connectivity failed"
    Write-Host "ALERT: Dataset connectivity failed" -ForegroundColor Red
} elseif ($connectivityTime -gt 5000) {
    $alerts += "WARNING: Slow connectivity"
    Write-Host "ALERT: Slow connectivity ($connectivityTime ms)" -ForegroundColor Yellow
}

if ($refreshStatus -eq "Failed") {
    $alerts += "CRITICAL: Last refresh failed"
    Write-Host "ALERT: Last refresh failed" -ForegroundColor Red
}

if ($alerts.Count -eq 0) {
    Write-Host "No performance issues detected" -ForegroundColor Green
}

Set-Location $repo
# Add all monitoring data and script files
git add "monitoring/*"
git add "scripts/*"
# FIX: Use Get-Date -Format instead of ToString with single quotes
$commitMessage = "auto: Performance monitoring - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git commit -m $commitMessage
git push origin main

Write-Host ""
Write-Host "=== Complete ===" -ForegroundColor Cyan
Write-Host "Connectivity: $connectivityResult ($connectivityTime ms)" -ForegroundColor White
Write-Host "Refresh Status: $refreshStatus" -ForegroundColor White
Write-Host "Alerts: $($alerts.Count)" -ForegroundColor White

Read-Host "Press Enter to close"