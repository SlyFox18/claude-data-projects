# SPI Parts Hub: Pieces In Set, three Inventory reports (design)

> **Status:** design approved by Brian, 2026-11-05. Plan: `docs/superpowers/plans/2026-11-05-spi-parts-hub-pieces-in-set.md` (Plan R).
> **Shipped 2026-11-06:** app 0.16.0 (commit `b7018cc`) on Fedora, publish contract 8, PR #53. Corrected below after the
> build: R-D6's row count and the idle statement. Results are in the plan's Shipped block.
> **Origin:** the Inventory reports spec `2026-11-03-spi-parts-hub-inventory-reports-design.md` (L-D8 order); the workbook
> `projects/corp parts excel reports/SPI-Pieces In Set/` (three queries, plus formula columns in the workbook).
> **Builds on:** 0.15.1. Reports only: nothing appears on the order screens (that is F12, Reason Codes, afterwards).

## Goal

The workbook's three lists as built-in Inventory reports that match Excel, with editable copies.

## Decisions (Brian, with Ben's answers, 2026-11-05)

| # | Decision |
|---|---|
| R-D1 | **Three lists:** the main list, 3 Months or Less, Review. The Buy List can be a copy of the main list; the analysis tabs stay in Excel. |
| R-D2 | **The queries' code and the workbook's formulas are the truth** (as M-D2). |
| R-D3 | **Bin Qty, not On hand**, is the stock in Stock Position and Round Up (Ben's request; Brian, 2026-11-05: keep it). |
| R-D4 | **Box and bulk quantities are labelled only** (PIS Class), not removed (Ben). |
| R-D5 | **Overstocked parts keep their recommendation**, with the Coverage Flag beside it: the report matches Excel and the dollars stay visible. A copy can leave them out; the 3 Months or Less list has none by definition. |
| R-D6 | **Franchise D's own record only.** The query's join ignores franchise, so rows take Bin, On Order or Commodity Code from another franchise's record of the part: **18 rows on 2026-11-06, 19 on 2026-11-05** (the 9 first written here undercounted, because exact ties are arbitrary in the query). The app reads the D record. Listed in `INVENTORY-REPORTS.md`. |
| R-D7 | **Trailing-space twins show once:** the stats go on the record the query's JdisDedup would pick (longest description, then smallest; then smallest part number as stored), so the other twin never qualifies. |
| R-D8 | **Category and Dup Branch+Part? are left out** (a keyword map; a check the dedup made pointless). |

## Probe, 2026-11-05

Prod Silver as of 15:15 against Brian's 15:15 refresh: 3,317 rows on each side, 3,314 shared, 3 only in Excel, 3 only in
ours; set size identical on every shared row; Invoices, Match % and Sales Qty differ on 19 rows and stock on about 100
(today's activity against Prod's morning copy; to explain at the Excel check). Bronze `InMaster.Pieces_In_Set` has the
256 franchise D records above 1 (excluding 2 and 4) that the workbook's notes describe.

## 1. Data (Fabric and publish)

**`Silver_InMaster` gains `PiecesInSet`** (Bronze `Pieces_In_Set`).

**`Fact_CorpParts_JD` gains seven columns**, in `Build_Gold_NonJD_Reorder` Part 5:

| Column | Definition |
|---|---|
| `BinQty` | `Silver_PartInformation.BinQty` |
| `PiecesInSet` | `MAX(Silver_InMaster.PiecesInSet)` over the franchise D rows of the Branch + part (trimmed, upper-case); NULL = none |
| `PisInvoices` | invoices, below; 0 when none |
| `PisSalesQty` | the sum of their net quantities |
| `PisQty` | the most common net quantity (ties: the smaller) |
| `PisQtyInvoices` | the invoices at `PisQty` |
| `PisMultipleInvoices` | the invoices whose net quantity is a whole multiple of `PiecesInSet` (0 when `PiecesInSet` isn't above 1) |

**Invoices:** franchise D, type I with Qty > 0 or type C with Qty < 0, dated 18 months before Gold's `DemandAsOf` through
`DemandAsOf`; grouped by Branch + part + (`RONumber` for I, `OriginalInvoiceNo` for C), kept when the net quantity is
above 0 and there is an I line. Unlike Corp demands, invoices run through "now", not now-7 days. Stats are computed at
every branch (2 and 4 too); the reports' conditions leave those out, so a copy can include them. One record of a twin
pair gets them (R-D7).

The idle table and files don't change. **Corrected in the build:** idle records can have 18-month invoices (about 500 to 572
have 1 or 2 in Prod, mostly recent sales inside Corp demands' 7-day lag), so the first statement here, none by definition,
was wrong. None has 3 or more, the least any report needs. Gold warns in the refresh summary if one does and still writes the
tables (commit `39e0afcf`), because stopping the build would hold up everything over one row that returns within the week.

**Publish:** contract **v8**: the seven fields on `jd_<branch>.json.gz`. Measure the size change.

## 2. App: fields

JD catalogue fields, each unknown on a publish before v8 ("isn't in today's data", as earlier fields).

Stored: `binQty` (Bin qty), `piecesInSet` (InMaster PIS), `pisQty` (SPI PIS), `pisInvoices` (Invoices), `pisDemands`
(Demands; the workbook shows the same number twice), `pisSalesQty` (Sales qty).

Calculated (all blank when the record has no invoices, except as noted), from the workbook:

| Field | Formula |
|---|---|
| Match % | round(100 × `PisQtyInvoices` / `PisInvoices`, 1) |
| PIS multiple % | round(100 × `PisMultipleInvoices` / `PisInvoices`, 1) |
| Stock position | Bin + On order |
| Round up | SPI PIS when Stock position is 0; else ceil(Stock position / SPI PIS) × SPI PIS |
| Recommended qty | Round up − Stock position |
| Recommended cost | Cost × Recommended qty |
| Months of supply | Stock position / (Sales qty / 18); blank when Sales qty is 0 |
| Tier | Invoices ≤ 3 "4 - Thin"; Match ≥ 90 and Invoices ≥ 10 "1 - Act Now"; Match ≥ 80 and Invoices ≥ 5 "2 - Likely"; else "3 - Review" |
| PIS class | SPI PIS ≥ 50 "Box / Bulk Qty"; ≤ 12 "Set"; else "Large Multiple" |
| Coverage flag | Stock 0 "Out of Stock"; Sales 0 "No Sales"; Months < 1 "Thin"; ≤ 6 "Healthy"; else "Overstocked" |

The workbook's thresholds are fixed in the app (the Excel settings sheets have no equivalent); a copy filters on the
fields. The 75% tests use the rounded Match %: a ratio in [74.95, 75) needs 500+ invoices, and any such row shows at the
Excel check.

## 3. App: the built-ins

Each is branch grain, active rows only, so it counts at once.

| Report | Conditions | Columns |
|---|---|---|
| **Pieces In Set** | Branch not one of 2, 4 · SPI PIS > 1 · Match % ≥ 75 · Invoices ≥ 3 · Super To blank | Branch, Part #, Description, Source, SLC, Commodity Code, Dealer Group Code, SPI PIS, Match %, Invoices, Demands, Sales Qty, Bin Qty, On Order Qty, Cost, Round Up, Recommended Qty, Recommended Cost, Tier, PIS Class, Stock Position, Months of Supply, Coverage Flag |
| **Pieces In Set: 3 Months or Less** | The same, and Months of supply ≤ 3 | The same |
| **Pieces In Set Review** | Branch not one of 2, 4 · InMaster PIS > 1 · Match % < 75 · Invoices ≥ 3 | Branch, Part #, Description, Source, SLC, Commodity Code, Dealer Group Code, InMaster PIS, Most Common Qty, Match %, PIS Multiple %, Invoices, Demands, Sales Qty |

CSV headings are the workbook's, including "SPI PIS" and "Most Common Qty" for the same field. Description comes from
the record, so a part reads as that branch spells it. Copies and the editor work as for the other branch reports.

A blank Months of supply fails "≤ 3", as the workbook's "is number" test does (a row with no sales has none anyway).

## Checks and release

- `corp_parts_check.py --report pis / pis3 / pisreview`: the query's SQL over Prod Silver, against Gold's new columns and
  the workbook.
- Vitest: every formula at its edges (zero stock forces one full set; negative and fractional stock; an exact multiple
  recommends 0; tier and class boundaries; no-sales blanks); the built-ins over one-fail-each mock rows; v1–v3 reports
  unchanged; "not in today's data" on v7; a click-through; try-it notes.
- **Excel check before Ben:** Brian refreshes in the evening (**Refresh All twice**, so the first tab catches up with
  the Data table) and it is compared with the next morning's Prod; every difference explained by part.
- **Release order:** Fabric to Prod and a Prod refresh of the changed items → app 0.16.0 to Fedora (reads v7 and v8) →
  v8 publish code on the Gateway PC, then publish → real test. The app refuses a newer contract, so the app goes first.

## Later

Scrap and COTTON Trouble Parts are placed later. F12, Reason Codes, is next.
