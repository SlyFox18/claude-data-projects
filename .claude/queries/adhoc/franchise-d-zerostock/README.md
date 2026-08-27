# Franchise D - Zero Stock, Company-Wide Demand (Ad Hoc)

**Requested by:** Ben (Corp Parts Manager) via Brian, 2026-08-27
**Purpose:** Company-wide reorder-candidate view - Franchise D parts with
ZERO on-hand and ZERO on-order at every branch, that still generate demand
at 3+ distinct branches. Different grain from the branch-level sibling
report (`../FranchiseD_LowDemand_Parts_CrossBranch.pq`) - that one flags a
low-demand *branch* against a specific candidate list; this one drops
Branch entirely and looks at the whole company per part.

## Why this is a script, not a Power Query

The equivalent SQL was first built as an ad-hoc `.pq` query against the live
ODBC source (`../FranchiseD_ZeroStock_CompanyWide.pq`, kept for history/
reference - do not use it as-is, see its own header for the full story). It
hung for 30+ minutes, twice, even with ODBC capacity confirmed fine.

Diagnosed by running the real numbers against the Lakehouse copies of the
same tables:

| Stage | Row count |
|---|---|
| `jdis_Part_Information` total | 1,110,498 |
| ...filtered to `Franchise = 'D'` | 886,523 (**80%** of the whole table) |
| ...+ eligibility filters | 516,567 rows / 109,240 distinct parts |
| `InTrans_Incremental`, demand-def filtered | 770,691 rows / 59,830 parts |
| Parts passing zero-stock-everywhere | 90,492 |
| Final (`LocationCount >= 3`) | **3,118** |

This isn't a badly-written query - Franchise D is ~80% of the entire parts
catalog, so unlike the branch-level report (which narrows to 5 of 47
branches, ~10%), this one can't meaningfully restrict scope and has to touch
500K-900K+ rows on both sides. DuckDB over OneLake (columnar) runs the whole
pipeline in well under a minute; `dsn=EquipRDB64` (row-store OLTP over an
ODBC network bridge) does not, and no SQL rewrite fixes that - it's a scale
problem, not a query-shape problem.

**Trade-off:** this is run-on-demand, not a live-refreshing Power Query in
the workbook. Data is as fresh as the last Lakehouse dataflow run (jdis
refreshes 3x/day; `InTrans_Incremental` on the nightly pipeline) - not
live-ODBC-fresh, but should be plenty fresh for a reorder-candidate scan.

## Method

`build_report.py` queries the `LH_Master_Data` lakehouse directly via DuckDB
over OneLake (`delta_scan`, Azure CLI credential chain) - same pattern as
`../kurt-sales/build_report.py`.

- **Eligibility (jdis_Part_Information):** Franchise D, branches 2 & 4
  excluded, Package Qty = 1, Return Indicator = 'R', Source <> 'AN', SLC not
  in 21%/90%/91%/99% families, AND zero on-hand + zero on-order at **every**
  remaining branch that carries the part (not summed across branches).
- **Demand (InTrans_Incremental):** customer invoice (Type = 'I'), Qty > 0,
  Franchise D, branches 2 & 4 excluded, 7 days to 18 months back - same
  demand definition and branch exclusion as the branch-level report.
- **Filter:** `LocationCount >= 3` (distinct branches with real demand) -
  no floor on total demand magnitude (Ben asked for this to be removed).

## Confirmed with Ben (2026-08-27, via Brian)

1. **On Hand = 0** - CONFIRMED: every branch showing exactly 0, not the sum
   across branches. A part with +5 at one branch and -5 at another is
   excluded here.
2. **On Order = 0** - CONFIRMED: same "every branch = 0" treatment as #1.
3. **Branch scope** - CORRECTED: branches 2 & 4 ARE excluded here too, same
   as the branch-level report. This was the one thing Brian's original
   guess ("include all branches") got wrong - fixed 2026-08-27, which
   changed the result count from 3,118 to 1,809.
4. **Source/SLC exclusions and the 7-day-18-month window** - CONFIRMED,
   carried over identically from the branch-level report.
5. **Judgment call (not explicitly discussed)** - a branch excluded by
   Source/SLC, or now by the 2/4 exclusion, is treated as irrelevant to the
   "zero stock everywhere" check (its stock doesn't disqualify the part).

## Output

`Franchise D - Zero Stock Company-Wide Demand.xlsx` - single tab, one row
per qualifying part: PartNumber, Description, Cost, Source, SLC,
CommodityCode, DealerGroupCode, OnOrder (always 0), OnHandQty (always 0),
TotalDemand, LocationCount. Sorted by LocationCount desc, then TotalDemand
desc.

## Results (as of 2026-08-27 run, branches 2 & 4 excluded)

- 1,809 parts meet all criteria (was 3,118 before Ben confirmed 2 & 4
  should be excluded - see Confirmed Answers above)

Re-run `build_report.py` from this folder any time for a refreshed pull
(requires `fab auth login` and `az login` to be active).
