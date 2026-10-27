# Non-JD Parts Order Tool: round 2 phase 2: data, contract v3, phase-in and transfer suggestions (Plan E)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax. SharePoint, Entra, Gateway PC and Fabric UI steps are Brian's, one at a time, verified. Live SharePoint writes by Claude need Brian's explicit OK.

> **Progress:** plan written 2026-10-27 (Claude, for Brian).
> - **E0a done 2026-10-27:** `PhaseInQty` (Number, decimals none), `PhaseInEnds` and `PhaseInOn` (dateOnly) on `NonJD_PartSettings` (`a4b26767-…`), internal names equal display names (verified through Graph). A failed save had created a duplicate `PhaseInEnds0`; it was deleted and the column recreated. **For later list steps:** if SharePoint shows an error on save, refresh before saving again.
> - **E0b done 2026-10-27:** `SLC`, `Source`, `VendorCode`, `ProductGroup`, `CommodityCode` (single line of text, not required, no default) on `NonJD_OrderRules` (`6938ff15-…`); internal names equal display names. The 5 rules are unchanged (Default: 12 months, 3 demands, 12 Weeks, modified 2026-10-26) and blank in the new columns. Note: the rules list's supply column is internally `WeeksOfCover`.
> - **E0c done 2026-10-27:** `NonJD_TransferRules` list ID **`3b3fc526-f73a-4d2a-b15e-0fbaeb01175f`**. All 21 columns verified through Graph (internal names = display names; types, decimals, defaults Active/AllowSend/AllowReceive Yes, Archived No, ExcessSupply 12 (1 dp), RedistMax 6 (1 dp), RedistMinValue 25 (2 dp), ExcessUnit/RedistUnit Weeks/Months default Months, Priority required 0 dp, Notes plain multi-line); no extra columns; 0 items.
> - **E0d done 2026-10-27:** `NonJD_Transfers` list ID **`7236d483-71cb-486f-9c6c-1fa5abe9749f`**. Columns verified through Graph: FromBranch / ToBranch text, **indexed**; Status choice Draft/Exported/Placed/Cancelled, default Draft; PlacedAt date and time; ExportCount 0 dp, default 0; Parameters plain multi-line. No extra columns; 0 items.
> - **E0e done 2026-10-27:** `NonJD_TransferLines` list ID **`00ee3db9-507f-4c97-a246-5ac9df948b8e`**. Columns verified: TransferId 0 dp **indexed**; Kind choice Conventional/Redistribution, no default; SuggestedQty/Qty 0 dp; Cost/LineValue 2 dp; Franchise, PartNumber, Description, FromBin, ToBin text. No extra columns; 0 items. **All SharePoint steps (E0a–E0e) are done.**
> - **E1 done 2026-10-27** (fabric-workspace-docs `39a0538d` dataflows + DAG, `60e7e867` shortcuts). Dev staging synced; all four dataflows ran (no connection binding needed). `NonJD_PartSettings` 1 row with PhaseInQty/PhaseInEnds/PhaseInOn (null); `NonJD_OrderRules` 5 rows with the five criteria (null); `NonJD_TransferRules` and `NonJD_Transfers` 0 rows with the planned schemas. DP_Presentation Dev: lakehouse conflict → Brian accepted incoming; both shortcuts resolve.
>   - **Deviation:** `Fact_NonJD_TransferSuggestion` is **not** yet in Gold's `produces`, because `dag_check` fails on a declared-but-unsaved table and the dev push runs it in CI. **E5 adds it** in the same commit as the notebook's `.save(...)`, then regenerates TABLE-LINEAGE.
>   - **To check in phase 3:** `df_NonJD_Transfers_Raw` converts PlacedAt/Created to UTC, treating zone-less values as Pacific (site-local) time. Confirm with the first real saved transfer.
> - **E2 done 2026-10-27** (`f17adfbb`; 395 tests). Review: nothing critical. The follow-up fix clamps line Qty (spec "Part 1 clarifications"). Dev check: 0 differences on the 28 round-1 columns; the new columns await E4.
> - **Ben's answers 2026-10-27** (`feedback/2026-10-27-ben-transfer-answers.md`). They change E3, E5 and E9 (allocation order by months of supply), the built-in RedistMinValue (0, was 25), E12 (both kinds ticked, kind badge, franchise filter) and the SharePoint default (**Brian: set `NonJD_TransferRules.RedistMinValue` default to 0**). The spec's A6, A9, A12 and Part 3 are updated, and they win over any older wording below.
> - **E11b done 2026-10-27** (app `cd8f0dc` + review fixes `6e2418d`; 999 tests, lint clean): dealer group checklist on One-Time Order and Recommended Reorder (`?dgc=`), a "(none)" choice for parts with no group (36% of parts; `-` in the URL, `""` in Parameters), ticking every group = All, requested groups kept while branches load. Known quirk to show in the walkthrough: Select all on the group list reads as All (boxes unticked), because nothing ticked already means every group. Not deployed; ships with 0.5.0.
>
> **Brian, 2026-10-27: the test users can live with the app being down or changing for a while, so build once and test on the real thing.** This overrules **X1**:
> - no `test-v3` folder, no `NONJD_FOLDER` / `VITE_GRAPH_DATA_FOLDER` settings, no localhost redirect URI;
> - keep the publish's local `--out` build (no upload), which the app's parity checks use;
> - E15 becomes: Dev Gold matches the reference (in the lakehouse, as in round 1), and the app matches a local `--out` build of Dev data;
> - then E18: release to Prod, deploy 0.5.0, publish v3 from the Gateway PC, and test the app on Prod data. A short outage on the live app is acceptable.
>
> **Users get batched releases:** no update, guide or walkthrough per version. Keep the walkthrough's sections and the version notes up to date as we go. Brian sends one combined release later (every version since 0.2.0, open questions, walkthrough), at the point where we can't go further without their feedback. Ben gets only the questions that block the build, now.

**Goal:** put phase-in live and publish daily transfer suggestions (conventional and redistribution) that Shannon can see and export, on contract v3, with Gold, the DuckDB reference and the app engine agreeing part for part and line for line.

**Architecture:** this is phase 2 of the round 2 spec (`docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md`, "Phasing"). The spec's "The calculation" (Parts 1–3), "The lists", "The data model", "The contract (v3)" and the phase 2 parts of "The UI" are the source of truth; this plan says who builds what, in which order, and how it is checked. The pipeline doesn't change: SharePoint lists → DP_Staging dataflows → `Build_Gold_NonJD_Reorder` → the publish on the Gateway PC → the React app, which recalculates live. There's no ticking, saving or transfer order page yet (phase 3), but the engine already reads committed transfers, so phase 3 is screens only.

**Tech stack:** Fabric Dataflow Gen2 (Power Query M), Spark notebook (PySpark + `applyInPandas`), DuckDB reference (Python, pytest), publish (Python, pytest), app (Vite 7, React 19, TypeScript, Vitest, tsx scripts).

**Repos and branches** (all work on `dev`; stage only named files):
- `data-projects`: reference, fuzz generator, publish, documents, this plan.
- `fabric-workspace-docs`: dataflows, Gold notebook, `dp_refresh_dag.json`, shortcuts.
- `nonjd-order-app`: engine, data layer, screens. App version **0.5.0**.

---

## Decisions made in this plan (Brian can overrule any of them)

The spec leaves these open. Each is what we'll build unless Brian says otherwise.

| # | Decision | Why |
|---|---|---|
| X1 | **Dev v3 is tested on its own folder, not on the live library.** The publish gets an optional folder setting (`NONJD_FOLDER`, default the library root), and the app gets `VITE_GRAPH_DATA_FOLDER` (default root). In E15 Brian publishes Dev data from his PC into `NonJD Order Data/test-v3` with a separate env file, and runs the app locally (`npm run dev`, graph mode) against that folder. The live library and the Gateway PC stay on Prod v2 until the release (E18). | Round 1 was tested on the live library because it was still Dev-fed then. It's now Prod-fed and Ben's team uses it, and a v3 publish there would break the deployed 0.4.0 app. The live library is still published only from the Gateway PC. **Needs:** `http://localhost:5173` must be a redirect URI on the app's Entra registration. Brian checks in E15 step 1, and adds it if it's missing. |
| X2 | **The app reads `NonJD_TransferRules`, `NonJD_Transfers` and `NonJD_TransferLines` live, read-only, in phase 2.** Nothing in the app writes to them until phase 3. | Step 8b and the per-group parity check need them, and the engine is then finished for phase 3. The lists are empty, apart from Brian's test rows in E15. |
| X3 | **There's no Transfer rules page in phase 2.** Until 0.6.0, transfer rules are edited directly in the SharePoint list (Brian only). The Transfers page shows which transfer rules are in use, read-only, with the built-in default row. | The spec puts the page in phase 3. Ben starts with no rows. |
| X4 | **The order Rules editor gets the five new criteria (SLC, Source, Vendor code, Product group, Commodity code) in phase 2,** and so does Try it. | A11 changes rule matching in phase 2. Without the editor, the criteria could only be set in SharePoint. The work is small, because the editor already handles text criteria. |
| X5 | **The differential fuzz is committed this time,** as `tools/dp-migration/nonjd_transfer_fuzz.py` (cases + expected output) and the app's `scripts/fuzz-transfers.ts` (runs the engine over them). | The B4/C5 fuzz lived in the scratchpad and was lost. The allocation is sequential, which makes it the most bug-prone part. |
| X6 | **`transferRuleId` is in the contract too,** alongside `transferRuleName`. | The spec lists TransferRuleId as a Gold column but leaves it out of the contract. The app needs it to show which rule applied and to check parity. |
| X7 | **Months of supply shown on screens** = trunc(on hand) ÷ MonthlyRate, to 1 decimal, and "—" when the rate is 0. | This is A1's meaning. The spec doesn't say how to show it when the rate is 0. |
| X8 | **The two new dataflows are added to the DAG by name.** `Pipeline_DP_Refresh` runs them by name, so the pipeline JSON is unchanged and stays claimed. `claim_prod_pipeline.py` still runs after the deploy, as a check. | This settles spec Decision 4. It's the same pattern as the round 1 release (PR #44). |
| X9 | **Whole groups go into the engine fixture.** `make_engine_fixture.py` samples Franchise + PartNumber groups with every branch row, never single rows, for the allocation strata. | Allocation needs every branch of a group. A row sample would make parity fail for the wrong reason. |
| X10 | **The two allocation implementations are written blind.** The reference (E3) and Gold (E5) are written by different subagents from the spec's Part 3, and neither is shown the other's code. The app's version (E9) is written from the spec, not ported. | The spec's risk table: "Reference written independently". This is why the plan has no allocation code. |

**Spec decisions due now:**
- **Decision 2 (lists):** this is E0a–E0e, Brian's steps.
- **Decision 4 (dataflows):** this is E1 and X8. The Prod deploy is in E18.

**Ben:** the spec says to send the assumption table before phase 3. Phase 2 already builds A1–A11, A15–A19 and A22 into code. The defaults (12 months, 6 months, $25) are rule values, so they can change without code. A3, A4, A5, A6 and A8 are code. **Recommendation:** Brian sends Ben the table (with the round 2 questions N4/N5) before E3 starts, so a change there costs a test edit rather than a rework.

---

## File map

**data-projects**
| File | Change |
|---|---|
| `tools/dp-migration/nonjd_reorder_check.py` | A11 criteria, step 7b/8/8b/9, Part 2 SQL, Part 3 Python loop, transfer rule validation, suggestion compare |
| `tools/dp-migration/test_nonjd_reorder_check.py` | New cases (tests first) |
| `tools/dp-migration/nonjd_transfer_fuzz.py` (new) | Random group generator + expected output from the reference (X5) |
| `tools/dp-migration/test_nonjd_transfer_fuzz.py` (new) | Generator determinism, case validity |
| `projects/part order tool - app/publish/extract.py` | New columns, transfer rules, suggestions + committed |
| `projects/part order tool - app/publish/build_files.py` | New reorder fields, `transfer_rules.json.gz`, `transfer_suggestions.json.gz`, rules criteria |
| `projects/part order tool - app/publish/publish_logic.py` | `CONTRACT_VERSION = 3`, upload order |
| `projects/part order tool - app/publish/config.py`, `upload.py`, `run_publish.py` | `NONJD_FOLDER` (X1), `--out <dir>` local build with no upload |
| `projects/part order tool - app/publish/make_engine_fixture.py` | Phase-in, committed and group strata (X9) |
| `projects/part order tool - app/publish/README.md` | Contract v3 |
| `projects/part order tool - app/publish/test_*.py` | Updated / new cases |
| `projects/part order tool - app/for-users/` | Walkthrough doc, new 0.5.0 section (E16); user guide and REORDER-RULES (E17) |

**fabric-workspace-docs**
| File | Change |
|---|---|
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow/mashup.pq` | PhaseInQty, PhaseInEnds, PhaseInOn |
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_OrderRules_Raw.Dataflow/mashup.pq` | SLC, Source, VendorCode, ProductGroup, CommodityCode |
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_TransferRules_Raw.Dataflow/` (new: `.platform`, `queryMetadata.json`, `mashup.pq`) | List → `NonJD_TransferRules` |
| `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_Transfers_Raw.Dataflow/` (new, same three files) | Header + lines → `NonJD_Transfers` |
| `workspaces/DP - Presentation - Dev/DP_Presentation.Lakehouse/shortcuts.metadata.json` | Shortcuts `NonJD_TransferRules`, `NonJD_Transfers` |
| `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py` | Parts 1–3, `Fact_NonJD_TransferSuggestion` |
| `deploy/dp_refresh_dag.json` | Two dataflows, Gold `dependsOn` + `produces` |
| `docs/TABLE-LINEAGE.md` | Regenerated |

**nonjd-order-app**
| File | Change |
|---|---|
| `src/data/contract.ts`, `src/data/types.ts`, `src/data/files.ts`, `src/data/lists.ts`, `src/data/source.ts`, `src/config.ts`, `src/data/mock/*` | v3, new files, new list columns, three read-only lists, data folder |
| `src/engine/rules.ts`, `calc.ts`, `oneTime.ts`, `explain.ts`, `parity.ts`, `types.ts` | Criteria, phase-in, step 8b, explanations, parity fields |
| `src/engine/transferRules.ts` (new) | Transfer rule validation and pick |
| `src/engine/transfers.ts` (new) | `transferInputs`, `allocateGroup`, `allocateAll` |
| `src/engine/transferParity.ts` (new) | Per-group parity |
| `src/state/engineBranches.ts` | Runs Parts 2–3 once every branch is loaded |
| `src/pages/part/SettingsTab.tsx`, `settingsForm.ts`, `src/pages/reorder/QuickActions.tsx`, `src/pages/PartLookupPage.tsx` | Phase-in |
| `src/pages/SpecialStatusesPage.tsx`, `src/pages/special/specialRows.ts` | Phase-in statuses |
| `src/pages/part/OtherBranches.tsx`, `otherBranchRows.ts`, `src/pages/PartPage.tsx` | Above target, Excess, Months of supply, suggested transfers |
| `src/pages/rules/RuleEditor.tsx`, `ruleForm.ts`, `tryIt.ts` | Five criteria (X4) |
| `src/pages/TransfersPage.tsx` (new), `src/pages/transfers/transferRows.ts` (new), `src/ui/nav.ts`, `src/App.tsx` | Read-only Transfers page |
| `scripts/parity-full.ts`, `scripts/fuzz-transfers.ts` (new) | Suggestions parity, differential fuzz |
| `package.json`, `README.md` | 0.5.0, Versions table |

---

## Tasks

### Task E0a (Brian, SharePoint): `NonJD_PartSettings` phase-in columns

- [ ] **Step 1 (Brian):** on the Report Site, in `NonJD_PartSettings`, add:
  - `PhaseInQty` (Number, 0 decimals, no default);
  - `PhaseInEnds` (Date only);
  - `PhaseInOn` (Date only).
- [ ] **Step 2 (Claude):** verify through Graph (read-only). The internal names must equal the display names, with no `_x0020_` and no `0` suffix:

```bash
SITE="spitractor.sharepoint.com,dc84cab5-e496-4929-a599-3123cbb823e1,65b43472-28c3-45c7-9c74-f7a57f2c839c"
L=<NonJD_PartSettings list id, from src/config.ts VITE_LIST_SETTINGS in the app's .env.production>
az rest --method get --url "https://graph.microsoft.com/v1.0/sites/$SITE/lists/$L/columns" \
  --query "value[?contains(['PhaseInQty','PhaseInEnds','PhaseInOn'], name)].{name:name,display:displayName,number:number,dateTime:dateTime}" -o json
```

  Expected: three columns. PhaseInQty has `decimalPlaces: none`. Both date columns have `format: dateOnly`.
- [ ] **Step 3:** record the result in this plan's Progress block.

### Task E0b (Brian, SharePoint): `NonJD_OrderRules` criteria columns

- [ ] **Step 1 (Brian):** add `SLC`, `Source`, `VendorCode`, `ProductGroup` and `CommodityCode` (all single line of text, no default) to `NonJD_OrderRules`. Leave the existing rows blank (blank = any).
- [ ] **Step 2 (Claude):** verify with the E0a query on the rules list (`VITE_LIST_RULES`), with the five names. Then list the rows to confirm nothing else changed (`Title, Active, Priority, MinDemands, SupplyUnit, Supply`).
- [ ] **Step 3:** record the result in Progress.

### Task E0c (Brian, SharePoint): new list `NonJD_TransferRules`

- [ ] **Step 1 (Brian):** create the list with the columns from the spec's "The lists" table:
  - Title (the rule name);
  - Priority (Number, required);
  - Active (Yes/No, default Yes);
  - Archived (Yes/No, default No);
  - Franchise, DealerGroupCode, Branch, SLC, Source, VendorCode, ProductGroup, CommodityCode (text);
  - StartMonth, EndMonth (Number, 0 dp);
  - ExcessSupply (Number, 1 dp, default 12);
  - ExcessUnit (Choice Weeks/Months, default Months);
  - AllowSend (Yes/No, default Yes);
  - AllowReceive (Yes/No, default Yes);
  - RedistMax (Number, 1 dp, default 6);
  - RedistUnit (Choice Weeks/Months, default Months);
  - RedistMinValue (Number, 2 dp, default 25);
  - Notes (multiple lines).

  **No rows.** Give the app's users group the same permissions as `NonJD_OrderRules`.
- [ ] **Step 2 (Claude):** look up the list ID (`az rest .../sites/$SITE/lists?$filter=displayName eq 'NonJD_TransferRules'`). Then verify every column's internal name, type, decimals, choices and default with the E0a query, and that the list has 0 items.
- [ ] **Step 3:** record the list ID in Progress. The dataflow (E1) and the app's `.env` files (E7) need it.

### Task E0d (Brian, SharePoint): new list `NonJD_Transfers`

- [ ] **Step 1 (Brian):** create the list:
  - Title;
  - FromBranch, ToBranch (text, each **indexed**);
  - Status (Choice Draft / Exported / Placed / Cancelled, default Draft);
  - PlacedAt (Date and time);
  - ExportCount (Number, 0 dp, default 0);
  - Parameters (multiple lines, plain text).

  Same permissions as `NonJD_Orders`. No rows.
- [ ] **Step 2 (Claude):** verify the columns, the two indexes (`indexed: true` in the columns query) and 0 items. Record the list ID.

### Task E0e (Brian, SharePoint): new list `NonJD_TransferLines`

- [ ] **Step 1 (Brian):** create the list:
  - Title;
  - TransferId (Number, 0 dp, **indexed**);
  - Franchise, PartNumber (text);
  - Kind (Choice Conventional / Redistribution);
  - SuggestedQty, Qty (Number, 0 dp);
  - Cost, LineValue (Number, 2 dp);
  - Description, FromBin, ToBin (text).

  Same permissions as `NonJD_OrderLines`. No rows.
- [ ] **Step 2 (Claude):** verify, and record the list ID.

### Task E1: Dataflows, DAG and shortcuts (fabric-workspace-docs, Dev)

**Files:** the two existing `mashup.pq` files, the two new dataflow folders, `deploy/dp_refresh_dag.json`, `shortcuts.metadata.json` and `docs/TABLE-LINEAGE.md` (see the file map).

- [ ] **Step 1:** `df_NonJD_PartSettings_Raw`: add `PhaseInQty` (number), `PhaseInEnds` and `PhaseInOn` (date, as the Central date, the same as `MaskedOn`). Extend the typed empty table to match.
- [ ] **Step 2:** `df_NonJD_OrderRules_Raw`: add the five criteria as text, with blank → null (the same as `Franchise`).
- [ ] **Step 3:** create `df_NonJD_TransferRules_Raw` by copying `df_NonJD_PartSettings_Raw`'s pattern:
  - navigate by list GUID;
  - a typed empty table when the list is empty;
  - the header comment (purpose, grain, source, business use);
  - `Modified` handling;
  - the same SharePoint cloud connection.

  Output `NonJD_TransferRules`:
  - Id (Int64), RuleName (from Title), Priority, Active, Archived;
  - the eight criteria (text, blank → null);
  - StartMonth, EndMonth, ExcessSupply, RedistMax, RedistMinValue (number = DOUBLE);
  - ExcessUnit, RedistUnit (text);
  - AllowSend, AllowReceive (logical);
  - Modified (datetime).

  The `.platform` gets a new `logicalId` (`python -c "import uuid; print(uuid.uuid4())"`).
- [ ] **Step 4:** create `df_NonJD_Transfers_Raw`. It reads `NonJD_Transfers` and `NonJD_TransferLines` by GUID and inner-joins the lines to their header on TransferId = Id.
  - **Filters:**
    - drop `Status = "Cancelled"`;
    - drop `Status = "Placed"` where the Central date of `PlacedAt` is more than 30 days before the Central date of the run (`DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -6)` is wrong across DST; use the pattern in `.claude/queries/DATA-REFRESH-TEMPLATE.pq`).
  - **Output** `NonJD_Transfers`:
    - TransferId (Int64), Status (text), PlacedAt (datetimezone → UTC datetime);
    - FromBranch, ToBranch (text);
    - LineId (Int64), Franchise, PartNumber (text, **not trimmed**: copied from Gold);
    - Qty (number), Kind (text), Created (datetime).
  - A typed empty table when either list is empty. That's the normal state in phase 2.
- [ ] **Step 5:** `dp_refresh_dag.json`:
  - add the two dataflows (type `dataflow`, workspace and tier `staging`, cadence `daily`, `produces` `NonJD_TransferRules` / `NonJD_Transfers`), copying the `df_NonJD_OrderRules_Raw` entry;
  - add both to `Build_Gold_NonJD_Reorder.dependsOn`;
  - add `Fact_NonJD_TransferSuggestion` to its `produces`.
- [ ] **Step 6:** `shortcuts.metadata.json`: append `NonJD_TransferRules` and `NonJD_Transfers`, the same shape as the existing `NonJD_OrderRules` entry.
- [ ] **Step 7:** run `python deploy/dag_check.py` and `python -m pytest deploy -q`, then regenerate `docs/TABLE-LINEAGE.md` (the generator `dag_check.py` names). Expected: all pass. `dag_check` will report `Fact_NonJD_TransferSuggestion` as declared but not yet saved; that's acceptable until E5, when it's fixed.
- [ ] **Step 8:** commit and push dev:

```bash
git add "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_PartSettings_Raw.Dataflow/mashup.pq" \
  "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_OrderRules_Raw.Dataflow/mashup.pq" \
  "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_TransferRules_Raw.Dataflow" \
  "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_NonJD_Transfers_Raw.Dataflow" \
  deploy/dp_refresh_dag.json docs/TABLE-LINEAGE.md
git commit -m "Non-JD round 2: transfer dataflows, phase-in and criteria columns"
```

  **Leave `shortcuts.metadata.json` for Step 10.** Build the staging table before its shortcut.
- [ ] **Step 9:** git sync **DP - Staging - Dev** (`python tools/dp-migration/git_sync.py <workspaceId>` in data-projects). Run the four dataflows (`run_item.py`). Check with DuckDB:
  - `NonJD_PartSettings` and `NonJD_OrderRules` have the new columns (null on existing rows) and the same row counts as before;
  - `NonJD_TransferRules` and `NonJD_Transfers` exist with 0 rows and the exact schema above.
- [ ] **Step 10:** commit `shortcuts.metadata.json`, push, and git sync **DP - Presentation - Dev**. On a lakehouse conflict, choose **Accept incoming**. Then check that both shortcuts resolve (DuckDB `delta_scan` on the DP_Presentation path returns 0 rows without error).

### Task E2: Reference, Part 1 (criteria, phase-in, committed transfers)

**Files:** `tools/dp-migration/nonjd_reorder_check.py`, `tools/dp-migration/test_nonjd_reorder_check.py`

- [ ] **Step 1: write the failing tests first.** Each one is a small in-memory DuckDB fixture, as the existing 118 tests are:
  - **A11 matching:**
    - SLC criterion `"00"` matches a part with SLC `" 00 "` (trimmed, upper-cased);
    - a blank SLC criterion matches a null SLC;
    - an SLC criterion `"00"` does **not** match a null SLC;
    - VendorCode criterion `"1234"` matches integer 1234;
    - a rule with 4 criteria beats an equal-priority rule with 3 (criteria count includes the new five).
  - **Step 7b:**
    - PhaseInQty 5, ends tomorrow, DemandCount 0, MinDemands 3 → PhaseInActive true, target ≥ 5;
    - PhaseInEnds yesterday → `Expired`, not active;
    - DemandCount 3 with MinDemands 3 → `MetCriteria`;
    - MinDemands 0 with DemandCount 0 → still active (max(MinDemands, 1) = 1);
    - PhaseInQty null or 0 → reason null;
    - masked or Manual order with an active phase-in → order 0 (A19).
  - **Step 8:** target = max(CalcTarget, ceil(EffectiveMin), ceil(PhaseInQty)) when active. A fractional PhaseInQty is impossible (validation), but ceil is applied anyway.
  - **Step 8b:**
    - Draft and Exported lines count;
    - Placed counts only when the Central date of PlacedAt ≥ the build's Central date;
    - Cancelled never counts (also filtered upstream);
    - branch compare trimmed and case-insensitive (`" 1 "` = `"1"`, `"4b"` = `"4B"`);
    - franchise and part compared exactly (`"X "` ≠ `"X"`);
    - lines to or from excluded branches are ignored;
    - AppInboundQty and AppOutboundQty sum several lines.
  - **Step 9:** base = max(0, Target − oh − oo − AppInboundQty).
  - **Validation:** PhaseInQty 0, 1.5 or 100000 → the setting is ignored and reported with "PhaseInQty must be a whole number 1-99999".
- [ ] **Step 2:** run `python -m pytest tools/dp-migration/test_nonjd_reorder_check.py -q`. Expected: the new tests FAIL and the old ones pass.
- [ ] **Step 3: implement.**
  - `RULE_CHECK_CTE` / `EXPECTED_SQL` get the criteria, steps 7b/8/8b/9 and the new columns.
  - `load_inputs` reads the new columns as optional (`select_list`, already used for columns that may be absent) and reads `NonJD_Transfers`.
  - `_params` adds the build's Central date (it's already `today`).
  - `OUTPUT_COLS` / `COMPARE_COLS` add: PendingQty, SLC, Source, CommodityCode, PhaseInQty, PhaseInEnds, PhaseInOn, PhaseInActive, PhaseInEndReason, AppInboundQty, AppOutboundQty.
- [ ] **Step 4:** run pytest. Expected: all pass.
- [ ] **Step 5:** commit:

```bash
git add tools/dp-migration/nonjd_reorder_check.py tools/dp-migration/test_nonjd_reorder_check.py
git commit -m "Non-JD reference: round 2 criteria, phase-in and committed transfers"
```

### Task E3: Reference, Parts 2–3 (transfer inputs, allocation, suggestions compare, fuzz generator)

**Files:**
- `tools/dp-migration/nonjd_reorder_check.py`
- `tools/dp-migration/test_nonjd_reorder_check.py`
- new `tools/dp-migration/nonjd_transfer_fuzz.py`
- new `tools/dp-migration/test_nonjd_transfer_fuzz.py`

**X10:** write the allocation from the spec's Part 3 only. Don't read the Gold notebook.

- [ ] **Step 1: failing tests:**
  - **Transfer rule pick:**
    - no rows → the built-in default (12 Months, send/receive Yes, 6 Months, $0 minimum);
    - priority, then criteria count, then lowest Id;
    - season;
    - Archived / inactive ignored.
  - **Transfer rule validation:** one test per message in the spec's "Validation":
    - Priority missing;
    - ExcessSupply missing;
    - ExcessSupply 61 Months / 261 Weeks;
    - RedistMax 25 Months / 105 Weeks;
    - RedistMinValue −1;
    - a bad unit;
    - a bad season.
  - **Part 2:**
    - ExcessKeep with rate 0 = Target (A3);
    - FreeExcess subtracts pending and AppOutboundQty;
    - AllowSend false → 0;
    - ConvNeed is 0 for each of AllowReceive false / ManualOrder / IsMasked / MinimumNoDemand / FreeExcess > 0;
    - RedistCap uses Weeks → months conversion;
    - RedistEligible needs rate > 0 and Target > 0.
  - **Part 3, conventional:**
    - the lowest receiver cover first (rate 0: cover 0 with no stock, +∞ otherwise; Ben A6);
    - then the largest need;
    - then branch order (`"2"` before `"10"` before `"4B"`);
    - the sender with the greatest cover ((oh − sent) / rate, +∞ at rate 0; ties by the largest free) re-picked each iteration;
    - one receiver filled from two senders gives two lines with Seq 1, 2;
    - a sender never sends to itself.
  - **Part 3, redistribution:**
    - runs on what conventional left;
    - lowest cover first;
    - a rule's RedistMinValue (set to $25 in the test) skips a sender and tries the next; the default 0 skips nothing;
    - room counts got[r] from conventional;
    - RedistMax 0 → no room.
  - **Determinism:** shuffling input rows gives an identical output.
  - **Output:**
    - Value = Qty × ToCost rounded to cents;
    - SuggestedInQty / SuggestedConvInQty / SuggestedOutQty per part.
  - **Only candidate groups:** a group with excess but no receiver emits nothing.
- [ ] **Step 2:** run pytest. Expected: the new tests FAIL.
- [ ] **Step 3: implement:**
  - `TRANSFER_RULE_CHECK_CTE` / `INVALID_TRANSFER_RULES_SQL` (the same shape as the order rule ones);
  - the Part 2 columns in SQL;
  - `allocate_group(rows: list[dict], branch_order_key) -> list[dict]` as a plain Python loop over the SQL result;
  - `expected_suggestions(con)`;
  - `compare_suggestions(con, gold, expected)` (row by row on the key; Qty/Seq exact; costs and Value within `TOLERANCE`);
  - `main` prints both compares and FAILs on either;
  - add the Part 2 columns and the transfer rule columns (TransferRuleId, TransferRuleName, ExcessSupply, ExcessUnit, AllowSend, AllowReceive, RedistMax, RedistUnit, RedistMinValue, ExcessKeep, FreeExcess, ConvNeed, RedistCap, RedistEligible, SuggestedInQty, SuggestedConvInQty, SuggestedOutQty) to `OUTPUT_COLS`.
- [ ] **Step 4: fuzz generator.** `nonjd_transfer_fuzz.py --seed N --groups G --out <dir>` writes `cases.json` and `expected.json`:
  - `cases.json`: groups of 2–19 branch rows with random oh / oo / pending / rate / target / flags / cost, plus random transfer rules and committed lines;
  - `expected.json`: the Part 2 columns and suggestion lines, from the functions above.

  The same seed gives the same files. It reads no lakehouse data.
- [ ] **Step 5:** run pytest on both test files. Expected: all pass.
- [ ] **Step 6:** commit:

```bash
git add tools/dp-migration/nonjd_reorder_check.py tools/dp-migration/test_nonjd_reorder_check.py \
  tools/dp-migration/nonjd_transfer_fuzz.py tools/dp-migration/test_nonjd_transfer_fuzz.py
git commit -m "Non-JD reference: transfer inputs, allocation, suggestions compare, fuzz generator"
```

### Task E4: Gold, Part 1

**Files:** `Build_Gold_NonJD_Reorder.Notebook/notebook-content.py`

- [ ] **Step 1:** read the new inputs:
  - PendingQty, SLC, Source, CommodityCode from `Silver_PartInformation` (already read);
  - PhaseInQty / PhaseInEnds / PhaseInOn from `NonJD_PartSettings`;
  - the five criteria from `NonJD_OrderRules`;
  - `NonJD_Transfers` (new shortcut).

  Validate PhaseInQty (ignored and listed in the WARN exit, as an invalid MinOverride is).
- [ ] **Step 2:** rule matching gets the criteria. The criteria count in the window ordering includes them, and the ordering stays unique (Priority desc, criteria desc, Id asc).
- [ ] **Step 3:** steps 7b, 8, 8b and 9 as in the spec. Committed lines are aggregated with `groupBy` + `sum` (no `first`), and excluded branches are dropped first.
- [ ] **Step 4:** add the Part 1 output columns (the E2 list). The header comment's RULES line points at the round 2 spec.
- [ ] **Step 5:** commit, push dev, git sync DP - Presentation - Dev. Run the Gold notebook **twice** through `Pipeline_DP_Refresh` `mode=items`, `items=Build_Gold_NonJD_Reorder`, so it is logged. Then run `python tools/dp-migration/nonjd_reorder_check.py --tier dev` (data-projects).
  - **Expected:** Part 1 columns PASS with 0 differences. Both runs give the same fingerprint.
  - With empty settings and transfers, RecommendedOrderQty equals yesterday's Dev Gold for every part except those whose rule match changed through a new criterion. There are none: no rule has the new criteria yet.
- [ ] **Step 6:** run `python deploy/hygiene_audit.py`, `python deploy/dag_check.py` and `python -m pytest deploy -q`. Expected: pass.

### Task E5: Gold, Parts 2–3 and `Fact_NonJD_TransferSuggestion`

**X10:** written by a different subagent from E3, from the spec only. Don't read `nonjd_reorder_check.py`.

- [ ] **Step 1:** read `NonJD_TransferRules`. Validate it with the spec's messages (invalid rules are skipped and named in the WARN exit). Pick a transfer rule per part with the same window pattern as order rules, falling back to the built-in default.
- [ ] **Step 2:** add the Part 2 columns.
- [ ] **Step 3:** candidate groups are the Franchise + PartNumber groups with some FreeExcess > 0 and some other branch with ConvNeed > 0 or RedistEligible. Allocate them with `groupBy("Franchise", "PartNumber").applyInPandas(allocate, schema)`. `allocate` is a plain Python function with the spec's explicit sorts; branch order is a key computed inside it (digits-only codes as ints first, then the rest by ordinal comparison).
- [ ] **Step 4:** join SuggestedInQty / SuggestedConvInQty / SuggestedOutQty back onto the reorder rows (0 where none). Write `Fact_NonJD_TransferSuggestion` with the spec's columns:
  - write with a literal `.save("Tables/Fact_NonJD_TransferSuggestion")`, overwrite;
  - then `VACUUM ... RETAIN 0 HOURS`;
  - the write must still produce the table when there are 0 suggestions, with an explicit schema.
- [ ] **Step 5:** commit, sync, run twice through `mode=items`, then run `nonjd_reorder_check.py --tier dev`.
  - **Expected:** both compares PASS with 0 differences, and the fingerprint is identical on both runs.
  - Sanity: about 1,000–1,200 conventional and 500–600 redistribution lines (the spec's opportunity table, on the 12 Weeks Default).
  - Run `dag_check.py`, `hygiene_audit.py` and pytest.
- [ ] **Step 6:** record the counts and the run time added in Progress. The spec estimates under a minute.

### Task E6: Publish, contract v3

**Files:** the publish files in the file map, and their tests.

- [ ] **Step 1: failing tests:**
  - `test_extract.py`: `check_columns` fails naming a missing new column; the transfer rules and suggestions extracts; committed lines read from `NonJD_Transfers` with the spec's committed rule.
  - `test_build_files.py`:
    - the new reorder fields in camelCase (`transferRuleId` too, per X6), with `""` for blank never-null text and null only for the seven nullable fields;
    - `transfer_rules.json.gz` ordered by id;
    - `transfer_suggestions.json.gz` with `lines` and `committed`;
    - `rules.json.gz` with the five criteria;
    - `_meta.json` with `contractVersion 3` and `counts.transferSuggestions`;
    - a non-finite number in a transfer rule fails the build.
  - `test_publish_logic.py`: the upload order puts `transfer_suggestions.json.gz` before `_meta.json`, and it is uploaded every run even when unchanged.
  - `test_upload.py`: `NONJD_FOLDER=test-v3` puts files under `root:/test-v3/<name>:`, and with no folder they go to root.
  - `test_run_publish.py`: `--out <dir>` writes every file plus `_meta.json` into `<dir>` and uploads nothing, writes no `publish_state.json` and takes no lock.
- [ ] **Step 2:** run `python -m pytest "projects/part order tool - app/publish" -q`. Expected: the new tests FAIL.
- [ ] **Step 3:** implement. `publish_logic.CONTRACT_VERSION = 3`.
- [ ] **Step 4:** `make_engine_fixture.py`, whole groups (X9). Add strata for:
  - an active phase-in;
  - Expired;
  - MetCriteria;
  - a committed inbound and outbound;
  - a group with a conventional line from two senders;
  - a redistribution group;
  - a group where a rule's RedistMinValue ($25 in the fixture) skips a sender;
  - a group with AllowSend false.

  The fixture includes the suggestions and committed lines of its groups.
- [ ] **Step 5:** README: contract v3, written from the spec's "The contract (v3)" plus `transferRuleId`, `NONJD_FOLDER` and `--out`.
- [ ] **Step 6:** run pytest (expected all pass). Then build locally from Dev: `python run_publish.py --out <scratchpad>/v3 --force` with a scratch env file (`NONJD_ENV_FILE`, `NONJD_SOURCE=dev`).
  - Expected: 41 + 2 files and `_meta.json` (contractVersion 3).
  - The suggestions file is well under 4 MB.
- [ ] **Step 7:** commit the publish files and tests.

### Task E7: App data layer (contract v3, lists, data folder)

**Files:** the `src/data/*` and `src/config.ts` files in the file map, plus their tests.

- [ ] **Step 1: failing tests:**
  - `contract.ts`: `CONTRACT_VERSION = 3`; a v2 `_meta` shows `CONTRACT_OLDER_MESSAGE`, and v4 shows `CONTRACT_NEWER_MESSAGE`.
  - `files.ts`:
    - loads `transfer_rules.json.gz` and `transfer_suggestions.json.gz`;
    - prefixes paths with `VITE_GRAPH_DATA_FOLDER` when set;
    - root when blank.
  - `lists.ts`:
    - `SETTING_FIELDS` gains `PhaseInQty, PhaseInEnds, PhaseInOn`, using `dateOnlyFromGraph` / `dateOnlyToGraph` like MaskedOn;
    - `RULE_FIELDS` gains the five criteria;
    - new `transferRuleFromItem`, `transferFromItem` and `transferLineFromItem`, with a read of open + recent transfers (Status ≠ Cancelled; Placed within 30 days) joined to lines by TransferId;
    - `settingPatchToFields` sends only the changed phase-in columns.
  - `config.ts`: the new `VITE_LIST_TRANSFER_RULES`, `VITE_LIST_TRANSFERS` and `VITE_LIST_TRANSFER_LINES` are required in graph mode, with the existing missing-config page.
- [ ] **Step 2:** run `npm test -- src/data src/__tests__/config.test.ts`. Expected: FAIL.
- [ ] **Step 3:** implement:
  - the types in `src/data/types.ts`, from the contract README;
  - mock fixtures in v3, with one active phase-in part, one ended phase-in, two suggestion groups and one committed Draft line;
  - add the three list IDs to `.env.production` and `.env.example` (Brian supplies the IDs from E0c–E0e). `.env.production` holds no secrets; check it's tracked before editing.
- [ ] **Step 4:** run `npm test`, `npm run lint` and `npm run build`. Expected: pass.
- [ ] **Step 5:** commit.

### Task E8: App engine, Part 1

**Files:** `src/engine/rules.ts`, `calc.ts`, `oneTime.ts`, `explain.ts`, `parity.ts`, `types.ts` and their tests; `scripts/parity-full.ts`; `src/engine/__fixtures__/gold-sample.json`.

- [ ] **Step 1: failing tests.** Port E2's cases one for one into `rules.test.ts`, `calc.test.ts` and `oneTime.test.ts`, with the same inputs and expected values. Also:
  - `explain.test.ts`: the spec's exact sentences for active phase-in, ended at its date, ended at the minimum, and "; 3 coming by transfer from branch 92 (saved 2026-11-03)";
  - `parity.test.ts`:
    - the new fields are in `PARITY_EXACT`;
    - a part whose committed lines differ from the file's `committed` is **Changed**, not a mismatch;
    - a part whose phase-in setting changed is Changed.
- [ ] **Step 2:** run `npm test -- src/engine`. Expected: FAIL.
- [ ] **Step 3: implement:**
  - criteria in `pickRule`;
  - steps 7b, 8, 8b and 9 in `computePart` (committed lines passed in through `PartInputs`, keyed by trimmed upper-case branch + exact franchise + part);
  - the One-Time rec qty subtracts AppInboundQty;
  - `explain()` clauses;
  - PhaseInQty validation with the reference's message;
  - committed is evaluated against the Central date of `dataAsOf`.
- [ ] **Step 4:** regenerate the fixture: `python make_engine_fixture.py` from E5's Dev Gold. Then:
  - run `npm test`. Expected: pass;
  - run `npx tsx scripts/parity-full.ts <scratchpad>/v3` (E6 Step 6 output). **Expected: 0 mismatches over every part and every field.**
- [ ] **Step 5:** commit.

### Task E9: App engine, Parts 2–3 (transfers, per-group parity, fuzz)

**Files:**
- new `src/engine/transferRules.ts`, `src/engine/transfers.ts` and `src/engine/transferParity.ts`, with tests in `src/engine/__tests__/`;
- `src/state/engineBranches.ts`;
- `scripts/parity-full.ts`;
- new `scripts/fuzz-transfers.ts`.

Written from the spec's Part 2 and Part 3 (X10), not ported from Python.

- [ ] **Step 1: failing tests.** Port E3's cases into `transferRules.test.ts` and `transfers.test.ts`. The validation messages must equal the reference's. Also `transferParity.test.ts`:
  - a group equals Gold line for line when the live order rules, the live transfer rules, the group's settings and its committed lines all equal the snapshot;
  - otherwise the group is **Changed**, never a mismatch.
- [ ] **Step 2:** run `npm test -- src/engine`. Expected: FAIL.
- [ ] **Step 3: implement:**
  - `transferInputs(part, result, rule)`;
  - `allocateGroup(rows)`, pure and deterministic;
  - `allocateAll(byGroup)`, which visits only candidate groups;
  - in `engineBranches.ts`, once every branch is loaded, run Parts 2–3 over all branches and expose `suggestions` and per-part `suggestedIn/Out`. Rerun only on a rules, transfer rules, settings or committed change, never on render.
  - Time `allocateAll` on the full Dev data in a test log. The spec expects under 100 ms.
- [ ] **Step 4:** `parity-full.ts` also checks every group's suggestions against `transfer_suggestions.json.gz` and the new per-part fields. Run it on `<scratchpad>/v3`. **Expected: 0 mismatches.**
- [ ] **Step 5: differential fuzz.**
  - `scripts/fuzz-transfers.ts <dir>` reads `cases.json`, runs the engine and compares with `expected.json` field by field.
  - Run `python tools/dp-migration/nonjd_transfer_fuzz.py --seed 1 --groups 5000 --out <scratchpad>/fuzz1`, then seeds 2 and 3, then `npx tsx scripts/fuzz-transfers.ts` on each. **Expected: 0 mismatches.**
  - **Planted-bug check:**
    - flip the redistribution sort to descending: the fuzz must fail;
    - drop the self-send guard: the fuzz must fail.

    Revert both and record them in Progress.
- [ ] **Step 6:** run `npm test`, lint and build, then commit.

### Task E10: Screens, phase-in and Special statuses

**Files:**
- `src/pages/part/SettingsTab.tsx`, `src/pages/part/settingsForm.ts`
- `src/pages/reorder/QuickActions.tsx`, `src/pages/PartLookupPage.tsx`
- `src/pages/SpecialStatusesPage.tsx`, `src/pages/special/specialRows.ts`
- `src/pages/reorder/RowDetail.tsx`, `src/pages/part/DetailTab.tsx`
- tests in `src/pages/__tests__/` and `src/pages/part/__tests__/settingsForm.test.ts`

- [ ] **Step 1: failing tests:**
  - **Settings tab "Phase in":**
    - quantity + end date (default Central today + 12 months);
    - Save writes PhaseInQty, PhaseInEnds and PhaseInOn = Central today, and only those columns (assert the PATCH body);
    - Clear sends all three as null;
    - the validation message for 0 / 1.5 / 100000.
  - **Quick action "Phase in…"** on a Reorder row and a Part Lookup result: the same dialog, the same patch rule as Mask, and the row recalculates after save.
  - **Special statuses:**
    - new statuses **Phase-in** (qty + end date) and **Phase-in ended** ("expired 2027-10-27" / "met the demand minimum");
    - the status filter includes both;
    - CSV columns PhaseInQty and PhaseInEnds.
  - **Row detail / Detail tab:** show the E8 sentences.
- [ ] **Step 2:** run the tests. Expected: FAIL. Then implement, and run `npm test`, lint and build.
- [ ] **Step 3:** commit.

### Task E11: Screens, wording, Part page and order rule criteria

**Files:**
- `src/pages/part/OtherBranches.tsx`, `src/pages/part/otherBranchRows.ts`, `src/pages/PartPage.tsx`
- `src/pages/rules/RuleEditor.tsx`, `src/pages/rules/ruleForm.ts`, `src/pages/rules/tryIt.ts`
- every screen that says "Excess" today
- `src/pages/__tests__/wording.test.tsx`

- [ ] **Step 1: failing tests:**
  - **Wording:**
    - `wording.test.tsx` asserts round 1's figure is labelled **Above target** everywhere ("Above target = on hand above that branch's target");
    - **Excess** appears only for FreeExcess ("Excess = free stock above what the branch keeps: the larger of its target and its excess supply");
    - "Surplus" still never appears.
  - **Other branches:**
    - columns On hand, Target, Above target, Excess, Months of supply (X7: 1 decimal, "—" at rate 0), Sold 12 mo;
    - a totals row for the summable columns.
  - **Part page:** a "Suggested transfers" line, e.g. "Suggested: 4 from branch 92 (conventional)", or "No transfers suggested". It uses the morning file until every branch loads, then the live result.
  - **Rules editor:** the five criteria, saved and patched like Franchise. Try it reflects a criterion change.
- [ ] **Step 2:** run the tests. Expected: FAIL. Then implement, and run `npm test`, lint and build.
- [ ] **Step 3:** commit.

### Task E11b: Several dealer group codes (One-Time Order and Recommended Reorder; Barry, 2026-10-27)

App only: no Gold, reference, publish or contract change. One-Time is worked out in the app, and on Recommended Reorder this is a filter on rows already computed.

**Files:** `src/pages/OneTimeOrderPage.tsx`, `src/pages/oneTime/*` (`dealerGroupsOf`, `oneTimeLines`), `src/pages/ReorderPage.tsx`, `src/pages/reorder/selection.ts`, `src/orders/draft.ts` (Parameters), the multi-check list component used for One-Time's branches and franchises (0.3.0), and their tests.

- [ ] **Step 1: tests first.**
  - One-Time: ticking groups A and B lists only parts in A or B. Nothing ticked lists every group (as blank does today). Each order's Parameters carry `dealerGroupCodes: ["A","B"]`. An order saved before 0.5.0 with `dealerGroupCode: "A"` still reads (shown as one group).
  - Reorder: the same checklist filters the list, the totals, Totals by branch and Select all. The URL keeps it (`?dgc=A,B`; old URLs without it mean all). Ticked parts in a group that gets unticked are deselected, with the same notice as the branch picker ("N selected parts in dealer group X were deselected").
- [ ] **Step 2:** One-Time: replace the dealer group `<select>` with the multi-check list (Select all / Clear). The groups offered are those of the ticked franchises across the loaded branches, sorted. `oneTimeLines` takes `dealerGroupCodes: string[] | null` (null or empty = all). The review summary shows "Dealer groups: A, B".
- [ ] **Step 3:** Recommended Reorder: a **Dealer group** control beside Franchise. It is a button that opens the checklist (like **Several branches…**) and shows "All" or the ticked codes. The offered groups come from the rows of the branch and franchise picked.
- [ ] **Step 4:** run `npm test`, `npm run lint` and `npm run build`. Commit.
- [ ] **Step 5:** walkthrough (E16): add steps for both pages to the 0.5.0 section.

### Task E12: Read-only Transfers page

**Files:**
- new `src/pages/TransfersPage.tsx`
- new `src/pages/transfers/transferRows.ts`
- `src/ui/nav.ts`, `src/App.tsx`
- `src/export/csv.ts` (reuse; no change expected)
- tests `src/pages/__tests__/TransfersPage.test.tsx` and `src/pages/__tests__/transferRows.test.ts`

- [ ] **Step 1: failing tests:**
  - **Menu and route:** a **Transfers** menu item, `/transfers`. A deep link works (`deepLinks.test.tsx`).
  - **Loading:**
    - on open, it shows the morning file's suggestions marked "as of this morning";
    - it starts the all-branch load (`engineBranches`, 4 at a time, with the existing progress component);
    - when the load finishes, it switches to the live result, with an info banner naming how many groups are **Changed** since the morning (per-group parity) and, in a details list, why.
  - **Filters:** Kind, From, To, Franchise; the URL keeps them (`?kind=Redistribution&from=92`).
  - **Kind badge** on every line (Conventional / Redistribution; Ben A12). The **Franchise** filter is at the top of the page, so one franchise can be worked at a time (Ben A13).
  - **Excess in months:** the sender columns show its excess in units and in months of supply (Ben, A16).
  - **Columns:** Kind, To, part, description, need, From, qty, sender on hand and months of supply before → after, receiver months of supply before → after, value. Default sort: Kind, then To in branch order, then part.
  - **Footer:** "N suggestions, M order lines covered, $X you wouldn't buy" (conventional), plus redistribution lines and value.
  - **CSV:**
    - **Export CSV** of the filtered list with columns `Kind,FromBranch,ToBranch,PartNumber,Franchise,Description,Qty,FromBin,ToBin,FromCost,Value`;
    - the existing CSV rules (quoting, leading-zero part numbers kept as text).
  - **No tick boxes, no save button.** A muted line says "Saving transfers comes in the next version; key these into Equip by hand for now."
  - **Transfer rules in use:**
    - a collapsed section listing the live transfer rules read-only;
    - "Built-in default: excess above 12 months, receive up to 6 months, no minimum for redistribution" when there are none;
    - invalid rules named with their messages.
- [ ] **Step 2:** run the tests. Expected: FAIL. Then implement, and run `npm test`, lint and build.
- [ ] **Step 3:** commit.

### Task E13: Mock-mode walkthrough check (Claude)

- [ ] **Step 1:** run `npm run dev` (mock mode). Go through Home, Recommended Reorder (one branch and several), the Part page (Settings phase-in, Other branches, Suggested transfers), Special statuses, Rules (criteria), the Transfers page (filters, CSV) and One-Time.
- [ ] **Step 2:** fix anything broken, with a test first. Commit.

### Task E14: App 0.5.0 and review

- [ ] **Step 1:** in `package.json`, set `"version": "0.5.0"`. Add a README Versions row: "0.5.0: round 2 phase 2: contract v3, phase-in, transfer suggestions (read-only Transfers page), Above target / Excess wording, order rule criteria".
- [ ] **Step 2:** run `npm test`, `npm run lint` and `npm run build`. Then run the dist check (real list IDs present, including the three new ones; no mock strings).
- [ ] **Step 3:** code review (`typescript-reviewer`) of everything since `3ca2dec`. Fix the findings and re-run step 2.
- [ ] **Step 4:** commit.

### Task E15 (Brian + Claude): Dev end-to-end on the test folder (X1)

- [ ] **Step 1 (Brian):** confirm `http://localhost:5173` is a SPA redirect URI on the app's Entra registration (add it if it's missing). Create the folder `test-v3` in the `NonJD Order Data` library.
- [ ] **Step 2 (Brian, approved writes):** add test rows. Claude lists them first; Brian approves and adds them by hand, or approves Claude's Graph writes.
  - **A Branch 1 phase-in:** PhaseInQty 4, ends in 12 months, on a part with 0 demands and no stock.
  - **A transfer rule** "Test - transfers": Branch 92, AllowSend No.
  - **An order rule criterion:** SLC `00` on the existing "Test - UI/UX" rule.
  - **A Draft transfer:** branch 95 → 1 with one Conventional line for a part that has a Branch 1 order line.
  - **A Placed transfer** with PlacedAt yesterday (must **not** count).
- [ ] **Step 3:** Dev refresh, `Pipeline_DP_Refresh` `mode=items`, items = the four dataflows + `Build_Gold_NonJD_Reorder`. Then run `nonjd_reorder_check.py --tier dev`. **Expected:** both compares PASS, and:
  - the phase-in part's target is 4 and its order is 4;
  - branch 92 sends nothing;
  - the Draft lowers the Branch 1 line and the 95 sender's FreeExcess;
  - the Placed line is ignored.
- [ ] **Step 4 (Brian, on his PC):** publish to the test folder with a separate env file:

```powershell
cd "C:\Users\bfox\Documents\Git-Projects\data-projects\projects\part order tool - app\publish"
$env:NONJD_ENV_FILE = "$PWD\.env.test-v3"   # copy of .env with NONJD_SOURCE=dev and NONJD_FOLDER=test-v3
python run_publish.py --force
```

  Then `npx tsx scripts/parity-full.ts` on a local `--out` build of the same data: 0 mismatches.
- [ ] **Step 5 (Brian):** run the app locally against the folder: `.env.local` with `VITE_DATA_MODE=graph` and `VITE_GRAPH_DATA_FOLDER=test-v3`, then `npm run dev`. Work through the 0.5.0 walkthrough section (E16). Expected: no parity banner; the Transfers page loads live; the test rows show as above.
- [ ] **Step 6 (Brian + Claude):** restore. Delete the test rows (Brian's OK) and clear the "Test - UI/UX" SLC. Check field by field through Graph. Delete the `test-v3` folder contents (Brian's OK). Run the Dev refresh again and check Gold equals the pre-test copy for Branch 1.
- [ ] **Step 7:** record the results in Progress.

### Task E16: Walkthrough doc, new section for 0.5.0

**Files:** the walkthrough doc and its generator in `projects/part order tool - app/for-users/`.

- [ ] **Step 1:** add a "0.5.0" section in the walkthrough's format. Each step says what to do, what you should see, and Pass/Fail. Use real parts from the current data (pick them from Prod Gold with DuckDB at the time and write them in). Cover:
  - About shows 0.5.0;
  - a part with "Above target" and "Excess" on its Other branches table, with the definitions;
  - Months of supply;
  - setting and clearing a phase-in on a test part (and seeing it on Special statuses);
  - a Phase-in ended example once one exists;
  - the Transfers page: morning file, then live after loading, filters, CSV opened in Excel, the "Changed since this morning" banner after editing a setting;
  - a part's "Suggested transfers" line;
  - an order rule criterion in Try it.
- [ ] **Step 2:** regenerate the Word file with the generator, and check it opens. Commit the generator and the .docx (named files only).

### Task E17: Documents for users

**Files:** `projects/part order tool - app/for-users/guide.js` (+ regenerated .docx), `projects/part order tool - app/REORDER-RULES.md`, `projects/part order tool - app/CORP-PARTS-MANAGER-QUESTIONS.md`

- [ ] **Step 1:** user guide:
  - phase-in (how to set, when it ends);
  - the Transfers page (read-only for now; key into Equip by hand);
  - Above target vs Excess;
  - the new rule criteria.
- [ ] **Step 2:** REORDER-RULES: steps 7b, 8, 8b and 9, the criteria, and transfer suggestions in plain words (A1–A9).
- [ ] **Step 3:** questions doc: mark N4's phase-in question as built as assumed.
- [ ] **Step 4:** regenerate, then commit the named files. **Don't** commit Brian's working copy of the guide .docx unless it was regenerated in this step.

### Task E18 (Brian + Claude): Prod release

The order is the same as round 1 (C10 + the Prod runbook): **the app goes first, then Gateway, Gold and the publish in one sitting.** Once Prod Gold has the v3 columns and the Gateway has the v3 code, a v2 app can't read the files. And the v3 code with v2 Gold fails `check_columns` and uploads nothing.

- [ ] **Step 1 (Claude):** run `python deploy/merge_preview.py` in fabric-workspace-docs. Open the PR `dev → main` with the `dev_to_main.md` template, covering:
  - the two new dataflows;
  - the two changed dataflows;
  - the Gold changes;
  - the new table;
  - two new shortcuts;
  - the pipeline unchanged and still claimed (X8).
- [ ] **Step 2 (Brian):** merge with **Create a merge commit**, then run **Deploy DP backend**.
- [ ] **Step 3 (Brian + Claude):**
  - run `python deploy/claim_prod_pipeline.py` (expect "unchanged → still claimed");
  - fast-forward dev: `git fetch origin && git merge --ff-only origin/main && git push origin dev`.
- [ ] **Step 4:** build the Prod staging tables. Run Prod `Pipeline_DP_Refresh` `mode=items`, `items=df_NonJD_TransferRules_Raw,df_NonJD_Transfers_Raw,df_NonJD_PartSettings_Raw,df_NonJD_OrderRules_Raw`. Then run `python deploy/sync_shortcuts.py` (dry run: expect the 2 new DP_Presentation shortcuts) and `python deploy/sync_shortcuts.py --apply`.
- [ ] **Step 5 (Brian), in one sitting, after the 07:15–10:15 publish window or with the Gateway task disabled for the duration:**
  1. Deploy app 0.5.0 to Fedora (`docs/FEDORA-TEST-DEPLOYMENT.md`). It shows "The data was published in an older format…" until step 4 of this list.
  2. Run Prod `Pipeline_DP_Refresh` `mode=items`, `items=Build_Gold_NonJD_Reorder` (logged, so the publish guard accepts it).
  3. Claude: run `nonjd_reorder_check.py --tier prod`. **Expected: both compares PASS.**
  4. Gateway PC: `git pull`, `python -m pytest -q`, then `python run_publish.py --force`. Expected: 43 files + `_meta` (v3). Re-enable the task if it was disabled.
- [ ] **Step 6 (Brian):** Ctrl+F5 on Fedora:
  - About shows 0.5.0;
  - no parity banner on Branch 1;
  - Home's numbers equal Prod Gold for Branch 1 (Claude computes them);
  - the Transfers page lists about 1,000 conventional and 500 redistribution suggestions;
  - the CSV opens in Excel.
- [ ] **Step 7:** next morning, check the scheduled 06:15 run and the 07:15 publish both succeed with v3 (`/check-refresh prod` and the app's data date).
- [ ] **Step 8:** update the round 2 spec's Progress, this plan's Progress, the app README and the memory note.

---

## Self-review against the spec

- **Phase 2 row covered:**
  - lists (E0a–e);
  - dataflows (E1);
  - reference first (E2–E3);
  - Gold Parts 1–3 + suggestion table (E4–E5);
  - publish v3 (E6);
  - app engine with phase-in, criteria, committed transfers, transfer inputs, allocation and parity (E7–E9);
  - Settings tab phase-in, quick action and Special statuses (E10);
  - Part page columns and the Above target / Excess wording (E11);
  - read-only Transfers page with CSV (E12);
  - deploy the app, then Prod Gold + publish together (E18).
- **Left for phase 3, as the spec says:**
  - ticking and preview;
  - saving transfer orders;
  - transfer order pages;
  - the Transfer rules page with Try it (X3);
  - the Home line;
  - the Reorder stepper and row detail Transfers section;
  - One-Time transfers (phase 4).
- **Calculation:**
  - steps 7b/8/8b/9, Part 2 items 1–5, Part 3 conventional, redistribution, output and determinism are in E2/E3 (tests), E4/E5 (Gold) and E8/E9 (app);
  - validation messages for transfer rules and PhaseInQty are in E3/E5/E9 and E2/E8/E10;
  - the One-Time AppInboundQty term is in E8.
- **Data model / contract:** every Gold column and contract field in the spec appears in E2–E6, plus `transferRuleId` (X6).
- **Risks:**
  - PendingQty is settled (Decision 3);
  - three implementations are covered by X10 + fuzz with planted bugs (E9);
  - the contract bump is covered by E18's order;
  - all-branch load uses the 0.4.0 loader (E9/E12).
