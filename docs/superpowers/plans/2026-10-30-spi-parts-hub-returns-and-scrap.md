# SPI Parts Hub round 3 phase 1: returns and scrap (Plan I, app 0.9.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a
> review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-10-30 (Claude, for Brian).
> - **I0a–I0c done 2026-10-30** (Brian created, Claude verified through Graph; 0 items each). `NonJD_ReturnRules`
>   **`4b8e36cc-4d85-4af2-b465-b9a64b45da6a`**, `NonJD_Returns` **`b3284d52-4ccf-43cf-81b8-2035cd08cd6e`** (Franchise and
>   Status indexed; Parameters plain text), `NonJD_ReturnLines` **`1a210f70-7a1e-42f0-a758-c24c3dc0ccda`** (ReturnId
>   indexed). All columns as planned. Differences: Status has no default (the app always writes it); ReturnLines has an
>   extra `Number` column (2 dp) the app ignores (Brian may delete it). Left: I0c step 3 (`.env.local`, Brian).
> - **Starting point:** app 0.8.1 (`1b38c40`) live on Fedora on Prod data (contract v3). fabric-workspace-docs `dev`
>   = `main`. Spec approved: `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md` (R1–R16, D1–D3).

**Goal:** a "Returns & scrap" area where users keep franchise return and scrap rules, work a company-wide return
(pre-picked up to the allowance, with credit) or scrap list (with Transfer instead where another branch has demand),
and track the saved documents to Credit received / Scrapped.

**Architecture:** mostly app-only. Three new SharePoint lists hold the rules and the saved documents (the app reads and
writes them live through Graph, as transfer rules and transfers; no dataflow, no Gold read). One Fabric change: Gold
adds `LastReceived` to `Fact_NonJD_Reorder` and a new `Fact_NonJD_Purchases` (12-month purchases at cost per branch
and franchise), both from InTrans purchase rows, checked by the reference script and published in contract v4. The
selection logic is pure engine code (`src/engine/returns.ts`) over data the app already loads for transfers (every
branch's reorder and history files), plus the new purchases file.

**Tech stack:** React 19 + TypeScript + Vite + Tailwind 4, react-router 7, Vitest + Testing Library, Microsoft Graph;
Fabric PySpark notebook; Python + DuckDB for the reference check and the publish.

**Spec:** `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md`, "Phase 1".

---

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| I1 | **Purchases are gross Type `P` CostValue** (InTrans rows with `Type = 'P'`). On Prod since Sep 2025 every P row has Qty > 0 (42,375 rows, $17.8M); no supplier-return type shows in InTrans, so nothing is netted. **Brian checks what Type `R` is** (8,430 rows, mostly positive, $1.26M; likely repair-order issues, not supplier returns). If it is a supplier return, I3 nets it. | The data: P never goes negative. |
| I2 | **The purchases window is the 12 full months before the build's Central month** (the same months as `sales12`), by `TransDatetime`'s date as stored (UTC session, like `DateLastRequested`). | Same window people already see as "12-mo sales". |
| I3 | **`LastReceived`** = the date of the newest Type `P` row for the branch + franchise + part (trimmed part number, as the Gold join), null when never received. Added to `Fact_NonJD_Reorder` (and so the reorder parity) rather than a separate table. | One field per part the app already loads. |
| I4 | **`Fact_NonJD_Purchases`**: Branch, Franchise, Purchases12 (sum of CostValue, 2 dp), BuiltAtUtc; one row per branch + franchise with purchases in the window; excluded branches left out (as every Non-JD output). Published as `purchases.json.gz` `{dataAsOf, rows: [{branch, franchise, purchases12}]}`. | The allowance base `Purchases12` (R15). |
| I5 | **Contract v4.** The app accepts v3 and v4 (v3 = no purchases file, `lastReceived` absent → treated as unknown: "not received for" can't be applied and the rule editor says so); the publish writes v4 only after the 0.9.0 app is on Fedora. | Deploy the app before the publish (memory gotcha). |
| I6 | **The lists:** `NonJD_ReturnRules`, `NonJD_Returns`, `NonJD_ReturnLines` (columns in I0a–I0c). Build-time IDs `VITE_LIST_RETURN_RULES`, `VITE_LIST_RETURNS`, `VITE_LIST_RETURN_LINES`, added to `REQUIRED_LIST_KEYS`. | As the transfer lists (round 2). |
| I7 | **Qualifying `no sales`:** units sold = 0 in history `sales` indexes 0..N (the current partial month and the N full months before it). | Spec ("a sale this month disqualifies"). |
| I8 | **Last sold** = the label of the newest index with sales > 0 in the 60 months, else "Over 5 years". Sort key: never sold first (as index 60). | Spec. |
| I9 | **Demand elsewhere** = for each other ticked-or-not branch (every included branch, not just the ticked ones), the sum of `requests` indexes 1..W (W = window months, default 18; full months only), > 0 listed busiest first, ties in branch order (`compareBranchOrder`). | Ben's question is "anywhere else"; full months match the workbook's whole-month view. |
| I10 | **Transfer instead's branches** are the branches with demand whose part row has `allowReceive = true` (a branch without the part file row is skipped: no row means no transfer rule result). | Spec (R9 + AllowReceive). |
| I11 | **Holds** = Qty on lines of `NonJD_Returns` documents in status Draft or Exported, keyed by branch + franchise + part (`committedKey`). Read with the open transfers on app load and on each wizard's Save re-check. | Spec R10. |
| I12 | **Titles:** `<franchise>-RET-<yyyymmdd>-<hhmm>` / `<franchise>-SCR-…` in Central time (as `transferTitle`). | Spec. |
| I13 | **Transfer instead saves through the existing transfer saver** with `source: 'Return' | 'Scrap'` and `orderName` = the document title; Kind `Conventional`. `TransferParameters.source` gains the two values; `parametersSummary` says `From Return "<title>"` / `From Scrap "<title>"`. | Reuses the stock re-check and the one-order-per-pair rule. |
| I14 | **Save order:** transfer orders first, then the document and its lines. If the transfers save but the document fails, the page shows the saved transfers and a Retry for the document only (the "unfinished save" pattern of the transfer hook). | A half-save never loses transfers the user saw saved. |
| I15 | **Version 0.9.0**; documents batched (walkthrough "Version 0.9.0", guide section, a short RETURNS-AND-SCRAP.md for Ben). | Ben: batched releases. |

---

## File map

**fabric-workspace-docs**
| File | Change |
|---|---|
| `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py` | Read `Tables/Silver_InTrans`; LastReceived on the reorder rows; write `Tables/Fact_NonJD_Purchases` (+ VACUUM) |
| `deploy/dp_refresh_dag.json` | `Build_Gold_NonJD_Reorder`: dependsOn += `Build_Silver_InTrans`; produces += `Fact_NonJD_Purchases` |
| `docs/TABLE-LINEAGE.md` | Regenerated |

**data-projects**
| File | Change |
|---|---|
| `tools/dp-migration/nonjd_reorder_check.py` | Expected LastReceived (compared with the reorder columns) and expected purchases (compared row by row) |
| `projects/part order tool - app/publish/extract.py`, `build_files.py`, `publish_logic.py`, `README.md`, tests | `lastReceived` field, `purchases.json.gz`, `CONTRACT_VERSION = 4` |
| `projects/part order tool - app/for-users/…` | 0.9.0 click-through, walkthrough, guide, RETURNS-AND-SCRAP.md |

**nonjd-order-app**
| File | Change |
|---|---|
| `src/config.ts` | Three list IDs + required keys |
| `src/data/types.ts`, `src/data/contract.ts`, `src/data/files.ts` | `lastReceived`, `PurchasesFile`, v4 |
| `src/data/source.ts`, `src/data/lists.ts`, `src/data/graph.ts`, `src/data/mock/*` | Return rules, returns, return lines CRUD; `loadPurchases`; `loadOpenReturns` |
| `src/engine/returns.ts` (new) + `src/engine/index.ts` | Pure selection logic |
| `src/returns/ruleValidation.ts`, `src/returns/draft.ts`, `src/returns/status.ts`, `src/returns/actions.ts`, `src/returns/saveReturn.ts` (new) | Rule checks, document drafts / titles, statuses, status actions, the save |
| `src/export/csv.ts` | `returnCsv`, `scrapCsv` |
| `src/ui/areas.ts`, `src/App.tsx`, `src/pages/LaunchPage.tsx`, `src/pages/launch/launchCounts.ts` | The area, routes, the launch card |
| `src/pages/ReturnRulesPage.tsx`, `src/pages/returnRules/*` (new) | Rules page with tabs, edit panel, Try it |
| `src/pages/ReturnsPage.tsx`, `src/pages/ReturnWizardPage.tsx`, `src/pages/ReturnDocumentPage.tsx`, `src/pages/returns/*` (new) | Lists, the three-step wizard, the document page (one set of components, `kind` = Return / Scrap) |
| `src/transfers/draft.ts`, `src/pages/transfers/transferOrderText.ts` | `source` Return / Scrap |
| `src/pages/reorder/*`, `src/pages/transfers/*`, `src/pages/part/*` | "On return / On scrap" tags |
| `package.json`, `README.md` | 0.9.0 |

---

## Tasks

### Task I0a (Brian, SharePoint): `NonJD_ReturnRules`

- [ ] **Step 1 (Brian):** create the list on the Report Site, same permissions as `NonJD_TransferRules`:
  - Title (the rule name);
  - Kind (Choice `Return` / `Scrap`, required, no default);
  - Franchise (text; blank = all franchises, scrap only);
  - Active (Yes/No, default Yes); Archived (Yes/No, default No);
  - AllowancePct, CreditPct (Number, 2 dp);
  - AllowanceBase (Choice `Purchases12` / `StockValue` / `QualifyingValue`, not required);
  - NoSalesMonths, NotReceivedMonths (Number, 0 dp);
  - MinLineValue, MinUnitCost (Number, 2 dp);
  - LeaveOutManualOrder, LeaveOutMinimum (Yes/No, default No);
  - SeasonStart, SeasonEnd (text, `MM-DD`).
- [ ] **Step 2 (Claude):** verify the columns through Graph (`columns` query) and 0 items; record the list ID here.

### Task I0b (Brian, SharePoint): `NonJD_Returns`

- [ ] **Step 1 (Brian):** same permissions as `NonJD_Transfers`:
  - Title;
  - Kind (Choice `Return` / `Scrap`, required);
  - Franchise (text, **indexed**);
  - Status (Choice `Draft` / `Exported` / `Sent` / `Credited` / `Scrapped` / `Cancelled`, default `Draft`, **indexed**);
  - RANumber (text);
  - ExpectedCredit, CreditReceived (Number, 2 dp);
  - Archived (Yes/No, default No);
  - Parameters (multiple lines, plain text).
- [ ] **Step 2 (Claude):** verify (incl. the two indexes) and record the ID.

### Task I0c (Brian, SharePoint): `NonJD_ReturnLines`

- [ ] **Step 1 (Brian):** same permissions as `NonJD_TransferLines`:
  - Title;
  - ReturnId (Number, 0 dp, **indexed**);
  - Branch, Franchise, PartNumber, Description, Bin, LastSold, DemandElsewhere (text);
  - Qty (Number, 0 dp);
  - Cost, LineValue, CreditPct, CreditValue (Number, 2 dp).
- [ ] **Step 2 (Claude):** verify and record the ID.
- [ ] **Step 3 (Brian):** add to the app's `.env.local` on his PC (Claude can't read `.env*` files):
  `VITE_LIST_RETURN_RULES=<id>`, `VITE_LIST_RETURNS=<id>`, `VITE_LIST_RETURN_LINES=<id>`.

### Task I1: Gold: LastReceived and Fact_NonJD_Purchases (fabric-workspace-docs, Dev)

**Files:** the Gold notebook; `deploy/dp_refresh_dag.json`; `docs/TABLE-LINEAGE.md`.

- [ ] **Step 1:** in the notebook's input cell, read the purchases (follow `docs/architecture/dp-notebook-rules.md`:
  no `dropDuplicates`, deterministic, trim for the join):

```python
# Round 3 (Plan I): InTrans purchases from suppliers (Type 'P'; always Qty > 0, nothing netted, decision I1).
intrans_p = (spark.read.format("delta").load("Tables/Silver_InTrans")
             .where(F.col("Type") == "P")
             .select(F.upper(F.trim("Branch")).alias("Branch"), F.trim("Franchise").alias("Franchise"),
                     F.trim("PartNumber").alias("PartNumberTrim"),
                     F.to_date("TransDatetime").alias("TransDate"),
                     F.col("CostValue").cast("decimal(14,2)").alias("CostValue")))
```

- [ ] **Step 2:** LastReceived per branch + franchise + trimmed part, joined onto the reorder rows before the write (a
  left join on the same trimmed key the notebook already uses for InMaster; the column is a DATE, null when never):

```python
last_received = (intrans_p.groupBy("Branch", "Franchise", "PartNumberTrim")
                 .agg(F.max("TransDate").alias("LastReceived")))
```

- [ ] **Step 3:** Fact_NonJD_Purchases over the 12 full months before the build's Central month (the notebook's
  existing `current_month` / `add_months` helpers give the window the sales use):

```python
p_from, p_to = add_months(current_month, -12), current_month          # [p_from, p_to)
purchases = (intrans_p.where((F.col("TransDate") >= F.lit(p_from)) & (F.col("TransDate") < F.lit(p_to)))
             .where(~F.col("Branch").isin(EXCLUDED_BRANCHES))
             .groupBy("Branch", "Franchise")
             .agg(F.round(F.sum("CostValue"), 2).cast("double").alias("Purchases12"))
             .withColumn("BuiltAtUtc", F.lit(built_at_utc)))
(purchases.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
 .save("Tables/Fact_NonJD_Purchases"))
spark.sql("VACUUM delta.`Tables/Fact_NonJD_Purchases` RETAIN 0 HOURS")
```

  Use the notebook's existing names for the excluded branches, the build time and the Central month (read them first;
  rename in this snippet to match). Check the Franchise filter matches how the notebook scopes "non-JD" (it is
  `Franchise <> 'D'` upstream in `Silver_PartInformation`; apply the same here).
- [ ] **Step 4:** DAG: `Build_Gold_NonJD_Reorder` `dependsOn` += `"Build_Silver_InTrans"`, `produces` +=
  `"Fact_NonJD_Purchases"`. Confirm `Silver_InTrans` is already shortcut into DP_Presentation (other Gold items read
  it); if not, add it to the shortcut list and run `deploy/sync_shortcuts.py` on Dev.
- [ ] **Step 5:** `python deploy/dag_check.py`, `python deploy/hygiene_audit.py`, `python -m pytest deploy -q`;
  regenerate TABLE-LINEAGE (the repo's generator). Expected: all pass.
- [ ] **Step 6:** commit (named files), push dev, `python tools/dp-migration/git_sync.py <Dev presentation ws>`, run
  the Dev pipeline `mode=items`, `items=Build_Gold_NonJD_Reorder` (the az rest call in the round 2 notes). Expected:
  Completed; `Fact_NonJD_Purchases` has rows for every included branch with purchases.

### Task I2: The reference check (data-projects)

**Files:** `tools/dp-migration/nonjd_reorder_check.py`.

- [ ] **Step 1:** `load_inputs` reads InTrans Type P (Branch upper-trimmed, Franchise trimmed, PartNumber trimmed,
  `CAST(TransDatetime AS DATE)` in the UTC session, CostValue) into a `purchases_src` table, filtered to Franchise ≠ 'D'
  at read to keep it small.
- [ ] **Step 2:** expected `LastReceived` joins onto the expected reorder rows (max date per key) and is added to
  `COMPARE_COLS` (exact, null-safe).
- [ ] **Step 3:** expected purchases: `SELECT Branch, Franchise, round(sum(CostValue), 2) AS Purchases12 FROM
  purchases_src WHERE d >= $from AND d < $to AND Branch NOT IN (excluded) GROUP BY ALL`; compared with
  `Fact_NonJD_Purchases` on (Branch, Franchise) with a 0.005 tolerance; the summary adds a
  `Fact_NonJD_Purchases: {only_gold, only_expected, different}` line, and any difference FAILs.
- [ ] **Step 4:** run `python tools/dp-migration/nonjd_reorder_check.py --tier dev`. Expected: PASS with both new
  comparisons at 0. Commit.

### Task I3: The publish, contract v4 (data-projects)

**Files:** `publish/extract.py`, `publish/build_files.py`, `publish/publish_logic.py`, `publish/README.md`, tests.

- [ ] **Step 1 (tests first):** `test_extract.py`: `REORDER_COLUMNS` ends with `("LastReceived", "lastReceived")`;
  `purchases(con)` returns `[{branch, franchise, purchases12}]` sorted by branch then franchise.
  `test_build_files.py`: `build(..., purchases=[...])` writes `purchases.json.gz` with `{dataAsOf, rows}`; meta
  `contractVersion == 4`.
- [ ] **Step 2:** run `python -m pytest projects/"part order tool - app"/publish -q`. Expected: the new tests FAIL.
- [ ] **Step 3:** implement: the column (as a date string `YYYY-MM-DD` or null), `purchases(con)` reading
  `Fact_NonJD_Purchases`, the file, `CONTRACT_VERSION = 4`; README contract: the field, the file, "Changed in
  contractVersion 4".
- [ ] **Step 4:** tests pass; `python run_publish.py --out C:\Temp\nonjd-publish-v4` from Brian's PC against Dev
  (`NONJD_SOURCE=dev` for this run only: Brian sets it) builds the files. Commit. **Don't publish v4 to the library
  until Task I12.**

### Task I4: App data layer

**Files:** `src/config.ts`, `src/data/types.ts`, `src/data/contract.ts`, `src/data/files.ts`, `src/data/source.ts`,
`src/data/lists.ts`, `src/data/graph.ts`, `src/data/mock/*`, tests beside them.

- [ ] **Step 1: types** (`src/data/types.ts`):

```ts
/** `reorder_<branch>.json.gz` (contract v4): newest supplier receipt date, 'YYYY-MM-DD'; null = never;
 * undefined = a v3 file (unknown). */
// in ReorderPart:
lastReceived?: string | null;

/** `purchases.json.gz` (contract v4): 12 full months before the build month, at cost. */
export interface PurchasesFile {
  dataAsOf: string;
  rows: { branch: string; franchise: string; purchases12: number }[];
}

export type ReturnKind = 'Return' | 'Scrap';
export type AllowanceBase = 'Purchases12' | 'StockValue' | 'QualifyingValue';

export interface ReturnRule {
  kind: ReturnKind;
  name: string;
  /** '' = all franchises (scrap only). */
  franchise: string;
  active: boolean;
  archived: boolean;
  allowancePct: number | null;
  allowanceBase: AllowanceBase | null;
  noSalesMonths: number | null;
  notReceivedMonths: number | null;
  minLineValue: number | null;
  minUnitCost: number | null;
  creditPct: number | null;
  leaveOutManualOrder: boolean;
  leaveOutMinimum: boolean;
  /** 'MM-DD' or null. */
  seasonStart: string | null;
  seasonEnd: string | null;
}
export interface ReturnRuleRow extends ReturnRule, ItemAudit { itemId: number }
export type ReturnRuleInput = ReturnRule;
export type ReturnRulePatch = Partial<ReturnRule>;

export type ReturnStatus = 'Draft' | 'Exported' | 'Sent' | 'Credited' | 'Scrapped' | 'Cancelled';
export interface ReturnDoc extends ItemAudit {
  itemId: number;
  kind: ReturnKind;
  title: string;
  franchise: string;
  status: ReturnStatus;
  raNumber: string | null;
  expectedCredit: number | null;
  creditReceived: number | null;
  archived: boolean;
  parameters: string | null;
  created: string | null;
  author: string | null;
}
export interface ReturnLine extends ItemAudit {
  itemId: number;
  returnId: number;
  branch: string;
  franchise: string;
  partNumber: string;
  description: string | null;
  bin: string | null;
  qty: number;
  cost: number;
  lineValue: number;
  creditPct: number | null;
  creditValue: number | null;
  lastSold: string | null;
  demandElsewhere: string | null;
}
export type ReturnDocInput = Omit<ReturnDoc, keyof ItemAudit | 'itemId' | 'created' | 'author'>;
export type ReturnDocPatch = Partial<Pick<ReturnDoc, 'status' | 'raNumber' | 'creditReceived' | 'archived' | 'expectedCredit'>>;
export type ReturnLineInput = Omit<ReturnLine, keyof ItemAudit | 'itemId'>;
export type ReturnLinePatch = Partial<Pick<ReturnLine, 'qty' | 'lineValue' | 'creditValue'>>;
/** Open documents' lines (Draft / Exported), for holds (decision I11). */
export interface OpenReturns { lines: (ReturnLine & { title: string; kind: ReturnKind })[] }
```

- [ ] **Step 2: source interface** (`src/data/source.ts`), each documented like its transfer twin:
  `loadPurchases(): Promise<PurchasesFile | null>` (null on a v3 publish), `loadReturnRules()`,
  `saveReturnRule(input)`, `patchReturnRule(itemId, patch)`, `loadReturns(filter?: { kind?: ReturnKind;
  includeArchived?: boolean })`, `loadReturn(itemId)`, `createReturn(input)`, `updateReturn(itemId, patch)`,
  `loadReturnLines(returnId)`, `createReturnLines(returnId, lines)`, `updateReturnLine(itemId, patch)`,
  `deleteReturnLine(itemId)`, `loadOpenReturns()`.
- [ ] **Step 3: contract** accepts 3 and 4 (`SUPPORTED_CONTRACT_VERSIONS = [3, 4]`); `purchases.json.gz` loaded only
  when `contractVersion >= 4`.
- [ ] **Step 4: Graph + lists mapping** (field names exactly as the I0 columns; number columns null-safe; `Kind` and
  `Status` choices validated, an unknown value → the row is skipped with a console warning, as transfer rows).
  `updateReturn` uses the same If-Match etag check as `updateTransferOrder` (refused when someone else changed it).
- [ ] **Step 5: mock** (`src/data/mock`): two return rules (MM Return "MM annual return": 10% Purchases12, no sales
  24, not received 12, credit 85%; All-franchise Scrap "Scrap default": no sales 36, min unit cost 0.10), purchases
  for MM at branches 1 and 92, and parts covering: never sold (MM-RET-OLD), sold this month (MM-RET-NOW), received 6
  months ago (MM-RET-NEW), a minimum (MM-RET-MIN), ManualOrder (MM-RET-MAN), demand at 3 and 92 (MM-RET-DEM, 92's row
  `allowReceive: false`), held by a mock open return (MM-RET-HELD, qty 2 of 5).
- [ ] **Step 6:** tests: graph mapping round trips, v3 files load with `lastReceived` undefined and purchases null.
  Run `npx vitest run src/data`. Commit.

### Task I5: The engine (pure)

**Files:** create `src/engine/returns.ts`, `src/engine/__tests__/returns.test.ts`; export from `src/engine/index.ts`.

- [ ] **Step 1: tests first.** One `describe` per function below, with these cases at least:
  - `availableQty`: `trunc(onHand) - max(0, trunc(pending)) - appOutbound - held`, floored at 0 (onHand 5.7,
    pending 1, out 1, held 2 → 1; negative pending ignored).
  - `noSalesFor`: sales `[0, 0, 3, …]` → false for 24 (index 2 sold), true for 1; `[2, 0…]` → false (this month).
  - `lastSold`: newest index with sales > 0 → its label; none → `null`.
  - `receivedWithin`: lastReceived `2026-05-01`, today `2026-10-30`, 12 months → true; `undefined` → null (unknown).
  - `inSeason`: `11-01`..`02-28` on Dec 15 → true, on Mar 1 → false; both null → true.
  - `demandElsewhere`: requests summed over indexes 1..18 per other branch, > 0 only, busiest first, ties by
    `compareBranchOrder`; the line's own branch never counts.
  - `allowanceDollars` for each base (Purchases12 summed over ticked branches; StockValue = Σ trunc(onHand) × cost;
    QualifyingValue = Σ qualifying line values), × pct / 100, rounded to cents.
  - `prePick`: lines by last sold ascending (null first), value desc, branch order, part number; skip a line that
    doesn't fit, keep scanning; allowance 0 → nothing ticked.
  - `defaultTransferTarget`: busiest branch with `allowReceive`; none → null.
  - `qualifyingLines`: each leave-out, the min line value (return) / min unit cost (scrap), the no-sales and
    not-received filters, held qty taken off.
- [ ] **Step 2:** `npx vitest run src/engine/__tests__/returns.test.ts` → FAIL (module missing).
- [ ] **Step 3: implement:**

```ts
// Round 3 phase 1 (Plan I): which parts qualify for a return or scrap list, the allowance and the pre-pick.
// Pure functions over the reorder + history rows the app already loads for transfers (spec "New return / New scrap
// list"); no Gold version and no parity check (the selection is live-only, like One-Time).
import type { AllowanceBase, ReturnRule } from '@/data/types';
import { compareBranchOrder } from './transfers';
import { committedKey } from './committed';

export interface ReturnSourceRow {
  branch: string;
  franchise: string;
  partNumber: string;
  description: string | null;
  bin: string;
  onHand: number;
  pendingQty: number;
  appOutboundQty: number;
  cost: number;
  minimumQty: number | null;
  manualOrder: boolean;
  allowReceive: boolean;
  lastReceived?: string | null;
  /** History, index 0 = current partial month; [] when the part has no history row. */
  sales: readonly number[];
  requests: readonly number[];
}

export interface ReturnCandidate {
  row: ReturnSourceRow;
  available: number;
  /** 'YYYY-MM' or null (over 5 years). */
  lastSold: string | null;
  value: number;
  credit: number | null;
  demand: { branch: string; requests: number }[];
  transferTarget: string | null;
}

const cents = (x: number) => Math.round(x * 100) / 100;

export function availableQty(r: Pick<ReturnSourceRow, 'onHand' | 'pendingQty' | 'appOutboundQty'>, held = 0): number {
  return Math.max(0, Math.trunc(r.onHand) - Math.max(0, Math.trunc(r.pendingQty)) - r.appOutboundQty - held);
}

export function noSalesFor(sales: readonly number[], months: number): boolean {
  for (let i = 0; i <= months && i < sales.length; i++) if (sales[i] > 0) return false;
  return true;
}

export function lastSold(sales: readonly number[], labels: readonly string[]): string | null {
  for (let i = 0; i < sales.length; i++) if (sales[i] > 0) return labels[i] ?? null;
  return null;
}

/** null = unknown (a v3 file); true when received on or after today minus `months`. */
export function receivedWithin(lastReceived: string | null | undefined, today: string, months: number): boolean | null {
  if (lastReceived === undefined) return null;
  if (lastReceived === null) return false;
  const [y, m, d] = today.split('-').map(Number);
  const from = new Date(Date.UTC(y, m - 1 - months, d)).toISOString().slice(0, 10);
  return lastReceived >= from;
}

export function inSeason(start: string | null, end: string | null, today: string): boolean {
  if (!start || !end) return true;
  const md = today.slice(5);
  return start <= end ? md >= start && md <= end : md >= start || md <= end;
}

export function demandElsewhere(
  own: string, byBranch: ReadonlyMap<string, readonly number[]>, windowMonths: number,
): { branch: string; requests: number }[] {
  const out: { branch: string; requests: number }[] = [];
  for (const [branch, requests] of byBranch) {
    if (branch === own) continue;
    let n = 0;
    for (let i = 1; i <= windowMonths && i < requests.length; i++) n += requests[i];
    if (n > 0) out.push({ branch, requests: n });
  }
  return out.sort((a, b) => b.requests - a.requests || compareBranchOrder(a.branch, b.branch));
}

export function defaultTransferTarget(
  demand: readonly { branch: string }[], allowReceive: (branch: string) => boolean,
): string | null {
  return demand.find((d) => allowReceive(d.branch))?.branch ?? null;
}

export function demandText(demand: readonly { branch: string; requests: number }[]): string {
  return demand.map((d) => `${d.branch} (${d.requests})`).join(', ');
}

export interface AllowanceInput {
  base: AllowanceBase;
  pct: number;
  purchases12: number;          // Σ over the ticked branches for the franchise
  stockValue: number;           // Σ trunc(onHand) × cost, ticked branches, franchise
  qualifyingValue: number;      // Σ qualifying line values
}
export function allowanceDollars(a: AllowanceInput): number {
  const base = a.base === 'Purchases12' ? a.purchases12 : a.base === 'StockValue' ? a.stockValue : a.qualifyingValue;
  return cents((base * a.pct) / 100);
}

/** Keys of the lines the pre-pick ticks (decision R4). */
export function prePick(lines: readonly ReturnCandidate[], allowance: number): Set<string> {
  const order = [...lines].sort((a, b) =>
    (a.lastSold ?? '') .localeCompare(b.lastSold ?? '')
    || b.value - a.value
    || compareBranchOrder(a.row.branch, b.row.branch)
    || a.row.partNumber.localeCompare(b.row.partNumber));
  const picked = new Set<string>();
  let used = 0;
  for (const l of order) {
    if (used + l.value <= allowance + 1e-9) {
      picked.add(lineKey(l.row));
      used = cents(used + l.value);
    }
  }
  return picked;
}

export function lineKey(r: Pick<ReturnSourceRow, 'branch' | 'franchise' | 'partNumber'>): string {
  return committedKey(r.branch, r.franchise, r.partNumber);
}

export interface QualifyContext {
  rule: ReturnRule;
  today: string;               // Central 'YYYY-MM-DD' of the build
  labels: readonly string[];   // history month labels
  held: ReadonlyMap<string, number>;
  requestsByPart: (franchise: string, partNumber: string) => ReadonlyMap<string, readonly number[]>;
  /** Over every loaded branch, not only the ticked ones (a ticked-off branch can still receive). */
  allowReceive: (branch: string, franchise: string, partNumber: string) => boolean;
  windowMonths: number;
}

export function qualifyingLines(rows: readonly ReturnSourceRow[], ctx: QualifyContext): ReturnCandidate[] {
  const { rule } = ctx;
  const out: ReturnCandidate[] = [];
  for (const r of rows) {
    if (rule.franchise && r.franchise !== rule.franchise) continue;
    if (rule.leaveOutManualOrder && r.manualOrder) continue;
    if (rule.leaveOutMinimum && (r.minimumQty ?? 0) > 0) continue;
    const available = availableQty(r, ctx.held.get(lineKey(r)) ?? 0);
    if (available <= 0) continue;
    if (rule.noSalesMonths != null && !noSalesFor(r.sales, rule.noSalesMonths)) continue;
    if (rule.notReceivedMonths != null && receivedWithin(r.lastReceived, ctx.today, rule.notReceivedMonths) === true) continue;
    const value = cents(available * r.cost);
    if (rule.kind === 'Return' && rule.minLineValue != null && value < rule.minLineValue) continue;
    if (rule.kind === 'Scrap' && rule.minUnitCost != null && r.cost < rule.minUnitCost) continue;
    const demand = demandElsewhere(r.branch, ctx.requestsByPart(r.franchise, r.partNumber), ctx.windowMonths);
    out.push({
      row: r, available, value,
      lastSold: lastSold(r.sales, ctx.labels),
      credit: rule.kind === 'Return' && rule.creditPct != null ? cents((value * rule.creditPct) / 100) : null,
      demand,
      transferTarget: defaultTransferTarget(demand, (b) => ctx.allowReceive(b, r.franchise, r.partNumber)),
    });
  }
  return out;
}
```

  (A `notReceivedMonths` with unknown data (`null` from `receivedWithin`) doesn't exclude; the rules page and Step 1
  show "Last received isn't in this morning's data yet" while a v3 publish is live, decision I5.)
- [ ] **Step 4:** tests pass; `npx tsc --noEmit -p .`, `npm run lint`. Commit `I5: returns engine`.

### Task I6: Rule validation and the Return & scrap rules page

**Files:** create `src/returns/ruleValidation.ts` (+ test), `src/pages/ReturnRulesPage.tsx`,
`src/pages/returnRules/RuleTable.tsx`, `src/pages/returnRules/RuleEditor.tsx`, `src/pages/returnRules/TryIt.tsx`,
tests under `src/pages/__tests__/ReturnRulesPage.test.tsx`.

- [ ] **Step 1 (tests first) `ruleProblems(rule): string[]`:** "Give the rule a name."; "A return rule needs a
  franchise."; "Allowance % must be 0 to 100." (and for Credit %); "Pick what the allowance is based on.";
  "No sales for must be 1 to 59 months."; "Not received for must be blank or 1 to 59 months."; "Min line value
  can't be negative." (and Min unit cost); "Season start and end must both be set (MM-DD) or both blank.";
  a valid MM rule → `[]`. And `activeConflict(rule, rows)`: the other active, unarchived rule with the same Kind and
  franchise (`''` for All), or null.
- [ ] **Step 2:** implement until green.
- [ ] **Step 3: page** at `/return-rules`, tabs **Return rules** / **Scrap rules** (`?tab=scrap`), modelled on
  `TransferRulesPage.tsx` (read it first; same Card / table / editor drawer / Show archived pattern):
  - table columns: Name, Franchise ("All franchises" for ''), Terms (`ruleTerms(rule)`: e.g. "10% of 12-mo purchases ·
    no sales 24 mo · not received 12 mo · credit 85%"; scrap: "no sales 36 mo · unit cost ≥ $0.10"), Season, Active,
    Changed;
  - editor groups **Which parts / Allowance / Credit / When** (Allowance and Credit hidden on the Scrap tab);
  - Save with a conflict asks "Rule '<name>' is active for MM. Make this one active instead?" (Stay / Make this one
    active: patches the other `active: false`, then saves);
  - **Try it** (`TryIt.tsx`): loads every branch (`useAllBranches`, the transfer rules page's loader), runs
    `qualifyingLines` with the draft rule, shows: qualifying parts and value; return: allowance and what `prePick`
    ticks ("pre-pick ticks 37 parts, $4,820 of $5,000"); scrap: parts with demand elsewhere.
  - When the publish is v3: a note under Not received for: "Last received isn't in this morning's data yet; this
    filter applies once it is."
- [ ] **Step 4: tests:** the two tabs; create, edit, archive; the conflict question both answers; Try it figures on the
  mock data (MM rule: qualifying = MM-RET-OLD, MM-RET-DEM, MM-RET-HELD (3 left); MM-RET-NOW / -NEW / -MIN excluded as
  their switches say).
- [ ] **Step 5:** full suite, lint, tsc. Commit.

### Task I7: The area, routes and the launch card

**Files:** `src/ui/areas.ts` (+ test), `src/App.tsx`, `src/pages/LaunchPage.tsx`, `src/pages/launch/launchCounts.ts`
(+ tests).

- [ ] **Step 1:** `AREAS` gains, after `cleanup`: `{ id: 'returns', name: 'Returns & scrap', description: 'Vendor
  returns and scrap, by franchise rule.', live: true, screens: [Returns /returns, Scrap /scrap, Return & scrap rules
  /return-rules] }`; `areaFor` maps `/returns*`, `/scrap*`, `/return-rules` to it (tests for each, incl. `/returns/new`
  and `/scrap/12`).
- [ ] **Step 2:** routes: `/returns`, `/returns/new`, `/returns/:id`, `/scrap`, `/scrap/new`, `/scrap/:id`,
  `/return-rules` (the pages from I6, I8, I9; placeholders until those land, each with a test that it renders).
- [ ] **Step 3:** `launchCounts` adds `openReturns` / `openScrap` from `loadOpenReturns()` (documents, not lines);
  the card shows "N open returns · N open scrap lists", parts left out when 0, nothing while loading or on error
  (as the other counts).
- [ ] **Step 4:** tests; commit.

### Task I8: New return / New scrap list (the wizard)

**Files:** create `src/pages/ReturnWizardPage.tsx`, `src/pages/returns/steps.ts`, `src/pages/returns/PartsStep.tsx`,
`src/pages/returns/ReviewStep.tsx`, `src/pages/returns/useReturnSource.ts`, `src/returns/draft.ts`,
`src/returns/saveReturn.ts` (+ tests); modify `src/transfers/draft.ts`, `src/data/types.ts` (`TransferParameters.source`),
`src/pages/transfers/transferOrderText.ts`.

- [ ] **Step 1: `useReturnSource(kind)`:** loads every branch (the shared all-branch loader, progress / Cancel / Load
  the rest), purchases, open returns (holds) and open transfers; builds `ReturnSourceRow[]` by joining each branch's
  reorder parts to its history parts (`committedKey`), `requestsByPart` from every branch's history and `allowReceive`
  from every branch's reorder rows (a branch without the part → false). Returns
  `{ rows, labels, today, purchases, held, requestsByPart, allowReceive, loading, error }`; the wizard passes only the
  ticked branches' rows to `qualifyingLines`.
- [ ] **Step 2: Set up step:** franchise select (franchises with an active rule of this kind first, then the rest);
  the applied rule in one line (`ruleTerms`) with a link to `/return-rules?tab=…`; for scrap with no franchise rule,
  the All-franchises rule applies; no rule → "No return rule for MM yet" + **Create one** (opens the rules page
  editor prefilled with the franchise); branch checkboxes (all ticked); out of season → a note; the demand window
  (default 18, 1–59).
- [ ] **Step 3: Parts step (`PartsStep.tsx`):** the `qualifyingLines` result for the ticked branches; ticks start from
  `prePick` (return) or all (scrap); qty input (whole number, 1..available; "At most N"); the allowance meter
  (`allowanceDollars` with the rule's base; red when the ticked value is over); Transfer instead checkbox where
  `transferTarget` is not null (default on for scrap, off for returns, R16) with a branch select over the demand
  branches that allow receiving; search, branch filter; sticky footer "N lines · $X · credit $Y" (+ "N to transfer").
- [ ] **Step 4: `src/returns/draft.ts`:** `returnTitle(kind, franchise, now)` (`MM-RET-20261030-1415`, Central);
  `buildReturnDraft(...)` → `{ doc: ReturnDocInput, lines: ReturnLineInput[], transfers: TransferTick[] }` where
  `Parameters` = `{ rule (as applied), windowMonths, dataAsOf, branches, saveId }`, ExpectedCredit = Σ credit (returns),
  lines carry `lastSold` (label or "Over 5 years") and `demandElsewhere` (`demandText`).
- [ ] **Step 5: `saveReturn.ts`:** re-read `loadOpenReturns()` and open transfers; recompute `availableQty` for every
  ticked line (and transfer-instead line); anything short → nothing saved, a message naming the parts ("MM-RET-OLD at
  1: 2 available now, 4 ticked"). Then transfers through the existing saver (`source: kind`, `orderName: title`), then
  the document, then its lines (decision I14: a failure after the transfers keeps a Retry for the document).
- [ ] **Step 6: Review step:** totals, the transfers grouped From → To, **Save**; after saving, open the document page.
  Leaving with ticks or unsaved changes asks (the LeaveTicksGuard).
- [ ] **Step 7:** `TransferParameters.source` adds `'Return' | 'Scrap'`; `parametersSummary` → `From Return "<title>"` /
  `From Scrap "<title>"` (tests).
- [ ] **Step 8: tests** on the mock data: MM return pre-pick ticks within the allowance; MM-RET-DEM's Transfer instead
  offers 3 only (92 can't receive); a scrap list starts with Transfer instead on; save writes one transfer order
  (source Scrap) and the document with its lines; the stock re-check refusal; Retry after a document failure.
  Full suite, lint, tsc. Commit.

### Task I9: The Returns / Scrap lists and the document page

**Files:** create `src/pages/ReturnsPage.tsx` (both lists, `kind` prop), `src/pages/ReturnDocumentPage.tsx`,
`src/returns/status.ts`, `src/returns/actions.ts` (+ tests); modify `src/export/csv.ts` (+ tests).

- [ ] **Step 1: `status.ts`:** pills (Draft amber, Exported blue, Sent green, Credited dark green, Scrapped green,
  Cancelled grey); `nextActions(kind, status)`; `canEditLines(status)` = Draft; `canArchive` = Sent / Credited /
  Scrapped / Cancelled; `canCancel` = Draft / Exported.
- [ ] **Step 2: `actions.ts`:** `recordReturnExport` (Draft → Exported; Exported stays), `markSent`, `markScrapped`,
  `markCredited(amount)`, `cancelReturn`, `setReturnArchived`, `setRaNumber`; each re-reads the document first and
  refuses with "This return was changed by someone else; reload it." on a status mismatch (as `transfers/actions.ts`).
- [ ] **Step 3: CSV:** `RETURN_CSV_HEADER = ['Branch','PartNumber','Description','Bin','Qty','Cost','LineValue',
  'CreditPct','CreditValue','LastSold']`, a final totals row (`Total`, …, LineValue sum, '', CreditValue sum, ''),
  `neutraliseFormula` on text cells; `SCRAP_CSV_HEADER` without the credit columns; **Export by branch** = one file per
  branch (`<title>-<branch>.csv`).
- [ ] **Step 4: list pages** `/returns`, `/scrap`: columns Title, Franchise, Branches, Lines, Value, Credit
  (expected / received), Status pill, Saved; Show archived; **New return** / **New scrap list**.
- [ ] **Step 5: document page:** header (title, franchise, status, RA number field, Expected / Received "(94%)"),
  lines table (qty editable while Draft, remove line), actions by `nextActions`, the transfer orders made with it
  (from `loadTransferOrders` filtered on Parameters `orderName` = title).
- [ ] **Step 6:** tests for each status path and the refusal; commit.

### Task I10: Holds on the other pages

**Files:** `src/state/` (a `useOpenReturns` hook beside the open transfers), Recommended Reorder line, transfer
suggestion line, Part page; tests.

- [ ] **Step 1:** `useOpenReturns()` (shared, cached like the open transfers) → `Map<committedKey, { title, kind,
  qty }[]>`.
- [ ] **Step 2:** a small tag `On return MM-RET-… (2)` / `On scrap … (2)` (neutral grey Pill) on Reorder lines,
  transfer suggestion lines and the Part page stock table, for the line's branch + franchise + part. No calculation
  changes (R10).
- [ ] **Step 3:** tests with MM-RET-HELD; full suite; commit.

### Task I11: Click-through, review, 0.9.0 build

- [ ] **Step 1:** `src/__tests__/clickThrough090.test.tsx` walks: launch card → rules (create MM return rule) → New
  return (pre-pick, meter, one Transfer instead) → save → document (Export, RA, Sent, Credited) → New scrap list →
  save → tags on Reorder.
- [ ] **Step 2:** `for-users/0.9.0-click-through.md` for Brian (mock mode, numbered steps with what to see).
- [ ] **Step 3:** review pass (typescript-reviewer over the I4–I10 range); fix; full suite, lint, tsc.
- [ ] **Step 4:** `package.json` 0.9.0, README Versions row; `npm run build`; check dist (list and site IDs incl. the
  three new ones, no mock strings, version and commit stamped). Push.

### Task I12: Release (Brian's steps, one at a time)

- [ ] **Step 1 (Brian):** confirm Type R (decision I1).
- [ ] **Step 2:** fabric-workspace-docs: `python deploy/merge_preview.py`, PR dev → main (Gold + DAG + lineage).
  **Brian merges** (merge commit) and runs **Deploy DP backend**; then `python deploy/claim_prod_pipeline.py` (Brian),
  fast-forward dev.
- [ ] **Step 3 (Brian):** deploy app 0.9.0 to Fedora (still reads v3: no purchases yet; the Purchases12 base shows
  "available after the next publish").
- [ ] **Step 4:** the next 06:15 Prod run; `/check-refresh prod`; `nonjd_reorder_check.py --tier prod` PASS with the
  new comparisons.
- [ ] **Step 5 (Brian, Gateway PC):** pull data-projects, so the 07:15 publish writes v4 (`purchases.json.gz`,
  `lastReceived`). Claude confirms `_meta.json` `contractVersion: 4` in the library.
- [ ] **Step 6:** real test on Fedora: Brian makes a TEST return rule and a TEST return (one line, quantity 1) and a
  TEST scrap list with one Transfer instead; Claude checks the lists through Graph; then cancels and deletes the TEST
  rows (test data, Brian's standing OK 2026-10-30).

### Task I13: Documents and progress

- [ ] **Step 1:** walkthrough "Version 0.9.0" (Part 2) and the 0.9.0 release checks (Part 3); guide section "Returns &
  scrap"; `projects/part order tool - app/RETURNS-AND-SCRAP.md` (Ben: each rule field, the allowance bases, the
  pre-pick, demand elsewhere, Transfer instead, statuses); regenerate the .docx (check for hand edits first).
- [ ] **Step 2:** FUTURE-IDEAS F6 → done in 0.9.0; this plan's Progress; the spec's Progress; memory note.

---

## Self-review against the spec

- R1/R2/R7 rules and fields: I0a, I4 types, I6. R3 company-wide: I8 Step 1–3 (one list over ticked branches,
  allowance summed). R4 pre-pick + meter: I5 `prePick`, I8 Step 3. R5 CSV: I9 Step 3. R6/D1 own lists: I0. R8
  demand elsewhere: I5, I8. R9/I10 Transfer instead target: I5 `defaultTransferTarget`, I8. R10 holds: I4
  `loadOpenReturns`, I10, I8 Step 5. R13 area: I7. R14 statuses + RA + credit: I0b, I9. R15 purchases: I1–I3. R16
  defaults: I8 Step 3.
- Spec "Step 1" (season note, Create one, window): I8 Step 2. "Safety" re-check and stale refusal: I8 Step 5, I9 Step 2.
- Testing section: I5 unit tests, I2 reference, I4 mock cases, I11 click-through, I12 real test.
