# Service Time Sheets Audit Write-Back Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Tasks 3, 4, and 5 are marked `[AUTOMATABLE]` — pure file edits that a subagent can do. Every other task is marked `[MANUAL]` — work in SharePoint, Fabric, or Power BI Desktop that has no file-based path and must be done by the user. Do not attempt to script or automate a `[MANUAL]` task.

**Goal:** Let the Corp Service Manager (and occasionally the CFO / After Market Sales Manager) check off audited rows in the Time Sheet Audit table and record what was found, via an embedded Power Apps panel that writes to a SharePoint list synced through the Lakehouse overnight.

**Architecture:** A new SharePoint list holds audit records (Tech × RO × PayPeriod, upsert not append). A new Dataflow Gen2 pulls it into the Lakehouse nightly. The semantic model reads it as a new `AuditLog` table and surfaces it on `Fact_ServiceTimeSheet_Audit` via `LOOKUPVALUE` calculated columns (no model relationship, consistent with this report's existing convention). A Power Apps canvas app embedded on Page 2 reads/writes the SharePoint list live and is the only way data gets written.

**Tech Stack:** Power BI / Fabric (TMDL semantic model), SharePoint List, Fabric Dataflow Gen2, Power Apps (canvas app embedded via Power BI's Power Apps visual), DAX.

**Design spec:** `docs/superpowers/specs/2026-06-25-service-time-sheets-audit-writeback-design.md`

**Status: COMPLETE — live and in active use.** All tasks below shipped; the
checkbox tracking had fallen behind actual progress (several `[MANUAL]`
Power Apps Studio steps were done without being checked off as they
happened). Confirmed working in production as of 2026-09-03 — usage
history shows the panel was used by Mary or Gery within the past week.

---

## Task 1 [MANUAL]: Create the SharePoint Audit Log List

**Where:** Your separate, restricted SharePoint site (not the time sheet submission site).

- [X] **Step 1: Create a new list**

Name it exactly `ServiceTimeSheet_AuditLog` (this exact name is referenced later by the Dataflow Gen2 and the Power Apps formulas — if you use a different name, you must use that name consistently in Tasks 2 and 7 instead).

- [X] **Step 2: Add these six columns**

| Column name  | Type                                                                 | Notes                                                                         |
| ------------ | -------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| TechNum      | Single line of text                                                  | Join key — must match`Fact_ServiceTimeSheet_Audit[TechNum]` values exactly |
| RONumberText | Single line of text                                                  | Join key                                                                      |
| PayEnd       | Date and Time — set format to**Date Only**                    | Join key                                                                      |
| AuditNote    | Multiple lines of text — set to**Plain text** (not rich text) | What was found                                                                |
| AuditedBy    | Single line of text                                                  | Populated by Power Apps`User().FullName`, not typed by hand                 |
| AuditedDate  | Date and Time — set format to**Date and Time**                | Populated by Power Apps`Now()`                                              |

- [X] **Step 3: Leave the default "Title" column alone**

It's unused but SharePoint requires it to exist. No action needed.

- [X] **Step 4: Note the site URL**

You'll need it in Task 2 (Dataflow Gen2 source) and Task 7 (Power Apps data source). Keep it handy.

---

## Task 2 [MANUAL]: Build the Dataflow Gen2 and Add It to the Pipeline

**Where:** Fabric, `LH_Master_Data` workspace.

- [X] **Step 1: Create a new Dataflow Gen2**

Name it `df_ServiceTimeSheet_AuditLog`.

- [X] **Step 2: Connect to the SharePoint list**

Get Data → SharePoint list → paste the site URL from Task 1 → select the `ServiceTimeSheet_AuditLog` list.

- [X] **Step 3: Clean up the query**

SharePoint list connectors bring back default metadata columns (ID, Title, Author, Editor, Created, Modified, etc.) alongside your 6 custom columns. Remove all columns except: `TechNum`, `RONumberText`, `PayEnd`, `AuditNote`, `AuditedBy`, `AuditedDate`.

Verify types after cleanup:

- `TechNum` → Text
- `RONumberText` → Text
- `PayEnd` → Date (or Date/Time — either is fine since the Lakehouse will store it as datetime)
- `AuditNote` → Text
- `AuditedBy` → Text
- `AuditedDate` → Date/Time

- [X] **Step 4: Set the destination**

Lakehouse: `LH_Master_Data`. Table name: `AuditLog` (must match exactly — this is the table name referenced in Task 3's partition query). Update method: **Replace** (this list will only ever hold a small number of rows — full replace each run is simpler than incremental refresh and matches how other small reference tables in this project are handled).

- [X] **Step 5: Publish the dataflow**
- [X] **Step 6: Run it once manually**

Confirm it completes successfully and the `AuditLog` table appears in `LH_Master_Data` (it will have 0 rows right now since the SharePoint list is empty — that's expected).

- [X] **Step 7: Add it to Phase 1 of Pipeline_Master_Orchestrator**

Open the pipeline, go to the Phase 1 (Raw Data) activity group. Add a new Dataflow Gen2 activity referencing `df_ServiceTimeSheet_AuditLog`. No dependencies needed — it runs in parallel with the other Phase 1 raw dataflows (including `df_ServiceTimeSheets_Raw`), since it doesn't depend on anything else and nothing else depends on it at this phase. Save and publish the pipeline.

---

## Task 3 [AUTOMATABLE]: Create `AuditLog.tmdl`

**Files:**

- Create: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/AuditLog.tmdl`

This defines the new semantic model table that reads the `AuditLog` Lakehouse table created in Task 2. It mirrors the exact connection pattern already used by `Fact_ServiceTimeSheet_Audit.tmdl` and `Fact_InvoiceLabor.tmdl` — same SQL endpoint, different Lakehouse table name.

- [X] **Step 1: Create the file with this exact content**

```
table AuditLog
	lineageTag: b2e5f6a7-2222-4333-9444-000000000401

	column TechNum
		dataType: string
		lineageTag: b2e5f6a7-2222-4333-9444-000000000402
		summarizeBy: none
		sourceColumn: TechNum

		annotation SummarizationSetBy = Automatic

	column RONumberText
		dataType: string
		lineageTag: b2e5f6a7-2222-4333-9444-000000000403
		summarizeBy: none
		sourceColumn: RONumberText

		annotation SummarizationSetBy = Automatic

	column PayEnd
		dataType: dateTime
		formatString: Long Date
		lineageTag: b2e5f6a7-2222-4333-9444-000000000404
		summarizeBy: none
		sourceColumn: PayEnd

		annotation SummarizationSetBy = Automatic

		annotation UnderlyingDateTimeDataType = Date

	column AuditNote
		dataType: string
		lineageTag: b2e5f6a7-2222-4333-9444-000000000405
		summarizeBy: none
		sourceColumn: AuditNote

		annotation SummarizationSetBy = Automatic

	column AuditedBy
		dataType: string
		lineageTag: b2e5f6a7-2222-4333-9444-000000000406
		summarizeBy: none
		sourceColumn: AuditedBy

		annotation SummarizationSetBy = Automatic

	column AuditedDate
		dataType: dateTime
		formatString: General Date
		lineageTag: b2e5f6a7-2222-4333-9444-000000000407
		summarizeBy: none
		sourceColumn: AuditedDate

		annotation SummarizationSetBy = Automatic

	partition AuditLog = m
		mode: import
		source =
				let
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_AuditLog = Source{[Schema="dbo",Item="AuditLog"]}[Data]
				in
				    dbo_AuditLog
```

Before writing the file, verify none of the six lineage tags above (`b2e5f6a7-2222-4333-9444-000000000401` through `...0407`) already appear anywhere in `projects/service time sheets/reports/Service Time Sheets.SemanticModel/`. They were checked clean as of this plan's writing, but re-verify since other tables may have been edited since:

```bash
grep -rn "b2e5f6a7-2222-4333-9444" "projects/service time sheets/reports/Service Time Sheets.SemanticModel/"
```

Expected: no matches. If any match, pick different suffixes and use them consistently.

- [X] **Step 2: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/AuditLog.tmdl"
git commit -m "feat(service-time-sheets): add AuditLog semantic model table"
```

---

## Task 4 [AUTOMATABLE]: Register `AuditLog` in `model.tmdl`

**Files:**

- Modify: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/model.tmdl`

New tables must be explicitly registered in `model.tmdl` via a `ref table` line, and added to the `PBI_QueryOrder` annotation, or Power BI Desktop will not recognize the table file. The existing `dim_BranchLocation` table is a precedent for this exact situation: it's referenced by a `LOOKUPVALUE` calculated column on `Fact_ServiceTimeSheet_Audit` (the `WOBranchMismatch` column), and it appears in `PBI_QueryOrder` **before** `Fact_ServiceTimeSheet_Audit` so it loads first. `AuditLog` needs the same treatment, for the same reason — Task 5's calculated columns look it up.

- [X] **Step 1: Read the current file**

```bash
cat "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/model.tmdl"
```

You should see this line (line 11 as of this plan's writing):

```
annotation PBI_QueryOrder = ["Data Refresh","dim_BranchLocation","dim_DateTable","dim_Technician_Code_Names","Fact_ServiceTimeSheet_Audit","TechnicianInvoiceDetail","Fact_InvoiceLabor"]
```

And this block near the bottom:

```
ref table 'Data Refresh'
ref table dim_BranchLocation
ref table dim_DateTable
ref table 'New Report Tables'
ref table 'New Report Relationships'
ref table 'New Report Columns'
ref table _Measures
ref table dim_Technician_Code_Names
ref table Fact_ServiceTimeSheet_Audit
ref table TechnicianInvoiceDetail
ref table Fact_InvoiceLabor
```

If the file looks meaningfully different from this (e.g. a different table was added since), stop and report back rather than guessing at placement.

- [X] **Step 2: Insert "AuditLog" into PBI_QueryOrder, immediately before "Fact_ServiceTimeSheet_Audit"**

Change:

```
annotation PBI_QueryOrder = ["Data Refresh","dim_BranchLocation","dim_DateTable","dim_Technician_Code_Names","Fact_ServiceTimeSheet_Audit","TechnicianInvoiceDetail","Fact_InvoiceLabor"]
```

to:

```
annotation PBI_QueryOrder = ["Data Refresh","dim_BranchLocation","dim_DateTable","dim_Technician_Code_Names","AuditLog","Fact_ServiceTimeSheet_Audit","TechnicianInvoiceDetail","Fact_InvoiceLabor"]
```

- [X] **Step 3: Add a `ref table AuditLog` line immediately before `ref table Fact_ServiceTimeSheet_Audit`**

Change:

```
ref table dim_Technician_Code_Names
ref table Fact_ServiceTimeSheet_Audit
```

to:

```
ref table dim_Technician_Code_Names
ref table AuditLog
ref table Fact_ServiceTimeSheet_Audit
```

- [X] **Step 4: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/model.tmdl"
git commit -m "feat(service-time-sheets): register AuditLog table in model"
```

---

## Task 5 [AUTOMATABLE]: Add Calculated Columns to `Fact_ServiceTimeSheet_Audit.tmdl`

**Files:**

- Modify: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl`

Five new calculated columns, added after the existing `ROStatusDisplay` column (currently the last column in the file, ending right before the `partition` block). Two existing columns are your formatting reference:

- `WOBranchMismatch` (search for it in the file) — the precedent for a cross-table `LOOKUPVALUE` wrapped in `IFERROR`, which is the pattern `AuditNote`/`AuditedBy`/`AuditedDate` follow below (matching against multiple columns at once, and falling back to `BLANK()` rather than surfacing a hard DAX error to every report viewer if the SharePoint list ever ends up with a duplicate key — which would happen only if the Power Apps upsert logic in Task 7 has a bug, but a single bad row should not break Page 2 for everyone).
- `HasMultipleJobTypes` / `IsAudited` (below) — the precedent for a boolean calculated column's `formatString`.

- [X] **Step 1: Read the end of the file to find the exact insertion point and confirm current indentation**

```bash
tail -30 "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl"
```

You're looking for the `ROStatusDisplay` column's closing lines (`annotation SummarizationSetBy = Automatic` followed by a blank line) immediately before `partition Fact_ServiceTimeSheet_Audit = m`. Insert the five new columns between that blank line and the `partition` line. Match the exact tab-based indentation used by the surrounding columns — do not eyeball it, read the file and copy the indentation pattern from `WOBranchMismatch` and `HasMultipleJobTypes` directly.

- [X] **Step 2: Insert these five columns**

```
	column AuditNote =
			IFERROR(
			    LOOKUPVALUE(
			        AuditLog[AuditNote],
			        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
			        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
			        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
			    ),
			    BLANK()
			)
		dataType: string
		lineageTag: a1d4e5f6-1111-4222-8333-000000000301
		summarizeBy: none

		annotation SummarizationSetBy = Automatic

	column AuditedBy =
			IFERROR(
			    LOOKUPVALUE(
			        AuditLog[AuditedBy],
			        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
			        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
			        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
			    ),
			    BLANK()
			)
		dataType: string
		lineageTag: a1d4e5f6-1111-4222-8333-000000000302
		summarizeBy: none

		annotation SummarizationSetBy = Automatic

	column AuditedDate =
			IFERROR(
			    LOOKUPVALUE(
			        AuditLog[AuditedDate],
			        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
			        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
			        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
			    ),
			    BLANK()
			)
		dataType: dateTime
		formatString: General Date
		lineageTag: a1d4e5f6-1111-4222-8333-000000000303
		summarizeBy: none

		annotation SummarizationSetBy = Automatic

	column IsAudited =
			NOT ISBLANK(Fact_ServiceTimeSheet_Audit[AuditedDate])
		dataType: boolean
		formatString: """TRUE"";""TRUE"";""FALSE"""
		lineageTag: a1d4e5f6-1111-4222-8333-000000000304
		summarizeBy: none

		annotation SummarizationSetBy = Automatic

	column AuditedIcon =
			IF(Fact_ServiceTimeSheet_Audit[IsAudited], "✓", "")
		dataType: string
		lineageTag: a1d4e5f6-1111-4222-8333-000000000305
		summarizeBy: none

		annotation SummarizationSetBy = Automatic
```

Before writing, verify none of the five lineage tags (`a1d4e5f6-1111-4222-8333-000000000301` through `...0305`) already exist in this file:

```bash
grep -n "a1d4e5f6-1111-4222-8333" "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl"
```

Expected: no matches. If any match, pick different suffixes and use them consistently across all five.

- [X] **Step 3: Verify no `//` comments were introduced**

```bash
grep -n "^\s*//" "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl"
```

Expected: no matches (or only pre-existing matches inside DAX backtick expressions, if any existed before this edit).

- [X] **Step 4: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl"
git commit -m "feat(service-time-sheets): add audit write-back calculated columns"
```

---

## Task 6 [MANUAL]: Refresh and Verify in Power BI Desktop

**Where:** Power BI Desktop, with the Service Time Sheets PBIP open.

- [X] **Step 1: Open the report**

Desktop should detect the new `AuditLog` table and the five new calculated columns on `Fact_ServiceTimeSheet_Audit` from the TMDL changes in Tasks 3–5. If Desktop was already open when those files changed, close and reopen it (new TMDL tables sometimes need a fresh load, per past experience with this kind of change).

- [X] **Step 2: Refresh**

Refresh the `AuditLog` and `Fact_ServiceTimeSheet_Audit` tables. This should succeed even though `AuditLog` has 0 rows — the calculated columns will all return blank/false, which is correct for "nothing has been audited yet."

- [X] **Step 3: Spot-check with a DAX query**

Open the DAX query view and run:

```
EVALUATE TOPN(5, Fact_ServiceTimeSheet_Audit, Fact_ServiceTimeSheet_Audit[RONumber])
```

Confirm `AuditNote`, `AuditedBy`, `AuditedDate` are blank, `IsAudited` is `FALSE`, and `AuditedIcon` is an empty string for all 5 rows. If you see a DAX error instead of blanks, stop here — something in Task 5 needs fixing before moving on to building the Power Apps app.

---

## Task 7 [MANUAL]: Build the Power Apps Canvas App

**Where:** Power BI Desktop, Page 2 (Time Sheet Audit), inside the embedded Power Apps visual editor.

- [X] **Step 1: Insert the Power Apps visual**

On Page 2, resize the existing table to leave room on the right edge of the page for a side panel (a few inches of width is enough — this is the fixed panel from the design). Insert → Power Apps for Power BI. Choose "Create new."

- [X] **Step 2: Add the fields the panel needs**

In the visual's Data well, add these fields from `Fact_ServiceTimeSheet_Audit`: `TechName`, `TechNum`, `RONumberText`, `RONumber`, `PayEnd`, `PayPeriod`, `AuditStatus`, `HoursDifference`.

- [X] **Step 3: Add the SharePoint list as a data source inside Power Apps Studio**

Data sources → Add data → SharePoint → paste the site URL from Task 1 → select `ServiceTimeSheet_AuditLog`.

- [X] **Step 4: Build the screen layout**

Add these controls (names below are referenced by the formulas in the next step — use them exactly, or substitute your own names consistently):

- `lblTechName`, `lblRO`, `lblPayPeriod`, `lblAuditStatus`, `lblHoursDiff` — labels showing selected-row context
- `lblExistingStatus` — label showing the current audit state ("Not Yet Reviewed" or the existing note/who/when)
- `txtAuditNote` — a text input (multi-line) for the note
- `btnSave` — a button

- [X] **Step 5: Wire up `PowerBIIntegration.OnSelectionChanged`**

This fires whenever the selected row in the Power BI table changes. Set its formula to:

```
Set(
    varSelectedRow,
    First(PowerBIIntegration.Data)
);
Set(
    varExistingAudit,
    LookUp(
        ServiceTimeSheet_AuditLog,
        TechNum = varSelectedRow.TechNum && RONumberText = varSelectedRow.RONumberText && PayEnd = varSelectedRow.PayEnd
    )
);
Reset(txtAuditNote)
```

- [X] **Step 6: Set the context labels**

```
lblTechName.Text = varSelectedRow.TechName
lblRO.Text = "RO " & varSelectedRow.RONumberText
lblPayPeriod.Text = varSelectedRow.PayPeriod
lblAuditStatus.Text = varSelectedRow.AuditStatus
lblHoursDiff.Text = "Hours Diff: " & Text(varSelectedRow.HoursDifference, "#,##0.00")
```

- [X] **Step 7: Set the existing-audit status label**

```
lblExistingStatus.Text =
    If(
        IsBlank(varExistingAudit),
        "Not Yet Reviewed",
        "Audited by " & varExistingAudit.AuditedBy & " on " & Text(varExistingAudit.AuditedDate, "mm/dd/yyyy") & Char(10) & varExistingAudit.AuditNote
    )
```

- [X] **Step 8: Pre-fill the note field with any existing note**

```
txtAuditNote.Default = If(IsBlank(varExistingAudit), "", varExistingAudit.AuditNote)
```

- [X] **Step 9: Wire up the Save button**

This is the upsert: `LookUp` finds the existing record for this Tech/RO/PayPeriod (or returns blank if none exists), and `Patch` either updates that exact record or creates a new one if the lookup was blank. The note is optional by design — saving with an empty `txtAuditNote` still records who/when.

```
btnSave.OnSelect =
    Patch(
        ServiceTimeSheet_AuditLog,
        LookUp(
            ServiceTimeSheet_AuditLog,
            TechNum = varSelectedRow.TechNum && RONumberText = varSelectedRow.RONumberText && PayEnd = varSelectedRow.PayEnd
        ),
        {
            TechNum: varSelectedRow.TechNum,
            RONumberText: varSelectedRow.RONumberText,
            PayEnd: varSelectedRow.PayEnd,
            AuditNote: txtAuditNote.Text,
            AuditedBy: User().FullName,
            AuditedDate: Now()
        }
    );
    Set(
        varExistingAudit,
        LookUp(
            ServiceTimeSheet_AuditLog,
            TechNum = varSelectedRow.TechNum && RONumberText = varSelectedRow.RONumberText && PayEnd = varSelectedRow.PayEnd
        )
    );
    Notify("Saved", NotificationType.Success)
```

- [X] **Step 10: Save the Power Apps app**

Save and close the Power Apps Studio editor, returning to Power BI Desktop.

---

## Task 8 [MANUAL]: Position the Panel and Add the "Audited" Column

**Where:** Power BI Desktop, Page 2.

- [X] **Step 1: Position the Power Apps visual**

Confirm it's docked as a fixed panel along the right edge of the page, sized so the table doesn't require horizontal scrolling to reach it, per the design decision to keep it always visible rather than collapsible (a collapse toggle can be added later as a layout-only change if the width turns out to be a problem — it would not require touching the Power Apps app or data model).

- [X] **Step 2: Add the "Audited" column to the table**

Add the `AuditedIcon` field to the Page 2 table visual, positioned immediately after the existing "RO Status" column. Rename the column header to "Audited."

- [X] **Step 3: Save**

---

## Task 9 [MANUAL]: End-to-End Test and Publish

**Where:** Power BI Desktop (Page 2), SharePoint, Fabric.

- [X] **Step 1: Test a fresh audit**

Select a row with a real discrepancy (e.g. an "Invoiced More Than Claimed" or "Claimed More Than Invoiced" row). Confirm the panel shows the correct Tech, RO, Pay Period, Audit Status, and Hours Diff, and that `lblExistingStatus` reads "Not Yet Reviewed."

- [X] **Step 2: Save a note**

Type a test note in `txtAuditNote`, click Save. Confirm the "Saved" notification appears.

- [X] **Step 3: Verify in SharePoint**

Open the `ServiceTimeSheet_AuditLog` list directly. Confirm exactly one new item exists with the correct `TechNum`, `RONumberText`, `PayEnd`, `AuditNote`, your name in `AuditedBy`, and a current timestamp in `AuditedDate`.

- [X] **Step 4: Verify row switching**

Click a different row in the table. Confirm the panel updates to that row's context and shows "Not Yet Reviewed" (assuming it hasn't been audited).

- [X] **Step 5: Verify the upsert (not append)**

Click back to the row you audited in Step 2. Confirm `lblExistingStatus` shows your note, who, and when — this is the **live** SharePoint read working as designed, ahead of any Power BI refresh. Edit the note text and click Save again. Go back to SharePoint and confirm the item **count is unchanged** — the same item was updated, not duplicated.

- [X] **Step 6: Verify the nightly sync path**

Manually trigger `df_ServiceTimeSheet_AuditLog` (from Task 2). Confirm the Lakehouse `AuditLog` table now has 1 row matching what's in SharePoint.

- [X] **Step 7: Refresh the semantic model**

Refresh `AuditLog` and `Fact_ServiceTimeSheet_Audit`. Confirm the "Audited" ✓ now appears in the Page 2 table for the row you audited, and nowhere else.

- [X] **Step 8: Follow the established deployment workflow before going live**

This introduces a new external data source (SharePoint) and new semantic model tables/columns — per this project's standard workflow, that counts as a significant change. Publish to RP-Dev first and verify privately, then promote through RP-Sandbox for stakeholder validation before publishing to RP - Service Reports. Don't skip straight to production for this one.
