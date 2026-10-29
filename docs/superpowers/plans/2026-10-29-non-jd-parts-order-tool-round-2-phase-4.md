# Non-JD Parts Order Tool: round 2 phase 4: One-Time Order transfers (Plan G, app 0.7.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-10-29 (Claude, for Brian). Waiting on Brian's read of the decisions below.
> - **G7 steps 1–2 done 2026-10-29.** Brian deployed 0.7.0 to Fedora. TEST: One-Time Order "TEST 0.7.0", branch 1, saved ET-3912-J (MM) 1 from 3 → 1, $32.00, 15:00 Central (item 4, `3-1-20261029-1500`), then cancelled; Graph: Status Cancelled, Parameters `source: "One-Time"`, `orderName: "TEST 0.7.0"`. **Left:** step 3, Brian's OK to delete items 2, 3 and 4 (with today's two Plan F TESTs) after tomorrow's Prod check; G8 documents; G9 progress.
> - **G5 and G6 done 2026-10-29.** G5: `src/__tests__/clickThrough070.test.tsx` (app `27d2856`) walks the whole One-Time transfer flow through the real routes; Brian's 14-step list `for-users/0.7.0-click-through.md`: **no issues** (Brian). Review (typescript-reviewer, `0bec57a..d788c1c`): no high; fixed in `84141a6` (1,811 tests): a receiver's AllowReceive = false now receives nothing; a save waiting for Retry asks (UNFINISHED_SAVE_TEXT) before a setup change and "Leave it" drops it (resetKey counter); with a strategy, runWith no longer reruns on branch ticks, and oneTimeTransferLines indexes only receiver groups; a parts/sources alignment guard; step 2 search box. **Brian's call:** a line fully covered by saved transfers stays on Review (0, "Covered by transfers", never ordered), as Reorder. G6: app `ff52dc3` 0.7.0, lint clean, `dist/` = 0.7.0 (`index-FIN2Rzc7.js`, list and site IDs present, no mock strings). Next: G7 (Brian deploys; one real TEST).
> - **G3/G4 done 2026-10-29** (app `d788c1c`; 1,796 tests, lint, tsc clean). Stepper Set up → Transfers → Review; "Continue to transfers" starts the all-branch load (G5); step 2 = TransferStep with the Order before → after preview (computeOneTime with the ticked qty in); Save first? (Stay / Continue without them / Save and continue); skip to Review with "No transfers suggested for this order." only once loaded (or at once when nothing is listed); receivers frozen at Next, a changed setup after an edit asks "Your transfer changes will be lost."; Review's "Transfer in" column + "Includes N coming by transfer from branch X" (tooltip "Transfers saved in this app, taken off the quantity": One-Time doesn't subtract Equip transfers); Parameters source One-Time + orderName, `From One-Time Order "<name>"`. **Deviation (correctness):** receivers store gross need (baseQty + appInboundQty) and the strategy subtracts the current appInboundQty, so a save's re-check never re-suggests saved stock. **Open:** a line fully covered by saved transfers drops off Review (qty 0); the One-Time stepper isn't clickable; factor/minimum changes made on Review reach step 2 only at the next Next.
> - **G2 done 2026-10-29** (app `a9d8f49`; 1,789 tests: the 1,785 existing unchanged + 4; lint, tsc clean). `useReorderTransfers` option `lines: TransferLinesStrategy` gets `{ computed, run, sources, transferRun }` (sources and transferRun.parts line up, for `oneTimeTransferLines`) and returns `{ lines, facts }` (`runFacts` exported for the default facts); used inside `runWith`, so the shown lines, default ticks, stale check, ticksAfterSave and Refresh all use it; a new strategy identity recomputes and merges ticks. With a strategy: no morning lines, every branch loads, mode 'morning' (nothing to tick) until all loaded. `TransferParameters.source` adds 'One-Time'; optional `orderName`. Reviewed by Claude (diff): default path unchanged.
> - **G1 done 2026-10-29** (app `7dde8e2`; engine 595 tests, lint and tsc clean; dist untouched). `src/engine/oneTimeTransfers.ts`: receivers with need > 0 summed per branch + part (branch trimmed and upper-cased, as committedKey); rows rebuilt with `allocationRow` from every source in a receiver's group; receivers `convNeed = need, freeExcess 0` (G3), senders keep FreeExcess; every row `redistEligible: false`; `allocateAll` sorts. A receiver without a source row is skipped (guard). Reviewed by Claude: no changes.
> - **Starting point:** app 0.6.2 (`0bec57a`) live on Fedora on Prod data. Phase 3 (Plan F) is done: transfers are ticked and saved on Recommended Reorder step 1 and the Transfers page, transfer orders are exported / entered in Equip / cancelled, and Ben edits transfer rules. One-Time Order already subtracts saved transfers in (`AppInboundQty`, spec "One-Time Order with transfers", first bullet); what it lacks is suggesting them.
> - **Asked by Ben (2026-10-29, through Brian):** "do the transfers apply to the One-Time Orders as well?"

**Goal:** One-Time Order suggests conventional transfers from other branches' excess before the order is reviewed, so a one-time buy is filled from stock the company already has where it can, with the same tick / save / "Save first?" flow as Recommended Reorder.

**Architecture:** app-only. Gold, the reference, the publish and the contract don't change (spec: "live-only, like the rest of One-Time: there is no Gold version and no parity check"). The engine's existing `allocateGroup` does the work: the one-time lines are the receivers (ConvNeed = the one-time quantity before the line value limits), the live all-branch run's FreeExcess are the senders, and redistribution is switched off (every row `redistEligible: false`). The phase 3 transfer hook (`useReorderTransfers`) is generalised to take the lines from a strategy, so One-Time reuses ticks, the stale check, the saver, the lag overlay and the re-reads unchanged.

**Tech stack:** React + TypeScript + Vite + Tailwind, Vitest + Testing Library, Microsoft Graph (SharePoint lists) through `src/data/graph.ts`, mock source for tests and `npm run dev`.

**Spec:** `docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md`: A21, "One-Time Order with transfers", "The UI" → One-Time Order, "Phasing" row 4.

---

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| G1 | **The wizard becomes "1 Set up → 2 Transfers → 3 Review".** The Transfers step is skipped (straight to Review, with a one-line note "No transfers suggested for this order") when nothing can come by transfer. | Spec. Same shape as Reorder's stepper. |
| G2 | **Conventional only** (A21). Receivers: the listed one-time lines at the ticked branches, need = `baseQty` (the one-time quantity before the min / max line value limits), masked and Manual order parts left out as today. Senders: every branch's **FreeExcess** from the live run (Part 2), so the sender's own rules decide what it can spare and committed transfers out are already off. | Spec. A one-time buy is a single purchase; redistribution belongs with the daily order. |
| G3 | **A branch that is receiving the part in this order never sends it** (its row has FreeExcess 0 for that group). A ticked branch can still send a part it isn't buying here. | It can't be both buying and giving away the same part in one order. |
| G4 | **This morning's daily suggestions are not subtracted from the senders.** They are suggestions, not commitments; only saved transfers (Draft / Exported / Entered) count, as everywhere else. | Same rule as Reorder; avoids One-Time depending on what someone else might tick later. |
| G5 | **Every branch loads when the person clicks Next on Set up** (the shared engine loader, with the same progress bar and Cancel / Load the rest), not before. Saving waits until every branch has loaded (as phase 3 Y1). | The senders need every branch; loading on open would slow down a One-Time used only for one branch's buy. About 10–15 s the first time in a session, then cached. |
| G6 | **Ticks start ticked**, quantities capped at the suggestion (Brian 2026-10-29: keep the cap). Changing the order's settings on Set up (branches, franchises, groups, months, method, factor, minimums) after ticking asks first ("Your transfer ticks will be lost") and recomputes. | Same as Reorder; the receivers depend on the settings. |
| G7 | **Continue to Review with unsaved ticks asks "Save the N ticked transfers first?"** (Save and continue / Continue without them / Stay), as Reorder. Review counts **saved** transfers only, with "Includes N coming by transfer from branch X" on the lines they cover. | Same question and rule as Reorder; the order is never built on unsaved transfers. |
| G8 | **Saved transfers say where they came from:** Parameters `source: "One-Time"` and the order name (`orderName`). The transfer order page shows "From One-Time Order "<name>"", and Transfers → Transfer orders gets no new column. | People can trace a transfer back to the buy it was for. |
| G9 | **Saved here, one transfer order per From + To** (the phase 3 saver), title as today (`<from>-<to>-<yyyymmdd>-<hhmm>`). | Equip keys transfers by branch pair. |
| G10 | **Version 0.7.0.** Documents (walkthrough, guide, REORDER-RULES, a short TRANSFER-RULES guide for Ben, and the "Round 2 changes" summary) are written and batched; users get them when Brian decides (Ben 2026-10-28: no release notes every release). | Spec phasing row 4; Ben's guidance. |

---

## File map

**nonjd-order-app**
| File | Change |
|---|---|
| `src/engine/oneTimeTransfers.ts` (new) + `src/engine/index.ts` | `oneTimeTransferLines(receivers, sources, run)`: builds the allocation rows (G2, G3) and calls `allocateGroup` per group; conventional lines only |
| `src/pages/reorder/useReorderTransfers.ts` → keeps its name, gains a `lines` strategy option | Default strategy = today's (live run lines into the branches); One-Time passes its own. `saveSource` gains `'One-Time'`; Parameters gain `orderName` |
| `src/transfers/draft.ts`, `src/data/types.ts` | `TransferParameters.source` adds `'One-Time'`; optional `orderName` |
| `src/pages/OneTimeOrderPage.tsx`, `src/pages/oneTime/OneTimeTransfersStep.tsx` (new), `src/pages/oneTime/steps.ts` (new) | Three-step stepper, the Transfers step (TransferStep + the Save-first question), skip rule, settings-change question |
| `src/pages/OneTimeOrderPage.tsx` (Review) | "Includes N coming by transfer" note per line (as Reorder step 2) |
| `src/pages/transfers/transferOrderText.ts` | `parametersSummary` names a One-Time source with its order name |
| `package.json`, `README.md` | 0.7.0, Versions row |
| tests under `src/**/__tests__/` | New and changed cases |

**data-projects**
| File | Change |
|---|---|
| `projects/part order tool - app/for-users/walkthrough.js`, `guide.js` (+ .docx), `REORDER-RULES.md` | One-Time Transfers step |
| `projects/part order tool - app/TRANSFER-RULES.md` (new) | Ben's guide to the transfer rule fields and the pick order |
| `projects/part order tool - app/for-users/round2.js` (new, + .docx) | "Round 2 changes", as `round1.js` |
| this plan, the round 2 spec, the memory note | Progress |

---

## Tasks

### Task G1: The one-time allocation (pure engine)

**Files:** `src/engine/oneTimeTransfers.ts` (new), `src/engine/index.ts`, `src/engine/__tests__/oneTimeTransfers.test.ts` (new).

- [ ] **Step 1: tests first.** A `OneTimeReceiver` is `{ branch, franchise, partNumber, need }` (need = `baseQty`). Cases, each against hand-worked numbers:
  - one receiver, two senders: the greater sender cover sends first, re-picked after each line; the line quantities add up to min(need, total free);
  - two receivers in one group: the lower receiver cover receives first (spec Part 3, conventional step 1);
  - a receiving branch with FreeExcess > 0 for the same part sends nothing (G3), but sends another part it isn't receiving;
  - no redistribution lines, ever, even where the daily run would make some;
  - need 0, or no sender with free > 0: no lines;
  - the result doesn't depend on the order of receivers or sources (shuffle and compare);
  - a receiver with no source row at its branch is skipped (a guard: One-Time lines always come from loaded branch parts, and the all-branch run has every part of every branch).
- [ ] **Step 2:** implement: index `run.parts` / `sources` by `suggestedKey`; for each group with a receiver, build `AllocationRow`s with `allocationRow(...)` from the source and its `PartTransfer`, then override: receivers `{ convNeed: need, freeExcess: 0, redistEligible: false }`, others `{ convNeed: 0, redistEligible: false }` (FreeExcess kept); call `allocateGroup`. Return `SuggestionLine[]` sorted as `allocateAll` does.
- [ ] **Step 3:** `npx vitest run src/engine`, `npm run lint`; commit.

### Task G2: Generalise the transfer hook

**Files:** `src/pages/reorder/useReorderTransfers.ts`, `src/transfers/draft.ts`, `src/data/types.ts`, tests.

- [ ] **Step 1:** add an option `lines?: (run: AllBranchTransfers, computed: readonly BranchComputed[]) => { lines: TransferLineInput[]; facts: FactsLookup }`. Absent = today's behaviour (the live run's lines into `branches`). The `runWith(committed)` path, the stale check and `ticksAfterSave` use whatever the strategy returns, so a save re-checks one-time lines against a fresh one-time run.
- [ ] **Step 2:** `saveSource: 'Reorder' | 'Transfers' | 'One-Time'`, and an optional `orderName` written into Parameters (G8).
- [ ] **Step 3:** no morning mode for a strategy (One-Time has no morning file): `mode` is 'live' once every branch has loaded, else the step shows the loader and nothing to tick.
- [ ] **Step 4:** every existing Reorder and Transfers test passes unchanged (that is the check that the default strategy is today's); new hook tests with a stub strategy: save, stale check, lag overlay.
- [ ] **Step 5:** commit.

### Task G3: One-Time, the Transfers step

**Files:** `src/pages/OneTimeOrderPage.tsx`, `src/pages/oneTime/OneTimeTransfersStep.tsx` (new), `src/pages/oneTime/steps.ts` (new), tests (`src/pages/__tests__/oneTimeTransfers.test.tsx`, new).

- [ ] **Step 1:** the stepper "Set up order → Transfers → Review & calculate". Next on Set up starts the all-branch load (G5) and opens step 2; step 2 shows the progress bar until every branch is in.
- [ ] **Step 2:** the receivers are the order's listed lines (the same `oneTimeLines` the Review uses, `baseQty`), the strategy is `oneTimeTransferLines` (G1). Step 2 renders `TransferStep` (search, sticky footer Save, preview of the receiving line's one-time quantity) and the Save-first question on Continue (G7). Nothing suggested → straight to Review with the note (G1).
- [ ] **Step 3:** Back to Set up keeps the ticks; changing a setting asks first when ticks were edited (G6) and recomputes.
- [ ] **Step 4:** leaving the page with unsaved transfer edits or ticked review lines asks (LeaveTicksGuard, as 0.6.0), including while a save runs.
- [ ] **Step 5:** tests on the mock: a one-time line that another branch can cover shows on step 2 ticked; Save writes one Draft per From + To with source "One-Time" and the order name; Review then shows the line reduced with "Includes N coming by transfer"; Continue without saving leaves Review as it was; a setup change after an untick asks; a branch with nothing to receive skips step 2.
- [ ] **Step 6:** commit.

### Task G4: Review, the transfer order page and Transfers

- [ ] **Step 1:** Review: the "Includes N coming by transfer from branch X" note on lines covered by saved transfers (the shared helper Reorder step 2 uses), and the Inbound tooltip "Equip transfers + transfers saved in this app".
- [ ] **Step 2:** `parametersSummary`: "From One-Time Order "<name>" · data as of …" (G8). Transfer orders list unchanged.
- [ ] **Step 3:** tests; commit.

### Task G5: Mock click-through test (Claude), then Brian's list

- [ ] **Step 1:** one test through the real routes: One-Time set up (two branches, a franchise) → Next → step 2 lines → untick one, save → Review shows the reduction → Create order → Orders; the transfer order page shows the One-Time source.
- [ ] **Step 2:** a short click-through list for Brian (`for-users/0.7.0-click-through.md`), run with `npm run dev`.

### Task G6: 0.7.0, review, build

- [ ] **Step 1:** `package.json` 0.7.0; README row.
- [ ] **Step 2:** `npm test`, `npm run lint`, `npm run build`; dist check (list and site IDs present, no mock strings, About stamped).
- [ ] **Step 3:** `typescript-reviewer` over everything since 0.6.2 (`0bec57a`), focused on the hook's strategy (no Reorder behaviour change), the setup-change reset, and the allocation's G3 rule. Fix, re-run step 2, commit and push dev.

### Task G7 (Brian + Claude): Fedora and one real TEST

- [ ] **Step 1 (Brian):** deploy 0.7.0; About shows it.
- [ ] **Step 2 (Brian, approved writes, after 10:15):** a One-Time Order for one branch and franchise that Claude names from Prod data that morning (a part with a small one-time quantity another branch can send). On step 2, save one line; then cancel that transfer order from its page. Claude confirms the Parameters (source One-Time, order name) through Graph and that, after Refresh, the line is offered again. No order is created (Back, or leave).
- [ ] **Step 3:** Brian's OK to delete the TEST header and line (by id).

### Task G8: Documents (batched)

- [ ] **Step 1:** walkthrough: "New in 0.7.0" (the Transfers step on One-Time), with a Prod example of the day. Guide: One-Time section gets the Transfers step. REORDER-RULES: "One-Time Order transfers" (G2–G4).
- [ ] **Step 2:** `TRANSFER-RULES.md` for Ben: each field (ExcessSupply, AllowSend / AllowReceive, RedistMax, RedistMinValue, season), which branch's rule decides what (sender: excess; receiver: whether and how much redistribution), the pick order, and Try it.
- [ ] **Step 3:** `round2.js` + .docx: the round 2 summary (several branches, phase-in, transfers from suggestion to Equip, Transfer rules, One-Time transfers), one page, as `round1.js`.
- [ ] **Step 4:** regenerate the .docx files (check for Brian's hand edits first), commit named files only.

### Task G9: Progress

- [ ] **Step 1:** this plan's Progress, the round 2 spec's Progress (round 2 complete), the app README, the memory note (0.7.0 live; next: Brian's pick from FUTURE-IDEAS / N2).

---

## Self-review against the spec

- "One-Time rec qty … − AppInboundQty": already live since 0.5.0 (no task).
- "The One-Time transfer step runs only the conventional half of Part 3; receivers: listed one-time parts at the ticked branches, need = rec qty before the line value limits, masked and Manual order left out; senders: FreeExcess from Part 2 for every branch": G1, G2, G3.
- "Live-only, no Gold version, no parity check": no backend task.
- "Set up → Transfers → Review; same table, save and question as Reorder; Review subtracts saved transfers in; skipped when nothing is suggested": G3, G4.
- "Phase 4 documents: user guide, REORDER-RULES, a TRANSFER-RULES guide for Ben, the Round 2 changes doc": G8.
