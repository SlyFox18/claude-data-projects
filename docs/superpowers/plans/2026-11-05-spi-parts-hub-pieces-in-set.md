# Pieces In Set (Plan R, app 0.16.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The SPI Pieces In Set workbook's main list, 3 Months or Less and Review as three built-in Inventory reports that
match Excel. Reports only: nothing on the order screens.

**Architecture:** One Fabric change: `Silver_InMaster.PiecesInSet` and seven columns on `Fact_CorpParts_JD`. Publish
contract v8 carries them on the JD files. In the app they're JD catalogue fields, stored and calculated, and the three
reports are ordinary branch built-ins, so the condition engine, editor, results page and copies need no new behaviour.

**Tech Stack:** PySpark notebooks and `deploy/` tooling (fabric-workspace-docs, branch `dev`); Python publish and DuckDB
reference (data-projects, branch `dev`); React 19 + TS + Vitest (nonjd-order-app, branch `dev`).

**Spec:** `docs/superpowers/specs/2026-11-05-spi-parts-hub-pieces-in-set-design.md`. **Workbook code (the truth, R-D2):**
`projects/corp parts excel reports/SPI-Pieces In Set/SPI - Pieces In Set.pq`, `SPI -Pieces In Set Review.pq`.

**Rules for every task:** stage only named files, never `git add -A` (all three repos hold unrelated changes;
`.env.example` in the app; `CLAUDE.md` and untracked folders in data-projects); never read `.env*`; no `npm run build`
before R7; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Follow
`docs/architecture/dp-notebook-rules.md`. Never `fab import`. No merge to `main`, no Prod deploy and no claim: those are
Brian's.

---

### Task R1: The reference (data-projects)

**Files:** Modify `tools/dp-migration/corp_parts_check.py`, `tools/dp-migration/test_corp_parts_check.py`.

The stats as the query computes them, independent of Gold; the reports for `--report` and `--compare-xlsx`.

- [ ] **Step 1: Failing tests** in `test_corp_parts_check.py`, over small in-memory `parts`, `intrans`, `inmaster` tables
in the file's existing style:

```python
def test_pis_worked_example():
    # The query's own example: invoices of 2, 2, 2, 1 => SPI PIS 2, Match 75.0, Invoices 4, Sales 7.
    ...
    assert (row["SPI PIS"], row["Match %"], row["Invoices"], row["Sales Qty"]) == (2, 75.0, 4, 7)

def test_pis_split_lines_and_credits():
    # Two lines of one invoice sum; a credit nets into its OriginalInvoiceNo; a fully returned invoice drops out;
    # a credit whose invoice is outside the window drops out; transfers never count.

def test_pis_round_up():
    # Stock 0 => one full set; stock 3, set 2 => up to 4, Recommended 1; stock 4, set 2 => 4, Recommended 0;
    # Recommended Cost = Cost x Recommended Qty.

def test_pis_filters():
    # Branches 2 and 4 out; Super To set out; 2 invoices out; SPI PIS 1 out; Match below 75 out.

def test_pis_three_months():
    # Months of Supply = (Bin + On Order) / (Sales / 18); kept at exactly 3, dropped above; no sales dropped.

def test_pis_review():
    # InMaster PIS 4 (MAX over franchise D rows only), Match below 75, 3+ invoices: listed with Most Common Qty and
    # PIS Multiple % (invoices of 4, 8 count; 3 doesn't). Match at 75 not listed. Super To set is STILL listed.

def test_pis_twins_once():
    # 'X' and 'X ' at a branch: one row, the longer description's.
```

- [ ] **Step 2: Run them** (`python -m pytest test_corp_parts_check.py -q`) → FAIL.

- [ ] **Step 3: Implement.** Add `BinQty` to the `parts` table and a Prod Bronze-free `inmaster` table (from
`Silver_InMaster.PiecesInSet` when it has the column; `--inmaster-bronze` isn't needed once R2 is in Dev). Add:
- `build_pis_stats(con, now)`: table `pis_stats` (b, p, PisQty, PisQtyInvoices, PisInvoices, PisSalesQty,
  PisMultipleInvoices), following the query's `InvoiceQty`, `QtyCounts`, `PartTotals`, `Ranked`: window
  `add_months_dt(now, -18)` .. `now` for both types; `intrans` must be loaded from that start, so load it from the
  earlier of the two window starts.
- `pis_rows(con)`, `pis3_rows(con)`, `pis_review_rows(con)` returning the workbook's columns; the record per Branch +
  upper(trim(part)) is franchise D's (R-D6), longest description then smallest, then smallest part number (R-D7).
- `REPORTS["pis"]`, `["pis3"]`, `["pisreview"]`: sheet names `Data`, `SPI - Pieces In Set ` (trailing space, as in the
  workbook), `SPI -Pieces In Set Review`; columns as the spec, key Branch + upper part, `Description` compared nocase.
  Numbers tolerate 0.05 (Match % is rounded to 1 dp; Excel's Months of Supply isn't).
- `--check-pis-gold`: compares Gold's seven columns with `pis_stats` over every active record (keys on both sides), and
  fails naming rows. It also checks no idle record has an 18-month invoice (R-D7's "check in the plan"). Run by default
  when Gold has the columns, as the Corp demand compare is.

- [ ] **Step 4: Run** the tests, then against Prod with the morning's data:
`python corp_parts_check.py --tier prod --groups-tier prod --report pis --as-of '2026-11-05 15:15:00' --compare-xlsx <copy> --diff-out <csv>`
Expected (Gold has no columns yet, so that compare is skipped): about 3,317 rows, about 3 only on each side.

- [ ] **Step 5: Commit** `Plan R task R1: corp_parts_check --report pis, pis3, pisreview`.

---

### Task R2: Silver and Gold (fabric-workspace-docs)

**Files:**
- `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InMaster.Notebook/notebook-content.py`
- `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py`
- `deploy/dp_refresh_dag.json` only if `dag_check` says so; `docs/TABLE-LINEAGE.md` is generated.

- [ ] **Step 1: Silver.** In the `bronze.select(...)`, after `LastDemandDate`:

```python
    F.col("Pieces_In_Set").alias("PiecesInSet"),
```

Update its header comment ("Replicates the old 19-column contract ... additions: IN_TRANSIT_QTY, Pieces_In_Set (Pieces In
Set Review, Plan R)").

- [ ] **Step 2: Gold, the invoices.** In Part 5, after `corp_demands`:

```python
# Plan R: the SPI Pieces In Set stats (SPI - Pieces In Set.pq, InvoiceQty to Ranked): one row per invoice, net of its
# credits, over the 18 months through now (unlike Corp demands, invoices aren't held back 7 days), at every branch.
# The reports' conditions leave out 2 and 4.
_pis_t = F.upper(ztrim(c("Type")))
pis_invoices = (spark.sql("""SELECT Branch, Franchise, PartNumber, Type, Qty, TransDatetime, RONumber, OriginalInvoiceNo
                             FROM Silver_InTrans""")
                .where((F.upper(ztrim(c("Franchise"))) == "D")
                       & (c("TransDatetime") >= ts_lit(win_start)) & (c("TransDatetime") <= ts_lit(demand_as_of))
                       & (((_pis_t == "I") & (c("Qty") > 0)) | ((_pis_t == "C") & (c("Qty") < 0))))
                .select(F.upper(ztrim(c("Branch"))).alias("_pb"), F.upper(ztrim(c("PartNumber"))).alias("_pp"),
                        F.when(_pis_t == "I", ztrim(c("RONumber"))).otherwise(ztrim(c("OriginalInvoiceNo"))).alias("_pi"),
                        c("Qty"), (_pis_t == "I").cast("int").alias("_pisInv"))
                .groupBy("_pb", "_pp", "_pi").agg(F.sum("Qty").alias("_q"), F.max("_pisInv").alias("_h"))
                .where((c("_q") > 0) & (c("_h") == 1))
                .select("_pb", "_pp", "_q")
                .persist(StorageLevel.MEMORY_AND_DISK))
```

- [ ] **Step 3: Gold, the stats.**

```python
# InMaster's Pieces In Set per Branch + part, franchise D only (InMaster repeats a part across franchises; the Review
# query takes MAX, not an arbitrary row).
in_master_pis = (spark.sql("SELECT Branch, Franchise, PartNumber, PiecesInSet FROM Silver_InMaster")
                 .where(F.upper(ztrim(c("Franchise"))) == "D")
                 .groupBy(F.upper(ztrim(c("Branch"))).alias("_mb"), F.upper(ztrim(c("PartNumber"))).alias("_mp"))
                 .agg(F.max("PiecesInSet").alias("_pieces")))

_pis_totals = pis_invoices.groupBy("_pb", "_pp").agg(F.count(F.lit(1)).cast("int").alias("_pis_inv"),
                                                     F.sum("_q").alias("_pis_sales"))
# The most common net quantity; ties go to the smaller, as the query's ROW_NUMBER does (the order is unique: a Branch +
# part has one row per distinct quantity).
_pis_modes = (pis_invoices.groupBy("_pb", "_pp", "_q").agg(F.count(F.lit(1)).cast("int").alias("_n"))
              .withColumn("_rn", F.row_number().over(Window.partitionBy("_pb", "_pp")
                                                     .orderBy(F.desc("_n"), F.asc("_q"))))
              .where(c("_rn") == 1).select("_pb", "_pp", c("_q").alias("_pis_qty"), c("_n").alias("_pis_qty_inv")))
_pis_mult = (pis_invoices.join(in_master_pis.where(c("_pieces") > 1),
                               (c("_pb") == c("_mb")) & (c("_pp") == c("_mp")))
             .groupBy("_pb", "_pp")
             .agg(F.sum(F.when(F.expr("pmod(_q, _pieces)") == 0, 1).otherwise(0)).cast("int").alias("_pis_mult")))
pis_stats = _pis_totals.join(_pis_modes, ["_pb", "_pp"]).join(_pis_mult, ["_pb", "_pp"], "left")

# R-D7: one record of a trailing-space twin pair carries the stats, the one the query's JdisDedup picks: longest
# description, then the smallest, then the smallest part number as stored (unique within franchise D's Branch + part).
_pis_pick = (jd_parts.select(c("Branch"), c("PartNumber"),
                             F.row_number().over(
                                 Window.partitionBy(F.upper(ztrim(c("Branch"))), F.upper(ztrim(c("PartNumber"))))
                                 .orderBy(F.desc(F.length(c("Description"))), F.asc(c("Description")),
                                          F.asc(c("PartNumber")))).alias("_pick")))
```

Check `F.length(NULL)` sorts last under `desc` as the query's `LEN` does, and that `Window` is imported. Add `BinQty` to
`jd_parts`'s SELECT.

- [ ] **Step 4: Gold, the columns.** In `jd_all`, join `pis_stats` and `in_master_pis` on the trimmed upper Branch + part
(each has one row per key, so neither can fan out) and `_pis_pick` on `Branch` + `PartNumber`, and select:

```python
                  "BinQty",
                  c("_pieces").alias("PiecesInSet"),
                  *[F.when(c("_pick") == 1, F.coalesce(c(src), F.lit(0))).otherwise(F.lit(0)).alias(name)
                    for src, name in [("_pis_inv", "PisInvoices"), ("_pis_sales", "PisSalesQty"),
                                      ("_pis_qty", "PisQty"), ("_pis_qty_inv", "PisQtyInvoices"),
                                      ("_pis_mult", "PisMultipleInvoices")]],
```

Add the seven to `CORP_COLS` (active table). `Fact_CorpParts_JD_Idle` keeps its own column list; assert before writing:
`jd_all.where(~c("_active") & (c("PisInvoices") > 0)).count() == 0`, raising with examples (an invoice in 18 months means
sales in 24 months, unless Equip's sales counters disagree: stop and look rather than lose a row). Also assert the row
count is unchanged by the joins, as the stocking join does.

- [ ] **Step 5:** `python deploy/dag_check.py`, `python -m pytest deploy -q`, `python deploy/hygiene_audit.py` if it's
part of `dag_check`'s advice. Commit `Plan R task R2: Silver_InMaster.PiecesInSet; Fact_CorpParts_JD Pieces In Set columns`,
push `dev`.

- [ ] **Step 6: Dev.** `python tools/dp-migration/git_sync.py <staging dev id>`, then `<presentation dev id>` (ids in
`docs/architecture/data-platform-workspaces.md`). Run `Build_Silver_InMaster` then `Build_Gold_NonJD_Reorder` in Dev
(`tools/dp-migration/run_item.py`). Run Gold twice and `deploy/compare_tiers.py` as the notebook rules ask: the same rows.

- [ ] **Step 7: Verify:** `python corp_parts_check.py --tier dev --groups-tier prod --report pis`: PASS on the Gold
compare, the Pieces In Set compare and the idle check. Also `SELECT count(*) FROM Silver_InMaster WHERE PiecesInSet IS
NULL` (report it; NULL only if Bronze has NULLs).

---

### Task R3: Publish contract v8 (data-projects)

**Files:** `projects/part order tool - app/publish/extract.py`, `build_files.py`, `publish_logic.py`, `test_build_files.py`,
`README.md`.

- [ ] **Step 1: Failing test:** a JD row carries the seven fields; `binQty` etc. numeric; `_meta.contractVersion == 8`;
missing Gold columns fail naming them ("deploy Plan R ... before publishing v8").

- [ ] **Step 2: Implement.** `CONTRACT_VERSION = 8` with its comment line; `JD_COLUMNS` gains
`("BinQty", "binQty"), ("PiecesInSet", "piecesInSet"), ("PisInvoices", "pisInvoices"), ("PisSalesQty", "pisSalesQty"),
("PisQty", "pisQty"), ("PisQtyInvoices", "pisQtyInvoices"), ("PisMultipleInvoices", "pisMultipleInvoices")`; `build_files`:
`binQty`, `pisSalesQty`, `pisQty` to 2 dp, `piecesInSet` nullable, the invoice counts whole numbers, `require_columns`
naming Plan R. Update the existing `contractVersion == 7` assertions to 8. README "File contract" and the deploy note:
Gold first, then app 0.16.0, then this code on the Gateway PC.

- [ ] **Step 3: Measure** size: run the extract against Dev to a temp folder with `build_files` (no upload) and report
the total `jd_*.json.gz` bytes against today's Prod `jd_*` total. Report the number; don't change the shape unless it
grows more than about 30%, in which case stop and ask.

- [ ] **Step 4: Commit** `Plan R task R3: publish contract v8 (Pieces In Set fields on the JD files)`. **Don't pull it on
the Gateway PC:** that's R7.

---

### Task R4: App fields (nonjd-order-app)

**Files:** `src/data/contract.ts`, `src/data/types.ts`, `src/data/mock/jdFixtures.ts`, `src/inventory/fields.ts`, new
`src/inventory/pisFields.ts`; tests `src/inventory/__tests__/pisFields.test.ts`, `fields.test.ts`, `src/data/__tests__/contract*`.

- [ ] **Step 1: Failing tests** in `pisFields.test.ts`:

```ts
const rec = (o: Partial<JdRow>): JdRow => ({ ...BASE, binQty: 0, onOrder: 0, cost: 2, pisQty: 2, pisInvoices: 4,
  pisQtyInvoices: 3, pisSalesQty: 7, pisMultipleInvoices: 0, piecesInSet: 1, ...o });

it('Match %: one decimal', () => expect(matchPct(rec({ pisInvoices: 9, pisQtyInvoices: 7 }))).toBe(77.8));

it.each([
  [0, 0, 2, 2, 2],   // stock 0 orders one full set (Brian, 2026-08-27)
  [3, 0, 2, 4, 1],   // up to the next multiple
  [4, 0, 2, 4, 0],   // already on a multiple: nothing
  [1, 2, 2, 4, 1],   // on order counts
  [1.5, 0, 2, 2, 0.5], // fractional stock
  [-2, 0, 2, -2, 0], // negative stock: the query's CEILING, never negative
])('Round up: bin %d on order %d set %d', (binQty, onOrder, pisQty, up, qty) => {
  const r = rec({ binQty, onOrder, pisQty });
  expect(roundUp(r)).toBe(up);
  expect(recommendedQty(r)).toBe(qty);
});

it('Recommended cost to the cent', () => expect(recommendedCost(rec({ binQty: 3, cost: 1.975 }))).toBe(1.98));

it('Months of supply: stock / (sales / 18); blank with no sales', () => {
  expect(monthsOfSupply(rec({ binQty: 2, pisSalesQty: 16 }))).toBe(2.25);
  expect(monthsOfSupply(rec({ pisSalesQty: 0 }))).toBeNull();
});

it.each([
  [3, 100, '4 - Thin'], [10, 90, '1 - Act Now'], [9, 95, '2 - Likely'], [5, 80, '2 - Likely'],
  [4, 95, '3 - Review'], [10, 79.9, '3 - Review'],
])('Tier: %d invoices at %d%%', (pisInvoices, match, tier) => { /* set pisQtyInvoices so matchPct = match */ });

it.each([[12, 'Set'], [13, 'Large Multiple'], [49, 'Large Multiple'], [50, 'Box / Bulk Qty']])(
  'PIS class of %d', (pisQty, cls) => expect(pisClass(rec({ pisQty }))).toBe(cls));

it.each([
  [{ binQty: 0 }, 'Out of Stock'], [{ binQty: 1, pisSalesQty: 0 }, 'No Sales'],
  [{ binQty: 1, pisSalesQty: 36 }, 'Thin'],       // 0.5 months
  [{ binQty: 6, pisSalesQty: 18 }, 'Healthy'],    // exactly 6
  [{ binQty: 7, pisSalesQty: 18 }, 'Overstocked'],
])('Coverage flag', (o, flag) => expect(coverageFlag(rec(o))).toBe(flag));

it('every calculated field is blank on a record with no invoices', () => {
  const r = rec({ pisInvoices: 0, pisQtyInvoices: 0, pisQty: 0 });
  for (const f of [matchPct, pisMultiplePct, roundUp, recommendedQty, recommendedCost, monthsOfSupply, tier, pisClass,
    coverageFlag]) expect(f(r)).toBeNull();
});
```

`fields.test.ts`: the new ids in catalogue order; each new field `undefined` (not known) on a v7 publish, and known on v8.
Contract test: 8 supported, `hasPiecesInSet(meta)` true from 8.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement.** `contract.ts`: `SUPPORTED_CONTRACT_VERSIONS` gains 8, `CONTRACT_VERSION = 8`,
`hasPiecesInSet`. `types.ts`: `JdPart` gains the seven, optional (`?`: undefined on a v6/v7 file), documented.
`pisFields.ts`: pure functions above, named as the tests do. `fields.ts`: `JdFieldId` and `JD_FIELDS` gain, after
`sales24`, `binQty` (Bin qty), `piecesInSet` (InMaster PIS, blankable), `pisQty` (SPI PIS), `matchPct` (Match %, number),
`pisMultiplePct` (PIS multiple %), `pisInvoices` (Invoices), `pisDemands` (Demands), `pisSalesQty` (Sales qty),
`stockPosition`, `roundUp`, `recommendedQty`, `recommendedCost` (money), `monthsOfSupply`, `pisTier` (Tier, text),
`pisClass` (PIS class, text), `coverageFlag` (Coverage flag, text), all blankable and read through `pisFields.ts`; zero
`pisInvoices` reads `pisQty` and `pisInvoices` as 0 so conditions fail cleanly. Unknown before v8: follow how
`src/cleanup/fields.ts` `inData` does it, adding `fieldInData` to `JD_CATALOGUE` if it has none (check `makeCatalogue`).
These are `rowField`s only if always known; a v7 row isn't, so use `field`. `JdPartPanel` lists every JD field: confirm the
panel reads well with the extra ones (hide `pisDemands`, it's a duplicate). `Months of supply` shows 2 decimals; check how
number fields format and add `decimals` only if needed.

`jdFixtures.ts`: set the fields on existing rows only where a test needs it; add the R5 rows.

- [ ] **Step 4: Run** `npx vitest run src/inventory src/data src/pages/__tests__ src/__tests__`, tsc, lint → PASS. Update
field-count tests; existing built-ins' results and CSVs must not change.

- [ ] **Step 5: Commit** `Plan R task R4: contract v8 and the Pieces In Set fields`.

---

### Task R5: The three built-ins

**Files:** `src/inventory/builtIns.ts`, `src/data/mock/jdFixtures.ts`; tests `src/inventory/__tests__/builtIns.test.ts`,
page tests naming the built-ins.

- [ ] **Step 1: Failing tests:** `BUILT_INS` ids end `..., 'superseded-stock', 'pieces-in-set', 'pieces-in-set-3-months',
'pieces-in-set-review'`. Mock rows (at branch 7 unless noted, Corp demands 0 and with stock or a Super To so no other
built-in finds them; `JD-SS-` ones unaffected) found exactly:

| Row | Result |
|---|---|
| `JD-PIS-OK`: set 2, 9 invoices, 7 at 2, sales 16, bin 2 | main (Match 77.8, Tier 3, 2.25 months) and 3 months |
| `JD-PIS-OVER`: set 2, 8/8 invoices, sales 16, bin 7 | main only (Round up 8, Recommended 1, Overstocked) |
| `JD-PIS-ZERO`: set 4, 4/4, bin 0 | main and 3 months (Round up 4, Out of Stock, Tier 3) |
| `JD-PIS-BOX`: set 1000, 4/4 | main (Box / Bulk Qty), labelled, not removed |
| `JD-PIS-THIN`: set 2, 3/3 | main (Tier 4 - Thin) |
| `JD-PIS-SUPER`: set 2, 4/4, Super To `R1` | not listed (but in Review's logic if PIS > 1, below) |
| `JD-PIS-ONE`: set 1, 4/4 | not listed |
| `JD-PIS-LOW`: set 2, 2/4 | not listed |
| `JD-PIS-2INV`: set 2, 2/2 | not listed |
| branch 2 `JD-PIS-B2`: set 2, 4/4 | not listed |
| `JD-PIS-REV`: InMaster PIS 4, most common 1, 2/4 (Match 50), 1 multiple (25%) | Review only |
| `JD-PIS-REVOK`: InMaster PIS 4, set 4, 4/4 | main; not Review |
| `JD-PIS-REV2`: InMaster PIS 4, Match 50, 2 invoices | not listed |

Plus the CSV headers: main `Branch,Part #,Description,Source,SLC,Commodity Code,Dealer Group Code,SPI PIS,Match %,Invoices,Demands,Sales Qty,Bin Qty,On Order Qty,Cost,Round Up,Recommended Qty,Recommended Cost,Tier,PIS Class,Stock Position,Months of Supply,Coverage Flag`;
Review `Branch,Part #,Description,Source,SLC,Commodity Code,Dealer Group Code,InMaster PIS,Most Common Qty,Match %,PIS Multiple %,Invoices,Demands,Sales Qty`.
On a v7 publish, each shows its "not in today's data" message.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** in `builtIns.ts` after `SUPERSEDED_STOCK_BUILT_IN`, using `list` and `num` (widen `num`'s op
union with `'gt'`, `'le'`; check the Match % `lt` exists on numbers):

```ts
/** Every Pieces In Set list (the workbook's SQL): not 2 or 4, 3 or more invoices. */
const PIS_BASE = [NOT_2_OR_4, num('pisInvoices', 'ge', 3)];
/** The main list's WHERE: a most common quantity above 1 at 75% of invoices, not superseded. */
const PIS_MAIN: readonly ConditionItem<JdFieldId>[] = [
  ...PIS_BASE, num('pisQty', 'gt', 1), num('matchPct', 'ge', 75),
  { field: 'superTo', op: 'blank', value: { kind: 'none' } },
];
```

The three `BranchBuiltIn`s with ids above, descriptions in a parts manager's words, `includeIdle: false`, `pool: null`,
columns and `csvHeaders` as in the test; `fileStem` = the name with `:` removed. Update header comments and the
"built-in names" lists in tests (`inventoryReportsPage`, `inventoryEditorPage`, click-throughs). Any copy CSV header:
extend `reportCsvHeader` so a copy's new columns get the workbook's names through a `PIS_CSV_HEADERS` map, as
`POOL_CSV_HEADERS` does (`pisQty` → `SPI PIS`).

- [ ] **Step 4: Run** the same suite plus tsc and lint → PASS.

- [ ] **Step 5: Commit** `Plan R task R5: Pieces In Set, 3 Months or Less, Review built-ins`.

---

### Task R6: 0.16.0, click-through, try-it notes

- [ ] **Step 1:** `package.json` and lock `0.16.0`; `src/__tests__/clickThrough0160.test.tsx` (setup as 0150; move the
version test to it, from 0151): Inventory lists eight built-ins and counts each at once; open Pieces In Set: the rows
above, JD-PIS-BOX labelled Box / Bulk Qty, CSV header; 3 Months or Less leaves out JD-PIS-OVER; Review shows JD-PIS-REV
with PIS Multiple %; Copy as my own, add Tier is 1 - Act Now, Try it, Save.

- [ ] **Step 2:** the full suite in two halves, tsc, lint.

- [ ] **Step 3:** `for-users/0.16.0-try-it.md` (0.15.0's style; say exactly where to click, and that these are three new
separate reports). Include how to make the Buy List as a copy (Tier is one of 1 - Act Now, 2 - Likely; PIS class isn't Box
/ Bulk Qty; Recommended qty > 0).

- [ ] **Step 4:** commit both repos.

---

### Task R7: Release (with Brian)

- [ ] **1. PR** `dev → main` in fabric-workspace-docs (`python deploy/merge_preview.py`; template). Brian merges with a merge
commit and runs "Deploy DP backend", then `python deploy/claim_prod_pipeline.py`. Fast-forward dev.
- [ ] **2. Prod data:** Brian runs Pipeline_DP_Refresh with `{"executionData":{"parameters":{"mode":"items","items":"Build_Silver_InMaster,Build_Gold_NonJD_Reorder","reason":"Plan R"}}}`
(item names as `dp_refresh_dag.json` has them). `corp_parts_check.py --tier prod --report pis`: Gold PASS.
- [ ] **3. App:** `npm run build`, dist checks, upload to Fedora staging; Brian installs 0.16.0. Reports show "not in today's
data" until step 4; every other report works as before.
- [ ] **4. Publish:** Brian pulls the v8 code on the Gateway PC and runs `run_publish.py --force`. Check `_meta.json`
`contractVersion: 8`.
- [ ] **5. Excel check:** Brian refreshes in the evening, **Refresh All twice**; after the next morning's Prod refresh, all three
reports through `--compare-xlsx`; explain every difference by part. List R-D6's rows.
- [ ] **6. Real test:** Brian exports the three CSVs; compare with the reference. A TEST copy saved and deleted.
- [ ] **7. Docs:** guide + walkthrough (regenerate both .docx), INVENTORY-REPORTS, `corp parts excel reports/CLAUDE.md` note,
FUTURE-IDEAS (F4's last workbook done; F12 next), plan and spec status, memory.
