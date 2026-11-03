# SPI Parts Hub: cross-branch Inventory reports, Border Stores and 2 & 4 Cotton (design)

> **Status:** design approved section by section by Brian, 2026-11-03 (brainstorm). Next: the implementation plan
> (Plan M, app 0.13.0).
> **Origin:** the Inventory reports spec `2026-11-03-spi-parts-hub-inventory-reports-design.md` ("Later"); the
> workbooks `projects/corp parts excel reports/Border Stores/Border Stores.pq` and
> `2 & 4 Cotton & Stripper Parts/2 & 4 Cotton & Stripper Parts.pq`.
> **Builds on:** 0.12.0 (Plan L): `Fact_CorpParts_JD`, contract v6 `jd_<branch>` files, the condition engine over a
> catalogue, built-in + Copy as my own.

## Goal

Two more Corp Parts workbooks as built-in Inventory reports that match Excel row for row, and editable copies that
can change which branches are compared, left out or counted. Both workbooks compare a part at one branch with the
same part at the other branches, which 0.12.0's one-row-at-a-time conditions can't express.

## Decisions (Brian, 2026-11-03)

| # | Decision |
|---|---|
| M-D1 | **The engine learns "other branches"** (not fixed Gold figures), so copies can change the branches and thresholds. |
| M-D2 | **The queries' code is the truth**, not their header notes (they're stale after several revisions). Border Stores candidates are 95, 91, 96 with local demand ≥ 1 (the notes say 7, 14, 95, 91, 96 and < 3). |
| M-D3 | **Idle JD records are published too** (Brian: "we will need this in the future anyway"), in separate files loaded only when a report needs them. |
| M-D4 | **Corporate Stocking is a later release** (one row per part, "zero at every branch"); it builds on this. |

## What the workbooks do (from the code)

- **Border Stores.** A row is a branch + part at **95, 91 or 96** with Corp demands **≥ 1**, on hand **< 1** and the
  six part filters¹, where **OtherBranchDemands ≥ 10** and **OtherLocationCount ≥ 5**. The other-branch figures add up
  the part's rows at every branch **except 2 and 4** (and the row's own) that pass the six part filters.
- **2 & 4 Cotton.** The same with the candidates at **2 or 4**, Corp demands **= 0** (its rows come only from the
  zero-fill), and the **cotton rule**² applied to the candidate and to the other-branch rows.

¹ On order = 0, Package qty = 1, Return indicator R, Source not AN, SLC not 21/90/91/99…, Super To blank.
² The row's own dealer group is COTTON, STRIPPER or PICKER, **or** the part number is coded 690, 770, CS690 or JDCS690
at any branch.

A probe on 2026-11-03 against Prod `Fact_CorpParts_JD` and Brian's 14:31 / 14:34 refreshes: Border Stores 1,562 of
1,571 rows matched (9 only in Excel, 17 only in ours, 80 rows with different other-branch figures: to explain); 2 & 4
Cotton 14 of 248, because **234 of its rows are idle records Gold leaves out** (nothing on hand or on order, no sales,
no demand), hence M-D3.

## 1. Engine: other branches, any-of groups

**A report has two condition lists:**
1. **Rows to show** (today's conditions).
2. **Count other branches where** (optional): which JD rows at other branches count.

**Two pool fields**, computed per row from list 2, usable in list 1 and as columns:
- **Other-branch demands:** the sum of Corp demands over rows that pass list 2, with the same trimmed part number,
  at a branch other than the row's own.
- **Other branches with demand:** how many of those rows have Corp demands ≥ 1.

A report without list 2 can't use the pool fields (the editor shows the card once one is used). Each other branch
counts once: trailing-space twin rows at one branch carry the same Corp demands (counted on the trimmed part number)
and SQL Anywhere groups them as one row, so a branch adds its demands once and counts as one branch (corrected
2026-11-03; no twins in today's lists).

**Any-of groups:** a condition can be a group whose lines need only one to match (one level; no groups in groups),
in either list.

**Dealer group at any branch:** a text field (one of / is not one of) true when any JD record of the part number
(active or idle, any branch) has one of the codes, trimmed and case-insensitive.

**Include parts with no activity:** a report switch. Off: the report runs over active JD rows (as today). On: it also
loads the idle files and runs over both. "Dealer group at any branch" always uses both (loading the idle files when a
report uses it).

**Built-ins** (conditions only, no special code):

| | Border Stores | 2 & 4 Cotton |
|---|---|---|
| Rows to show | Branch one of 95, 91, 96 · Corp demands ≥ 1 · On hand < 1 · the six part filters · Other-branch demands ≥ 10 · Other branches with demand ≥ 5 | Branch one of 2, 4 · Corp demands = 0 · On hand < 1 · the six part filters · cotton group · the same two thresholds |
| Count other branches where | Branch not one of 2, 4 · the six part filters | Branch not one of 2, 4 · the six part filters · cotton group |
| No-activity switch | off | on |

Cotton group = any of (Dealer group one of COTTON, STRIPPER, PICKER; Dealer group at any branch one of 690, 770,
CS690, JDCS690).

Columns: the 12 MLPF columns, then Other-branch demands and Other branches with demand. CSV headers: the workbook's
(… Demands, OtherBranchDemands, OtherLocationCount). Sort: part number, then branch.

**Stored format:** a saved report's JSON gains `pool` (conditions), `includeIdle` (boolean) and group conditions.
Reports saved by 0.12.0 parse and behave exactly as before.

## 2. Data, publish, app

**Gold `Fact_CorpParts_JD_Idle`** (Part 5 of `Build_Gold_NonJD_Reorder`): every franchise D record of
Silver_PartInformation that `Fact_CorpParts_JD` leaves out (on hand 0, on order ≤ 0, 24-month sales 0, no Corp
demands). Columns: Branch, Franchise, PartNumber, Description, Cost, OnOrder (0 or negative: the workbooks require
exactly 0, found in the Excel comparison), PackageQty, ReturnIndicator, Source, SLC, SuperTo,
CommodityCode, CommodityGroup, DealerGroupCode, MinimumQty, MaximumQty, BuiltAtUtc. Same grain, guards and rules as
the active table; the two tables never share a key and together hold every franchise D record (asserted in the
notebook). Prod 2026-11-03: about 643,000 records at 40 branches.

**Publish contract v7:** `jd_idle_<branch>.json.gz` per branch (fields as above, camelCase; numbers that are 0 by
definition left out), `_meta.json` `jdIdleBranches` and `counts.jdIdleParts`. Additive. Measured: 11 MB compressed in
all, largest 978 KB (branch 4).

**App 0.13.0:** reads v6 and v7 (on v6 a report needing idle records says "Parts with no activity aren't in today's
data yet"); `useJdIdleBranches()` loads the idle files on demand (same cache rules, 6 at a time); idle rows become
JdRows with on hand, on order, sales and Corp demands 0. The editor gets the "Count other branches where" card, any-of
groups and the no-activity switch; results and the details panel show the pool fields. MLPF Gaps and 0.12.0 copies
are unchanged and never load the idle files.

**Performance:** the pool is computed once per (list 2, data): a map from trimmed part number to the passing rows'
branch and Corp demands; then each candidate row's figures are a lookup. O(rows).

## 3. Testing and release

- **Gold:** run twice; `dag_check`, `hygiene_audit`, pytest; active + idle = all franchise D records, disjoint.
- **Reference check** `corp_parts_check.py`: the idle table; independent Border Stores and 2 & 4 Cotton lists from
  the workbook SQL; `--compare-xlsx` for both workbooks with the other-branch columns.
- **Excel comparison (gate before Ben):** both refreshed workbooks against Prod; every difference explained by part.
- **Publish:** pytest for the idle files and contract v7; a local build checks sizes.
- **App:** Vitest for the pool fields (own branch excluded, only passing rows), any-of groups, dealer group at any
  branch, the switch (idle files load only when needed), both built-ins against one-fail-each mock parts, 0.12.0
  reports unchanged, the editor; a 0.13.0 click-through; a review after each task; try-it notes.
- **Release (same-day pattern):** PR → Deploy DP backend → claim → app 0.13.0 to Fedora first → Prod items run →
  reference check → Gateway `git pull` + publish → Excel comparison → TEST copy checked and deleted → docs.

## Later

Corporate Stocking (part grain); Pieces In Set; a JD Part page; actions from a row.
