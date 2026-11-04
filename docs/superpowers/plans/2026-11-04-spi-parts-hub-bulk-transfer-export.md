# SPI Parts Hub: bulk transfer export (Plan N, app 0.13.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export (N) on the Transfer orders tab: one combined CSV of the ticked transfers, each recorded as exported.

**Architecture:** A pure CSV builder in `src/export/csv.ts`, a pure "plan" (what's included, what's left out and
why) plus an async runner in `src/transfers/bulkExport.ts`, and the button / notice / failures panel in
`src/pages/transfers/TransferOrdersList.tsx`, following its Archive flow.

**Tech Stack:** React 19 + TS, Vitest + Testing Library, the mock data source.

**Spec:** `docs/superpowers/specs/2026-11-04-spi-parts-hub-bulk-transfer-export-design.md` (N-D1, N-D2).

---

### Task N1: Combined CSV and the bulk export logic

**Files:**
- Modify: `src/export/csv.ts` (add `TRANSFER_ORDERS_CSV_HEADER`, `transferOrdersCsv`)
- Create: `src/transfers/bulkExport.ts`
- Test: `src/export/__tests__/` (beside the existing transferOrderCsv tests), `src/transfers/__tests__/bulkExport.test.ts`

- [ ] `transferOrdersCsv(groups: readonly { title: string; from: string; to: string; lines: readonly TransferCsvLine[] }[])`:
  header `['Transfer', 'From', 'To', ...TRANSFER_ORDER_CSV_HEADER]`; per group, per line with qty > 0, the three
  leading cells (title via `textCell`, branches via `quoteField`) then exactly the cells `transferOrderCsv` writes
  (share the line-cells code rather than copying it); CRLF. Tests: columns, order, qty filter, a title starting
  with `=` is guarded, a branch code is exact.
- [ ] `planBulkExport(fresh: readonly { transfer: Transfer; lines: TransferOrderLine[] }[])` →
  `{ include: [...], leftOut: { transfer, reason }[] }`; reasons: archived, not exportable (status label, via
  `transferStatusLabel`), no line with a quantity. Pure; tests for each reason and the keep-order rule.
- [ ] `exportTransfers(src, ids, { download, now })`: reads each transfer + lines (`loadTransferOrder`,
  `loadTransferOrderLines`, like TransferOrderPage's onExport), plans, downloads once
  (`Transfer-orders-YYYYMMDD.csv` via `csvFilename` + `centralToday`) when anything is included, then
  `recordTransferExport` one by one; returns `{ recorded: Transfer[], failed: { transfer, error }[], leftOut,
  lineCount }`. A read failure of one transfer leaves it out with its error (reason "couldn't be read"), not the
  whole export. `recordExports(src, transfers)` does the recording step alone (for Try again). Tests with a fake
  source: one download, partial record failure, Try again records only, nothing included → no download.
- [ ] `npx vitest run` on the touched tests, `npm run lint`, `npx tsc -b`; commit.

### Task N2: Export (N) on the Transfer orders tab

**Files:**
- Modify: `src/pages/transfers/TransferOrdersList.tsx` (+ its tests in `src/pages/transfers/__tests__/` or
  `src/pages/__tests__/`, wherever the archive tests live)

- [ ] **Export (N)** (secondary, download icon) beside Archive (N) when ticks exist; enabled when every ticked row is
  unarchived and `canExportTransfer`; otherwise the hint from the spec. Disabled while archiving or exporting
  ("Exporting…").
- [ ] Runs `exportTransfers`; merges each recorded transfer's status and exportCount onto the rows; unticks the
  recorded ones; notice per the spec (counts, lines, left-out names with reasons); focus moves to the notice.
- [ ] Failures panel like the archive one ("N transfer orders were downloaded but not recorded as exported"), Try
  again (sign in first on `AuthRequiredError`, then `recordExports` only) and Dismiss. Keep it separate from the
  archive failures state.
- [ ] Tests: button enablement and hint; one download with the combined file; rows show Exported / count after;
  left-out message; partial failure + Try again records without downloading again.
- [ ] Update the file's header comment; lint, tsc, the transfers tests; commit.

### Task N3: Version, click-through, try-it notes

- [ ] `package.json` version 0.13.1; a click-through test (mock): Transfers → Transfer orders → tick all → Export →
  one CSV, statuses Exported.
- [ ] Full test suite in two halves, lint, tsc; commit; push dev.
- [ ] `projects/part order tool - app/for-users/0.13.1-try-it.md` (data-projects): one short job on mock.
- [ ] Release build (`npm run build`) after Brian's try-it, dist checks (list IDs, no mock strings, About 0.13.1),
  upload to Fedora staging; Brian installs.
