# Parts Low Margin Alerts — Power Automate Design

## Overview

Two new, independent Power Automate flows that alert parts staff when current
inventory is priced below a target profit margin. Built on the same
distribution mechanism as the existing **Parts Action Summary - Orchestrator**
flow (SPI-PARTS Azure AD group, PartsBranchMapping SharePoint list, "Parts
Action Dashboard Email" app registration), but visually distinct so
recipients never confuse them with the Parts Action email.

**Business driver:** Ben wants visibility when a part's current margin drops
below 20%, split into a steady weekly view (everything currently below
threshold) and a fast daily notice (anything that just crossed the line).

## Data & Threshold

- **Report/model:** Part Sales with Low Margin (`RP - Parts Reports`
  workspace) — Page 2 ("Inventory Cost Discrepancy"), backed by
  `dim_Parts_LowMargin`.
- **Threshold field:** `Actual Margin % (INV)` < 20%, evaluated per
  part + branch + franchise row.
- **Not the same as `LowMarginFlag`:** `dim_Parts_LowMargin[LowMarginFlag]`
  is a separate, actively-used field sourced from InMaster that parts
  managers already rely on for other purposes. It does not encode a 20%
  cutoff and is not being repurposed here — the two flows compute their own
  margin-percent comparison independently.
- **Full column set** (used in both CSVs, matches the Page 2 table exactly):
  Branch, Franchise, Part No, Description, Total SOH Qty, Inventory Cost,
  MDP/Sell Value, Desired Margin %, Actual Margin % (INV), Desired Margin $,
  Actual Margin $ (INV), Margin $ Discrepancy, Low (flag), New Sell Price.

## Flow A — Weekly Low Margin Digest

| Setting | Value |
|---|---|
| Trigger | Recurrence — weekly, Monday 8:30 AM CST |
| Content | Every part+branch currently below 20% margin (Actual Margin % (INV)), regardless of prior reporting |
| HTML body | Purple-accented KPI summary — count of parts below threshold + total $ margin gap for the branch. Same card layout as Parts Action for familiarity, purple stripe/accent instead of navy so it reads as related-but-distinct. |
| CSV attachment | `Low_Margin_Parts.csv` — full column set (above), all qualifying rows for that branch |
| Recipients | SPI-PARTS Azure AD group → PartsBranchMapping lookup (same pipeline as Parts Action) |

Monday is a starting assumption, not a fixed requirement — it's a single
recurrence-trigger setting and can be changed later if Ben wants a different
day.

## Flow B — Daily New-Item Alert

| Setting | Value |
|---|---|
| Trigger | Recurrence — daily, Mon-Fri, 8:30 AM CST (after the ~8 AM Tier 1 refresh completes) |
| Content | Only part+branch combinations that are newly below 20% margin since the last run |
| HTML body | Dark-red banner, "New Low Margin Alert" — no KPI cards, just a short highlighted table (Part, Margin %) of the new item(s). Built to look urgent and visually distinct from both Flow A and Parts Action. |
| CSV attachment | Full column set (above), for the newly-crossed part(s) only |
| Recipients | Same SPI-PARTS + PartsBranchMapping pipeline as Flow A |
| Send condition | Only sends to a branch if that branch has at least one newly-crossed item that day — most branches most days will trigger no email |

### New-item detection (state tracking)

A new SharePoint list (e.g. `LowMarginPartsTracking`) stores the composite
key (PartNumber + Branch + Franchise) of every part+branch currently known
to be below threshold. Each run:

1. Query the current below-threshold set from `dim_Parts_LowMargin`.
2. Diff against the tracking list to find newly-crossed keys.
3. Email only the newly-crossed rows (if any).
4. Overwrite the tracking list with the new current full set.

This means parts that get re-priced above 20% drop off the tracking list
automatically, and will trigger a fresh alert if they cross back below 20%
later.

## Shared Infrastructure (reused, not duplicated)

- SPI-PARTS Azure AD group, PartsBranchMapping SharePoint list, and the
  "Parts Action Dashboard Email" app registration are reused as-is — no new
  Azure app registration or recipient list.
- Each flow gets a manual-test child flow (per-branch inputs), matching the
  existing "Weekly Branch Email" test-flow pattern.

## Open Items for the Implementation Plan

- The Power BI workspace/dataset IDs for "Part Sales with Low Margin" are
  not yet documented (unlike the 6 datasets already listed in
  `parts action dashboard - report/documentation/power-automate-setup.md`)
  — look these up via `fab`/`pbi` before building the DAX query steps.
- Exact DAX query text for both flows (aggregate + detail, mirroring the
  patterns in the existing setup doc) needs to be written and tested against
  the live model.
- Confirm the SharePoint site/list creation details for
  `LowMarginPartsTracking` (site, columns, permissions) during planning.
