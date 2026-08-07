#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Registers the daily Windows Scheduled Task that runs
    Harvest-PriceUpdateFiles.ps1.

.DESCRIPTION
    Must be run as Administrator. Creates a task named
    "JD Price Update Harvest" under Task Scheduler Library \ Fabric,
    running daily at 2:00 AM (well before the Fabric pipeline's 4:15 AM start).

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
    Time of day to run, as "HH:mm". Defaults to 02:00 (well before the main
    Fabric pipeline's 4:15 AM start, so the day's harvest is sitting in
    New\ before the Fabric-side pipeline runs).

.EXAMPLE
    .\Register-HarvestPriceUpdateTask.ps1 -SourceFolderPath "\\<server>\...\Price_Update" -LandingRootPath "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data.Lakehouse\Files\PriceUpdate_Landing"

.NOTES
    CRITICAL: Tasks run as the current user and require the user session to be
    active (logged in) at the scheduled time. The 2:00 AM default trigger time
    creates a HIGH RISK that the machine may be asleep or logged off.

    Before registering, ENSURE ONE OF THE FOLLOWING:
      1. Machine is configured to NOT sleep before 4:15 AM, OR
      2. You configure Windows Power Settings to wake the machine at 2:00 AM, OR
      3. You accept that the task may fail silently if the machine is asleep
         (it will run on next wake, potentially missing the Fabric pipeline cutoff)

    If you need the task to run even when logged off, re-register this script with:
      -RunLevel Highest and supply a stored password in Windows Credential Manager.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolderPath,

    [Parameter(Mandatory = $true)]
    [string]$LandingRootPath,

    [string]$TriggerTime = "02:00"
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
