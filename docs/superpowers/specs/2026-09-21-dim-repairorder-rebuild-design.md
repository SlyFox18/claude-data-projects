# `dim_RepairOrder` Full Rebuild — Design Spec

## 1. Problem Statement

`Parts Promo` — the original pilot report for this whole DP backend project — was
left with a genuinely broken `dim_RepairOrder`: the real Gold table in
`DP_Presentation` has only 2 columns (`REF_NO`, `CustomerNo`), but the report's
own semantic model still declares 15, and 5 of the missing 13
(`NetMargin`, `NetOrderValue`, `OriginalMargin`, `TotalPartsCost`,
`TotalPartsSales`) are directly referenced (via `LOOKUPVALUE`/`SUM`) by the
report's own core margin and discount-analysis DAX measures — this report's actual
reason for existing.

This isn't a bug in anything built this session. The 15→2 column trim was a real,
deliberate decision made 2026-09-11, based on a column-usage-depth audit
(`docs/architecture/lh-master-data-dimensions-catalog.md`) that found only `REF_NO`
and `CustomerNo` "genuinely used by the live Parts Promo report" at the time. That
audit predated Parts Promo's own facts (`Fact_PartsPromo`,
`Fact_InTrans_AllPromo`) and `dim_RepairOrder` actually being repointed to
`DP_Presentation` and refreshed for real — the same "usage audit didn't cover this
specific report yet" pattern already found and fixed 4 times this session
(`dim_DateTable.SortableMonthYear`, and gaps in `dim_BranchLocation`/
`dim_CustomerList`/`dim_Parts` across 6 other reports).

The existing Gold notebook (`Build_Gold_PartsPromo.Notebook`, in
`DP - Presentation - Dev/Fact Tables/Parts Promo/`) already documents this exact
situation in its own header comment: the dropped 13 columns are "well-designed
pre-aggregated order-level metrics — genuinely good logic that replaced a runtime
self-join... just never surfaced in the report." They have now surfaced.

## 2. Scope: Restore the Full Original 15-Column Design

Brian's own call, not a default: restore all 15 columns, not just the 5 confirmed
used in DAX today. The table was originally, deliberately designed as this
complete set for this exact report — it isn't speculative work, it's restoring
intentional design to the report it was built for.

The 15 columns: `REF_NO`, `BranchKey`, `CustomerNo`, `OrderDate`,
`LastActivityDate`, `TotalPartsSales`, `TotalPartsCost`, `PartsCount`,
`TotalPromoDiscount`, `PromoCount`, `NetOrderValue`, `OriginalMargin`, `NetMargin`,
`DiscountAmount`, `DiscountPercent`.

## 3. Real Source and Column Logic

Traced directly from the original, real production Power Query
(`projects/parts promo - report/queries/new report/dimensions/dim_RepairOrder.pq`
in `data-projects` — read in full, not assumed) and cross-checked against the
current Gold notebook's own already-correct 2-column build of the same table
(confirmed the promo-order-identification and CustomerNo logic already match
exactly).

**Source:** `Silver_InTrans` (already read into the notebook's `silver` DataFrame,
filtered to `TransDatetime >= "2022-01-01"` — the same start date the original
query used, matching `Fact_PartsPromo`'s own date range). **No deduplication step
is needed** — the original query's `Table.Group`-based dedup existed specifically
to work around a real `InTrans_Incremental` duplication bug (introduced ~December
2024); `Silver_InTrans` is already deduplicated at this layer (confirmed by this
same notebook's own comment: "Silver_InTrans is already deduped, unlike
InTrans_Incremental").

**Grain:** one row per `REF_NO` (repair order), for orders that have at least one
promo line (`PartNumber` starting with `*`) — identical to the current 2-column
build's own `promo_ros`/`orders_with_promo` logic; this rebuild extends that same
join, it doesn't replace it.

**Column derivations:**

| Column | Logic |
|---|---|
| `REF_NO` | `RONumber`, renamed (already correct in the current build) |
| `CustomerNo` | First `CustomerNo` across the *whole* order's rows, not just non-promo rows (already correct in the current build) |
| `BranchKey` | First `Branch` value per order, cast to `Int64.Type` — **a real fix to carry forward**: the original 15-column build (before the 2026-09-11 trim) left this as a string; the notebook's own header already documents this as a known, deliberate correction that simply never got exercised since the column was dropped before the fix could matter |
| `OrderDate` | `MIN(TransDatetime)` per order |
| `LastActivityDate` | `MAX(TransDatetime)` per order |
| `TotalPartsSales` | `SUM(SaleValue)` where `PartNumber` doesn't start with `*` AND `Franchise != 'ZP'` (nulls treated as 0) |
| `TotalPartsCost` | `SUM(CostValue)`, same filter as `TotalPartsSales` |
| `PartsCount` | `COUNT(*)`, same filter as `TotalPartsSales` |
| `TotalPromoDiscount` | `SUM(SaleValue)` where `PartNumber` starts with `*` — **no** `Franchise != 'ZP'` exclusion (promo parts are typically `ZP` franchise; excluding them would zero this out) |
| `PromoCount` | `COUNT(*)`, same filter as `TotalPromoDiscount` |
| `NetOrderValue` | `TotalPartsSales + TotalPromoDiscount` (discount is stored as a negative `SaleValue`) |
| `OriginalMargin` | `TotalPartsSales - TotalPartsCost` |
| `NetMargin` | `NetOrderValue - TotalPartsCost` |
| `DiscountAmount` | `ABS(TotalPromoDiscount)` |
| `DiscountPercent` | `DiscountAmount / TotalPartsSales`, or `0` if `TotalPartsSales` is `0` or null |

## 4. Architecture

Extend the existing `dim_repair_order` build cell in `Build_Gold_PartsPromo.Notebook`
in place — not a new notebook. It already loads `Silver_InTrans` once into `silver`
and shares that load across `dim_RepairOrder`, `Fact_PartsPromo`, and
`Fact_InTrans_AllPromo`; a separate notebook would mean a redundant second read of
the same source table for no benefit. The write step
(`.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/dim_RepairOrder")`)
already exists and needs no change — `overwriteSchema=true` means the column-count
change from 2 to 15 is handled automatically.

No changes to `Fact_PartsPromo` or `Fact_InTrans_AllPromo`'s own build cells, and
no changes to any report's TMDL files — Parts Promo's `dim_RepairOrder.tmdl`
already declares all 15 columns (it was never trimmed at the report layer, only
the Gold table was), so once the Gold table has all 15 real columns again, the
existing model just works.

## 5. Verification Plan

Parts Promo's own `dim_RepairOrder` has no working "before" state to diff against
(it's the same broken 2-column table being fixed). Verify instead by independently
computing the same aggregates directly against `Silver_InTrans` via DuckDB —
a separate, independent check from the notebook's own Spark logic — for:

1. A handful of real, arbitrary `REF_NO`s, to confirm the general computation is
   right.
2. The 11 "known-bad" `REF_NO`s already tracked in this notebook's own existing
   verification cell (`1986984`, `1981941`, `1984493`, `1987016`, `1986996`,
   `1985073`, `1979395`, `1985078`, `1985139`, `1987116`, `1987002`) — these were
   flagged in the original investigation as specifically worth checking, so they
   remain the right spot-check target here too.

Compare the independently-computed DuckDB values against the notebook's real
output for these same orders before considering this correct — matching this
project's own established "verify against real data, don't just trust internal
consistency" discipline.

## 6. What This Spec Deliberately Does Not Cover

- Any change to `Fact_PartsPromo` or `Fact_InTrans_AllPromo` — both already
  correctly built, out of scope.
- Any change to Parts Promo's report-layer TMDL files — already correctly
  declares all 15 columns, needs no edit once the Gold table matches.
- The 4 dimensions already fixed for Parts Promo this session
  (`dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Parts`) — done,
  separate from this spec.
- Any other report's use of `dim_RepairOrder` — this table is specific to Parts
  Promo (confirmed via its own real relationships: `REF_NO ← Fact_PartsPromo`,
  `BranchKey → dim_BranchLocation`), not a shared dimension.
