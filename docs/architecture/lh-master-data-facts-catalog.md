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
confirmed-recurring pattern across this whole backend, not a one-off: the original Data
Refresh Table bug (fixed 2026-02-27), `Fact_PartsAdjustments.LoadedDatetime` (fixed
2026-09-09, before this catalog existed), and `Fact_NegativeOnHand.DaysSinceLastRequest` +
`Fact_InSalOrd_InSalPar.Days_Open`/`Aging` (both found and fixed in Batch A). Grepped every
in-scope dataflow for it — these still have a live instance to check when their batch comes
up (don't assume it needs fixing, some uses may be harmless logging timestamps like the
`Fact_PartsAdjustments` one was, but check each one against what the value actually feeds):

`Fact_Branch12_Transactions`, `Fact_WorkOrderParts`, `Fact_Invoice_InventoryAnalysis`,
`Fact_JobCodeFrequency_Branch`, `Fact_JobCodePartFrequency`, `Fact_PartsNotReordered`,
`Fact_AdjustmentPairs`.

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
| `df_FactPartTransactions_Incremental` | Inventory Analysis + Price Matrix (shared) | `InTrans_Incremental` | `dim_Parts`, `dim_Franchise`, `dim_BranchLocation`, `dim_CustomerList` | 10M+ rows, already incremental in production (the "success story" the old doc cites) — needs a real incremental-refresh design on the DP backend, not just a faithful one-shot port. 40+ output columns, several derived pricing-analytics fields. |
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

**Batch B — ~12 medium facts:** `Fact_JobCodePartFrequency`(+`_Branch`),
`Fact_InternalWorkOrders`, `Fact_PendingInspections`, `Fact_LaborJobSummary`,
`Fact_ServiceRecommendations` (after the 2 Inspections facts above), `Fact_PlanterInspectionParts`,
`Fact_Invoice_UniqueCustomers`+`Fact_InTrans_UniqueCustomers`, `Fact_Invoice_InventoryAnalysis`,
`Fact_PartsNotReordered` (added on re-check — see the correction note above),
`Fact_MDInvoices_Closed`+`Fact_MDInvoices_NoFreight`, `Fact_Transfers`.

**Batch C — 5 large/perf-sensitive facts:** `Fact_WorkOrderParts` (the known 18-19 min
refresh), `Fact_Inventory` (real per-branch `VendorCode` grain — preserve exactly),
`df_FactPartTransactions_Incremental` (10M+ rows, needs a real incremental design),
`Fact_AdjustmentPairs` (needs `Fact_PartsAdjustments` reconfirmed first),
`Fact_Parts_Open_Tickets`+`_Details` (SQL-view origin needs investigation first).

**Batch D — Customer Anatomy, 9 dataflows, on its own.** All raw dependencies already
migrated; complexity is business-logic depth (the real `CustomerVehicleFlag`
Stock/Unknown customer-assignment logic), not missing infrastructure.

Still deferred/blocked, not part of any batch yet: `Fact_Branch12_Transactions` (blocked
on `dim_Branch12_Parts`, itself circularly blocked in the dims catalog — needs a real
build-order decision).
