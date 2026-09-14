# LH_Master_Data Facts Catalog (2026-09-14)

Full audit of every fact dataflow in `LH_Master_Data / Dataflows / 04 - Facts`, cross-checked
against real live production report workspaces (`fab ls` on `RP - Parts Reports`,
`RP - Service Reports`, `RP - Financial Reports`), and against what's already migrated on the
DP backend (all Silver raw sources, all dims — see
`docs/architecture/lh-master-data-dimensions-catalog.md`, now complete). Same methodology as
the dimensions catalog: real ground truth over any stale local doc.

**Supersedes** `.claude/queries/facts/FACT-TABLES-SUMMARY.md` as the authoritative inventory —
that doc (last updated Aug 27) undercounted real production scope significantly: it listed
"24 fact tables" but production actually has **45 fact dataflows**, missing `Customer Anatomy`'s
9 entirely, `MD Invoices`' 2, `Service Time Sheets`' 2, `Top 50 Job Codes`, `Stock Check`,
`Planter Inspection Part Sales`, and `Transfers`. `FACT-TABLES-SUMMARY.md` is still useful for
its refresh-time/row-count history and its documentation-status tracking per project — not
superseded on those points, just on "what exists."

**Correction (2026-09-14, same day):** this catalog's own first pass missed
`Fact_PartsNotReordered` (source dataflow `df_Fact_PartSales_24Hours`, folder `Part Sales - 24
Hours`) — confirmed live production (`Parts Not Re-Ordered 24 Hours` report, `RP - Parts
Reports`, twice-daily scheduled per the old summary doc). Added below. A real reminder that
even a "full ground-truth audit" benefits from a second pass — this was caught while grepping
every in-scope dataflow for `DateTime.LocalNow()` (a known recurring bug pattern), not by the
audit's own methodology.

## Methodology

1. `find` on `04 - Facts/*/` for every `.Dataflow` folder — 58 dataflows total.
2. Excluded `Archive - Fact Tables/` (14 dataflows) entirely — confirmed genuinely archived
   (superseded experiments: `Fact_Part_Transactions` superseded by the top-level
   `df_FactPartTransactions_Incremental`; the "Test Queries - Inspection Report" subfolder
   holds 8 earlier design iterations of what's now `Fact_LaborJobSummary`/`Fact_WorkOrderParts`
   in the live `Inspection Report Queries` folder).
3. Excluded `Parts Availability App` and `Parts Ordering Tool` (3 dataflows) — separate systems,
   not part of the LH_Master_Data→DP report migration: Parts Availability is the already-live,
   already-shipped Fabric App (see `project_parts_lookup_tool.md`); Parts Ordering Tool is the
   paused Non-JD tool (see `project_nonjd_parts_order_tool_paused.md`).
4. Read every remaining dataflow's real header comment + enough of its body to identify real
   source tables, real dims used, and real complexity — same header-first depth as the dims
   audit's "full dimension matrix" pass. Full line-by-line logic reads are deferred to whichever
   batch actually builds each fact (same as dims).
5. Cross-checked live report existence via `fab ls` against `RP - Parts Reports` (17 reports),
   `RP - Service Reports` (7 reports), `RP - Financial Reports` (1 report) — 25 live production
   reports total, confirming which fact-owning "projects" are real vs. sandbox-only or
   not-yet-promoted.

**Real total in scope: 42 fact dataflows** (45 minus `Fact_PartsPromo`/`Fact_PartsAdjustments`,
already built on the DP backend, listed separately below) across 21 live report projects, plus
3 dataflows flagged as out-of-scope-for-now (see "Explicitly excluded" below).

## Already built on the DP backend

| Fact | Report | Location | Notes |
|---|---|---|---|
| `Fact_PartsPromo` | Parts Promo | `DP_Presentation` | **Re-audited 2026-09-14 (Batch A) — clean.** No correctness bugs found. |
| `Fact_InTrans_AllPromo` | (supporting `Fact_PartsPromo`) | `DP_Presentation` | **Re-audited 2026-09-14 (Batch A).** One misleading header comment fixed (it's NOT scoped to promo-active orders — confirmed against the real original production `.pq`, which has no such filter at all: every InTrans transaction since 2023-01-01, related via many-to-many `REF_NO` for "% of total" DAX context measures). One real improvement found and documented: `Qty` is now safely included where production explicitly excluded it (text-value data-quality problem in the old ODBC path, confirmed via DuckDB that `Silver_InTrans.Qty` is a clean `DECIMAL(8,2)` now). |
| `Fact_PartsAdjustments` | Parts Adjustments | `DP_Presentation` | **Re-audited 2026-09-14 (Batch A) — already clean.** Turns out this one had already been through a real bug-hunt before this session: a genuine `DocRef`-reuse misclassification (same bug class as `InTrans.TransId`'s own reuse problem) and a `DateTime.LocalNow()` UTC bug were both found and fixed on 2026-09-09. Independently re-verified this session: `GlTrans.DEPT`/`ACCT`/`SUB_ACCT` cast-and-filter chain doesn't silently drop real rows (confirmed via DuckDB — no non-numeric `DEPT` values near "30"). No new issues found. Its sibling `Fact_AdjustmentPairs` (self-referencing match logic) is still NOT yet built — now safe to build against, since this fact is confirmed correct. |

## Explicitly excluded from this phase

| Dataflow(s) | Reason |
|---|---|
| `Fact_PriceUpdate_Enriched` (JD Price Updates) | Report not in any live `RP -*` workspace — still exploratory/early per `project_jd_price_updates_dax_report_build.md`. Its own raw source (`Raw_PriceUpdate_History`) isn't migrated to Silver either. Revisit once the report itself is promoted. |
| `Fact_Top_JobCode_Anaysis` (Top 50 Job Codes) | Confirmed sandbox-only, zero git tracking, per `project_dimensions_catalog_audit.md`'s earlier finding — not live production. |
| `Fact_ServiceTimeSheet_Audit`, `AuditLog` (Service Time Sheets) | Not a Power BI report — an Excel/SharePoint-based audit tool (`projects/service time sheets/`) with its own separate "Phase 1" raw ingestion and pipeline. Different workstream; flag for a separate conversation rather than folding into this batch plan silently. |

## Known recurring bug to check for in every remaining dataflow: `DateTime.LocalNow()`

`DateTime.LocalNow()` returns UTC in the Fabric service, not actual local time — a
confirmed-recurring pattern across this whole backend, not a one-off. **6 real instances
found and fixed so far**: the original Data Refresh Table bug (fixed 2026-02-27),
`Fact_PartsAdjustments.LoadedDatetime` (fixed 2026-09-09, before this catalog existed),
`Fact_NegativeOnHand.DaysSinceLastRequest` + `Fact_InSalOrd_InSalPar.Days_Open`/`Aging`
(Batch A), and `Fact_JobCodePartFrequency`(+`_Branch`)'s 3-year cutoff +
`Fact_Invoice_InventoryAnalysis`'s `RangeEnd` + `Fact_PartsNotReordered`'s 7-day window
(all 3 Batch B). Grepped every in-scope dataflow for it up front — these still have a
live instance to check when their batch comes up (don't assume it needs fixing, some
uses may be harmless logging timestamps like the `Fact_PartsAdjustments` one was, but
check each one against what the value actually feeds):

`Fact_Branch12_Transactions`, `Fact_WorkOrderParts`, `Fact_AdjustmentPairs`.

## Full fact-dataflow matrix (42 in scope)

Grouped by report project, with real source tables (bronze table names, not yet re-verified
against Silver column names — that happens per-batch same as every dim did), dims needed (all
already built unless noted), and a rough complexity call.

### Already-simple, single-source, small (candidates for an easy first batch)

| Fact | Report | Source(s) | Dims needed | Complexity notes |
|---|---|---|---|---|
| `Fact_NegativeOnHand_OnHandNoBin` | Negative On Hand-On Hand No Bin | `jdis_Part_Information` | `dim_BranchLocation`, `dim_DateTable` | Simple flag/filter logic, no joins. |
| `Fact_InSalOrd_InSalPar` | 60+ Days Past Due | `Insalord`, `insalpar` | `dim_BranchLocation`, `dim_DateTable`, `dim_CustomerList` | Simple type-normalize + join, small (1,386 rows historically). |
| `Fact_OpenOrderParts` | Job Code Parts Advisor (Recommendations) | `insalpar`, `Insalord` | none directly | Small, 2-table join, `OrderType='W'` filter. |
| `Fact_OpenOrders` | Job Code Parts Advisor (Recommendations) | `WKROFILE`, `wkothsub` | `dim_CustomerList` (via CustomerNumber) | Small, `IsClosed='N'` filter, hundreds-low-thousands rows. |

### Medium — real joins/logic but self-contained, no known perf landmines

| Fact | Report | Source(s) | Dims needed | Complexity notes |
|---|---|---|---|---|
| `Fact_JobCodePartFrequency` | Job Code Parts Advisor | `wkothsub`, `InTrans_Incremental` | none directly | ⚠️ Real documented join gotcha: `wkothsub.InvoiceNumber = InTrans.RONumber` (RONumber in InTrans is the invoice number, NOT the work order number — joining wrong produces ~1% of correct rows). 3-year rolling window. |
| `Fact_JobCodePartFrequency_Branch` | Job Code Parts Advisor | same + Branch | none directly | Branch-level version of the above, same join gotcha applies. |
| `Fact_InternalWorkOrders` | Stock Check | `wkrodesc`, `WKROFILE`, `wkothsub`, `wkmechwk`, `VhStock`, `WkVehFl` | none directly | 6-table join, `JobType='I'` filter, `CreatedOn >= 2026-01-01` scope. |
| `Fact_PendingInspections` | Inspections | `RepairOrderDetail`, `TechnicianPunchedDetail` | none directly | Small, work-order-level grain (not job-level). |
| `Fact_LaborJobSummary` | Inspections | `wkothsub`, `wkmechwk`, `WKROFILE` | none directly | Core Inspections fact, 3-source join + hours aggregation, ~350K rows historically. |
| `Fact_ServiceRecommendations` | Inspections | `Fact_LaborJobSummary`, `Fact_PendingInspections` (both self-built, sequencing dependency) | none directly | Must build AFTER those two. Was moved off a DAX calculated table for CU cost reasons (2026-08-13) — validated row-for-row against the old DAX output before cutover; preserve that same validation discipline here. |
| `Fact_PlanterInspectionParts` | Planter Inspection Part Sales | `wkothsub`, `InTrans_Incremental` | `dim_DateTable` | Same invoice-not-workorder join pattern as `Fact_WorkOrderParts`. |
| `Fact_Invoice_UniqueCustomers`, `Fact_InTrans_UniqueCustomers` | Unique Parts Customers | `Invoice` / `InTrans`, `ArMaster_Customer` | `dim_UniqueCustomers`, `dim_BranchLocation`, `dim_DateTable` | Dual-fact architecture (2 sources feeding the same customer dim), hardcoded customer-identification lists — read `dim_UniqueCustomers`'s own build for the current real list before porting. |
| `Fact_Invoice_InventoryAnalysis` | Inventory Analysis | `Invoice` | `dim_ModuleType`, `dim_PaymentMethod`, `dim_BranchLocation`, `dim_CustomerList` | Straightforward invoice-level filter/select, ~469K rows historically. |
| `Fact_MDInvoices_Closed`, `Fact_MDInvoices_NoFreight` | MD Invoices With No Freight | `InSalPar_Audit`, `InTrans_Incremental`, `jdis_Part_Information` (direct SQL Analytics Endpoint queries, not standard Lakehouse dataflow reads) | `dim_BranchLocation`, `dim_Franchise`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts` | Real documented business logic (freight-as-line-item pattern, `PurOrderType='E'`) already reasoned through by a past investigation — read that reasoning before rebuilding, don't re-derive from scratch. |
| `Fact_Transfers` | Transfers | `InTrans_Incremental` | `dim_DateTable`, `dim_BranchLocation`, `dim_Parts` | 🚧 Already in development per the (superseded but still useful) old summary doc — check current state before starting fresh. Real documented Branch-12-exclusion and transfer-subtype-classification logic. |
| `Fact_PartsNotReordered` (source dataflow `df_Fact_PartSales_24Hours`) | Parts Not Re-Ordered 24 Hours | `InTrans_Incremental`, `jdis_Part_Information` | `dim_BranchLocation`, `dim_DateTable` | **Missed in this catalog's first pass — added on re-check.** 7-day rolling window, `Franchise='D'` only, real documented dedup logic on both source queries. Twice-daily scheduled in production per the old summary doc (~7,965 rows) — the only twice-daily fact in the whole catalog, worth preserving that cadence rather than defaulting to daily. Uses `DateTime.LocalNow()` — check for the same UTC bug already found 3x this project before porting. |

### Large / needs real design attention (known perf landmines or big scale)

| Fact | Report | Source(s) | Dims needed | Complexity notes |
|---|---|---|---|---|
| `Fact_WorkOrderParts` | Inspections | `wkothsub`, `InTrans_Incremental` | none directly | **The known 18-19 minute refresh** — longest fact in the whole old system, flagged as the #1 optimization priority in the old summary doc. This is exactly the kind of large-scale operation Spark should handle far better than Power Query M (same category of win as `dim_Parts`'s majority-vote fix) — but confirm the real bottleneck (row count vs. join shape vs. something else) before assuming a straight port fixes it. |
| `Fact_Inventory` | Inventory Analysis + Price Matrix (shared) | `jdis_Part_Information` | `dim_BranchLocation`, `dim_Parts`, `dim_Franchise`, `dim_VendorCode`, `dim_Source`, `dim_SLC`, `dim_DealerGroupCode`, `dim_CommodityCode` | Real per-branch grain (confirmed this session during the `dim_Parts.VendorCode` investigation) — this is where `VendorCode` is correctly captured at the branch level; preserve that exact pattern (read `VendorCode` directly from `Silver_PartInformation` at its native grain, not from `dim_Parts`). ~138K rows historically, ~6 min old refresh. |
| `df_FactPartTransactions_Incremental` | Inventory Analysis + Price Matrix (shared) | `InTrans_Incremental` | `dim_Parts`, `dim_Franchise`, `dim_BranchLocation` | **Redesigned, not ported (2026-09-14, confirmed with Brian)** — real usage audit found only ~10 of 40+ columns are ever used by either real report; rebuilt lean, dropped the matrix-pricing block and customer join entirely, full overwrite instead of watermark incremental. See the dedicated write-up below. |
| `Fact_AdjustmentPairs` | Parts Adjustments | `Fact_PartsAdjustments` (self-referencing) | none directly | Matches negative adjustments to positive ones within 12/24-month windows — real matching logic. `Fact_PartsAdjustments` itself is now re-audited/confirmed correct (Batch A), so this is safe to build against. |
| `Fact_Parts_Open_Tickets`, `Fact_Parts_Open_Tickets_Details` | Open Parts Tickets | `vw_Fact_Parts_Open_Tickets`, `vw_Fact_Parts_Open_Tickets_Details` (SQL views via the SQL Analytics Endpoint — **origin not yet identified**, old doc says "raw tables not specified") | `dim_BranchLocation`, `dim_DateTable` | Needs investigation before scoping — these read pre-built SQL views, not a Lakehouse table; find what builds those views before deciding how to port. |

### Flagship — Customer Anatomy (9 dataflows, biggest single undertaking)

All raw dependencies are already migrated to Silver (`Invoice`, `InTrans`, `wkothsub`,
`WkInvReg`, `WKROFILE`, `VhStock`, `VhTrans` all confirmed present) — complexity here is business
logic depth, not missing infrastructure. Real 3-level drill-through architecture:

| Fact | Level | Source(s) | Notes |
|---|---|---|---|
| `CustomerLookup` | Bridge | `dim_CustomerList` | Denormalized 3-key (AccountNumber/CustomerNumber/ContactID) matching bridge — avoids every downstream fact doing 2-3 joins. Build this first, everything else in this group depends on it. |
| `dim_EngagedAcres` | Support | CSV (SharePoint-sourced file in Lakehouse Files) | Small reference table, unrelated to invoices. |
| `Fact_CustomerPerformance` | Level 1 | Aggregates Level 2 facts below | Must build AFTER the 3 Level-2 facts it aggregates. |
| `Fact_Parts_Invoices` | Level 2 | `Invoice` (`ModuleType='I'`) | |
| `Fact_Service_Invoices` | Level 2 | `Invoice` (`ModuleType='W'`) | Real `CustomerVehicleFlag`-based Stock/Unknown assignment logic (`CustomerKey=-9`/`-1`) — same special-key pattern as `dim_CustomerList`. Already reduced Unknown-Customer revenue from ~$19M to ~$2.3M in production; preserve that logic exactly, don't re-derive. |
| `Fact_Equipment_Sales` | Level 2 | `VhStock` | |
| `Fact_Parts_Details` | Level 3 | `InTrans` (pre-filtered "PartsCounter" variant — confirm this filtered raw table's real Silver equivalent before building) | |
| `Fact_Service_Detail` | Level 3 | `wkothsub` + `WkInvReg` (fallback) | Same `CustomerVehicleFlag` logic as `Fact_Service_Invoices`. |
| `Fact_Service_Parts_Detail` | Level 3 | `InTrans_Incremental` | |

## Deferred, blocked, or otherwise not startable yet

| Fact | Blocked on |
|---|---|
| `Fact_Branch12_Transactions` (Combine Vault Sales) | `dim_Branch12_Parts` — already deliberately deferred in the dimensions catalog, blocked on `Fact_Branch12_Transactions` itself not existing yet (circular in the old catalog's own framing; needs a decision on which comes first, or whether `dim_Branch12_Parts` can build off `Silver_PartInformation` directly without the fact). |

## Implementation plan (confirmed 2026-09-14)

Mirrors the dims A→D structure. Confirmed with Brian via `AskUserQuestion` as proposed:

**Batch A — re-audit + 4 easy facts — COMPLETE, built and verified 2026-09-14:**
- Re-audit `Fact_PartsPromo` and `Fact_PartsAdjustments` — **done**, see "Already built on
  the DP backend" above for results (both clean; one misleading comment fixed on
  `Fact_InTrans_AllPromo`).
- Built: `Build_Gold_NegativeOnHand`, `Build_Gold_InSalOrdInSalPar`, `Build_Gold_OpenOrderParts`,
  `Build_Gold_OpenOrders` (all in `DP_Presentation/Fact Tables/`). **2 real bugs found and
  fixed**, both the same `DateTime.LocalNow()`-returns-UTC class already hit twice this
  project: `Fact_NegativeOnHand`'s `DaysSinceLastRequest` and — the most consequential
  instance yet — `Fact_InSalOrd_InSalPar`'s `Days_Open`/`Aging`, since aging-bucket
  classification is the entire point of the 60+ Days Past Due report. Both fixed via
  explicit UTC-to-Central conversion. `Fact_OpenOrderParts`/`Fact_OpenOrders` are faithful
  ports, no bugs found.
- **Verified 2026-09-14** via `.claude/queries/adhoc/dp-bronze-verify/verify_batch_a_facts.py`:
  all 4 column contracts match exactly. Row counts (2,015 / 2,308 / 10,740 / 2,831) run
  higher than the old summary doc's historical snapshot (~1,398 / ~1,386) — expected, not a
  defect: these are dynamic operational tables (open bin issues, open orders) that grow
  daily, and that doc was already months stale. The invariants that actually matter both
  passed clean: 0 "No Issue" rows leaked through `Fact_NegativeOnHand`'s filter, 0 duplicate
  `FileNumber`s in `Fact_InSalOrd_InSalPar` (confirms the order-level aggregation correctly
  collapsed to one row per order).

**Batch B — built 2026-09-14, not yet run.** Turned out to be 17 real Gold tables once
built (not ~12) — 3 dataflows had extra real outputs found only by reading their full
body, not just headers (Planter Inspection Part Sales: 4 tables in 1; MD Invoices
NoFreight: a 3rd table, `FreightCalculator`, deliberately skipped — not yet a live
dependency; Transfers: a 2nd table, `Fact_OutstandingTransfers`, deliberately deferred —
see below).

Built: `Fact_JobCodePartFrequency`(+`_Branch`), `Fact_InternalWorkOrders`,
`Fact_PendingInspections`, `Fact_LaborJobSummary`, `Fact_ServiceRecommendations` (after
the 2 Inspections facts above), `Fact_PlanterInspectionParts`+`Fact_PlanterInspections`+
`Fact_PlanterPartSales`+`Fact_PlanterInvoiceAllParts` (all 4 from one dataflow),
`Fact_Invoice_UniqueCustomers`+`Fact_InTrans_UniqueCustomers`, `Fact_Invoice_InventoryAnalysis`,
`Fact_PartsNotReordered` (added on re-check — see the correction note above),
`Fact_MDInvoices_Closed`+`Fact_MDInvoices_NoFreight`, `Fact_Transfers`.

**Real bugs found and fixed this batch** (beyond faithful porting):
- **3 more `DateTime.LocalNow()` UTC bugs** (now 6 confirmed instances across this whole
  project): the 2 `Fact_JobCodePartFrequency` dataflows' 3-year rolling cutoff,
  `Fact_Invoice_InventoryAnalysis`'s `RangeEnd`, `Fact_PartsNotReordered`'s 7-day window
  (the most consequential of these three — a much smaller window, and the only
  twice-daily-scheduled fact in the whole catalog).
- **`Fact_InternalWorkOrders` real grain gap**: `Silver_WkRoDesc` deliberately doesn't
  pre-filter to `LineNumber=1` (a real, documented, deferred decision from its own build)
  — this fact is the first real consumer that needs that filter, and without it would
  have silently included ~26% extra rows (the unexplained `1000001`/`1000002`
  `LineNumber` pattern). Fixed by adding the filter explicitly.
- **`Fact_LaborJobSummary.IsPending` confirmed permanently broken in real production
  itself** (not a new regression): checks lowercase `"wip"/"bi"/"va"` against real
  uppercase 2-letter `ProgressStatus` codes — 0 real rows have ever matched. Discussed
  with Brian: ported faithfully (matches real current behavior) given this feeds one of
  the most-used reports in the portfolio, clearly flagged as needing a real business
  definition before anything depending on `IsPending` specifically is trusted.
- **`Fact_Invoice_InventoryAnalysis` real data-completeness bug**: `ModuleTypeKey`
  assignment claimed to be "IDENTICAL to `dim_ModuleType`" but used an incomplete
  fallback (`null`, then filtered out entirely) instead of `dim_ModuleType`'s own real
  `.otherwise(99)` for its documented 12th-row edge case — real invoice dollars were
  silently missing from every Inventory Analysis visual. Fixed by using the exact same
  complete mapping as the dimension.

**Deliberately deferred, not silently dropped:**
- `FreightCalculator` (from the MD Invoices NoFreight dataflow) — its own header says
  the one calculation that would consume it is "DEFERRED pending stakeholder input," so
  it isn't a live dependency yet. Needs a CSV upload to this backend's Files section if
  ever picked up.
- `Fact_OutstandingTransfers` (from the Transfers dataflow, Page 3) — its real source,
  the `Parts_InterbranchTransfers` VIEW, was already fully resolved earlier this project
  with **no live ODBC needed** (`Silver_InSalPar`+`Silver_InSalOrd`+`Silver_InMaster`
  cover it), but needs (1) a new `Silver_InSalOrd` column (`trf_to_branch`, for
  `RequestingBranch`) and (2) a real design decision already flagged in that
  investigation: its `OrderAge` column is computed relative to query time and must
  become a DAX measure, not a frozen ETL column. A well-defined next step, not scoped
  into this batch.

Needs 4 new shortcuts in `DP_Presentation` before this batch can run: `RepairOrderDetail`,
`Silver_WkMechWk`, `Silver_VhStock`, and `InSalPar_Audit` (this last one was a real
documentation gap on my part — `Build_Gold_MDInvoicesClosed.Notebook` reads it directly
but I never called out that it needed a new shortcut like the other 3; Brian had to add
it manually on first run without being told to. Now documented here and in the
notebook's own header). Verification script:
`.claude/queries/adhoc/dp-bronze-verify/verify_batch_b_facts.py`.

**Batch B fully verified complete (2026-09-14).** All 17 tables ran successfully after
the 2 fixes below; `verify_batch_b_facts.py` confirms all 17 column contracts match
exactly. 2 row-count anomalies flagged by the script were investigated independently
against source data and confirmed NOT bugs:
- `Fact_Invoice_InventoryAnalysis` (562,669 rows vs. the doc's "~300-350K"): an
  independent DuckDB recount of `Silver_Invoice` under the exact same filter produced
  562,669 exactly — the doc estimate was simply stale (same pattern as Batch A's row
  counts running higher than its own stale doc). `ModuleTypeKey=99` correctly shows 0
  rows: verified directly that 0 real invoices in the 2023+ window have an
  Internal/Warranty customer with `ModuleType='S'` — the fix (matching `dim_ModuleType`'s
  real `.otherwise(99)`) is still correct, that edge case just isn't populated in current
  data.
- `Fact_InternalWorkOrders` (4,257 rows vs. the doc's "~7,000-12,000"): independently
  recomputed the full join (`JobType='I' AND LineNumber=1` joined to
  `WkRoFile.CreatedOn >= '2026-01-01'`) directly in SQL and got exactly 4,257 — an exact
  match, confirming the notebook's join/filter logic is correct. The doc's higher
  estimate is stale relative to the current sparse 2026-01-01+ window (only 15,376 total
  work orders of any type fall in that window so far this year).

**Real bugs found from Brian's live run (2026-09-14), fixed:**
- `Fact_PlanterInspectionParts`/`Fact_PlanterInvoiceAllParts` (Planter Inspection Part
  Sales) hit `AnalysisException: Column RONumber#903, Branch#902 are ambiguous` — same
  same-name-join anti-pattern already seen on `dim_Salesperson`/`dim_JobCode`: both used
  explicit `df["col"] == df2["col"]` join conditions where a shared-origin column name
  existed on both sides. Fixed by renaming to matching names before each join and using
  same-name-list joins (`.join(other, ["Branch", "RONumber"], "inner")`) instead.
- `Fact_InTrans_UniqueCustomers` (Unique Parts Customers) hit
  `AnalysisException [COLUMN_ALREADY_EXISTS]: The column customer_tradetype already
  exists` — `Silver_InTrans` already has its own native `TradeType` column (transaction-
  level, distinct from the joined-in customer-classification `TradeType`); renaming the
  joined-in column to `Customer_TradeType` *after* the join renamed both copies to the
  same name. Fixed by aliasing to `Customer_TradeType` inside the lookup's own `.select()`
  *before* the join, so the collision never occurs — matching production's own real
  nested-join-then-rename-on-expand pattern that a flat Spark join-then-rename didn't
  replicate.

**Batch C — 5 large/perf-sensitive facts:** `Fact_WorkOrderParts`, `Fact_Inventory` (real
per-branch `VendorCode` grain — preserve exactly), `df_FactPartTransactions_Incremental`
(10M+ rows, needs a real incremental design), `Fact_AdjustmentPairs` (needs
`Fact_PartsAdjustments` reconfirmed first), `Fact_Parts_Open_Tickets`+`_Details` (SQL-view
origin needs investigation first).

**CORRECTION (2026-09-14):** the "known 18-19 min refresh" note above and
`REFRESH-TIMES.md`'s "Top Optimization Target #1" both describe the *original*
`df_Fact_WorkOrderParts.Dataflow` (full-history `Raw_InTrans`, no incremental source).
Production's own dataflow was already optimized at some later point (its own header says
"OPTIMIZED", switched to `InTrans_Incremental`, target 2-4 min) and Brian confirms real
recent runs are ~2 minutes — those docs were simply never updated after that change
shipped. **Not a live performance problem** by the time this batch started. Built anyway
as `Build_Gold_WorkOrderParts.Notebook` (Fact Tables/Inspections/) — feeds the
Inspections report alongside `Fact_LaborJobSummary`/`Fact_PendingInspections`, so it got
the same care regardless of urgency. Preserved 2 pieces of real production logic exactly
rather than simplifying them away: the sub-branch normalization fix (a documented real
$29K+ bug in production's history — `wkothsub`'s sub-branch codes like "11S" vs
`InTrans`'s main branch code "11" silently dropping the join) and the "keep all
franchises including ZP" decision (ZP rows are discount line items, filtered in DAX not
at the source). Fixed the same recurring `DateTime.LocalNow()` UTC bug on the 3-year
rolling cutoff (now 7 confirmed instances project-wide). Carried forward, not newly
introduced, one real caveat: production's own business-grain dedup step (a defense
against a known historical InTrans duplicate-loading issue) is likely a no-op now that
`Silver_InTrans` is MERGE-deduplicated by its own `(TransId, TransDatetime)` key, but was
kept as a faithful port with before/after row counts printed so any real collapse would
be visible, not silent.

**Verified (2026-09-14) after Brian ran it clean.** 14-column contract matches exactly,
93,294 rows. Independently recomputed the full join directly in SQL (inspection-invoice
lookup with sub-branch normalization, 3-year cutoff, business-grain dedup) and got
93,294 exactly, confirming the notebook's logic is correct. Two more real findings from
this verification pass, both non-bugs, both now documented in the notebook headers (and
retroactively in `Build_Gold_LaborJobSummary`/`Build_Gold_PendingInspections`, which
share the same list):
- The shared 111-code inspection list actually has **113** real codes — verified
  directly against production's own `mashup.pq` `InspectionCodes` table. Production's own
  "111" comment was itself stale/wrong; the list content itself was copied correctly (no
  transcription error), just the expected-count comment was off. Cosmetic, fixed in all 3
  notebooks so the print doesn't look like a bug later.
- `Franchise='ZP'` is NOT purely "discount items" the way production's own header
  comment claims — confirmed independently against `Silver_InTrans` directly. It's a
  broader fee/surcharge bucket: freight (`3750`), service fees (`VEHSERV`), filter fees,
  battery core charges, warranty deductibles, dyno fees, etc. are mostly *positive*, while
  only the specifically-named discount codes (`LEGACY`/`*10PROMO`/`ADV`/`4900`) are ~100%
  negative. Only ~58% of all ZP rows are negative overall — expected given this mix, not
  a defect. Flagged so no future DAX measure assumes "Franchise='ZP' implies discount."

Verification script: `.claude/queries/adhoc/dp-bronze-verify/verify_batch_c_workorderparts.py`.

**`Fact_Inventory` built (2026-09-14, Batch C 2/5).** `Build_Gold_Inventory.Notebook`
(Fact Tables/Inventory/) - shared by Inventory Analysis and Price Matrix. Preserved the
real per-branch `VendorCode` grain flagged during the `dim_Parts.VendorCode`
investigation (`VendorCode` read directly from `Silver_PartInformation`, joined straight
to `dim_VendorCode`, not through `dim_Parts`). 3 real findings, all fixed:
- **`dim_DealerGroupCode` duplicate-key bug** (fixed at the dimension - see the
  dimensions catalog's "Post-closure correction" section): 9 real rows with
  `DealerGroupCode` literally "UNKNOWN" collided with the dimension's own sentinel row,
  a real join fan-out risk. Independently confirmed all 7 other dimensions this fact
  joins against have zero natural-key duplicates - an isolated issue.
- **CommodityCode data-completeness bug**: production's own fallback uses literal
  "UNKNOWN" (uppercase) but `dim_CommodityCode`'s real sentinel row is "Unknown" (mixed
  case) - a case mismatch that silently drops ~22% of real inventory rows (32,382 of
  147,831) to a NULL `CommodityCodeKey` in PRODUCTION ITSELF. Fixed to match the
  dimension's real casing.
- **Real discrepancy resolved by reading the actual code, not the header prose**:
  production's header claims "all natural keys removed," but its own `RemoveColumns`
  step and its `DataDestinations` mapping both keep `PartNumber` as a real output column
  (25 columns total, not 24). Preserved here to match the real contract.

**Ran clean after fixing a real `WRITE_ANCIENT_DATETIME` bug** (missed the ancient-
datetime Spark config that's standing practice elsewhere in this backend - `DateCreated`/
`DateLastRequested` carry real pre-1900 JD source sentinel dates; fixed by setting
`datetimeRebaseModeInWrite`/`InRead` to `CORRECTED`).

**Verified (2026-09-14).** 25-column contract matches, 147,831 rows — independently
recounted `Silver_PartInformation` (`InventoryCost <> 0`) and got an exact match. Found
and fixed one more real bug during this verification pass:
- **SOURCE/SLC trim-order bug**: both lookups checked for blank *before* trimming
  instead of after (unlike `DealerGroupCode`/`CommodityCode`, which already had the
  correct order). 690 real rows have a raw `SLC` value of pure whitespace (`"   "`,
  confirmed via hex dump — not `""` or `NULL`), which slipped past the blank check,
  trimmed down to an actual empty string too late for the `UNKNOWN` fallback, and
  silently joined to nothing. Fixed by trimming first on both columns, matching
  production's real step order.
- Also confirmed the `(PartNumber, BranchKey)` "duplicates" the verification script
  first flagged are **not a bug**: `Silver_PartInformation`'s true natural key is
  `(Branch, PartNumber, Franchise)` — the same part can have separate real records at
  the same branch under different franchise codes. 0 duplicates at the real
  `(PartNumber, BranchKey, FranchiseKey)` grain.

Verification script: `.claude/queries/adhoc/dp-bronze-verify/verify_batch_c_inventory.py`.

**Re-verified after the fix (2026-09-14): fully clean.** All 8 dimension keys
(`BranchKey`, `PartNumberKey`, `FranchiseKey`, `VendorCodeKey`, `SourceKey`, `SLCKey`,
`DealerGroupKey`, `CommodityCodeKey`) have 0 nulls — the `SLCKey` fix resolved exactly
the 690 rows it was expected to. `Fact_Inventory` fully closed out.

**`Fact_Part_Transactions` REDESIGNED, not ported (2026-09-14, Batch C 3/5).** Brian's
own assessment before building anything: "I know that this was one of the very first
fact tables that I ever built and I think I may have tried to do too much with it...
I am wondering if there may be a better way here." Real usage audit confirmed it —
exhaustively checked every relationship, DAX measure, and visual-level column reference
across BOTH real consuming semantic models (`Inventory Analysis`, `Price Matrix`) and
BOTH real reports:
- `Inventory Analysis` imports only 8 columns via its own direct SQL query
  (`TransactionDate`, `FranchiseKey`, `PartNumberKey`, `BranchKey`, `Branch`,
  `SaleAmount`, `CostAmount`, `Quantity`), filtered to `Type IN ('C','I')` and a rolling
  7-year window.
- `Price Matrix` imports nearly all 70+ real columns wholesale, filtered at import to
  `FranchiseKey = 7 AND Type IN ('C','I')` and a rolling 13-month window — but across
  every measure, relationship, and visual in the entire report, only 6 more columns are
  ever referenced (`BranchKey`, `CostAmount`, `PartNumberKey`, `Quantity`, `SaleAmount`,
  `TransactionDate`) plus `SalesType` in one visual. **None** of the 8 matrix-pricing
  columns, **none** of the 7 customer-dimension columns, and **none** of the ~40 raw JD
  pass-through columns are used anywhere — despite the report's own name.

Real combined usage: ~10 of 70+ columns. Decision (confirmed): rebuild lean rather than
port the bloat. `Build_Gold_PartTransactions.Notebook` (Fact Tables/Inventory Analysis/)
drops the entire matrix-pricing block, the entire customer-dimension join, and every
unused raw column — keeps `TransactionDate`, `Branch`, `BranchKey`, `FranchiseKey`,
`PartNumber`, `PartNumberKey`, `Type`, `Quantity`, `SaleAmount`, `CostAmount`, `Margin`,
`MarginPercent`, `SalesType` (13 columns; `PartNumber`/`Margin`/`MarginPercent` kept as
essentially-free join-byproduct/derived columns, matching convention elsewhere in this
backend). Filtered to `Type IN ('C','I')` at the ETL layer — cuts `Silver_InTrans` from
20,473,073 to 11,237,844 rows, exactly what both reports consume (the excluded types are
P/T/A/R, which neither report ever reads).

This also eliminates the watermark-safety question entirely: production's own dataflow
used append + `TransDatetime > watermark`, the exact same structurally-unsafe pattern
already found and fixed once at the Silver layer (a late-committing row gets permanently
skipped once the watermark advances past it). With the matrix-pricing calcs and customer
join gone, a full overwrite every run is now entirely reasonable — same pattern as every
other Gold notebook in this backend, no incremental complexity, no watermark risk.

Also verified production's own "critical fix" comment (strip leading zeros from
`Branch`) is unneeded against real `Silver_InTrans` data — 0 real leading-zero values, 0
real unmatched `Branch` values against `dim_BranchLocation`, confirmed directly.

**Report-level correctness against this leaner shape is deliberately deferred to the
report-rebuild phase**, per Brian's explicit direction — not blocking this backend work.

**Verified (2026-09-14): fully clean.** Ran successfully first try. 13-column contract
matches exactly, 11,237,844 rows — independently recounted `Silver_InTrans`
(`Type IN ('C','I')`) and got an exact match. `Type` breakdown confirms only `C`/`I`
present. `Margin` calculation: 0 mismatches against `SaleAmount - CostAmount`. Only
anomaly: 8 rows (0.00007%) have a null `PartNumberKey` — traced to a single real part
number (`RRH-801355`) that has real transactions in `Silver_InTrans` but doesn't exist
in `dim_Parts` (likely obsolete/deleted) — a genuine, expected left-join miss, not a
bug. `Fact_Part_Transactions` fully closed out. Verification script:
`.claude/queries/adhoc/dp-bronze-verify/verify_batch_c_parttransactions.py`.

**`Fact_AdjustmentPairs` + `Fact_AdjPairs_Summary` built (2026-09-14, Batch C 4/5).**
`Build_Gold_AdjustmentPairs.Notebook` (Fact Tables/Parts Adjustments/) — production's
dataflow defines 2 real output tables, both built here: `Fact_AdjustmentPairs` (one row
per matched negative/positive pair — self-join on `Branch`+`PartNumber`, 24-month
bidirectional window, `IsExact`/`MatchType` per pair; multiple matches per transaction
are intentional, documented by production itself) and `Fact_AdjPairs_Summary` (one row
per negative transaction, ALL negatives from `Fact_PartsAdjustments` — not just matched
ones — with matches aggregated into 12/24-month windows; unmatched negatives get 0s and
`MatchType = "No Match"`).

Built the self-join safely from the start: `Negatives` and `Positives` both derive from
`Fact_PartsAdjustments` and share identical `Branch`/`PartNumber` column names — the
exact self-join shape that's already caused `AMBIGUOUS_REFERENCE` bugs elsewhere in this
project (`dim_Salesperson`, `dim_JobCode`, Planter Inspection Part Sales) — used a
same-name-list join instead of an explicit condition.

Fixed the recurring `DateTime.LocalNow()` UTC bug — more consequential here than most
instances: the 24-month cutoff determines the entire real scope of both tables, not just
a cosmetic `LoadedDatetime` stamp. Now 8+ confirmed instances of this bug pattern
project-wide. Not yet run by Brian as of this doc update.

**Batch D — Customer Anatomy, 9 dataflows, on its own.** All raw dependencies already
migrated; complexity is business-logic depth (the real `CustomerVehicleFlag`
Stock/Unknown customer-assignment logic), not missing infrastructure.

Still deferred/blocked, not part of any batch yet: `Fact_Branch12_Transactions` (blocked
on `dim_Branch12_Parts`, itself circularly blocked in the dims catalog — needs a real
build-order decision).
