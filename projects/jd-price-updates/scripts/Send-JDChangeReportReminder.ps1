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
    Test this manually once before relying on the scheduled version.
.PARAMETER EmailTo
    Recipient address for the reminder email.
.EXAMPLE
    .\Send-JDChangeReportReminder.ps1 -EmailTo "bfox@spitractor.com"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EmailTo
)

$ErrorActionPreference = "Stop"

$reminderText = "Download this week's JD Global Parts Pricing Change Report"
$reminderNotes = "Log in to pricednld.deere.com (2FA via SMS), download the latest weekly Change Report CSV, and place it in both New/ and Archive/ under OneLake Files/JDChangeReports_Landing/. Only the 4 most recent weeks are ever available -- don't let one roll off."

$exitCode = 0

# 1. Reynard todo item
try {
    $body = @{
        text  = $reminderText
        notes = $reminderNotes
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://localhost:5151/capture" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10
    Write-Host "Reynard todo item created, id=$($response.id)"
}
catch {
    Write-Host "FAILED to create Reynard todo item: $($_.Exception.Message)"
    $exitCode = 1
}

# 2. Email via Outlook COM
try {
    $outlook = New-Object -ComObject Outlook.Application
    $mail = $outlook.CreateItem(0)  # 0 = olMailItem
    $mail.To = $EmailTo
    $mail.Subject = "Reminder: JD Change Report due this week"
    $mail.Body = "$reminderText`r`n`r`n$reminderNotes"
    $mail.Send()
    Write-Host "Reminder email sent to $EmailTo"
}
catch {
    Write-Host "FAILED to send reminder email: $($_.Exception.Message)"
    $exitCode = 1
}

exit $exitCode
