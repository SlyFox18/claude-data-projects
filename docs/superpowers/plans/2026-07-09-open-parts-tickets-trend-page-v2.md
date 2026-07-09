# Open Parts Tickets — Trend Page v2 (Controls & Visual Rework) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Trends page's two grain-mismatched combo charts with proportion-bar timelines matching the Overview page's existing bar component, fix the KPI Row's inconsistent coloring, and add always-visible Aging + time-window controls with a dynamic header context line.

**Architecture:** 5 measure changes in `_Measures.tmdl` (1 modified, 4 new — all mechanical DAX, subagent-executable). The remaining work is Power BI Desktop GUI (remove 2 visuals, add 2 new HTML timeline visuals, add 2 new slicers + 1 action button + 1 bookmark, set Edit Interactions) — **not** subagent-executable, same division of labor as v1.

**Tech Stack:** TMDL (direct file edit), DAX, Power BI Desktop (PBIP format), `pbi` CLI for post-open verification.

**Design spec:** `docs/superpowers/specs/2026-07-09-open-parts-tickets-trend-page-v2-design.md`

**Baseline:** Brian's manual v1 Desktop build is committed as `5dc41867`. This plan's DAX tasks (1–5) modify `_Measures.tmdl` starting from that commit. **The hidden slicer panel (including Brian's own leftover test slicer on `SnapshotDate`) is explicitly out of scope — do not touch it, per his instruction during design review.**

**TMDL formatting note (found during investigation, corrects the convention used in the v1 plan):** Power BI Desktop's own TMDL serializer does **not** wrap multi-line DAX measure bodies in backtick (```` ``` ````) fences — it just writes the indented lines directly after `measure 'Name' =` with no fence markers at all. The v1 measures (`HTML - Trend KPI Row`, `Page 6 - Trends - Header`, etc.) originally had backtick fences when hand-written, but after Desktop opened and saved the file, the fences are gone. All edits below match Desktop's actual current formatting (no backticks) — don't add them back in.

---

## File Map

| File | Change |
|---|---|
| `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl` | Modify `HTML - Trend KPI Row` (Clr1/Clr2 coloring fix) and `Page 6 - Trends - Header` (context line); add `Snapshot Orders with Backorder`, `HTML - Dollars Trend Timeline`, `HTML - Orders Trend Timeline` |
| Desktop: Trends page (`ac8bedf2271b0d172508`) | Remove 2 combo-chart visuals; add 2 htmlContent timeline visuals, 1 Aging Slicer, 1 "All" action button, 1 Relative Date Slicer, 1 bookmark; set Edit Interactions |

---

### Task 1: Fix `HTML - Trend KPI Row` coloring (Invoices + Order Total $ now conditional, not neutral)

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Currently `Card1` (# Invoices) and `Card2` (Order Total $) hardcode their delta text color to `NeutralClr`, while `Card3`/`Card4` (Backorder $ / Backorder Count) use conditional `Clr3`/`Clr4`. Per the v2 design decision, all 4 should use the same red(increase)/green(decrease) rule — this table is open/unfulfilled orders, so a growing Order Count or Order Total $ is backlog growing, same "bad direction" as backorders.

- [ ] **Step 1: Locate the `Clr3`/`Clr4` VAR block**

In `_Measures.tmdl`, inside the `'HTML - Trend KPI Row'` measure, find:

```
			VAR Clr3 = IF(BODollarsChange > 0, BadClr, IF(BODollarsChange < 0, GoodClr, NeutralClr))
			VAR Clr4 = IF(BOCountChange > 0, BadClr, IF(BOCountChange < 0, GoodClr, NeutralClr))
```

- [ ] **Step 2: Add `Clr1`/`Clr2` using the same pattern**

Replace that block with:

```
			VAR Clr1 = IF(InvoicesChange > 0, BadClr, IF(InvoicesChange < 0, GoodClr, NeutralClr))
			VAR Clr2 = IF(DollarsChange > 0, BadClr, IF(DollarsChange < 0, GoodClr, NeutralClr))
			VAR Clr3 = IF(BODollarsChange > 0, BadClr, IF(BODollarsChange < 0, GoodClr, NeutralClr))
			VAR Clr4 = IF(BOCountChange > 0, BadClr, IF(BOCountChange < 0, GoodClr, NeutralClr))
```

- [ ] **Step 3: Locate `Card1` and `Card2`**

Find:

```
			VAR Card1 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'># Invoices</div><div style='" & ValueCSS & "'>" & FORMAT(InvoicesNow, "#,##0") & "</div><div style='font-size: 13px; color: " & NeutralClr & ";'>" & Delta1 & "</div></div>"
			VAR Card2 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'>Order Total $</div><div style='" & ValueCSS & "'>" & FORMAT(DollarsNow, "$#,##0") & "</div><div style='font-size: 13px; color: " & NeutralClr & ";'>" & Delta2 & "</div></div>"
```

- [ ] **Step 4: Swap `NeutralClr` for `Clr1`/`Clr2` in those two lines**

```
			VAR Card1 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'># Invoices</div><div style='" & ValueCSS & "'>" & FORMAT(InvoicesNow, "#,##0") & "</div><div style='font-size: 13px; color: " & Clr1 & ";'>" & Delta1 & "</div></div>"
			VAR Card2 = "<div style='" & CardCSS & "'><div style='" & LabelCSS & "'>Order Total $</div><div style='" & ValueCSS & "'>" & FORMAT(DollarsNow, "$#,##0") & "</div><div style='font-size: 13px; color: " & Clr2 & ";'>" & Delta2 & "</div></div>"
```

Do not touch `Card3`/`Card4`, `Delta1`–`Delta4`, or anything else in this measure. `NeutralClr` stays defined (still used as the fallback branch inside `Clr1`–`Clr4`'s own `IF` logic) — don't remove its `VAR` declaration.

- [ ] **Step 5: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "fix(open-parts-tickets): color all 4 Trend KPI cards consistently, not just backorder ones"
```

---

### Task 2: Add `Snapshot Orders with Backorder` measure

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Counts distinct orders that have at least one backordered part, at the snapshot table's grain — mirrors the live report's existing `Orders with Backordered Parts` measure (`CALCULATE(COUNTROWS(Fact_Parts_Open_Tickets), Fact_Parts_Open_Tickets[#_On_Back_Order] > 0)`), adapted to `DISTINCTCOUNT(Order_No)` since the snapshot table isn't guaranteed one-row-per-order the same way `COUNTROWS` would assume (it's already effectively one row per order per month, but `DISTINCTCOUNT` is the correct, explicit choice here since it's what the sibling `Snapshot Order Count` measure also uses).

- [ ] **Step 1: Confirm the lineage tag is unused**

Search `_Measures.tmdl` for `dddddddddd01`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Locate the end of the `'Snapshot Backorder Count'` measure block:

```
	measure 'Snapshot Backorder Count' = SUM(fact_parts_open_orders_snapshot[#_On_Back_Order])
		formatString: 0
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-3333-4ccc-9003-cccccccccc04

```

followed by a blank line, then `measure 'HTML - Trend KPI Row' =`. Insert the new measure in that blank gap.

- [ ] **Step 3: Insert the measure**

```
	measure 'Snapshot Orders with Backorder' = CALCULATE(DISTINCTCOUNT(fact_parts_open_orders_snapshot[Order_No]), fact_parts_open_orders_snapshot[#_On_Back_Order] > 0)
		formatString: 0
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-4444-4ddd-9004-dddddddddd01

```

Indentation: 1 tab for `measure`, 2 tabs for `formatString`/`displayFolder`/`lineageTag`, matching the sibling single-line measures immediately above it.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add Snapshot Orders with Backorder measure"
```

---

### Task 3: Add `HTML - Dollars Trend Timeline` measure

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Renders one proportion-bar row per snapshot month currently in view (respecting whatever the Aging Slicer and Relative Date Slicer — both added in later Desktop tasks — have filtered), each showing Available $ vs. Backordered $ as a 2-segment bar, styled identically to Overview's `bar-good`/`bar-warning` gradient classes (`#4A5B73`→`#3D4D5F` and `#D45353`→`#B93F3F`). Row count is dynamic — built via `CONCATENATEX` over `VALUES(fact_parts_open_orders_snapshot[SnapshotDate])`, not hardcoded per-month `VAR`s like the retired v1 line chart's data — so it naturally shows fewer rows if the Relative Date slicer is narrowed, or more as new snapshot months accumulate.

- [ ] **Step 1: Confirm the lineage tag is unused**

Search `_Measures.tmdl` for `dddddddddd02`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Insert immediately after the `'Snapshot Orders with Backorder'` block added in Task 2, before `measure 'HTML - Trend KPI Row' =`.

- [ ] **Step 3: Insert the measure**

```
	measure 'HTML - Dollars Trend Timeline' =
			
			VAR RowCSS = "display:grid; grid-template-columns:58px 1fr; gap:10px; align-items:center; margin-bottom:11px;"
			VAR MonthCSS = "font-size:11.5px; font-weight:700; color:#5B6B74; text-align:right;"
			VAR EndLabelCSS = "display:flex; justify-content:space-between; font-size:10.5px; color:#5B6B74; margin-bottom:3px;"
			VAR BarCSS = "display:flex; height:22px; border-radius:5px; overflow:hidden; box-shadow: inset 0 1px 2px rgba(0,0,0,0.15);"
			VAR SegGoodCSS = "display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; color:#fff; background:linear-gradient(to bottom,#4A5B73,#3D4D5F);"
			VAR SegBadCSS = "display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; color:#fff; background:linear-gradient(to bottom,#D45353,#B93F3F);"
			
			VAR MonthsWithAmounts =
			    ADDCOLUMNS(
			        VALUES(fact_parts_open_orders_snapshot[SnapshotDate]),
			        "TotalAmt", CALCULATE([Snapshot Order Total $]),
			        "BOAmt", CALCULATE([Snapshot Backorder $])
			    )
			VAR MonthsWithPct =
			    ADDCOLUMNS(
			        MonthsWithAmounts,
			        "AvailAmt", [TotalAmt] - [BOAmt],
			        "AvailPct", DIVIDE([TotalAmt] - [BOAmt], [TotalAmt]),
			        "BOPct", DIVIDE([BOAmt], [TotalAmt]),
			        "MonthLabel", FORMAT(fact_parts_open_orders_snapshot[SnapshotDate], "MMM YYYY")
			    )
			
			VAR Rows =
			    CONCATENATEX(
			        MonthsWithPct,
			        "<div style='" & RowCSS & "'><div style='" & MonthCSS & "'>" & [MonthLabel] & "</div><div><div style='" & EndLabelCSS & "'><span>" & FORMAT([AvailAmt], "$#,##0") & "</span><span>" & FORMAT([BOAmt], "$#,##0") & "</span></div><div style='" & BarCSS & "'><div style='" & SegGoodCSS & " width:" & FORMAT([AvailPct] * 100, "0.0") & "%;'>" & FORMAT([AvailPct], "0%") & "</div><div style='" & SegBadCSS & " width:" & FORMAT([BOPct] * 100, "0.0") & "%;'>" & FORMAT([BOPct], "0%") & "</div></div></div></div>",
			        "",
			        fact_parts_open_orders_snapshot[SnapshotDate], ASC
			    )
			
			RETURN
			"<div style='font-family: Segoe UI, Arial, sans-serif;'>" & Rows & "</div>"
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-4444-4ddd-9004-dddddddddd02

```

Indentation: 3 tabs for the DAX body lines (matching `HTML - Trend KPI Row`'s current formatting — no backtick fence, per the note at the top of this plan), 2 tabs for `displayFolder`/`lineageTag`, blank line after.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Dollars Trend Timeline measure"
```

---

### Task 4: Add `HTML - Orders Trend Timeline` measure

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Same pattern as Task 3, but Orders without a backorder vs. orders with ≥1 backordered part (`[Snapshot Order Count]` and `[Snapshot Orders with Backorder]` instead of the two dollar measures).

- [ ] **Step 1: Confirm the lineage tag is unused**

Search `_Measures.tmdl` for `dddddddddd03`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Insert immediately after the `'HTML - Dollars Trend Timeline'` block added in Task 3, before `measure 'HTML - Trend KPI Row' =`.

- [ ] **Step 3: Insert the measure**

```
	measure 'HTML - Orders Trend Timeline' =
			
			VAR RowCSS = "display:grid; grid-template-columns:58px 1fr; gap:10px; align-items:center; margin-bottom:11px;"
			VAR MonthCSS = "font-size:11.5px; font-weight:700; color:#5B6B74; text-align:right;"
			VAR EndLabelCSS = "display:flex; justify-content:space-between; font-size:10.5px; color:#5B6B74; margin-bottom:3px;"
			VAR BarCSS = "display:flex; height:22px; border-radius:5px; overflow:hidden; box-shadow: inset 0 1px 2px rgba(0,0,0,0.15);"
			VAR SegGoodCSS = "display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; color:#fff; background:linear-gradient(to bottom,#4A5B73,#3D4D5F);"
			VAR SegBadCSS = "display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; color:#fff; background:linear-gradient(to bottom,#D45353,#B93F3F);"
			
			VAR MonthsWithCounts =
			    ADDCOLUMNS(
			        VALUES(fact_parts_open_orders_snapshot[SnapshotDate]),
			        "TotalOrders", CALCULATE([Snapshot Order Count]),
			        "WithBO", CALCULATE([Snapshot Orders with Backorder])
			    )
			VAR MonthsWithPct =
			    ADDCOLUMNS(
			        MonthsWithCounts,
			        "WithoutBO", [TotalOrders] - [WithBO],
			        "WithoutBOPct", DIVIDE([TotalOrders] - [WithBO], [TotalOrders]),
			        "WithBOPct", DIVIDE([WithBO], [TotalOrders]),
			        "MonthLabel", FORMAT(fact_parts_open_orders_snapshot[SnapshotDate], "MMM YYYY")
			    )
			
			VAR Rows =
			    CONCATENATEX(
			        MonthsWithPct,
			        "<div style='" & RowCSS & "'><div style='" & MonthCSS & "'>" & [MonthLabel] & "</div><div><div style='" & EndLabelCSS & "'><span>" & FORMAT([WithoutBO], "#,##0") & " orders</span><span>" & FORMAT([WithBO], "#,##0") & " orders</span></div><div style='" & BarCSS & "'><div style='" & SegGoodCSS & " width:" & FORMAT([WithoutBOPct] * 100, "0.0") & "%;'>" & FORMAT([WithoutBOPct], "0%") & "</div><div style='" & SegBadCSS & " width:" & FORMAT([WithBOPct] * 100, "0.0") & "%;'>" & FORMAT([WithBOPct], "0%") & "</div></div></div></div>",
			        "",
			        fact_parts_open_orders_snapshot[SnapshotDate], ASC
			    )
			
			RETURN
			"<div style='font-family: Segoe UI, Arial, sans-serif;'>" & Rows & "</div>"
		displayFolder: Snapshot Trend
		lineageTag: f2b3c4d5-4444-4ddd-9004-dddddddddd03

```

Same indentation convention as Task 3.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Orders Trend Timeline measure"
```

---

### Task 5: Add dynamic context line to `Page 6 - Trends - Header`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Shows what's currently in view — e.g. "Viewing May 2026 - Jul 2026 · Aging 90+ days" — computed from plain `MIN`/`MAX`/`SELECTEDVALUE` in the header visual's own ambient filter context (no `CALCULATE` override needed: the header visual will receive the same Aging Slicer + Relative Date Slicer filters as every other visual on the page once those slicers are added in Task 9/11, as long as Edit Interactions isn't set to "None" between them — leave it at the default "Filter"). This sidesteps the open question flagged in the design spec about reading back a Relative Date slicer's specific selection — instead of trying to reverse-engineer which preset was picked, the header just reports the actual resulting date range, which is correct regardless of what filtering mechanism produced it.

- [ ] **Step 1: Locate the VAR block before `RETURN`**

Find:

```
			VAR TimeGreeting =
			    IF(CurrentHour < 12, "Good Morning",
			    IF(CurrentHour < 17, "Good Afternoon",
			    "Good Evening"))
			
			RETURN
```

- [ ] **Step 2: Add the context VARs**

```
			VAR TimeGreeting =
			    IF(CurrentHour < 12, "Good Morning",
			    IF(CurrentHour < 17, "Good Afternoon",
			    "Good Evening"))
			
			VAR ViewMin = MIN(fact_parts_open_orders_snapshot[SnapshotDate])
			VAR ViewMax = MAX(fact_parts_open_orders_snapshot[SnapshotDate])
			VAR ViewLabel =
			    IF(
			        ISBLANK(ViewMin), "All Months",
			        IF(ViewMin = ViewMax, FORMAT(ViewMax, "MMM YYYY"), FORMAT(ViewMin, "MMM YYYY") & " - " & FORMAT(ViewMax, "MMM YYYY"))
			    )
			VAR AgingLabel = SELECTEDVALUE(fact_parts_open_orders_snapshot[Aging], "All")
			
			RETURN
```

- [ ] **Step 3: Locate the Title `<div>` block**

Find:

```
			    <!-- Title -->
			    <div>
			        <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
			            REPORT
			        </div>
			        <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
			            Trends - Open Parts Tickets
			        </div>
			    </div>
```

- [ ] **Step 4: Add the context line inside that div**

```
			    <!-- Title -->
			    <div>
			        <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
			            REPORT
			        </div>
			        <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
			            Trends - Open Parts Tickets
			        </div>
			        <div style='font-size: 12px; opacity: 0.75; margin-top: 4px;'>
			            Viewing " & ViewLabel & " &middot; Aging " & AgingLabel & "
			        </div>
			    </div>
```

- [ ] **Step 5: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add dynamic filter context line to Trends header"
```

---

### Task 6: Open in Desktop and verify all 5 measure changes

**Files:** No file edits — verification only.

- [ ] **Step 1: Open/refresh in Desktop**

`projects/open parts tickets - report/reports/current/Open Parts Tickets.pbip` should already be open (per Brian). If Desktop reports a parse error, it names the file and line — common causes: mismatched tab indentation, a duplicate lineage tag, or a stray `//` at the TMDL structural level. Fix in the TMDL file, save, reopen.

- [ ] **Step 2: Connect the `pbi` CLI**

```powershell
$env:Path += ";C:\Users\bfox\.local\bin"
pbi connect -n "PBIDesktop-Open Parts Tickets-<port>"
```

(Use `pbi connect` with no args first to auto-detect the port; if `pbi measure list` then fails with a "Connection not found" error, re-run with the exact `-n` name it auto-detected — this connection-naming mismatch was a known `pbi-cli` quirk hit during v1's Task 4.)

- [ ] **Step 3: Verify all 5 new/changed measures exist**

```
pbi measure list
```

Expected: `Snapshot Orders with Backorder`, `HTML - Dollars Trend Timeline`, `HTML - Orders Trend Timeline` all appear under `_Measures` / Snapshot Trend (new). `HTML - Trend KPI Row` and `Page 6 - Trends - Header` still appear (modified, not renamed).

- [ ] **Step 4: Spot-check `Snapshot Orders with Backorder`**

```
pbi dax execute "EVALUATE ROW(""WithBO"", [Snapshot Orders with Backorder], ""Total"", [Snapshot Order Count])"
```

**Note:** `pbi dax execute` was found broken in v1's Task 4 (it silently drops row data due to an `EmbeddedResource` parsing bug in the installed `pbi-cli` version — returns `{"success":true}` with no values). If that recurs, don't treat a blank/missing result as the measure being wrong — cross-check via the Desktop UI directly instead (drop the measure onto a temporary Card visual and read the number, or use Performance Analyzer). Expected either way: a non-blank, non-zero `WithBO` value strictly less than `Total`.

- [ ] **Step 5: Spot-check `HTML - Dollars Trend Timeline` renders multiple rows**

```
pbi dax execute "EVALUATE ROW(""Timeline"", LEFT([HTML - Dollars Trend Timeline], 300))"
```

(Or via a temporary Card/Table visual if Step 4's tooling issue recurs.) Expected: HTML starting with the wrapper div, followed by at least one row's markup containing a month label (e.g. `Mar 2026`) and a `$` amount. If it errors, check that `[Snapshot Order Total $]` and `[Snapshot Backorder $]` are spelled exactly as in Task 3's `ADDCOLUMNS` calls (case-sensitive DAX bracket references).

- [ ] **Step 6: Spot-check `HTML - Orders Trend Timeline` the same way**

```
pbi dax execute "EVALUATE ROW(""Timeline"", LEFT([HTML - Orders Trend Timeline], 300))"
```

Expected: HTML starting with the wrapper div, a month label, and an "orders" label. If it errors, check `[Snapshot Order Count]` and `[Snapshot Orders with Backorder]` spelling.

- [ ] **Step 7: Spot-check the header's new context line (unfiltered state)**

```
pbi dax execute "EVALUATE ROW(""Header"", MID([Page 6 - Trends - Header], 1, 1500))"
```

With no Aging/Relative Date slicers on the page yet (added in later tasks), this evaluates in the model's default/unfiltered context. Expected: the returned HTML contains `Viewing` followed by a month range spanning all snapshot months to date, and `Aging All` (since `SELECTEDVALUE` falls back to `"All"` with nothing selected). This confirms the DAX is syntactically valid and evaluates without error — full behavior (narrowing when slicers are applied) gets validated in Task 13 once those slicers exist.

- [ ] **Step 8: Verify `HTML - Trend KPI Row`'s new coloring**

```
pbi dax execute "EVALUATE ROW(""KPI"", MID([HTML - Trend KPI Row], 1, 2000))"
```

Search the returned string for the `# Invoices` and `Order Total $` card blocks. Expected: their delta `<div>`'s `color:` value is now `#5CB85C` (green) or `#FF6B6B` (red) — not `#1D3C4E` (the old neutral navy) — matching whatever direction the current month's change actually is.

---

### Task 7: Remove the 2 old combo-chart visuals

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Delete "Order Count Trend"**

On the Trends page, select the combo chart at the top-left (internal name `761c2eaecd4392148d88`, bound to `Snapshot Order Count` + `Snapshot Backorder Count`). Press Delete.

- [ ] **Step 2: Delete "Dollars Trend" (combo chart)**

Select the combo chart at the bottom-left (internal name `6d4ba374659736084bf1`, bound to `Snapshot Order Total $` + `Snapshot Backorder $`). Press Delete.

- [ ] **Step 3: Save**

`Ctrl+S`.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "chore(open-parts-tickets): remove v1 combo charts from Trends page"
```

---

### Task 8: Add the 2 new proportion-bar timeline visuals

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add "Dollars Trend" timeline**

Drag an "HTML Content" custom visual onto the canvas (same spot the old top-left combo chart occupied — roughly `x=59, y=249, width=791, height=314`, but use your judgment on exact fit once the control bar in Task 11 is in place). Bind it to `HTML - Dollars Trend Timeline`. Give it a title: "Dollars Trend".

- [ ] **Step 2: Add "Orders Trend" timeline**

Drag another "HTML Content" visual into the bottom-left spot (roughly `x=59, y=578, width=791, height=328`). Bind it to `HTML - Orders Trend Timeline`. Title: "Orders Trend".

- [ ] **Step 3: Save**

`Ctrl+S`.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Dollars Trend and Orders Trend proportion-bar timelines"
```

---

### Task 9: Add the Aging chip slicer + "All" button

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

**Reminder: this goes in the main canvas, not the hidden panel.** Suggested position: a new row between the header and the KPI row (you'll likely need to nudge the KPI row and the two panels below it down slightly, and/or shrink Aging Mix Over Time's height a bit, to make room — use your judgment on exact pixels, the page is nearly full at 936px tall already).

- [ ] **Step 1: Add the Aging Slicer**

Drag a Slicer visual onto the canvas. Bind it to `fact_parts_open_orders_snapshot[Aging]`.

- [ ] **Step 2: Style it as a horizontal tile row**

Format pane:
1. **Visual → Slicer settings → Options**: Style = `Tile`, Orientation = `Horizontal`.
2. **Visual → Slicer settings → Selection**: Single select = On.
3. **Visual → Header**: toggle off.
4. **General → Effects**: light border, white background — match the `.chip` styling from the mockup discussed in chat (rounded pill look) as closely as Power BI's native tile formatting allows.

- [ ] **Step 3: Confirm sort order**

Right-click the slicer's field or use "More options" → **Sort by** `Aging_Sort_Order` (should already be the default, since that's set at the model level).

- [ ] **Step 4: Color the tiles per the real aging palette**

Format pane → Visual → Values (or per-category formatting, depending on Desktop version) — set each Aging value's tile color:

| Aging value | Color |
|---|---|
| 0-7 days | `#27ae60` |
| 8-14 days | `#52c41a` |
| 15-30 days | `#faad14` |
| 31-60 days | `#fa8c16` |
| 61-90 days | `#f5222d` |
| 90+ days | `#cf1322` |

- [ ] **Step 5: Add the "All" button**

Drag an "Action Button" (Blank type) immediately to the left of the Aging slicer. Label it "All". Style it to visually match the slicer tiles (rounded, similar sizing).

- [ ] **Step 6: Create a bookmark that clears the Aging slicer**

With the Aging slicer showing no selection, open the Bookmarks pane → **Add** a new bookmark. Rename it to something clear, e.g. "Clear Aging Filter". Under the bookmark's options, make sure only "Data" (filter state) is captured, not "Display" (so it doesn't also reset visual visibility/position).

- [ ] **Step 7: Wire the "All" button to the bookmark**

Select the "All" button → Format pane → **Action**: toggle on, Type = `Bookmark`, Bookmark = "Clear Aging Filter" (the one just created).

- [ ] **Step 8: Save**

`Ctrl+S`.

- [ ] **Step 9: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/" "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/bookmarks/"
git commit -m "feat(open-parts-tickets): add Aging chip slicer and All button to Trends page"
```

---

### Task 10: Add the Relative Date slicer

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

- [ ] **Step 1: Add the slicer**

Drag a new Slicer visual onto the canvas, positioned next to the Aging chip row (e.g. right-aligned in the same control-bar row). Bind it to `fact_parts_open_orders_snapshot[SnapshotDate]`.

- [ ] **Step 2: Switch to Relative Date style**

Format pane → Visual → **Slicer settings → Options → Style**: `Relative date`. Set the default unit to **Months**, value **6** (i.e., "in the last 6 months").

- [ ] **Step 3: Confirm behavior**

With no other filters applied, this should show all 5 current snapshot months (Mar–Jul 2026) since there are fewer than 6 months of history so far — confirm it doesn't error or show blank just because the full window isn't "filled" yet.

- [ ] **Step 4: Save**

`Ctrl+S`.

- [ ] **Step 5: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): add Relative Date slicer to Trends page"
```

---

### Task 11: Set Edit Interactions for both new slicers

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/`

Per the design spec's interaction-scoping table:

| Slicer | KPI Row | Dollars Trend Timeline | Orders Trend Timeline | Aging Mix Over Time |
|---|---|---|---|---|
| Aging Slicer | Filter | Filter | Filter | **None** |
| Relative Date Slicer | Filter | Filter | Filter | Filter |

- [ ] **Step 1: Select the Aging Slicer, enter Edit Interactions**

Format ribbon tab → **Edit interactions**. Filter-type icons appear above every other visual on the page.

- [ ] **Step 2: Set Aging Slicer's interactions**

- Above the KPI Row visual: **Filter**
- Above the Dollars Trend Timeline visual: **Filter**
- Above the Orders Trend Timeline visual: **Filter**
- Above the Aging Mix Over Time visual: **None**
- Leave the hidden panel's visuls and any other page elements at their default — don't touch them

- [ ] **Step 3: Select the Relative Date Slicer, repeat**

- Above the KPI Row visual: **Filter**
- Above the Dollars Trend Timeline visual: **Filter**
- Above the Orders Trend Timeline visual: **Filter**
- Above the Aging Mix Over Time visual: **Filter**

- [ ] **Step 4: Exit Edit Interactions mode, save**

`Ctrl+S`.

- [ ] **Step 5: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/ac8bedf2271b0d172508/"
git commit -m "feat(open-parts-tickets): scope Trends page slicer interactions (Aging Mix immune to Aging filter)"
```

---

### Task 12: Visual and interaction QA

**Files:** No file edits — verification only. Re-run the relevant earlier task's Desktop steps if any check below fails, then re-save and re-commit.

- [ ] **Step 1: Default state**

With no Aging selection and the Relative Date slicer at its default, confirm: KPI Row shows correct consistent coloring on all 4 cards, both timelines render one row per available month, Aging Mix Over Time shows all 6 buckets across all months, header context line reads something like "Viewing Mar 2026 - Jul 2026 · Aging All".

- [ ] **Step 2: Aging Slicer filters correctly, Aging Mix stays immune**

Select a single Aging bucket (e.g. "90+ days"). Confirm: KPI Row and both timelines update to reflect only that bucket. Aging Mix Over Time does **not** change. Header context line updates to show the selected bucket name.

- [ ] **Step 3: "All" button clears the Aging selection**

Click "All". Confirm the Aging slicer's selection clears and all 4 visuals return to the unfiltered-by-Aging state. Header context line returns to "Aging All".

- [ ] **Step 4: Relative Date slicer filters everything including Aging Mix**

Narrow the Relative Date slicer (e.g. "in the last 3 months"). Confirm all 4 visuals — KPI Row, both timelines, and Aging Mix Over Time — shrink to the narrower window. Header context line's "Viewing" range updates accordingly.

- [ ] **Step 5: Timeline row count matches the filtered window**

Confirm the Dollars Trend and Orders Trend timelines show exactly as many rows as months are in view per Step 4 — no extra blank rows, no missing months.

- [ ] **Step 6: Combined filtering**

Select one Aging bucket **and** narrow the Relative Date slicer at the same time. Confirm KPI Row and both timelines reflect both filters together (narrower month range, single bucket), while Aging Mix Over Time reflects only the date narrowing.

- [ ] **Step 7: Hidden panel is untouched**

Open the hidden panel (however Brian currently triggers it). Confirm it looks exactly as it did before this work started — same slicers (including his test `SnapshotDate` slicer, left as-is), same bookmarks, same navigation behavior.

- [ ] **Step 8: Other pages unaffected**

Navigate to Overview, On Order Details, Comparison, Charts, and the Backordered Parts drillthrough page. Confirm none of them changed.

---

### Task 13: Push to origin/dev

**Files:** No file edits.

- [ ] **Step 1: Push**

```bash
git push origin dev
```

- [ ] **Step 2: Reminder**

The Trends page is still `HiddenInViewMode` and still carries the leftover `Order_No` drillthrough filter binding — both remain Brian's call, untouched by this plan. Once ready, validate in RP-Dev before promoting to RP-Sandbox, then publish to the RP - Parts Reports production workspace per the standard deployment workflow.

---

## Self-Review Notes

- **Spec coverage:** KPI Row consistent coloring (Task 1), same-grain Orders measure (Task 2), both proportion-bar timeline measures (Tasks 3–4), dynamic header context (Task 5), removal of the old grain-mismatched charts (Task 7), new timeline visuals (Task 8), Aging chip control + All button (Task 9), Relative Date control (Task 10), correct interaction scoping including Aging Mix's immunity to the Aging filter (Task 11) — all spec sections have a corresponding task.
- **Hidden panel respected:** no task touches the hidden panel; Task 12 Step 7 explicitly verifies it's unchanged, including Brian's own leftover test slicer.
- **Corrected the design spec's open question:** the spec flagged "reading back a Relative Date slicer's selection needs a Desktop spike." Task 5 resolves this without a spike — by computing the actual `MIN`/`MAX` of the filtered date range directly (mechanism-agnostic, works regardless of what produced the filter) instead of trying to read the slicer's internal preset label.
- **Found and corrected a formatting assumption:** the v1 plan's backtick-fence convention for multi-line DAX doesn't match what Desktop's TMDL serializer actually writes (confirmed by reading the live file after Brian's Desktop session saved it). All new/modified DAX in this plan matches the real current format.
- **Type/measure name consistency:** `[Snapshot Order Count]`, `[Snapshot Order Total $]`, `[Snapshot Backorder $]`, `[Snapshot Orders with Backorder]` are spelled identically across their defining tasks and every place they're consumed (Tasks 3, 4) — verified against actual current `_Measures.tmdl` content, not assumed from memory.
