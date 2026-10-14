# JD Pricing Fact Tables (Sub-project 3, Phase 1) — Design

## Overview

Sub-project 3 of the JD parts pricing effort (see `projects/jd-price-updates/README.md`)
was originally framed as "margin-impact analysis and slicing price changes
by `dim_Parts` classifications." Rather than jumping straight to a specific
analysis or report, this phase builds the foundational **fact layer**: two
enriched, `dim_Parts`-joined fact tables derived from the two raw price
history tables built in sub-projects 1 and 2. What specific KPIs, margin
calculations, or reports get built on top of these facts is explicitly
**out of scope** for this phase — deferred until a real analysis need
defines what "good" looks like.

**Depends on:**
- `Raw_PriceUpdate_History` (sub-project 1) — 5.1M+ rows, 2008-08-25 to
  present, branch-tagged, parts actually sold/carried at South Plains.
- `Raw_JDNationalChangeReport_History` (sub-project 2) — ~48K rows and
  growing weekly, 2026-07-13 to present, no branch dimension, all Deere
  parts nationally (most not carried locally).
- `dim_Parts` — current-snapshot parts dimension, one row per `PartNumber`.

## Why two separate fact tables, not one unified table

The two raw sources describe the same kind of event (a JD price change on
`PartNumber + EffectiveDate`) but differ enough that forcing them into one
grain now would be premature:

- **History depth is wildly different.** 18 years vs. 5 weeks. Unifying
  now means the national side is mostly empty across nearly all of
  history — harmless, but it also means designing cross-source dedup/
  reconciliation logic before there's any real evidence it's needed.
- **Scope is different.** `Raw_PriceUpdate_History` only covers parts
  South Plains actually carries (branch-tagged). The National Change
  Report covers *all* Deere parts, the large majority of which aren't
  carried locally.
- **Preserving trend fidelity matters.** Keeping `Raw_PriceUpdate_History`
  ingestion and its 18-year branch history untouched (see `Fact_PriceUpdate_Enriched`
  grain below) was an explicit design goal — a premature unification
  risked compromising that.

Both fact tables use the same enrichment pattern (same `dim_Parts` join,
same column set added), so a future reconciliation or unified view — once
a specific analysis need actually calls for one — is a cheap follow-on,
not something baked in prematurely.

## `PartNumber` normalization (required for correct joins)

None of the three tables normalize `PartNumber` the same way today:

| Table | Trim? | Upper? |
|---|---|---|
| `dim_Parts` | Yes | Yes |
| `Raw_JDNationalChangeReport_History` | Yes | No |
| `Raw_PriceUpdate_History` | No | No |

A naive join on `PartNumber` as-is would silently under-match — some real,
carried parts would incorrectly show up as "not found in `dim_Parts`"
purely from casing/whitespace differences, not because they aren't
actually carried. Both fact-building queries must normalize `PartNumber`
(`Text.Trim` + `Text.Upper`) to `dim_Parts`' convention **before** joining.
The underlying raw tables are not touched — this normalization happens
only within the fact-building queries, consistent with the repo's
"raw layer preserves fidelity, normalization is a downstream concern"
convention.

## `Fact_PriceUpdate_Enriched`

**Source:** `Raw_PriceUpdate_History`.

**Grain:** one row per `PartNumber + EffectiveDate` — **not**
`Branch + PartNumber + EffectiveDate + SourceFileName` like the raw table.
Per the raw table's own header comment and confirmed independently by
Ben (South Plains stakeholder) during a live walkthrough: branch doesn't
affect price, only assortment, so collapsing across branches to this
grain is the natural key for price-trend analysis, not a loss of
information — it's the removal of an assortment artifact that was never
analytically meaningful for pricing questions in the first place.

**Columns:**

| Column | Source | Notes |
|---|---|---|
| `PartNumber` | Raw (normalized) | Join key |
| `EffectiveDate` | Raw | |
| `Category` | Raw (pass-through) | Raw table's header comment flags mapping this to `dim_Parts` `CommodityCode`/`SLC` as an analysis-phase concern — this phase provides that mapping via the `dim_Parts` join columns below; `Category` itself is passed through unchanged, not remapped in place. |
| `ManufacturerListPrice`, `DealerListPrice`, `ListPriceChangePercent`, `ManufacturerReplacePrice`, `DealerReplacePrice`, `ManufacturerSellPrice1`, `DealerSellPrice1`, `SellPriceOld`, `CostDiff`, `ListDiff`, `SellPrice1Diff`, `UpdateCode` | Raw | Carried through as a single representative value per `PartNumber + EffectiveDate` (see `HasBranchPriceDisagreement` below for what happens when branches disagree) |
| `AffectedBranchCount` | Computed | Count of distinct **rolled-up main** `Branch` values (not `SourceFileBranch`) that reported this `PartNumber + EffectiveDate` price change — consistent with the raw table's existing convention that sub-branch codes aren't analytically meaningful. |
| `HasBranchPriceDisagreement` | Computed | Safety-net flag: true if the branch rows being collapsed for this `PartNumber + EffectiveDate` don't actually agree on the price/change fields above. Expected to be rare-to-never (per the "branch doesn't affect price" assumption) but this project has repeatedly found that "should never happen" assumptions are worth a cheap, explicit check rather than a silent overwrite. |
| `HasTypeConversionIssue` | Aggregated from raw | True if **any** of the collapsed branch rows had a conversion issue in the raw table. |
| `IngestedAt` | Computed fresh | DST-aware UTC→Central timestamp of this fact's own build, same pattern as `.claude/queries/DATA-REFRESH-TEMPLATE.pq` — not carried from the raw rows' `IngestedAt`. |
| `Description` | `dim_Parts` (join) | **Replaces** the raw table's own `PartDescription`, which varies inconsistently by branch/file (confirmed a leftover artifact, not meaningful data, per Ben) |
| `Source`, `SLC`, `DealerGroupCode`, `CommodityCode`, `VendorCode` | `dim_Parts` (join) | Business classification columns for future slicing |
| `IsCarriedLocally` | Computed | True if the `dim_Parts` join found a match. Always true in practice for this fact (source is inherently "parts we carry"), but included for schema consistency with `Fact_JDNationalChangeReport_Enriched`, where it's the main analytical point. |

**Explicitly dropped** (present in the raw table, not carried into this
fact — full detail remains available in `Raw_PriceUpdate_History` if ever
needed): `Branch`, `SourceFileBranch`, `BinLocation`, `OnHandQty`,
`SourceFileName`, `SourceFileDate`, `BranchMismatchFlag`, raw
`PartDescription`, raw `Franchise` (see below).

**`Franchise` validation (build-time check, not a column):** all JD parts
are expected to have `Franchise = 'D'`. Rather than add a column that
would always show the same value, the fact-building query performs a
one-time validation comparing the raw table's own `Franchise` value
(across all branch rows being collapsed) against `dim_Parts`' `Franchise`
for the same part, confirming both agree and both equal `'D'`. Findings
are documented in the query's header comment, not persisted as row data.

## `Fact_JDNationalChangeReport_Enriched`

**Source:** `Raw_JDNationalChangeReport_History`. Unaffected by the
grain change above — this source never had a branch dimension to begin
with.

**Grain:** unchanged from raw — one row per
`PartNumber + EffectiveDate + SourceFileName`.

**Columns:** all existing raw columns (`PartNumber`, `EffectiveDate`,
`CurrentDNP`, `CurrentSLP`, `NewDNP`, `NewSLP`, `SourceFileName`,
`SourceFileDate`, `FileNameDateMismatchFlag`, `HasTypeConversionIssue`,
`IngestedAt`) plus the same `dim_Parts` enrichment set as above:
`Description`, `Source`, `SLC`, `DealerGroupCode`, `CommodityCode`,
`VendorCode`, `IsCarriedLocally`. No current-snapshot pricing/inventory
columns from `dim_Parts` are added here either, for the same reason as
below.

`IsCarriedLocally` is expected to be `false` for the large majority of
rows here, since most national Deere parts aren't carried at South
Plains — this is expected, not a defect.

## Why no current-snapshot pricing/inventory columns

`dim_Parts` is a current snapshot (one row per part, refreshed daily),
not point-in-time history. Joining it onto a historical price-change row
(some going back to 2008) would give *today's* classification/price/cost
for that part, not what was true when the change happened. That's safe
for stable attributes (`CommodityCode`, `SLC`, etc. essentially never
change), but would be actively misleading for `SellPrice1`,
`InventoryCost`, `ListPrice`, `QuantityOnHand`, or `ActivityStatus` — a
future analysis could easily and incorrectly use *today's* price to
compute a "margin at the time" for a years-old price change. These are
deliberately excluded from both fact tables in this phase. If a specific
future analysis need calls for a defined point-in-time or current-vs-then
comparison, that's a deliberate, explicit addition to make later — not a
default to bake in now.

## Fabric objects, location, and naming

- New folder: `projects/jd-price-updates/queries/fact-tables/`, matching
  the repo's established `projects/{name}/queries/fact-tables/{fact}.pq`
  convention. Contains `Fact_PriceUpdate_Enriched.pq` and
  `Fact_JDNationalChangeReport_Enriched.pq` as gold-standard reference
  copies (same "reference copy, not live sync" caveat as sub-project 1's
  `.pq` files — see `projects/jd-price-updates/README.md`).
- Fabric Dataflow Gen2 + Lakehouse table pairs:
  - `df_Fact_PriceUpdate_Enriched` → `Fact_PriceUpdate_Enriched`
  - `df_Fact_JDNationalChangeReport_Enriched` → `Fact_JDNationalChangeReport_Enriched`
- Both dataflows read their respective raw Lakehouse table (not files —
  these are derived from already-ingested raw tables, not landing-folder
  files) and join to `dim_Parts`.
- **Load mode: full Replace, not Append**, on every refresh. These are
  derived/enriched rebuilds of their entire source table, not
  new-rows-only appends. Simpler and correct given the grain-collapsing
  logic (`AffectedBranchCount` etc. can't be computed incrementally
  without re-scanning all branch rows for a given part+date anyway).
  Incremental refresh is a documented future option if the
  `Fact_PriceUpdate_Enriched` join ever proves slow at scale — same path
  already proven on `Fact_Part_Transactions` (10M+ rows, 2-3 min
  incremental) — but not built from day one per YAGNI.
- `FACT-TABLES-SUMMARY.md` gets a new entry for both fact tables,
  consistent with every other fact table in the repo.

## Refresh cadence

- `Fact_PriceUpdate_Enriched`: **daily**, scheduled after
  `Raw_PriceUpdate_History` (harvested daily at 02:00) and `dim_Parts`
  both refresh — mirrors sub-project 1's own daily cadence.
- `Fact_JDNationalChangeReport_Enriched`: **weekly**. Its source only
  changes when Brian manually places a new file (at most weekly, per the
  Saturday reminder), so a daily refresh would just spend CU re-deriving
  identical data. Scheduled after a new file is expected to have landed.

## Known caveats / residual risks (documented, not fixed — deliberate)

- `dim_Parts` is a current snapshot; enrichment columns reflect *today's*
  classification, not history. Fine for stable attributes, would be
  wrong to treat as historical truth for anything else (see above).
- `IsCarriedLocally = false` will dominate
  `Fact_JDNationalChangeReport_Enriched` for the foreseeable future — most
  national Deere parts simply aren't carried locally. Expected, not a
  defect.
- `HasBranchPriceDisagreement` and the `Franchise` validation check are
  both expected to essentially never fire, based on stated assumptions
  about how JD pricing works. Given this project's track record of
  finding real, rare exceptions to "should never happen" assumptions
  (the header-padding bug, the 21-row `FileNameDateMismatchFlag` rows,
  etc.), both should be checked against real data during implementation,
  not assumed clean.
- Actual refresh time for `Fact_PriceUpdate_Enriched`'s branch-collapsing
  join across 5.1M+ raw rows is unknown until built — expected to be
  meaningfully faster than a naive per-row enrichment would have been
  (given the new grain drastically reduces output row count), but not
  yet measured.

## Out of scope for this phase

- Any specific margin calculation, KPI, or report built on top of these
  facts.
- Reconciliation or a unified view combining both fact tables.
- Point-in-time / historical `dim_Parts` snapshots.
- Incremental refresh (documented as a future option only).
