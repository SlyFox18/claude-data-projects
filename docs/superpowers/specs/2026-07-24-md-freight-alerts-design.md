# MD Freight Alerts — Power Automate Design

## Overview

Two new, independent Power Automate flows that alert parts/branch staff when
an open Machine Down (MD) order is missing freight or significantly
under-charged. Built on the same distribution mechanism as the existing
**Parts Action Summary - Orchestrator** and **Low Margin** flows (SPI-PARTS
Azure AD group, PartsBranchMapping SharePoint list, "Parts Action Dashboard
Email" app registration), but visually distinct from both so recipients
never confuse the three email families.

**Business driver:** Ben wants visibility into open MD orders where freight
was not charged or was materially under-charged, split into a steady weekly
view (everything currently qualifying) and a fast daily notice (anything
that just newly qualified).

## Data & Threshold

- **Report/model:** MD Invoices With No Freight — `RP - Parts Reports`
  workspace (`4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`), dataset
  `MD Invoices With No Freight` (`88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d`).
- **Scope:** Open Orders only (`Fact_MDInvoices_NoFreight`). Closed
  Invoices (`Fact_MDInvoices_Closed`) is out of scope — it's historical,
  already-invoiced data, so alerting on it doesn't drive corrective action
  the way an open order does.
- **Threshold logic:** a row qualifies when
  `Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"` **OR**
  (`FreightBucket = "Partial Freight"` **AND**
  `Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10`).
  10% is hardcoded into both flows, independent of the report's adjustable
  "Alert Threshold %" slider (which defaults to 15% and stays a separate
  what-if tool on the report).
- **Qualification grain:** invoice level (`FileNumber`), matching how
  `MissedFreightAmount` / `PctFreightDifference` are already computed on the
  fact table (`CALCULATE(..., ALLEXCEPT(Fact_MDInvoices_NoFreight,
  Fact_MDInvoices_NoFreight[FileNumber]))`). An invoice qualifies or doesn't
  as a whole; its part lines all ride along together in the CSV.
- **Full column set** (used in both CSVs, matches the Open Orders matrix
  exactly plus `PartNumber` since the live matrix has Invoice # and Part
  Number both in the row axis): `FileNumber` (Invoice #), `RONumber` (RO #),
  `OrderDate`, `Branch`, `PartNumber`, `Order Qty`, `Sell Price 1`,
  `Unit Price`, `Total Weight`, `Actual Freight`, `Calculated Freight`,
  `% Freight Difference`, `Missed Freight`. The first five are raw columns
  on `Fact_MDInvoices_NoFreight`; the rest are `_Measures` used by the live
  report table.
- **Performance note carried over from the report itself:** read
  `MissedFreightAmount` / `PctFreightDifference` (the cached calculated
  columns) for filter/threshold logic, not the live `[Missed Freight]` /
  `[% Freight Difference]` measures — same reasoning as the report's own
  `Is In Selected Group` performance fix (avoids formula-engine row-by-row
  evaluation). The live measures are still fine to use for the CSV's
  *display* values, matching what the report itself shows.

## Flow A — MD Freight Weekly Digest

| Setting | Value |
|---|---|
| Trigger | Recurrence — weekly, placeholder Monday 9:00 AM CST |
| Content | Every open MD invoice currently qualifying (No Freight, or Partial Freight ≥ 10%), regardless of prior reporting |
| HTML body | Turquoise/cyan-accented KPI summary — count of invoices flagged + total $ opportunity (missed freight) for the branch. Same card layout as Parts Action/Low Margin for familiarity, turquoise stripe/accent (`#0e8a9c` header, `#e9f7f9` card background) instead of navy or purple so it reads as related-but-distinct. |
| CSV attachment | `MD_Freight_Missed.csv` — full column set (above), all qualifying rows for that branch |
| Recipients | SPI-PARTS Azure AD group → PartsBranchMapping lookup (same pipeline as Parts Action / Low Margin) |

Monday 9:00 AM is a starting assumption, not a fixed requirement. It's later
than Low Margin's 8:30 AM because MD Invoices With No Freight is a **Tier 2**
report (can finish refreshing after 8 AM), unlike Low Margin's Tier 1 source
(fresh by 8 AM) — the exact time is a single recurrence-trigger setting and
can be changed once Ben/Brian pick a real schedule.

## Flow B — MD Freight Daily New-Item Alert

| Setting | Value |
|---|---|
| Trigger | Recurrence — daily, placeholder weekdays 9:00 AM CST |
| Content | Only invoices (`FileNumber`) that are newly qualifying since the last run |
| HTML body | Amber/orange urgent banner (`linear-gradient(135deg, #d97a1f, #b8590f)`), "New Freight Alert" — no KPI cards, just a short highlighted table (Invoice #, Branch, % Freight Difference) of the new item(s). Built to look urgent and visually distinct from both Flow A and the Low Margin/Parts Action emails. |
| CSV attachment | Full column set (above), for the newly-crossed invoice(s) only — all part lines belonging to those invoices |
| Recipients | Same SPI-PARTS + PartsBranchMapping pipeline as Flow A |
| Send condition | Only sends to a branch if that branch has at least one newly-crossed invoice that day |

### New-item detection (state tracking)

A new SharePoint list, `MDFreightTracking`, stores the invoice number
(`FileNumber`) of every open MD invoice currently known to be qualifying,
plus its branch. Each run:

1. Query the current qualifying set from `Fact_MDInvoices_NoFreight`
   (deduplicated to one row per `FileNumber`).
2. Diff against the tracking list to find newly-crossed `FileNumber`s.
3. Email only the newly-crossed invoices' rows (if any), pulling all part
   lines for those invoices for the CSV.
4. Add a list item for every newly-crossed `FileNumber`; delete the list
   item for any `FileNumber` no longer qualifying (i.e. freight was added or
   corrected, or the order closed/invoiced).

This mirrors `LowMarginPartsTracking`'s self-correcting sync logic — no
manual cleanup needed. An invoice that drops off and later re-qualifies
(e.g. a new part line added without freight) triggers a fresh alert.

**Tracking list columns:**

| Column | Type |
|---|---|
| FileNumber | Single line text |
| Branch | Single line text (BranchFilter format, e.g. `"2 - Tornillo"`) |
| FirstFlaggedDate | Date and Time |

Site: same South Plains Implement - Report Site as `PartsBranchMapping` and
`LowMarginPartsTracking`.

## Shared Infrastructure (reused, not duplicated)

- SPI-PARTS Azure AD group, PartsBranchMapping SharePoint list, and the
  "Parts Action Dashboard Email" app registration are reused as-is — no new
  Azure app registration or recipient list.
- Same Power BI (`shared_powerbi`) and SharePoint (`shared_sharepointonline`)
  connection references as the Low Margin flows — see that project's
  `POWER-AUTOMATE-SETUP.md` for the exact connection IDs and the "auto
  discovered connection is broken" gotcha, which still applies here.
- Sender mailbox: `bfox@spitractor.com` (Graph API `sendMail`, same pattern).
- Each flow gets a manual-test child flow (4 inputs — Name, Branch,
  BranchFilter, Email — via Button trigger), matching the existing
  "Weekly Branch Email" test-flow pattern.

## Naming

- `MD Freight Weekly Digest`
- `MD Freight New Item Alert`

(Parallel to `Low Margin Weekly Digest` / `Low Margin New Item Alert`.)

## Rollout / Testing

- Both Orchestrators are built and left **Stopped** — same as the Low
  Margin flows — until Brian/Ben approve a go-live schedule. No fixed
  schedule has been chosen yet; the recurrence times above are placeholders.
- **All testing (including the manual test flows) sends only to
  `bfox@spitractor.com`** — never to the parts department — until Brian
  explicitly says otherwise.

## Open Items for the Implementation Plan

- Exact DAX query text for both flows (aggregate + detail) needs to be
  written and tested against the live model — mirror the pattern in the Low
  Margin flows' `Run_Detail_Query`/`Run_Aggregate_Query` actions.
- Confirm exact SharePoint list creation details for `MDFreightTracking`
  (permissions, any additional columns) during planning.
- Known Power Automate gotchas already discovered while building the Low
  Margin flows (broken `copy_flow`/`edit_flow`, no native
  `select()`/`difference()` expression functions, `update_flow`'s stricter
  connection-reference validation, `Table` actions needing `body()` not
  `outputs()`, `weekDays` requiring `frequency: "Week"`) all apply here too
  — build by hand-authoring flow JSON via `create_flow`, not `copy_flow`.
