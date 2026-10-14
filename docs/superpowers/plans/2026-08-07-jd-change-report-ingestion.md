# JD National Change Report Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Tasks 1-4 are marked `[AUTOMATABLE]` — pure file edits/script development, testable against synthetic fixtures, that a subagent can do entirely inside this workspace (two of them touch the separate `personal-dashboard` repo, not `data-projects` — noted per task). Tasks 5-10 are marked `[MANUAL]` — Fabric portal work, the JD portal's 2FA-gated manual download, Windows Task Scheduler registration (elevation), and Outlook/Reynard runtime checks that must be done by Brian. Task 11 is `[AUTOMATABLE]` documentation. Do not attempt to script or automate a `[MANUAL]` task.

**Goal:** Ingest John Deere's national weekly "Change Report" CSVs (all Deere parts, not just what South Plains sells) into a new `Raw_JDNationalChangeReport_History` table in `LH_Master_Data`, reusing the harvest/landing/pipeline pattern already proven in sub-project 1 — plus a weekly reminder (Reynard todo + Outlook email) since there's no way to automate past JD's 2FA, and a small related reliability fix for the Reynard server itself.

**Architecture:** Since there's no automated network share for this source (files only exist because Brian manually downloads them from JD's 2FA-gated portal), there is no PowerShell harvest script — Brian manually places each week's file into both `New/` and `Archive/` under a new `Files/JDChangeReports_Landing/` OneLake folder. A Fabric Pipeline (Dataflow Gen2 Append, then a Delete data activity on success) parses and loads exactly like sub-project 1. A new Windows Scheduled Task sends a weekly reminder via two channels: a POST to Reynard's existing `/capture` endpoint, and an Outlook COM-automated email (chosen over Microsoft Graph after confirming `fabric-monitoring`'s Teams notification is actually a plain webhook, not Graph — building unattended Graph auth from scratch would be disproportionate for a low-priority reminder). See `docs/superpowers/specs/2026-08-07-jd-change-report-ingestion-design.md` for full design rationale, confirmed real file schema, and the Reynard reliability finding.

**Tech Stack:** PowerShell (reminder script, Windows Task Scheduler), Outlook COM automation (`New-Object -ComObject Outlook.Application`), Reynard's existing Flask `/capture` endpoint, Fabric Dataflow Gen2 (Power Query M, comma-delimited CSV parsing), Fabric Data Pipeline (Dataflow activity + Delete Data activity).

---

## Task 1 [AUTOMATABLE]: Raw table parsing query (Power Query M reference)

**Files:**
- Create: `.claude/queries/raw-tables/Raw_JDNationalChangeReport_History.pq`

Per repo convention, the actual Dataflow Gen2 is built in the Fabric portal (Task 7) — this file is the reference copy pasted into its Advanced Editor.

- [ ] **Step 1: Write `Raw_JDNationalChangeReport_History.pq`**

```powerquery
/*
============================================================================
Query: Raw_JDNationalChangeReport_History
Dataflow: df_Raw_JDNationalChangeReport_History
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parses JD Global Parts Pricing "Change Report" CSVs
(US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv), manually downloaded weekly by
Brian (2FA-gated JD portal, no automated harvest possible) and placed
into OneLake Files/JDChangeReports_Landing/New, appending parsed rows to
Raw_JDNationalChangeReport_History. Covers ALL Deere parts nationally,
not just parts South Plains carries -- see
docs/superpowers/specs/2026-08-07-jd-change-report-ingestion-design.md.

GRAIN: One row per PartNumber + EffectiveDate + SourceFileName (raw event
log, same "no dedup at this layer" philosophy as Raw_PriceUpdate_History).

SOURCE: OneLake Lakehouse Files -- LH_Master_Data / Files /
JDChangeReports_Landing / New (folder connector, configured via the
Dataflow Gen2 "Get Data > Lakehouse > Files" wizard -- the wizard-
generated step becomes `Source` below; replace the placeholder name with
whatever the wizard actually names it).

REFRESH: Append-only, driven by a Fabric Pipeline (dataflow refresh, then
on success only, a pipeline activity clears New/). No automated harvest
script exists for this source -- Brian places each week's file into both
New/ and Archive/ manually, since there's no network share to poll (JD's
portal requires interactive login + SMS 2FA).

DESTINATION LOAD SETTING: APPEND, not Replace. Same reasoning as
Raw_PriceUpdate_History: New/ only ever contains files not yet
successfully ingested.

FILE FORMAT: comma-delimited (NOT tab-delimited like Raw_PriceUpdate_History).
Confirmed byte-identical header across all 4 files available as of
2026-08-07: PART NUMBER,CURRENT DNP,CURRENT SLP,NEW DNP,NEW SLP,EFFECTIVE DATE.
Every line is padded with trailing spaces to a fixed record length (a
legacy-export quirk) -- every parsed value must be Text.Trim'd, not just
the last column.

FILENAME DATE: US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv -- confirmed the date
always matches every row's own EFFECTIVE DATE column exactly, since this
file specifically lists that week's changes (unlike Raw_PriceUpdate_History,
where effective_date can be years older than the file for slow-moving
parts). FileNameDateMismatchFlag below is a tripwire for this assumption,
not expected to ever fire based on the 4 files checked so far.

DEFENSE-IN-DEPTH (carried over from Raw_PriceUpdate_History, same
reasoning): missing-column tolerance via MissingField.UseNull, a
malformed-filename guard before fixed-index NameParts access, and
try/otherwise on every numeric/date conversion with a HasTypeConversionIssue
flag. No known defect in this file family yet (unlike Raw_PriceUpdate_History's
confirmed row-shift issue) -- this is precautionary, not reactive, cheap
insurance given the sibling table needed exactly this the hard way.
============================================================================
*/

let
    // Placeholder name -- replace with whatever the Dataflow Gen2 "Get Data
    // > Lakehouse > Files" wizard actually names this step when pointed at
    // JDChangeReports_Landing/New.
    Source = LakehouseFilesFolder_JDChangeReportsLandingNew,

    // Defensive filter -- only files matching the expected naming pattern.
    FilterToChangeReportFiles = Table.SelectRows(Source, each
        Text.StartsWith(Text.Upper([Name]), "US.UPDCOMP.UPDATE.V2-") and Text.EndsWith(Text.Upper([Name]), ".CSV")
    ),

    // ------------------------------------------------------------------
    // Parse the date out of the filename: US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv
    // {0, RelativePosition.FromEnd} = text before the LAST "." in the name,
    // i.e. strips the ".csv" extension regardless of case.
    // ------------------------------------------------------------------
    AddNameParts = Table.AddColumn(FilterToChangeReportFiles, "NameParts", each
        Text.Split(Text.BeforeDelimiter([Name], ".", {0, RelativePosition.FromEnd}), "-")),

    // Guard against fixed-index access below -- only the expected 4-token
    // shape (prefix, YYYY, MM, DD) proceeds past this point.
    FilterToWellFormedNames = Table.SelectRows(AddNameParts, each List.Count([NameParts]) = 4),

    AddSourceFileDate = Table.AddColumn(FilterToWellFormedNames, "SourceFileDate", each
        #date(Number.FromText([NameParts]{1}), Number.FromText([NameParts]{2}), Number.FromText([NameParts]{3})),
        type date),

    // ------------------------------------------------------------------
    // Parse file content: comma-delimited, header row promoted (parses by
    // column NAME downstream via ExpandTableColumn, not position).
    // ------------------------------------------------------------------
    AddParsedContent = Table.AddColumn(AddSourceFileDate, "ParsedContent", each
        Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = ",", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
            [PromoteAllScalars = true]
        )),

    ExpectedSourceColumns = {
        "PART NUMBER", "CURRENT DNP", "CURRENT SLP", "NEW DNP", "NEW SLP", "EFFECTIVE DATE"
    },

    // Normalize each row's parsed table to exactly ExpectedSourceColumns
    // before expanding. MissingField.UseNull fills any absent source
    // column with null instead of erroring.
    NormalizeParsedContent = Table.TransformColumns(AddParsedContent, {
        {"ParsedContent", each Table.SelectColumns(_, ExpectedSourceColumns, MissingField.UseNull), type table}
    }),

    SelectForExpand = Table.SelectColumns(NormalizeParsedContent,
        {"Name", "SourceFileDate", "ParsedContent"}),

    ExpandedRows = Table.ExpandTableColumn(SelectForExpand, "ParsedContent", ExpectedSourceColumns),

    // ------------------------------------------------------------------
    // Rename to PascalCase per repo convention
    // ------------------------------------------------------------------
    RenameColumns = Table.RenameColumns(ExpandedRows, {
        {"Name", "SourceFileName"},
        {"PART NUMBER", "PartNumber"},
        {"CURRENT DNP", "CurrentDNP"},
        {"CURRENT SLP", "CurrentSLP"},
        {"NEW DNP", "NewDNP"},
        {"NEW SLP", "NewSLP"},
        {"EFFECTIVE DATE", "EffectiveDate"}
    }),

    // ------------------------------------------------------------------
    // Data-quality tripwire: filename date vs each row's own EffectiveDate.
    // Computed on the raw text EffectiveDate (before SafeConvertRiskyColumns
    // below converts it to a real date), so a row whose EffectiveDate fails
    // to parse doesn't get double-counted here -- that's HasTypeConversionIssue's
    // job, not this flag's.
    // ------------------------------------------------------------------
    AddDateMismatchFlag = Table.AddColumn(RenameColumns, "FileNameDateMismatchFlag", each
        let
            rowDateText = Text.Trim(Text.From([EffectiveDate] ?? "")),
            rowDate = try Date.From(rowDateText) otherwise null
        in
            rowDate <> null and rowDate <> [SourceFileDate], type logical),

    // ------------------------------------------------------------------
    // IngestedAt -- DST-aware UTC -> Central, same pattern as
    // .claude/queries/DATA-REFRESH-TEMPLATE.pq
    // ------------------------------------------------------------------
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    AddIngestedAt = Table.AddColumn(AddDateMismatchFlag, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Data-quality tripwire: flags any row where a numeric/date field has
    // a non-blank value that fails to convert cleanly. Same defensive
    // pattern already proven necessary in Raw_PriceUpdate_History.pq --
    // precautionary here, no known defect in this file family yet.
    // Computed BEFORE SafeConvertRiskyColumns so it inspects RAW text.
    // ------------------------------------------------------------------
    AddConversionIssueFlag = Table.AddColumn(AddIngestedAt, "HasTypeConversionIssue", each
        let
            NumericValues = {[CurrentDNP], [CurrentSLP], [NewDNP], [NewSLP]},
            IsNumericIssue = (v) =>
                let t = Text.Trim(Text.From(v ?? "")) in
                t <> "" and (try Number.From(t) otherwise null) = null,
            DateText = Text.Trim(Text.From([EffectiveDate] ?? "")),
            IsDateIssue = DateText <> "" and (try Date.From(DateText) otherwise null) = null
        in
            List.AnyTrue(List.Transform(NumericValues, IsNumericIssue)) or IsDateIssue,
        type logical),

    // ------------------------------------------------------------------
    // Safe numeric/date conversions -- try/otherwise per value, so one
    // row's malformed field degrades just that field to null instead of
    // aborting the write for the entire batch.
    // ------------------------------------------------------------------
    SafeConvertRiskyColumns = Table.TransformColumns(AddConversionIssueFlag, {
        {"CurrentDNP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"CurrentSLP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"NewDNP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"NewSLP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"EffectiveDate", each try Date.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable date}
    }),

    // ------------------------------------------------------------------
    // Remaining type assignments (plain text) + final column order
    // ------------------------------------------------------------------
    ChangedTypes = Table.TransformColumnTypes(SafeConvertRiskyColumns, {
        {"PartNumber", type text}, {"SourceFileName", type text}, {"SourceFileDate", type date}
    }),

    FinalColumnOrder = Table.ReorderColumns(ChangedTypes, {
        "PartNumber", "EffectiveDate", "CurrentDNP", "CurrentSLP", "NewDNP", "NewSLP",
        "SourceFileName", "SourceFileDate", "FileNameDateMismatchFlag",
        "HasTypeConversionIssue", "IngestedAt"
    })
in
    FinalColumnOrder
```

No automated test is possible for M code outside Fabric — verification happens in Task 7 when this is pasted into the Dataflow Gen2 Advanced Editor and previewed against the real files.

- [ ] **Step 2: Manually trace the M logic against a real file before committing**

Using the actual downloaded file `US.UPDCOMP.UPDATE.V2-2026-08-03.csv` (header:
`PART NUMBER,CURRENT DNP,CURRENT SLP,NEW DNP,NEW SLP,EFFECTIVE DATE`, first
data row `A-AL77483,106.98,152.83,94.02,134.32,08/03/2026`):

- `Text.Split("US.UPDCOMP.UPDATE.V2-2026-08-03", "-")` → `{"US.UPDCOMP.UPDATE.V2", "2026", "08", "03"}` (4 elements — passes `FilterToWellFormedNames`)
- `#date(2026, 8, 3)` → confirms `SourceFileDate` matches the filename exactly
- Row: `PartNumber = "A-AL77483"`, `CurrentDNP = 106.98`, `EffectiveDate` parses `"08/03/2026"` → `#date(2026,8,3)`, matching `SourceFileDate` → `FileNameDateMismatchFlag = false`
- `HasTypeConversionIssue = false` for this row (all values convert cleanly)

Confirm this reasoning holds before moving to Step 3.

- [ ] **Step 3: Commit**

```bash
git add ".claude/queries/raw-tables/Raw_JDNationalChangeReport_History.pq"
git commit -m "Add Raw_JDNationalChangeReport_History parsing query reference"
```

---

## Task 2 [AUTOMATABLE]: Weekly reminder script

**Files:**
- Create: `projects/jd-price-updates/scripts/Send-JDChangeReportReminder.ps1`

- [ ] **Step 1: Write `Send-JDChangeReportReminder.ps1`**

```powershell
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
```

- [ ] **Step 2: Test the Reynard half against a real (but disposable) capture, with Reynard running**

```powershell
& "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\jd-price-updates\scripts\Send-JDChangeReportReminder.ps1" -EmailTo "bfox@spitractor.com"
```

Expected: `Reynard todo item created, id=<some number>` and `Reminder email sent to bfox@spitractor.com`, exit code 0. If Outlook shows a security prompt, this is the KNOWN RISK from the docstring — note it and flag it in Task 9 rather than trying to silently work around it here.

- [ ] **Step 3: Check the dashboard for the test item, then delete it**

Open `http://localhost:5151/` — confirm the reminder shows up in the inbox. Manually mark it completed or delete it via the dashboard UI (it was just a test, not a real week's reminder) so it doesn't linger as noise.

- [ ] **Step 4: Commit**

```bash
git add "projects/jd-price-updates/scripts/Send-JDChangeReportReminder.ps1"
git commit -m "Add weekly JD Change Report reminder script (Reynard + Outlook)"
```

---

## Task 3 [AUTOMATABLE]: Scheduled task registration script for the reminder

**Files:**
- Create: `projects/jd-price-updates/scripts/Register-JDChangeReportReminderTask.ps1`

- [ ] **Step 1: Write `Register-JDChangeReportReminderTask.ps1`**

```powershell
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
```

- [ ] **Step 2: Commit** (execution/verification happens in Task 9, since it requires Administrator elevation)

```bash
git add "projects/jd-price-updates/scripts/Register-JDChangeReportReminderTask.ps1"
git commit -m "Add scheduled task registration script for JD Change Report reminder"
```

---

## Task 4 [AUTOMATABLE]: Reynard server reliability fix

**Files:**
- Modify: `personal-dashboard/scripts/register-scheduled-tasks.ps1` (a **separate repo** from `data-projects` — local-only, `master` branch, no remote configured, no PR workflow needed, just commit directly)

Fixes the finding from this session's brainstorming: `PersonalDashboard-Server`'s only trigger is "at logon," so if the process is ever cleanly terminated without a subsequent fresh Windows login, it silently stays down (confirmed: it had been down for 3 days before this session, with no auto-recovery).

- [ ] **Step 1: Read the current file to get exact context**

```bash
cat "/c/Users/bfox/Documents/Git-Projects/personal-dashboard/scripts/register-scheduled-tasks.ps1"
```

- [ ] **Step 2: Replace the server task registration section**

Find this block (the first of the three task registrations in the file):

```powershell
# 1. Server auto-start at login, restart on failure
$serverAction = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$appScript`"" -WorkingDirectory $repoRoot
$serverTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$serverSettings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "PersonalDashboard-Server" -Action $serverAction -Trigger $serverTrigger -Settings $serverSettings -Force
```

Replace it with:

```powershell
# 1. Server auto-start at login, restart on failure, self-healing repeat check
$serverAction = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$appScript`"" -WorkingDirectory $repoRoot
$serverLogonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
# Repeating health-check trigger: if the server process was ever cleanly
# terminated (reboot, manual close) without a subsequent fresh Windows
# logon, the AtLogOn trigger above never refires -- confirmed this
# actually happened (server was down 3 days with no auto-recovery before
# this fix). This trigger fires every 20 minutes, indefinitely, and
# relaunches the server if it's not already running. MultipleInstances
# IgnoreNew (in $serverSettings below) makes this a safe no-op if the
# server is still alive -- Task Scheduler only considers a fresh launch
# necessary if the previously-triggered instance actually ended.
$serverRepeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 20) -RepetitionDuration ([TimeSpan]::MaxValue)
$serverSettings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "PersonalDashboard-Server" -Action $serverAction -Trigger @($serverLogonTrigger, $serverRepeatTrigger) -Settings $serverSettings -Force
```

- [ ] **Step 3: Commit directly (no PR needed — local-only repo)**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/personal-dashboard"
git add scripts/register-scheduled-tasks.ps1
git commit -m "Add self-healing repeat trigger to PersonalDashboard-Server task

The AtLogOn-only trigger never refires if the server process is cleanly
terminated without a subsequent fresh Windows login -- confirmed this
left the server down for 3 days with no auto-recovery. A repeating
20-minute health-check trigger now relaunches it if it's ever found not
running, with MultipleInstances IgnoreNew making it a safe no-op
otherwise."
```

Re-registration (actually applying this to the live scheduled task) happens in Task 10, since `scripts/register-scheduled-tasks.ps1` also needs Administrator elevation to run.

---

## Task 5 [MANUAL]: Create the OneLake landing folder structure

**Where:** OneLake File Explorer or the Fabric portal's Files browser.

- [ ] **Step 1: Create the landing folder structure**

```powershell
$landingRoot = "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data\LH_Master_Data.Lakehouse\Files\JDChangeReports_Landing"
New-Item -ItemType Directory -Path (Join-Path $landingRoot "New") -Force
New-Item -ItemType Directory -Path (Join-Path $landingRoot "Archive") -Force
```

No `Quarantine/` folder — see design spec, there's no automated harvest step to quarantine against.

- [ ] **Step 2: Verify via the Fabric portal's Files browser (not the local mount — confirmed unreliable this session)**

Open `LH_Master_Data` in the Fabric portal → Files → confirm `JDChangeReports_Landing/New` and `JDChangeReports_Landing/Archive` both exist.

---

## Task 6 [MANUAL]: Place the 4 already-downloaded files (one-time backfill)

**Where:** Brian's machine, PowerShell.

- [ ] **Step 1: Copy all 4 files from Downloads into both New/ and Archive/**

```powershell
$landingRoot = "C:\Users\bfox\OneLake - Microsoft\LH_Master_Data\LH_Master_Data.Lakehouse\Files\JDChangeReports_Landing"
$files = Get-ChildItem "C:\Users\bfox\Downloads" -Filter "US.UPDCOMP.UPDATE.V2-*.csv"
Write-Host "Found $($files.Count) files (expect 4)"
$files | ForEach-Object {
    Copy-Item $_.FullName -Destination (Join-Path $landingRoot "New") -Force
    Copy-Item $_.FullName -Destination (Join-Path $landingRoot "Archive") -Force
    Write-Host "Copied: $($_.Name)"
}
```

- [ ] **Step 2: Verify via the Fabric portal's Files browser**

Confirm both `New/` and `Archive/` show all 4 files: `US.UPDCOMP.UPDATE.V2-2026-07-13.csv`, `-2026-07-20.csv`, `-2026-07-27.csv`, `-2026-08-03.csv`.

---

## Task 7 [MANUAL]: Build the Dataflow Gen2 and Fabric Pipeline

**Where:** Fabric, `LH_Master_Data` workspace. Same shape as sub-project 1's Task 9 — follow that same process.

- [ ] **Step 1: Create the Dataflow Gen2** — new Dataflow Gen2 in `01 - Raw Sources`, name it `df_Raw_JDNationalChangeReport_History`. Get Data → Lakehouse → `LH_Master_Data` → navigate to `Files/JDChangeReports_Landing/New`.

- [ ] **Step 2: Paste the parsing logic** — open the Advanced Editor, paste the query from Task 1's `.pq` file, and rename the placeholder `Source = LakehouseFilesFolder_JDChangeReportsLandingNew` line's right-hand side to whatever the wizard actually generated for the folder-connection step in Step 1.

- [ ] **Step 3: Preview** — confirm the preview shows the 11 expected output columns (`PartNumber`, `EffectiveDate`, `CurrentDNP`, `CurrentSLP`, `NewDNP`, `NewSLP`, `SourceFileName`, `SourceFileDate`, `FileNameDateMismatchFlag`, `HasTypeConversionIssue`, `IngestedAt`) with no errors, using the 4 files landed in Task 6.

- [ ] **Step 4: Set the destination and rename the query** — rename the query from its default name to `Raw_JDNationalChangeReport_History` (this becomes the destination table name). Data destination → Lakehouse → `LH_Master_Data` → new table `Raw_JDNationalChangeReport_History` → Update method **Append**. Publish — do not run it standalone yet.

- [ ] **Step 5: Create the pipeline** — new Data Pipeline, name it `pl_Raw_JDNationalChangeReport_History`. Add a **Dataflow** activity referencing `df_Raw_JDNationalChangeReport_History`. Add a **Delete data** activity connected on **Success**, targeting Lakehouse `LH_Master_Data`, **File path type: Wildcard file path** (not plain "File path" — that mode silently no-ops, confirmed the hard way in sub-project 1), wildcard folder path `JDChangeReports_Landing/New`, wildcard file name `*.csv`, non-recursive. Uncheck "Enable logging" on the Delete data activity unless you want to set up a logging connection.

- [ ] **Step 6: Run the pipeline manually once** and verify via the SQL analytics endpoint:

```sql
SELECT COUNT(*) AS [TotalRows], COUNT(DISTINCT SourceFileName) AS [TotalFiles], MIN(EffectiveDate) AS [MinDate], MAX(EffectiveDate) AS [MaxDate] FROM Raw_JDNationalChangeReport_History
```

Expected: `TotalFiles = 4`, `MinDate = 2026-07-13`, `MaxDate = 2026-08-03`. Also confirm via the portal's Files browser that `New/` is now empty.

---

## Task 8 [MANUAL]: Confirm the backfill loaded correctly

**Where:** Fabric SQL analytics endpoint.

- [ ] **Step 1: Check row count is plausible**

The 4 files had 7,852 + 39,964 + 358 + 195 = 48,369 data rows total (header rows excluded). Confirm `TotalRows` from Task 7 Step 6's query is close to this (allowing for the header-row-count difference if any file had a trailing blank line).

- [ ] **Step 2: Check for flagged rows**

```sql
SELECT COUNT(*) AS [FlaggedRows] FROM Raw_JDNationalChangeReport_History WHERE HasTypeConversionIssue = 1 OR FileNameDateMismatchFlag = 1
```

If this returns 0 (expected, based on the 4 files already checked by hand), the ingestion is clean. If not, look at the flagged rows directly — this is new, unconfirmed territory unlike `Raw_PriceUpdate_History`'s already-diagnosed row-shift defect, so don't assume the same root cause without checking.

---

## Task 9 [MANUAL]: Register and test the reminder scheduled task

**Where:** Brian's machine, PowerShell (as Administrator for registration).

- [ ] **Step 1: Register the task**

```powershell
& "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\jd-price-updates\scripts\Register-JDChangeReportReminderTask.ps1" -EmailTo "bfox@spitractor.com"
```

- [ ] **Step 2: Verify in Task Scheduler** — Task Scheduler Library → Fabric → confirm "JD Change Report Reminder" exists, weekly Saturday trigger.

- [ ] **Step 3: Run it manually once and confirm both channels work**

Right-click the task → Run (or re-invoke `Send-JDChangeReportReminder.ps1` directly, per Task 2 Step 2). Confirm the Reynard todo item appears and the email arrives, with no Outlook security prompt blocking it. If a prompt does appear, this needs a decision (accept the manual click each time, since it only fires weekly, or investigate an Outlook Trust Center / Object Model Guard exception) before relying on this running unattended.

---

## Task 10 [MANUAL]: Apply the Reynard reliability fix

**Where:** Brian's machine, PowerShell (as Administrator).

- [ ] **Step 1: Re-run Reynard's registration script to apply Task 4's change**

```powershell
cd "C:\Users\bfox\Documents\Git-Projects\personal-dashboard"
powershell -File scripts\register-scheduled-tasks.ps1
```

- [ ] **Step 2: Verify the repeat trigger is present**

```powershell
(Get-ScheduledTask -TaskName "PersonalDashboard-Server").Triggers | Format-List
```

Expect two triggers: the original `AtLogOn` trigger, and a new one with `Repetition` showing a 20-minute interval.

- [ ] **Step 3: Confirm self-healing works** — stop the server process, wait up to 20 minutes (or manually trigger the repeat trigger's underlying scheduled run early via `Start-ScheduledTask` if you don't want to wait), and confirm it comes back without you doing anything.

```powershell
Get-Process python* | Stop-Process -Force
# wait, then check:
Invoke-WebRequest -Uri "http://localhost:5151/" -UseBasicParsing -TimeoutSec 5
```

---

## Task 11 [AUTOMATABLE]: Finalize documentation

**Files:**
- Modify: `projects/jd-price-updates/README.md`

- [ ] **Step 1: Add a "Sub-project 2: JD National Change Report" section** covering: the real Fabric object names (`df_Raw_JDNationalChangeReport_History`, `pl_Raw_JDNationalChangeReport_History`), the confirmed backfill counts from Task 8, the reminder task name/schedule, and the Outlook-COM-over-Graph decision with its known security-prompt risk.

- [ ] **Step 2: Update the "Next Steps" section** — mark sub-project 2 done, leave sub-project 3 (analysis layer) as the only remaining piece.

- [ ] **Step 3: Commit**

```bash
git add "projects/jd-price-updates/README.md"
git commit -m "Document JD National Change Report ingestion (sub-project 2)"
```
