# Open Parts Tickets — Trend Page (Snapshot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build trend content (4 KPI cards + 4 trend charts) on the already-scaffolded "Trends" page of the Open Parts Tickets report, driven by the monthly `fact_parts_open_orders_snapshot` table, and fix the page's pre-built slicer panel so it actually filters that content.

**Architecture:** 5 new DAX measures added directly to `_Measures.tmdl` (4 simple snapshot aggregates + 1 combined KPI-row HTML measure computing latest-vs-prior-month deltas internally). One TMDL edit to add `sortByColumn` to the snapshot table's `Aging` column. All report-layer changes (slicer rebind/removal, new visuals) are done in Power BI Desktop, since hand-authoring chart `visual.json` is unreliable — Desktop's save process writes correct JSON.

**Tech Stack:** TMDL (direct file edit), DAX, Power BI Desktop (PBIP format), `pbi` CLI for post-open verification.

**Design spec:** `docs/superpowers/specs/2026-07-08-open-parts-tickets-trend-page-design.md`

**Correction vs. the design spec:** the spec listed 8 new measures (4 base + 4 separate "prior month" measures) for the KPI cards. In practice, this codebase's established convention (see `HTML - Aging Card Row`, `HTML - Backorder Pulse` in the same file) is one self-contained HTML measure per multi-item card row, computing everything via internal `VAR`s rather than exposing intermediate "prior month" measures nobody else uses. This plan builds 4 base measures (needed standalone for the trend charts) + 1 combined `HTML - Trend KPI Row` measure (computes latest/prior internally) — 5 measures total, not 8. Nothing in the spec's intended behavior changes.

---

## File Map

| File | Change |
|---|---|
| `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/fact_parts_open_orders_snapshot.tmdl` | Add `sortByColumn: Aging_Sort_Order` to the `Aging` column |
| `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl` | Add `Snapshot Order Count`, `Snapshot Order Total $`, `Snapshot Backorder $`, `Snapshot Backorder Count`, `HTML - Trend KPI Row` |
| Desktop: Trends page (`ac8bedf2271b0d172508`) | Rebind Aging slicer to snapshot table; remove Invoice_Type/Customer/Contact Code slicers; reposition Aging slicer; add 1 KPI row visual + 4 chart visuals |

---

### Task 1: Add `sortByColumn` to the snapshot table's `Aging` column

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/fact_parts_open_orders_snapshot.tmdl`

Without this, the Aging slicer (rebound in Task 5) would sort alphabetically ("0-7 days", "15-30 days", "31-60 days"...) instead of by aging severity. The live `Fact_Parts_Open_Tickets[Aging]` column already uses this exact pattern (`sortByColumn: Aging_Sort_Order` + `changedProperty = SortByColumn`).

- [ ] **Step 1: Locate the `Aging` column block**

In `fact_parts_open_orders_snapshot.tmdl`, find:

```
	column Aging
		dataType: string
		lineageTag: 72b3e47e-3f60-4f60-a219-ea613b24938b
		summarizeBy: none
		sourceColumn: Aging

		annotation SummarizationSetBy = Automatic
```

- [ ] **Step 2: Add the sort-by-column property**

Replace that block with:

```
	column Aging
		dataType: string
		lineageTag: 72b3e47e-3f60-4f60-a219-ea613b24938b
		summarizeBy: none
		sourceColumn: Aging
		sortByColumn: Aging_Sort_Order

		changedProperty = SortByColumn

		annotation SummarizationSetBy = Automatic
```

- [ ] **Step 3: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/fact_parts_open_orders_snapshot.tmdl"
git commit -m "feat(open-parts-tickets): sort snapshot Aging column by Aging_Sort_Order"
```

---

### Task 2: Add the 4 base snapshot measures to `_Measures.tmdl`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

These are simple aggregates against `fact_parts_open_orders_snapshot`, needed both by the 4 trend charts (Task 8–11) and internally by `HTML - Trend KPI Row` (Task 3). Format strings follow the same conventions already used for `'# Parts On Order'` (`formatString: 0`) and `'Order Total'` (`formatString: \$#,0.00;(\$#,0.00);\$#,0.00`) earlier in this file.

- [ ] **Step 1: Confirm lineage tags are unused**

Search `_Measures.tmdl` for each of `cccccccccc01`, `cccccccccc02`, `cccccccccc03`, `cccccccccc04`. Expected: no matches for any.

- [ ] **Step 2: Find the insertion point**

Locate the end of the `'Page 6 - Trends - Header'` measure block — it ends with:

```
		displayFolder: UI & Navigation
		lineageTag: 5c6a098c-cc3a-4827-9e66-295a603bee9e
```

followed by a blank line, then `	column Value`. Insert the new measures in that blank gap, before `column Value`.

- [ ] **Step 3: Insert the 4 measures**

```
	measure 'Snapshot Order Count' = DISTINCTCOUNT(fact_parts_open_orders_snapshot[Order_No])
		formatString: 0
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc01

	measure 'Snapshot Order Total $' = SUM(fact_parts_open_orders_snapshot[Order_Total_$$])
		formatString: \$#,0.00;(\$#,0.00);\$#,0.00
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc02

	measure 'Snapshot Backorder $' = SUM(fact_parts_open_orders_snapshot[$$_BackOrdered])
		formatString: \$#,0.00;(\$#,0.00);\$#,0.00
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc03

	measure 'Snapshot Backorder Count' = SUM(fact_parts_open_orders_snapshot[#_On_Back_Order])
		formatString: 0
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc04

```

Indentation: 1 tab for `measure`, 2 tabs for `formatString`/`displayFolder`/`lineageTag`, matching the surrounding single-line measures in this file. Blank line after each measure's `lineageTag` line.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add 4 base snapshot trend measures"
```

---

### Task 3: Add `HTML - Trend KPI Row` measure to `_Measures.tmdl`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

One HTML measure rendering all 4 KPI cards (# Invoices, Order Total $, Backorder $, # Back Orders), each showing the latest snapshot month's value and a delta vs. the prior snapshot month with a literal month name (e.g. "vs May 2026", not "vs Prior Period" — matching the convention established on the Pin Capture report). "Latest" and "prior" are always the two most recent snapshot months in the whole table (`ALL(fact_parts_open_orders_snapshot)`), regardless of what the Aging/Branch slicers have filtered, so the comparison basis doesn't silently change when a user filters to one bucket — but the *values themselves* still respect those slicers (only the `SnapshotDate` filter is overridden by `CALCULATE`, not Aging/Branch). Backorder $ and Backorder Count deltas are colored red (increase) / green (decrease); Invoices and Order Total $ deltas are neutral dark blue, since a growing backlog isn't inherently good or bad in isolation.

- [ ] **Step 1: Confirm lineage tag is unused**

Search `_Measures.tmdl` for `cccccccccc05`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Insert immediately after the `'Snapshot Backorder Count'` block added in Task 2 (after its `lineageTag` line and the following blank line), before `column Value`.

- [ ] **Step 3: Insert the measure**

```
	measure 'HTML - Trend KPI Row' = ```
			
			VAR LatestSnapshot =
			    CALCULATE(
			        MAX(fact_parts_open_orders_snapshot[SnapshotDate]),
			        ALL(fact_parts_open_orders_snapshot)
			    )
			VAR PriorSnapshot =
			    CALCULATE(
			        MAX(fact_parts_open_orders_snapshot[SnapshotDate]),
			        ALL(fact_parts_open_orders_snapshot),
			        fact_parts_open_orders_snapshot[SnapshotDate] < LatestSnapshot
			    )
			VAR HasPrior = NOT ISBLANK(PriorSnapshot)
			VAR PriorLabel = IF(HasPrior, "vs " & FORMAT(PriorSnapshot, "MMMM YYYY"), "no prior month")
			
			VAR InvoicesNow = CALCULATE([Snapshot Order Count], fact_parts_open_orders_snapshot[SnapshotDate] = LatestSnapshot)
			VAR InvoicesPrior = CALCULATE([Snapshot Order Count], fact_parts_open_orders_snapshot[SnapshotDate] = PriorSnapshot)
			VAR InvoicesChange = DIVIDE(InvoicesNow - InvoicesPrior, InvoicesPrior)
			
			VAR DollarsNow = CALCULATE([Snapshot Order Total $], fact_parts_open_orders_snapshot[SnapshotDate] = LatestSnapshot)
			VAR DollarsPrior = CALCULATE([Snapshot Order Total $], fact_parts_open_orders_snapshot[SnapshotDate] = PriorSnapshot)
			VAR DollarsChange = DIVIDE(DollarsNow - DollarsPrior, DollarsPrior)
			
			VAR BODollarsNow = CALCULATE([Snapshot Backorder $], fact_parts_open_orders_snapshot[SnapshotDate] = LatestSnapshot)
			VAR BODollarsPrior = CALCULATE([Snapshot Backorder $], fact_parts_open_orders_snapshot[SnapshotDate] = PriorSnapshot)
			VAR BODollarsChange = DIVIDE(BODollarsNow - BODollarsPrior, BODollarsPrior)
			
			VAR BOCountNow = CALCULATE([Snapshot Backorder Count], fact_parts_open_orders_snapshot[SnapshotDate] = LatestSnapshot)
			VAR BOCountPrior = CALCULATE([Snapshot Backorder Count], fact_parts_open_orders_snapshot[SnapshotDate] = PriorSnapshot)
			VAR BOCountChange = DIVIDE(BOCountNow - BOCountPrior, BOCountPrior)
			
			VAR NeutralClr = "#1D3C4E"
			VAR GoodClr = "#5CB85C"
			VAR BadClr = "#FF6B6B"
			
			VAR Arrow1 = IF(InvoicesChange > 0, "▲", IF(InvoicesChange < 0, "▼", "→"))
			VAR Arrow2 = IF(DollarsChange > 0, "▲", IF(DollarsChange < 0, "▼", "→"))
			VAR Arrow3 = IF(BODollarsChange > 0, "▲", IF(BODollarsChange < 0, "▼", "→"))
			VAR Arrow4 = IF(BOCountChange > 0, "▲", IF(BOCountChange < 0, "▼", "→"))
			
			VAR Clr3 = IF(BODollarsChange > 0, BadClr, IF(BODollarsChange < 0, GoodClr, NeutralClr))
			VAR Clr4 = IF(BOCountChange > 0, BadClr, IF(BOCountChange < 0, GoodClr, NeutralClr))
			
			VAR CardCSS = "background: white; border-radius: 8px; padding: 16px; text-align: center; flex: 1; box-shadow: 0 2px 4px rgba(0,0,0,0.1); box-sizing: border-box;"
			VAR LabelCSS = "font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px;"
			VAR ValueCSS = "font-size: 28px; font-weight: 700; color: #1D3C4E; margin: 6px 0;"
			
			VAR Delta1 = IF(HasPrior, Arrow1 & " " & FORMAT(ABS(InvoicesChange), "0.0%") & " " & PriorLabel, PriorLabel)
			VAR Delta2 = IF(HasPrior, Arrow2 & " " & FORMAT(ABS(DollarsChange), "0.0%") & " " & PriorLabel, PriorLabel)
			VAR Delta3 = IF(HasPrior, Arrow3 & " " & FORMAT(ABS(BODollarsChange), "0.0%") & " " & PriorLabel, PriorLabel)
			VAR Delta4 = IF(HasPrior, Arrow4 & " " & FORMAT(ABS(BOCountChange), "0.0%") & " " & PriorLabel, PriorLabel)
			
			VAR Card1 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'># Invoices</div><div style='" & ValueCSS & "'>" & FORMAT(InvoicesNow, "#,##0") & "</div><div style='font-size: 13px; color: " & NeutralClr & ";'>" & Delta1 & "</div></div>"
			VAR Card2 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'>Order Total $</div><div style='" & ValueCSS & "'>" & FORMAT(DollarsNow, "$#,##0") & "</div><div style='font-size: 13px; color: " & NeutralClr & ";'>" & Delta2 & "</div></div>"
			VAR Card3 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'>Backorder $</div><div style='" & ValueCSS & "'>" & FORMAT(BODollarsNow, "$#,##0") & "</div><div style='font-size: 13px; color: " & Clr3 & ";'>" & Delta3 & "</div></div>"
			VAR Card4 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'># Back Orders</div><div style='" & ValueCSS & "'>" & FORMAT(BOCountNow, "#,##0") & "</div><div style='font-size: 13px; color: " & Clr4 & ";'>" & Delta4 & "</div></div>"
			
			RETURN
			"<div style='font-family: Segoe UI, Arial, sans-serif; display: flex; gap: 10px; height: 100%; box-sizing: border-box;'>" & Card1 & Card2 & Card3 & Card4 & "</div>"
			```
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc05

```

Indentation: 3 tabs for the backtick-fenced DAX body (matching `HTML - Aging Card Row` and `HTML - Backorder Pulse` elsewhere in this file), 2 tabs for `displayFolder`/`lineageTag`. Blank line after `lineageTag` before `column Value`.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Trend KPI Row measure"
```

---

### Task 4: Open in Desktop and verify the 5 new measures

**Files:** No file edits — verification only.

- [ ] **Step 1: Open the PBIP file**

Open `projects/open parts tickets - report/reports/current/Open Parts Tickets.pbip` in Power BI Desktop.

If Desktop reports a parse error, it names the file and line. Common causes: a stray `//` at the TMDL structural level, mismatched tab indentation, or a duplicate lineage tag. Fix in the TMDL file, save, reopen.

- [ ] **Step 2: Connect the `pbi` CLI**

```powershell
$env:Path += ";C:\Users\bfox\.local\bin"
pbi connect
```

- [ ] **Step 3: Verify all 5 measures exist**

```
pbi measure list
```

Expected: `Snapshot Order Count`, `Snapshot Order Total $`, `Snapshot Backorder $`, `Snapshot Backorder Count`, `HTML - Trend KPI Row` all appear under `_Measures` / Snapshot Trend.

- [ ] **Step 4: Spot-check the 4 base measures return non-blank numbers**

```
pbi dax execute "EVALUATE ROW(""Invoices"", [Snapshot Order Count], ""OrderTotal"", [Snapshot Order Total $], ""BODollars"", [Snapshot Backorder $], ""BOCount"", [Snapshot Backorder Count])"
```

Expected: 4 non-blank numeric values (these are unfiltered grand totals across all snapshot months — sanity-check they're not zero or blank, not that they match any specific figure).

- [ ] **Step 5: Spot-check `HTML - Trend KPI Row` evaluates without error**

```
pbi dax execute "EVALUATE ROW(""KPI"", LEFT([HTML - Trend KPI Row], 100))"
```

Expected: a string starting with `<div style='font-family: Segoe UI, Arial, sans-serif; display: flex...`. If this errors, check that `[Snapshot Order Count]`, `[Snapshot Order Total $]`, `[Snapshot Backorder $]`, `[Snapshot Backorder Count]` exist exactly as named (case-sensitive).

- [ ] **Step 6: Confirm the "vs {month}" label renders correctly**

```
pbi dax execute "EVALUATE ROW(""KPI"", MID([HTML - Trend KPI Row], 1, 2000))"
```

Search the returned string for `vs `. Expected: `vs ` followed by a month name and 4-digit year (e.g. `vs May 2026`) — confirms `PriorSnapshot`/`FORMAT` resolved correctly, not `"no prior month"` (which would indicate only 1 snapshot month exists — unexpected given ~5 months of history).

---

### Task 5: Rebind the Aging slicer to the snapshot table

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/visuals/37863f7901b2021370d5/visual.json`

- [ ] **Step 1: Navigate to the Trends page and reveal the hidden panel**

In Desktop's Report view (not published/reading view — hidden pages are still editable in Desktop), click the "Trends" page tab. Open the Bookmarks pane (View ribbon → Bookmarks). Click the bookmark named **"Show Nav Panel 6"** to reveal the 5-slicer panel on canvas.

- [ ] **Step 2: Select the Aging slicer**

Click the slicer currently showing Aging tier values (0-7 days, 8-14 days, etc.) — third from the top in the panel.

- [ ] **Step 3: Remove the old field and add the new one**

In the Fields pane (or the visual's field well), remove `Fact_Parts_Open_Tickets[Aging]`. Drag `fact_parts_open_orders_snapshot[Aging]` into the same field well.

- [ ] **Step 4: Confirm the sort order**

Click the "More options" (`...`) on the slicer → **Sort by** → confirm `Aging_Sort_Order` is selected (this should already be the default now, since Task 1 set `sortByColumn` at the model level). If it shows alphabetical sort instead, explicitly pick `Aging_Sort_Order`.

- [ ] **Step 5: Save**

`Ctrl+S`.

- [ ] **Step 6: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "fix(open-parts-tickets): rebind Trends page Aging slicer to snapshot table"
```

---

### Task 6: Remove the 3 out-of-scope slicers and reposition Aging

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

The panel currently stacks 5 slicers top-to-bottom: Branch (y≈409), Invoice_Type (y≈489), Aging (y≈569), Customer (y≈659), Contact Code (y≈748). After removing Invoice_Type/Customer/Contact Code, only Branch and Aging remain — reposition Aging up to close the gap left by Invoice_Type.

- [ ] **Step 1: Delete the Invoice_Type slicer**

On the Trends page (panel still visible from Task 5), click the slicer bound to `Fact_Parts_Open_Tickets[Invoice_Type]` (second from top, showing "Type" values). Press Delete.

- [ ] **Step 2: Delete the Customer slicer**

Click the slicer bound to `Fact_Parts_Open_Tickets[Customer]` (now second-to-last). Press Delete.

- [ ] **Step 3: Delete the Contact Code slicer**

Click the slicer bound to `Fact_Parts_Open_Tickets[Contact Code]` (last one, bottom of the panel). Press Delete.

- [ ] **Step 4: Reposition the Aging slicer**

Select the Aging slicer (rebound in Task 5). Open Format pane → General → Properties → Size and position. Set `y` to `488.82` (closing the gap left by the deleted Invoice_Type slicer; `x` stays at its current value, `7.63`).

- [ ] **Step 5: Save**

`Ctrl+S`.

- [ ] **Step 6: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "chore(open-parts-tickets): remove out-of-scope slicers from Trends panel, reposition Aging"
```

---

### Task 7: Add the KPI Row visual

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Hide the panel again**

Click the "Hide Nav Panel 6" bookmark (Bookmarks pane) so the canvas is clear for laying out the new content below the header.

- [ ] **Step 2: Add the HTML Content visual**

From the Visualizations pane, drag the "HTML Content" custom visual (already registered in this report — `</>` icon) onto the canvas. Bind it to `HTML - Trend KPI Row`.

- [ ] **Step 3: Position it**

Format pane → General → Properties → Size and position: `x=200, y=110, width=1452, height=110`.

- [ ] **Step 4: Save**

`Ctrl+S`.

- [ ] **Step 5: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Trend KPI row visual to Trends page"
```

---

### Task 8: Add the Order Count Trend chart

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add a Line Chart visual**

Drag a "Line chart" visual onto the canvas.

- [ ] **Step 2: Bind fields**

X-axis: `dim_DateTable[MonthYear]`. Y-axis: `[Snapshot Order Count]`.

- [ ] **Step 3: Set X-axis sort**

Click the visual's "More options" (`...`) → **Sort axis** → **Sort by** `SortableMonthYear`, ascending. (Without this, `MonthYear` sorts alphabetically — "Apr 2026" before "Mar 2026" — instead of chronologically.)

- [ ] **Step 4: Title and position**

Format pane → General → Title: "Order Count Trend". Format pane → General → Properties → Size and position: `x=200, y=235, width=716, height=320`.

- [ ] **Step 5: Line color**

Format pane → Line → set the `Snapshot Order Count` series color to `#3A7CA5` (matches the report's primary blue, used for `Order Total` on the existing Charts page).

- [ ] **Step 6: Save**

`Ctrl+S`.

- [ ] **Step 7: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Order Count Trend chart to Trends page"
```

---

### Task 9: Add the Dollars Trend chart

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add a Line Chart visual**

Drag a "Line chart" visual onto the canvas.

- [ ] **Step 2: Bind fields**

X-axis: `dim_DateTable[MonthYear]`. Y-axis: both `[Snapshot Order Total $]` and `[Snapshot Backorder $]` (drag both into the same Y-axis well — same unit, no secondary axis needed).

- [ ] **Step 3: Set X-axis sort**

Same as Task 8 Step 3: sort by `SortableMonthYear`, ascending.

- [ ] **Step 4: Title and position**

Title: "Dollars Trend". Size and position: `x=931, y=235, width=716, height=320`.

- [ ] **Step 5: Line colors**

Format pane → Line → set `Snapshot Order Total $` to `#3A7CA5` (blue) and `Snapshot Backorder $` to `#FF6B6B` (red) — matches the report's existing Order Total / backorder color convention.

- [ ] **Step 6: Save**

`Ctrl+S`.

- [ ] **Step 7: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Dollars Trend chart to Trends page"
```

---

### Task 10: Add the Backorder Count Trend chart

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add a Line Chart visual**

Drag a "Line chart" visual onto the canvas.

- [ ] **Step 2: Bind fields**

X-axis: `dim_DateTable[MonthYear]`. Y-axis: `[Snapshot Backorder Count]`.

- [ ] **Step 3: Set X-axis sort**

Same as Task 8 Step 3: sort by `SortableMonthYear`, ascending.

- [ ] **Step 4: Title and position**

Title: "Backorder Count Trend". Size and position: `x=200, y=570, width=716, height=320`.

- [ ] **Step 5: Line color**

Format pane → Line → set the series color to `#FF6B6B` (red, matches the backorder-is-bad convention used elsewhere in this report).

- [ ] **Step 6: Save**

`Ctrl+S`.

- [ ] **Step 7: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Backorder Count Trend chart to Trends page"
```

---

### Task 11: Add the Aging Mix Over Time chart

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add a 100% Stacked Column Chart visual**

Drag a "100% Stacked column chart" visual onto the canvas.

- [ ] **Step 2: Bind fields**

X-axis: `dim_DateTable[MonthYear]`. Y-axis: `[Snapshot Order Count]`. Legend: `fact_parts_open_orders_snapshot[Aging]`.

- [ ] **Step 3: Set X-axis sort**

Same as Task 8 Step 3: sort by `SortableMonthYear`, ascending.

- [ ] **Step 4: Set legend sort**

The legend should already order by `Aging_Sort_Order` since Task 1 set that as the column's model-level sort. If it doesn't, click the visual's "More options" (`...`) and look for a legend sort option, or confirm via Task 5 Step 4's method on this table's `Aging` column.

- [ ] **Step 5: Title and position**

Title: "Aging Mix Over Time". Size and position: `x=931, y=570, width=716, height=320`.

- [ ] **Step 6: Apply the real aging color palette**

Format pane → Columns → Colors → for each of the 6 series, set the color individually (not the stale `REPORT-PAGES-GUIDE.md` gradient — use the palette from `_HTML_Bucket1`–`6` / the design spec):

| Aging value | Color |
|---|---|
| 90+ days | `#cf1322` |
| 61-90 days | `#f5222d` |
| 31-60 days | `#fa8c16` |
| 15-30 days | `#faad14` |
| 8-14 days | `#52c41a` |
| 0-7 days | `#27ae60` |

- [ ] **Step 7: Save**

`Ctrl+S`.

- [ ] **Step 8: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Aging Mix Over Time chart to Trends page"
```

---

### Task 12: Visual and interaction QA

**Files:** No file edits — verification only. Re-run the relevant earlier task's Desktop steps if any check below fails, then re-save and re-commit.

- [ ] **Step 1: Default state (no slicers applied)**

With the panel hidden and no filters selected, confirm all 4 KPI cards show non-blank numbers and a `vs {Month} {Year}` delta line (not "no prior month"), and all 4 charts render with visible data points across the available snapshot months.

- [ ] **Step 2: Aging slicer filters correctly**

Show the panel (Bookmarks → "Show Nav Panel 6"). Select a single Aging bucket (e.g. "90+ days"). Confirm all 4 KPI cards and all 4 charts update to reflect only that bucket. Clear the selection and confirm everything returns to the all-buckets view.

- [ ] **Step 3: Branch slicer filters correctly**

Select a single branch. Confirm the same 8 visuals (4 KPI + 4 charts) update accordingly. Clear the selection.

- [ ] **Step 4: KPI comparison basis stays fixed under filtering**

With the Aging slicer set to a single bucket, confirm the `vs {Month}` text in each KPI card still names the same two most recent snapshot months as it did in Step 1 (unfiltered) — i.e., filtering to a bucket changes the *numbers*, not *which months* are being compared.

- [ ] **Step 5: X-axis chronological order**

On all 4 charts, confirm months run left-to-right in calendar order (oldest to newest), not alphabetically.

- [ ] **Step 6: Other pages unaffected**

Navigate to Overview, On Order Details, Comparison, Charts, and the Backordered Parts drillthrough page. Confirm none of them changed — this work only touched the Trends page and `_Measures.tmdl`/the snapshot table's TMDL (additions only, no existing measures modified).

- [ ] **Step 7: Hide the panel and save final state**

Click "Hide Nav Panel 6" so the Trends page defaults to the clean (no-panel) view. `Ctrl+S`.

- [ ] **Step 8: Commit if Step 7 produced changes**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "chore(open-parts-tickets): set Trends page default state to panel-hidden"
```

---

### Task 13: Push to origin/dev

**Files:** No file edits.

- [ ] **Step 1: Push**

```bash
git push origin dev
```

- [ ] **Step 2: Reminder**

The Trends page is still `HiddenInViewMode` (left as-is per explicit decision during design — not addressed by this plan) and still carries a leftover `Order_No` drillthrough filter binding from whatever page it was originally cloned from. Both remain your call to clean up separately. Once ready, validate in RP-Dev before promoting to RP-Sandbox, then publish to the RP - Parts Reports production workspace per the standard deployment workflow.

---

## Self-Review Notes

- **Spec coverage:** Aging slicer rebind + sort (Task 1, 5), removal of 3 out-of-scope slicers (Task 6), 4 base measures (Task 2), combined KPI row measure with literal-month wording and backorder-only color-coding (Task 3), 4 trend charts including the Aging Mix stacked chart with the real (non-stale) color palette (Task 8–11) — all spec sections have a corresponding task.
- **Deviation documented:** collapsed the spec's 8-measure plan (4 base + 4 separate prior-month measures) into 5 measures (4 base + 1 self-contained KPI row), matching this file's established multi-item HTML measure convention. Noted at the top of this plan.
- **Type/measure name consistency:** `[Snapshot Order Count]`, `[Snapshot Order Total $]`, `[Snapshot Backorder $]`, `[Snapshot Backorder Count]` are used identically across Task 2 (definition), Task 3 (consumed inside `HTML - Trend KPI Row`), and Tasks 8–11 (chart bindings) — verified consistent spelling/capitalization throughout.
- **Explicit user decision:** page visibility (`HiddenInViewMode`) and the leftover `Order_No` drillthrough filter binding are intentionally left untouched per the user's explicit choice during design review — called out again in Task 13 as a reminder, not silently dropped.
