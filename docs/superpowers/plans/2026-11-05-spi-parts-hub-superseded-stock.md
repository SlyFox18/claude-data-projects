# Stock on superseded parts (Plan P, app 0.15.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

> **Shipped 2026-11-05:** app 0.15.0 (commit `130b68e`) on Fedora, installed by Brian. Commits: P1 e9076500
> (data-projects, `superseded_stock_check.py`); app d60870d (P2), 4d83afa (P3), b7a1c3c (P4), d0d424e (P5), 130b68e
> (review tidy-ups: `isConditionBuiltInId` in place of casts). P3 + P4 reviewed and approved; 3,022 tests, lint and tsc
> clean. App only: no Fabric, publish or contract change.
> **Real test (2026-11-05):** the app's CSVs against `superseded_stock_check.py --tier prod`: JD 2,477 = 2,477 records at
> 20 branches, non-JD 698 = 698 at 19 branches, 0 differences in on hand or Super To. On-hand value: JD $571,028.49,
> non-JD $497,322.78. 22 non-JD records have a word Super To.
> **Differences from the plan below:** `cents()` returns dollars rounded to 2 places, so P2's test expects 6.75, not 675;
> the JD part panel lists every JD field, so it shows On-hand value too; the JD report keeps the default part-number
> sort; MC-SS-1 has no sales, so on mock it also joins the Scrap default (14 → 15 lines, $959 → $1,013; no doc quotes
> these); About can't show the version in tests (`__APP_VERSION__` is a test value), so the click-through checks
> `package.json`.

**Goal:** Two built-ins, "Stock on superseded parts" (on hand > 0 and a Super To): a fifth Inventory report over JD
records and a third Cleanup check over non-JD parts.

**Architecture:** App only (spec P-D4). The JD report is one more `BranchBuiltIn` in `src/inventory/builtIns.ts`,
active rows only. The Cleanup check needs `superTo` on `SlimPart` and a Super To catalogue field; the special-cased
`'value-no-qty'` built-in becomes a small table of condition built-ins so the new one is data, not more special cases.

**Tech Stack:** React 19 + TS + Vite + Vitest (nonjd-order-app, branch `dev`); Python + DuckDB for the reference
(data-projects `tools/dp-migration`).

**Spec:** `docs/superpowers/specs/2026-11-05-spi-parts-hub-superseded-stock-design.md`.

**Prod reference (2026-11-05, Gold):** JD `Fact_CorpParts_JD` 2,477 records with on hand > 0 and a Super To;
`Fact_CorpParts_JD_Idle` has no on-hand column (idle = no stock), so the JD report reads active rows only;
non-JD `Fact_NonJD_Reorder` 698 records at 19 branches (22 with a word Super To such as `BOLTS`).

**Rules for every task:** work on `dev`; stage only the named files (`.env.example` has an unrelated change; never
`git add -A`); never read `.env*`; don't run `npm run build` (P6 only); commit messages end with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run tests with `npx vitest run <paths>`; `npx tsc -b
--noEmit` and `npx eslint <files>` before each commit.

---

### Task P1: Reference check script (data-projects)

**Files:**
- Create: `tools/dp-migration/superseded_stock_check.py`
- Test: `tools/dp-migration/test_superseded_stock_check.py`

- [x] **Step 1: Write the failing test**

```python
import duckdb

import superseded_stock_check as s


def _con():
    con = duckdb.connect()
    con.execute("""CREATE TABLE t AS SELECT * FROM (VALUES
        ('1', 'A', 2.0, 'B'), ('1', 'C', 0.0, 'D'), ('7', 'E', 1.0, '  '), ('7', 'F', 3.0, NULL),
        ('11', 'G', 1.0, 'BOLTS')) v(Branch, PartNumber, QuantityOnHand, SuperTo)""")
    return con


def test_rows_on_hand_and_super_to():
    rows = s.superseded_rows(_con(), "t", "QuantityOnHand")
    assert [(r["Branch"], r["PartNumber"]) for r in rows] == [("1", "A"), ("11", "G")]
```

- [x] **Step 2: Run it to see it fail**

Run: `cd tools/dp-migration && python -m pytest test_superseded_stock_check.py -q`
Expected: FAIL, `ModuleNotFoundError: superseded_stock_check`.

- [x] **Step 3: Write the script**

```python
"""Stock on superseded parts (Plan P): the reference for the app's two built-ins, from Prod or Dev Gold.

JD: Fact_CorpParts_JD (active rows; the idle table has no on hand) where OnHand > 0 and SuperTo is not blank.
Non-JD: Fact_NonJD_Reorder (the publish's source) where QuantityOnHand > 0 and SuperTo is not blank. Branch order
numeric, then part number. Usage: python superseded_stock_check.py --tier prod [--jd-out x.csv] [--nonjd-out y.csv]
"""
import argparse
import csv

import corp_parts_check as c


def superseded_rows(con, source: str, on_hand: str) -> list[dict]:
    cur = con.execute(f"""SELECT trim(Branch) AS Branch, trim(PartNumber) AS PartNumber, {on_hand} AS OnHand,
                                 trim(SuperTo) AS SuperTo
                          FROM {source} WHERE {on_hand} > 0 AND trim(coalesce(SuperTo, '')) <> ''
                          ORDER BY TRY_CAST(trim(Branch) AS INT) NULLS LAST, trim(Branch), trim(PartNumber)""")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def _write(rows: list[dict], path: str) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["Branch", "PartNumber", "OnHand", "SuperTo"])
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tier", choices=["dev", "prod"], required=True)
    ap.add_argument("--jd-out")
    ap.add_argument("--nonjd-out")
    a = ap.parse_args()
    con = c._connect()
    scan = lambda t: f"delta_scan('{c._path(a.tier, 'presentation', t)}')"
    jd = superseded_rows(con, scan("Fact_CorpParts_JD"), "OnHand")
    nonjd = superseded_rows(con, scan("Fact_NonJD_Reorder"), "QuantityOnHand")
    print(f"JD: {len(jd):,} records; non-JD: {len(nonjd):,} records")
    if a.jd_out:
        _write(jd, a.jd_out)
    if a.nonjd_out:
        _write(nonjd, a.nonjd_out)


if __name__ == "__main__":
    main()
```

- [x] **Step 4: Run the test, then the script against Prod**

Run: `python -m pytest test_superseded_stock_check.py -q` → PASS.
Run: `python superseded_stock_check.py --tier prod` → `JD: 2,477 records; non-JD: 698 records` (or today's numbers).

- [x] **Step 5: Commit** (data-projects)

```bash
git add tools/dp-migration/superseded_stock_check.py tools/dp-migration/test_superseded_stock_check.py
git commit -m "Plan P task P1: superseded_stock_check.py (reference for Stock on superseded parts)"
```

---

### Task P2: JD built-in Inventory report

**Files:**
- Modify: `src/inventory/fields.ts` (add `onHandValue` to `JdFieldId` and `JD_FIELDS`)
- Modify: `src/inventory/builtIns.ts` (add `SUPERSEDED_STOCK`, `SUPERSEDED_STOCK_BUILT_IN`; append to `BUILT_INS`)
- Modify: `src/data/mock/jdFixtures.ts` (mock rows)
- Test: `src/inventory/__tests__/builtIns.test.ts` (or the file that tests the other built-ins; `grep -l BORDER_STORES src/inventory/__tests__`)

- [x] **Step 1: Write the failing tests**

```ts
describe('Stock on superseded parts (Plan P)', () => {
  it('is the fifth built-in: on hand > 0 and Super To not blank, active rows only', () => {
    expect(BUILT_INS.map((b) => b.id)).toEqual(
      ['mlpf-gaps', 'border-stores', 'cotton-2-4', 'corporate-stocking', 'superseded-stock']);
    expect(SUPERSEDED_STOCK_BUILT_IN.def).toEqual({
      conditions: [
        { field: 'onHand', op: 'gt', value: { kind: 'number', value: 0 } },
        { field: 'superTo', op: 'notBlank', value: { kind: 'none' } },
      ],
      pool: null, includeIdle: false,
    });
    expect(SUPERSEDED_STOCK_BUILT_IN.csvHeaders).toEqual(['Branch', 'PartNumber', 'Description', 'OnHand', 'Cost',
      'OnHandValue', 'SuperTo', 'Source', 'SLC']);
  });

  it('finds the mock records with stock and a Super To (a word too), not blank or spaces-only, not without stock', () => {
    const found = runBranchBuiltIn(SUPERSEDED_STOCK_BUILT_IN); // the helper the Border Stores tests use over JD_FIXTURES
    expect(found.map((r) => r.partNumber).sort()).toEqual(['JD-SS-BOLTS', 'JD-SS-OK']);
  });

  it('On-hand value is whole units at cost, never below 0', () => {
    const f = JD_CATALOGUE.fieldDef('onHandValue');
    expect(f.read({ ...ROW, onHand: 3.5, cost: 2.25 })).toBe(675); // cents
    expect(f.read({ ...ROW, onHand: -2, cost: 9 })).toBe(0);
  });
});
```

(Use the existing test file's helper for running a built-in over the mock rows and its sample `ROW`; if the op for
"greater than" is not `'gt'`, check `src/cleanup/conditions.ts` op names and use the one the editor offers for
"is more than"; with `'ge'` use value 1 only if quantities are whole. Prefer `'gt'` 0 so 0.5 counts.)

- [x] **Step 2: Run them to see them fail**

Run: `npx vitest run src/inventory/__tests__/builtIns.test.ts -t "superseded"` → FAIL (no export).

- [x] **Step 3: Implement**

In `src/inventory/fields.ts`, add `'onHandValue'` to `JdFieldId` after `'cost'`, and after the `cost` row field:

```ts
  // As the Cleanup checks' On-hand value: whole units on hand (never below 0) at cost.
  rowField('onHandValue', 'On-hand value', 'money', (r) => cents(Math.max(0, Math.trunc(r.onHand)) * r.cost)),
```

In `src/inventory/builtIns.ts`, after `COTTON_2_4_BUILT_IN`:

```ts
/** Stock on superseded parts (Ben, 2026-11-05, Plan P): stock still on hand under a part with a Super To. */
export const SUPERSEDED_STOCK: InventoryReportDef = {
  conditions: [
    { field: 'onHand', op: 'gt', value: { kind: 'number', value: 0 } },
    { field: 'superTo', op: 'notBlank', value: { kind: 'none' } },
  ],
  pool: null,
  // Idle records have no stock by definition (the idle files carry no on hand), so none could pass.
  includeIdle: false,
};

export const SUPERSEDED_STOCK_COLUMNS: readonly JdFieldId[] = ['branch', 'partNumber', 'description', 'onHand',
  'cost', 'onHandValue', 'superTo', 'source', 'slc'];

export const SUPERSEDED_STOCK_BUILT_IN: BranchBuiltIn = {
  id: 'superseded-stock',
  name: 'Stock on superseded parts',
  description: 'JD parts with stock on hand but a Super To: stock still under the old part number (any Super To, ' +
    'notes such as BOLTS too).',
  def: SUPERSEDED_STOCK,
  columns: SUPERSEDED_STOCK_COLUMNS,
  csvHeaders: ['Branch', 'PartNumber', 'Description', 'OnHand', 'Cost', 'OnHandValue', 'SuperTo', 'Source', 'SLC'],
  fileStem: 'Stock on superseded parts',
};
```

and append `SUPERSEDED_STOCK_BUILT_IN` to `BUILT_INS` (after `CORPORATE_STOCKING_BUILT_IN`). Update the file's and
`InventoryReportsPage.tsx`'s header comments that list the built-ins.

In `src/data/mock/jdFixtures.ts`, add at a branch the mock already has (next to the Border Stores rows), using its
existing row helper:
- `JD-SS-OK` on hand 4, cost 12.5, Super To `R334455` (found);
- `JD-SS-BOLTS` on hand 25, cost 0.4, Super To `BOLTS` (found);
- `JD-SS-NONE` on hand 0, Super To `R334456` (not found: no stock);
- `JD-SS-BLANK` on hand 3, Super To `'   '` (not found: spaces only).
Make sure none of them passes MLPF Gaps / Border Stores / Cotton / Corporate Stocking (on hand > 0 or Super To set
already fails their filters), so the existing counts don't move.

- [x] **Step 4: Run the inventory tests**

Run: `npx vitest run src/inventory src/pages/__tests__/inventoryReportsPage.test.tsx src/pages/__tests__/inventoryResultsPage.test.tsx src/__tests__`
Expected: PASS. Tests that list the built-ins (names, counts, BUILT_IN_NAMES in `inventoryReportsPage.test.tsx`)
gain the fifth; update them to include `'Stock on superseded parts'` and its count (2 on mock).

- [x] **Step 5: Commit** (nonjd-order-app)

```bash
git add src/inventory/fields.ts src/inventory/builtIns.ts src/data/mock/jdFixtures.ts <the test files changed>
git commit -m "Plan P task P2: Stock on superseded parts, JD built-in Inventory report"
```

---

### Task P3: Super To for non-JD parts (SlimPart and the Cleanup catalogue)

**Files:**
- Modify: `src/state/allBranches.ts` (`SlimPart.superTo`, `slimReorder`)
- Modify: `src/cleanup/fields.ts` (`superTo` field; add `'superTo'` to `FieldId`)
- Modify: `src/data/mock/fixtures.ts` (`PartSpec.superTo`, used in the `ReorderPart`)
- Test: `src/cleanup/__tests__/fields.test.ts` (or the catalogue's test file), `src/state/__tests__/allBranches.test.ts`

- [x] **Step 1: Write the failing tests**

```ts
it('slimReorder keeps Super To', () => {
  const slim = slimReorder('1', { ...FILE, parts: [{ ...PART, superTo: 'R12' }] });
  expect(slim[0].superTo).toBe('R12');
});

it('Super To: a blankable text field; spaces-only is blank', () => {
  const f = CLEANUP_CATALOGUE.fieldDef('superTo');
  expect(f.label).toBe('Super To');
  expect(f.read({ ...SLIM, superTo: ' R12 ' })).toBe('R12');
  expect(f.read({ ...SLIM, superTo: '   ' })).toBeNull();
});
```

(`FILE`, `PART`, `SLIM`: the sample objects the existing tests in those files build; reuse them.)

- [x] **Step 2: Run them to see them fail** → FAIL (no `superTo`).

- [x] **Step 3: Implement**

`SlimPart`, after `source`:

```ts
  /** Equip's Super To, as published ("" when blank). */
  superTo: string;
```

`slimReorder`: add `superTo: p.superTo,` after `source: p.source,`.

`src/cleanup/fields.ts`, after the `source` field:

```ts
  field('superTo', 'Super To', 'text', (p) => textValue(p.superTo), true),
```

`src/data/mock/fixtures.ts`: add `superTo?: string;` to `PartSpec` and use `superTo: spec.superTo ?? ''` in the
`ReorderPart`. Add two branch-1 specs: `MC-SS-1` ("Old filter head", on hand 3, cost 18, Super To `MC-SS-2`) and
`MC-SS-NO` ("Retired gasket", on hand 0, Super To `MC-SS-3`); give them no history so they don't change reorder
results (check the Reorder page tests' counts still pass; if one counts every branch-1 part, update it).

Any other code that builds a `SlimPart` literal (tests, `grep -rn "minimumNoDemand:" src --include=*.ts*`) gains
`superTo: ''`.

- [x] **Step 4: Run** `npx vitest run src/cleanup src/state src/pages/__tests__` and tsc → PASS.

- [x] **Step 5: Commit**

```bash
git add src/state/allBranches.ts src/cleanup/fields.ts src/data/mock/fixtures.ts <tests changed>
git commit -m "Plan P task P3: Super To on non-JD parts (SlimPart, Cleanup field, mock)"
```

---

### Task P4: Cleanup built-in "Stock on superseded parts"

The built-in "Stock value with no quantity" is special-cased by the literal `'value-no-qty'` in `checkResults.ts`
(`resultFields`, `totalField`), `CheckResultsPage.tsx` (`builtIn?: 'value-no-qty'`, the def at line ~142),
`CleanupChecksPage.tsx` (the count at line ~151), `builtIns.ts`, `App.tsx` (route) and `ui/nav.ts` (title and path
regex). Replace that with one table of condition built-ins.

**Files:**
- Modify: `src/cleanup/conditions.ts` (add `SUPERSEDED_STOCK`, `SUPERSEDED_STOCK_NAME`, `..._DESCRIPTION`, `..._COLUMNS`)
- Modify: `src/pages/cleanup/builtIns.ts` (the table, `ConditionBuiltInId`)
- Modify: `src/pages/cleanup/checkResults.ts`, `CheckResultsPage.tsx`, `CleanupChecksPage.tsx`, `src/App.tsx`, `src/ui/nav.ts`
- Test: `src/pages/__tests__/cleanupChecksPage.test.tsx`, `checkResultsPage.test.tsx` (find with `grep -l value-no-qty src/pages/__tests__`), `src/ui/__tests__/nav.test.ts`

- [x] **Step 1: Write the failing tests**

```ts
// cleanup checks list
it('lists the three built-ins, Stock on superseded parts last, with its count', async () => {
  renderPage();
  await waitFor(() => expect(countOf('superseded-stock')).toMatch(/1 part/));
  expect(builtInNames()).toEqual(['Minimums with no demand', 'Stock value with no quantity', 'Stock on superseded parts']);
});

// results page
it('/cleanup/superseded-stock shows MC-SS-1 with its Super To; On hand, Cost, On-hand value, Super To columns', async () => {
  renderAt('/cleanup/superseded-stock');
  expect(await screen.findByRole('heading', { level: 1, name: 'Stock on superseded parts' })).toBeInTheDocument();
  expect(columnHeaders()).toEqual(expect.arrayContaining(['On hand', 'Cost', 'On-hand value', 'Super To']));
  expect(partNumbers()).toEqual(['MC-SS-1']);
});

// nav
it('titles /cleanup/superseded-stock', () => {
  expect(pageTitle('/cleanup/superseded-stock')).toBe('Stock on superseded parts');
});
```

(Use each file's existing helpers; the names above are placeholders for them: read the file's value-no-qty tests
and mirror them.)

- [x] **Step 2: Run them to see them fail.**

- [x] **Step 3: Implement**

`src/cleanup/conditions.ts`, after `VALUE_NO_QTY_COLUMNS`:

```ts
export const SUPERSEDED_STOCK_NAME = 'Stock on superseded parts';
export const SUPERSEDED_STOCK_DESCRIPTION =
  'Stock on hand on a part with a Super To: stock still under the old part number (any Super To, notes such as ' +
  'BOLTS too).';
export const SUPERSEDED_STOCK: readonly Condition[] = [
  { field: 'onHand', op: 'gt', value: { kind: 'number', value: 0 } },
  { field: 'superTo', op: 'notBlank', value: { kind: 'none' } },
];
export const SUPERSEDED_STOCK_COLUMNS: readonly FieldId[] = ['onHand', 'cost', 'onHandValue', 'superTo'];
```

`src/pages/cleanup/builtIns.ts`:

```ts
export type ConditionBuiltInId = 'value-no-qty' | 'superseded-stock';
export type BuiltInId = 'minimums' | ConditionBuiltInId;

/** A built-in made of conditions (shown by CheckResultsPage): its conditions, columns and what it totals. */
export interface ConditionBuiltIn {
  id: ConditionBuiltInId;
  name: string;
  description: string;
  conditions: readonly Condition[];
  columns: readonly FieldId[];
  total: 'equipStockValue' | 'onHandValue';
}

export const CONDITION_BUILT_INS: Readonly<Record<ConditionBuiltInId, ConditionBuiltIn>> = {
  'value-no-qty': { id: 'value-no-qty', name: VALUE_NO_QTY_NAME, description: VALUE_NO_QTY_DESCRIPTION,
    conditions: VALUE_NO_QTY, columns: VALUE_NO_QTY_COLUMNS, total: 'equipStockValue' },
  'superseded-stock': { id: 'superseded-stock', name: SUPERSEDED_STOCK_NAME,
    description: SUPERSEDED_STOCK_DESCRIPTION, conditions: SUPERSEDED_STOCK, columns: SUPERSEDED_STOCK_COLUMNS,
    total: 'onHandValue' },
};
```

and build `BUILT_IN_CHECKS` as `[minimums, ...Object.values(CONDITION_BUILT_INS).map((b) => ({ id: b.id, name:
b.name, description: b.description, conditionsText: conditionsText(b.conditions), to: `/cleanup/${b.id}` }))]`.

`checkResults.ts`: `resultFields(conditions | ConditionBuiltInId)` returns `[...CONDITION_BUILT_INS[id].columns]`
for a built-in id; `totalField` returns `CONDITION_BUILT_INS[id].total`; `valueNoQtyTest` stays only if something
else uses it (otherwise remove it and use `compileFor(CONDITION_BUILT_INS[id].conditions, now)`).

`CheckResultsPage.tsx`: `builtIn?: ConditionBuiltInId`; the def becomes
`const b = CONDITION_BUILT_INS[builtIn]; return { name: b.name, description: b.description, conditions: b.conditions,
active: true, fields: resultFields(builtIn), total: totalField(builtIn) };`. Update the header comment.

`CleanupChecksPage.tsx`: replace `set('value-no-qty', conditionCount(VALUE_NO_QTY));` with
`for (const b of Object.values(CONDITION_BUILT_INS)) set(b.id, conditionCount(b.conditions));`.

`App.tsx`: replace the value-no-qty route with
`...Object.keys(CONDITION_BUILT_INS).map((id) => ({ path: `cleanup/${id}`, element: <CheckResultsPage key={id} builtIn={id as ConditionBuiltInId} /> }))`.

`ui/nav.ts`: the title lookup uses `CONDITION_BUILT_INS[sub]?.name`; the regex
`(minimums|value-no-qty|superseded-stock|new|check\/...)`.

- [x] **Step 4: Run** `npx vitest run src/pages src/ui src/cleanup src/__tests__`, tsc, lint → PASS. The value-no-qty
tests must pass unchanged (same page, same columns, same total).

- [x] **Step 5: Commit**

```bash
git add src/cleanup/conditions.ts src/pages/cleanup/builtIns.ts src/pages/cleanup/checkResults.ts \
  src/pages/cleanup/CheckResultsPage.tsx src/pages/cleanup/CleanupChecksPage.tsx src/App.tsx src/ui/nav.ts <tests>
git commit -m "Plan P task P4: Cleanup built-in Stock on superseded parts (condition built-ins as a table)"
```

---

### Task P5: 0.15.0, click-through, try-it notes

**Files:**
- Modify: `package.json` (`"version": "0.15.0"`)
- Create: `src/__tests__/clickThrough0150.test.tsx`
- Create (data-projects): `projects/part order tool - app/for-users/0.15.0-try-it.md`

- [x] **Step 1: Click-through test** (mirror `src/__tests__/clickThrough0140.test.tsx`'s setup): Inventory lists
five built-ins and Stock on superseded parts counts 2; opening it lists JD-SS-BOLTS and JD-SS-OK with their Super To;
Export CSV's first line is `Branch,PartNumber,Description,OnHand,Cost,OnHandValue,SuperTo,Source,SLC`. Cleanup lists
three built-ins; Stock on superseded parts counts 1 and shows MC-SS-1 with Super To MC-SS-2; About says 0.15.0.

- [x] **Step 2: Run it** and the full suite in two halves as before (`npx vitest run src/pages` and the rest); tsc;
lint → PASS.

- [x] **Step 3: Try-it notes** (`0.15.0-try-it.md`, the 0.14.0 note's style): 1. Inventory → Stock on superseded
parts (2 parts, Super To column, BOLTS shown on purpose, CSV headings); 2. Cleanup → Stock on superseded parts
(MC-SS-1; MC-SS-NO isn't listed because it has no stock); 3. a saved Cleanup check can now use Super To (New check →
Super To is not blank); then About 0.15.0. Real-app numbers to expect: JD about 2,477, non-JD about 698.

- [x] **Step 4: Commit both repos**

```bash
git add package.json src/__tests__/clickThrough0150.test.tsx
git commit -m "Plan P task P5: 0.15.0 and its click-through"
# data-projects
git add "projects/part order tool - app/for-users/0.15.0-try-it.md"
git commit -m "0.15.0 try-it notes (Stock on superseded parts)"
```

---

### Task P6: Release (with Brian)

- [x] Brian's try-it on mock.
- [x] `npm run build`; dist checks (version 0.15.0, the commit, SharePoint site id, no `JD-SS-OK`/`MC-SS-1` mock data);
  upload to `~/nonjd-order-deploy/dist` on 10.110.100.13; Brian installs (the six sudo steps).
- [x] Real test: run `python tools/dp-migration/superseded_stock_check.py --tier prod --jd-out jd.csv --nonjd-out
  nonjd.csv`; Brian exports both built-ins' CSVs; compare by Branch + PartNumber (every record, on hand, Super To);
  explain any difference (a publish older than Gold's build, trailing-space part numbers).
- [x] Docs: guide + walkthrough (regenerate both .docx: `node guide.js`, `node walkthrough.js`), INVENTORY-REPORTS,
  FUTURE-IDEAS (F10 done), this plan's and the spec's status, memory.
