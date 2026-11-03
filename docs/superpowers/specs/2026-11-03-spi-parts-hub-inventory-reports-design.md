# SPI Parts Hub: Inventory reports (F4, MLPF Gaps first) (design)

> **Status:** design approved section by section by Brian, 2026-11-03 (brainstorm). Next: the implementation plan
> (Plan L, app 0.12.0).
> **Origin:** `projects/part order tool - app/FUTURE-IDEAS.md` F4 (inventory management); the Corp Parts Excel
> workbooks in `projects/corp parts excel reports/` (Ben, Barry, Curt), starting with `MLPF Gaps/MLPF Gaps.pq`.
> **Context:** the parts team is testing the app (round 3 live). Saved documents are test data and may be deleted.

## Goal

Bring the Corp Parts Excel reports into the app as **Inventory reports**: searchable, filterable tables over the active
JD (franchise D) parts. Each workbook becomes a **built-in** report that matches the workbook row for row, and anyone
can **Copy as my own** to get an editable version, so rule changes no longer need Brian. The workbooks keep working
alongside until Ben is happy to retire them.

This spec covers the platform and the first report, **MLPF Gaps** (0.12.0). Border Stores / 2 & 4 Cotton, Corporate
Stocking and Pieces In Set follow as their own small releases (see Later).

## Decisions (Brian, 2026-11-03)

| # | Decision |
|---|---|
| L-D1 | Each workbook becomes a fixed built-in that matches the workbook exactly, plus **Copy as my own** (an editable copy in the condition editor). The built-in never changes; a popular copy can become a new built-in in a later release. |
| L-D2 | **Everyone** sees the Inventory area (no roles), like Cleanup checks. |
| L-D3 | **Once-a-day data** (the morning DP run and publish), shown as "Data as of …" on each report. Intraday is a later option (DP `intraday` mode). |
| L-D4 | **Option 1:** ship the active JD parts to the app and run the reports in the browser on the Cleanup checks engine. Not precomputed results in Gold (copies couldn't be edited), not a mix (two ways to the same answer). |
| L-D5 | The JD files carry **every JD branch**, including the app's excluded branches (12, 5, 97, 4B, 93C). Each report's own conditions do the excluding, as each workbook does. |
| L-D6 | Saved copies go in a **new SharePoint list, InventoryReports** (same columns as CleanupChecks), so a copy never runs over the wrong parts. Brian creates it and adds its ID to both `.env` files. |
| L-D7 | No Part page link for JD parts in 0.12.0 (the Part page is non-JD). A row opens a details panel instead. |
| L-D8 | Order: MLPF Gaps first; then Border Stores and 2 & 4 Cotton; then Corporate Stocking; then Pieces In Set. Scrap and COTTON Trouble Parts are placed later. |

## 1. Data (Fabric and the publish)

**Gold table `Fact_CorpParts_JD`**, built in `Build_Gold_NonJD_Reorder` (declared in `dp_refresh_dag.json`
`produces`). One row per branch + JD part (franchise D), **active parts only**: on hand ≠ 0, on order > 0, or a sale in
the last 24 months, or CorpDemands > 0 (so the active filter can never drop a part a demand-based report needs). About
230,000 rows over 41 branches (Prod, 2026-11-02).

| Column | From |
|---|---|
| Branch, PartNumber (trimmed) | Silver_PartInformation key (Branch + Franchise + PartNumber, franchise D) |
| Description, Cost, OnHand, OnOrder, PackageQty, ReturnIndicator, Source, SLC, SuperTo, CommodityCode, Min, Max | Silver_PartInformation |
| DealerGroupCode | per branch, with the known quirks (`reference_jdis_dealer_group_code_quirks`) |
| CommodityGroup | the same CommodityCodeGroups data the workbook uses (monthly SharePoint CSV) |
| CorpDemands | the Corp demand rule below, from Silver_InTrans |

**Corp demand rule** (shared by all the workbooks, computed once): per Branch + PartNumber, count invoices of TYPE 'I'
with QTY > 0 dated 7 days to 18 months before the data date; credits (TYPE 'C', QTY < 0) net against their invoice via
ORIGINAL_INVOICE_NO; an invoice whose net is ≤ 0 doesn't count; transfers never count. Invoice identity uses the full
key (InvoiceNumber is reused). Part numbers are trimmed before every comparison (trailing-space twins).

Notebook rules apply (`docs/architecture/dp-notebook-rules.md`): JD keys, no `dropDuplicates`/`first`, unique
ordering, UTC session, path-based save, VACUUM.

**Publish (contract v6):** per-branch files `jd_<branch>.json.gz`, listed in `_meta.json` (a separate JD branch list,
since L-D5 includes branches the other files leave out), carrying `dataAsOf`. Additive: v5 apps ignore them. The
largest branch must stay under the 4 MB upload limit; measure it before building and split the file if not.

## 2. The app (engine and screens)

**Engine:** the Cleanup checks engine (`src/cleanup/conditions.ts`, `fields.ts`), all conditions must match, over a
JD part type instead of the non-JD slim part.
- New JD fields in the condition builder: Corp demands, Package qty, Return indicator, Source, SLC, Super To,
  Commodity code, Commodity group, On order, On hand, Cost, Dealer group, Branch.
- New comparisons **starts with** and **doesn't start with**, taking a list. Blank follows the existing rules
  ("is blank" for Super To; a blank doesn't start with anything).
- A condition on a field the data doesn't carry gives `unknown` ("can't be checked"), never 0 parts.

**Built-in MLPF Gaps** (from `MLPF Gaps.pq`, conditions only, no special code):

| Condition | Workbook |
|---|---|
| Branch is not 12 | all branches except 12 |
| Corp demands = 2 | exactly 2 demands |
| On hand < 1 | on hand < 1 |
| On order = 0 | On Order = 0 |
| Package qty = 1 | Package Qty = 1 |
| Return indicator is R | Return Indicator 'R' |
| Source is not AN | Source <> 'AN' |
| SLC doesn't start with 21, 90, 91, 99 | SLC NOT LIKE 21%/90%/91%/99% |
| Super To is blank | Super To blank |

Franchise D is implied by the data set. Columns, in the workbook's order: Branch, PartNumber, Description, Cost,
Source, SLC, CommodityCode, CommodityGroup, DealerGroupCode, OnOrder, OnHandQty, Demands.

**Saved copies:** InventoryReports list (L-D6). **Copy as my own** opens the editor pre-filled with the report's
conditions and "Copy of <name>"; saving creates a new row. Copies have Edit, Switch off, Archive / Unarchive, as
Cleanup checks do.

**Screens:**
- **Inventory** card on the launch page and a left-menu item.
- **List page:** built-ins first with a 🔒 "Built in" tag, then saved copies; each shows its part count (filling in as
  branches load). Copy as my own on every report; Edit / Switch off / Archive on copies only; Show archived.
- **Results page:** "Data as of …"; the report's columns; branch filter (default all branches); search (part number
  or description); sort by any column; row count and total cost; **Export CSV** with the same columns. Clicking a row
  opens a details panel with all the part's fields.

**Loading:** the JD files load only when Inventory is opened, once per visit, and stay in memory while moving between
reports. The rest of the app doesn't load them.

## 3. Errors, testing and release

**Errors:**
- JD files missing or `_meta.json` below v6: Inventory says "JD parts aren't in today's data yet"; the rest of the app
  works as normal.
- A branch file fails to load: the report names the missing branches and says what the count covers; a total is never
  silently short.
- A copy's condition reads a field not in the data: "can't be checked" (the `unknown` result).

**Testing:**
- Gold: run twice (determinism), `deploy/compare_tiers.py`, `dag_check.py`, `hygiene_audit.py`, `pytest deploy`.
- Reference check `tools/dp-migration/corp_parts_check.py` (DuckDB): recomputes CorpDemands and the MLPF list
  independently and compares them with Gold.
- **Excel comparison (the gate before Ben sees it):** Brian refreshes `MLPF Gaps.xlsx` on the check morning; the app's
  CSV is compared with it and every difference is explained by part.
- Publish: pytest for the JD files, the JD branch list in `_meta.json` and the size limit.
- App: Vitest for the new comparisons, the JD fields, the MLPF built-in (fixture parts that each fail exactly one
  condition, plus one that passes all), copies, and the pages. The mock gets a handful of JD parts.

**Release (0.12.0), the same-day pattern:** PR merged → Deploy DP backend → Brian runs `claim_prod_pipeline.py` → app
to Fedora first (accepts v5 and v6) → Prod `mode=items items=Build_Gold_NonJD_Reorder` → reference check `--tier prod`
→ Gateway `git pull` + publish → Excel comparison → try-it notes for Brian, then for Ben → user docs.

## Later (not in this spec)

- Border Stores and 2 & 4 Cotton, then Corporate Stocking, then Pieces In Set: each checks whether it needs new
  fields, then adds a built-in and its own Excel comparison.
- A JD Part page (L-D7), actions from a report row (order, transfer, set a min), intraday data (L-D3).
