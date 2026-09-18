# `jdis_Part_Information` Rebuild — Design Spec

**Supersedes:** Section 8 of `docs/superpowers/specs/2026-09-17-dp-refresh-pipeline-design.md`
("Known High-Priority Follow-On"), which flagged this as a real, confirmed gap but
deliberately deferred it. This spec designs the actual rebuild.

## 1. Problem Statement

`Build_Silver_PartInformation.Notebook` (in `DP - Staging - Dev`, feeding `dim_Parts`
and read directly by both Bin Location Report and Physical Inventory) currently
depends on two Dataflow Gen2 items — `df_JDIS_PartInformation_Active_Raw` and
`df_JDIS_PartInformation_Dead_Raw` — that query the live source system directly via
ODBC (`dsn=EquipRDB64`), bypassing the JD Bronze mirror architecture this entire
project is built around. Confirmed 2026-09-17/18:

- Both dataflows query `jdis_Part_Information`, a **SQL Anywhere view**, not a base
  table (real `ALTER VIEW` SQL obtained from Brian).
- **Neither dataflow has a schedule at all** — only two manual refreshes on record,
  a week apart (2026-09-09, 2026-09-16).
- Both are Dataflow Gen2 items, invisible to `deploy_backend.py`'s deploy scope and
  to all three refresh pipelines built in the prior plan (Notebook-only).
- Every real table the view depends on is already mirrored in
  `JD_EquipRDB_Production_Bronze` (209 tables total) — including the two heaviest,
  `InHistMQT` and `INHIST_MONTH_4_PI`, as already-computed/pre-aggregated tables,
  not raw data needing re-aggregation from scratch.

This spec replaces both dataflows with a proper Silver notebook, sourced from Bronze
shortcuts like every other table in this project, bringing `jdis_Part_Information`
fully into the managed, scheduled, git-tracked architecture.

## 2. Scope: Faithful Port of the Current ~33 Columns Only

The view exposes roughly 200 columns, including 60 months each of rolling
sales/lost-sales/sales-activity history and fiscal-year-aware YTD sums. The two
existing dataflows only ever selected 33 of them (confirmed identical column lists
between `_Active_Raw` and `_Dead_Raw`, differing only in their `WHERE` filter):

```
Branch, PartNumber, Description, Franchise, Source, SLC, CommodityCode,
DealerGroupCode, QuantityOnHand, BinQty, BulkBinQty, PendingQty, BackOrderQty,
BulkBin, Bin, PackageQty, Returnable, Weight, OnOrder, SuperTo, SuperFrom,
InventoryCost, Cost, SellPrice1, ListPrice, Current12MoSales, Current12MoDollars,
Previous12MoSales, Previous12MoDollars, VendorCode, DateCreated, DateLastRequested,
StocktakeDate
```

**Decision:** this rebuild targets exactly this column set — no expansion to the
view's other ~170 columns (the 60-month history arrays, fiscal-year YTD sums,
suggested-order-qty, current-month aggregates). Matches this project's established
pattern (`dim_Parts`, `dim_CustomerList`, etc. were all ported faithfully first,
enhanced later as separate work if ever needed) and keeps this rebuild focused on
its real goal: eliminating the two unmanaged dataflows, not expanding functionality.

## 3. Real Column-to-Source Mapping

Traced directly from the view's real `ALTER VIEW` SQL (not assumed) — **to be
double-checked against live data during implementation** before being trusted in
code, given the SQL's legacy/unusual syntax in places (see Section 6).

**Simple joins/CASE logic (no aggregation) — the large majority of the 33 columns:**
Sourced from `InMaster` (already shortcut and used elsewhere in this project) joined
to `Branch_Name` (already shortcut) and conditionally to `InManuf_Locale`/`InManuf`
(new shortcuts needed) based on a `FR_LOC_INDICATOR` flag. Examples: `Branch`,
`PartNumber`, `Description`, `Franchise`, `DealerGroupCode`, `QuantityOnHand`,
`BinQty`, `SuperTo`/`SuperFrom`, `Cost`, `ListPrice`, `VendorCode`,
`DateCreated`/`DateLastRequested`/`StocktakeDate`, etc. **Exact real mapping for all
of these (the literal `pi_X AS Y` pairs) already exists** in
`df_JDIS_PartInformation_Active_Raw.Dataflow/mashup.pq`'s SQL string (both old
dataflows select the identical column list) — the implementation plan should read
that file directly as the source of truth for the simple-column mapping rather than
re-deriving it, and cross-reference each `pi_X` against the real view SQL to
confirm which underlying table/join it actually comes from before writing the
notebook.

**`Current12MoSales` / `Previous12MoSales`:** these appear in the view's SELECT list
as bare `isnull(pi_current_12_mo_sales, 0)` / `isnull(pi_previous_12_mo_sales, 0)` —
no subquery of their own, meaning they resolve to real, already-computed columns on
`INHIST_MONTH_4_PI` (the view's `LEFT JOIN` target literally named "month for PI" -
i.e. purpose-built to feed exactly this view). **New shortcut needed:**
`INHIST_MONTH_4_PI`. This is a simple join, not an aggregation.

**`Current12MoDollars` / `Previous12MoDollars`:** unlike the two above, these ARE
real correlated subqueries in the view SQL — rolling sums of `sal_val` from a
`temp_inhist` CTE (`WITH temp_inhist AS (SELECT ... FROM InHistMQT WHERE mm_YYYY >
current timestamp - 1825)`), filtered to trailing 12-month windows
(`Current12MoDollars`: this month back 12; `Previous12MoDollars`: the 12 months
before that), grouped by `(branch, franchise, part_no)`. **New shortcut needed:**
`InHistMQT`. This is the one piece of this rebuild needing a real Spark
aggregation (two rolling-12-month sums) rather than a plain join — a bounded,
tractable amount of logic, not the view's full 60-month/fiscal-year machinery.

## 4. Architecture

**Replace `Build_Silver_PartInformation.Notebook` in place** — same name, same
notebook ID, same workspace. It's already wired into `dp_backend_scope.json`
(`notebookId`/`workspaceId` don't change when a notebook's internal logic changes)
and all three refresh pipelines built in the prior plan, so this rebuild needs
**zero changes** to the shared config or any pipeline — only the notebook's own
code changes.

```
DP - Staging - Dev
├── InMaster.Shortcut          (existing, reused directly - not via Silver_InMaster,
│                                which was scoped for a different purpose and is
│                                missing columns this rebuild needs, e.g. bin
│                                location, dealer group code, min/max qty,
│                                supersession fields)
├── Branch_Name.Shortcut       (existing, reused directly)
├── InManuf.Shortcut           (new)
├── InManuf_Locale.Shortcut    (new)
├── INHIST_MONTH_4_PI.Shortcut (new)
├── InHistMQT.Shortcut         (new)
└── Build_Silver_PartInformation.Notebook (rewritten in place)
    → joins the above per Section 3's mapping
    → writes Tables/Silver_PartInformation (single table, no Active/Dead split)
```

**Cadence:** daily, matching `dim_Parts`' existing schedule in
`dp_backend_scope.json` (`Build_Silver_PartInformation` is already listed there with
`"cadence": "daily"` — no config change needed, this rebuild just changes what the
notebook does internally).

## 5. Active/Dead Split: Deliberately Deferred, Not Decided Here

The two old dataflows split Active (26.8% of rows, has stock or recent sales) from
Dead (73.2%, neither) specifically so the small Active slice could eventually refresh
more often than the large Dead majority, once refresh scheduling existed for this
backend (documented in the current notebook's own header as an explicit future
intent). That scheduling now exists (the prior plan's daily/monthly pipelines).

**However**, the original CU-saving logic behind the split doesn't carry over
cleanly to a Spark/Bronze rebuild: the old dataflows' `WHERE` filter operated on
columns the *view itself* already computed, so SQL Anywhere ran the full expensive
logic for all 1.1M rows before either dataflow's filter ever applied — the split
only reduced *rows shipped over the network*, not *computation performed*. A row's
Active/Dead status is only knowable *after* computing the aggregates that classify
it, so a Spark version can't cheaply pre-filter into two smaller jobs the way the
old ODBC split implicitly could.

**Decision:** build one unified notebook first, measure its real CU/duration (Task
in the implementation plan), and decide whether an Active/Dead split still makes
sense — and if so, in what form (likely: compute once, write two output tables on
different cadences, not two independent compute passes) — from that real data. Not
decided now, on theory.

## 6. Verification Plan

Given the SQL's legacy syntax and the "bare column resolves to whichever joined
table has it" idiom used for `Current12MoSales`/`Previous12MoSales`, the column
mapping in Section 3 needs real verification before being trusted in code:

1. Pick a small, real sample of parts (a handful of `(Branch, PartNumber,
   Franchise)` combinations already known from the current `Silver_PartInformation`
   table's output).
2. For each, independently compute what `Current12MoSales`/`Previous12MoSales`/
   `Current12MoDollars`/`Previous12MoDollars` *should* be from the raw Bronze
   `InHistMQT`/`INHIST_MONTH_4_PI` tables directly (a DuckDB query, not the new
   notebook's own logic — an independent check).
3. Compare against the *current* production values for those same parts (queryable
   live via the source system, per this project's established "verify against real
   data" pattern) to confirm the mapping is actually right, not just internally
   self-consistent.
4. Only then build the real notebook logic against the confirmed-correct mapping.

This mirrors the exact discipline already used throughout this project (e.g. the
control-character bug found in `Build_Gold_Parts`, the Table.SelectColumns bug
class) — verify against real data before trusting a column mapping in code.

## 7. Cutover and Cleanup

1. Build and verify the rebuilt notebook against real data (Section 6).
2. Cut over: the rebuilt `Build_Silver_PartInformation.Notebook` starts reading from
   the new Bronze shortcuts instead of `PartInformation_Active`/`PartInformation_Dead`.
3. **Delete both old Dataflow Gen2 items** (`df_JDIS_PartInformation_Active_Raw`,
   `df_JDIS_PartInformation_Dead_Raw`) and their now-unused output tables
   (`PartInformation_Active`, `PartInformation_Dead`) once the new notebook's output
   is confirmed correct — immediately after validation, not kept as a fallback
   (Brian's own call: no reason to keep the exact unmanaged/unscheduled items this
   rebuild exists to eliminate).

## 8. What This Spec Deliberately Does Not Cover

- The view's other ~170 columns (60-month history arrays, fiscal-year YTD sums,
  suggested-order-qty, current-month aggregates) — out of scope per Section 2.
- The Active/Dead split decision — deferred per Section 5, pending real measurement.
- Any change to `dim_Parts`'s own business logic (promo/margin/supersession
  classification) — `Build_Silver_PartInformation` produces a Silver table, not a
  business-enriched Gold one; that boundary is unchanged by this rebuild.
- Prod-tier shortcuts/notebook — this rebuild is Dev-tier only, same as every other
  piece of the DP backend not yet promoted.
