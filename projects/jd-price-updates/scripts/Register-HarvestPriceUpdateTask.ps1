#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Registers the daily Windows Scheduled Task that runs
    Harvest-PriceUpdateFiles.ps1.

.DESCRIPTION
    Must be run as Administrator. Creates a task named
    "JD Price Update Harvest" under Task Scheduler Library \ Fabric,
    running daily at 1:00 PM by default.

    Configured for reliable unattended operation:
      - Execution timeout: 45 minutes (prevents hung network access blocking pipeline)
      - Network dependency: task requires network to be available
      - Retry behavior: ignores new trigger if already running
      - Concurrency: only one instance runs at a time

    Fill in -SourceFolderPath and -LandingRootPath with the real values
    determined in the implementation plan's Task 6/7 before running this.

.PARAMETER SourceFolderPath
    The real network folder path (kept out of source control -- pass it at
    registration time, not hardcoded here).

.PARAMETER LandingRootPath
    The real local OneLake-mounted PriceUpdate_Landing path.

.PARAMETER TriggerTime
    Time of day to run, as "HH:mm". Defaults to 13:00. Originally 02:00 (to
    land before the main Fabric pipeline's 4:15 AM start) -- changed
    2026-09-01 after the 2:00 AM schedule silently failed for 11 straight
    days (2026-08-22 to 2026-09-01) with "Cannot find path" errors against
    the source share, while other unattended tasks on this same machine
    using the identical LogonType=Interactive succeeded reliably at 7-8 AM.
    Root cause: this exact CRITICAL risk, documented below since this
    script's original version, of the user session not being active that
    early. This report isn't on the Tier 1-3 automated pipeline schedule
    (it's refreshed manually in Desktop), and the harvest step itself has
    zero Fabric CU cost regardless of time of day (it's a local file copy,
    not a Fabric operation) -- so there was never a real reason to run this
    before dawn. 1:00 PM lands well inside the hours this machine has
    already proven reliable for unattended Interactive-logon tasks.

.EXAMPLE
    .\Register-HarvestPriceUpdateTask.ps1 -SourceFolderPath "\\<server>\...\Price_Update" -LandingRootPath "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data.Lakehouse\Files\PriceUpdate_Landing"

.NOTES
    CRITICAL: Tasks run as the current user and require the user session to be
    active (logged in) at the scheduled time. An early-morning trigger time
    (before you're typically logged in) creates a HIGH RISK of exactly this
    failure -- confirmed in production 2026-08-22 to 2026-09-01. Keep the
    trigger time within hours this machine is reliably logged in and active.

    If you need the task to run even when logged off, re-register this script with:
      -RunLevel Highest and supply a stored password in Windows Credential Manager.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolderPath,

    [Parameter(Mandatory = $true)]
    [string]$LandingRootPath,

    [string]$TriggerTime = "13:00"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Harvest-PriceUpdateFiles.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Harvest-PriceUpdateFiles.ps1 not found next to this script at $scriptPath"
}

$taskName = "JD Price Update Harvest"
$taskPath = "\Fabric\"

$argumentList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -SourceFolderPath `"$SourceFolderPath`" -LandingRootPath `"$LandingRootPath`""

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentList -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45) `
    -MultipleInstances IgnoreNew `
    -RunOnlyIfNetworkAvailable `
    -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

Write-Host "Registered scheduled task '$taskPath$taskName' to run daily at $TriggerTime."
Write-Host "Verify in Task Scheduler: Task Scheduler Library -> Fabric -> $taskName"
