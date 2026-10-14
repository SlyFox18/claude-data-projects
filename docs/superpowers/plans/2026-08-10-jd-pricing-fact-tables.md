# JD Pricing Fact Tables (Sub-project 3, Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build two enriched fact tables (`Fact_PriceUpdate_Enriched`, `Fact_JDNationalChangeReport_Enriched`) that join the two existing raw JD pricing tables to `dim_Parts` for classification enrichment, with `Fact_PriceUpdate_Enriched` additionally collapsing branch-level rows down to a `PartNumber + EffectiveDate` grain with an `AffectedBranchCount` column.

**Architecture:** Each fact is a Power Query M transformation (Dataflow Gen2) reading from an already-ingested Lakehouse table (not files), joined to `dim_Parts` on a normalized `PartNumber`. Before writing each M query, its core logic (grouping/join behavior) is prototyped and verified in SQL directly against the real production data via DuckDB + OneLake `delta_scan` — proving the logic is correct using real numbers before it's ever pasted into Fabric, rather than writing M on faith and discovering problems during manual UI testing later.

**Tech Stack:** Power Query M (Fabric Dataflow Gen2), Python + DuckDB (verification only, not part of the production pipeline), Fabric Pipelines (scheduling).

---

## Task 1: Prototype and verify `Fact_PriceUpdate_Enriched` logic via DuckDB

**Files:**
- Create: `projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py`

This task proves the grouping/dedup logic works correctly against real data
*before* writing a single line of M code. `Raw_PriceUpdate_History` and
`dim_Parts` are both already-materialized Delta tables in `LH_Master_Data`,
so this is directly queryable right now via the same DuckDB/OneLake pattern
already established in `.claude/queries/adhoc/kurt-sales/build_report.py`
(same workspace/lakehouse GUIDs, same `delta_scan` + Azure CLI credential
chain approach).

- [ ] **Step 1: Write the verification script**

```python
"""
Verifies the Fact_PriceUpdate_Enriched grouping/dedup logic against real
production data via DuckDB + OneLake delta_scan, BEFORE the equivalent
Power Query M logic is written. Confirms:
  1. Collapsing Raw_PriceUpdate_History from Branch+PartNumber+EffectiveDate
     grain to PartNumber+EffectiveDate grain produces a meaningfully smaller
     row count.
  2. AffectedBranchCount (count of distinct rolled-up Branch values per
     PartNumber+EffectiveDate group) matches a real, manually-confirmed
     example: PartNumber 57M11134 on EffectiveDate 2026-08-03 was
     confirmed (via the Fabric table preview, 2026-08-10) to span exactly
     15 branches. NOTE: if this script is run well after 2026-08-10, this
     specific historical row's AffectedBranchCount should still read 15 --
     it's a fixed historical price event, not something that grows over
     time. If it does NOT read 15, investigate before proceeding --
     that's a signal the grouping logic doesn't match what was manually
     observed in Fabric.
  3. HasBranchPriceDisagreement (branches disagreeing on price fields for
     the same PartNumber+EffectiveDate) fires rarely/never, per the raw
     table's own documented assumption that branch doesn't affect price.
  4. Franchise is consistently 'D' both within Raw_PriceUpdate_History
     itself (across every branch row for a given part+date) and against
     dim_Parts' own Franchise column for the same PartNumber.

Run manually -- not part of any scheduled pipeline. This script's job is
finished once its output has been reviewed; it does not need to be kept
running long-term (though there's no harm leaving it in the repo as a
reference for how the M query's logic was validated).
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

con.execute(f"""
    CREATE OR REPLACE TEMP VIEW normalized AS
    SELECT
        UPPER(TRIM(PartNumber)) AS PartNumber,
        EffectiveDate,
        Branch,
        Franchise,
        Category,
        ManufacturerListPrice, DealerListPrice, ListPriceChangePercent,
        ManufacturerReplacePrice, DealerReplacePrice, ManufacturerSellPrice1,
        DealerSellPrice1, SellPriceOld, CostDiff, ListDiff, SellPrice1Diff,
        UpdateCode, HasTypeConversionIssue
    FROM delta_scan('{base}/Raw_PriceUpdate_History')
""")

raw_row_count = con.execute("SELECT COUNT(*) FROM normalized").fetchone()[0]

con.execute("""
    CREATE OR REPLACE TEMP VIEW grouped AS
    SELECT
        PartNumber,
        EffectiveDate,
        COUNT(DISTINCT Branch) AS AffectedBranchCount,
        (COUNT(DISTINCT ManufacturerListPrice) > 1
            OR COUNT(DISTINCT DealerListPrice) > 1
            OR COUNT(DISTINCT ListPriceChangePercent) > 1
            OR COUNT(DISTINCT ManufacturerReplacePrice) > 1
            OR COUNT(DISTINCT DealerReplacePrice) > 1
            OR COUNT(DISTINCT ManufacturerSellPrice1) > 1
            OR COUNT(DISTINCT DealerSellPrice1) > 1
            OR COUNT(DISTINCT SellPriceOld) > 1
            OR COUNT(DISTINCT CostDiff) > 1
            OR COUNT(DISTINCT ListDiff) > 1
            OR COUNT(DISTINCT SellPrice1Diff) > 1
            OR COUNT(DISTINCT UpdateCode) > 1) AS HasBranchPriceDisagreement,
        BOOL_OR(HasTypeConversionIssue) AS HasTypeConversionIssue,
        COUNT(DISTINCT Franchise) AS DistinctFranchiseCountWithinGroup
    FROM normalized
    GROUP BY PartNumber, EffectiveDate
""")

grouped_row_count = con.execute("SELECT COUNT(*) FROM grouped").fetchone()[0]

print(f"1. ROW COUNT: raw={raw_row_count:,}  grouped={grouped_row_count:,}  "
      f"reduction={(1 - grouped_row_count / raw_row_count):.1%}")
print("   Expect grouped to be meaningfully smaller than raw (branches genuinely fan out).")

sample = con.execute("""
    SELECT PartNumber, EffectiveDate, AffectedBranchCount, HasBranchPriceDisagreement
    FROM grouped
    WHERE PartNumber = '57M11134' AND EffectiveDate = DATE '2026-08-03'
""").fetchall()
print(f"\n2. KNOWN EXAMPLE (57M11134 / 2026-08-03): {sample}")
print("   Expect AffectedBranchCount = 15, HasBranchPriceDisagreement = False.")

disagreement = con.execute("""
    SELECT SUM(CASE WHEN HasBranchPriceDisagreement THEN 1 ELSE 0 END) AS DisagreementCount,
           COUNT(*) AS TotalGroups
    FROM grouped
""").fetchone()
print(f"\n3. DISAGREEMENT CHECK: {disagreement[0]:,} of {disagreement[1]:,} groups "
      f"({disagreement[0] / disagreement[1]:.4%}) have HasBranchPriceDisagreement = True.")
print("   Expect this to be zero or very close to zero.")

franchise_check = con.execute(f"""
    SELECT r.Franchise AS RawFranchise, d.Franchise AS DimPartsFranchise, COUNT(*) AS RowCount
    FROM delta_scan('{base}/Raw_PriceUpdate_History') r
    LEFT JOIN delta_scan('{base}/dim_Parts') d
        ON UPPER(TRIM(r.PartNumber)) = d.PartNumber
    GROUP BY r.Franchise, d.Franchise
    ORDER BY RowCount DESC
""").fetchall()
print(f"\n4. FRANCHISE CONSISTENCY CHECK (raw vs dim_Parts):")
for row in franchise_check:
    print(f"   RawFranchise={row[0]!r}  DimPartsFranchise={row[1]!r}  RowCount={row[2]:,}")
print("   Expect a single row: RawFranchise='D', DimPartsFranchise='D'.")
print("   Any other row is a real exception worth investigating before building the M query.")
```

- [ ] **Step 2: Run the script**

Run: `python projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py`

Expected: four sections of output, as documented in the script's own print
statements above. Specifically check:
- Section 1: `grouped` row count is meaningfully smaller than `raw` row
  count (confirms branches really do fan out, validating the whole premise
  of this fact table's redesign).
- Section 2: the 57M11134 / 2026-08-03 example shows `AffectedBranchCount
  = 15` and `HasBranchPriceDisagreement = False`. If this doesn't match,
  STOP and investigate before proceeding to Task 2 -- this is a real,
  independently-confirmed data point (from the Fabric table preview) that
  the grouping logic must reproduce exactly.
- Section 3: disagreement count is zero or very close to it.
- Section 4: shows a single row, `RawFranchise='D'`, `DimPartsFranchise='D'`.
  If other rows appear, note them -- they'll need to be mentioned in
  `Fact_PriceUpdate_Enriched.pq`'s header comment in Task 2 as a confirmed
  real exception, not silently ignored.

If any of these checks come back unexpected, do not proceed to Task 2 with
unresolved discrepancies -- report back what was found so the design can be
revisited if needed.

- [ ] **Step 3: Commit**

```bash
git add projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py
git commit -m "Add DuckDB verification script for Fact_PriceUpdate_Enriched grouping logic"
```

---

## Task 2: Write `Fact_PriceUpdate_Enriched.pq`

**Files:**
- Create: `projects/jd-price-updates/queries/fact-tables/Fact_PriceUpdate_Enriched.pq`

This is the actual M query, transcribing the logic proven in Task 1 into
Power Query. Reference copy only -- see the "reference copy, not live sync"
caveat already established for this project's other `.pq` files.

- [ ] **Step 1: Write the query**

```
/*
============================================================================
Query: Fact_PriceUpdate_Enriched
Dataflow: df_Fact_PriceUpdate_Enriched
Location: LH_Master_Data → Dataflows (fact-tables folder, or alongside
other JD price update dataflows -- see Fabric workspace organization)
============================================================================

PURPOSE: Enriched, deduplicated fact table built from Raw_PriceUpdate_History
+ dim_Parts. Part of sub-project 3 phase 1 (foundational fact layer) -- see
docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md. What
specific analysis/KPIs get built on top of this fact is explicitly out of
scope for this query.

GRAIN: One row per PartNumber + EffectiveDate -- NOT Branch + PartNumber +
EffectiveDate + SourceFileName like the raw table. Confirmed with Brian and
Ben (2026-08-10): branch doesn't affect price, only assortment, so
collapsing across branches removes an assortment artifact that was never
analytically meaningful for pricing questions, and AffectedBranchCount
below captures exactly the "how many branches" signal that's actually
useful. This logic was verified against real production data via
projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py
BEFORE this query was written -- see that script for the SQL-equivalent
proof, including a confirmed real example (PartNumber 57M11134,
EffectiveDate 2026-08-03, AffectedBranchCount = 15).

SOURCE: Two Lakehouse table connectors within this same dataflow (via
"Get Data > Lakehouse > Tables", which names the resulting query after the
table itself, unlike the Files connector sub-projects 1/2 use -- no
placeholder renaming needed here): `Raw_PriceUpdate_History` and
`dim_Parts`.

REFRESH: Daily, full Replace (not Append) -- this is a derived/enriched
rebuild of the ENTIRE source table on every refresh, not new-rows-only.
Scheduled after both Raw_PriceUpdate_History (harvested daily 02:00) and
dim_Parts have refreshed. See Fabric Pipeline setup in the implementation
plan's Task 10.

PARTNUMBER NORMALIZATION: dim_Parts normalizes PartNumber with
Text.Upper(Text.Trim(...)); Raw_PriceUpdate_History does neither. A naive
join on PartNumber as-is would silently under-match real, carried parts
purely from casing/whitespace differences. This query normalizes
PartNumber to dim_Parts' convention before joining -- the underlying raw
table is not touched.

DROPPED COLUMNS (present in Raw_PriceUpdate_History, not carried into this
fact): Branch, SourceFileBranch, BinLocation, OnHandQty, SourceFileName,
SourceFileDate, BranchMismatchFlag, PartDescription (raw), Franchise (raw).
Branch/file-level detail remains available in Raw_PriceUpdate_History
itself if ever needed -- this fact intentionally doesn't duplicate it.

PARTDESCRIPTION: the raw table's own PartDescription varies inconsistently
by branch/file (confirmed a leftover artifact, not meaningful data, by Ben
2026-08-10) -- replaced here with dim_Parts' Description (standardized).

FRANCHISE: not persisted as a column here (all JD parts are expected to
have Franchise = 'D', so a column would carry no distinguishing
information). Validated instead via
verify_fact_priceupdate_enriched.py's Franchise consistency check (see
that script's Section 4) -- confirmed [FILL IN AFTER RUNNING TASK 1:
either "consistently 'D' across both raw and dim_Parts, no exceptions
found" or a description of whatever exception was found].

HASBRANCHPRICEDISAGREEMENT: safety-net flag -- true if the branch rows
being collapsed for a given PartNumber+EffectiveDate don't actually agree
on price/change fields. Per the raw table's own documented assumption
("branch does not affect pricing values, only assortment"), expected to
be rare-to-never -- confirmed via verify_fact_priceupdate_enriched.py
Section 3 at build time: [FILL IN AFTER RUNNING TASK 1: the disagreement
count/percentage observed]. This project has repeatedly found real
exceptions to "should never happen" assumptions elsewhere (JD's row-shift
defect, the header-padding bug, the FileNameDateMismatchFlag hits), so
this flag stays in place as cheap insurance rather than being removed as
"obviously always false."

NO CURRENT-SNAPSHOT VALUES: dim_Parts is a current snapshot, not
point-in-time history. Adding today's SellPrice1/InventoryCost/etc. onto a
historical price-change row (some back to 2008) would misleadingly invite
"today's price" being used to compute a "margin at the time." Deliberately
excluded -- see design spec.
============================================================================
*/

let
    // Placeholder names -- these come from this dataflow's own "Get Data >
    // Lakehouse > Tables" wizard steps, which name the resulting query
    // after the table itself (Raw_PriceUpdate_History, dim_Parts).
    Source = Raw_PriceUpdate_History,

    NormalizePartNumber = Table.TransformColumns(Source, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ------------------------------------------------------------------
    // Collapse Branch + PartNumber + EffectiveDate + SourceFileName grain
    // down to PartNumber + EffectiveDate. See GRAIN note above.
    // ------------------------------------------------------------------
    GroupedByPartAndDate = Table.Group(NormalizePartNumber, {"PartNumber", "EffectiveDate"}, {
        {"AffectedBranchCount", each List.Count(List.Distinct(List.RemoveNulls([Branch]))), Int64.Type},
        {"Category", each List.First(List.RemoveNulls([Category]), null), type nullable text},
        {"ManufacturerListPrice", each List.First(List.RemoveNulls([ManufacturerListPrice]), null), type nullable number},
        {"DealerListPrice", each List.First(List.RemoveNulls([DealerListPrice]), null), type nullable number},
        {"ListPriceChangePercent", each List.First(List.RemoveNulls([ListPriceChangePercent]), null), type nullable number},
        {"ManufacturerReplacePrice", each List.First(List.RemoveNulls([ManufacturerReplacePrice]), null), type nullable number},
        {"DealerReplacePrice", each List.First(List.RemoveNulls([DealerReplacePrice]), null), type nullable number},
        {"ManufacturerSellPrice1", each List.First(List.RemoveNulls([ManufacturerSellPrice1]), null), type nullable number},
        {"DealerSellPrice1", each List.First(List.RemoveNulls([DealerSellPrice1]), null), type nullable number},
        {"SellPriceOld", each List.First(List.RemoveNulls([SellPriceOld]), null), type nullable number},
        {"CostDiff", each List.First(List.RemoveNulls([CostDiff]), null), type nullable number},
        {"ListDiff", each List.First(List.RemoveNulls([ListDiff]), null), type nullable number},
        {"SellPrice1Diff", each List.First(List.RemoveNulls([SellPrice1Diff]), null), type nullable number},
        {"UpdateCode", each List.First(List.RemoveNulls([UpdateCode]), null), type nullable text},
        {"HasTypeConversionIssue", each List.AnyTrue([HasTypeConversionIssue]), type logical},
        {"HasBranchPriceDisagreement", each
            List.Count(List.Distinct(List.RemoveNulls([ManufacturerListPrice]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([DealerListPrice]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([ListPriceChangePercent]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([ManufacturerReplacePrice]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([DealerReplacePrice]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([ManufacturerSellPrice1]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([DealerSellPrice1]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([SellPriceOld]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([CostDiff]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([ListDiff]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([SellPrice1Diff]))) > 1 or
            List.Count(List.Distinct(List.RemoveNulls([UpdateCode]))) > 1,
        type logical}
    }),

    // ------------------------------------------------------------------
    // IngestedAt -- freshly computed at THIS fact's build time (not
    // carried from raw rows' IngestedAt, which becomes ambiguous once
    // multiple branch rows collapse into one group). DST-aware UTC ->
    // Central, same pattern as .claude/queries/DATA-REFRESH-TEMPLATE.pq
    // ------------------------------------------------------------------
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    AddIngestedAt = Table.AddColumn(GroupedByPartAndDate, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Enrich with dim_Parts classification columns. Left outer join --
    // dim_Parts guarantees PartNumber uniqueness (its own final
    // deduplication step), so this cannot fan out rows.
    // ------------------------------------------------------------------
    JoinWithDimParts = Table.NestedJoin(AddIngestedAt, {"PartNumber"}, dim_Parts, {"PartNumber"}, "DimPartsMatch", JoinKind.LeftOuter),

    ExpandDimParts = Table.ExpandTableColumn(JoinWithDimParts, "DimPartsMatch",
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"},
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"}),

    AddIsCarriedLocally = Table.AddColumn(ExpandDimParts, "IsCarriedLocally", each [SLC] <> null, type logical),

    FinalColumnOrder = Table.ReorderColumns(AddIsCarriedLocally, {
        "PartNumber", "EffectiveDate", "Description", "Category",
        "ManufacturerListPrice", "DealerListPrice", "ListPriceChangePercent",
        "ManufacturerReplacePrice", "DealerReplacePrice", "ManufacturerSellPrice1",
        "DealerSellPrice1", "SellPriceOld", "CostDiff", "ListDiff", "SellPrice1Diff",
        "UpdateCode", "AffectedBranchCount", "HasBranchPriceDisagreement",
        "HasTypeConversionIssue", "Source", "SLC", "DealerGroupCode", "CommodityCode",
        "VendorCode", "IsCarriedLocally", "IngestedAt"
    })
in
    FinalColumnOrder
```

- [ ] **Step 2: Fill in the two `[FILL IN AFTER RUNNING TASK 1: ...]` placeholders**

Using Task 1's actual script output, replace both bracketed placeholders in
the header comment (`FRANCHISE:` and `HASBRANCHPRICEDISAGREEMENT:` sections)
with the real observed values -- e.g. "confirmed consistently 'D' across
5,096,264 rows and every matched dim_Parts row, no exceptions found" or, if
exceptions were found, a factual description of what they were.

- [ ] **Step 3: Commit**

```bash
git add projects/jd-price-updates/queries/fact-tables/Fact_PriceUpdate_Enriched.pq
git commit -m "Add Fact_PriceUpdate_Enriched query (branch-collapsed, dim_Parts-enriched)"
```

---

## Task 3: Prototype and verify `Fact_JDNationalChangeReport_Enriched` logic via DuckDB

**Files:**
- Create: `projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py`

Simpler than Task 1 -- no grouping/dedup needed here, just confirming the
`dim_Parts` join and `IsCarriedLocally` flag behave as expected.

- [ ] **Step 1: Write the verification script**

```python
"""
Verifies the Fact_JDNationalChangeReport_Enriched dim_Parts join/enrichment
logic against real production data via DuckDB + OneLake delta_scan, BEFORE
the equivalent Power Query M logic is written. Confirms:
  1. Row count is unchanged from the raw table (this fact doesn't
     regrain/dedup -- unlike Fact_PriceUpdate_Enriched).
  2. IsCarriedLocally is mostly False (most national Deere parts aren't
     carried at South Plains) but genuinely True for at least some rows
     (confirming the join actually finds real matches, not silently
     failing entirely).

Run manually -- not part of any scheduled pipeline.
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

raw_row_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Raw_JDNationalChangeReport_History')
""").fetchone()[0]

carried_check = con.execute(f"""
    SELECT
        d.PartNumber IS NOT NULL AS IsCarriedLocally,
        COUNT(*) AS RowCount
    FROM delta_scan('{base}/Raw_JDNationalChangeReport_History') r
    LEFT JOIN delta_scan('{base}/dim_Parts') d
        ON UPPER(TRIM(r.PartNumber)) = d.PartNumber
    GROUP BY d.PartNumber IS NOT NULL
    ORDER BY IsCarriedLocally
""").fetchall()

joined_row_count = sum(row[1] for row in carried_check)

print(f"1. ROW COUNT: raw={raw_row_count:,}  joined={joined_row_count:,}")
print("   Expect these to be EQUAL -- this fact doesn't regrain, only enriches.")

print(f"\n2. IsCarriedLocally DISTRIBUTION:")
for row in carried_check:
    print(f"   IsCarriedLocally={row[0]}  RowCount={row[1]:,}")
print("   Expect the majority to be False (most national parts aren't carried "
      "locally), but at least some True rows confirming the join actually "
      "finds real matches, not silently failing entirely.")
```

- [ ] **Step 2: Run the script**

Run: `python projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py`

Expected: Section 1 shows `raw` and `joined` row counts exactly equal.
Section 2 shows both `True` and `False` rows present, with `False`
substantially outnumbering `True`. If `joined` is not exactly equal to
`raw`, STOP -- that would mean the join is unexpectedly fanning out or
dropping rows, and needs investigation before Task 4. If every row shows
`IsCarriedLocally=False` with zero `True` rows, that's also worth
investigating -- it would suggest the join isn't matching anything at all
(e.g. a normalization bug), not that South Plains genuinely carries none
of these parts.

- [ ] **Step 3: Commit**

```bash
git add projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py
git commit -m "Add DuckDB verification script for Fact_JDNationalChangeReport_Enriched"
```

---

## Task 4: Write `Fact_JDNationalChangeReport_Enriched.pq`

**Files:**
- Create: `projects/jd-price-updates/queries/fact-tables/Fact_JDNationalChangeReport_Enriched.pq`

- [ ] **Step 1: Write the query**

```
/*
============================================================================
Query: Fact_JDNationalChangeReport_Enriched
Dataflow: df_Fact_JDNationalChangeReport_Enriched
Location: LH_Master_Data → Dataflows (fact-tables folder, or alongside
other JD price update dataflows -- see Fabric workspace organization)
============================================================================

PURPOSE: Enriched fact table built from Raw_JDNationalChangeReport_History
+ dim_Parts. Part of sub-project 3 phase 1 (foundational fact layer) -- see
docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md. What
specific analysis/KPIs get built on top of this fact is explicitly out of
scope for this query.

GRAIN: Unchanged from raw -- one row per PartNumber + EffectiveDate +
SourceFileName. Unlike Fact_PriceUpdate_Enriched, this source never had a
branch dimension to begin with, so there's nothing to collapse. Verified
against real production data via
projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py
BEFORE this query was written -- confirmed row count is unchanged from the
raw table and the dim_Parts join finds genuine matches (not silently
failing entirely).

SOURCE: Two Lakehouse table connectors within this same dataflow (via
"Get Data > Lakehouse > Tables"): `Raw_JDNationalChangeReport_History` and
`dim_Parts`.

REFRESH: Weekly, full Replace (not Append) -- the source only changes when
Brian manually places a new file (at most weekly, per the Saturday
reminder), so a daily refresh would just spend CU re-deriving identical
data. See Fabric Pipeline setup in the implementation plan's Task 10.

PARTNUMBER NORMALIZATION: same reasoning as Fact_PriceUpdate_Enriched --
dim_Parts normalizes PartNumber with Text.Upper(Text.Trim(...));
Raw_JDNationalChangeReport_History only trims, doesn't uppercase. This
query normalizes to dim_Parts' convention before joining.

ISCARRIEDLOCALLY: expected False for the large majority of rows -- most
national Deere parts aren't carried at South Plains. This is expected, not
a defect. Confirmed via the verification script that both True and False
rows genuinely appear (not a join that silently matches nothing).

IngestedAt IS CARRIED THROUGH FROM RAW, NOT RECOMPUTED: unlike
Fact_PriceUpdate_Enriched (which regrains and therefore needs a fresh
IngestedAt), this fact's grain is unchanged from raw -- each row still
corresponds to exactly one raw row, so its original IngestedAt value
remains meaningful and is passed through as-is.

NO CURRENT-SNAPSHOT VALUES: same reasoning as Fact_PriceUpdate_Enriched --
see that query's header comment and the design spec.
============================================================================
*/

let
    // Placeholder names -- these come from this dataflow's own "Get Data >
    // Lakehouse > Tables" wizard steps, which name the resulting query
    // after the table itself (Raw_JDNationalChangeReport_History, dim_Parts).
    Source = Raw_JDNationalChangeReport_History,

    NormalizePartNumber = Table.TransformColumns(Source, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ------------------------------------------------------------------
    // Enrich with dim_Parts classification columns. Left outer join --
    // dim_Parts guarantees PartNumber uniqueness, so this cannot fan out
    // rows (grain stays exactly as in the raw table).
    // ------------------------------------------------------------------
    JoinWithDimParts = Table.NestedJoin(NormalizePartNumber, {"PartNumber"}, dim_Parts, {"PartNumber"}, "DimPartsMatch", JoinKind.LeftOuter),

    ExpandDimParts = Table.ExpandTableColumn(JoinWithDimParts, "DimPartsMatch",
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"},
        {"Description", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"}),

    AddIsCarriedLocally = Table.AddColumn(ExpandDimParts, "IsCarriedLocally", each [SLC] <> null, type logical),

    FinalColumnOrder = Table.ReorderColumns(AddIsCarriedLocally, {
        "PartNumber", "EffectiveDate", "Description", "CurrentDNP", "CurrentSLP", "NewDNP", "NewSLP",
        "SourceFileName", "SourceFileDate", "FileNameDateMismatchFlag", "HasTypeConversionIssue",
        "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode", "IsCarriedLocally", "IngestedAt"
    })
in
    FinalColumnOrder
```

- [ ] **Step 2: Commit**

```bash
git add projects/jd-price-updates/queries/fact-tables/Fact_JDNationalChangeReport_Enriched.pq
git commit -m "Add Fact_JDNationalChangeReport_Enriched query (dim_Parts-enriched)"
```

---

## Task 5: Update `FACT-TABLES-SUMMARY.md`

**Files:**
- Modify: `.claude/queries/facts/FACT-TABLES-SUMMARY.md`

- [ ] **Step 1: Add a new project section**

Add this new section, placed alphabetically between the existing "Inventory
Analysis" and "Negative On Hand" project sections (matching the file's
existing alphabetical-by-project ordering):

```markdown
### **Project: JD Price Updates (Sub-project 3)**
**Location:** `projects/jd-price-updates/queries/fact-tables/`
**Department:** Parts
**Created:** 08/10/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PriceUpdate_Enriched | df_Fact_PriceUpdate_Enriched | TBD (fewer than Raw_PriceUpdate_History's 5.1M, collapsed to PartNumber+EffectiveDate grain) | TBD | Daily | Branch-collapsed, dim_Parts-enriched price change history for parts sold locally |
| Fact_JDNationalChangeReport_Enriched | df_Fact_JDNationalChangeReport_Enriched | ~48K+ (unchanged grain from raw) | TBD | Weekly | dim_Parts-enriched national Deere price change history (all parts, not just ones carried locally) |

**Raw Tables:** Raw_PriceUpdate_History, Raw_JDNationalChangeReport_History

**Dimensions:** dim_Parts

**Business Context:** Foundational fact layer for JD parts pricing analysis (sub-project 3, phase 1). `Fact_PriceUpdate_Enriched` collapses the raw table's branch-level rows to one row per PartNumber+EffectiveDate with an `AffectedBranchCount` column (how many branches were affected), since branch doesn't affect price, only assortment. `Fact_JDNationalChangeReport_Enriched` keeps the raw table's grain unchanged. Both add `dim_Parts` classification columns (Source, SLC, DealerGroupCode, CommodityCode, VendorCode) and an `IsCarriedLocally` flag. What specific margin/KPI analysis gets built on top of these facts is deferred to a later phase -- see `docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md`.

**Status:** 🚧 In Development

**Recommended Schedule:** Daily for Fact_PriceUpdate_Enriched (matches Raw_PriceUpdate_History's daily harvest), Weekly for Fact_JDNationalChangeReport_Enriched (matches its source's weekly cadence)
```

- [ ] **Step 2: Update the Dimension Usage Matrix**

In the `## 🔗 Dimension Usage Matrix` table, update the `dim_Parts` row's
"Used by # of Projects" and "Used by # of Facts" counts by incrementing
each by 1 (one new project, two new facts using it) and append this
project to its "Example Projects" list:

```markdown
| **dim_Parts** | 10 | ~15 | All parts-focused reports, JD Price Updates |
```

(Replace whatever the current numbers are at the time this task is
executed with those numbers + 1 and + 2 respectively -- read the existing
row first to get the current baseline before incrementing.)

- [ ] **Step 3: Commit**

```bash
git add .claude/queries/facts/FACT-TABLES-SUMMARY.md
git commit -m "Document Fact_PriceUpdate_Enriched and Fact_JDNationalChangeReport_Enriched in fact table registry"
```

---

## Task 6 [MANUAL]: Build `df_Fact_PriceUpdate_Enriched` in Fabric

**This task is performed by Brian in the Fabric UI, not by an agent.**

1. In `LH_Master_Data` workspace, create a new Dataflow Gen2 named
   `df_Fact_PriceUpdate_Enriched`.
2. **Get Data → Lakehouse → Tables** → select `Raw_PriceUpdate_History`.
   This becomes a query named `Raw_PriceUpdate_History` in this dataflow.
3. **Get Data → Lakehouse → Tables** again → select `dim_Parts`. This
   becomes a query named `dim_Parts`.
4. Create a new blank query, open the Advanced Editor, and paste the full
   contents of `Fact_PriceUpdate_Enriched.pq` (from Task 2) -- note this
   file's `Source = Raw_PriceUpdate_History` and the `dim_Parts` reference
   in the join step both refer to the two queries created in steps 2-3
   above by name, so no placeholder renaming is needed here (unlike the
   Files-connector dataflows in sub-projects 1/2).
5. Rename this new query to `Fact_PriceUpdate_Enriched`.
6. Set the destination: **Lakehouse** → `LH_Master_Data` → new table
   `Fact_PriceUpdate_Enriched` → **Replace** (not Append).
7. Publish.

---

## Task 7 [MANUAL]: Verify `Fact_PriceUpdate_Enriched` against Task 1's numbers

**This task is performed by Brian, not by an agent.**

After the dataflow runs, query the SQL analytics endpoint (not the local
OneLake mount -- verify folder/table state via the portal or SQL endpoint,
per this project's established practice) and compare against Task 1's
DuckDB output:

```sql
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN HasBranchPriceDisagreement = 1 THEN 1 ELSE 0 END) AS DisagreementRows,
    SUM(CASE WHEN HasTypeConversionIssue = 1 THEN 1 ELSE 0 END) AS ConversionIssueRows
FROM Fact_PriceUpdate_Enriched;

SELECT PartNumber, EffectiveDate, AffectedBranchCount, HasBranchPriceDisagreement
FROM Fact_PriceUpdate_Enriched
WHERE PartNumber = '57M11134' AND EffectiveDate = '2026-08-03';
```

Expected: `TotalRows` matches Task 1's `grouped` row count from the DuckDB
script (should be very close -- may differ slightly if new raw data landed
between running the script and building the dataflow). The 57M11134 row
should show `AffectedBranchCount = 15`, `HasBranchPriceDisagreement = 0`.
`DisagreementRows` should match Task 1's disagreement count closely.

If these don't line up, do not proceed to Task 8 -- report back what was
found.

---

## Task 8 [MANUAL]: Build `df_Fact_JDNationalChangeReport_Enriched` in Fabric

**This task is performed by Brian, not by an agent.**

Same pattern as Task 6:

1. New Dataflow Gen2: `df_Fact_JDNationalChangeReport_Enriched`.
2. **Get Data → Lakehouse → Tables** → `Raw_JDNationalChangeReport_History`.
3. **Get Data → Lakehouse → Tables** → `dim_Parts`.
4. New blank query → Advanced Editor → paste `Fact_JDNationalChangeReport_Enriched.pq`
   (from Task 4).
5. Rename to `Fact_JDNationalChangeReport_Enriched`.
6. Destination: Lakehouse → `LH_Master_Data` → new table
   `Fact_JDNationalChangeReport_Enriched` → **Replace**.
7. Publish.

---

## Task 9 [MANUAL]: Verify `Fact_JDNationalChangeReport_Enriched` against Task 3's numbers

**This task is performed by Brian, not by an agent.**

```sql
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN IsCarriedLocally = TRUE THEN 1 ELSE 0 END) AS CarriedLocallyRows,
    SUM(CASE WHEN IsCarriedLocally = FALSE THEN 1 ELSE 0 END) AS NotCarriedRows
FROM Fact_JDNationalChangeReport_Enriched;
```

Expected: `TotalRows` matches `Raw_JDNationalChangeReport_History`'s own
row count exactly (this fact doesn't regrain). `CarriedLocallyRows` should
be nonzero but substantially smaller than `NotCarriedRows`, consistent
with Task 3's DuckDB output.

If `TotalRows` doesn't exactly match the raw table's row count, do not
proceed to Task 10 -- report back what was found.

---

## Task 10 [MANUAL]: Schedule refreshes

**This task is performed by Brian, not by an agent.**

1. Add `df_Fact_PriceUpdate_Enriched` to the existing daily facts pipeline
   (or create a small dedicated Fabric Pipeline), scheduled to run after
   both `Raw_PriceUpdate_History`'s daily 02:00 harvest and `dim_Parts`'
   daily refresh have completed.
2. Schedule `df_Fact_JDNationalChangeReport_Enriched` weekly, timed to run
   after the JD Change Report weekly reminder cycle (Saturdays 10:00) --
   e.g. Saturday afternoon or Sunday, giving Brian time to have actually
   downloaded and placed the week's file first.

---

## Task 11: Finalize documentation

**Files:**
- Modify: `projects/jd-price-updates/README.md`

- [ ] **Step 1: Add a new "Sub-project 3 (Phase 1)" section**

Add a new section after the existing "Sub-project 2: JD National Change
Report" section and before "Next Steps", following the same structure
(Status line, Architecture diagram, Fabric objects, Known caveats):

```markdown
## Sub-project 3 (Phase 1): Pricing Fact Tables

Foundational, enriched fact layer joining both raw price-history tables
to `dim_Parts` for classification enrichment. What specific margin/KPI
analysis gets built on top of these facts is deferred to a later phase --
see the design spec for the full rationale.

**Design spec:** `docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md`
**Implementation plan:** `docs/superpowers/plans/2026-08-10-jd-pricing-fact-tables.md`

Status: [FILL IN based on actual completion state at the time this task
runs -- e.g. "live and operating" if Tasks 6-10 are done, or "fact tables
built, refresh scheduling pending" if only some manual tasks are complete].

### Architecture

```
Raw_PriceUpdate_History (5.1M+ rows, branch-tagged)  ─┐
                                                        ├──▶ dim_Parts (join on
Raw_JDNationalChangeReport_History (~48K+ rows)     ──┘     normalized PartNumber)
        │                                                          │
        │ [df_Fact_PriceUpdate_Enriched -- collapses to            │
        │  PartNumber+EffectiveDate, adds AffectedBranchCount]     │
        ▼                                                          │
Fact_PriceUpdate_Enriched                                          │
                                                                    │
        │ [df_Fact_JDNationalChangeReport_Enriched -- grain         │
        │  unchanged from raw]                                     │
        ▼                                                          │
Fact_JDNationalChangeReport_Enriched  ◀────────────────────────────┘
```

### Fabric objects (LH_Master_Data workspace)

- **Dataflow Gen2:** `df_Fact_PriceUpdate_Enriched` -- reads
  `Raw_PriceUpdate_History` + `dim_Parts`, collapses to
  `PartNumber + EffectiveDate` grain, writes to `Fact_PriceUpdate_Enriched`
  with **Update method: Replace**. Reference M code:
  `projects/jd-price-updates/queries/fact-tables/Fact_PriceUpdate_Enriched.pq`.
- **Dataflow Gen2:** `df_Fact_JDNationalChangeReport_Enriched` -- reads
  `Raw_JDNationalChangeReport_History` + `dim_Parts`, grain unchanged,
  writes to `Fact_JDNationalChangeReport_Enriched` with **Update method:
  Replace**. Reference M code:
  `projects/jd-price-updates/queries/fact-tables/Fact_JDNationalChangeReport_Enriched.pq`.
- **Verification scripts** (DuckDB/OneLake, run manually, not scheduled):
  `projects/jd-price-updates/scripts/verify_fact_priceupdate_enriched.py`,
  `projects/jd-price-updates/scripts/verify_fact_jdnationalchangereport_enriched.py`.

### Known caveats (see design spec for full detail)

- `dim_Parts` is a current snapshot -- enrichment columns reflect today's
  classification, not historical truth.
- `IsCarriedLocally = false` dominates `Fact_JDNationalChangeReport_Enriched`
  -- expected, not a defect.
- `HasBranchPriceDisagreement` is a safety-net flag expected to rarely/never
  fire -- see `Fact_PriceUpdate_Enriched.pq`'s header comment for the actual
  observed rate at build time.
```

- [ ] **Step 2: Update "Next Steps"**

Change item 3 in the existing "Next Steps" numbered list from "not
started" to reflect phase 1 completion:

```markdown
3. **Analysis layer** — Phase 1 (foundational fact tables) done. Specific
   margin-impact analysis, KPIs, and slicing by `dim_Parts` classifications
   (SLC, DealerGroupCode, CommodityCode) still to be defined -- a future
   phase 2, once a real analysis need identifies what's actually useful to
   build on top of `Fact_PriceUpdate_Enriched` and
   `Fact_JDNationalChangeReport_Enriched`.
```

- [ ] **Step 3: Commit**

```bash
git add projects/jd-price-updates/README.md
git commit -m "Document sub-project 3 phase 1 (JD pricing fact tables)"
```
