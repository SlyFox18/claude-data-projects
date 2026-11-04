# SPI Parts Hub: Corporate Stocking (Plan O, app 0.14.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A one-row-per-part Inventory report type and the built-in Corporate Stocking, matching the workbook, with
editable copies.

**Architecture:** Branch-grain reports (`InventoryReportDef`, `src/inventory/report.ts`) stay exactly as they are. A new
`PartReportDef` (`src/inventory/partReport.ts`) holds four condition lists: three over JD rows (JD_ROW_CATALOGUE) and
one over a new part catalogue (`src/inventory/partFields.ts`, rows = `PartRow`). `compilePartReport` groups every
active + idle JD row by part key, works out each part's counted records, demand and fields, and yields the matching
`PartRow`s. The stored form is v3; `parseAnyReportDef` dispatches. Pages branch on the grain: the list page counts
either kind, a new `PartReportResultsPage` shows part rows, and the editor shows four cards for a part report.

**Tech Stack:** React 19 + TS, Vitest + Testing Library, the mock data source; Python + DuckDB for the reference.

**Spec:** `docs/superpowers/specs/2026-11-04-spi-parts-hub-corporate-stocking-design.md` (O-D1 to O-D4).

**Repos:** app = `C:\Users\bfox\Documents\Git-Projects\nonjd-order-app` (dev); reference check = data-projects
`tools/dp-migration/corp_parts_check.py` (dev). No fabric-workspace-docs or publish changes (O-D3).

**Working rules (every task):** TDD; match neighbouring files' header comments (cite "Plan O task On" and decision
IDs), naming and idioms; run the touched tests, `npm run lint`, `npx tsc -b`; never `npm run build` (release only);
stage named files only (never `git add -A`; `.env.example` has an unrelated user change); commit messages end with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push dev. A typescript-reviewer reviews each app task.

---

## Decisions made while planning

| # | Decision | Why |
|---|---|---|
| O-D5 | `InventoryReportDef` is unchanged; `PartReportDef` is a separate type; `AnyReportDef = InventoryReportDef \| PartReportDef`; `isPartReport(d)` checks `'grain' in d`. | Nothing in the branch-grain code or its tests changes shape. |
| O-D6 | Lists 1–3 (counted, every, demandAt) read **row fields only** (`JD_ROW_CATALOGUE`); list 4 reads the **part catalogue**. Lists 1–3 may be empty (empty = every record / no requirement / demand at every branch); list 4 needs a condition (`NO_CONDITIONS_PROBLEM`). | The workbook needs no report fields there; empty lists have an obvious meaning. |
| O-D7 | "Locations with demand" is a multi-value text field (`readMany`, comparisons one of / not one of), like "Dealer group at any branch": "one of 93" = has a demand at 93. | No new comparison in the engine; the spec's "contains a branch". |
| O-D8 | A part's text fields = the largest trimmed value over its counted records (blank ignored; plain string order), cost = the largest; description per O-D4 (largest by upper case; among case variants the one at the lowest branch, branch order below). | SQL `MAX` (the workbook); the probe found case variants only in descriptions. |
| O-D9 | Branch order (locations text, O-D4 ties): numeric codes by number, then the others by code (ordinal). | The workbook's `try Number.From(_) otherwise 99999` sort, made total. |
| O-D10 | A part's `every` result: all counted records `=== true`; a record `'unknown'` makes the part not shown (as 'unknown' rows aren't shown). | Same rule as rows. |
| O-D11 | Demand per branch = the largest Corp demands of that branch's records that pass `demandAt` (twins once); the branch has demand when that is ≥ 1. | As the pool (M-D8). |

---

### Task O1: Reference check `--report stocking` (data-projects)

**Files:** Modify `tools/dp-migration/corp_parts_check.py`, `tools/dp-migration/test_corp_parts_check.py`.

- [ ] Add `STOCKING_FILTERS` (the four filters, no on order / Super To):
  ```python
  STOCKING_FILTERS = """PackageQty = 1 AND upper(trim(ReturnIndicator)) = 'R'
      AND coalesce(upper(trim(Source)), '') <> 'AN'
      AND NOT (coalesce(trim(SLC), '') LIKE '21%' OR coalesce(trim(SLC), '') LIKE '90%'
               OR coalesce(trim(SLC), '') LIKE '91%' OR coalesce(trim(SLC), '') LIKE '99%')"""
  STOCKING_COLUMNS = ["PartNumber", "Description", "Cost", "Source", "SLC", "CommodityCode", "DealerGroupCode",
                      "OnOrder", "OnHandQty", "R18 Demands", "Count of Locations with Demands",
                      "Locations with Demands"]
  ```
- [ ] `stocking_rows(con, source="jd_all") -> list[dict]` implementing the spec: eligibility over records with
  `upper(trim(Branch)) NOT IN ('2','4') AND coalesce(STOCKING_FILTERS, false)` grouped by `upper(trim(PartNumber))`
  with the three HAVING sums (on hand ≠ 0, on order ≠ 0, Super To not blank, each = 0); text fields `max(trim(x))`,
  cost `max(Cost)`, description per O-D4 (`arg_max(trim(Description), [upper(trim(Description)), branch-order key])`
  where the branch-order key makes the lowest branch win; write it as a window or a two-step query rather than a
  trick, and test it); demand from `corp_demands` (b not in 2, 4), `count(*) >= 3`; locations
  `string_agg(b, ', ' ORDER BY <O-D9 key>)`; OnOrder and OnHandQty 0; sorted count desc, demands desc, part number.
  Twins: `corp_demands` is already per (b, upper(trim(part))) since 67480aa1.
- [ ] `REPORTS["stocking"]` with `key=("PartNumber",)`, `columns=STOCKING_COLUMNS`, the numeric columns, sheet
  `SPI Corparate Stocking`; generalise `compare_xlsx` / `_xkey` / `part_context` / the diff CSV to the report's key
  (Branch + PartNumber for the others, PartNumber alone here; for stocking, part_context lists every branch's record
  of the part). Description compares ignoring case for stocking only.
- [ ] Tests (DuckDB in memory, the file's helpers `_part`, `_sale`, `_credit`, `_con`): a part with three demand
  branches and zero stock listed; one counted record with on hand 1 → not listed; the same record at branch 2 → listed;
  a record with SLC 21A and on hand 5 → listed; Super To on a counted idle record → not listed; on order −1 → not
  listed; two demand branches → not listed; a demand at a branch whose record fails the filters still counts;
  locations "3, 11, 93" order with a non-numeric branch last; description "Valve" at 11 and "VALVE" at 3 → "VALVE".
- [ ] `python -m pytest tools/dp-migration/test_corp_parts_check.py -q`; commit; push.

### Task O2: Part fields and `PartRow` (app)

**Files:** Create `src/inventory/partFields.ts`, `src/inventory/__tests__/partFields.test.ts`.

- [ ] Types:
  ```ts
  export type PartFieldId =
    | 'partNumber' | 'description' | 'cost' | 'source' | 'slc' | 'commodityCode' | 'commodityGroup' | 'dealerGroup'
    | 'demands' | 'demandBranches' | 'demandLocations' | 'onHand' | 'onOrder';

  /** One record of the part and how the report treated it (for the details panel). */
  export interface PartRecord {
    row: JdRow;
    /** Passed "Records that count". */
    counted: boolean;
    /** For a counted record: passed "Every counted record must" (true / false / 'unknown'); null when not counted. */
    every: MatchResult | null;
    /** Its Corp demands counted towards the part's (passed "Demand counts where" and was its branch's largest). */
    demandCounted: boolean;
  }

  export interface PartRow {
    /** The part key (trimmed, upper case). */
    key: string;
    partNumber: string;        // trimmed, from the first counted record in branch order (O-D9)
    description: string | null;
    cost: number;
    source: string | null; slc: string | null; commodityCode: string | null; commodityGroup: string | null;
    dealerGroupCode: string | null;
    onHand: number;            // sum over counted records (0 for the built-in)
    onOrder: number;           // sum over counted records
    demands: number;           // R18 demands
    demandLocations: readonly string[];  // branch codes with demand, O-D9 order
    records: readonly PartRecord[];      // every record of the part, O-D9 branch order
  }
  ```
- [ ] `PART_FIELDS` (labels: Part number, Description, Cost, Source, SLC, Commodity code, Commodity group, Dealer
  group, R18 demands, Branches with demand, Locations with demand, On hand, On order) as `FieldDefOf<PartRow,
  PartFieldId>` with the same text rules as `JD_FIELDS` (`textValue`, `cents`, `DEALER_GROUP_OPTIONS`), all
  `alwaysKnown`; `demandBranches` reads `demandLocations.length`; `demandLocations` is text with `readMany: (p) =>
  p.demandLocations`, `comparisons: ['oneOf', 'notOneOf']`, `blankable: false` (O-D7), shown as the ", " text.
  `PART_CATALOGUE = makeCatalogue(PART_FIELDS, OPTIONS)` (export `OPTIONS` from `./fields` rather than copy it).
- [ ] `branchOrder(a, b)` (O-D9) exported from here for O3 and the pages.
- [ ] Tests: each field's read on a hand-made PartRow; `branchOrder` sorts `['93','3','11','4B']` → `3, 11, 93, 4B`;
  `conditionProblem` accepts `demandBranches ge 3` and `demandLocations oneOf ['93']`, rejects `demandLocations ge`.
- [ ] Lint, tsc, tests; commit.

### Task O3: `PartReportDef`, parsing, v3 storage, compiling (app)

**Files:** Create `src/inventory/partReport.ts`, `src/inventory/__tests__/partReport.test.ts`; modify
`src/inventory/report.ts` (only to export `branchKey` / `partKey` if not already, and `AnyReportDef`,
`parseAnyReportDef`, `anyReportDefToJson`, `isPartReport`).

- [ ] Types and storage:
  ```ts
  export interface PartReportDef {
    grain: 'part';
    counted: ConditionItem<JdFieldId>[];
    every: ConditionItem<JdFieldId>[];
    demandAt: ConditionItem<JdFieldId>[];
    conditions: ConditionItem<PartFieldId>[];
  }
  export const PART_REPORT_DEF_VERSION = 3;
  // stored: { v: 3, grain: 'part', counted, every, demandAt, conditions }
  ```
  `partReportDefProblem(def)`: list 4 empty → `NO_CONDITIONS_PROBLEM`; each item of lists 1–3 valid in
  `JD_ROW_CATALOGUE`, of list 4 in `PART_CATALOGUE` (`conditionProblem`); first problem in list order.
  `parsePartReportDef(raw)`: v3 object with the four arrays (`parseConditions` with the right catalogue) and no
  problem, else null. In report.ts: `parseAnyReportDef(raw) = raw?.v === 3 ? parsePartReportDef(raw) :
  parseReportDef(raw)`; `anyReportDefToJson`.
- [ ] `compilePartReport(def, active, idle, today)` → `{ status: 'needsIdle' } | { status: 'invalid', problem } |
  ReadyPartReport` where
  ```ts
  export interface ReadyPartReport {
    status: 'ready';
    /** The parts shown, in the default order (demandBranches desc, demands desc, partNumber). */
    rows: readonly PartRow[];
    /** Every part the data has (shown or not), by key: the details panel and "why not" in tests. */
    part(key: string): PartRow | undefined;
    catalogue: Catalogue<PartRow, PartFieldId>;
  }
  ```
  Always needs idle (`idle === null` → needsIdle). Algorithm, one pass: group active then idle rows by `partKey`;
  for each part: records sorted by `branchOrder` then file order; `counted` via `compileConditions(def.counted,
  today, JD_ROW_CATALOGUE)` (empty list → all true); for counted records `every`; demand per branch per O-D11;
  fields per O-D8; the part is a candidate when it has ≥ 1 counted record and every counted record's `every` is
  `true`; shown when `compileConditions(def.conditions, today, PART_CATALOGUE)` is `true`. Keep the built part map per
  (active, idle, today, JSON of lists 1–3) in a small keep-last-N cache like `keptPoolIndex` (lists 1–3 decide the
  PartRows; list 4 only filters), so editing a threshold doesn't regroup ~890k rows.
- [ ] Tests (hand-made JdRows; reuse the helpers in `src/inventory/__tests__/report.test.ts` if they exist): the O1 cases
  one by one through `compilePartReport` with the built-in's lists; twins at one branch count once (largest);
  `every` 'unknown' hides the part; list 4 `demandLocations oneOf 93`; v3 round trip; a v2 and an array still parse
  via `parseAnyReportDef` to the same `InventoryReportDef` as `parseReportDef`; a v3 with a problem → null; needsIdle;
  the cache isn't rebuilt when only list 4 changes (a build counter like `poolIndexBuilds`).
- [ ] Lint, tsc, tests; commit.

### Task O4: The built-in and the mock data (app)

**Files:** Modify `src/inventory/builtIns.ts`, the mock fixtures (`src/data/mock/jdFixtures.ts`,
`jdIdleFixtures.ts` or wherever they live), `src/inventory/__tests__/builtIns.test.ts`.

- [ ] `CORPORATE_STOCKING: PartReportDef` per the spec (counted: branch notOneOf 2, 4 + package qty eq 1, return
  indicator is R, source isNot AN, slc notStartsWith 21, 90, 91, 99, reusing the matching items of `PART_FILTERS`;
  every: onHand eq 0, onOrder eq 0, superTo blank; demandAt: branch notOneOf 2, 4; conditions: demandBranches ge 3).
  `BuiltInReport` gains an optional grain: make `def: AnyReportDef`; `CORPORATE_STOCKING_BUILT_IN` (id
  `corporate-stocking`, name "Corporate Stocking", description from the workbook's purpose in one sentence, columns =
  the workbook's 12, CSV headers = the workbook's), appended to `BUILT_INS`. Update `copyColumns` and any `BuiltInReport`
  consumer that assumed `InventoryReportDef` (tsc will list them; for a part report they take the part columns).
- [ ] Mock: JD-CS-* parts at branches 1, 3, 6, 11 that no other built-in finds (Corp demands 1 or 3, never 2; no
  candidates at 95/91/96 or 2/4; no cotton dealer groups): JD-CS-OK (demand at 1, 3, 6; zero stock) listed;
  JD-CS-OH (one counted record on hand 1) not; JD-CS-B2 (on hand 5 only at branch 2) listed; JD-CS-SLC (SLC 21A on hand
  5 at 11) listed; JD-CS-SUP (an idle record at 11 with Super To) not; JD-CS-2B (demand at two branches) not;
  JD-CS-AN (a demand at 11 whose record is source AN) listed with 3 locations.
- [ ] Tests: the built-in against the mock finds exactly OK, B2, SLC, AN, in the default order; MLPF Gaps, Border
  Stores and 2 & 4 Cotton find the same rows as before (their existing tests unchanged and passing).
- [ ] Lint, tsc, tests (`src/inventory`, `src/pages/inventory`, the click-throughs); commit.

### Task O5: List page and loading (app)

**Files:** Modify `src/pages/inventory/reportLoad.ts`, `useReportsList.ts`, `InventoryReportsPage.tsx` and their tests.

- [ ] Saved reports parse with `parseAnyReportDef`; the list shows Corporate Stocking among the built-ins with the
  Count button (it always needs the idle files); a part report's count = `rows.length`. Copy as my own of a part
  report opens the editor with the four lists (O7). Saving writes `anyReportDefToJson`.
- [ ] Tests: the built-in's Count on mock = 4; a stored v3 copy lists and counts; an unreadable v3 says so as a bad
  stored report does today.
- [ ] Lint, tsc, tests; commit.

### Task O6: Results page and details panel for part reports (app)

**Files:** Create `src/pages/inventory/PartReportResultsPage.tsx`, `src/pages/inventory/PartRecordsPanel.tsx`,
`src/inventory/partResults.ts` (+ tests); modify the route / `ReportResultsPage.tsx` to hand a part report to the new
page.

- [ ] `partResults.ts`: `filterPartRows(rows, { search, demandAt })` (search = part number or description,
  case-insensitive, as `filterReportRows`; `demandAt` = a branch code → parts whose `demandLocations` include it),
  `sortPartRows(rows, sort)` (any column; default = O3's order), `partReportCsv(rows, columns, headers)` (the
  workbook's headings; Locations as the ", " text), `totalCost`.
- [ ] The page mirrors `ReportResultsPage` (Data as of, search, a **Demand at branch** select listing branches with a
  label, sortable columns, row count and total cost, Export CSV, the missing-branches / needsIdle messages); a row
  opens `PartRecordsPanel`: a table of every record (branch, on hand, on order, Super To, Corp demands, Counted:
  "Yes" / "No: not in Records that count" / "No: fails Every counted record must"; demand counted ✓).
- [ ] Tests: columns and default order; Demand at branch filter; search; CSV headers and the Locations cell; the panel's
  rows and reasons for JD-CS-AN.
- [ ] Lint, tsc, tests; commit.

### Task O7: Editor for part reports (app)

**Files:** Modify `src/pages/inventory/ReportEditorPage.tsx` (+ tests); reuse `ConditionListEditor` / `GroupRowEditor`.

- [ ] New report: a choice at the top, **One row per branch** (today) / **One row per part**, only when creating;
  a copy or an edit keeps its grain. A part report shows four cards in order (titles from the spec, a one-line hint
  each), lists 1–3 with `JD_ROW_CATALOGUE`'s fields, list 4 with `PART_CATALOGUE`'s; Try it runs
  `compilePartReport`; saving validates with `partReportDefProblem`.
- [ ] Tests: create a part report from scratch (choose the grain, a list-4 condition, save → v3 JSON); copy Corporate
  Stocking, change list 4 to `≥ 4` and list 1's branch to `not one of 2, 4, 12`, Try it, save; edit keeps the grain;
  a branch report's editor is unchanged (existing tests pass).
- [ ] Lint, tsc, tests; commit.

### Task O8: Version, click-through, try-it notes (app + data-projects)

- [ ] `package.json` / `package-lock.json` / README version table 0.14.0 (as commit 1319ca9 did).
- [ ] `src/__tests__/clickThrough0140.test.tsx` (model: `clickThrough0130.test.tsx`): Inventory → Count Corporate
  Stocking (4) → open it → the four parts in order → click JD-CS-AN, panel → Export CSV headers → Copy as my own →
  list 4 ≥ 4 → Try it (0) → save.
- [ ] Full suite in two halves (`npx vitest run src/pages` and `npx vitest run --exclude 'src/pages/**'`), lint, tsc;
  commit; push dev.
- [ ] `projects/part order tool - app/for-users/0.14.0-try-it.md` (data-projects): three short jobs on mock.

### Task O9: Excel gate and release (Claude + Brian)

1. Brian's try-it on mock.
2. Brian refreshes `SPI Corparate Stocking.xlsx` in the evening; after the next morning's Prod refresh:
   `corp_parts_check.py --tier prod --groups-tier prod --report stocking --as-of '<refresh time>' --compare-xlsx
   <copy> --diff-out <csv>` → every difference explained by part.
3. Release build, dist checks (list IDs, no mock strings, About 0.14.0), upload to Fedora staging; Brian installs.
4. Real test: Corporate Stocking count ≈ the reference; its CSV compared with the reference row for row; a TEST copy
   (list 4 ≥ 4) checked in SharePoint (v3 JSON) and deleted.
5. Docs: guide section + walkthrough 0.14.0 (regenerate both .docx), INVENTORY-REPORTS.md, FUTURE-IDEAS (F4: Pieces
   In Set next), plan/spec progress, memory.
