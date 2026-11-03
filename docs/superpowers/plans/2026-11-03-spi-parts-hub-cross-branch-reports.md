# SPI Parts Hub: cross-branch Inventory reports, Border Stores and 2 & 4 Cotton (Plan M, app 0.13.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a
> review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-11-03 (Claude, for Brian). Spec approved 2026-11-03.

**Goal:** built-in **Border Stores** and **2 & 4 Cotton** Inventory reports that match the workbooks row for row, with
copies that can change which branches are compared, left out or counted.

**Architecture:** Gold adds `Fact_CorpParts_JD_Idle` (the franchise D records the active table leaves out); the
publish adds `jd_idle_<branch>` files (contract v7); the app loads them on demand and extends the condition engine
with a second condition list ("Count other branches where") that yields per-row other-branch figures, one-level
"any of" groups, a "Dealer group at any branch" field and an "Include parts with no activity" switch.

**Tech stack:** Fabric notebook (PySpark) in fabric-workspace-docs; DuckDB reference check and the Python publish in
data-projects; nonjd-order-app (React 19, TypeScript, Vite, Tailwind 4, react-router 7, Vitest).

**Spec:** `docs/superpowers/specs/2026-11-03-spi-parts-hub-cross-branch-reports-design.md`. Builds on Plan L
(`2026-11-03-spi-parts-hub-inventory-reports.md`): read its Progress notes for what exists.

---

## What we know (2026-11-03)

- Prod Silver franchise D: 893,847 records; `Fact_CorpParts_JD` (active) 250,867; **idle 663,333 at 40 branches**,
  11 MB gzipped as per-branch JSON (largest branch 4: 978 KB, under the 4 MB upload limit).
- Probe (Prod Gold active rows vs Brian's refreshes, scratchpad `border/probe.py`): Border Stores 1,562 / 1,571
  matched (9 only in Excel, 17 only in ours, 80 with different other-branch figures); 2 & 4 Cotton 14 / 248, the other
  234 being idle records.
- Workbook copies (Brian's refreshes): scratchpad `border/Border Stores.xlsx` (14:34, 1,571 rows) and
  `border/2 & 4 Cotton & Stripper Parts.xlsx` (14:31, 248 rows). Columns: the 12 MLPF ones + OtherBranchDemands,
  OtherLocationCount.

## How we run this plan

As Plan L: one task at a time, a review after each, fixes, push; stage named files only; `.env*` never read or
committed; app tests in two halves, `npm run lint`, `npx tsc -b`; `npm run build` only in M10; Edit/Write tools for
source edits. Fabric: `dev`, `dag_check`, `hygiene_audit`, `pytest deploy -q`, git sync Dev, never `fab import`;
start Pipeline_DP_Refresh with **plain-string** parameters (not `run_item.py`). **Order:** app 0.13.0 on Fedora
before the Gateway publishes v7; Prod Gold with the idle table before the Gateway pulls the v7 publish code.

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| M-D5 | **Stored format:** the Conditions column holds either today's array (0.12.0) or an object `{"v":2,"conditions":[…],"pool":[…]|null,"includeIdle":bool}`. Arrays parse as `{conditions, pool: null, includeIdle: false}`. The app writes an array when pool is null and includeIdle false, so 0.12.0-shaped reports stay readable by a 0.12.0 app during the rollout. | Back-compatible both ways where possible. |
| M-D6 | **Group condition:** `{ "anyOf": Condition[] }` (2–10 plain conditions, no nesting, no pool fields inside a group). Text: "any of (A; B)". | One level, as the spec says. |
| M-D7 | **Pool fields** `otherDemands` ("Other-branch demands", number) and `otherBranches` ("Other branches with demand", number) exist only when the report has a pool; a condition on them in a report with no pool is a validation error ("Add 'Count other branches where' to use this field."). Not allowed inside the pool list itself. | Avoids circular definitions. |
| M-D8 | **Pool matching key:** trimmed, upper-cased part number; "other" = trimmed branch ≠ the row's trimmed branch. Twins at one branch both count. | Matches the workbook's GROUP BY over stored values (RTRIM-insensitive in SQL Anywhere). Verified in M2b. |
| M-D9 | **`dealerGroupAnyBranch`** ("Dealer group at any branch"; comparisons one of / not one of): over every JD record of the part (active and idle, any branch), trimmed, upper-cased. A report that uses it loads the idle files even with the switch off. | The cotton rule is part-level. |
| M-D10 | **Idle rows in the app:** `JdRow` with onHand 0, onOrder 0, sales12 0, salesPrev12 0, corpDemands 0, plus `idle: true`. Only reports with `includeIdle` see them as candidates or pool rows. | One row type for the engine. |
| M-D11 | **Built-in ids/routes:** `/inventory/border-stores`, `/inventory/cotton-2-4`; list order MLPF Gaps, Border Stores, 2 & 4 Cotton. CSV headers: the 12 MLPF names + `OtherBranchDemands`, `OtherLocationCount`. File names `Inventory-Border Stores-<date>.csv`, `Inventory-2 & 4 Cotton-<date>.csv`. | As MLPF Gaps. |
| M-D12 | **Contract v7:** `jd_idle_<branch>.json.gz` `{branch, dataAsOf, parts:[{partNumber, description, cost, packageQty, returnIndicator, source, slc, superTo, commodityCode, commodityGroup, dealerGroupCode, minimumQty, maximumQty}]}`; `_meta.jdIdleBranches`, `counts.jdIdleParts`. App accepts 3–7. | Spec section 2. |

## File map

| Repo | File | Change |
|---|---|---|
| fabric-workspace-docs | `…/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py`; `deploy/dp_refresh_dag.json`; `docs/TABLE-LINEAGE.md` | `Fact_CorpParts_JD_Idle` |
| data-projects | `tools/dp-migration/corp_parts_check.py` + test | idle table; Border Stores and 2 & 4 Cotton lists; xlsx compare with the other-branch columns |
| data-projects | `projects/part order tool - app/publish/` extract, build_files, publish_logic, run_publish, README, tests | v7 idle files |
| app | `src/data/contract.ts`, `types.ts`, `files.ts`, `source.ts`, mock; `src/state/jdIdleBranches.ts` | v7, `loadJdIdle`, `useJdIdleBranches` |
| app | `src/cleanup/conditions.ts` (+ catalogue) | any-of groups |
| app | `src/inventory/report.ts` (new), `fields.ts`, `builtIns.ts`, `reportResults.ts`; `src/data/lists.ts` | report model (conditions + pool + includeIdle), pool fields, dealer group at any branch, built-ins, stored format |
| app | `src/pages/inventory/*`, `src/pages/cleanup/ConditionRowEditor.tsx` | editor cards, switch, groups; results columns; routes |

---

## Tasks

### Task M1: Gold `Fact_CorpParts_JD_Idle` (fabric-workspace-docs, Dev)

- [ ] **Step 1:** in Part 5, after the active table's build, the idle rows = `jd_parts` (franchise D, Silver grain,
  with min/max and commodity group joined as for the active table) **minus** the L-D14 active filter
  (`NOT active`), columns per spec section 2, `BuiltAtUtc` as the active table. Guards (raise with offenders): idle
  key unique; no key in both tables (`join … "inner"` count = 0); `active rows + idle rows = jd_rows` (the Silver
  franchise D count). Literal `.save("Tables/Fact_CorpParts_JD_Idle")`, overwrite + overwriteSchema, VACUUM, a log
  line with the row count. Header GRAIN / PLAN M note.
- [ ] **Step 2:** `dp_refresh_dag.json` produces `Fact_CorpParts_JD_Idle`; dag_check, hygiene_audit, pytest,
  table_lineage. Commit, push, wait_ci, git sync DP - Presentation - Dev (Accept incoming only for the known
  DP_Presentation lakehouse conflict), Dev run items=Build_Gold_NonJD_Reorder twice; idle row counts equal; DuckDB
  check: active + idle = Silver franchise D, disjoint; Fact_NonJD_* fingerprints unchanged.

### Task M2: Reference check (data-projects)

- [ ] **Step 1 (tests first):** in `test_corp_parts_check.py`: idle = Silver D minus active, disjoint, columns;
  Border Stores and 2 & 4 Cotton lists from fixture tables: a candidate whose other-branch rows include one at branch
  2 (not counted), one failing a part filter (not counted), its own branch (not counted), twins at one branch (both
  counted); the thresholds 10 / 5 at their edges; 2 & 4 Cotton with an idle candidate, the cotton rule via own dealer
  group and via a 770 code at another branch (and a part coded COMBINE here with no model code: out); compare-xlsx
  with the two extra columns.
- [ ] **Step 2:** `corp_parts_check.py`: build and compare the idle table (Gold vs expected from Silver);
  `--report mlpf|border|cotton` for `--mlpf-out`-style output (`--report-out <csv>`) and `--compare-xlsx` (the
  workbook's columns, incl. OtherBranchDemands / OtherLocationCount, numeric compare). The Border / Cotton lists are
  computed in SQL from the expected tables (active + idle), independent of the app, per the spec's "What the
  workbooks do". `--tier dev` → PASS. Commit, push.

### Task M2b: Excel comparison against Prod (Claude)

- [ ] Prod Gold has no idle table until release: run `--tier prod --report border|cotton --as-of` with the idle rows
  computed from Prod Silver (the check's expected table), against the two workbook copies. Classify every difference
  (timing / twins / the workbook's franchise-less join / Silver drift / rule bug) as in L3b. Anything that's a rule
  difference is fixed in the spec, M2 and later app tasks before they're built. Notes in Progress.

### Task M3: Publish contract v7 (data-projects)

- [ ] Tests first, then: `extract.JD_IDLE_COLUMNS`, `jd_idle_parts(con)` (missing table → error naming
  `Fact_CorpParts_JD_Idle`); `build_files.build_jd_idle(rows, names, data_as_of)` (same rules as `build_jd`: all
  branches, twins kept, 4 MB check; zero-by-definition fields omitted); `_meta.jdIdleBranches`,
  `counts.jdIdleParts`; `CONTRACT_VERSION = 7`; BuiltAtUtc checks as for the active table; README contract history
  ("7 = Plan M: jd_idle_<branch>.json.gz; deploy app 0.13.0 first") and the file section. Local `--out` build on Dev:
  sizes, counts. Don't publish until M11.

### Task M4: App data: v7 and the idle files

- [ ] `contract.ts` [3–7], `hasJdIdle(meta)`; `types.ts` `JdIdlePart`, `JdIdleFile`, `Meta.jdIdleBranches?`,
  `counts.jdIdleParts?`; `files.loadJdIdle`; `DataSource.loadJdIdle`; mock v7 (idle files for branches 1, 2, 4, 12
  with fixtures from M7), `asV6`; `src/state/jdIdleBranches.ts` `useJdIdleBranches(enabled: boolean)` on the
  `publishCache` rules (6 at a time; `notInData` on v6; nothing loaded when `enabled` is false), returning
  `JdRow[]` per branch with the M-D10 zeros and `idle: true` (`JdRow` gains `idle?: true`). Tests as L5's.

### Task M5: Any-of groups (engine, both catalogues)

- [ ] `Condition<F>` becomes `PlainCondition<F> | { anyOf: PlainCondition<F>[] }` in conditions.ts with parse /
  validate ("A group needs 2 to 10 lines."; no nesting) / match (some) / text ("any of (A; B)"); `checkColumns` /
  `copyColumns` include the fields used inside groups; the editor row model supports a group (add group, add line to
  group, remove). Cleanup gets groups too (harmless; same engine). Existing stored checks and 0.12.0 reports parse and
  behave unchanged (their tests untouched). Tests.

### Task M6: Report model, pool fields, dealer group at any branch (pure)

- [ ] `src/inventory/report.ts`: `InventoryReportDef = { conditions, pool: Condition[] | null, includeIdle: boolean }`,
  `parseReportDef(json)` / `reportDefToJson(def)` per M-D5; `compileReport(def, rowsByBranch, idleRowsByBranch)`
  that builds the part index once (trimmed upper part number → rows passing `pool`, with branch and corpDemands; and
  → all dealer group codes over active + idle rows) and returns a matcher plus `poolFigures(row)` →
  `{ otherDemands, otherBranches }` (M-D8). JD catalogue gains `otherDemands`, `otherBranches` (number; valid only
  with a pool, never inside the pool; M-D7) and `dealerGroupAnyBranch` (text, one of / not one of; M-D9), whose
  `read` uses the compiled index (pass context to `read`, or resolve these three fields in the matcher; pick the
  cleaner, document it). Validation messages per M-D7. `copyColumns` adds the pool fields when the report has a pool.
  L8's list mapping uses `parseReportDef` / `reportDefToJson` (unreadable rows as before). Tests: pool own-branch
  exclusion, failing pool rows excluded, twins, idle rows only with includeIdle, dealer group any branch across idle
  rows, M-D5 round trips (array in → array out when no pool/idle), M-D7 errors.

### Task M7: Built-ins Border Stores and 2 & 4 Cotton

- [ ] `builtIns.ts`: `BORDER_STORES` and `COTTON_2_4` defs exactly per the spec table, `BUILT_INS` list (MLPF Gaps,
  Border Stores, 2 & 4 Cotton) with id, name, description, def, columns (MLPF_COLUMNS + otherDemands,
  otherBranches), CSV headers (M-D11). Mock JD fixtures (`jdFixtures.ts`): for each built-in one passing candidate and
  one-fail-each candidates (incl. a pool that totals 9 / 4 branches, a pool row at branch 2 that must not count, an
  idle cotton candidate at branch 4 with a 770-coded record at another branch, and a COMBINE-coded part with no model
  code). Tests: exactly the passing parts match; each fixture fails only its own condition; pool figures equal the
  hand-computed values.

### Task M8: Pages

- [ ] List: the three built-ins; counts (a built-in needing idle rows shows "…" until they load, and "Parts with no
  activity aren't in today's data yet" on v6). Results: routes per M-D11, the extra columns, the details panel shows
  the pool figures; idle files loaded only when the report needs them (`includeIdle` or `dealerGroupAnyBranch`), with
  progress. Editor: "Count other branches where" card (collapsed until a pool field is used or the user opens it;
  same row editor with `JD_CATALOGUE` minus the pool fields), "Include parts with no activity" switch (with a line
  saying it loads more data), group rows, Try it over active (+ idle when needed). Copy as my own copies pool and
  switch. Tests for each, including that MLPF Gaps never requests idle files.

### Task M9: Click-through and try-it notes

- [ ] `clickThrough0130.test.tsx`: Inventory → Border Stores (its mock count, CSV headers incl. OtherBranchDemands)
  → 2 & 4 Cotton (idle candidate shown) → Copy Border Stores → change branches to 7, 14 and Other-branch demands to
  ≥ 8 → Try it → Save → listed. `for-users/0.13.0-try-it.md` (three short jobs with "Look for").

### Task M10: Review and 0.13.0 build

- [ ] typescript-reviewer over M4–M9; fixes; suites, lint, tsc; 0.13.0 in package.json / lock / README; `npm run
  build`; dist checks (list IDs, site, no mock strings, version + commit).

### Task M11: Release (Brian's steps, one at a time)

1. fabric-workspace-docs PR dev → main; Brian merges, runs Deploy DP backend, then the claim (no new shortcuts).
2. Brian deploys app 0.13.0 to Fedora (reads v6 and v7).
3. Brian runs Prod `mode=items items=Build_Gold_NonJD_Reorder`; Claude runs `corp_parts_check --tier prod` (all
   three reports) and `nonjd_reorder_check --tier prod` → PASS.
4. Brian pulls `C:\data-projects` on the Gateway PC and publishes; Claude checks `jdIdleParts` in the output.
5. Brian refreshes both workbooks; `--compare-xlsx` for each against Prod Gold → every difference explained.
6. Real test on Fedora: both built-ins' counts ≈ the workbooks'; Brian saves a TEST copy of Border Stores with
   changed branches; Claude checks the stored JSON (object form, M-D5) and deletes it.

### Task M12: Documents and progress

- [ ] Guide section "Border Stores and 2 & 4 Cotton (0.13.0)", walkthrough 0.13.0, regenerate both .docx,
  `INVENTORY-REPORTS.md` (the two reports, other branches, any-of groups, the no-activity switch, the Excel
  comparison), FUTURE-IDEAS, a note for the Corp Parts CLAUDE.md (Brian commits it), plan and spec Progress, memory.

---

## Self-review against the spec

- M-D1 engine with other branches: M5 (groups), M6 (pool fields, report model), M8 (editor). M-D2 queries' code:
  M7 built-ins per the spec table; M2 reference from the workbook SQL; M2b / M11 Excel gates. M-D3 idle records: M1,
  M3, M4, M8 (on demand). M-D4 Corporate Stocking: out of scope.
- Dealer group at any branch over active + idle: M6 (M-D9), loaded in M8. Stored format back-compatible: M-D5, M6.
- Testing: run twice (M1), reference (M2), Excel (M2b, M11), publish pytest (M3), Vitest + click-through (M4–M9),
  reviews (each task, M10). Release pattern: M11. Docs: M12.
