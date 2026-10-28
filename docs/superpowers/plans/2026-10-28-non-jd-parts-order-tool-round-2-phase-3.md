# Non-JD Parts Order Tool: round 2 phase 3: the transfer step (Plan F, app 0.6.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax. SharePoint, Entra, Gateway PC and Fabric UI steps are Brian's, one at a time, verified. Live SharePoint writes by Claude need Brian's explicit OK.

> **Progress:** plan written 2026-10-28 (Claude, for Brian). Nothing built yet.
> - **Starting point:** app 0.5.0 (`88c7d59`) is live on Fedora on Prod data since 2026-10-28 (Plan E E18). Prod Gold already reads saved transfers (step 8b, `NonJD_Transfers` + lines, shortcut on Prod). Contract v3 is unchanged by this plan.
> - **Open from Plan E, settled here:** "no Refresh re-reads committed lines on a page left open" (Brian's decision 2 below); "PlacedAt / Created treated as Pacific in `df_NonJD_Transfers_Raw`" (F13 step 3, checked with the first real saved transfer).

**Goal:** people tick suggested transfers, save them as transfer orders (one per sending + receiving branch), see the order drop, export each transfer for Equip, mark it entered or cancel it, and Ben edits transfer rules in the app with Try it.

**Architecture:** app-only. The engine already does Parts 1–3 live over every branch (`state/engineBranches.ts` `useAllBranchTransfers`) and counts committed app transfers (`engine/committed.ts`); phase 3 adds writes to the three transfer lists, a tick/preview layer over the live suggestions, and four screens (Reorder step 1, Transfers page ticking + Transfer orders, the transfer order page, Transfer rules). Gold, the reference, the publish and the contract don't change; the only possible backend change is a time-zone fix in `df_NonJD_Transfers_Raw` (F13, conditional).

**Tech stack:** React 18 + TypeScript + Vite + Tailwind, Vitest + Testing Library, Microsoft Graph (SharePoint lists) through `src/data/graph.ts`, mock source for tests and `npm run dev`.

**Spec:** `docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md`: "Part 4: what ticking does", "The lists", "The UI" (Recommended Reorder transfer step, Transfers page, Transfer rules page, Home), phasing row 3. Ben's answers: `projects/part order tool - app/feedback/2026-10-27-ben-transfer-answers.md`.

---

## Brian's decisions (2026-10-28)

| # | Decision |
|---|---|
| B1 | **Recommended Reorder gets the spec's two-step stepper, "1 Transfers → 2 Order".** Step 1 opens first when any suggestion goes into the selected branches; otherwise it says "No transfers suggested" and step 2 is open. Step 1 lists the suggestions into those branches: both kinds start ticked (A12), each with its kind badge, a franchise filter (A13), quantity editable 0..suggested. Ticking previews step 2 live (Part 4: recompute only the receiving part with AppInboundQty + the ticked quantity; the allocation is never re-run on a tick). **Save transfers** writes one transfer order per From + To, all franchises together. **Continue to order** with unsaved ticks asks **Save and continue** / **Continue without them**. Step 2 is today's order list; a line a saved transfer reduced says "Transfer in: N from branch X". 0.5.0's purple markers stay, and until every branch has loaded step 1 shows this morning's file marked "as of this morning". |
| B2 | **Freshness: re-read on open, after save, and on Refresh; check before saving; no polling.** `NonJD_Transfers` + lines are re-read when the Transfer step or the Transfers page opens, after every save, and on a visible **Refresh** button. Just before saving, the app re-reads them, re-runs the calculation, and checks each ticked line against the fresh suggestions; if a sender no longer has the stock (someone else saved meanwhile), it shows what changed and does not save until the person looks again. |

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| Y1 | **Saving is allowed only once every branch has loaded** (the live result). Before that, step 1 and the Transfers page show this morning's suggestions read-only, with "Loading every branch… you can save once it finishes" by the Save button. | B2's check needs the live excess; saving from the morning file could promise stock someone saved away today. Loading takes about 10 s on Fedora. |
| Y2 | **Reorder loads every branch in the background only when this morning's file has a suggestion into the selected branches.** With none, step 1 says "No transfers suggested", step 2 opens, and nothing extra loads. | 0.5.0 kept Reorder to its own branch for speed. Most mornings most branches have suggestions, but a branch with none shouldn't pay 10 s. |
| Y3 | **The stale check compares ticks with the fresh suggestion lines:** a ticked line is stale when the fresh run has no line with the same kind, From, To, franchise and part, or its fresh quantity is below the ticked one. Stale ticks are clamped to the fresh quantity (or dropped), fresh lines that are new appear ticked, and a banner lists the changes; the person clicks Save again. | One rule covers both a sender that lost stock and a receiver that someone else already filled. |
| Y4 | **A new `TransferSaver` (`src/transfers/saveTransfers.ts`) copies `OrderSaver`'s recovery algorithm** (saveId in Parameters, look up before re-creating an ambiguous header, re-read and re-match lines, single-flight, never delete) and reuses its exported helpers (`mayHaveBeenSaved`, `rootError`, `newSaveId`). Lines are matched on **franchise + part number** (exact, then ignoring trailing spaces), because one transfer mixes franchises. `OrderSaver` is left alone. | The order saver is live and proven; a transfer header has two branches and no franchise, so a shared generic class would touch working code for little gain. |
| Y5 | **A transfer line's LineValue = Qty × Cost, where Cost is the sender's cost** (spec "The lists"), rounded with `lineValue` from `orders/draft.ts`. Suggestion values (Transfers page, footers) stay at the receiver's cost (spec Part 3). | The transfer order records stock moved out of the sender; the suggestion's value is what buying would have cost. The two can differ (984 of 2,312 Dev lines). Each screen labels which cost it uses. |
| Y6 | **Transfer lines are never deleted.** On a Draft transfer a line's Qty can be set to 0 (it then counts 0 and is left out of the CSV). Cancel ends the whole transfer. | The spec says nothing is deleted for transfers; Qty 0 keeps the record of what was suggested (SuggestedQty). |
| Y7 | **Leaving step 1 asks only if the person changed something** (an untick or a quantity edit). The default all-ticked state is regenerated on return, so losing it loses nothing. Step 2 keeps 0.5.0's LeaveTicksGuard. | Both kinds start ticked; a guard on default ticks would ask every time someone leaves Reorder. |
| Y8 | **Routes:** `/reorder?…&step=transfers|order` (step 1 / 2); `/transfers` (suggestions) and `/transfers?tab=orders` (Transfer orders); `/transfers/orders/:transferId` (one transfer order); `/transfer-rules` (nav item "Transfer rules", after Rules). Home's transfers card links to `/reorder?branches=<branch>&step=transfers` (it links to `/transfers?to=` in 0.5.0). | The spec's Home line points at Reorder step 1; the Transfers page keeps its own link in the card's text. |
| Y9 | **Mark entered in Equip** sets Status Placed and PlacedAt = now (ISO UTC). It needs an export first, like orders. Cancel is allowed for Draft and Exported (confirm first); Placed can't be cancelled (it is in Equip). | Mirrors `orders/status.ts`; A14: a Placed transfer counts until the next morning's data carries it in Equip. |
| Y10 | **Who can edit transfer rules** is SharePoint's list permission, as for order rules (`NO_PERMISSION` message on a 403). Brian sets it (F0). | Same model as Rules; the app shows the page read-only to someone without write access. |
| Y11 | **Try it for transfer rules** reports, before → after: conventional lines and $ (labelled "Order $ avoided", the receivers' cost), redistribution lines and $, and the 20 parts whose suggested value changes most. It runs on the loaded branches with the draft rule in place of the saved one. | Spec "Transfer rules page"; conventional $ is exactly the order dollars a transfer replaces, so one figure carries both names. |

**Spec items that 0.5.0 already changed (this plan follows 0.5.0):**
- Home's transfers line was built in 0.5.0 (spec: phase 3). Only its link changes (Y8).
- The Reorder row detail's "Transfers" section is 0.5.0's purple "Suggested transfers" box; phase 3 keeps it and adds the saved transfers in (already listed as "Transfers saved in this app").
- 0.5.0's Reorder pills come from the morning file; in phase 3 they switch to the live run once every branch has loaded (Y2).
- The Transfers page's "Saving transfers comes in the next version…" line is removed (F6).

---

## File map

**nonjd-order-app**
| File | Change |
|---|---|
| `src/data/types.ts` | `TransferOrderInput`, `TransferOrderPatch`, `TransferOrderLineInput`, `TransferOrderLinePatch`, `TransferOrdersFilter`, `TransferRuleInput`, `TransferRulePatch`, `TransferParameters` |
| `src/data/lists.ts` | Transfer order reads/writes, transfer rule writes, `*ToFields` mappers |
| `src/data/source.ts`, `src/data/mock/index.ts`, `src/data/mock/fixtures.ts` | New DataSource methods; mock writes |
| `src/transfers/draft.ts` (new) | Ticks → transfer drafts (one per From + To), titles, Parameters, inputs |
| `src/transfers/saveTransfers.ts` (new) | `TransferSaver` (Y4) |
| `src/transfers/status.ts` (new) | Status rules and patches (Y9), labels |
| `src/transfers/ticks.ts` (new) | Default ticks, preview inputs, stale check (Y3) |
| `src/export/csv.ts` | `TRANSFER_ORDER_CSV_HEADER`, `transferOrderCsv` |
| `src/pages/transfers/TransferStep.tsx` (new) | The tick/save table shared by Reorder step 1 and the Transfers page |
| `src/pages/transfers/paths.ts` (new) | Route helpers (Y8) |
| `src/pages/transfers/TransferOrdersList.tsx` (new) | The Transfer orders tab |
| `src/pages/TransferOrderPage.tsx` (new) | One transfer order |
| `src/pages/TransfersPage.tsx` | Ticking + Save through TransferStep, status filter, Refresh, Transfer orders tab |
| `src/pages/ReorderPage.tsx`, `src/pages/reorder/Stepper.tsx` (new), `src/pages/reorder/RowDetail.tsx` | Stepper, step 1, "Transfer in" notes, live pills |
| `src/pages/HomePage.tsx`, `src/pages/reorder/transferHints.ts` | Card link (Y8) |
| `src/pages/TransferRulesPage.tsx` (new), `src/pages/transferRules/transferRuleForm.ts` (new), `TransferRuleEditor.tsx` (new), `transferTryIt.ts` (new), `TransferTryItPanel.tsx` (new) | Transfer rules page and Try it |
| `src/state/useBranchData.ts`, `src/state/engineBranches.ts` | Refresh / after-save re-read wiring (`reloadTransfers` exists) |
| `src/ui/nav.ts`, `src/App.tsx` | Routes and nav item |
| `package.json`, `README.md` | 0.6.0, Versions table |
| tests under `src/**/__tests__/` | New and changed cases |

**data-projects**
| File | Change |
|---|---|
| `projects/part order tool - app/for-users/walkthrough.js` (+ .docx) | 0.6.0 section (F14) |
| `projects/part order tool - app/for-users/guide.js` (+ .docx), `REORDER-RULES.md` | Saving transfers, transfer orders, Transfer rules page |
| `projects/part order tool - app/FUTURE-IDEAS.md` | One line: phase 4 (One-Time transfers) is next |
| this plan, the round 2 spec's Progress | Progress notes |

**fabric-workspace-docs** (only if F13 step 3 finds the time zone wrong)
| File | Change |
|---|---|
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_Transfers_Raw.Dataflow/mashup.pq` | `ToUtc` for PlacedAt / Created |

---

## Tasks

### Task F0 (Brian, SharePoint): permissions on the transfer lists

- [ ] **Step 1:** in each of `NonJD_Transfers`, `NonJD_TransferLines` and `NonJD_TransferRules` → List settings → Permissions for this list: confirm "This list inherits permissions from its parent" (Brian said 2026-10-28 they match the others).
- [ ] **Step 2:** decide who may edit transfer rules (Y10). If only Ben and Brian, break inheritance on `NonJD_TransferRules` only and give everyone else Read. Tell Claude the result; F8's read-only view is tested either way.

### Task F1: Data layer, transfer order and transfer rule writes

**Files:** `src/data/types.ts`, `src/data/lists.ts`, `src/data/source.ts`, `src/data/mock/index.ts`, `src/data/mock/fixtures.ts`; tests `src/data/__tests__/lists.test.ts`, `src/data/__tests__/mockSource.test.ts`.

- [ ] **Step 1: types** in `src/data/types.ts`:

```ts
/** NonJD_Transfers Parameters (spec "The lists"). */
export interface TransferParameters {
  dataAsOf: string;
  saveId: string;
  lineCount: number;
  source: 'Reorder' | 'OneTime' | 'Transfers';
  rulesSource: 'snapshot' | 'live';
  transferRules: { id: number; name: string; modified: string | null }[];
}

export interface TransferOrderInput {
  title: string;
  fromBranch: string;
  toBranch: string;
  status: 'Draft';
  exportCount: 0;
  /** JSON.stringify(TransferParameters). */
  parameters: string;
}

export type TransferOrderPatch = Partial<{
  status: TransferStatus; exportCount: number; placedAt: string | null;
}>;

export interface TransferOrderLineInput {
  /** `from|to|franchise|partNumber`. */
  title: string;
  franchise: string;
  /** Raw. */
  partNumber: string;
  kind: TransferKind;
  suggestedQty: number;
  qty: number;
  /** The sender's cost (Y5). */
  cost: number;
  lineValue: number;
  description: string | null;
  fromBin: string | null;
  toBin: string | null;
}

export type TransferOrderLinePatch = Partial<Pick<TransferOrderLineInput, 'qty' | 'lineValue'>>;

export interface TransferOrdersFilter {
  fromBranch?: string | null;
  toBranch?: string | null;
  status?: TransferStatus | null;
}

/** A transfer rule to create (no itemId) or replace. Same fields as TransferRuleRow without the audit columns. */
export type TransferRuleInput = Omit<TransferRuleRow, 'itemId' | 'modified' | 'editor'> & { itemId?: number };
export type TransferRulePatch = Partial<Pick<TransferRuleRow, 'active' | 'archived'>>;
```

  Check `TransferRuleRow`'s audit field names against `ItemAudit` before writing `TransferRuleInput`, and use the real ones.
- [ ] **Step 2: failing tests** in `src/data/__tests__/lists.test.ts`, with `graph.ts` mocked as the existing order tests do:
  - `transferOrderToFields` maps to `Title, FromBranch, ToBranch, Status, ExportCount, Parameters` (create) and only the patched columns (`Status`, `ExportCount`, `PlacedAt`) for an update.
  - `transferOrderLineToFields(transferId, line)` maps to `Title, TransferId, Franchise, PartNumber, Kind, SuggestedQty, Qty, Cost, LineValue, Description, FromBin, ToBin`; the part number is written raw (a trailing space kept).
  - `loadTransferOrders({ fromBranch: '1' })` filters server-side on the indexed `FromBranch` (`fields/FromBranch eq '1'`, quoted through `odataString`); `toBranch` likewise; `status` is filtered in the browser (Status isn't indexed). Newest first by item id.
  - `loadTransferOrder(id)` returns one transfer, `NotFoundError` when missing.
  - `loadTransferOrderLines(transferId)` filters on `fields/TransferId eq <id>`, sorted by item id.
  - `createTransferOrderLines(transferId, lines)` is sequential and throws `CreateOrderLinesError` (existing class) with the ids saved so far when one fails.
  - `transferRuleToFields(rule, forUpdate)` writes every column of `TRANSFER_RULE_FIELDS` (units as "Weeks"/"Months", blanks as null); `patchTransferRule` sends only `Active` / `Archived`.
- [ ] **Step 3:** run `npx vitest run src/data`. Expected: FAIL (functions not defined).
- [ ] **Step 4: implement** in `src/data/lists.ts` with the existing `listItems`, `getItem`, `createItem`, `updateItem` helpers from `graph.ts` and the `TRANSFER_FIELDS` / `TRANSFER_LINE_FIELDS` / `TRANSFER_RULE_FIELDS` constants: `transferOrderToFields`, `transferOrderLineToFields`, `loadTransferOrders`, `loadTransferOrder`, `createTransferOrder`, `updateTransferOrder`, `loadTransferOrderLines`, `createTransferOrderLines`, `updateTransferOrderLine`, `transferRuleToFields`, `saveTransferRule`, `patchTransferRule`. Never a delete function for these lists (Y6).
- [ ] **Step 5: DataSource** (`src/data/source.ts`): add the same names to the interface and `graphSource`; remove the "read-only in phase 2" comment. Mock (`src/data/mock/index.ts`): in-memory writes like `createOrder` / `createOrderLines` (new item ids, `modified`/`editor` stamped), and `loadOpenTransfers` reads the in-memory lists so a mock save counts at once. Tests in `mockSource.test.ts`: create a transfer + 2 lines, `loadOpenTransfers()` then includes them in `committed`; set it Cancelled and they drop out.
- [ ] **Step 6:** run `npm test`, `npm run lint`, `npm run build`. Commit: `Data layer: transfer order and transfer rule writes (Plan F F1)`.

### Task F2: Transfer drafts, saver, status and CSV (pure + saver)

**Files:** new `src/transfers/draft.ts`, `src/transfers/saveTransfers.ts`, `src/transfers/status.ts`; `src/export/csv.ts`; tests `src/transfers/__tests__/draft.test.ts`, `saveTransfers.test.ts`, `status.test.ts`, `src/export/__tests__/csv.test.ts`.

- [ ] **Step 1: failing tests, `draft.test.ts`:**
  - `buildTransferDrafts(ticks)` groups ticked lines (qty > 0) by trimmed From + To: two lines 6→1 (franchises M and BS) and one 13→1 give **two** drafts, 6-1 with both franchises; a ticked line with qty 0 is left out; a draft with no lines isn't made.
  - Draft lines keep the suggestion's raw part number and franchise; `cost` = the sender's cost (`fromCost`), `lineValue` = `lineValue(qty, fromCost)`; `suggestedQty` = the suggestion's qty.
  - `transferTitle('6', '1', new Date('2026-11-03T15:04:00Z'))` = `'6-1-20261103-0904'` (Central, via `centralStamp`).
  - Line title = `'6|1|M|MULTISEAL'`.
  - `transferParameters(draft, ctx, saveId)` = `{ dataAsOf, saveId, lineCount, source, rulesSource, transferRules: [{ id, name, modified }] }` for the rules that picked these parts (live transfer rules; `[]` when only the built-in default applied).
- [ ] **Step 2: implement `src/transfers/draft.ts`:**

```ts
import type { TransferKind, TransferOrderInput, TransferOrderLineInput, TransferParameters } from '@/data/types';
import { centralStamp, lineValue } from '@/orders/draft';

/** One suggestion line as ticked on step 1 (qty is what the person kept, 0..suggestedQty). */
export interface TransferTick {
  key: string;
  kind: TransferKind;
  franchise: string;
  partNumber: string;
  fromBranch: string;
  toBranch: string;
  suggestedQty: number;
  qty: number;
  ticked: boolean;
  fromCost: number;
  description: string | null;
  fromBin: string | null;
  toBin: string | null;
}

export interface TransferDraft {
  fromBranch: string;
  toBranch: string;
  lines: TransferTick[];
}

export interface TransferContext {
  dataAsOf: string;
  source: TransferParameters['source'];
  rulesSource: TransferParameters['rulesSource'];
  transferRules: TransferParameters['transferRules'];
  now: Date;
}

export function transferTitle(from: string, to: string, now: Date): string {
  return `${from.trim()}-${to.trim()}-${centralStamp(now)}`;
}

export function transferLineTitle(t: Pick<TransferTick, 'fromBranch' | 'toBranch' | 'franchise' | 'partNumber'>): string {
  return `${t.fromBranch.trim()}|${t.toBranch.trim()}|${t.franchise}|${t.partNumber}`;
}

/** One draft per trimmed From + To, in branch order of (from, to); only ticked lines with qty > 0. */
export function buildTransferDrafts(ticks: readonly TransferTick[]): TransferDraft[] {
  const byPair = new Map<string, TransferDraft>();
  for (const t of ticks) {
    if (!t.ticked || !(t.qty > 0)) continue;
    const from = t.fromBranch.trim();
    const to = t.toBranch.trim();
    const k = `${from}\u0000${to}`;
    let d = byPair.get(k);
    if (!d) byPair.set(k, (d = { fromBranch: from, toBranch: to, lines: [] }));
    d.lines.push(t);
  }
  return [...byPair.values()];
}

export function transferParameters(d: TransferDraft, ctx: TransferContext, saveId: string): TransferParameters {
  return {
    dataAsOf: ctx.dataAsOf, saveId, lineCount: d.lines.length, source: ctx.source,
    rulesSource: ctx.rulesSource, transferRules: ctx.transferRules,
  };
}

export function toTransferOrderInput(d: TransferDraft, ctx: TransferContext, saveId: string): TransferOrderInput {
  return {
    title: transferTitle(d.fromBranch, d.toBranch, ctx.now), fromBranch: d.fromBranch, toBranch: d.toBranch,
    status: 'Draft', exportCount: 0, parameters: JSON.stringify(transferParameters(d, ctx, saveId)),
  };
}

export function toTransferOrderLineInput(t: TransferTick): TransferOrderLineInput {
  return {
    title: transferLineTitle(t), franchise: t.franchise, partNumber: t.partNumber, kind: t.kind,
    suggestedQty: t.suggestedQty, qty: t.qty, cost: t.fromCost, lineValue: lineValue(t.qty, t.fromCost),
    description: t.description, fromBin: t.fromBin, toBin: t.toBin,
  };
}
```

  Order the drafts with `compareBranchOrder` from `@/engine` (from, then to) instead of insertion order, and test that.
- [ ] **Step 3: failing tests, `status.test.ts`** (mirror `orders/__tests__/status.test.ts`):
  - `canEditTransferLines`: Draft only. `canExportTransfer`: Draft, Exported. `canMarkEntered`: Exported only. `canCancelTransfer`: Draft, Exported.
  - `transferExportPatch({status:'Draft', exportCount:0})` = `{ status:'Exported', exportCount:1 }`; on Placed it throws.
  - `enteredPatch({status:'Exported'}, new Date('2026-11-03T15:04:00Z'))` = `{ status:'Placed', placedAt:'2026-11-03T15:04:00.000Z' }`; on Draft it throws "Export the transfer first: the CSV is the record of what was keyed into Equip."
  - `cancelPatch({status:'Exported'})` = `{ status:'Cancelled' }`; on Placed it throws.
  - `transferStatusLabel('Placed')` = "Entered in Equip"; other statuses as is; null → "Unknown".
  - `isOldDraft({status:'Draft', created:'2026-10-20T15:00:00Z'}, now 2026-10-28)` = true (> 7 days, A23); Exported never.
- [ ] **Step 4:** implement `src/transfers/status.ts` to pass them.
- [ ] **Step 5: failing tests, `saveTransfers.test.ts`** (port `orders/__tests__/saveOrders.test.ts`'s cases to transfers, against the mock source with failure injection):
  - two drafts save in order: header then lines; `progress` reports per draft; outcome `{ ok:true, transferIds:[…] }`.
  - a line create that fails with 500 → run() again re-reads that transfer's lines and creates only the missing ones; lines are matched on franchise + part number, so `M|MULTISEAL` and `BS|MULTISEAL` on one transfer both save once.
  - a header create that fails ambiguously → the next run looks it up by FromBranch (indexed) and matches title + `Parameters.saveId` before creating; another user's transfer with the same title is not adopted.
  - a 429/503 or AuthRequiredError is not "may have been saved".
  - double click shares one run; nothing is ever deleted (no delete method is called).
- [ ] **Step 6:** implement `TransferSaver` in `src/transfers/saveTransfers.ts` following `orders/saveOrders.ts` step by step (Y4); import `mayHaveBeenSaved`, `rootError`, `newSaveId` from there. Its matcher:

```ts
export function matchExistingTransferLines(
  lines: readonly TransferTick[], known: ReadonlyMap<string, number>, existing: readonly AppTransferLine[],
): Map<string, number> {
  const result = new Map(known);
  const claimed = new Set(known.values());
  const pool = existing.filter((l) => l.partNumber != null && !claimed.has(l.itemId));
  const take = (franchise: string, pred: (pn: string) => boolean) => {
    const i = pool.findIndex((l) => l.franchise === franchise && pred(l.partNumber as string));
    return i < 0 ? null : pool.splice(i, 1)[0];
  };
  const open = lines.filter((l) => !result.has(l.key));
  for (const l of open) {
    const hit = take(l.franchise, (pn) => pn === l.partNumber);
    if (hit) result.set(l.key, hit.itemId);
  }
  for (const l of open) {
    if (result.has(l.key)) continue;
    const want = l.partNumber.replace(/\s+$/, '');
    const hit = take(l.franchise, (pn) => pn.replace(/\s+$/, '') === want);
    if (hit) result.set(l.key, hit.itemId);
  }
  return result;
}
```

- [ ] **Step 7: CSV.** Failing test in `src/export/__tests__/csv.test.ts`: `transferOrderCsv(lines)` writes header `PartNumber,Franchise,Description,Qty,FromBin,ToBin,Cost,LineValue`, skips Qty 0 lines (Y6), keeps leading zeros and neutralises formulas with the existing `textCell` / `quoteField`. Implement `TRANSFER_ORDER_CSV_HEADER` and `transferOrderCsv` next to `orderCsv`; `csvBlob` adds the BOM as for orders.
- [ ] **Step 8:** run `npm test`, `npm run lint`, `npm run build`. Commit: `Transfer drafts, saver, status rules and CSV (Plan F F2)`.

### Task F3: Ticks, preview and the stale check (pure)

**Files:** new `src/transfers/ticks.ts`; test `src/transfers/__tests__/ticks.test.ts`.

- [ ] **Step 1: failing tests:**
  - `tickKey(line)` = kind + from + to + franchise + part (raw), stable across runs.
  - `defaultTicks(lines, facts)` makes one `TransferTick` per suggestion line, ticked, qty = suggested; description and bins from `facts` (the `FactsLookup` of `pages/transfers/transferRows.ts`).
  - `mergeTicks(previous, fresh)` keeps a person's untick and lowered qty for lines still suggested (qty clamped to the fresh suggested qty), adds new lines ticked, drops lines no longer suggested.
  - `tickedIntoByPart(ticks)` sums ticked qty per `committedKey(toBranch, franchise, partNumber)` (from `engine/committed.ts`), conventional and redistribution together.
  - `previewInputs(inputs, tickedInto)` returns a copy with `appInboundQty` raised by the ticked qty; the original isn't mutated. With `computePart` from `@/engine` (as `state/branchRows.ts` calls it), BS-XFER-1 at branch 1 (mock: target 3, oh 0, 2 committed) with a ticked 1 → order 0; unticked → order 1 (Ben's T2: unticking puts the order back).
  - `staleTicks(ticks, freshLines)` (Y3): returns `{ changed: [{ key, was, now }], ticks }`. A ticked line whose fresh qty dropped from 44 to 20 is clamped to 20 and listed; a line gone from the fresh run is dropped and listed with `now: 0`; an unticked line never counts as stale; no change → `changed` empty and the same tick values.
  - `isEdited(ticks, defaults)` is true only after an untick or a qty change (Y7).
- [ ] **Step 2:** run `npx vitest run src/transfers`. Expected: FAIL.
- [ ] **Step 3:** implement `src/transfers/ticks.ts` to pass them. No React here.
- [ ] **Step 4:** run `npm test`, lint, build. Commit: `Transfer ticks, preview and stale check (Plan F F3)`.

### Task F4: The shared transfer step (`TransferStep`)

**Files:** new `src/pages/transfers/TransferStep.tsx`; test `src/pages/transfers/__tests__/TransferStep.test.tsx`.

Props (controlled by the page):

```ts
export interface TransferStepProps {
  /** Suggestion lines to show (already filtered to the page's branches when it has any). */
  lines: readonly SuggestionLine[];
  facts: FactsLookup;
  /** 'morning' until every branch has loaded (read-only, Y1), then 'live'. */
  mode: 'morning' | 'live';
  ticks: readonly TransferTick[];
  onTicksChange: (ticks: TransferTick[]) => void;
  /** Receiver order before → after the ticks, per suggestion key (Part 4 preview); absent on the Transfers page. */
  preview?: ReadonlyMap<string, { before: number; after: number }>;
  /** Saved transfers into / out of the shown branches (Draft, Exported, Placed today), newest first. */
  saved: readonly Transfer[];
  onSave: () => void;
  onRefresh: () => void;
  saving: SaveProgress | null;
  /** Y3's result after a failed pre-save check. */
  staleChanges: readonly StaleChange[] | null;
  canSave: boolean;
}
```

- [ ] **Step 1: failing tests** (mock data: BS-XFER-1 conventional 1 and redistribution 9 from 92 into 1; BS-XFER-2 conventional 6 and redistribution 18 from 1 into 92):
  - Every line has a checkbox (ticked), a kind badge (purple, as 0.5.0), and a qty input; typing 12 when 9 is suggested shows "At most 9" and keeps 9; 0 is allowed.
  - A **Franchise** filter at the top (Ben A13) and a **Kind** filter; filtering never changes ticks on hidden lines; the footer says "N of M ticked shown".
  - Footer: "N transfers cover M order lines and $X you won't buy" (conventional, receivers' cost) plus "R redistribution lines, $Y" — reuse `transferSummary` / `transferFooter` from `transferRows.ts` over the ticked lines.
  - With `preview`, an **Order** column shows "1 → 0" for BS-XFER-1 at 1, and unticking shows "1 → 1".
  - `mode='morning'`: checkboxes and qty disabled, the Save button disabled with "Loading every branch… you can save once it finishes", and a muted "as of this morning" label.
  - **Save transfers** shows the count ("Save 3 transfers (2 transfer orders)") and calls `onSave`; while saving, a progress line per transfer order ("6 → 1: 2 of 3 lines"), and on failure the saver's error with **Retry** (calls `onSave` again) or **Sign in again**.
  - **Refresh** button calls `onRefresh`; with `staleChanges`, an amber banner lists "MULTISEAL from 6: 44 → 20 (someone saved a transfer)" and "Save again to save the rest".
  - The **Saved** section lists `saved` transfers ("6 → 1 · 2 lines · Draft · saved 10:42 by Shannon Brooks") with links to `transferOrderPath(id)` and the "Entered in Equip" label for Placed.
- [ ] **Step 2:** run the test. Expected: FAIL. Implement with the existing `Table`, `Pill` (tone `xfer`), `Button`, `Banner` (tone `xfer` / `warn`), `Toggle` components; testids `transfer-step`, `transfer-line`, `transfer-qty`, `transfer-save`, `transfer-refresh`, `transfer-saved`, `transfer-stale`.
- [ ] **Step 3:** run `npm test`, lint, build. Commit: `TransferStep: tick, edit, preview and save suggested transfers (Plan F F4)`.

### Task F5: Recommended Reorder, the stepper

**Files:** `src/pages/ReorderPage.tsx`, new `src/pages/reorder/Stepper.tsx`, `src/pages/reorder/RowDetail.tsx`, `src/pages/reorder/transferHints.ts`, `src/pages/HomePage.tsx`, new `src/pages/transfers/paths.ts`; tests `src/pages/__tests__/reorderTransferStep.test.tsx`, `src/pages/__tests__/transfersStandOut.test.tsx` (update), `src/pages/reorder/__tests__/transferHints.test.ts` (update).

- [ ] **Step 1: paths.** `src/pages/transfers/paths.ts`:

```ts
export function transferOrderPath(transferId: number): string {
  return `/transfers/orders/${transferId}`;
}

export function transferOrdersPath(f: { from?: string | null; to?: string | null; status?: string | null } = {}): string {
  const p = new URLSearchParams({ tab: 'orders' });
  if (f.from) p.set('from', f.from);
  if (f.to) p.set('to', f.to);
  if (f.status) p.set('status', f.status);
  return `/transfers?${p.toString()}`;
}

export function reorderTransfersPath(branch: string): string {
  return `/reorder?branches=${encodeURIComponent(branch)}&step=transfers`;
}
```

  Home's transfers card "Review transfers" uses `reorderTransfersPath(branch)` when the branch has suggestions into it (else `/transfers`); update `transferHints.test.ts` / the Home test.
- [ ] **Step 2: failing tests**, `reorderTransfersStep.test.tsx` (mock source):
  - Branch 1 opens on **1 Transfers** (stepper shows "1 Transfers → 2 Order", step 1 current) because the morning file has suggestions into 1; `?step=order` opens step 2 directly; a branch with none opens step 2 and step 1 reads "No transfers suggested into branch X".
  - Step 1 starts the all-branch load (progress shown) only in the first case (Y2: a branch with no morning suggestion loads nothing extra — assert the mock source's `loadReorder` call count).
  - Until loaded: morning lines, read-only (Y1). After: live lines from `useAllBranchTransfers`, filtered to `toBranch` in the selected branches, ticks from `defaultTicks`.
  - Unticking BS-XFER-1's conventional line previews its order 0 → 1 in step 1; step 2 still shows the order computed from **saved** transfers only (Part 4 / B1).
  - **Continue to order** with ticks unsaved asks "Save the 2 ticked transfers first?" (into branch 1: BS-XFER-1 conventional 1 and redistribution 9 from 92) with **Save and continue** / **Continue without them**; the first saves (mock) then shows step 2 with BS-XFER-1 at order 0 and "Transfer in: 1 from branch 92" (plus the earlier 2), the second goes to step 2 unchanged.
  - **Save transfers**: B2's flow — re-read (`reloadTransfers`), recompute, `staleTicks`; with no change it saves; the mock then has one Draft 92 → 1 with the ticked lines, the step shows it under **Saved**, and the suggestions recompute (BS-XFER-1 conventional gone, because its need is now covered).
  - Stale path: the test adds a Draft line 92 → 95 for BS-XFER-1 qty 20 to the mock **after** the page loaded; Save → 92's free excess drops from 26 to 6, so after the conventional 1 only 5 are left: banner "BS-XFER-1 from 92 (Redistribution): 9 → 5", the tick is clamped to 5, and nothing is saved until Save again.
  - Leaving step 1 after an untick asks (LeaveTicksGuard wording "Leave this page? Your transfer changes will be lost."); leaving with default ticks doesn't (Y7).
  - The purple row pill on step 2 uses the live lines once loaded (ticks don't change it).
- [ ] **Step 3:** run them. Expected: FAIL.
- [ ] **Step 4: implement.**
  - `Stepper.tsx`: two buttons with `aria-current="step"`; clicking step 2 from step 1 is the same as **Continue to order**.
  - `ReorderPage.tsx`: `step` in the URL (`step=transfers|order`, default as above). Step 1 renders `TransferStep` with `lines` = live (or morning) suggestions into the selected branches, `preview` from `previewInputs` + `computePart` for the receiving rows only, `saved` from `useBranchData().committed`'s transfers into those branches. Save builds drafts (`buildTransferDrafts`), context (`dataAsOf` from _meta, `source:'Reorder'`, `rulesSource` live/snapshot like orders, the picked transfer rules from the live run), runs `TransferSaver`, then `reloadTransfers()`.
  - `RowDetail.tsx`: the existing "Transfers saved in this app" list stays; the order explanation already says "N coming by transfer from branch X (saved …)".
- [ ] **Step 5:** run `npm test`, lint, build. Commit: `Recommended Reorder: Transfers then Order stepper, save transfers (Plan F F5)`.

### Task F6: Transfers page, ticking and the Transfer orders tab

**Files:** `src/pages/TransfersPage.tsx`, new `src/pages/transfers/TransferOrdersList.tsx`, `src/pages/transfers/transferRows.ts`; tests `src/pages/__tests__/TransfersPage.test.tsx` (update), new `src/pages/transfers/__tests__/TransferOrdersList.test.tsx`.

- [ ] **Step 1: failing tests:**
  - The page has two tabs, **Suggestions** and **Transfer orders** (`?tab=orders`).
  - Suggestions uses `TransferStep` for every branch (all From / To), with the existing Kind / From / To / Franchise filters and a new **Status** filter: Suggested (not yet saved) / Saved (the saved lines today, from the live committed lines). Shannon can filter From = 92 and save just those (redistribution by sender).
  - The muted "Saving transfers comes in the next version…" line is gone (wording test).
  - Refresh and the pre-save check behave as on Reorder (B2); `source:'Transfers'` in Parameters.
  - Export CSV of suggestions still works and still uses `TRANSFERS_CSV_HEADER`.
  - **Transfer orders tab:** rows newest first: Title, From, To, Status label (Placed → "Entered in Equip"), lines, value (sender's cost), exported count, created by / when. Filters From, To, Status in the URL (`transferOrdersPath`). A Draft older than 7 days has an amber "Draft for 9 days" pill (A23) and the tab label counts them ("Transfer orders (2 old drafts)"). Each row links to `transferOrderPath(id)`. A Refresh button re-reads.
- [ ] **Step 2:** run them. Expected: FAIL. Implement; the list reads `loadTransferOrders(filter)` and each transfer's line count/value from `loadTransferOrderLines` lazily (4 at a time, as `loadOpenTransfers` does), or from the open transfers already loaded when the filter is Draft/Exported.
- [ ] **Step 3:** run `npm test`, lint, build. Commit: `Transfers page: tick and save, Transfer orders tab (Plan F F6)`.

### Task F7: The transfer order page

**Files:** new `src/pages/TransferOrderPage.tsx`, `src/App.tsx` (route `transfers/orders/:transferId`), `src/ui/nav.ts` (breadcrumb Home › Transfers › title); test `src/pages/__tests__/TransferOrderPage.test.tsx`.

- [ ] **Step 1: failing tests** (mock: a Draft 92 → 1 with BS-XFER-1 qty 2):
  - Header: "92 → 1", title, status pill (label from `transferStatusLabel`), saved by / when, Parameters summary ("From Recommended Reorder · data as of Oct 21, 6:41 AM · rules: built-in default"); a warning when fewer lines were read than `Parameters.lineCount` ("This transfer has 1 of 2 lines; the save may not have finished").
  - Lines: part (link to the Part page at the **receiving** branch), franchise, description, kind badge, From bin, To bin, suggested qty, qty, cost (sender's, Y5), value.
  - **Draft:** qty editable 0..99999 (`parseQty`), saved on blur with `updateTransferOrderLine` (`qty`, `lineValue`); 0 shows "Not sent" (Y6). Exported / Placed / Cancelled: read-only with the reason ("Exported: start a new transfer to change it", as orders).
  - **Export CSV** downloads `transferOrderCsv` named from the title (`csvFilename`), then patches `transferExportPatch`; a failed patch shows "Downloaded, but the export wasn't recorded" with Retry.
  - **Mark entered in Equip** (enabled only when Exported, tooltip otherwise "Export it first…") patches `enteredPatch(now)`.
  - **Cancel transfer** (Draft, Exported) asks "Cancel this transfer? Its stock is released for other suggestions." then patches `cancelPatch`; nothing is deleted.
  - Not found → the not-found card; 403 → "You don't have permission to change transfers."; AuthRequired → Sign in again.
- [ ] **Step 2:** run. Expected: FAIL. Implement following `OrderPage.tsx` (same layout, `Card`, `Banner`, `Button`; `csvExport` submitter pattern for the download).
- [ ] **Step 3:** run `npm test`, lint, build. Commit: `Transfer order page: edit, export, entered in Equip, cancel (Plan F F7)`.

### Task F8: Transfer rules page

**Files:** new `src/pages/TransferRulesPage.tsx`, `src/pages/transferRules/transferRuleForm.ts`, `src/pages/transferRules/TransferRuleEditor.tsx`; `src/ui/nav.ts` (item "Transfer rules" after Rules, icon `transfer`), `src/App.tsx` (route `transfer-rules`); tests `src/pages/__tests__/TransferRulesPage.test.tsx`, `src/pages/transferRules/__tests__/transferRuleForm.test.ts`.

- [ ] **Step 1: failing tests, `transferRuleForm.test.ts`** (mirror `rules/__tests__/ruleForm.test.ts`):
  - `formFromTransferRule(row)` / `transferFormToInput(form)` round-trip every field: name, priority, active, the eight criteria + Branch, StartMonth/EndMonth, ExcessSupply + ExcessUnit, AllowSend, AllowReceive, RedistMax + RedistUnit, RedistMinValue, Notes.
  - `transferFormProblems(form)` returns exactly the engine's `transferRuleProblems` messages for the draft (e.g. ExcessSupply 99 Months → "ExcessSupply must be 0-60 months"; RedistMinValue -1 → "RedistMinValue must be 0 or more"; blank Priority → "Priority is missing").
  - `NEW_TRANSFER_RULE_FORM` = Active, Priority blank, ExcessSupply 12 Months, AllowSend / AllowReceive Yes, RedistMax 6 Months, RedistMinValue 0.
  - `transferRuleChanges(before, after)` lists changed fields for the confirmation line, as `ruleChanges` does.
- [ ] **Step 2: failing tests, `TransferRulesPage.test.tsx`:**
  - Lists every rule (`loadTransferRules`) with state pills (Active / Off / Archived / Invalid with its messages / Out of season), criteria text, excess ("12 months"), send/receive, redistribution ("up to 6 months, no minimum"); Show archived toggle; the **built-in default** as a read-only first row ("Built-in default: excess above 12 months, receive up to 6 months, no minimum for redistribution").
  - The pick-order sentence above the list: "Rules are picked like order rules: highest priority, then most criteria, then lowest number. The sending branch's rule decides what counts as excess and whether it may send; the receiving branch's rule decides whether it takes transfers and how much redistribution."
  - Edit / New rule opens `TransferRuleEditor`; Save calls `saveTransferRule` and re-reads; Archive / Unarchive and Switch on / off use `patchTransferRule`; unsaved edits ask before leaving (the Rules page's `useBlocker` + Discard pattern); a 403 shows `NO_PERMISSION`-style "You don't have permission to change transfer rules." and the page stays read-only.
  - A save note: "Applies immediately in this app; the morning run uses it tomorrow."
- [ ] **Step 3:** run. Expected: FAIL. Implement by following `RulesPage.tsx` / `RuleEditor.tsx` / `ruleForm.ts` (copy the structure, not the order-rule fields). Remove the Transfers page's "Transfer rules in use" section's "edit in SharePoint" wording and link it to `/transfer-rules`.
- [ ] **Step 4:** run `npm test`, lint, build. Commit: `Transfer rules page: list, editor, archive (Plan F F8)`.

### Task F9: Transfer rules Try it

**Files:** new `src/pages/transferRules/transferTryIt.ts`, `src/pages/transferRules/TransferTryItPanel.tsx`; `src/pages/TransferRulesPage.tsx`; tests `src/pages/transferRules/__tests__/transferTryIt.test.ts`, `src/pages/__tests__/TransferRulesPage.test.tsx` (add).

- [ ] **Step 1: failing tests, `transferTryIt.test.ts`:**
  - `transferRulesWithDraft(rules, draft)` replaces the edited rule (or appends the new one) for the run only.
  - `summariseTransfers(lines)` = `{ convLines, convValue, redistLines, redistValue }` (values at the receivers' cost, Y11).
  - `changedTransferParts(before, after, 20)` lists groups (franchise + part) whose total suggested value changed, largest |Δ| first, with before/after qty and value per kind; ties by franchise then part.
- [ ] **Step 2: failing UI test:** with the mock, a draft "AllowSend No at branch 92" makes Try it show conventional lines 2 → 1 and $ 38.00 → 13.50 ("Order $ avoided"), redistribution 2 → 1, and BS-XFER-1 in the changed list; Try it shows the all-branch progress until loaded and "Fix the rule's problems to try it" while invalid.
- [ ] **Step 3:** run. Expected: FAIL. Implement: the page loads every branch with `useEngineBranches` (all published branches) and computes the after-run with `memoAllBranchTransfers(computed, { ...shared, liveTransferRules: draftRules })` (debounced as Rules' Try it is); before = the live run.
- [ ] **Step 4:** run `npm test`, lint, build. Commit: `Transfer rules Try it (Plan F F9)`.

### Task F10: Parity and re-run after saves

**Files:** `src/state/engineBranches.ts`, `src/state/useBranchData.ts` (if needed), `src/engine/transferParity.ts` (if needed); tests `src/state/__tests__/engineBranchesTransfers.test.ts`, `src/engine/__tests__/transferParity.test.ts`.

- [ ] **Step 1: failing tests:**
  - With live committed lines equal to the file's `committed`, every group is **checked** and matches Gold (existing behaviour, keep green).
  - After a mock save today (a Draft line 92 → 1 BS-XFER-1), `reloadTransfers()` changes `shared.committed`; the all-branch run re-runs once (memo key changes), the group BS|BS-XFER-1 is **Changed** (reason "committed transfers changed"), never a mismatch, and other groups stay checked.
  - A tick never re-runs the allocation (assert `runTransfers` call count unchanged across 5 tick changes).
  - Cancelled transfers drop out of committed on the next re-read and the group returns to checked when it again equals the file.
- [ ] **Step 2:** run. Fix whatever fails (expected: little or nothing, since E9 built the parity on committed changes).
- [ ] **Step 3: timing.** With the Dev v3 build (`run_publish.py --out <scratchpad>/v3f`), add to `scripts/parity-full.ts` an optional `--committed <json>` that injects extra committed lines; run it once with 50 synthetic Draft lines and record the re-run time (expect under 300 ms after load) and 0 mismatches outside the touched groups. Record in Progress.
- [ ] **Step 4:** run `npm test`, lint, build. Commit: `Transfers: parity and re-run after saves (Plan F F10)`.

### Task F11: Mock-mode click-through (Claude), then Brian's list

- [ ] **Step 1 (Claude):** `npm run dev` (mock). Go through: Home card → Reorder step 1 (tick, untick, qty, preview, Save, stale banner by editing the mock in the console as the test does, Continue question) → step 2 ("Transfer in") → Transfers page (both tabs, filters, Save by sender) → transfer order page (edit, export, entered, cancel) → Transfer rules (new, invalid, archive, Try it). Fix anything broken with a test first; commit.
- [ ] **Step 2:** write Brian's 15-step mock click-through list into the hand-off message (what to click, what to see), the same style as the 0.5.0 list.

### Task F12: App 0.6.0 and review

- [ ] **Step 1:** `package.json` `"version": "0.6.0"`; README Versions row: "0.6.0: round 2 phase 3: tick and save transfers (Reorder step 1, Transfers page), transfer orders (export, entered in Equip, cancel), Transfer rules page with Try it".
- [ ] **Step 2:** `npm test`, `npm run lint`, `npm run build`, then the dist check (scratchpad `check_dist.sh`: all six list IDs, no mock strings).
- [ ] **Step 3:** code review (`typescript-reviewer`) of everything since `88c7d59`, focused on the saver's recovery, the stale check, and the stepper's state. Fix findings, re-run step 2.
- [ ] **Step 4:** commit and push dev.

### Task F13 (Brian + Claude): Fedora deploy and end-to-end on real lists

The lists are shared by Dev and Prod and 0.6.0 writes to them for real. Test rows are named TEST, saved after 10:15 (after the Gateway publish window) and **Cancelled the same day**, so Prod's 06:15 Gold never counts them (Cancelled never counts). Deleting them afterwards needs Brian's OK.

- [ ] **Step 1 (Brian):** deploy 0.6.0 to Fedora (`docs/FEDORA-TEST-DEPLOYMENT.md`); About shows 0.6.0.
- [ ] **Step 2 (Brian, approved writes):** on branch 1, step 1, untick everything except one small conventional line (Claude names it from Prod Gold that morning), save it. Note the time. Then on its transfer order page: Export CSV, Mark entered in Equip. Note that time too.
- [ ] **Step 3 (Claude): time zone check** (Plan E open item). Read the header through Graph (PlacedAt, Created as UTC). Run the Dev pipeline `mode=items`, `items=df_NonJD_Transfers_Raw` (Brian in the UI if the permission check blocks it), then read Dev `NonJD_Transfers` with DuckDB. **Expected:** PlacedAt and Created equal Graph's UTC values to the minute. If they are off by whole hours, fix `ToUtc` in `df_NonJD_Transfers_Raw` (fabric-workspace-docs dev; test on Dev; it then needs a backend PR like #45) and record it; otherwise record "confirmed".
- [ ] **Step 4 (Claude):** run Dev Gold `mode=items` (`Build_Gold_NonJD_Reorder`), then `nonjd_reorder_check.py --tier dev`. **Expected PASS**, with the TEST line's receiver showing AppInboundQty = the qty and its sender AppOutboundQty = the qty. (Placed today: it counts until the next build date, A14.)
- [ ] **Step 5 (Brian):** a second TEST transfer: save, then **Cancel** it; Claude confirms it drops out of committed in the app after Refresh.
- [ ] **Step 6:** the first TEST transfer is Placed, so it can't be cancelled (Y9), and it doesn't need to be: a Placed line counts only while the Central date of PlacedAt is on or after the build date (A14), so tomorrow's 06:15 Gold drops it. Until then it lowers one small line in today's live app, which is why step 2 picks a small one. After step 7, Brian OKs deleting both TEST headers and their lines; Claude deletes by the recorded ids only.
- [ ] **Step 7:** next morning, `/check-refresh prod` and the reference check on Prod pass with no TEST lines counted.

### Task F14: Documents (batched; users don't get them yet)

**Files:** `projects/part order tool - app/for-users/walkthrough.js`, `guide.js` (+ regenerated .docx), `REORDER-RULES.md`, `FUTURE-IDEAS.md`.

- [ ] **Step 1:** walkthrough "New since 0.5.0" + a 0.6.0 section in the same table format: Reorder step 1 (tick, untick, qty, preview, Save, Saved, Refresh), the Continue question, step 2's "Transfer in", the Transfers page by sender, Transfer orders tab and old-draft flag, transfer order page (export, entered, cancel), Transfer rules (new rule, invalid rule message, Try it). Example parts from Prod Gold on the day (MULTISEAL at 1 if it still has "Transfer 44 from 6"). Tell testers to cancel anything they save while testing.
- [ ] **Step 2:** guide: replace "key them into Equip by hand for now" everywhere with the saving flow; new sections "Saving transfers", "Transfer orders", "Transfer rules". REORDER-RULES: "Saved transfers" (Draft/Exported/Entered count straight away, Cancelled never; A14) and the Transfer rules page.
- [ ] **Step 3:** FUTURE-IDEAS: one line under the intro: "Next on the round 2 plan: phase 4, One-Time Order transfers (conventional only, A21)." Nothing else changes there.
- [ ] **Step 4:** regenerate the .docx files (check the User Guide working copy for Brian's own edits first, as in E17), commit named files only.

### Task F15: Progress

- [ ] **Step 1:** update this plan's Progress, the round 2 spec's Progress (phase 3 done), the app README, and the memory note `project_nonjd_parts_order_tool_paused.md` (0.6.0 live; next phase 4).

---

## Self-review against the spec

- **Phase 3 row:**
  - live allocation in Reorder: F5 (Y2 background load);
  - ticking and preview: F3 (pure), F4 (UI), F5 (Reorder);
  - saving transfer orders: F1 (writes), F2 (drafts, saver), F4–F6;
  - transfer order pages: F6 (list), F7 (page: export, entered in Equip, cancel);
  - Transfer rules page with Try it: F8, F9;
  - Home line: built in 0.5.0; F5 step 1 points it at step 1 (Y8).
- **Part 4:** preview recomputes only the receiver (F3 `previewInputs`, F5 test); no re-allocation on ticks (F10 test); saved lines become committed and everything re-runs after the re-read (F5, F10); the sender's order never changes (A17: covered by the engine; F5's save test checks the sender's order is unchanged).
- **The lists:** titles, Parameters JSON, statuses (F1, F2); never delete (Y6, F2 tests); indexed filters (F1).
- **The UI, Reorder:** stepper, step 1 open first / "No transfers suggested", both kinds ticked, kind badge, franchise filter, qty 0..suggested, columns, footer, Save, Continue question, step 2 "Transfer in" (F4, F5). Row detail Transfers section: 0.5.0's box (kept).
- **The UI, Transfers page:** Suggestions with status filter, tick + save, CSV (F6); Transfer orders list with filters and old-draft flag (F6, A23); transfer order page with the spec's CSV columns (F2, F7).
- **Freshness (B2):** re-read on open, after save, Refresh, pre-save check (F4, F5, F6); no polling.
- **Parity:** unchanged groups still match Gold; touched groups are Changed (F10).
- **Not in this plan:** One-Time transfers (phase 4, A21), the "Round 2 changes" doc (phase 4), drafts expiring (A23 says flag only).
- **Placeholder scan:** done; every task names its files, tests and expected results. UI tasks give behaviour, wording and testids rather than full component code, matching Plan E; pure modules (F2, F3) give code.
- **Type consistency:** `TransferTick` (F2) is used by F3–F6; `transferOrderPath` / `transferOrdersPath` / `reorderTransfersPath` (F5) by F4, F6, F7 and Home; DataSource names from F1 (`loadTransferOrders`, `loadTransferOrder`, `createTransferOrder`, `updateTransferOrder`, `loadTransferOrderLines`, `createTransferOrderLines`, `updateTransferOrderLine`, `saveTransferRule`, `patchTransferRule`) are the ones F2 and F6–F9 call.
