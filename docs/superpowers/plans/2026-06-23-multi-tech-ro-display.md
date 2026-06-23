# Multi-Tech RO Visual De-alarm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** De-alarm shared-RO "Invoiced More Than Claimed" rows in the Time Sheet Audit tables on Pages 2 and 3 by switching them from yellow to blue and adding a compact "RO Status" column that shows the aggregate RO-level outcome inline.

**Architecture:** Two TMDL file edits (calculated column + four measure changes), followed by two Power BI Desktop table visual changes. No ETL changes. No hero card KPI changes. The calculated column `ROStatusDisplay` mirrors the pattern of the existing `SharedRO` column using `CALCULATE(..., ALL(...), RONumber = _RO)` to evaluate across the full table at row compute time.

**Tech Stack:** TMDL (direct file edit), DAX, Power BI Desktop (PBIP format), `pbi` CLI for post-open verification.

**Design spec:** `docs/superpowers/specs/2026-06-23-multi-tech-ro-display-design.md`

---

## File Map

| File | Change |
|---|---|
| `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` | Add `ROStatusDisplay` calculated column after line 358 (after existing `SharedRO` column) |
| `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl` | Add `RO Status Display Color` measure; update `Hours Diff Color` (line 148), `Row Status Color` (line 256), `Hours Diff Color Bar` (line 605) |
| Desktop: Page 2 table visual | Add `ROStatusDisplay` field after Audit Status, apply CF |
| Desktop: Page 3 table visual | Add `ROStatusDisplay` field after Audit Status, apply CF |

---

### Task 1: Add `ROStatusDisplay` calculated column to `Fact_ServiceTimeSheet_Audit.tmdl`

**Files:**
- Modify: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` (after line 358)

This column uses the same `CALCULATE(..., ALL(Fact_ServiceTimeSheet_Audit), RONumber = _RO)` pattern as the existing `SharedRO` column (lines 340–358). It returns the RO-level audit outcome as short text for shared-RO rows, and `BLANK()` for single-tech rows. Evaluated at model refresh time — not a measure.

- [ ] **Step 1: Verify the insertion point**

Open `Fact_ServiceTimeSheet_Audit.tmdl`. Find the `SharedRO` calculated column block — it ends around line 358 with:

```
    annotation SummarizationSetBy = Automatic
```

The next line after that is blank, then `column IsClosed`. You will insert the new column **between the end of `SharedRO` and the start of `column IsClosed`**.

Confirm no existing column is named `ROStatusDisplay` (search the file).

- [ ] **Step 2: Confirm lineage tag `d4e5f6a7-b8c9-4123-6cde-f01234567901` is unused**

Search both TMDL files for this string:

```
d4e5f6a7-b8c9-4123-6cde-f01234567901
```

Expected: no matches. If it matches, choose a different UUID-shaped string that does not appear in either file.

- [ ] **Step 3: Insert the new calculated column**

In `Fact_ServiceTimeSheet_Audit.tmdl`, insert the following block immediately after the closing `annotation SummarizationSetBy = Automatic` line of the `SharedRO` column (after line 358), before `column IsClosed`:

```
	column ROStatusDisplay =
			VAR _RO = Fact_ServiceTimeSheet_Audit[RONumber]
			VAR _CommTechs =
			    CALCULATE(
			        DISTINCTCOUNT(Fact_ServiceTimeSheet_Audit[TechNum]),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO
			    )
			VAR _ClaimedMore =
			    CALCULATE(
			        COUNTROWS(Fact_ServiceTimeSheet_Audit),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO,
			        Fact_ServiceTimeSheet_Audit[AuditStatus] = "Claimed More Than Invoiced"
			    )
			VAR _InvoicedMore =
			    CALCULATE(
			        COUNTROWS(Fact_ServiceTimeSheet_Audit),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO,
			        Fact_ServiceTimeSheet_Audit[AuditStatus] = "Invoiced More Than Claimed"
			    )
			VAR _Partial =
			    CALCULATE(
			        COUNTROWS(Fact_ServiceTimeSheet_Audit),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO,
			        Fact_ServiceTimeSheet_Audit[AuditStatus] = "Partial Invoice - In Progress"
			    )
			VAR _Draw =
			    CALCULATE(
			        COUNTROWS(Fact_ServiceTimeSheet_Audit),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO,
			        Fact_ServiceTimeSheet_Audit[AuditStatus] IN {"Draw - Open RO", "Draw - In Progress"}
			    )
			VAR _Pending =
			    CALCULATE(
			        COUNTROWS(Fact_ServiceTimeSheet_Audit),
			        ALL(Fact_ServiceTimeSheet_Audit),
			        Fact_ServiceTimeSheet_Audit[RONumber] = _RO,
			        Fact_ServiceTimeSheet_Audit[AuditStatus] = "Pending Invoice"
			    )
			RETURN
			    IF(
			        _CommTechs <= 1, BLANK(),
			        IF(_ClaimedMore > 0 && _InvoicedMore > 0, "Mixed",
			        IF(_ClaimedMore > 0,                      "Claimed More",
			        IF(_InvoicedMore > 0,                     "Invoiced More",
			        IF(_Partial > 0,                          "Partial",
			        IF(_Draw > 0,                             "Draw",
			        IF(_Pending > 0,                          "Pending",
			                                                  "Match"))))))
			    )
		dataType: string
		lineageTag: d4e5f6a7-b8c9-4123-6cde-f01234567901
		summarizeBy: none

		annotation SummarizationSetBy = Automatic

```

Critical formatting notes:
- Each line inside the DAX expression is indented with **two tabs** (matching the `SharedRO` column above it)
- The `dataType:`, `lineageTag:`, `summarizeBy:`, and `annotation` lines are indented with **one tab**
- There must be a blank line after the closing `annotation` line before the next column block
- Do **not** add any `//` comment lines — TMDL does not support them at the structural level

- [ ] **Step 4: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl"
git commit -m "feat(service-time-sheets): add ROStatusDisplay calculated column"
```

---

### Task 2: Add `RO Status Display Color` measure to `_Measures.tmdl`

**Files:**
- Modify: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl`

This measure maps the short-form text values from `ROStatusDisplay` to hex color strings. Used as the font color conditional formatting rule on the new `RO Status` column in the table visuals.

- [ ] **Step 1: Confirm lineage tag `f0f1f2f3-f4f5-4f67-a001-000000000200` is unused**

Search `_Measures.tmdl` for:

```
000000000200
```

Expected: no matches. The IL measure series ends at `...0131`. If it matches, use `...000000000201` or another unused suffix.

- [ ] **Step 2: Find the insertion point**

In `_Measures.tmdl`, locate the last measure before `column Value`. It is `IL Status Color`, ending around line 1415 with:

```
	lineageTag: f0f1f2f3-f4f5-4f67-a001-000000000128
```

The next non-blank line is `column Value` (hidden). Insert the new measure **between the end of `IL Status Color` and the `column Value` block**.

- [ ] **Step 3: Insert the new measure**

Add the following block after the `IL Status Color` lineageTag line and before `column Value`:

```
	measure 'RO Status Display Color' =
			SWITCH(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[ROStatusDisplay]),
			    "Match",        "#16A34A",
			    "Claimed More", "#DC2626",
			    "Invoiced More","#B45309",
			    "Mixed",        "#6D28D9",
			    "Partial",      "#8B5CF6",
			    "Draw",         "#2563EB",
			    "Pending",      "#64748B",
			    BLANK()
			)
		lineageTag: f0f1f2f3-f4f5-4f67-a001-000000000200

```

Indentation: two tabs inside the measure expression body, one tab for `lineageTag`. Blank line after the lineageTag.

- [ ] **Step 4: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(service-time-sheets): add RO Status Display Color measure"
```

---

### Task 3: Update `Hours Diff Color`, `Row Status Color`, and `Hours Diff Color Bar` in `_Measures.tmdl`

**Files:**
- Modify: `projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl`

All three measures get the same pattern: wrap the existing `SWITCH` in an `IF` that intercepts shared-RO "Invoiced More" rows and returns a neutral color before the `SWITCH` runs.

Trigger condition (same for all three):
```
SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]) = "Invoiced More Than Claimed"
    && CONTAINSSTRING(SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[SharedRO]), "Commission Techs")
```

The `SharedRO` calculated column was pre-computed at refresh time. `SELECTEDVALUE` works here because conditional formatting measures evaluate in the row filter context of the table visual.

- [ ] **Step 1: Update `Hours Diff Color` (around line 148)**

Find this block (lineageTag `f9a0b1c2-d3e4-4567-1234-678901200017`):

```
	measure 'Hours Diff Color' =
			SWITCH(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			    "Claimed More Than Invoiced",     "#DC2626",
			    "Invoiced More Than Claimed",     "#B45309",
			    "Partial Invoice - In Progress",  "#8B5CF6",
			    "Match",                          "#16A34A",
			    "Draw - Open RO",                 "#2563EB",
			    "Pending Invoice",                "#64748B",
			    "Draw - In Progress",             "#D97706",
			    BLANK()
			)
		lineageTag: f9a0b1c2-d3e4-4567-1234-678901200017
```

Replace with:

```
	measure 'Hours Diff Color' =
			IF(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]) = "Invoiced More Than Claimed"
			        && CONTAINSSTRING(SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[SharedRO]), "Commission Techs"),
			    "#64748B",
			    SWITCH(
			        SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			        "Claimed More Than Invoiced",     "#DC2626",
			        "Invoiced More Than Claimed",     "#B45309",
			        "Partial Invoice - In Progress",  "#8B5CF6",
			        "Match",                          "#16A34A",
			        "Draw - Open RO",                 "#2563EB",
			        "Pending Invoice",                "#64748B",
			        "Draw - In Progress",             "#D97706",
			        BLANK()
			    )
			)
		lineageTag: f9a0b1c2-d3e4-4567-1234-678901200017
```

- [ ] **Step 2: Update `Row Status Color` (around line 256)**

Find this block (lineageTag `b0c1d2e3-f4a5-4678-2345-789012300030`):

```
	measure 'Row Status Color' =
			SWITCH(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			    "Claimed More Than Invoiced",     "#FEE2E2",
			    "Invoiced More Than Claimed",     "#FEF3C7",
			    "Partial Invoice - In Progress",  "#F5F3FF",
			    "Match",                          "#F0FDF4",
			    "Draw - Open RO",                 "#EFF6FF",
			    "Pending Invoice",                "#F8FAFC",
			    "Draw - In Progress",             "#FFF7ED",
			    "⚠",                              "#E57F7F",
			    "#FFFFFF"
			)
		lineageTag: b0c1d2e3-f4a5-4678-2345-789012300030
```

Replace with:

```
	measure 'Row Status Color' =
			IF(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]) = "Invoiced More Than Claimed"
			        && CONTAINSSTRING(SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[SharedRO]), "Commission Techs"),
			    "#EFF6FF",
			    SWITCH(
			        SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			        "Claimed More Than Invoiced",     "#FEE2E2",
			        "Invoiced More Than Claimed",     "#FEF3C7",
			        "Partial Invoice - In Progress",  "#F5F3FF",
			        "Match",                          "#F0FDF4",
			        "Draw - Open RO",                 "#EFF6FF",
			        "Pending Invoice",                "#F8FAFC",
			        "Draw - In Progress",             "#FFF7ED",
			        "⚠",                              "#E57F7F",
			        "#FFFFFF"
			    )
			)
		lineageTag: b0c1d2e3-f4a5-4678-2345-789012300030
```

- [ ] **Step 3: Update `Hours Diff Color Bar` (around line 605)**

Find this block (lineageTag `caf41df0-0c34-4e72-a1b9-5b34f236aea0`):

```
	measure 'Hours Diff Color Bar' =
			SWITCH(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			    "Claimed More Than Invoiced",     "#F87171",
			    "Invoiced More Than Claimed",     "#facc15",
			    "Partial Invoice - In Progress",  "#C4B5FD",
			    "Match",                          "#16A34A",
			    "Draw - Open RO",                 "#60A5FA",
			    "Pending Invoice",                "#CBD5E1",
			    "Draw - In Progress",             "#FB923C",
			    BLANK()
			)
		lineageTag: caf41df0-0c34-4e72-a1b9-5b34f236aea0
```

Replace with:

```
	measure 'Hours Diff Color Bar' =
			IF(
			    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]) = "Invoiced More Than Claimed"
			        && CONTAINSSTRING(SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[SharedRO]), "Commission Techs"),
			    "#CBD5E1",
			    SWITCH(
			        SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]),
			        "Claimed More Than Invoiced",     "#F87171",
			        "Invoiced More Than Claimed",     "#facc15",
			        "Partial Invoice - In Progress",  "#C4B5FD",
			        "Match",                          "#16A34A",
			        "Draw - Open RO",                 "#60A5FA",
			        "Pending Invoice",                "#CBD5E1",
			        "Draw - In Progress",             "#FB923C",
			        BLANK()
			    )
			)
		lineageTag: caf41df0-0c34-4e72-a1b9-5b34f236aea0
```

- [ ] **Step 4: Commit**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(service-time-sheets): de-alarm shared-RO Invoiced More color measures"
```

---

### Task 4: Open in Desktop and verify TMDL changes

**Files:** No file edits in this task — verification only.

- [ ] **Step 1: Open the PBIP file in Power BI Desktop**

Open `projects/service time sheets/reports/Service Time Sheets.pbip` in Power BI Desktop.

If Desktop reports a parse error, it will show which file and line number failed. Common causes:
- Extra `//` comment line in TMDL (not allowed at structural level)
- Mismatched indentation (tabs vs spaces) 
- Duplicate lineage tag

Fix the error in the TMDL file, save, and reopen.

- [ ] **Step 2: Verify `ROStatusDisplay` column appears in the model**

In Desktop, open the Data pane and expand `Fact_ServiceTimeSheet_Audit`. Confirm `ROStatusDisplay` appears in the column list.

- [ ] **Step 3: Connect pbi CLI and verify column values**

In a terminal (with `$env:Path += ";C:\Users\bfox\.local\bin"` if needed):

```powershell
pbi connect
```

This auto-detects the running Desktop instance. Then run:

```
pbi dax execute "EVALUATE SELECTCOLUMNS(FILTER(Fact_ServiceTimeSheet_Audit, NOT(ISBLANK(Fact_ServiceTimeSheet_Audit[ROStatusDisplay]))), ""RO"", Fact_ServiceTimeSheet_Audit[RONumberText], ""Tech"", Fact_ServiceTimeSheet_Audit[TechName], ""ROStatus"", Fact_ServiceTimeSheet_Audit[ROStatusDisplay]) ORDER BY [RO]"
```

Expected: rows appear for any shared ROs in the current data slice, showing `"Match"`, `"Mixed"`, or another status. RO 691944 should show `"Match"` for both James Acker and Branden Price rows.

- [ ] **Step 4: Verify `RO Status Display Color` measure appears**

```
pbi measure list
```

Confirm `RO Status Display Color` appears in the list alongside the other color measures.

- [ ] **Step 5: Spot-check `Row Status Color` for shared-RO row**

```
pbi dax execute "EVALUATE ROW(""Test"", CALCULATE([Row Status Color], Fact_ServiceTimeSheet_Audit[RONumberText] = ""691944"", Fact_ServiceTimeSheet_Audit[TechName] = ""James Acker""))"
```

Expected result: `#EFF6FF` (the blue value for shared-RO de-alarm). If the result is `#FEF3C7` (yellow), the `IF` condition in `Row Status Color` is not matching — recheck the `CONTAINSSTRING` syntax.

---

### Task 5: Add RO Status column to Page 2 (Time Sheet Audit) in Desktop

**Files:** Desktop saves will update the visual.json for the Page 2 table visual.

This task cannot be done in TMDL — table visual field configuration is stored in `visual.json` and must be set through the Desktop UI.

- [ ] **Step 1: Navigate to Page 2 (Time Sheet Audit)**

In Desktop, click the `Time Sheet Audit` page tab (Page 2).

- [ ] **Step 2: Select the main audit table visual**

Click on the large row-level table that shows all technician/RO rows (the one with columns like Location, PayPeriod, Tech Name, RO#, Claimed Hrs, Invoiced Hrs, etc.).

- [ ] **Step 3: Add `ROStatusDisplay` to the table**

In the **Fields** pane on the right, expand `Fact_ServiceTimeSheet_Audit`. Drag `ROStatusDisplay` into the **Columns** bucket in the **Visualizations** pane.

- [ ] **Step 4: Position the column immediately after Audit Status**

In the **Columns** bucket, drag `ROStatusDisplay` up/down until it appears directly after `AuditStatus` in the list.

- [ ] **Step 5: Rename the column header**

Double-click the `ROStatusDisplay` entry in the Columns bucket and rename it to `RO Status`.

- [ ] **Step 6: Apply font color conditional formatting**

With the table still selected:
1. In the Visualizations pane, click **Format your visual** (paint roller icon)
2. Expand **Cell elements**
3. Find the `RO Status` column entry → toggle on **Font color**
4. Click the **fx** button next to Font color
5. Set **Format style** to `Field value`
6. Set **What field should we base this on?** to `RO Status Display Color` (under _Measures)
7. Click OK

- [ ] **Step 7: Save the file**

`Ctrl+S` in Desktop. The `visual.json` for the Page 2 table will be updated on disk.

---

### Task 6: Add RO Status column to Page 3 (Tech Audit Detail) in Desktop

**Files:** Desktop saves will update the visual.json for the Page 3 table visual.

Same steps as Task 5 but on the Page 3 drill-through table.

- [ ] **Step 1: Navigate to Page 3 (Tech Audit Detail)**

Click the `Tech Audit Detail` page tab (Page 3).

- [ ] **Step 2: Select the RO detail table**

Click on the table that shows individual ROs for the drilled-through tech (columns include RO#, Invoice#, Invoice Date, Job Type, Customer, Model, % Complete, Draw 1/2/3, Final Draw, Claimed Hours, Invoiced Hours, Hours Difference, Tech Pay, Labor Billed, Paid Difference, Shared RO).

- [ ] **Step 3: Add `ROStatusDisplay` to the table**

In the Fields pane, expand `Fact_ServiceTimeSheet_Audit`. Drag `ROStatusDisplay` into the Columns bucket.

- [ ] **Step 4: Position after the Audit Status equivalent column**

This table may not have a standalone `Audit Status` column. Position `ROStatusDisplay` (renamed `RO Status`) after the `Paid Difference` column or wherever it makes most sense contextually — ideally near the `Shared RO` column.

- [ ] **Step 5: Rename and apply font color CF**

Rename to `RO Status`. Apply `RO Status Display Color` as font color conditional formatting using the same Field value approach as Task 5 Step 6.

- [ ] **Step 6: Save the file**

`Ctrl+S`.

---

### Task 7: Verify visually in Desktop and commit

- [ ] **Step 1: Go to Page 2 and filter to the pay period containing RO 691944**

Use the PayPeriod slicer to select `6/1/2026 - 6/14/2026`. Find the James Acker / RO 691944 row.

Verify:
- Row background is **blue** (`#EFF6FF`), not yellow
- Hours Difference (`-3.20`) is shown in **slate/grey**, not amber
- `RO Status` column shows **Match** in green next to that row
- Branden Price / RO 691944 row (if visible with same filter) also shows `RO Status = Match`
- Other single-tech "Invoiced More" rows still show **yellow** background

- [ ] **Step 2: Go to Page 3 and drill to James Acker**

Right-click James Acker on Page 2 → Drill through → Tech Audit Detail.

Verify the RO 691944 row shows the `RO Status` column with `Match` and is visually de-alarmed.

- [ ] **Step 3: Commit all Desktop-generated file changes**

```bash
git add "projects/service time sheets/reports/Service Time Sheets.Report/definition/pages/e384167396533ecc066e/visuals/"
git add "projects/service time sheets/reports/Service Time Sheets.Report/definition/pages/9bbbea6a53e6688e04ec/visuals/"
git commit -m "feat(service-time-sheets): add RO Status column to Pages 2 and 3 audit tables"
```

(Adjust the visual folder paths if the changed visuals are in different folders — check `git status` first to see which visual.json files were modified.)

- [ ] **Step 4: Push to origin/dev**

```bash
git push origin dev
```

Reminder: validate in RP-Dev before promoting to RP-Sandbox, then publish to RP - Service Reports for production.
