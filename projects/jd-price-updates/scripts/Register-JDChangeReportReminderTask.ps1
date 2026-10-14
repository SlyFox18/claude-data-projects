<#
.SYNOPSIS
    Registers the weekly Windows Scheduled Task that runs
    Send-JDChangeReportReminder.ps1.
.DESCRIPTION
    Must be run as Administrator. Creates a task named "JD Change Report
    Reminder" under Task Scheduler Library \ Fabric, running weekly on
    Saturday (JD's observed posting day, based on the Available/Effective
    date pattern seen on the portal -- confirm/adjust after a few more
    real weeks of posting data).

    NOTES (same caveats as Register-HarvestPriceUpdateTask.ps1):
    - Tasks run as the CURRENT USER so they use your cached credentials --
      this task's Outlook COM step and Reynard HTTP step both need your
      interactive session's resources (a running Outlook, a running
      Reynard server), so LogonType Interactive is required, not a
      service account.
    - Tasks require the user session to be active (logged in). If this
      machine is regularly logged off on Saturdays, this reminder will
      not fire until the next login -- consider whether that matters
      given JD's 4-report retention window.
.PARAMETER EmailTo
    Recipient address for the reminder email, passed through to
    Send-JDChangeReportReminder.ps1.
.PARAMETER TriggerTime
    Time of day to run, as "HH:mm". Defaults to 10:00.
.EXAMPLE
    .\Register-JDChangeReportReminderTask.ps1 -EmailTo "bfox@spitractor.com"
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

    [string]$TriggerTime = "10:00"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Send-JDChangeReportReminder.ps1"
if (-not (Test-Path $scriptPath)) {
    throw "Send-JDChangeReportReminder.ps1 not found next to this script at $scriptPath"
}

$taskName = "JD Change Report Reminder"
$taskPath = "\Fabric\"

$argumentList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -EmailTo `"$EmailTo`""

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentList -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At $TriggerTime
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -RunOnlyIfNetworkAvailable
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

Write-Host "Registered scheduled task '$taskPath$taskName' to run weekly on Saturday at $TriggerTime."
Write-Host "Verify in Task Scheduler: Task Scheduler Library -> Fabric -> $taskName"
Write-Host ""
Write-Host "NOTE: this task needs Outlook desktop running/configured under this same user account (for the email step) and Reynard's server running on port 5151 (for the todo-item step)."
