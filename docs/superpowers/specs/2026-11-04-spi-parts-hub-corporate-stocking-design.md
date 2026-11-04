# SPI Parts Hub: Corporate Stocking, one-row-per-part Inventory reports (design)

> **Status:** design approved by Brian, 2026-11-04 (brainstorm). Next: the implementation plan (Plan O, app 0.14.0).
> **Origin:** the Inventory reports spec `2026-11-03-spi-parts-hub-inventory-reports-design.md` (L-D8 order) and the
> cross-branch spec `2026-11-03-spi-parts-hub-cross-branch-reports-design.md` (M-D4); the workbook
> `projects/corp parts excel reports/SPI Corparate Stocking/SPI Corparate Stocking.pq`.
> **Builds on:** 0.13.0 (Plan M): idle JD records (contract v7), the condition engine with pools and any-of groups.

## Goal

The Corporate Stocking workbook as a built-in Inventory report that matches Excel, and editable copies. Unlike the
earlier three it lists **one row per part** (no branch), so the engine learns a part-grain report.

## Decisions (Brian, 2026-11-04)

| # | Decision |
|---|---|
| O-D1 | **Full condition lists** for part-grain reports (option A), not a fixed form or fixed Gold results. |
| O-D2 | **The query's code is the truth** (as M-D2). |
| O-D3 | **No Fabric or publish changes:** Gold and contract v7 already carry every record and Corp demand the report needs. |

## What the workbook does (from the code)

A part is listed when:
- **Counted records:** its franchise D records at branches other than 2 and 4 that pass the four part filters
  (Package qty = 1, Return indicator R, Source not AN, SLC not starting 21/90/91/99). A record that fails them
  doesn't count either way. The part needs at least one counted record.
- **Every counted record** has on hand = 0, on order = 0 (not just ≤ 0) and Super To blank.
- **Demand:** Corp demands (the shared rule) at branches other than 2 and 4, whatever that branch's record looks
  like; at least **3 branches** with a demand.

Columns: PartNumber, Description, Cost, Source, SLC, CommodityCode, DealerGroupCode (the largest value over the counted
records, SQL `MAX`), OnOrder (0), OnHandQty (0), **R18 Demands** (sum), **Count of Locations with Demands**,
**Locations with Demands** (branch codes sorted by number, non-numbers last, ", "-separated). Sort: count of
locations desc, R18 Demands desc, PartNumber.

**Probe, 2026-11-04** (Prod Silver of 11-04, as of 15:03, against Brian's 15:03 refresh): 1,810 of Excel's 1,820
parts matched, all with identical demands, location counts and lists; 10 only in Excel and 9 only in ours (a day of
Equip changes between JD's evening copy and the live refresh; to explain at the Excel gate). 17 parts depend on idle
records (a Super To at a branch with no activity). Every Corp demand sits at a branch that has a part record, so
per-record CorpDemands loses nothing.

**Description case (O-D4):** branches spell some descriptions differently by case ("VALVE" / "Valve"); SQL Anywhere's
`MAX` treats them as equal and its pick isn't predictable (564 parts differ only by case). Ours: the largest ignoring
case; among case variants, the one at the lowest branch (numeric order). The Excel comparison treats a case-only
description difference as a match. The other text columns take the plain largest value (no case variants found).

## 1. Engine: part-grain reports

`InventoryReportDef` gains `grain: 'part'` (absent = today's branch grain) and, for part grain, four condition lists
(each with any-of groups, like today):

1. **Records that count** (`counted`): which records belong to the part.
2. **Every counted record must** (`every`): every counted record passes (a part with no counted record is out).
3. **Demand counts where** (`demandAt`): which records' Corp demands count; each branch counts once (twins: the max,
   as the pool does).
4. **Parts to show** (`conditions`): part-level conditions on the part fields below.

**Part fields** (computed per part, usable in list 4 and as columns): R18 demands, Branches with demand, Locations
with demand (text; one of / is not one of / contains a branch), and the part's Description, Cost, Source, SLC,
Commodity code, Commodity group, Dealer group (largest over the counted records, O-D4).

Part-grain reports always run over active + idle records (loading the idle files, as `includeIdle`). Performance:
one pass groups records by trimmed upper-case part number; O(records).

**Built-in Corporate Stocking:** counted = Branch not one of 2, 4 · Package qty = 1 · Return indicator is R ·
Source is not AN · SLC doesn't start with 21, 90, 91, 99; every = On hand = 0 · On order = 0 · Super To is blank;
demandAt = Branch not one of 2, 4; parts to show = Branches with demand ≥ 3.

**Stored format:** part-grain reports are saved as `{v:3, grain:'part', counted, every, demandAt, conditions}`;
v1/v2 reports parse and behave as before. 0.13.x can't read v3 (release note: deploy 0.14.0 first).

## 2. Screens, file, checks

- **Results:** the workbook's 12 columns and sort; the branch filter becomes **Demand at branch** (parts with a
  demand there); search (part number or description); row count and total cost as today. A row opens a panel listing
  every branch's record (on hand, on order, Super To, Corp demands) and whether it counted (and, if not, which list
  left it out).
- **CSV:** the workbook's headings.
- **List page:** the Count button (loads the idle files), as 2 & 4 Cotton.
- **Editor:** for a part-grain report, the four cards in order; Copy as my own works as today. A new report chooses
  its grain when it is created (one row per branch / one row per part).
- **Errors:** as today (missing idle files → "Parts with no activity aren't in today's data yet"; a field the data
  doesn't carry → can't be checked).

## Testing and release

- Reference check `corp_parts_check.py --report stocking` (the workbook SQL in DuckDB, as above) with
  `--compare-xlsx` (case-blind description).
- Vitest: each list's semantics (a failing record outside `counted` doesn't block; one counted record with on hand
  blocks; demand from a record outside `counted` still counts; twins once; idle Super To blocks), part fields
  (sums, location order, O-D4), the built-in against one-fail-each mock parts, v1/v2 reports unchanged, the editor and
  results page; a click-through; try-it notes.
- **Excel gate before Ben:** Brian refreshes the workbook in the evening; compare with the next morning's Prod; every
  difference explained by part.
- Release: app 0.14.0 to Fedora only (no Fabric, no publish change).

## Later

Pieces In Set (the last F4 workbook in the L-D8 order); Scrap and COTTON Trouble Parts are placed later.
