# Shannon — Parts Ordering Filter Tool — Claude Context

## Project Overview
- **Business purpose:** A simple, filterable Power BI report Shannon uses for parts ordering. She sets filters and exports the resulting list — it's a filter-and-export tool, not an analytical report with visuals/measures.
- **Primary user:** Shannon (Parts)
- **Report name:** "After Market - Parts Orders" (displayed report title), file name "Aftermarket - Parts Orders" — the earlier "Afermarket" (missing "t") filename typo was corrected 2026-09-03. Saved as a PBIP project at `projects/shannon-report/report/Aftermarket - Parts Orders.Report/` + `.SemanticModel/`.
- **Format:** Power BI report — direct ODBC query against the source system, **not** built on the shared Lakehouse/dataflow pipeline described in the root `CLAUDE.md`
- **Connection:** ODBC — `dsn=EquipRDB64` (queries `jdis_Part_Information` and `InMaster` directly)
- **Refresh:** Its own independent schedule, separate from the main Fabric pipeline and from every other report in this repo
- **Status (2026-09-03):** Query, calculated columns, and report layout built. Sent to Shannon for review/feedback — awaiting her response before further layout changes.

## Data Source
| Table | Role |
|-------|------|
| `jdis_Part_Information` | Parts master — description, cost, inventory, sales history, all the fields Shannon filters/orders from |
| `InMaster` | Supplies `user_field_2` (`UserField2`) via `LEFT JOIN` on `Branch` + `Part_No`, so parts without an `InMaster` match still appear (with `UserField2` blank) |

**Grain:** One row per part per branch, **scoped** to the population Shannon actually orders for (not the full ~1.1M-row table). The query's WHERE clause excludes:
- Franchises: `BW`, `C`, `DA`, `HW`, `ZP`, `S`, `TD`, `TM`, `UD`, `UM`, `W`, `D` (per Shannon — franchise `D` alone is ~700-800k of the ~1.1M total)
- Branches: `5`, `12`, `97`

**Confirmed row count: 202,262 rows** (tested live in a Shannon-only Fabric workspace, 2026-09-02 — matches the ~200k estimate). Semantic model refresh completed in **33 seconds** end-to-end (3:56:19 PM–3:56:52 PM). (Earlier versions of this query also filtered to only parts with `UserField2` populated; that row filter was removed separately so Shannon sees every part in-scope, whether or not `UserField2` is set.)

## Output Columns (M / Power Query layer)
`UserField2`, `Branch`, `Franchise`, `Part_No`, `Description`, `Vendor_Code`, `Bin`, `Dealer_Group_Code`, `Bin_Qty`, `On_Order`, `Cost`, `In_Transit_Qty`, `Pending_Qty`, `Inventory_Cost`, plus sales history: `current_mo_sales`, `sales_history_02`...`sales_history_60`. (The `current_mo_requests`/`sales_request_02..60` column family was dropped 2026-09-02 — Shannon confirmed she doesn't need it.)

**On-hand/back-order gap — RESOLVED 2026-09-03:** `On_Hand_Qty`, `Back_Ord_Qty`, `Committed_Qty` are **not** being added. Shannon's workflow uses `Bin_Qty` for on-hand purposes — it's relabeled `O/H` in the report visual (see "Display renames" below). No new source columns needed.

## Semantic Model Structure (live in Power BI Desktop)
Connect via `pbi connect -d localhost:<port> -n "PBIDesktop-Aftermarket - Parts Orders-<port>"` (auto-detect via plain `pbi connect` also works when only this file is open). Note: this connection name will show the corrected spelling only after Desktop is reopened with the renamed file — the "Afermarket" typo seen during 2026-09-02/03 development was a filename issue, now fixed.

**Tables:**
| Table | Columns | Role |
|---|---|---|
| `After_Market_Parts_Orders` | 85 (74 from the M query + 11 calculated) | The main fact table — one row per part/branch, scoped per above |
| `dim_BranchLocation` | 16 | Shared branch dimension, same table used across other reports in this repo |
| `_Measures` | 1 (placeholder) | Empty measures table — no measures built yet, only calculated columns so far |
| `Data Refresh` | 3 | Standard repo pattern — DST-aware UTC→Central refresh timestamp (see root `.claude/queries/DATA-REFRESH-TEMPLATE.pq`) |

**Relationship:** `After_Market_Parts_Orders[Branch]` → `dim_BranchLocation[BranchID]`, many-to-one, single direction, auto-detected.

**Report filter bar (confirmed, closes the "several other categories" open item):** Branch, Franchise, Vendor Code, DGC (`Dealer_Group_Code`), User Field 2, and a Part # text-search box.

**Display renames (visual-level only, NOT model-level):**
- `Bin_Qty` is displayed as **`O/H`** in the table visual
- `Inventory_Cost` is displayed as **`Inv Total`** in the table visual

These are field-display-name renames scoped to that one visual — the underlying model columns are still literally named `Bin_Qty` and `Inventory_Cost` (confirmed via `pbi column list`, 2026-09-03). **Important:** any DAX written against this table must reference `[Bin_Qty]`/`[Inventory_Cost]`, not `[O/H]`/`[Inv Total]` — those display names don't exist as model objects. A new visual added later will show the raw names again unless the same per-visual rename is applied there too.

## Calculated Columns (DAX, added 2026-09-02/03 via live `pbi column create` against the open Desktop session)
All 11 are calculated columns (not measures) on `After_Market_Parts_Orders` — appropriate since this is a flat per-row export table, not an interactive pivot. They reference only already-loaded M-layer columns, so they required no refresh to populate.

| Column | DAX Expression | Format |
|---|---|---|
| `R6mS` | `[current_mo_sales] + [sales_history_02] + [sales_history_03] + [sales_history_04] + [sales_history_05] + [sales_history_06]` | `#,##0` |
| `R12S` | Same pattern, extended through `[sales_history_12]` | `#,##0` |
| `R24S` | `[sales_history_13] + ... + [sales_history_24]` — **not** cumulative with R12S; this is the *next* 12-month bucket (13-24 months back), i.e. "last year," not a rolling-24 total | `#,##0` |
| `R36S` | `[sales_history_25] + ... + [sales_history_36]` — third 12-month bucket ("two years ago") | `#,##0` |
| `R6m $` | `[R6mS] * [Cost]` | `$#,##0` |
| `R12 $` | `[R12S] * [Cost]` | `$#,##0` |
| `R24 $` | `[R24S] * [Cost]` | `$#,##0` |
| `R36 $` | `[R36S] * [Cost]` | `$#,##0` |
| `To Order` | `BLANK()` | `#,##0` |
| `To Do` | `BLANK()` | `#,##0` |
| `Order $` | `BLANK()` | `$#,##0` |

`To Order`, `To Do`, `Order $` are intentionally blank — Shannon fills these in manually in Excel after exporting; they exist only to hold the column position/header in the export. Report visual gives them a distinct orange fill so they read as "your input goes here," separate from the calculated data.

**Verification (2026-09-02/03):** Spot-checked against real rows via the live connection — e.g. part `DEF`: `current_mo_sales`(0) + `sales_history_02..06` (1713.5+1065+1125+2589+2436) = **8928.5**, matches `R6mS` exactly; `R6m $` = 8928.5 × 1.63 cost = **14553.455**, matches exactly. Also confirmed visually in the report screenshot: part `20348`, Cost $58.88 × R24S 2 = **$117.76**, × R36S 1 = **$58.88** — both correct.

**Known tooling bug hit during verification:** `pbi dax execute` from the CLI silently drops row data (returns `{"success": true}` with no rows) — a real bug in `pbi-cli`'s response parser (documented separately in memory: `feedback_powerbi_mcp_dax_execute_blocked.md`). Workaround: a direct MCP client script reading `block.resource.text` instead of `block.text`. Doesn't affect column creation itself, only ad-hoc query verification via the CLI.

## Report Usability Notes (suggested 2026-09-03, not yet all applied — pending Shannon's feedback)
- Table visual's Total row currently sums `Cost` (a per-unit price) across rows, which isn't a meaningful number — suggested turning off the per-column Total for `Cost` specifically, keeping it only on true extended-value columns.
- Suggested default sort by `R12S` descending so Shannon's fastest-moving parts surface first.
- Suggested a short instructional text box near the blank input columns, since Power BI table visuals aren't editable and someone could reasonably try to type into `To Order`/`To Do` directly in the report.
- Suggested checking whether the `O/H` (`Bin_Qty`) = 0 highlight is real conditional formatting or a static column color — if static, real conditional formatting (flag true stockouts) would be more useful.
- Filter selections don't persist between Desktop sessions by default — a bookmark for Shannon's "usual" filter set was suggested as a possible convenience, not yet built.

## Refresh — REVISED 2026-09-02/03
Original concern (see git history for the superseded two-tier design) was that hourly refresh during business hours would meaningfully add to Fabric CU cost, since the *shared* `jdis_Part_Information` raw table is already the capacity's #3 CU consumer at 3×/day. **That concern doesn't apply here** — this report's query doesn't touch that shared table or pipeline at all; it's an independent, already-scoped (202k row) direct ODBC query, and the real-world refresh test came back at 33 seconds.

**Current direction: schedule the semantic model to refresh hourly, 8 AM–5 PM, directly** (no two-tier split needed) — Fabric-capacity workspaces support up to 48 scheduled refreshes/day, so ~10/day is well within range. Two things to sanity-check once it's actually running on schedule (not blockers, just verification):
1. **Real CU cost** via the Fabric Capacity Metrics app after a few days of hourly runs — 33 seconds of wall-clock time doesn't guarantee trivial CU draw.
2. **Live ERP contention** — this still hits the transactional source directly during business hours; watch for any reported slowness from Shannon or other Equip users in the first few days.

- **Open item:** exactly how this gets refreshed/published on the hourly schedule — a Fabric/PBI Service workspace behind a gateway, vs. a local Desktop file Shannon refreshes herself — isn't decided yet.
- **Resolved 2026-09-03:** the report was saved from Desktop as a PBIP project directly into `projects/shannon-report/report/` (`Aftermarket - Parts Orders.Report/` + `.SemanticModel/`), which writes TMDL automatically — the calculated columns, table, and relationship documented above are all captured on disk and version-controlled as of this commit, not just live in Desktop.

## Performance Notes (query/M layer, 2026-09-02)
- SQL `SELECT` lists needed columns explicitly (aliased to final names) instead of `pi.*` — cuts what ODBC transfers instead of pulling all ~230 `jdis_Part_Information` columns and trimming in Power Query.
- `ORDER BY` removed — sorting rows at the source before transfer bought nothing for an Import-mode model; report visuals handle sort.
- No M-side rename/reorder/select steps — the SQL does all of that, so `Source` is the finished table.
- **Unverified assumption:** every `jdis_Part_Information` column follows the `pi_` prefix convention. Confirmed directly for most fields against `.claude/queries/raw-tables/jdis_Part_Information.pq` (the canonical raw-table definition, which only documents 30 of the table's ~230+ columns); the rest — `In_Transit_Qty`, `current_mo_sales`, and the `sales_history_XX` series — were inferred by the same pattern but not directly confirmed. The 202,262-row live refresh succeeding is decent indirect evidence these are all correct, since a wrong column name would have errored the whole query.

## Query Library
Query lives in `queries/UserField2_ByPart.pq` in this project folder. Originally an ad-hoc file at `.claude/queries/adhoc/UserField2_ByPart.pq` (still there, untouched) — this copy has since diverged substantially (row filter removed, join switched to LEFT, column list narrowed and pushed into SQL, franchise/branch scope added, sales_request family dropped). **Note:** the `.pq` file only reflects the M/Power Query layer — the 11 calculated columns documented above live in the semantic model (DAX/TOM), not in this file, and won't show up if you only read the `.pq`.

## Open Items
- Confirm the hourly refresh mechanism (Service+gateway vs. local Desktop) and get it actually scheduled.
- After scheduling, verify real CU cost and check for ERP contention (see "Refresh" above).
- Await Shannon's feedback on the report as sent 2026-09-03; apply the usability suggestions above as she confirms which matter to her.
- Verify the unconfirmed `pi_` column-name assumptions with certainty (currently only indirectly confirmed by the query running successfully).
- Consider whether `projects/shannon-report/` should be renamed to match the `{name} - report/` convention used elsewhere in the repo, and/or fixing the "Afermarket" typo in the Desktop file name, once the report is finalized.
