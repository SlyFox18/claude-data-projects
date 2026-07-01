# Open Parts Tickets — Page 1 Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Page 1 ("Overview")'s single stacked-section HTML dashboard with a hero totals row, a compact 6-card aging row, and a Backorder Pulse section — with the aging cards driving Hero/Pulse via an invisible slicer overlay (the HTML Content custom visual has no native click support).

**Architecture:** Three new DAX measures in `_Measures.tmdl` (direct file edit), reusing existing measures (`[Order Total]`, `[# Parts On Order]`, `[Line Count]`, `[Total # of Orders]`, and the 4 `KPI SVG - ... (Modern)` measures) rather than rebuilding them. Page layout changes (new visual containers, the invisible slicer, Edit Interactions) are done in Power BI Desktop, since hand-authoring slicer format JSON is unreliable — Desktop's save process writes correct `visual.json`/`page.json`.

**Tech Stack:** TMDL (direct file edit), DAX, Power BI Desktop (PBIP format), `pbi` CLI for post-open verification.

**Design spec:** `docs/superpowers/specs/2026-06-24-open-parts-tickets-page1-redesign-design.md`

**Correction vs. the design spec:** the spec assumed the 4 `KPI SVG - ... (Modern)` measures return raw `<svg>` markup that can be concatenated directly into HTML. Checking the actual TMDL shows they return a full data URI instead (`RETURN "data:image/svg+xml;utf8," & SVG`) — meant to be consumed as an `<img src="...">` value, not concatenated as literal markup. Task 3 below handles this correctly with `CHAR(34)` quote handling (see that task for why).

---

## File Map

| File | Change |
|---|---|
| `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl` | Add `HTML - Parts Overview Hero`, `HTML - Aging Card Row`, `HTML - Backorder Pulse`. Later remove `_HTML_Bucket1`–`6` and `HTML - Parts Overview Dashboard`. |
| Desktop: Page 1 ("Overview") | Remove old HTML visual + 2 hidden scaffold visuals; add 3 new htmlContent visuals + 1 transparent Slicer; set Edit Interactions |

---

### Task 1: Add `HTML - Parts Overview Hero` measure to `_Measures.tmdl`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Adapted from the existing `Hero Card - Parts Open Tickets` measure (lines 1327–1409), trimmed from 4 metrics to 3 (drops Total Orders, since that now lives on the aging card the user clicked) and adds a dynamic "TOTALS — {tier}" label. Built as a **new** measure rather than editing the existing one, because `Hero Card - Parts Open Tickets` is already placed on 2 other pages (`On Order Details`, `Backordered Parts` drillthrough) and must not change there.

- [ ] **Step 1: Confirm lineage tag `e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa01` is unused**

Search `_Measures.tmdl` for `aaaaaaaaaa01`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Locate the end of the `Hero Card - Parts Open Tickets` measure block — it ends at line 1412 with:

```
		lineageTag: 694c9a63-5c85-44b7-9153-df1d784df5c9
```

followed by a blank line, then `measure 'Page 5 - Details DT - Header' =`. Insert the new measure in that blank gap, before `'Page 5 - Details DT - Header'`.

- [ ] **Step 3: Insert the new measure**

```
	measure 'HTML - Parts Overview Hero' = ```
			
			VAR SelectedTier = SELECTEDVALUE(Fact_Parts_Open_Tickets[Aging], "All Tiers")
			VAR OrderTotal = [Order Total]
			VAR PartsOnOrder = [# Parts On Order]
			VAR LinesCount = [Line Count]
			
			RETURN
			"
			<div style='
			    font-family: Segoe UI, Arial, sans-serif;
			    padding: 16px 30px;
			    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
			    border-radius: 12px;
			    color: white;
			    height: 100%;
			    box-sizing: border-box;
			    display: flex;
			    flex-direction: column;
			    justify-content: center;
			'>
			    <div style='font-size: 12px; opacity: 0.75; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px;'>
			        TOTALS &mdash; " & SelectedTier & "
			    </div>
			    <div style='display: flex; align-items: center; justify-content: space-around;'>
			        <div style='text-align: center; flex: 1;'>
			            <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 1px;'>
			                Order Total
			            </div>
			            <div style='font-size: 40px; font-weight: 700; line-height: 1;'>
			                " & FORMAT(OrderTotal, "$#,##0") & "
			            </div>
			        </div>
			        <div style='width: 2px; height: 60px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
			        <div style='text-align: center; flex: 1;'>
			            <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 1px;'>
			                # Parts On Order
			            </div>
			            <div style='font-size: 40px; font-weight: 700; line-height: 1;'>
			                " & FORMAT(PartsOnOrder, "#,##0") & "
			            </div>
			        </div>
			        <div style='width: 2px; height: 60px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
			        <div style='text-align: center; flex: 1;'>
			            <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 1px;'>
			                Parts Line Count
			            </div>
			            <div style='font-size: 40px; font-weight: 700; line-height: 1;'>
			                " & FORMAT(LinesCount, "#,##0") & "
			            </div>
			        </div>
			    </div>
			</div>
			"
			```
		displayFolder: Core Metrics
		lineageTag: e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa01

```

Indentation: the backtick-fenced DAX body uses 3 tabs for its content lines (matching the existing `Hero Card - Parts Open Tickets` measure directly above it), 2 tabs for `displayFolder`/`lineageTag`. Blank line after `lineageTag` before the next measure.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Parts Overview Hero measure"
```

---

### Task 2: Add `HTML - Aging Card Row` measure to `_Measures.tmdl`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Six compact cards, one per aging tier. Each count is hardcoded to its own bucket via `CALCULATE(..., Aging = Lbl)` — same convention as `_HTML_Bucket1`–`6` — so these cards are intentionally immune to the slicer added in Task 6. Colors are the real palette pulled from `_HTML_Bucket1`–`6` (not the stale gradient in `REPORT-PAGES-GUIDE.md`).

- [ ] **Step 1: Confirm lineage tag `e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa02` is unused**

Search `_Measures.tmdl` for `aaaaaaaaaa02`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Insert immediately after the `HTML - Parts Overview Hero` block added in Task 1 (after its `lineageTag` line and the following blank line), before `measure 'Page 5 - Details DT - Header' =`.

- [ ] **Step 3: Insert the new measure**

```
	measure 'HTML - Aging Card Row' = ```
			
			VAR Lbl1 = "90+ days"
			VAR Clr1 = "#cf1322"
			VAR Lbl2 = "61-90 days"
			VAR Clr2 = "#f5222d"
			VAR Lbl3 = "31-60 days"
			VAR Clr3 = "#fa8c16"
			VAR Lbl4 = "15-30 days"
			VAR Clr4 = "#faad14"
			VAR Lbl5 = "8-14 days"
			VAR Clr5 = "#52c41a"
			VAR Lbl6 = "0-7 days"
			VAR Clr6 = "#27ae60"
			VAR Cnt1 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl1)
			VAR Cnt2 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl2)
			VAR Cnt3 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl3)
			VAR Cnt4 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl4)
			VAR Cnt5 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl5)
			VAR Cnt6 = CALCULATE([Total # of Orders], Fact_Parts_Open_Tickets[Aging] = Lbl6)
			VAR CardCSS = "background: white; border-radius: 6px; padding: 10px 6px; text-align: center; flex: 1; box-shadow: 0 1px 3px rgba(0,0,0,0.08); box-sizing: border-box;"
			VAR Card1 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr1 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl1 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt1, "#,##0") & " orders</div></div>"
			VAR Card2 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr2 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl2 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt2, "#,##0") & " orders</div></div>"
			VAR Card3 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr3 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl3 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt3, "#,##0") & " orders</div></div>"
			VAR Card4 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr4 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl4 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt4, "#,##0") & " orders</div></div>"
			VAR Card5 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr5 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl5 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt5, "#,##0") & " orders</div></div>"
			VAR Card6 = "<div style='" & CardCSS & " border-top: 3px solid " & Clr6 & ";'><div style='font-size: 11px; color: #666;'>" & Lbl6 & "</div><div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-top: 4px;'>" & FORMAT(Cnt6, "#,##0") & " orders</div></div>"
			
			RETURN
			"<div style='font-family: Segoe UI, Arial, sans-serif; display: flex; gap: 6px; height: 100%; box-sizing: border-box;'>" & Card1 & Card2 & Card3 & Card4 & Card5 & Card6 & "</div>"
			```
		displayFolder: Core Metrics
		lineageTag: e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa02

```

Same indentation convention as Task 1 (3 tabs inside the backtick body, 2 tabs for `displayFolder`/`lineageTag`).

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Aging Card Row measure"
```

---

### Task 3: Add `HTML - Backorder Pulse` measure to `_Measures.tmdl`

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

**Why `CHAR(34)` instead of literal quotes:** the 4 `KPI SVG - ... (Modern)` measures return a data URI (`data:image/svg+xml;utf8,<svg ...>`), and that embedded SVG markup uses single quotes for all of its own attributes (e.g. `fill='#4A5B73'`). If this measure's own `<img src='...'>` wrapper also used single quotes, the SVG's first internal single quote would prematurely close the `src` attribute and corrupt the markup. Using `CHAR(34)` (a literal double-quote character) for the wrapper's `src` attribute avoids the collision entirely, since the embedded SVG never contains a double quote.

- [ ] **Step 1: Confirm lineage tag `e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa03` is unused**

Search `_Measures.tmdl` for `aaaaaaaaaa03`. Expected: no matches.

- [ ] **Step 2: Find the insertion point**

Insert immediately after the `HTML - Aging Card Row` block added in Task 2, before `measure 'Page 5 - Details DT - Header' =`.

- [ ] **Step 3: Insert the new measure**

```
	measure 'HTML - Backorder Pulse' = ```
			
			VAR Q = CHAR(34)
			VAR SelectedTier = SELECTEDVALUE(Fact_Parts_Open_Tickets[Aging], "All Tiers")
			VAR ImgCSS = "display: block; width: 100%; max-width: 700px; margin: 0 auto 12px auto;"
			VAR Img1 = "<img src=" & Q & [KPI SVG - Order Total vs Backordered (Modern)] & Q & " style=" & Q & ImgCSS & Q & " />"
			VAR Img2 = "<img src=" & Q & [KPI SVG - Parts On Order vs Back Order (Modern)] & Q & " style=" & Q & ImgCSS & Q & " />"
			VAR Img3 = "<img src=" & Q & [KPI SVG - Line Count vs Backordered Line (Modern)] & Q & " style=" & Q & ImgCSS & Q & " />"
			VAR Img4 = "<img src=" & Q & [KPI SVG - Orders vs Orders with BO Parts (Modern)] & Q & " style=" & Q & ImgCSS & Q & " />"
			
			RETURN
			"<div style='font-family: Segoe UI, Arial, sans-serif; background: white; border-radius: 6px; padding: 14px; height: 100%; box-sizing: border-box; overflow-y: auto;'>" &
			"<div style='font-size: 12px; color: #666; margin-bottom: 10px; font-weight: 600; text-align: center;'>BACKORDER PULSE &mdash; " & SelectedTier & "</div>" &
			Img1 & Img2 & Img3 & Img4 &
			"</div>"
			```
		displayFolder: Core Metrics
		lineageTag: e1a2b3c4-1111-4aaa-9001-aaaaaaaaaa03

```

Same indentation convention as Tasks 1–2.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "feat(open-parts-tickets): add HTML - Backorder Pulse measure"
```

---

### Task 4: Open in Desktop and verify the 3 new measures

**Files:** No file edits — verification only.

- [ ] **Step 1: Open the PBIP file**

Open `projects/open parts tickets - report/reports/current/Open Parts Tickets.pbip` in Power BI Desktop.

If Desktop reports a parse error, it names the file and line. Common causes: a stray `//` at the TMDL structural level, mismatched tab indentation, or a duplicate lineage tag. Fix in the TMDL file, save, reopen.

- [ ] **Step 2: Connect the `pbi` CLI**

```powershell
$env:Path += ";C:\Users\bfox\.local\bin"
pbi connect
```

- [ ] **Step 3: Verify all 3 measures exist**

```
pbi measure list
```

Expected: `HTML - Parts Overview Hero`, `HTML - Aging Card Row`, `HTML - Backorder Pulse` all appear under `_Measures` / Core Metrics.

- [ ] **Step 4: Spot-check the Hero measure's default (all-tiers) output**

```
pbi dax execute "EVALUATE ROW(""Hero"", LEFT([HTML - Parts Overview Hero], 80))"
```

Expected: a string starting with `<div style=' font-family: Segoe UI...` and containing `TOTALS — All Tiers` further in (not visible in the 80-char preview, but confirms the measure evaluates without error). If this errors, check that `[Order Total]`, `[# Parts On Order]`, and `[Line Count]` exist exactly as named (case-sensitive) in `_Measures`.

- [ ] **Step 5: Spot-check the Aging Card Row measure**

```
pbi dax execute "EVALUATE ROW(""Cards"", LEFT([HTML - Aging Card Row], 80))"
```

Expected: a string starting with `<div style='font-family: Segoe UI, Arial, sans-serif; display: flex...`.

- [ ] **Step 6: Spot-check the Backorder Pulse measure renders a valid data URI inside the `<img>` tag**

```
pbi dax execute "EVALUATE ROW(""Pulse"", MID([HTML - Backorder Pulse], 150, 60))"
```

Expected: somewhere in the output you should see `<img src="data:image/svg+xml;utf8,` (note **double** quotes around the data URI — confirms the `CHAR(34)` wrapper worked, not the SVG's own single quotes leaking into the `src` boundary). If instead you see `<img src='data:image...` with a single quote, the `Q` variable substitution did not take effect — recheck Step 3 of Task 3.

---

### Task 5: Spike — validate the invisible slicer overlay in isolation

**Files:** Desktop save will touch the Page 1 `visual.json`/`page.json` files, but this task is throwaway validation — nothing here is final layout.

Do this **before** removing any existing Page 1 visuals. The goal is to prove the click-to-filter + transparency + alignment technique actually works in this report before committing the final layout around it.

- [ ] **Step 1: Navigate to Page 1 ("Overview") in Desktop**

- [ ] **Step 2: Temporarily place a test htmlContent visual bound to `HTML - Aging Card Row`**

Drag the "HTML Content" custom visual (already registered — find it in the Visualizations pane, it has a `</>` style icon) onto an empty area of the canvas, e.g. `x=54, y=97, width=1597, height=90` (use the Format pane → General → Properties → Size and position to set exact values). Bind it to `HTML - Aging Card Row`.

- [ ] **Step 3: Add a Slicer visual on top, bound to `Aging`**

Drag a Slicer visual onto the canvas. In the Fields pane, drag `Fact_Parts_Open_Tickets[Aging]` into it. Set its position to the **exact same** values as the htmlContent visual in Step 2 (`x=54, y=97, width=1597, height=90`).

- [ ] **Step 4: Format the slicer as a transparent 6-column tile row**

With the slicer selected, open the Format pane (paint roller icon):
1. **General → Effects**: Background → toggle off (or set Transparency to 100%). Border → toggle off.
2. **Visual → Slicer settings → Options**: Style = `Tile`.
3. **Visual → Slicer settings → Options → Orientation**: `Horizontal`. Set columns/items-per-row so exactly 6 tiles fill one row (with 6 known category values, "Vertical items" or "Columns" = 1 row of 6 should auto-distribute; if there's an explicit column count field, set it to 6).
4. **Visual → Slicer settings → Selection**: Single select = On, Show "Select all" = Off.
5. **Visual → Values**: open the font color picker for the slicer's item text → Custom color → set Transparency to 100% (so the category label text doesn't visually print over the HTML card).
6. **Visual → Header**: toggle off entirely (hides the search/header bar).

- [ ] **Step 5: Bring the slicer to front**

Right-click the slicer → "Bring to front" (or use the Selection pane to confirm its z-order is above the htmlContent visual).

- [ ] **Step 6: Click-test in Desktop reading view (or via Performance Analyzer / Ctrl+click)**

Click each of the 6 invisible tile positions over the corresponding HTML card. Confirm:
- The click registers (check via a temporary visible Card visual showing `SELECTEDVALUE(Fact_Parts_Open_Tickets[Aging])` elsewhere on the canvas, or use the Selection pane / Filters pane to see the active slicer selection)
- The HTML card underneath remains visually unchanged (expected — its measure is hardcoded per bucket)
- Clicking the same tile again clears the selection (single-select toggle-off)

- [ ] **Step 7: If alignment is off**

If a click lands on the wrong tile or a gap between cards doesn't register, adjust the slicer's "Columns" setting or the htmlContent's flex-gap value (in the `HTML - Aging Card Row` measure's `CardCSS` var, currently `gap: 6px` on the wrapping div) until the 6 zones line up. Re-test.

- [ ] **Step 8: Delete the temporary test Card visual (if added) — keep the htmlContent + slicer pair**

These two visuals become the real Aging Card Row + overlay slicer in Task 7 — don't delete them, just remove any throwaway test Card used for step 6.

---

### Task 6: Remove the old Page 1 visuals

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/e384167396533ecc066e/`

- [ ] **Step 1: Select and delete the old HTML dashboard visual**

On Page 1, click the visual bound to `HTML - Parts Overview Dashboard` (the large visual occupying most of the canvas, visual name `d702c61039d5365b597d`). Press Delete.

- [ ] **Step 2: Delete the 2 hidden scaffold visuals**

Open the Selection pane (View ribbon → Selection pane). Two hidden/unused visuals sit underneath the dashboard:
- A `cardVisual` (internal name `b33423b49e53c9cb6022`) referencing the old `KPI SVG - ... (Modern)` measures and per-tier metrics — this was an earlier abandoned attempt at a native card layout
- A `tableEx` (internal name `03dc303b2bf81fc5e96e`)

Select each in the Selection pane and press Delete.

- [ ] **Step 3: Save**

`Ctrl+S`.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/e384167396533ecc066e/"
git commit -m "chore(open-parts-tickets): remove old Page 1 dashboard and unused scaffold visuals"
```

---

### Task 7: Build the final Page 1 layout

**Files:** Desktop save updates `projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/e384167396533ecc066e/`

Final layout coordinates (canvas is 1664×936, `FitToPage`):

| Visual | x | y | width | height |
|---|---|---|---|---|
| Hero (`HTML - Parts Overview Hero`) | 54 | 97 | 1597 | 110 |
| Aging Card Row (`HTML - Aging Card Row`) | 54 | 217 | 1597 | 90 |
| Overlay Slicer (Aging) | 54 | 217 | 1597 | 90 |
| Backorder Pulse (`HTML - Backorder Pulse`) | 54 | 317 | 1597 | 590 |

- [ ] **Step 1: Reposition the Task 5 spike visuals into their final spots**

If the htmlContent + slicer pair from Task 5 used the Aging Card Row position already, leave them at `x=54, y=217, width=1597, height=90`. Re-confirm via Format pane → General → Properties → Size and position.

- [ ] **Step 2: Add the Hero visual**

Drag a new "HTML Content" custom visual onto the canvas. Bind it to `HTML - Parts Overview Hero`. Set position to `x=54, y=97, width=1597, height=110`.

- [ ] **Step 3: Add the Backorder Pulse visual**

Drag a new "HTML Content" custom visual onto the canvas. Bind it to `HTML - Backorder Pulse`. Set position to `x=54, y=317, width=1597, height=590`.

- [ ] **Step 4: Set Edit Interactions for the overlay slicer**

Select the overlay slicer. Go to the Format ribbon tab → **Edit interactions**. Small filter-type icons appear above every other visual on the page:
- Above the Hero visual: click the **Filter** icon
- Above the Backorder Pulse visual: click the **Filter** icon
- Above the Aging Card Row visual: click the **None** icon
- Leave all other page visuals (the existing left-side filter panel slicers, header, nav buttons) at their default — don't touch their interaction icons

Click **Edit interactions** again to exit that mode.

- [ ] **Step 5: Save**

`Ctrl+S`.

- [ ] **Step 6: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.Report/definition/pages/e384167396533ecc066e/"
git commit -m "feat(open-parts-tickets): build Page 1 hero row, aging card row, and Backorder Pulse with click-to-filter"
```

---

### Task 8: Visual and interaction QA

**Files:** No file edits — verification only. Re-run Task 7 Steps 1–6 (reposition/reformat) if any check below fails, then re-save and re-commit.

- [ ] **Step 1: Default state**

With no aging tier selected, confirm:
- Hero shows "TOTALS — All Tiers" and 3 rolled-up numbers
- Backorder Pulse shows "BACKORDER PULSE — All Tiers" and 4 bars reflecting all-tiers totals
- All 6 aging cards show their own tier's order count

- [ ] **Step 2: Click each of the 6 cards individually**

For each tier, confirm Hero's label and 3 numbers change to that tier's values, Pulse's label and 4 bars change to that tier's split, and the aging cards themselves stay visually identical to Step 1.

- [ ] **Step 3: Click a selected card again**

Confirm Hero and Pulse return to the all-tiers rolled-up state from Step 1.

- [ ] **Step 4: Confirm the existing filter panel still works**

Open the existing Show/Hide filter panel (Branch, Aging, Invoice Type, Order Date, Customer, Contact Code slicers). Confirm these still filter the page normally and don't visibly conflict with the new overlay slicer.

- [ ] **Step 5: Confirm other pages are unaffected**

Navigate to Page 3 ("Comparison"), `On Order Details`, and the `Backordered Parts` drillthrough page. Confirm `Hero Card - Parts Open Tickets` (the original, untouched measure) still renders with all 4 metrics on those pages, unchanged from before this work.

- [ ] **Step 6: Zoom check**

At normal report zoom (100%) and at least one other zoom level, confirm the overlay slicer is truly invisible — no border, background tint, or text bleed-through over the HTML cards.

---

### Task 9: Retire the old measures

**Files:**
- Modify: `projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`

Only do this after Task 8 passes — these measures are no longer referenced by any visual once Task 6 removed the old dashboard visual.

- [ ] **Step 1: Confirm no remaining references**

Search the whole `Open Parts Tickets.Report/definition/` folder for each of these strings and confirm zero matches outside of the measure definitions themselves:

```
HTML - Parts Overview Dashboard
_HTML_Bucket1
_HTML_Bucket2
_HTML_Bucket3
_HTML_Bucket4
_HTML_Bucket5
_HTML_Bucket6
```

- [ ] **Step 2: Remove the 7 measures from `_Measures.tmdl`**

Delete the `HTML - Parts Overview Dashboard` measure block (originally at lines 1075–1080) and the `_HTML_Bucket1` through `_HTML_Bucket6` measure blocks (originally at lines 1147–1325). Leave `_HTML_CSS` (line 1143) in place — it's a shared CSS string measure that may still be referenced elsewhere; do not remove it without checking first.

- [ ] **Step 3: Save and reopen in Desktop to confirm no parse errors**

Open `Open Parts Tickets.pbip` in Desktop. Confirm it loads without error and Page 1 still renders correctly.

- [ ] **Step 4: Commit**

```bash
git add "projects/open parts tickets - report/reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl"
git commit -m "chore(open-parts-tickets): retire unused Page 1 dashboard and per-bucket measures"
```

- [ ] **Step 5: Push to origin/dev**

```bash
git push origin dev
```

Reminder: validate in RP-Dev before promoting to RP-Sandbox, then publish to the production Parts Reports workspace per the standard deployment workflow.

---

## Self-Review Notes

- **Spec coverage:** Hero row (Task 1, 7), Aging card row (Task 2, 7), Backorder Pulse (Task 3, 7), invisible slicer overlay + Edit Interactions scoping (Task 5, 7), cleanup of old dashboard + scaffold visuals (Task 6, 9) — all spec sections have a corresponding task.
- **Quote-collision fix:** corrected the spec's incorrect assumption that the SVG measures return raw markup — Task 3 uses `CHAR(34)` to avoid the single-quote collision between the wrapper `<img>` tag and the SVG's internal attribute quoting.
- **Type/measure name consistency:** verified `[Order Total]`, `[# Parts On Order]`, `[Line Count]`, `[Total # of Orders]`, and the 4 `KPI SVG - ... (Modern)` measure names against the actual `_Measures.tmdl` content (not the possibly-stale `DAX-MEASURES-REFERENCE.md` doc) before using them in Tasks 1–3.
