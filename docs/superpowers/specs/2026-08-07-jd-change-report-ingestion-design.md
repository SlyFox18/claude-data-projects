# JD National Change Report Ingestion — Design

## Overview

Sub-project 2 of the JD parts pricing effort (sub-project 1:
`docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md`,
now live and confirmed working). This spec covers ingesting John Deere's
**Global Parts Pricing** website "Change Reports" — a weekly CSV listing
**every** Deere part price change nationally, not just parts South Plains
carries. Requested by a stakeholder with no specific downstream analysis
in mind yet; the goal is reliable capture and storage, not analysis.

**Key difference from sub-project 1:** there is no automated network share
to poll. A file only ever exists because Brian manually logs into JD's
portal (2FA via SMS), downloads it, and places it somewhere. There is no
PowerShell harvest script here — Brian is the harvest step.

## Source Data

- **Where it comes from:** JD's Global Parts Pricing web portal
  (`pricednld.deere.com`), "United States (Change Reports) Weekly Price
  List" section. Requires login + SMS 2FA. Only the 4 most recent weekly
  reports are ever available to download at a time — no way to retrieve
  anything older after it rolls off that list.
- **File naming:** `US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv`, where the date
  is the report's effective date (confirmed: every row's own
  `EFFECTIVE DATE` column matches the filename's date exactly, since this
  file specifically lists *that week's* changes — unlike sub-project 1's
  file, where `effective_date` could be years older than the file itself
  for slow-moving parts. That risk does not apply here by construction.)
- **Format:** comma-delimited CSV, one header row:
  `PART NUMBER,CURRENT DNP,CURRENT SLP,NEW DNP,NEW SLP,EFFECTIVE DATE`.
  Confirmed byte-identical across all 4 currently-available files (plain
  ASCII, no BOM). Each line is padded with trailing spaces to a fixed
  record length (a legacy-export quirk) — parsing must `Text.Trim` every
  field, not just the last one.
- **Volume:** confirmed via the 4 files already downloaded (2026-07-13
  through 2026-08-03): row counts range from 195 to 39,964 depending on
  how many national price changes happened that week. No branch/franchise
  concept at all — this is a flat, national list.
- **Effective-date semantics:** DNP = Dealer Net Price, SLP = Suggested
  List Price (standard JD terminology). No further business meaning
  investigation needed for this ingestion layer.

## Non-Goals (this spec)

- Any analysis, comparison against `Raw_PriceUpdate_History`, or
  cross-referencing against `dim_Parts`/`InMaster` — sub-project 3's
  concern, not this one, per the original design's stated purpose (this
  data is being captured because a stakeholder asked, with no specific
  comparison in mind yet).
- Filtering to just South Plains-carried parts — raw ingestion captures
  the full national file as-is, same "raw layer stays raw" principle as
  sub-project 1.
- Any attempt to automate past the 2FA step (login automation, session
  reuse, etc.) — explicitly out of scope per Brian's decision; revisit in
  a future session if the manual step becomes a real burden.

## Architecture

```
JD web portal (manual: Brian logs in, 2FA, downloads CSV weekly)
        │
        │  [Brian manually copies the downloaded file into BOTH
        │   New/ and Archive/ — the same folders, same reason
        │   (idempotent processing, permanent audit copy) as
        │   sub-project 1, just without a script doing the copying]
        ▼
OneLake Files/JDChangeReports_Landing/
   ├── New/      ← cleared after each successful pipeline run
   └── Archive/  ← permanent copy of every file ever received
        │  [Fabric Pipeline pl_Raw_JDNationalChangeReport_History]
        │  1. Dataflow df_Raw_JDNationalChangeReport_History (Append)
        │  2. On success only: Delete data activity clears New/
        ▼
LH_Master_Data: Raw_JDNationalChangeReport_History
```

No `Quarantine/` folder — there is no automated validation gate before a
file reaches `New/` (Brian places it there directly), so there's nothing
for a script to quarantine against. Defensive parsing still lives in the
M query (see Error Handling) exactly as it does in sub-project 1, in case
a future week's file ever has a different shape.

## Raw Table Schema — `Raw_JDNationalChangeReport_History`

Grain: one row per part number + effective date + source file (raw event
log, same philosophy as sub-project 1 — no dedup at this layer).

| Source column | Raw table column | Notes |
|---|---|---|
| `PART NUMBER` | `PartNumber` | |
| `CURRENT DNP` | `CurrentDNP` | Dealer Net Price before this change |
| `CURRENT SLP` | `CurrentSLP` | Suggested List Price before this change |
| `NEW DNP` | `NewDNP` | Dealer Net Price after this change |
| `NEW SLP` | `NewSLP` | Suggested List Price after this change |
| `EFFECTIVE DATE` | `EffectiveDate` | Confirmed to always match the source filename's date |
| *(new)* | `SourceFileName` | Full filename, for traceability |
| *(new)* | `SourceFileDate` | Date parsed from the filename — cross-checked against `EffectiveDate` (see Error Handling) |
| *(new)* | `HasTypeConversionIssue` | Same defensive pattern as `Raw_PriceUpdate_History` — `true` if any numeric/date field had a non-blank value that failed to convert cleanly. Cheap insurance given sub-project 1 found a real reason for it; no known defect in this file format yet, but the file arrives from the same general JD export pipeline family |
| *(new)* | `IngestedAt` | Load timestamp, same DST-aware UTC→Central pattern (`.claude/queries/DATA-REFRESH-TEMPLATE.pq`) |

## Error Handling & Edge Cases

- **Type conversion:** every numeric (`CurrentDNP`, `CurrentSLP`, `NewDNP`,
  `NewSLP`) and date (`EffectiveDate`) conversion uses `try/otherwise`,
  exactly like the fix already proven in `Raw_PriceUpdate_History.pq` —
  a malformed value degrades that field to `null` and sets
  `HasTypeConversionIssue = true`, instead of risking an entire batch
  failure over one bad row.
- **Filename/content date mismatch:** `SourceFileDate` (parsed from
  filename) is compared against each row's own `EffectiveDate`. Per the
  confirmed real-file check, these should always match — a mismatch would
  indicate either a JD export anomaly or a file placed under the wrong
  name, worth a manual look but not blocking ingestion.
- **Trailing whitespace padding:** every parsed text/numeric value is
  `Text.Trim`'d before type conversion, since the raw file pads every line
  to a fixed record length with trailing spaces.
- **Duplicate/re-run safety:** identical mechanism to sub-project 1 —
  `New/` only clears after a confirmed successful append; re-running
  either side never double-appends, since a file already sitting in
  `Archive/` would need to be manually re-copied into `New/` to be
  reprocessed (no automated re-harvest exists here to accidentally do
  that).
- **Backfill:** the 4 currently-available files (2026-07-13, 07-20, 07-27,
  08-03) are the entire retrievable history — JD does not expose anything
  older once a report rolls off the 4-report list. No chunking needed at
  this volume.

## Weekly Reminder (unchanged scope decision from brainstorming)

Since no automation past the 2FA step was chosen, a weekly reminder
ensures Brian doesn't miss a report before it rolls off JD's 4-report
retention window. Two channels, both triggered by one new Windows
Scheduled Task:

- **Reynard todo item** — `POST http://localhost:5151/capture` with a
  reminder text. Reuses the existing, already-built `/capture` endpoint
  in `personal-dashboard/app.py` — no changes needed to Reynard itself for
  this specific integration.
- **Email** — via Outlook COM automation (`New-Object -ComObject
  Outlook.Application`), driving the already-signed-in Outlook desktop app
  on this machine to send the reminder. Chosen after checking:
  `fabric-monitoring`'s Teams notification is actually a plain webhook URL
  (`Invoke-RestMethod` to an Incoming Webhook), not Microsoft Graph — so
  there's no existing *unattended* Graph auth pattern in this repo to
  reuse, and building one from scratch (app registration or cached-token
  flow) would be disproportionate effort for a low-priority reminder.
  Outlook COM needs no API auth at all, at the cost of requiring Outlook
  desktop to be installed and configured on this machine. **Known risk:**
  Outlook can show a security prompt ("A program is trying to send an
  email on your behalf") that would block unattended sending — needs a
  one-time manual test run to confirm this doesn't fire, or a fix if it
  does (e.g. an Outlook Trust Center / Object Model Guard exception).
- **Timing:** weekly, targeting Saturday (JD's observed posting day, based
  on the Available/Effective date pattern seen on the portal — worth
  confirming against a few more weeks of real posting behavior before
  locking this in permanently).

## Related, Separately-Scoped Fix: Reynard Server Reliability

Found and partially fixed during this brainstorming session, tracked here
since the reminder mechanism depends on Reynard's `/capture` endpoint
being reachable: the `PersonalDashboard-Server` scheduled task's only
trigger is "at logon," so if the server process is ever cleanly
terminated (reboot, manual close) without a subsequent fresh Windows
login, it silently stays down — confirmed happened here (last run 3 days
prior to this session, no auto-recovery). Restarted manually as an
immediate fix (`Start-ScheduledTask -TaskName "PersonalDashboard-Server"`,
confirmed responding on port 5151).

**Planned durable fix:** add a repeating trigger (e.g. every 20 minutes)
to the existing task alongside its current "at logon" trigger, with
`MultipleInstances = IgnoreNew` so it never double-launches — if the
process is still alive, the repeat trigger is a no-op; if it died for any
reason, the next repeat trigger relaunches it within 20 minutes without
anyone needing to notice. Small, additive change to
`personal-dashboard/scripts/register-scheduled-tasks.ps1`.
