# Parts Low Margin Invoiced Sales Alert — Design (Rework)

## Overview

Supersedes the daily-alert portion of
`docs/superpowers/specs/2026-07-22-parts-low-margin-alerts-design.md` after
stakeholder feedback from Ben. The weekly digest concept is dropped
entirely; only a daily alert remains, and its data source changes from the
inventory-pricing snapshot (Page 2, `dim_Parts_LowMargin`) to invoiced
sales transactions (Page 1, `Fact_InTrans`).

**Why the change:** Corp parts managers (not branch-level staff) handle
pricing, and Ben's actual concern is parts being *sold* below margin
(invoiced transactions), not current inventory pricing gaps. Invoiced
transactions are permanent historical facts — they don't get "fixed" the
way a mispriced part in inventory does — so there is no ongoing "current
state" to digest weekly; the only useful signal is "did something new get
invoiced below margin."

## Data & Threshold

- Source: `Fact_InTrans` (grain: one row per invoice transaction,
  `Type = 'I'`, ~3-6M rows, 2 years of history).
- Threshold: `Actual Margin % = ActualMarginDollars / SaleValue < 0.20`.
- Filters: `Qty > 0 && SaleValue > 0` — excludes zero/negative-value lines
  (free/no-charge items, returns/credits) that would otherwise falsely
  qualify via divide-by-zero, or aren't real "invoiced sales" in the
  intended sense. Confirmed against the live Page 1 report: rows like
  `TR142012 DIAGNOSTIC` and `CARTON PACKAGING TAPE` currently show
  `$0.00`/`$0.00`/`0.00%` unfiltered — the same filters are being restored
  on the report itself (Brian, in progress) after apparently being removed
  at some point.
- No minimum dollar floor — every qualifying line alerts regardless of
  transaction size (e.g. a $0.21 sale at -614% margin still qualifies,
  matching the report's own literal behavior).
- **Description bug found while designing this:** `Fact_InTrans[Description]`
  is an invoice-level field, not the part description (confirmed by Brian
  against the published report — visually it often looks like a part
  description but is not reliably one). Use
  `LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber])`
  instead, matching the Page 2 pattern. This is a bug in the published
  report too (out of scope for this alert work, but worth a separate fix).

## Date Window (replaces the old alerts flow's tracking-list diff)

No SharePoint tracking list is needed for this alert — invoiced
transactions never need to be "resolved" or removed from tracking the way
inventory pricing gaps did. Instead, each run filters directly by date:

- Weekday-aware "since last run" window, computed in DAX from the current
  date: if today is Monday, cover Friday + Saturday + Sunday + Monday; any
  other weekday, cover just the prior calendar day + today.
- This also solves the "2 years of history" concern automatically — every
  run's window is bounded to at most a few days, regardless of how much
  history exists in the underlying table. No special first-run handling
  needed.

## Columns

**CSV attachment:** matches the live Page 1 report's own column order for
familiarity: Branch, Franchise, Part Number, Description (dim_Parts
lookup), Qty, Date, Ref No (RONumber), Salesman, Cost $, Sale $, Margin $
(ActualMarginDollars), Margin Value % (computed), Customer No.

**Inline HTML alert table:** narrower, scan-at-a-glance set — Part Number,
Description, Cost $, Actual Margin %.

## Architecture

- Single flow, daily (weekdays), 8:30 AM CST — same timing as the prior
  daily alert, after the ~8 AM Tier 1 refresh.
- Recipients: unchanged — SPI-PARTS Azure AD group + PartsBranchMapping
  SharePoint list, same per-branch distribution as Parts Action Summary and
  the prior design. Ben confirmed store-level parts staff not handling
  pricing doesn't change who should see the alert.
- Sender/app registration/CSV mechanics: reused as-is from the existing
  build.

### Email styling (revised after first review)

Brian reviewed the first build against a related flow, "MD Freight New Item
Alert," and asked to match its more polished pattern rather than the
plainer generic table originally used:

- **Explicit trigger description**: a subtitle line directly under the
  banner headline stating what caused the alert in plain language, e.g.
  *"Trigger: Invoiced parts sales with Qty > 0, Sale $ > 0, and Actual
  Margin % below 20% — newly invoiced since the last check."* Mirrors MD
  Freight's `"Trigger: No Freight, or Partial Freight with a 10%+
  difference..."` line.
- **Styled HTML table instead of the generic "Create HTML table" action**:
  a hand-built `<table>` with a tinted header row (light background, bold
  uppercase label text, colored bottom border) and body rows built via a
  `Select` action that produces one `<tr>...</tr>` HTML string per row
  (numeric columns right-aligned, last column bold), joined with `join()`
  and inserted after the header row. This is the same construction pattern
  MD Freight uses, just re-themed to this alert's red color story instead
  of MD Freight's orange:
  - Banner: `#8a1c1c` (unchanged, already approved)
  - Table header background: light red tint (e.g. `#fdecea`)
  - Table header text: dark red (e.g. `#7f1d1d`)
  - Table header bottom border: medium red (e.g. `#f3b3b3`)
  - Row text/dividers: neutral, matching MD Freight (`#333333` text,
    `#f1f5f9` row divider) — no reason to diverge here, it's not part of
    either alert's color identity.
- Still distinct from Parts Action's navy and the (now-unused) weekly
  digest's purple — only the *internal* table styling is being upgraded to
  match MD Freight's more polished construction, not the banner color.

## Disposition of Existing Flows

- **Delete:** the daily alert flow's manual test flow
  (`f6c9fd72-9279-424b-898a-8bc7a8eaf802`) and Orchestrator
  (`66e29bef-7838-4b01-9e6b-c4a8562fb51d`) get rebuilt in place (same flow
  IDs reused via `update_flow`, not recreated) with the new query/columns/
  date-window logic, since the recipient loop and email/CSV mechanics carry
  over unchanged.
- **Leave alone:** both Weekly Digest flows
  (`134dadf0-0ad8-4d0c-ae44-45206184ccc2`,
  `dad7ae83-e6d8-4f63-af15-7c33c734b025`) stay Stopped and untouched for
  now, per Brian's decision — no longer part of the design but not worth
  the risk of deleting yet.
- The `LowMarginPartsTracking` SharePoint list becomes unused by this
  rework (no longer needed for a date-window-based alert) but is left in
  place rather than deleted, since it's harmless and inexpensive to keep.

## Open Items for the Plan Phase

- Exact DAX for the weekday-aware date window needs to be written and
  validated against the live model (mirrors the validation step done for
  the original Page 2 query).
- Confirm whether `Salesman` should display as the raw code (e.g. `S090`,
  matching the report) or resolved to a name — default to matching the
  report's own convention (raw code) unless told otherwise.
