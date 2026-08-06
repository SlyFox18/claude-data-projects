<#
.SYNOPSIS
    Registers the daily Windows Scheduled Task that runs
    Harvest-PriceUpdateFiles.ps1.
.DESCRIPTION
    Must be run as Administrator. Creates a task named
    "JD Price Update Harvest" under Task Scheduler Library \ Fabric,
    running daily. Fill in -SourceFolderPath and -LandingRootPath with the
    real values determined in the implementation plan's Task 6/7 before
    running this.
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

$argumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -SourceFolderPath `"$SourceFolderPath`" -LandingRootPath `"$LandingRootPath`""

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentList
$trigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

Write-Host "Registered scheduled task '$taskPath$taskName' to run daily at $TriggerTime."
Write-Host "Verify in Task Scheduler: Task Scheduler Library -> Fabric -> $taskName"
