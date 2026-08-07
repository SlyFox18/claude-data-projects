<#
.SYNOPSIS
    Sends a weekly reminder to download JD's Global Parts Pricing Change
    Report before it rolls off the site's 4-report retention window.
.DESCRIPTION
    Posts a reminder item to Reynard (the local todo/capture system at
    http://localhost:5151/capture) and sends a reminder email via Outlook
    COM automation. Does not do anything automated about the actual
    download itself -- 2FA on JD's portal makes that out of scope (see
    docs/superpowers/specs/2026-08-07-jd-change-report-ingestion-design.md).

    Requires: Reynard's server running on port 5151 (PersonalDashboard-Server
    scheduled task) and Outlook desktop installed/configured under this
    same Windows user account.

    KNOWN RISK: Outlook can show a security prompt ("A program is trying
    to send an email on your behalf") that would block unattended sending.
    To guard against this hanging the script forever with nobody watching,
    the Outlook COM call is run in a background job (Start-Job -- confirmed
    working for out-of-process Outlook COM automation, ~3s round trip, no
    ThreadJob module needed) with an explicit 30-second timeout. If the job
    doesn't finish in time, it's stopped and logged as a timeout rather than
    left to hang indefinitely.

    ASSUMPTION: this script assumes Task 3's scheduled task runs under
    LogonType Interactive (a real, logged-in interactive session). Outlook
    COM automation may not work at all under SYSTEM or a "run whether user
    is logged on or not" logon type. If Task 3 is ever changed to a
    different logon type, re-verify Outlook COM still works before relying
    on this script unattended.
.PARAMETER EmailTo
    Recipient address for the reminder email.
.PARAMETER LogPath
    Optional. Defaults to a logs\reminder-YYYY-MM-DD.log file under
    projects\jd-price-updates\logs\, next to this script's parent folder.
.EXAMPLE
    .\Send-JDChangeReportReminder.ps1 -EmailTo "bfox@spitractor.com"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

    [string]$LogPath = (Join-Path $PSScriptRoot "..\logs\reminder-$(Get-Date -Format 'yyyy-MM-dd').log")
)

$ErrorActionPreference = "Stop"

function Write-ReminderLog {
    param([string]$Level, [string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $line
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $LogPath -Value $line
}

$reminderText = "Download this week's JD Global Parts Pricing Change Report"
$reminderNotes = "Log in to pricednld.deere.com (2FA via SMS), download the latest weekly Change Report CSV, and place it in both New/ and Archive/ under OneLake Files/JDChangeReports_Landing/. Only the 4 most recent weeks are ever available -- don't let one roll off."

$exitCode = 0

Write-ReminderLog "INFO" "Send-JDChangeReportReminder - Start"

# 1. Reynard todo item
try {
    $body = @{
        text  = $reminderText
        notes = $reminderNotes
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://localhost:5151/capture" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
    Write-ReminderLog "INFO" "Reynard todo item created, id=$($response.id)"
}
catch {
    Write-ReminderLog "ERROR" "FAILED to create Reynard todo item: $($_.Exception.Message)"
    $exitCode = 1
}

# 2. Email via Outlook COM -- run in a background job with an explicit
# timeout (see KNOWN RISK above). Without this, a blocked security prompt
# during a genuinely unattended run would hang $mail.Send() forever with
# zero diagnostic signal beyond "the log just stops." COM objects are
# created and released entirely inside the job's own process, so a timeout
# that kills the job also tears down any COM references with it.
$outlookJob = Start-Job -ScriptBlock {
    param($To, $Subject, $Body)
    $outlook = New-Object -ComObject Outlook.Application
    try {
        $mail = $outlook.CreateItem(0)  # 0 = olMailItem
        try {
            $mail.To = $To
            $mail.Subject = $Subject
            $mail.Body = $Body
            $mail.Send()
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($mail) | Out-Null
        }
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) | Out-Null
    }
} -ArgumentList $EmailTo, "Reminder: JD Change Report due this week", "$reminderText`r`n`r`n$reminderNotes"

try {
    if (Wait-Job -Job $outlookJob -Timeout 30) {
        Receive-Job -Job $outlookJob -ErrorAction Stop | Out-Null
        Write-ReminderLog "INFO" "Reminder email sent to $EmailTo"
    }
    else {
        Stop-Job -Job $outlookJob
        Write-ReminderLog "ERROR" "TIMEOUT: Outlook Send() did not return within 30s (likely a blocked security prompt) -- email NOT confirmed sent to $EmailTo"
        $exitCode = 1
    }
}
catch {
    Write-ReminderLog "ERROR" "FAILED to send reminder email: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    Remove-Job -Job $outlookJob -Force
}

Write-ReminderLog "INFO" "Send-JDChangeReportReminder - COMPLETED (exit $exitCode)"

exit $exitCode
