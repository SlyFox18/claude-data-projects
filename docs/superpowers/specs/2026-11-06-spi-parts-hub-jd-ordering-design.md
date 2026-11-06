# SPI Parts Hub: JD ordering, phase 1 (design)

> **Status:** design agreed with Brian, 2026-11-06, pending his review of this file. Next: the implementation plan (Plan S,
> app 0.17.0).
> **Origin:** the launch page's "JD ordering: coming later" card; Brian and Ben's Hub vision; F12 (tags on rules) needs a
> JD order screen for Corporate Stocking.
> **Builds on:** 0.16.0, contract 8.

## Goal

Barry, Curt and Ben can run JD Recommended Reorder and One-Time Order lists for any branch, adjust the rules themselves,
and export the result, beside Prism.

**What this isn't.** It doesn't replace Prism and doesn't connect to it. Prism connects to JD's ordering system and stays.
An order here ends as an exported list. The team is still exploring the app and it isn't their source of truth, so several
releases are fine and a missing screen is acceptable.

## Decisions (Brian, 2026-11-06)

| # | Decision |
|---|---|
| S-D1 | **Alongside Prism**, never replacing it. No connection to Prism or JD's ordering system. |
| S-D2 | **Phase 1 is Recommended Reorder and One-Time Order** (with Home, Orders, Rules and Special statuses). Transfers and anything else come in later releases. |
| S-D3 | **The JD Default rule starts at 12 months, 3 demands, 4 weeks of supply** (4 weeks is Prism's default, per Ben), so the lists sit close to Prism's. People change it on the Rules screen. |
| S-D4 | **Separate JD build and data.** Same logic as non-JD, its own Gold tables, files and rules list, so non-JD's numbers can't move. |
| S-D5 | **Every branch is included, with no exclusions.** Non-JD's exclusions don't apply here. Branch 12 is the combine vault (F13). |
| S-D6 | **JD has its own rules list.** Today's Default rule says "All parts", and a shared list would let a non-JD change move JD numbers. |
| S-D7 | **Records that could be ordered** (Claude, for Brian's review): see "Which records" below. |

**Left out of phase 1:** Transfers; spiking, EOQ and the check on Prism's Pre-Approved orders (Ben, 2026-10-23: JD-specific,
and the spiking criteria are still to come); rules with tags (F12, next); limiting areas by person; the combine vault (F13).

## Measured, 2026-11-06 (Prod, rough)

| | Non-JD published | JD, every branch |
|---|---|---|
| Part records | about 200,000 | 884,432 with cost > 0; 522,239 of them with history |
| History rows (60 months) | 511,217 | 3,076,987 |
| Branches | 19 | 33 with history |
| Largest branch | about 1 MB reorder file | about 36,000 to 40,000 parts with history |

A rough Default-rule estimate over all branches, on today's on hand and on order: 4 weeks gives about 3,622 lines and
$864,000; 12 weeks about 9,785 lines and $2.08 million. Only the scale matters here: it leaves out settings and value limits.

**Which records (S-D7):** franchise D, cost > 0, and any of: a sale in the 60 months of history, stock on hand or on order, or a
part setting (so a Phase-in on a part with no history still works). That is at most about 530,000 records. Non-JD keeps every
record with cost > 0, but for JD that would be 884,432, most of which can never be recommended. The plan measures the published
size for this scope and reports it before the publish is finalized. Files load one branch at a time.

## 1. Data (Fabric and publish)

**`Build_Gold_JD_Reorder`**, a new notebook, in the daily DP refresh after Silver:
- **`Fact_JD_Reorder`:** the same columns and calculation as `Fact_NonJD_Reorder`, without the transfer columns or
  allocation (Part 2 and 3). Key: Branch + Franchise + PartNumber, franchise D, trimmed and upper-cased as Part 5 does.
- **`Fact_JD_SalesHistory`:** the 60-month history of those parts, shaped as `Fact_NonJD_SalesHistory`.
- It reads `JD_OrderRules` and `NonJD_PartSettings` (which is already keyed by franchise, so one settings list serves both).
- It follows `dp-notebook-rules.md` and Gold's habits (UTC, path-based saves, VACUUM). `dag_check` and `hygiene_audit` pass.

**`Build_Gold_NonJD_Reorder` is not changed.** The plan chooses how to share the calculation without touching that
notebook's results; whichever way, the compare below proves it.

**`df_JD_OrderRules_Raw`**, a new staging dataflow, as `df_NonJD_OrderRules_Raw`.

**Publish, contract 9:** `jdorder_<branch>.json.gz`, `jdhistory_<branch>.json.gz`, `jd_rules.json.gz`; `_meta.json` gains the
JD order branches. No existing file or field changes. The largest file stays under the 4 MB limit; if a branch doesn't, stop
and ask.

## 2. SharePoint

- **`JD_OrderRules`:** the columns of `NonJD_OrderRules`, with one row to start, **Default** (All parts, All year, 12 months, 3
  demands, 4 weeks, UnitsSold). Built-in fallback for a part no rule fits: the same numbers.
- **Orders and One-Time templates** gain an **Area** column: `JD`; blank reads as non-JD, so existing rows don't change.
- **Special statuses** use the existing list.

## 3. App

**The JD ordering card goes live.** Its left nav: Home, Recommended Reorder, One-Time Order, Templates, Orders, Rules, Special
statuses. Part Lookup, Inventory and the other areas are unchanged.

**One set of screens, told which area they're in.** `ReorderPage`, `OneTimeOrderPage`, `OrdersPage`, `OrderPage`, `RulesPage`,
`TemplatesPage` and `SpecialStatusesPage` read an area setting that picks the files, the rules list, the fallback rule and the
order filter. Copies of these pages aren't made: `ReorderPage` alone is 1,560 lines, and a copy would drift.

| Screen | JD differences |
|---|---|
| Home | JD counts and dollars only; no transfer cards |
| Recommended Reorder | No Transfers step and no transfer hints |
| One-Time Order | No transfers step; its own templates |
| Orders, Order | Only JD orders; the same export |
| Rules | The JD list; the excluded-branch checks don't apply |
| Special statuses | JD parts only |
| Part details panel, part page | Work for franchise D, with JD history |

**Launch card counts:** as non-JD's. **On a publish before contract 9:** the card stays "Coming later" and the JD routes say
the data isn't in today's publish. Non-JD screens behave exactly as before on any contract.

**Routes:** under `/jd/...`. Existing URLs don't change.

## Checks and release

- **Non-JD can't move:** with the notebook unchanged, a repo check confirms it; the app's non-JD tests all pass unchanged, and a
  built non-JD file set before and after is byte-identical apart from `_meta.json`.
- **JD numbers:** an independent reference over Silver (as `tools/dp-migration`'s checks do) against `Fact_JD_Reorder`, and the
  app's calculation against the morning run's numbers (the existing parity banner, on JD data). A twice-run in Dev.
- **Vitest:** the area setting per screen; no transfer UI in JD; a JD order doesn't show on non-JD's Orders and the reverse;
  every branch available, including 12; contract 8 behaviour; a click-through.
- **Monday (Brian):** the JD area on mock, with a try-it, and the Dev check results. Nothing is in Prod until Brian releases.
- **Release order, Brian:** lists in Prod → Fabric PR, deploy, claim, items refresh → app 0.17.0 to Fedora → publish code on the
  Gateway PC, then publish → a real test on one branch.
- **Barry or Curt** then hold lists up against Prism. They won't match exactly (no spiking or EOQ here); the differences are
  for them to judge, and they decide what comes next.

**Over the weekend:** the app and Dev work run while Brian is away. Anything that needs Brian (a permission prompt, a list
or connection only he can create) stops that piece and is reported; the other pieces continue.

## Later, in order

1. Rules with tags (F12), on both areas.
2. Corporate Stocking as a real JD rule (cross-branch conditions).
3. JD Transfers.
4. Spiking and EOQ, when Ben's criteria arrive; the Pre-Approved check.
5. The combine vault (F13).
