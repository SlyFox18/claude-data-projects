# SPI Parts Hub round 3 phase 3: Cleanup checks (Plan K, app 0.11.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a
> review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-11-02 (Claude, for Brian). Decisions K-D1–K-D11 approved by Brian 2026-11-02.
> - **K7a done 2026-11-02** (app `b870a9d`, review fixes `240c7d7`; 2,494 tests in two halves, lint, tsc clean; pushed).
>   Old page moved (git mv) to `/cleanup/minimums` (H1 "Minimums with no demand", otherwise unchanged); `/cleanup` =
>   "Cleanup checks" list (built-ins, saved, Off, unreadable, Show archived; counts cached per conditions + data;
>   switch / archive with alertdialog, re-read, name clash refused on Switch on / Unarchive); results at
>   `/cleanup/value-no-qty` and `/cleanup/check/:id` (filters, per-branch row cache, sort deferred until loading ends,
>   unique columns, CSV via formatQty, `-partial` only when the filter's branches aren't all loaded); rail "Checks";
>   breadcrumb shows the check's name. Measured ~20–30 ms per check over 201,600 parts. `/cleanup/new` placeholder
>   until K7b.
> - **K6 done 2026-11-02** (app `d38f66d`, review fixes `8884837`; plus `b90217d` the $1 built-in; 2,446 tests in two halves,
>   lint, tsc clean; pushed). `loadCleanupChecks()` → `{ rows, unreadable }` (unreadable rows keep itemId, name, reason,
>   active, archived, modified, editor, so the page can show "can't be read" and still archive them); writes refuse a
>   blank or > 255-char name and invalid conditions before any request. Mock seeds "Old stock, no sales 2 years" (On
>   hand > 0, Sales 24 months = 0, Last received before 24 months ago or never; Ben Hill) and archived "Zero-cost parts".
>   New field `equipStockValueAbs` "Equip stock value (either way)"; `VALUE_NO_QTY` = that ≥ $1 and On hand ≤ 0;
>   `VALUE_NO_QTY_COLUMNS` = On hand, Cost, Equip stock value (signed).
> - **K3 done 2026-11-02** (data-projects `db8988cd`; publish tests 260 pass; pushed). Contract 5, `equipStockValue` required
>   and rounded to cents; older Gold refused naming EquipStockValue. Local `--out` build on Dev: 199,555 parts all with
>   the field, `_meta.json` contractVersion 5. Not published (K10). **Decided (Brian, 2026-11-02: A):** the built-in
>   "Stock value with no quantity" ignores values under $1 either way (Dev: 741 parts with a value and nothing on hand,
>   292 of them under $1 totalling −$19.31; 449 of $1 or more, −$144,056). Implemented as a new field "Equip stock value
>   (either way)" (absolute value): built-in = that ≥ $1 and On hand ≤ 0.
> - **K5 done 2026-11-02** (app `865efba`, review fixes `4966e59`; 2,430 tests in two halves, lint, tsc clean; pushed).
>   `src/cleanup/fields.ts` (21 fields, `comparisonsFor(id)`, `fieldInData`), `conditions.ts` (`parseConditions`,
>   `conditionProblem`, `compileConditions` + `matches`, `conditionText`, `checkColumns`, `VALUE_NO_QTY`). **Decided:**
>   number/money comparisons never match a blank (only "is blank"); text "is not" does; new `beforeOrNever` ("before
>   …, or never") for Last requested / Last received; Vendor is text (digits, is / is not / one of). Shared `money`,
>   `lastRequestedDate`, `STATUS_LABELS` now in `@/engine` (no engine → pages imports).
> - **K1 + K2 done 2026-11-02** (fabric-workspace-docs `863afe35`, data-projects `f59073c9`; review clean). Gold
>   `EquipStockValue` = round(Silver_PartInformation.InventoryCost, 2), decimal(18,2), after LastReceived (Silver's
>   InventoryCost is DECIMAL(12,2), coalesced to 0). Dev git-synced, Dev run `b8fce472` Completed (gold 254 s); reference
>   check `--tier dev` PASS, 0 differences on all three tables (Reorder 199,555 rows). The Dev email's Parts
>   Availability staleness warning is Dev-only (no Dev schedule); Prod reported no problems.
> - **K4 done 2026-11-02** (app `dcdf737`; 2,310 tests in two halves, lint, tsc clean; review clean; pushed). Contract
>   [3, 4, 5], `hasEquipStockValue`, `ReorderPart.equipStockValue?`, required `VITE_LIST_CLEANUP_CHECKS`; mock v5
>   (default value = on-hand value; seeded BS-VAL-NOQTY 0 on hand / $120, BS-VAL-NEG −2 / −$45, BS-QTY-NOVAL 3 / $0 at
>   branch 1); `SlimPart` 29 fields (≈ +30–40 MB for ~200k parts; key always present, so test `=== undefined`).
> - **K0 done 2026-11-02:** NonJD_CleanupChecks `a7a1a184-8421-440b-84e8-95ba37e3612b` created by Brian and checked
>   (Description, Conditions plain multi-line; Active default Yes; Archived default No). `.env` line
>   `VITE_LIST_CLEANUP_CHECKS` given to Brian.

**Goal:** Cleanup becomes a list of checks: the built-in **Minimums with no demand**, a new built-in **Stock value
with no quantity** (Ben's "value without quantity"), and checks anyone can save from conditions (field · comparison ·
value, all must match), each with a branch filter, a count and a CSV.

**Architecture:** Gold adds Equip's own stock value (`Silver_PartInformation.InventoryCost`, Equip's ON_HAND_VAL) to
Fact_NonJD_Reorder as `EquipStockValue`; the reference check compares it; the publish carries it as `equipStockValue`
in contract v5. The app adds a pure condition engine, a SharePoint list for saved checks, a check list page, a check
page (results) and a condition editor with a live count.

**Tech stack:** Fabric notebook (PySpark) in fabric-workspace-docs; DuckDB reference check and the Python publish in
data-projects; nonjd-order-app (React 19, TypeScript, Vite, Tailwind 4, react-router 7, Vitest).

**Spec:** `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md`, "Phase 3 (0.11.0)" and R12.

---

## What Prod shows today (2026-11-02, Fact_NonJD_Reorder joined to Silver_PartInformation)

- 199,706 Non-JD part rows; 25,919 have a non-zero Equip stock value.
- **444** have a stock value with 0 on hand; **254** have a value with negative on hand (e.g. RM-24V at 11: on hand
  −126, cost $500, value −$63,000). Together: −$137,786.25.
- **3,322** have stock on hand but a 0 stock value.
- Equip's value is close to, not exactly, on hand × cost (total absolute gap ≈ $923k across all rows).

## How we run this plan

- Same as Plans I and J: one task at a time, a review after each, fixes, push. Stage named files only; `.env*` never
  read or committed. App tests in two halves (`npx vitest run --exclude "src/pages/__tests__/**"`, then
  `npx vitest run src/pages/__tests__`), lint, tsc. `npm run build` only in K9. Commits end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Fabric: work on `dev` in fabric-workspace-docs; `python deploy/dag_check.py`, `python -m pytest deploy -q`; git sync
  Dev; never `fab import`. Brian merges and runs the deploys.
- **Order matters (as in Plan I):** app 0.11.0 (reads v4 and v5) on Fedora before the Gateway PC publishes v5; Prod
  Gold with `EquipStockValue` before the Gateway PC pulls the v5 publish code.

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| K-D1 | **Equip stock value = `Silver_PartInformation.InventoryCost`** (Equip ON_HAND_VAL, already used by other Gold notebooks), published per part as `equipStockValue` (dollars, 2 dp, never null; Silver coalesces to 0). | Spec phase 3; it's Equip's own figure, not qty × cost. |
| K-D2 | **Contract v5.** The app accepts 3, 4 and 5. On a v4 file the Equip stock value field is "not in today's data yet": conditions on it and the built-in Stock value check say so and can't run. | The app must tell "0" from "not published". |
| K-D3 | **On-hand value** (app-derived) = max(0, trunc(on hand)) × cost, the same as the returns stock-value base. | One definition across the app. |
| K-D4 | **Fields** (label · type): On hand · number; On order · number; Pending · number; Back order · number; Cost · money; On-hand value · money; Equip stock value · money; Equip minimum · number (blank = none); Equip maximum · number (blank = none); Sales 12 months · number; Sales 24 months · number (sales 12 + previous 12); Last requested · date (never = blank); Last received · date (never = blank; blank on v3); Status · choice; Franchise · text; Dealer group · text; Vendor · number; Product group · text; SLC · text; Source · text; Manual order · yes/no. **Not** last sold (needs every branch's history files: too heavy for a list over all branches). | Spec list plus the few Equip quantities people ask about; YAGNI on history. |
| K-D5 | **Comparisons by type.** Number / money: = ≠ < ≤ > ≥, is blank, is not blank (blank only for min / max). Date: before, after (a date, or "N months ago" so a check stays current), is blank, is not blank. Text: is, is not, one of, is blank, is not blank (trimmed, case-insensitive; dealer group "(none)" = blank). Choice (status): one of. Yes/no: is yes, is no. | Spec's comparisons, with relative dates for checks that are reused month after month. |
| K-D6 | **Built-in checks** (always there, can't be edited or archived): **Minimums with no demand** (as today, Gold's flag) and **Stock value with no quantity**: Equip stock value ≠ 0 and on hand ≤ 0. | Ben's check exists without anyone having to build it. |
| K-D7 | **Saved checks** live in `NonJD_CleanupChecks` (Title, Description, Conditions JSON, Active, Archived). Anyone can create, edit, switch off and archive (as rules). The author is SharePoint's Created By; "changed by" is Modified By. No separate history list. | Spec: "with a name, description and author; Active / Archived". |
| K-D8 | **Pages.** `/cleanup` lists the checks (built-ins first, then active saved checks; Show archived), each with its count over the loaded branches. `/cleanup/minimums` is today's page unchanged. `/cleanup/value-no-qty` and `/cleanup/check/<id>` are the shared results page. `/cleanup/new` and `/cleanup/check/<id>/edit` are the editor. | Today's page keeps working; one results page for everything else. |
| K-D9 | **Results page:** branch filter, franchise filter, count and total value, sortable table: Branch, Franchise, Part (link), Description, Bin, then the fields the check's conditions use (and On hand, Cost, Equip stock value for the built-in); **Export CSV** with the same columns (`neutraliseFormula` on text). Over all branches via `useAllBranches`. | Spec: "branch filter, count, export CSV". |
| K-D10 | **Editor:** name, description, condition rows (field select → comparison select → value input fitted to the type; add / remove rows; at least one), a live **Try it** count and the first 20 matching parts over every loaded branch, **Save check**. "Nothing is saved until Save check." Unsaved changes ask before leaving. | Same pattern as the rule editors. |
| K-D11 | **Launch card** keeps today's count (minimums with no demand at your branch). | Unchanged; checks are many. |

## SharePoint list (K0, Brian)

**NonJD_CleanupChecks**
| Column | Type | Notes |
|---|---|---|
| Title | (built in) | the check's name |
| Description | Multiple lines of text (plain) | optional |
| Conditions | Multiple lines of text (plain) | JSON, written by the app |
| Active | Yes/No | default Yes |
| Archived | Yes/No | default No |

Then `VITE_LIST_CLEANUP_CHECKS=<id>` in `.env.production` and `.env.example` (Claude reads the ID through Graph).

## File map

| Repo | File | Change |
|---|---|---|
| fabric-workspace-docs | `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py` | read `InventoryCost`; output `EquipStockValue` after `LastReceived` |
| fabric-workspace-docs | `docs/TABLE-LINEAGE.md` (generated) | regenerate if the column list is in it |
| data-projects | `tools/dp-migration/nonjd_reorder_check.py` (+ test) | read and compare `EquipStockValue` (tolerance 0.005) |
| data-projects | `projects/part order tool - app/publish/` extract, build_files, publish_logic, README, tests | `equipStockValue`, contract 5 |
| app | `src/data/contract.ts`, `types.ts`, mock | v5; `equipStockValue?: number` |
| app | `src/state/allBranches.ts` | `SlimPart` gains the K-D4 fields |
| app | `src/cleanup/fields.ts`, `conditions.ts` (new, pure) | field catalogue, condition types, validation, evaluation, text |
| app | `src/config.ts`, `src/data/source.ts`, `lists.ts`, mock | `NonJD_CleanupChecks` |
| app | `src/pages/CleanupPage.tsx` → `src/pages/cleanup/MinimumsPage.tsx`; new `CleanupChecksPage.tsx`, `CheckResultsPage.tsx`, `CheckEditorPage.tsx`; `src/App.tsx`, `src/ui/areas.ts` | pages and routes |

---

## Tasks

### Task K0: List and ID (Brian, with Claude)

- [ ] **Step 1:** Brian creates `NonJD_CleanupChecks` (above).
- [ ] **Step 2:** Claude reads its ID and checks the columns through Graph (plain multi-line, Active default Yes,
  Archived default No); gives Brian the `.env` line.

### Task K1: Gold `EquipStockValue` (fabric-workspace-docs, Dev)

- [ ] **Step 1:** in the notebook's Silver_PartInformation select (≈ line 133) add `InventoryCost`; carry it through
  `calc` and add `F.round(F.col("InventoryCost"), 2).cast("decimal(18,2)").alias("EquipStockValue")` to `final` right
  after `LastReceived` (before `BuiltAtUtc`); header note "round 3 (Plan K): EquipStockValue = Equip's ON_HAND_VAL".
  Keep the existing types of the other columns; no dropDuplicates; key unchanged.
- [ ] **Step 2:** `python deploy/dag_check.py`, `python deploy/hygiene_audit.py` (if it covers this notebook),
  `python -m pytest deploy -q`. Commit on dev, push, git sync DP - Presentation - Dev, run the Dev pipeline with
  `mode=items items=Build_Gold_NonJD_Reorder` (Claude may run Dev); confirm Completed.

### Task K2: Reference check

- [ ] **Step 1:** `nonjd_reorder_check.py`: read `InventoryCost` with the part rows; expected
  `EquipStockValue = round(InventoryCost, 2)`; add to `OUTPUT_COLS` and `TOLERANCE_COLS` (0.005); docstring note. Test
  in `test_nonjd_reorder_check.py` (a row with a value and 0 on hand passes through).
- [ ] **Step 2:** `--tier dev` → PASS with 0 differences. Commit, push.

### Task K3: Publish contract v5

- [ ] **Step 1 (tests first):** `test_extract.py` (Gold column list gains `EquipStockValue`; an older Gold without it
  fails `check_columns` naming it), `test_build_files.py` (`equipStockValue` rounded to cents, required, never null;
  `_meta.json` `contractVersion == 5`).
- [ ] **Step 2:** `extract.REORDER_COLUMNS` += `("EquipStockValue", "equipStockValue")`; `build_files` `_equip_stock_value`
  (present, finite, round 2; missing → error naming it); `publish_logic.CONTRACT_VERSION = 5` with the history line;
  README: contract history ("5 = round 3 phase 3: equipStockValue; deploy app 0.11.0 first"), null rules, field count,
  field row. 
- [ ] **Step 3:** tests pass; local `--out` build against Dev (Claude, if az tokens allow; else Brian). **Don't publish
  v5 until K10.** Commit, push.

### Task K4: App data: v5 and the slim fields

- [ ] **Step 1:** `contract.ts`: `SUPPORTED_CONTRACT_VERSIONS = [3, 4, 5]`, `CONTRACT_VERSION = 5`,
  `hasEquipStockValue(meta) = contractVersion >= 5`. `ReorderPart.equipStockValue?: number` ("undefined = a v3/v4
  file"). Mock: `contractVersion?: 3 | 4 | 5` (default 5) with seeded values: add mock parts for the built-in check
  (at branch 1: one with value $120.00 and on hand 0; one with on hand −2 and value −$45.00; one with on hand 3 and
  value 0) and an `asV4` that deletes the field.
- [ ] **Step 2:** `SlimPart` gains `pendingQty, backOrder, maximumQty, salesPrev12, lastReceived, dealerGroupCode,
  vendorCode, productGroup, slc, source, manualOrder, equipStockValue` (the latter two optional per version);
  `slimReorder` copies them. Check Part Lookup and Special statuses still pass. Tests. Commit "K4: v5 data and slim
  fields".

### Task K5: The condition engine (pure)

**Files:** `src/cleanup/fields.ts`, `src/cleanup/conditions.ts`, tests beside them.

- [ ] **Step 1: types**

```ts
export type FieldType = 'number' | 'money' | 'date' | 'text' | 'choice' | 'yesno';
export type FieldId =
  | 'onHand' | 'onOrder' | 'pending' | 'backOrder' | 'cost' | 'onHandValue' | 'equipStockValue'
  | 'minimum' | 'maximum' | 'sales12' | 'sales24' | 'lastRequested' | 'lastReceived'
  | 'status' | 'franchise' | 'dealerGroup' | 'vendor' | 'productGroup' | 'slc' | 'source' | 'manualOrder';

export interface FieldDef {
  id: FieldId; label: string; type: FieldType;
  /** The part's value; null = blank (never requested, no minimum, …); undefined = not in today's data (older file). */
  read(p: SlimPart): number | string | boolean | null | undefined;
}

export type Comparison =
  | 'eq' | 'ne' | 'lt' | 'le' | 'gt' | 'ge'           // number, money
  | 'before' | 'after'                                 // date
  | 'is' | 'isNot' | 'oneOf'                           // text, choice
  | 'yes' | 'no'                                       // yesno
  | 'blank' | 'notBlank';

export type ConditionValue =
  | { kind: 'number'; value: number }
  | { kind: 'date'; value: string }            // 'YYYY-MM-DD'
  | { kind: 'monthsAgo'; months: number }       // whole months before today (Central), 1..120
  | { kind: 'text'; value: string }
  | { kind: 'list'; values: string[] }
  | { kind: 'none' };

export interface Condition { field: FieldId; op: Comparison; value: ConditionValue; }
export interface CleanupCheck { name: string; description: string; active: boolean; archived: boolean; conditions: Condition[]; }
```

- [ ] **Step 2: functions** (each with tests first):
  - `FIELDS: readonly FieldDef[]` and `fieldDef(id)`; `comparisonsFor(type): Comparison[]` per K-D5 (blank / not
    blank only for minimum, maximum, the two dates and text fields).
  - `parseConditions(x: unknown): Condition[] | null` (strict, as `parseTemplateSetup`: known field, an op allowed for
    its type, a value kind that fits the op; text trimmed; lists de-duplicated; ≥ 1 condition).
  - `conditionProblem(c): string | null` (UI validation: "Enter a number.", "Pick a date.", "Enter whole months from 1
    to 120.", "Pick at least one.").
  - `matches(p: SlimPart, conditions: Condition[], today: string): boolean | 'unknown'`: all must match; a field
    whose value is `undefined` (older file) makes the result `'unknown'`; text compares trimmed and upper-cased; dates
    compare date strings; `monthsAgo` resolves to the date N months before `today` (same day, clamped to month end);
    blank = null.
  - `conditionText(c): string` ("On hand ≤ 0", "Equip stock value ≠ $0.00", "Last received before 6 months ago",
    "Franchise one of BS, KU") and `conditionsText(cs)` joined with " and ".
  - `usesUnknownField(conditions, meta)`: true when a condition reads `equipStockValue` and the data is v4.
- [ ] **Step 3:** the built-ins as data: `VALUE_NO_QTY: Condition[] = [{ field: 'equipStockValue', op: 'ne', value:
  { kind: 'number', value: 0 } }, { field: 'onHand', op: 'le', value: { kind: 'number', value: 0 } }]`. Test on the
  mock parts from K4: exactly the two with a value and no quantity match; on a v4 mock the result is `'unknown'`.
- [ ] **Step 4:** full suites, lint, tsc. Commit "K5: condition engine".

### Task K6: Saved checks list

- [ ] Config `lists.cleanupChecks` (`VITE_LIST_CLEANUP_CHECKS`, required); DataSource `loadCleanupChecks()`,
  `saveCleanupCheck(c: CleanupCheckInput): Promise<number>`, `patchCleanupCheck(itemId, patch)`; Graph mappers (skip a
  row with a blank Title or Conditions that fail `parseConditions`; writes validate first and throw, as templates);
  `CleanupCheckRow extends CleanupCheck, ItemAudit { itemId; author: string | null; created: string | null }`; mock
  seeds one active check "Old stock, no sales 2 years" (On hand > 0 and Sales 24 months = 0 and Last received before
  24 months ago; author 'Ben Hill') and one archived. Tests. Commit "K6: cleanup checks list".

### Task K7: Pages

- [ ] **Step 1:** move today's `CleanupPage` to `src/pages/cleanup/MinimumsPage.tsx` at `/cleanup/minimums`
  unchanged (tests move with it); `/cleanup` becomes `CleanupChecksPage`: cards or a table of checks (name,
  description, conditions text, author, changed, count over loaded branches with the all-branch progress), built-ins
  first, **New check**, Show archived (N), switch off / on, archive / unarchive (ask first; re-read first).
- [ ] **Step 2:** `CheckResultsPage` for `/cleanup/value-no-qty` and `/cleanup/check/:id` (K-D9): filters, count,
  total Equip stock value or on-hand value, sortable table, Export CSV (`Cleanup-<check name>-<yyyymmdd>[-partial].csv`),
  partial-export note as today; on v4 data a check that reads Equip stock value shows "Equip stock value isn't in
  today's data yet. It arrives with the next publish." and no rows.
- [ ] **Step 3:** `CheckEditorPage` (K-D10) with the condition rows, Try it (count + first 20), Save check (re-read
  for name clash among active, unarchived checks: "A check called X already exists."), leave guard.
- [ ] **Step 4:** rail: Cleanup's screens become "Checks" (`/cleanup`) only (the results and editor are reached from
  it); breadcrumbs. Tests for each page on the mock. Commit "K7: cleanup pages".

### Task K8: Click-through and try-it notes

- [ ] `src/__tests__/clickThrough0110.test.tsx`: Cleanup → the built-in Stock value with no quantity (2 mock parts,
  CSV) → Minimums with no demand still works → New check (On hand > 0, Sales 24 months = 0) → Try it count → Save →
  it's listed with a count → open → Export → edit and switch off → archive.
- [ ] `for-users/0.11.0-try-it.md`: three short jobs ("Find stock value with no quantity", "Build your own check",
  "Tidy the list"), each with what to look for (as 0.10.0's).

### Task K9: Review and 0.11.0 build

- [ ] typescript-reviewer over K4–K8; fixes; full suites, lint, tsc; `package.json` 0.11.0 and README row;
  `npm run build`; check dist (the new list ID plus the existing lists and site, no mock strings, "Version 0.11.0 ·
  commit …"). Push.

### Task K10: Release (Brian's steps, one at a time)

1. fabric-workspace-docs PR dev → main (`merge_preview.py`); Brian merges (merge commit), runs **Deploy DP backend**,
   then `claim_prod_pipeline.py`; Claude fast-forwards dev.
2. Brian deploys app 0.11.0 to Fedora (it reads v4 now and v5 later).
3. Brian runs Prod Pipeline_DP_Refresh `mode=items items=Build_Gold_NonJD_Reorder` (or waits for 06:15); Claude runs
   `nonjd_reorder_check.py --tier prod` → PASS.
4. Brian pulls `C:\data-projects` on the Gateway PC and runs `.venv\Scripts\python.exe run_publish.py`; Claude
   confirms `_meta.json` `contractVersion: 5`.
5. Real test on Fedora: the built-in Stock value with no quantity shows ≈ 698 parts (444 + 254 on today's figures);
   Brian saves a TEST check, switches it off and archives it; Claude checks the row through Graph and deletes it.

### Task K11: Documents and progress

- [ ] Guide section "Cleanup checks (0.11.0)" (task-shaped), walkthrough "Version 0.11.0", regenerate both .docx
  (hand-edit check first), `REORDER-RULES.md` or a short `CLEANUP-CHECKS.md` reference for Ben (fields, comparisons,
  the two built-ins, Equip stock value vs on-hand value), FUTURE-IDEAS F1 → done in 0.11.0; plan and spec Progress;
  memory.

---

## Self-review against the spec

- Cleanup lists the built-in Minimums with no demand and saved checks (K7 Step 1); each check rows of field ·
  comparison · value, all must match (K5); name, description, author; Active / Archived (K6, K7).
- Fields (spec list): on hand, pending, cost, on-hand value, Equip stock value, minimum, maximum, sales 12 / 24 months,
  last requested, last received, status, franchise, dealer group, vendor, product group, SLC, source: K-D4 / K5 (plus
  on order, back order, manual order).
- Comparisons = ≠ < ≤ > ≥, is blank / is not blank, before / after, one of: K-D5 / K5.
- Ben's value-without-quantity check with Equip's own stock value in Gold and the publish: K1–K3, K-D6.
- Each check: branch filter, count, export CSV: K7 Step 2. List `NonJD_CleanupChecks` with conditions as JSON: K0, K6.
- Testing: pure condition functions (K5), reference check 0 differences on Dev and Prod (K2, K10), mock covering
  each case, click-through, review, real test and cleanup (K8–K10).
