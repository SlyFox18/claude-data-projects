# SPI Parts Hub: Stock on superseded parts, JD and non-JD built-ins (design)

> **Status:** design approved by Brian, 2026-11-05. Next: the implementation plan (Plan P, app 0.15.0).
> **Origin:** Ben, 2026-11-05 (via Brian): "Parts with a Bin Qty greater than 0 with a Super To", for JD and non-JD.

## Decisions (Brian, 2026-11-05)

| # | Decision |
|---|---|
| P-D1 | **On hand > 0**, not Equip's BinQty: any stock at the branch, wherever it sits. (Prod 11-05, records with a Super To: JD 2,477 on hand > 0 vs 2,413 BinQty > 0; non-JD 721 vs 706. The gap is stock in the bulk bin or outside a bin.) |
| P-D2 | **Both JD and non-JD:** JD as a built-in Inventory report, non-JD as a built-in Cleanup check. |
| P-D3 | **Any non-blank Super To counts**, including words such as `BOLTS` (notes typed into the field); the user sees them and decides. |
| P-D4 | **No Fabric, publish or contract change:** JD records carry Super To and on hand (contract v6/v7); the non-JD reorder files carry `superTo` since contract 1. Only the Cleanup checks' slim parts drop it today. App only. |

## The rule

On hand > 0 and Super To (trimmed) is not blank. One row per branch record.

## 1. JD: built-in Inventory report "Stock on superseded parts"

- Fifth built-in (after Corporate Stocking), branch grain: conditions On hand > 0 · Super To is not blank; no pool.
- **Active records only** (`includeIdle` off): idle records are those with no stock, orders, sales or demand, so none
  can have on hand > 0. It counts at once, with no Count button and no idle download. (The plan's reference check
  confirms 0 idle records with on hand > 0 in Prod.)
- Columns: Branch, PartNumber, Description, OnHand, Cost, OnHandValue (a new JD field: whole units on hand at cost,
  as Cleanup's), SuperTo, Source, SLC. Sort: the reports' usual default (part number); any column sorts by a click.
  CSV headings = these names.
- Copy as my own works as for the other built-ins.

## 2. Non-JD: built-in Cleanup check "Stock on superseded parts"

- Third built-in check (after Minimums with no demand, Value with no quantity): On hand > 0 · Super To is not blank.
- `SlimPart` gains `superTo` (from the reorder file's `superTo`, trimmed, "" when blank); the Cleanup catalogue gains a
  **Super To** text field (blankable), so saved checks can use it too.
- Columns: On hand, Cost, On-hand value, Super To (after the usual part columns); sort as the other checks.

## Checks and release

- Reference: DuckDB over Prod (Silver_PartInformation for JD; Gold reorder for non-JD, the publish's source) counting
  records with on hand > 0 and a Super To, compared with the app's count and CSV on the real app.
- Vitest: the two built-ins over mock parts (one passing, one failing each condition, a word Super To, a blank and a
  spaces-only Super To); the Cleanup field; saved checks and reports unchanged.
- Mock data: a few superseded parts with stock in both mocks; try-it notes; click-through.
- Release: app 0.15.0 to Fedora only.
