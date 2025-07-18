# Enhanced Power BI Performance Monitor - Price Matrix Project
# Purpose: Comprehensive performance metrics, health checks, and diagnostics

$repo = "C:\Users\bfox\Documents\Git-Projects\claude-data-projects\projects\price-matrix"
$workspaceId = "ba9d8de4-ef13-44e6-9156-e23a2511f3ad"
$datasetId = "bdecebfa-be8a-4cb6-8fa0-554316c8a1c9"

Write-Host "=== Enhanced Power BI Performance Monitor ===" -ForegroundColor Cyan
Write-Host "Collecting comprehensive performance and health data..." -ForegroundColor Yellow

# Setup monitoring directories
$monitoringPath = "$repo\monitoring"
$performancePath = "$monitoringPath\performance-data"
$diagnosticsPath = "$monitoringPath\diagnostics"
$alertsPath = "$monitoringPath\alerts"

@($monitoringPath, $performancePath, $diagnosticsPath, $alertsPath) | ForEach-Object {
    if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

$timestamp = Get-Date
$dateStamp = Get-Date -Format "yyyy-MM-dd"
$timeStamp = Get-Date -Format "HH:mm:ss"

# Initialize results object
$monitoringResults = @{
    Timestamp = $timestamp
    Connectivity = @{}
    Dataset = @{}
    Refresh = @{}
    Workspace = @{}
    Performance = @{}
    Alerts = @()
}

Write-Host ""
Write-Host "1. Testing Power BI Service Connectivity..." -ForegroundColor Yellow
$connectStart = Get-Date

try {
    Connect-PowerBIServiceAccount
    $connectTime = (Get-Date) - $connectStart
    $connectMs = $connectTime.TotalMilliseconds
    Write-Host "  [SUCCESS] Connected successfully: $connectMs ms" -ForegroundColor Green
    
    $monitoringResults.Connectivity = @{
        Status = "Success"
        ResponseTime = [math]::Round($connectMs, 2)
        Timestamp = $connectStart
    }
} catch {
    $connectTime = (Get-Date) - $connectStart
    $errorMsg = $_.Exception.Message
    Write-Host "  [FAILED] Connection failed: $errorMsg" -ForegroundColor Red
    $monitoringResults.Connectivity = @{
        Status = "Failed"
        ResponseTime = -1
        Error = $errorMsg
        Timestamp = $connectStart
    }
}

Write-Host ""
Write-Host "2. Gathering Dataset Information..." -ForegroundColor Yellow

try {
    $datasetStart = Get-Date
    $datasetUrl = "groups/$workspaceId/datasets/$datasetId"
    $datasetInfo = Invoke-PowerBIRestMethod -Url $datasetUrl -Method Get | ConvertFrom-Json
    $datasetTime = (Get-Date) - $datasetStart
    $datasetMs = $datasetTime.TotalMilliseconds
    
    Write-Host "  [SUCCESS] Dataset Name: $($datasetInfo.name)" -ForegroundColor Green
    Write-Host "  [SUCCESS] Configuration Mode: $($datasetInfo.configuredBy)" -ForegroundColor Green
    Write-Host "  [SUCCESS] Data Retrieved in: $datasetMs ms" -ForegroundColor Green
    
    $monitoringResults.Dataset = @{
        Name = $datasetInfo.name
        Id = $datasetInfo.id
        ConfiguredBy = $datasetInfo.configuredBy
        WebUrl = $datasetInfo.webUrl
        QueryTime = [math]::Round($datasetMs, 2)
        Status = "Success"
    }
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "  [FAILED] Failed to retrieve dataset info: $errorMsg" -ForegroundColor Red
    $monitoringResults.Dataset = @{
        Status = "Failed"
        Error = $errorMsg
    }
}

Write-Host ""
Write-Host "3. Analyzing Refresh History..." -ForegroundColor Yellow

try {
    $refreshStart = Get-Date
    $refreshUrl = "groups/$workspaceId/datasets/$datasetId/refreshes"
    $refreshInfo = Invoke-PowerBIRestMethod -Url $refreshUrl -Method Get | ConvertFrom-Json
    $refreshTime = (Get-Date) - $refreshStart
    $refreshMs = $refreshTime.TotalMilliseconds
    
    if ($refreshInfo.value.Count -gt 0) {
        $lastRefresh = $refreshInfo.value[0]
        $refreshAge = (Get-Date) - [DateTime]$lastRefresh.endTime
        $refreshHours = [math]::Round($refreshAge.TotalHours, 1)
        
        Write-Host "  [SUCCESS] Last Refresh: $($lastRefresh.status) at $($lastRefresh.endTime)" -ForegroundColor Green
        Write-Host "  [SUCCESS] Refresh Age: $refreshHours hours" -ForegroundColor Green
        Write-Host "  [SUCCESS] Refresh History: $($refreshInfo.value.Count) records found" -ForegroundColor Green
        
        # Calculate success rate from recent refreshes
        $successCount = ($refreshInfo.value | Where-Object { $_.status -eq "Completed" }).Count
        $successRate = [math]::Round(($successCount / $refreshInfo.value.Count) * 100, 1)
        
        Write-Host "  [SUCCESS] Recent Success Rate: $successRate% ($successCount/$($refreshInfo.value.Count))" -ForegroundColor Green
        
        $monitoringResults.Refresh = @{
            LastStatus = $lastRefresh.status
            LastRefreshTime = $lastRefresh.endTime
            RefreshAgeHours = $refreshHours
            SuccessRate = $successRate
            TotalRecords = $refreshInfo.value.Count
            QueryTime = [math]::Round($refreshMs, 2)
            Status = "Success"
        }
        
    } else {
        Write-Host "  [WARNING] No refresh history found" -ForegroundColor Yellow
        $monitoringResults.Refresh = @{
            Status = "No History"
            QueryTime = [math]::Round($refreshMs, 2)
        }
    }
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "  [FAILED] Failed to get refresh info: $errorMsg" -ForegroundColor Red
    $monitoringResults.Refresh = @{
        Status = "Error"
        Error = $errorMsg
    }
}

Write-Host ""
Write-Host "4. Checking Workspace Health..." -ForegroundColor Yellow

try {
    $workspaceStart = Get-Date
    $workspaceUrl = "groups/$workspaceId"
    $datasetsUrl = "groups/$workspaceId/datasets"
    $reportsUrl = "groups/$workspaceId/reports"
    
    $workspaceInfo = Invoke-PowerBIRestMethod -Url $workspaceUrl -Method Get | ConvertFrom-Json
    $datasetsInWorkspace = Invoke-PowerBIRestMethod -Url $datasetsUrl -Method Get | ConvertFrom-Json
    $reportsInWorkspace = Invoke-PowerBIRestMethod -Url $reportsUrl -Method Get | ConvertFrom-Json
    $workspaceTime = (Get-Date) - $workspaceStart
    $workspaceMs = $workspaceTime.TotalMilliseconds
    
    Write-Host "  [SUCCESS] Workspace: $($workspaceInfo.name)" -ForegroundColor Green
    Write-Host "  [SUCCESS] Total Datasets: $($datasetsInWorkspace.value.Count)" -ForegroundColor Green
    Write-Host "  [SUCCESS] Total Reports: $($reportsInWorkspace.value.Count)" -ForegroundColor Green
    Write-Host "  [SUCCESS] Workspace Type: $($workspaceInfo.type)" -ForegroundColor Green
    
    $monitoringResults.Workspace = @{
        Name = $workspaceInfo.name
        Type = $workspaceInfo.type
        DatasetCount = $datasetsInWorkspace.value.Count
        ReportCount = $reportsInWorkspace.value.Count
        QueryTime = [math]::Round($workspaceMs, 2)
        Status = "Success"
    }
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "  [FAILED] Failed to get workspace info: $errorMsg" -ForegroundColor Red
    $monitoringResults.Workspace = @{
        Status = "Failed"
        Error = $errorMsg
    }
}

Write-Host ""
Write-Host "5. Performance Analysis..." -ForegroundColor Yellow

# Calculate overall performance metrics
$totalQueryTime = 0
if ($monitoringResults.Connectivity.ResponseTime -gt 0) { $totalQueryTime += $monitoringResults.Connectivity.ResponseTime }
if ($monitoringResults.Dataset.QueryTime) { $totalQueryTime += $monitoringResults.Dataset.QueryTime }
if ($monitoringResults.Refresh.QueryTime) { $totalQueryTime += $monitoringResults.Refresh.QueryTime }
if ($monitoringResults.Workspace.QueryTime) { $totalQueryTime += $monitoringResults.Workspace.QueryTime }

$avgResponseTime = [math]::Round($totalQueryTime / 4, 2)
$totalRounded = [math]::Round($totalQueryTime, 2)

Write-Host "  [SUCCESS] Total Query Time: $totalRounded ms" -ForegroundColor Green
Write-Host "  [SUCCESS] Average Response Time: $avgResponseTime ms" -ForegroundColor Green

$monitoringResults.Performance = @{
    TotalQueryTime = $totalRounded
    AverageResponseTime = $avgResponseTime
    Timestamp = Get-Date -Format "HH:mm:ss"
}

Write-Host ""
Write-Host "6. Alert Analysis..." -ForegroundColor Yellow

# Connectivity alerts
if ($monitoringResults.Connectivity.Status -eq "Failed") {
    $monitoringResults.Alerts += "CRITICAL: Power BI Service connectivity failed"
} elseif ($monitoringResults.Connectivity.ResponseTime -gt 5000) {
    $responseTime = $monitoringResults.Connectivity.ResponseTime
    $alertMsg = "WARNING: Slow Power BI Service connectivity ($responseTime ms)"
    $monitoringResults.Alerts += $alertMsg
}

# Dataset alerts
if ($monitoringResults.Dataset.Status -eq "Failed") {
    $monitoringResults.Alerts += "CRITICAL: Dataset query failed"
} elseif ($monitoringResults.Dataset.QueryTime -gt 3000) {
    $queryTime = $monitoringResults.Dataset.QueryTime
    $alertMsg = "WARNING: Slow dataset query response ($queryTime ms)"
    $monitoringResults.Alerts += $alertMsg
}

# Refresh alerts
if ($monitoringResults.Refresh.Status -eq "Success") {
    if ($monitoringResults.Refresh.LastStatus -eq "Failed") {
        $monitoringResults.Alerts += "CRITICAL: Last dataset refresh failed"
    } elseif ($monitoringResults.Refresh.RefreshAgeHours -gt 25) {
        $ageHours = $monitoringResults.Refresh.RefreshAgeHours
        $alertMsg = "WARNING: Dataset refresh is overdue (last refresh $ageHours hours ago)"
        $monitoringResults.Alerts += $alertMsg
    } elseif ($monitoringResults.Refresh.SuccessRate -lt 80) {
        $successRate = $monitoringResults.Refresh.SuccessRate
        $alertMsg = "WARNING: Low refresh success rate ($successRate%)"
        $monitoringResults.Alerts += $alertMsg
    }
}

# Performance alerts
if ($avgResponseTime -gt 4000) {
    $alertMsg = "WARNING: Overall slow API performance (avg: $avgResponseTime ms)"
    $monitoringResults.Alerts += $alertMsg
}

# Display alerts
if ($monitoringResults.Alerts.Count -eq 0) {
    Write-Host "  [SUCCESS] No issues detected - all systems healthy!" -ForegroundColor Green
} else {
    foreach ($alert in $monitoringResults.Alerts) {
        if ($alert.StartsWith("CRITICAL")) {
            Write-Host "  [CRITICAL] $alert" -ForegroundColor Red
        } else {
            Write-Host "  [WARNING] $alert" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "7. Saving Performance Data..." -ForegroundColor Yellow

# Create detailed performance record
$performanceRecord = [PSCustomObject]@{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ConnectivityStatus = $monitoringResults.Connectivity.Status
    ConnectivityTime = $monitoringResults.Connectivity.ResponseTime
    DatasetQueryTime = $monitoringResults.Dataset.QueryTime
    RefreshStatus = $monitoringResults.Refresh.LastStatus
    RefreshAgeHours = $monitoringResults.Refresh.RefreshAgeHours
    RefreshSuccessRate = $monitoringResults.Refresh.SuccessRate
    WorkspaceDatasets = $monitoringResults.Workspace.DatasetCount
    WorkspaceReports = $monitoringResults.Workspace.ReportCount
    TotalQueryTime = $monitoringResults.Performance.TotalQueryTime
    AverageResponseTime = $monitoringResults.Performance.AverageResponseTime
    AlertCount = $monitoringResults.Alerts.Count
}

# Save to CSV
$csvFile = "$performancePath\detailed-performance-$dateStamp.csv"
if (Test-Path $csvFile) {
    $performanceRecord | Export-Csv $csvFile -Append -NoTypeInformation
} else {
    $performanceRecord | Export-Csv $csvFile -NoTypeInformation
}

# Save diagnostics data
$diagnosticsFile = "$diagnosticsPath\diagnostics-$dateStamp.json"
$monitoringResults | ConvertTo-Json -Depth 4 | Out-File $diagnosticsFile -Encoding UTF8

# Save alerts if any
if ($monitoringResults.Alerts.Count -gt 0) {
    $alertsFile = "$alertsPath\alerts-$dateStamp.log"
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $alertHeader = "$currentTime - Alert Summary"
    $alertHeader | Out-File $alertsFile -Append
    $monitoringResults.Alerts | ForEach-Object { 
        $alertLine = "  - $_"
        $alertLine | Out-File $alertsFile -Append 
    }
    "" | Out-File $alertsFile -Append
}

Write-Host "  [SUCCESS] Performance data saved to CSV" -ForegroundColor Green
Write-Host "  [SUCCESS] Diagnostics saved to JSON" -ForegroundColor Green
if ($monitoringResults.Alerts.Count -gt 0) {
    Write-Host "  [SUCCESS] Alerts logged" -ForegroundColor Green
}

Write-Host ""
Write-Host "8. Committing to Git..." -ForegroundColor Yellow

Set-Location $repo
git add "monitoring/*"
git add "scripts/*"
$currentTime = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitMessage = "auto: Enhanced monitoring - $currentTime"
git commit -m $commitMessage
git push origin main

Write-Host "  [SUCCESS] Changes committed and pushed" -ForegroundColor Green

Write-Host ""
Write-Host "=== Monitoring Complete ===" -ForegroundColor Cyan

$connStatus = $monitoringResults.Connectivity.Status
Write-Host "Service Connectivity: $connStatus" -ForegroundColor White
if ($monitoringResults.Connectivity.ResponseTime -gt 0) {
    $connTime = $monitoringResults.Connectivity.ResponseTime
    Write-Host "  Response Time: $connTime ms" -ForegroundColor White
}

$datasetStatus = $monitoringResults.Dataset.Status
Write-Host "Dataset Health: $datasetStatus" -ForegroundColor White

$refreshStatus = $monitoringResults.Refresh.LastStatus
Write-Host "Refresh Status: $refreshStatus" -ForegroundColor White
if ($monitoringResults.Refresh.RefreshAgeHours) {
    $refreshAge = $monitoringResults.Refresh.RefreshAgeHours
    Write-Host "  Last Refresh: $refreshAge hours ago" -ForegroundColor White
}

$datasetCount = $monitoringResults.Workspace.DatasetCount
$reportCount = $monitoringResults.Workspace.ReportCount
Write-Host "Workspace: $datasetCount datasets, $reportCount reports" -ForegroundColor White

$avgTime = $monitoringResults.Performance.AverageResponseTime
Write-Host "Performance: $avgTime ms avg response" -ForegroundColor White

$alertCount = $monitoringResults.Alerts.Count
Write-Host "Alerts: $alertCount" -ForegroundColor White

Write-Host ""
Read-Host "Press Enter to close"