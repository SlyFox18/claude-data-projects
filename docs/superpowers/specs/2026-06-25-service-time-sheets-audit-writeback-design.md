# Service Time Sheets — Audit Write-Back Design Spec

**Date:** 2026-06-25
**Report:** Service Time Sheets
**Requested by:** CFO / Corp Service Manager (meeting 2026-06-23, follow-up request)
**Status:** Approved — ready for implementation

---

## Problem

The Time Sheet Audit table (Page 2) surfaces discrepancies, but there is no way to record that a flagged row has actually been investigated, or to capture what was found. Today, investigation outcomes live only in the Corp Service Manager's memory or in side conversations — there is no audit trail of who looked at a discrepancy, when, or what they concluded.

## Solution: Embedded Power Apps Write-Back Panel

A small Power Apps canvas app, embedded directly in Page 2 as a fixed side panel, lets the Corp Service Manager (primary user; CFO and After Market Sales Manager occasionally) select any row in the table and record an audit note. The note is written to a SharePoint list and read back into the semantic model on the next morning's refresh, surfacing a checkmark in the table.

**Users:** 1–3 people (primarily the Corp Service Manager). Small enough that Power Apps per-user licensing (already covered under the existing Microsoft 365 plan) is not a blocker.

**Refresh expectation:** Next-morning refresh is sufficient — this report is used in bursts around payroll, not continuously, and the CFO is mindful of F4 capacity usage. No DirectQuery, no near-real-time requirement.

---

## Scope

- **Page affected:** Page 2 (Time Sheet Audit) only. Not added to Page 3 (Tech Audit Detail) or any other page.
- **Rows auditable:** Any row, regardless of `AuditStatus`. Match and Pending rows rarely need it, but Draw rows sometimes do — restricting by status would add conditional logic for no real benefit, since the panel just reflects whatever row is currently selected.
- **No changes to:** ETL logic for `Fact_ServiceTimeSheet_Audit`, `AuditStatus` classification, hero card KPIs, any other page.

---

## Architecture

### Data flow

```
SharePoint List (ServiceTimeSheet_AuditLog)
  [Written by the Power Apps panel — always live]
        |
        ├─ read LIVE by Power Apps (panel's own lookup/display — has its own
        |   direct SharePoint connection, independent of Power BI refresh)
        |
        └─ read NIGHTLY by new Dataflow Gen2 (Phase 1, alongside df_ServiceTimeSheets_Raw)
                ↓
           LH_Master_Data.AuditLog (Lakehouse table)
                ↓ (Phase 5 semantic model refresh)
           Semantic Model — new "AuditLog" table (import mode, same
           Sql.Database(...) pattern as the two existing fact tables)
                ↓ (LOOKUPVALUE calculated columns, no model relationship)
           Fact_ServiceTimeSheet_Audit — AuditNote / AuditedBy / AuditedDate /
           IsAudited / AuditedIcon
                ↓
           Page 2 table — new "Audited" (✓ / blank) column
```

**Important nuance:** the Power Apps panel and the Page 2 table read from the same SharePoint list through two different paths with two different freshness guarantees. The panel always shows live data (it connects to SharePoint directly), so if the Service Manager re-opens a row she audited five minutes ago, her note is there. The table's ✓ column only updates the next morning, after the dataflow and semantic model refresh run. This is expected, not a bug — it follows directly from the "next morning is fine" refresh decision.

### SharePoint List — `ServiceTimeSheet_AuditLog`

Hosted on a separate, more restricted SharePoint site (not the time sheet submission site) — chosen by the user for tighter access control over investigation notes.

| Column | Type | Purpose |
|---|---|---|
| Title | Text (default SharePoint column) | Auto-generated, unused |
| TechNum | Single line text | Join key (matches `Fact_ServiceTimeSheet_Audit[TechNum]`) |
| RONumberText | Single line text | Join key (matches `Fact_ServiceTimeSheet_Audit[RONumberText]`) |
| PayEnd | Date | Join key (matches `Fact_ServiceTimeSheet_Audit[PayEnd]`) |
| AuditNote | Multiple lines of text | What was found during investigation |
| AuditedBy | Single line text | Captured from `User().FullName` in Power Apps |
| AuditedDate | Date and Time | Timestamp of the check-off, set by Power Apps on save |

One row per audited Tech × RO × PayPeriod combination — **upsert, not append**. Re-auditing a row updates the existing SharePoint item rather than creating a duplicate, so there's always exactly one record per key and no "latest record" logic needed anywhere downstream.

### Lookup mechanism — no synthetic key

DAX `LOOKUPVALUE` supports matching on multiple columns directly, so the join uses TechNum + RONumberText + PayEnd as three separate match criteria — no concatenated key column needed. This avoids any risk of date-formatting mismatches between what Power Apps writes and what DAX expects.

### New calculated columns — `Fact_ServiceTimeSheet_Audit.tmdl`

Same pattern as the existing `SharedRO`/`ROStatusDisplay` columns (cross-table lookup via calculated column, no model relationship):

```
AuditNote =
    LOOKUPVALUE(
        AuditLog[AuditNote],
        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
    )

AuditedBy =
    LOOKUPVALUE(
        AuditLog[AuditedBy],
        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
    )

AuditedDate =
    LOOKUPVALUE(
        AuditLog[AuditedDate],
        AuditLog[TechNum], Fact_ServiceTimeSheet_Audit[TechNum],
        AuditLog[RONumberText], Fact_ServiceTimeSheet_Audit[RONumberText],
        AuditLog[PayEnd], Fact_ServiceTimeSheet_Audit[PayEnd]
    )

IsAudited = NOT ISBLANK(Fact_ServiceTimeSheet_Audit[AuditedDate])

AuditedIcon = IF(Fact_ServiceTimeSheet_Audit[IsAudited], "✓", "")
```

### New table — `AuditLog` (semantic model)

Import-mode table reading from the Lakehouse, mirroring the exact connection pattern already used by `Fact_ServiceTimeSheet_Audit` and `Fact_InvoiceLabor`:

```
partition AuditLog = m
    mode: import
    source =
            let
                Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
                dbo_AuditLog = Source{[Schema="dbo",Item="AuditLog"]}[Data]
            in
                dbo_AuditLog
```

Columns: TechNum (string), RONumberText (string), PayEnd (dateTime), AuditNote (string), AuditedBy (string), AuditedDate (dateTime) — matching the Lakehouse table schema produced by the new dataflow.

### Page 2 table change

One new column: **Audited** (bound to `AuditedIcon`), narrow width, positioned immediately after the "RO Status" column (the last audit-related column currently in the table, added in the previous multi-tech RO display work). Shows ✓ or blank. The full note/who/when text is not duplicated in the table — it lives in the Power Apps panel — to avoid widening an already-dense table.

### Power Apps panel

- **Placement:** fixed side panel docked on the right edge of Page 2, always visible. (Switching to a collapsible/toggle panel later is a layout-only change — a bookmark-driven show/hide button — and does not touch the Power Apps app, the SharePoint list, or the data model. Safe to defer.)
- **Fields passed from Power BI to the visual** (via the Power Apps visual's Data well): TechName, TechNum, RONumberText, RONumber, PayEnd (and a friendly Pay Period label if useful), AuditStatus, HoursDifference.
- **Behavior on row selection:** reads `PowerBIIntegration.Data` for the selected row, then runs its own `LookUp` against the live SharePoint list using TechNum + RONumberText + PayEnd.
  - If a record exists: show the existing note, "Audited by {AuditedBy} on {AuditedDate}".
  - If not: show "Not Yet Reviewed".
- **Content:** selected-row context (Tech, RO, Pay Period, Audit Status, Hours Diff), current audit state, a multi-line text input for the note, and a single **Save** button.
- **Save behavior:** upsert via `Patch` — finds the existing SharePoint item by the three-column match and updates it, or creates a new item if none exists, setting `AuditedBy = User().FullName` and `AuditedDate = Now()`.
- The note field is optional — saving without typing anything still records who/when, in case there's nothing noteworthy to write but the row still needs to be marked as reviewed.

---

## What's Automatable vs. Manual

**File edits (no Desktop/Studio required):**
1. Add the `AuditLog` table definition to the semantic model TMDL (schema + partition, mirroring the existing `Sql.Database(...)` pattern)
2. Add the five new calculated columns to `Fact_ServiceTimeSheet_Audit.tmdl`

**Manual setup (no file-based authoring path exists for these):**
1. Create the SharePoint list `ServiceTimeSheet_AuditLog` on the user's separate, restricted SharePoint site
2. Build the Dataflow Gen2 (SharePoint list → `LH_Master_Data.AuditLog`), add it to Phase 1 of the pipeline orchestrator
3. Build the Power Apps canvas app — panel UI, live lookup, note field, Save/upsert logic — inside Power BI Desktop's embedded Power Apps visual editor
4. Embed the Power Apps visual on Page 2 as a fixed side panel, wire up the data fields it receives
5. Add the "Audited" column to the Page 2 table
6. End-to-end test: audit a row in Power Apps, confirm the SharePoint item, run the dataflow + semantic model refresh, confirm the ✓ appears in the table the next day

---

## Known Constraints & Gotchas

- **No model relationship** between `AuditLog` and `Fact_ServiceTimeSheet_Audit` — consistent with this report's existing convention of fully denormalized fact tables and `LOOKUPVALUE`-based cross-table lookups.
- **`AuditedDate` freshness skew is expected** — Power Apps shows live SharePoint data; the table's ✓ column lags until the next morning's refresh. Document this for the Service Manager so it isn't reported as a bug.
- **Upsert, not append** — the SharePoint list holds one row per Tech × RO × PayPeriod. The Power Apps `Patch` logic must look up the existing item before writing, or duplicates will accumulate and the `LOOKUPVALUE` columns will break (LOOKUPVALUE errors if more than one matching row is found).
- **TMDL files do not support `//` comments** at the structural level.
- **Lineage tag uniqueness** — check existing tags in `Fact_ServiceTimeSheet_Audit.tmdl` before assigning new ones for the calculated columns.
- **SharePoint site access** — whatever credential Fabric uses to authenticate the new Dataflow Gen2 must have read access to the user's separate restricted SharePoint site.
- **RONumberText, not RONumber** — joins must use the text version of the RO number, consistent with the rest of this report's join key convention (RONumber is a float in the source).

---

## Files to Edit

| File | Change |
|---|---|
| `reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` | Add `AuditNote`, `AuditedBy`, `AuditedDate`, `IsAudited`, `AuditedIcon` calculated columns |
| `reports/Service Time Sheets.SemanticModel/definition/tables/AuditLog.tmdl` | New table definition (schema + partition) |
| SharePoint (manual) | Create `ServiceTimeSheet_AuditLog` list on the user's restricted site |
| Fabric (manual) | New Dataflow Gen2, added to Phase 1 pipeline |
| Power BI Desktop (manual) | Build Power Apps canvas app, embed on Page 2, add "Audited" column to table |
