# Inspections Trend View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a rolling 24-month trend of Parts and Service (Labor) sales to the Inspections report's Details page, as a third bookmark-toggle state alongside the existing Jobcode/Branch matrix views, filterable by Branch and Inspection Category.

**Architecture:** Three new DAX measures generalize the existing invoice-number bridge pattern (currently hardcoded to CS690/770 job codes) so Parts $ correctly follows whatever Branch/Category filter is active. A third bookmark (`Matrix - Trend`) extends the existing two-bookmark toggle mechanism already on the Details page, hiding the two pivot tables and showing new trend visuals instead.

**Tech Stack:** Power BI semantic model (TMDL), Power BI Report (PBIR/JSON), DAX, `pbi-cli` (XMLA connection to Desktop) for measure validation, `pbir` CLI for post-edit structural validation.

**Reference spec:** `docs/superpowers/specs/2026-07-15-inspections-trend-view-design.md`

---

## Before You Start

- Open `Inspections.pbip` (in `projects/inspections - report/reports/current/`) in Power BI Desktop. Keep it open for the whole plan — several tasks connect to it live via `pbi-cli`, and later tasks build visuals directly in Desktop.
- Add `$env:Path += ";C:\Users\bfox\.local\bin"` if `pbi`/`pbir` aren't recognized in your PowerShell session.
- Confirm you're on the `dev` branch: `git branch --show-current` should print `dev`.

---

### Task 1: Add `Parts $ Total (Filtered)` measure

This is the core new measure — a generalized version of the existing CS690/770 invoice-number bridge (`_Measures.tmdl:66-78`) that inherits whatever `Fact_LaborJobSummary[InspectionCategory]` / Branch filter is active instead of a hardcoded job-code list. `Fact_WorkOrderParts` has no `JobCode`/`InspectionCategory` column of its own, so parts are only reachable through the invoice numbers shared with `Fact_LaborJobSummary`.

**Files:**
- Modify: `projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl` (insert after line 6700, before `column Value` at line 6702)

- [x] **Step 1: Confirm the measure doesn't exist yet (RED)**

With Desktop open and connected, run:

```bash
pbi connect
pbi dax execute "EVALUATE ROW(\"x\", [Parts \$ Total (Filtered)])"
```

Expected: an error naming `Parts $ Total (Filtered)` as an unknown measure/column. If it succeeds, stop — someone already added this measure; check git history before continuing.

- [x] **Step 2: Add the measure to `_Measures.tmdl`**

Insert immediately after the `'Total Inspections LY'` measure block (after line 6700), before the blank line and `column Value` (line 6702):

```
	measure 'Parts $ Total (Filtered)' =
			
			VAR ValidInv =
			    CALCULATETABLE(
			        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
			        Fact_LaborJobSummary[IsInspection] = TRUE,
			        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
			    )
			RETURN
			    CALCULATE(
			        SUM(Fact_WorkOrderParts[SaleValue]),
			        Fact_WorkOrderParts[InvoiceNumber] IN ValidInv,
			        Fact_WorkOrderParts[Franchise] <> "ZP",
			        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
			    )
		formatString: \$#,0.00;(\$#,0.00);\$#,0.00
		lineageTag: 79497b74-305f-4e1f-8e1f-2fe57d8ca52e

		annotation PBI_FormatHint = {"currencyCulture":"en-US"}

```

(Tabs, not spaces, matching the rest of the file. Leave the existing `column Value` block and everything after it untouched.)

- [x] **Step 3: Reload the model in Desktop**

Desktop should detect the external file change and prompt "This file has changed outside of Power BI Desktop — reload?" Click **Reload**. If no prompt appears within ~10 seconds, close and reopen `Inspections.pbip`.

- [x] **Step 4: Verify the new measure matches the existing unfiltered measure with no slicers applied (GREEN)**

```bash
pbi dax execute "EVALUATE ROW(\"Unfiltered\", [Parts \$ Total], \"Filtered\", [Parts \$ Total (Filtered)])"
```

Expected: both columns return the same dollar value (no category/branch filter is active in this query context, so the two measures should agree exactly).

- [x] **Step 5: Verify it changes correctly under a category filter, matching the existing CS690/770 measure as a spot-check**

```bash
pbi dax execute "EVALUATE CALCULATETABLE(ROW(\"Filtered\", [Parts \$ Total (Filtered)], \"CS690Existing\", [CS690-CS770 Parts Total]), Fact_LaborJobSummary[JobCode] IN {\"IS-CS690 INSPECT\", \"IS-CS770 INSPECT\", \"IS-STRIPPER INSPECT\", \"IS-CP690 INSPECT\", \"IS-CP770 INSPECT\"})"
```

Expected: `Filtered` and `CS690Existing` return the same value — confirms the generalized bridge produces identical results to the hardcoded one when given the same job-code set.

- [x] **Step 6: Commit**

```bash
git add "projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "Add Parts \$ Total (Filtered) measure for Inspections trend view

Generalizes the CS690/770 invoice-number bridge pattern to inherit
whatever InspectionCategory/Branch filter is active, since
Fact_WorkOrderParts has no JobCode column of its own."
```

---

### Task 2: Add `Avg Parts $ / Inspection (Rolling 24)` measure

Reuses the existing `Total Inspections` measure (`_Measures.tmdl:45-52`) as the denominator — it already filters only on `IsInspection = TRUE` with no hardcoded job codes, so it already respects whatever Branch/Category filter is active. No new "count" measure needed.

**Files:**
- Modify: `projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl` (insert after the measure added in Task 1)

- [x] **Step 1: Confirm the measure doesn't exist yet (RED)**

```bash
pbi dax execute "EVALUATE ROW(\"x\", [Avg Parts \$ / Inspection (Rolling 24)])"
```

Expected: error, unknown measure.

- [x] **Step 2: Add the measure**

Insert directly after the `'Parts $ Total (Filtered)'` block added in Task 1:

```
	measure 'Avg Parts $ / Inspection (Rolling 24)' =
			
			DIVIDE([Parts $ Total (Filtered)], [Total Inspections], 0)
		formatString: \$#,0.00;(\$#,0.00);\$#,0.00
		lineageTag: 94434eca-2607-4b3b-adde-f0e70d148cfc

		annotation PBI_FormatHint = {"currencyCulture":"en-US"}

```

- [x] **Step 3: Reload the model in Desktop**

Desktop should detect the external file change and prompt "This file has changed outside of Power BI Desktop — reload?" Click **Reload**. If no prompt appears within ~10 seconds, close and reopen `Inspections.pbip`.

- [x] **Step 4: Verify (GREEN)**

```bash
pbi dax execute "EVALUATE ROW(\"AvgParts\", [Avg Parts \$ / Inspection (Rolling 24)], \"PartsTotal\", [Parts \$ Total (Filtered)], \"Inspections\", [Total Inspections])"
```

Expected: `AvgParts` = `PartsTotal` / `Inspections` (manually verify the division holds with a calculator).

- [x] **Step 5: Commit**

```bash
git add "projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "Add Avg Parts \$ / Inspection measure for Inspections trend view"
```

---

### Task 3: Add `Avg Labor $ / Inspection (Rolling 24)` measure

Reuses the existing `Labor $$` measure (`_Measures.tmdl:80-86`) directly — it already filters `Fact_LaborJobSummary` on `IsInspection = TRUE` with no hardcoded job codes, so no new "filtered" labor measure is needed (unlike parts, labor doesn't need an invoice bridge — it's a direct column on the same table the JobCode/Category slicer will filter).

**Files:**
- Modify: `projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl` (insert after the measure added in Task 2)

- [x] **Step 1: Confirm the measure doesn't exist yet (RED)**

```bash
pbi dax execute "EVALUATE ROW(\"x\", [Avg Labor \$ / Inspection (Rolling 24)])"
```

Expected: error, unknown measure.

- [x] **Step 2: Add the measure**

Insert directly after the `'Avg Parts $ / Inspection (Rolling 24)'` block added in Task 2:

```
	measure 'Avg Labor $ / Inspection (Rolling 24)' =
			
			DIVIDE([Labor $$], [Total Inspections], 0)
		formatString: \$#,0.00;(\$#,0.00);\$#,0.00
		lineageTag: d733f574-d8c0-448a-ad63-37c8aebc3897

		annotation PBI_FormatHint = {"currencyCulture":"en-US"}

```

- [x] **Step 3: Reload the model in Desktop**

Desktop should detect the external file change and prompt "This file has changed outside of Power BI Desktop — reload?" Click **Reload**. If no prompt appears within ~10 seconds, close and reopen `Inspections.pbip`.

- [x] **Step 4: Verify (GREEN)**

```bash
pbi dax execute "EVALUATE ROW(\"AvgLabor\", [Avg Labor \$ / Inspection (Rolling 24)], \"LaborTotal\", [Labor \$\$], \"Inspections\", [Total Inspections])"
```

Expected: `AvgLabor` = `LaborTotal` / `Inspections`.

- [x] **Step 5: Commit**

```bash
git add "projects/inspections - report/reports/current/Inspections.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "Add Avg Labor \$ / Inspection measure for Inspections trend view"
```

---

### Task 4: Verify the rolling-24-month window and Category filter behave together

Before building visuals, confirm the `dim_DateTable[IsRolling24Months]` filter and an `InspectionCategory` filter compose correctly against the new measures — this is the exact combination the trend chart will use.

**Files:** none (validation only)

- [x] **Step 1: Run a combined query**

```bash
pbi dax execute "EVALUATE SUMMARIZECOLUMNS(dim_DateTable[MonthYear], dim_DateTable[SortableMonthYear], TREATAS({\"TRUE\"}, dim_DateTable[IsRolling24Months]), TREATAS({\"IS-COMBINE INSPECT\"}, Fact_LaborJobSummary[InspectionCategory]), \"Parts\", [Parts \$ Total (Filtered)], \"Labor\", [Labor \$\$]) ORDER BY dim_DateTable[SortableMonthYear]"
```

Expected: up to 24 rows, one per month, sorted chronologically, each with non-negative `Parts`/`Labor` values (some months may be blank/0 if that category had no activity that month — acceptable). If this returns zero rows entirely, stop and check whether `IS-COMBINE INSPECT` exists in the current data (`Fact_LaborJobSummary[JobCode]` — try a different real `InspectionCategory` value if so).

- [x] **Step 2: No commit** — this task is exploratory validation only, confirming the DAX composition works before wiring it into visuals.

---

### Task 5: Build the Trend visuals on the Details page (Desktop)

Build Option D from the spec: one combined dual-axis line chart (Parts $ left axis, Labor $ right axis) plus two KPI cards for average ticket size. This step is done directly in Power BI Desktop's UI — hand-authoring PBIR visual JSON for charts is error-prone and not how visuals are normally created in this repo (see `pbir-cli` skill notes on visuals being Desktop-authored, then read back).

**Files:**
- Modify (via Desktop save): `projects/inspections - report/reports/current/Inspections.Report/definition/pages/30a66c2b13c2a8e9f495/` (Details page — new `visuals/*/visual.json` files will appear)

- [x] **Step 1: Add the Inspection Category slicer**

On the Details page canvas, in an empty area near the existing Job Code/Branch slicers: Insert a **Slicer** visual, field = `Fact_LaborJobSummary[InspectionCategory]`. Match the visual style (colors, font) of the existing `dim_BranchLocation[Branch]` slicer on this page for consistency.

- [x] **Step 2: Add the combined trend line chart**

Insert a **Line Chart** (or **Line and Clustered Column Chart** if you want dual-axis lines — Power BI's basic Line Chart supports two Y-axes when there are two value fields with different measures, but confirm dual-axis rendering once fields are added):
- X-axis: `dim_DateTable[MonthYear]`, sort by `dim_DateTable[SortableMonthYear]` (Visualizations pane → ⋯ on the field → Sort by column)
- Line values: `[Parts $ Total (Filtered)]` and `[Labor $$]`
- Add a **Visual-level filter**: `dim_DateTable[IsRolling24Months]` = `True`
- If both lines render on one axis and Labor is dwarfed by Parts (or vice versa), move `Labor $$` to a secondary axis: Format pane → Y-axis → check for a "secondary axis" toggle, or switch the visual type to "Line and Clustered Column Chart" and assign Labor to the column/secondary-axis role.
- Colors: Parts line `#818cf8` (purple, matches the "Unique" badge convention in `CLAUDE.md`), Labor line `#fbbf24` (gold, matches "Key Customer" badge convention).

- [x] **Step 3: Add the two average-ticket KPI cards**

Insert two **Card** visuals below the chart:
- Card 1: `[Avg Parts $ / Inspection (Rolling 24)]`, with a Visual-level filter `dim_DateTable[IsRolling24Months]` = `True`. Label it "Avg Parts $ / Inspection".
- Card 2: `[Avg Labor $ / Inspection (Rolling 24)]`, same filter. Label it "Avg Labor $ / Inspection".
- Match the card styling already used elsewhere on the Details page (e.g. the existing "Total" card `597fbf99e82effc9a1f2`) for visual consistency.

- [x] **Step 4: Add the "Button - Trend" action button**

Insert an **Action Button** (blank type, no action needed yet — bookmarks will drive it), positioned next to the existing "Button - Jobcode" (`229ae583b0d3c00de190`) and "Button - Branch" (`86c962ed5b7147d37b57`) buttons. Label it "Trend", matching their font/size/color.

- [x] **Step 5: Save in Desktop**

File → Save (or Ctrl+S). This writes new `visuals/<id>/visual.json` files under the Details page folder.

- [x] **Step 6: Confirm the new visuals via `pbir tree`**

```bash
pbir tree "projects/inspections - report/reports/current/Inspections.Report"
```

Expected: the Details page's visual count increases by 5 (slicer, chart, 2 cards, button), and you can identify their new visual IDs in the output (needed for Task 6).

- [x] **Step 7: Commit**

```bash
git add "projects/inspections - report/reports/current/Inspections.Report/definition/pages/30a66c2b13c2a8e9f495/"
git commit -m "Add Inspections Details page trend visuals (Category slicer, combined chart, avg-ticket cards, Trend button)"
```

---

### Task 6: Wire up the three-way bookmark toggle (Desktop)

Extend the existing `Matrix - Jobcode` / `Matrix - Branch` bookmark toggle with a third `Matrix - Trend` state, and make all three bookmarks aware of all three states' visuals (currently the two existing bookmarks only reference each other — each must also hide the new Trend visuals/button, and the new Trend bookmark must hide both pivot tables and the other two buttons).

**Files:**
- Modify (via Desktop save): `projects/inspections - report/reports/current/Inspections.Report/definition/bookmarks/bookmarks.json`
- Modify (via Desktop save): `projects/inspections - report/reports/current/Inspections.Report/definition/bookmarks/7be3855dee35a77b98c8.bookmark.json` (`Matrix - Jobcode`)
- Modify (via Desktop save): `projects/inspections - report/reports/current/Inspections.Report/definition/bookmarks/9dba35dba10d0450704e.bookmark.json` (`Matrix - Branch`)
- Create (via Desktop save): new `<id>.bookmark.json` for `Matrix - Trend`

- [x] **Step 1: Set the canvas to the "Trend" state manually**

In Desktop, on the Details page: hide the two pivot tables (right-click each → Hide/Format pane → toggle visibility off, or use the Selection pane) and hide "Button - Jobcode"/"Button - Branch". Show the 5 new visuals from Task 5 and the "Button - Trend" button.

- [x] **Step 2: Create the new bookmark**

Open the **Bookmarks** pane (View → Bookmarks). Click **Add**. Rename the new bookmark to `Matrix - Trend` (double-click its name in the pane, matching the naming convention of `Matrix - Jobcode` / `Matrix - Branch`).

- [x] **Step 3: Restore the Jobcode state and update that bookmark**

Switch visibility back: show the Jobcode pivot table + "Button - Jobcode", hide the Branch pivot table + "Button - Branch", and now also hide all 5 new Trend visuals + "Button - Trend". Right-click the existing `Matrix - Jobcode` bookmark in the pane → **Update** (this captures the new hide-state for the Trend visuals without disturbing what it already does for the Jobcode/Branch visuals).

- [x] **Step 4: Restore the Branch state and update that bookmark**

Switch visibility: show the Branch pivot table + "Button - Branch", hide the Jobcode pivot table + "Button - Jobcode", and hide all 5 new Trend visuals + "Button - Trend". Right-click `Matrix - Branch` → **Update**.

- [x] **Step 5: Save in Desktop**

File → Save.

- [x] **Step 6: Round-trip test — click through all three bookmarks in Desktop**

In the Bookmarks pane, click `Matrix - Jobcode`, then `Matrix - Branch`, then `Matrix - Trend`, then back to `Matrix - Jobcode`. Confirm at each click that exactly one of {Jobcode pivot, Branch pivot, Trend visuals} is visible, and exactly one button is visible, matching that state. This is the critical manual check — a bookmark that doesn't hide something from an earlier state leaves stale visuals stuck on screen.

- [x] **Step 7: Verify with `pbir` and `git status` (per project convention — bookmark edits have previously caused unrelated-visual side effects)**

```bash
pbir validate "projects/inspections - report/reports/current/Inspections.Report" --all
git status --short "projects/inspections - report/reports/current/Inspections.Report/definition/bookmarks/"
```

Expected: `pbir validate` reports no broken references. `git status` shows exactly: the new bookmark file, `bookmarks.json` (new entry appended), and the two modified `Matrix - Jobcode`/`Matrix - Branch` bookmark files — no other bookmark files should appear as modified. If other bookmarks (`Show Nav - *`, `Hide Nav - *`, etc.) show as changed, investigate before committing — that would indicate an unintended side effect.

- [x] **Step 8: Commit**

```bash
git add "projects/inspections - report/reports/current/Inspections.Report/definition/bookmarks/"
git commit -m "Add Matrix - Trend bookmark; extend Jobcode/Branch bookmarks to hide new trend visuals"
```

---

### Task 7: Update documentation

**Files:**
- Modify: `projects/inspections - report/documentation/dax/dax-measures-library.md`
- Modify: `projects/inspections - report/documentation/report-pages.md`

- [x] **Step 1: Add the 3 new measures to the DAX library doc**

In `dax-measures-library.md`, add a new section (following the existing per-category format used throughout the file, e.g. matching the "Core Metrics" section style) documenting:
- `Parts $ Total (Filtered)` — DAX from Task 1, with a one-line note: "Generalized invoice-number bridge; respects InspectionCategory/Branch filter context instead of a hardcoded job-code list."
- `Avg Parts $ / Inspection (Rolling 24)` — DAX from Task 2
- `Avg Labor $ / Inspection (Rolling 24)` — DAX from Task 3

Update the measure count at the top of the file (currently "Total Measures: 172") to 175, and add a row to the category summary table for these 3 (e.g. under a new "Trend" category row).

- [x] **Step 2: Update the Details page section of `report-pages.md`**

In the "📄 Page 2: Details Page" section, add a subsection describing the third toggle state:

```markdown
#### 4. Trend View (3rd toggle state)
- Toggled via "Button - Trend" alongside the existing Jobcode/Branch toggle buttons
- Combined line chart: rolling 24-month Parts $ Total (Filtered) and Labor $$ trend, filterable by Inspection Category and Branch
- Two KPI cards: Avg Parts $ / Inspection and Avg Labor $ / Inspection (rolling 24-month average)
- Bookmark: `Matrix - Trend`
```

- [x] **Step 3: Commit**

```bash
git add "projects/inspections - report/documentation/dax/dax-measures-library.md" "projects/inspections - report/documentation/report-pages.md"
git commit -m "Document Inspections trend view measures and Details page toggle"
```

---

### Task 8: Full validation pass

Run through the spec's validation checklist end-to-end before calling this done.

**Files:** none (validation only)

- [x] **Step 1: Re-run the measure sanity checks from Tasks 1-3** with an actual `InspectionCategory` value from live data (pick one you confirmed exists in Task 4) and a Branch filter, confirming both filters compose correctly:

```bash
pbi dax execute "EVALUATE CALCULATETABLE(ROW(\"Parts\", [Parts \$ Total (Filtered)], \"Labor\", [Labor \$\$], \"AvgParts\", [Avg Parts \$ / Inspection (Rolling 24)], \"AvgLabor\", [Avg Labor \$ / Inspection (Rolling 24)]), Fact_LaborJobSummary[InspectionCategory] = \"IS-COMBINE INSPECT\", dim_BranchLocation[Branch] = \"1 - Seminole\")"
```

Expected: all 4 values return without error (0 is fine if that branch/category combination has no rolling-24-month activity — just confirm no error).

- [x] **Step 2: In Desktop, walk the manual checklist:**
  - [ ] Trend chart shows all available rolling-24 months, sorted chronologically (not alphabetically)
  - [ ] Changing the Inspection Category slicer updates the chart and both KPI cards
  - [ ] Changing the Branch slicer updates the chart and both KPI cards
  - [ ] Clicking `Button - Trend` → `Button - Jobcode` → `Button - Branch` → `Button - Trend` round-trips cleanly with no stuck visuals
  - [ ] Other Details page elements (header, discount panel, drill-through buttons to Work Order List/Details) still work unaffected
  - [ ] Compare the combined dual-axis chart (Option D, just built) against how it would look as two separate stacked charts (Option C) — decide with Brian/Casey whether to keep D or rebuild as C now that real data is on screen

- [x] **Step 3: No commit for this task** (validation only — if Step 2's last bullet leads to a layout change, that becomes a follow-up task, not a retroactive edit to already-committed work)

---

## Post-Plan Reminder

Per this repo's standard workflow (`CLAUDE.md`): after this is validated in Desktop, publish to RP-Dev, then remind Brian to validate in RP-Sandbox before promoting to the production Service Reports workspace (or skip Sandbox if this ends up being treated as a minor addition — confirm with Brian at that point).
