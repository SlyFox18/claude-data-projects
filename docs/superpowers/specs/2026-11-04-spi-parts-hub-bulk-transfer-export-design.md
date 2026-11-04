# SPI Parts Hub: export several transfer orders at once (design)

> **Status:** design approved by Brian, 2026-11-04. Plan: `docs/superpowers/plans/2026-11-04-spi-parts-hub-bulk-transfer-export.md`
> (Plan N, app 0.13.1).
> **Origin:** Brian, 2026-11-04: "When you select all transfers, can the user have the ability to export all of that
> at one time instead of individually?"

## Decisions (Brian, 2026-11-04)

| # | Decision |
|---|---|
| N-D1 | **One combined CSV**, not a zip of per-transfer files: today's transfer order columns with Transfer, From and To in front. |
| N-D2 | **It counts as exporting each transfer**: Draft → Exported, export count + 1, exactly like the single export. |

## Where

The **Transfer orders** tab (`TransferOrdersList`) already has tick boxes, a "Select every transfer order shown"
header box and Archive (N) / Unarchive (N). It gets an **Export (N)** button beside them for the ticked transfers.
Ticking all after filtering (e.g. To = 7) exports everything the filters show.

## Rules

- **Exportable:** a ticked transfer that is not archived and is Draft or Exported (`canExportTransfer`). The button
  is offered only when every ticked transfer is; otherwise a hint: "Only Draft or Exported transfer orders that
  aren't archived can be exported."
- **Fresh reads first (as the single export, F7 review):** each ticked transfer and its lines are re-read before the
  file is made. One that is now archived, entered, cancelled or otherwise not exportable is left out; one with no
  line of quantity > 0 is left out; both are named in the outcome message. The file uses the lines as stored now.
- **The file:** `Transfer-orders-YYYYMMDD.csv` (Central date, `csvFilename`). Columns: Transfer, From, To, then
  `TRANSFER_ORDER_CSV_HEADER` (PartNumber, Franchise, Description, Qty, FromBin, ToBin, Cost, LineValue); same cell
  rules as `transferOrderCsv` (codes exact, formula guard on free text, CRLF, BOM). Transfer = the transfer's title
  (falls back to "Transfer <id>"). Transfers in list order (newest first), each transfer's lines in stored order;
  lines with no quantity left out. Nothing exportable = no download, a message says why.
- **Recording:** after the download, each included transfer is recorded one by one with `recordTransferExport`
  (re-reads, checks, Draft → Exported, ExportCount + 1). The list rows take the stored status and export count.
  Failures stay listed with **Try again** (records only, no second download; sign in first when the sign-in expired)
  and **Dismiss**, as the archive failures do. Leaving the page with unrecorded exports isn't blocked: the failures
  panel is the reminder, and each transfer's own page still offers Export to record it.
- **Outcome message**, e.g. "Exported 5 transfer orders (42 lines). Left out: TR-1032 (no line with a quantity),
  TR-1029 (Entered in Equip)."

## Not included

Marking several as entered in Equip at once (a later addition the same way); per-transfer zip.

## Testing

Vitest: the combined CSV (columns, order, quantity filter, cell rules); the plan of what's included / left out from
fresh reads; recording with partial failures and Try again recording only (no second download); the button's
enablement and hint. A click-through on mock. Try-it notes. Release 0.13.1 to Fedora (app only, no data changes).
