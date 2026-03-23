<#
.SYNOPSIS
    One-time setup: registers all Fabric monitoring scheduled tasks in Windows.
    Run this script ONCE as Administrator to create the tasks.

.DESCRIPTION
    Creates two scheduled tasks:
      1. "Fabric - Post-Pipeline Monitoring"  (8:00 AM, Mon-Fri)
         Logs refresh history, checks freshness, updates CU tracking,
         commits documentation to dev branch, sends Teams notification.

      2. "Fabric - Azure Login Refresh"  (7:00 AM, Mon-Fri)
         Refreshes the saved Azure context so token requests keep working.
         Run slightly after monitoring so the token is always fresh next day.

    BEFORE RUNNING THIS SCRIPT:
      1. Open PowerShell as your normal user (not Admin) and run:
             Connect-AzAccount
             Save-AzContext -Path "$env:USERPROFILE\.azure\AzureRmContext.json" -Force
      2. Verify the token works:
             & "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\scripts\scheduled\Get-FreshToken.ps1"
      3. THEN run this registration script as Administrator.

.NOTES
    Tasks run as the CURRENT USER (bfox) so they use your cached credentials.
    Tasks require the user session to be active (logged in). If you need them
    to run when logged off, re-register with -RunLevel Highest and stored password.
#>

#Requires -RunAsAdministrator

$ScriptDir   = $PSScriptRoot
$MonitorScript = Join-Path $ScriptDir "Run-PostPipeline-Monitoring.ps1"
$LoginScript   = Join-Path $ScriptDir "Startup-AzureLogin.ps1"
$UserName      = $env:USERNAME

# Verify scripts exist before registering
if (-not (Test-Path $MonitorScript)) {
    Write-Error "Cannot find '$MonitorScript'. Run from the correct directory."
    exit 1
}

Write-Host "`nRegistering Fabric scheduled tasks..." -ForegroundColor Cyan
Write-Host "Script directory: $ScriptDir"
Write-Host "Running as user:  $UserName"

# ── Helper: create a task ────────────────────────────────────────────────────
function Register-FabricTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Description,
        [string]$Time,
        [string[]]$Days
    )

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$ScriptPath`"" `
        -WorkingDirectory $ScriptDir

    $trigger = New-ScheduledTaskTrigger `
        -Weekly `
        -DaysOfWeek $Days `
        -At $Time

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit        (New-TimeSpan -Minutes 45) `
        -MultipleInstances         IgnoreNew `
        -RunOnlyIfNetworkAvailable `
        -StartWhenAvailable

    $principal = New-ScheduledTaskPrincipal `
        -UserId    "$env:USERDOMAIN\$UserName" `
        -LogonType Interactive `
        -RunLevel  Limited

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName   $TaskName `
        -TaskPath   "\Fabric\" `
        -Action     $action `
        -Trigger    $trigger `
        -Settings   $settings `
        -Principal  $principal `
        -Description $Description `
        -Force | Out-Null

    Write-Host "  Registered: \Fabric\$TaskName" -ForegroundColor Green
    Write-Host "  Schedule:   $($Days -join ', ') at $Time"
    Write-Host "  Script:     $ScriptPath`n"
}

# ── Task 1: Post-pipeline monitoring ────────────────────────────────────────
Register-FabricTask `
    -TaskName   "Post-Pipeline Monitoring" `
    -ScriptPath $MonitorScript `
    -Description "Runs at 8 AM after all pipelines complete (Master ~5:27 AM, SM ~7:20 AM). Logs refresh history, checks freshness, sends Teams notification, pushes docs to dev." `
    -Time       "08:00AM" `
    -Days       @("Monday","Tuesday","Wednesday","Thursday","Friday")

# ── Task 2: Azure login refresh ──────────────────────────────────────────────
# Find Startup-AzureLogin.ps1 in parent scripts folder
$startupScript = Resolve-Path "$ScriptDir\..\Startup-AzureLogin.ps1" -ErrorAction SilentlyContinue
if ($startupScript) {
    Register-FabricTask `
        -TaskName   "Azure Login Refresh" `
        -ScriptPath $startupScript `
        -Description "Refreshes the cached Azure context daily so unattended token requests keep working." `
        -Time       "07:00AM" `
        -Days       @("Monday","Tuesday","Wednesday","Thursday","Friday")
} else {
    Write-Host "  Skipped: Azure Login Refresh (Startup-AzureLogin.ps1 not found)" -ForegroundColor Yellow
}

# ── Verify ───────────────────────────────────────────────────────────────────
Write-Host "`nRegistered tasks:" -ForegroundColor Cyan
Get-ScheduledTask -TaskPath "\Fabric\" -ErrorAction SilentlyContinue |
    Select-Object TaskName, State | Format-Table -AutoSize

Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Open Task Scheduler and find tasks under: Task Scheduler Library \ Fabric"
Write-Host "  2. Right-click 'Post-Pipeline Monitoring' and choose 'Run' to test it now"
Write-Host "  3. Check the log file after it runs:"
Write-Host "     $ScriptDir\..\..\logs\post-pipeline-$(Get-Date -Format 'yyyy-MM-dd').log"
Write-Host "  4. If it fails, see SCHEDULED-TASKS.md for troubleshooting steps"
