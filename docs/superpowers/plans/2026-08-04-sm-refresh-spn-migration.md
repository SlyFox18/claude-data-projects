# Semantic Model Refresh — Notebook-to-Native-Activity Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Every task except Task 5 is `[MANUAL]` — Fabric portal work (pipeline canvas, connection setup, Azure AD/Fabric admin portal) with no file-based path in `data-projects`. `data-projects` is a local reference/docs workspace, not Fabric-integrated — nothing here changes what's deployed. `fabric-workspace-docs` is the Fabric Git Integration mirror and reflects what's actually live, but even there, editing the mirrored JSON does not build the pipeline for you — Fabric pipelines are built in the portal UI; the JSON is what Fabric *exports*, not what you author by hand.

**Goal:** Stop paying full Spark-session billing for 20 semantic model refreshes/day that do zero actual Spark compute work — replace `Universal_SemanticModel_Refresh_WithPolling.ipynb` (invoked once per report inside `Pipeline_SemanticModels`) with Fabric Data Factory's native **Semantic model refresh** activity, which bills at orchestration-tier rates instead of full Spark session cost.

**Architecture:** A new, parallel pipeline (`Pipeline_SemanticModels_V2`) replicates `Pipeline_SemanticModels`'s exact wave structure and dependency graph, one native Semantic model refresh activity per report instead of one `TridentNotebook` activity per report, authenticated via the already-validated `SPN-Fabric-Refresh-Automation` service principal. Built and validated in parallel with the existing notebook-based pipeline — nothing about the current daily refresh changes until cutover (Task 6), matching the same "build parallel, don't touch the stable thing in place" approach used for the Parts Lookup incremental refresh.

**Tech Stack:** Fabric Data Factory pipeline (native Semantic model refresh activity, Wait activity, Office365Email activity), Entra ID Service Principal, Fabric Admin Portal tenant settings.

**Prerequisite context (already done, don't redo):** the SPN itself (`SPN-Fabric-Refresh-Automation`), its security group, tenant-level "Service principals can call Fabric public APIs" setting, and its Power BI Service `Tenant.ReadWrite.All` API permission are already fully set up and validated — see memory `project_sm_refresh_spn_migration.md` for the complete recipe if any of this needs re-verifying. Two real refreshes already succeeded through it: Bin Location Report (2026-08-03) and Inspections (2026-08-03). This plan is specifically about scaling that proven mechanism to all 20 reports currently on the notebook.

---

## Task 1 [DONE, via `fab` CLI API passthrough]: Confirm SPN workspace access covers every target workspace

**Where:** Fabric portal (workspace access) + `fab` CLI (to resolve workspace GUIDs to names).

The existing recipe added the SPN as Contributor to "the target report workspace" one at a time as each test report was migrated. Scaling to 20 reports means confirming coverage across *every* workspace those reports actually live in — don't assume it's just `RP - Parts Reports`.

- [ ] **Step 1: Get the real, distinct workspace GUIDs from the current pipeline**

Pulled directly from `fabric-workspace-docs/workspaces/LH_Master_Data/Pipelines/Pipeline_SemanticModels.DataPipeline/pipeline-content.json` (not guessed — this is every `workspace_id` value actually used across the 20 `TridentNotebook` activities):

| Workspace GUID | Reports using it |
|---|---|
| `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` | Inventory Analysis, Parts on Open Orders, First Pass Fill, Negative On Hand-On Hand No Bin, Parts Adjustments, Part Sales with Low Margin, Parts Not Re-Ordered 24 Hours (currently inactive), Unique Parts Customers, Combine Vault Sales, Transfers, Pin Capture, Physical Inventory, Price Matrix |
| `fa9b2eef-d507-48ad-bbeb-242037941987` | Inspections - V2, Open Work Orders, Labor Performance V2, Planter Inspection Part Sales - V2 |
| `ba9d8de4-ef13-44e6-9156-e23a2511f3ad` | Customer Anatomy V2, Parts Promo, MD Invoices With No Freight |
| `67fefa98-9e80-4a79-afdd-c8988b6e64fc` | 60+ Days Past Due |

- [ ] **Step 2: Resolve each GUID to a workspace name**

```bash
fab api -A powerbi "groups/4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7" | grep -i name
fab api -A powerbi "groups/fa9b2eef-d507-48ad-bbeb-242037941987" | grep -i name
fab api -A powerbi "groups/ba9d8de4-ef13-44e6-9156-e23a2511f3ad" | grep -i name
fab api -A powerbi "groups/67fefa98-9e80-4a79-afdd-c8988b6e64fc" | grep -i name
```
(If `fab api -A powerbi` isn't the right syntax for a raw Power BI REST passthrough in your installed CLI version, the workspace name is also visible by opening `https://app.powerbi.com/groups/<guid>/list` directly in a browser — faster if the CLI call doesn't cooperate.)

- [x] **Step 3: For each of the 4 workspaces, confirm the SPN is a Contributor** — done 2026-08-04 via `fab api workspaces/{id}/roleAssignments -A fabric`. Real results: workspace names resolved to `RP - Parts Reports`, `RP - Service Reports`, `RP - Sandbox`, `RP - Financial Reports` (via `fab api groups/{id} -A powerbi -q text.name`). `SPN-Fabric-Refresh-Automation` (principal id `8f71b80d-2698-42db-82cf-10ef0ffb8f12`) already had Contributor on Parts/Service/Financial Reports from earlier setup work — only `RP - Sandbox` was missing it (confirmed by listing all principals: only human users present), added via `POST roleAssignments` with `{"principal":{"id":"8f71b80d-...","type":"ServicePrincipal"},"role":"Contributor"}` → `201 Created`.

**Correction found during Task 2/3 (see Task 3's note):** it later turned out the 3 reports the stale pipeline JSON had placed in `RP - Sandbox` (Customer Anatomy V2, Parts Promo, MD Invoices With No Freight) have all since moved to production workspaces — meaning `RP - Sandbox` isn't actually needed for any of the real 20 reports. Harmless to leave the SPN's access there regardless (may be useful for other work later), just noting it turned out to be unnecessary for this specific migration.

---

## Task 2 [MANUAL]: Build the pipeline shell and validate the `ForEach` + dynamic-content pattern before committing to it

**Where:** Fabric, `LH_Master_Data` workspace.

**Design change from the original plan (2026-08-04, after discussion with Brian):** rather than replicating the original's 6 hand-wired waves (`Wait_WaveA1_Gate` → ... → `Wait_WaveB2_Gate`, 3-4 activities each), use a **`ForEach` activity with `batchCount`** per tier instead. Reasoning: the original wave design's real goal (confirmed by Brian) was grouping longer-running reports together to reduce total pipeline wall-clock time — but a hard wave gate waits for *every* activity in the wave to finish before the next wave starts, even if a slot sat idle because a short report in that wave finished early. A `ForEach` with `batchCount` is a continuous worker pool — Microsoft's own docs describe `batchCount` as "the upper concurrency limit, but the for-each activity will not always execute at this number," meaning the moment one item finishes, the next queued item starts immediately in the freed slot. Ordering items longest-duration-first (the "Longest Processing Time first" scheduling heuristic) and letting the pool refill continuously achieves the original goal *better* than hard-gated waves: using real durations pulled from `Pipeline_SemanticModels`'s run history on 2026-08-04, the current wave design totals ~18.7 minutes wall-clock; the same 20 reports through two `batchCount=4` `ForEach` loops (Tier 1, Tier 2 — preserving the original's real business-priority split, not the internal wave subdivision) is estimated at ~10-11 minutes.

**This is only worth doing if the Semantic model refresh activity's Workspace/Dataset fields actually accept `@item()` dynamic content inside a `ForEach`** — unconfirmed from docs alone (they explicitly confirm dynamic content works for table/partition-level settings, which is a strong signal, but doesn't say so for Workspace/Dataset specifically). Step 3 below validates this directly, cheaply, before committing to building all 20 around it — same "test small before building the full thing" discipline used throughout the Parts Lookup build.

- [ ] **Step 1: Create a new Data Pipeline named `Pipeline_SemanticModels_V2`**

New item, not a modification of `Pipeline_SemanticModels` — keep the notebook-based pipeline completely untouched and running normally through Task 4's validation period. Only cut over (disable the old one, promote the new one) in Task 6. If you already have the 2-activity "Sequence multiple semantic models" template scaffolded under this name, that's fine as a starting canvas — Step 3 below will replace those two activities.

- [ ] **Step 2: Add the SPN connection once, reuse it for every activity**

In the pipeline canvas, create one new connection: **Authentication kind = Service principal**, Tenant ID, **Application (client) ID** (not the Object ID — three different GUIDs exist per app registration, this is the one from the Azure Portal App registration's Overview page, "Application (client) ID"), and the client secret **Value** (not the Secret ID). This is the exact recipe from the validated Bin Location / Inspections tests — see memory `project_sm_refresh_spn_migration.md` if either GUID needs re-finding. Every Semantic model refresh activity in this pipeline will point at this same saved connection.

- [ ] **Step 3: Validate `ForEach` + dynamic content with a 2-item test before building the full design**

Add a `ForEach` activity (Activities pane → search "ForEach"). Settings tab: `Sequential` unchecked, `Batch count` = `2`. Items field — use the expression builder (pencil/lightning icon) and enter:
```
@json('[{"name":"Customer Anatomy V2","workspaceId":"ba9d8de4-ef13-44e6-9156-e23a2511f3ad","datasetId":"fd9cf725-0db8-429f-a9ab-efd2fe916c2b"},{"name":"Inspections - V2","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"39074778-3a2e-40b7-a30a-afd21f12268c"}]')
```
Inside the `ForEach`'s own Activities pane, add one **Semantic model refresh** activity, connection = the SPN connection from Step 2. On the Workspace and Dataset/Semantic model fields, look for the dynamic-content option (usually a small icon next to the field, same UI pattern as every other Fabric pipeline activity) and set them to `@item().workspaceId` and `@item().datasetId` respectively (exact property-path syntax will be confirmed by the UI's own expression picker — trust what it shows over this guess if they differ).

Run just this `ForEach` activity. **Confirm both Customer Anatomy V2 and Inspections - V2 actually refresh** (check "Last Refreshed" timestamps on both models in the Power BI service afterward) — not just that the activity reports success, since a misconfigured dynamic-content reference could easily refresh the same model twice instead of two different ones without erroring.

- [x] **Step 3 succeeded** (confirmed 2026-08-04, after also surviving a genuine retry test): `@item().workspaceId`/`@item().datasetId` dynamic content works correctly on the Semantic model refresh activity's Workspace/Dataset fields. Proven with two different real reports (Customer Anatomy V2, Inspections) both refreshing correctly and independently — no cross-contamination between loop iterations. One transient failure occurred on the first parallel run (Inspections, `DataflowPipelineSendOrReceiveError`/canceled) but succeeded cleanly on immediate retry with zero changes — consistent with a one-off blip, not a design flaw. **Proceed to Task 3.**

---

## Task 3 [MANUAL]: Build the two-tier `ForEach` design (if Task 2 Step 3 succeeded)

**Where:** `Pipeline_SemanticModels_V2` canvas.

**Important correction made 2026-08-04, during Task 2's validation test:** the workspace/dataset GUIDs pulled from `fabric-workspace-docs`'s `Pipeline_SemanticModels.DataPipeline/pipeline-content.json` turned out to be stale for 3 of the 20 reports — that JSON snapshot predates some report promotions from `RP - Sandbox` to production workspaces, and the local git mirror is 15 commits behind besides. The Task 2 validation test's Customer Anatomy attempt failed with `ItemNotFound` because of exactly this — the old dataset id no longer exists at all. Cross-checked every one of the 4 workspaces' live dataset lists (via `fab api groups/{id}/datasets`) against the full 20-report list before writing the items below; the other 17 all matched correctly on ID (a few have cosmetic display-name changes only — "Inspections - V2" is now just "Inspections," "Labor Performance V2" is now "Labor Performance," etc. — dataset ID is what's referenced below, not the display name, so those don't matter). Three genuinely needed correcting, confirmed directly with Brian for the one that was ambiguous (two different "Customer Anatomy"-named models exist across workspaces):

| Report | Stale value (don't use) | Corrected, verified live 2026-08-04 |
|---|---|---|
| Customer Anatomy V2 | `RP - Sandbox` / `fd9cf725-...` (doesn't exist anymore — this is what actually threw `ItemNotFound`) | `RP - Service Reports` (`fa9b2eef-d507-48ad-bbeb-242037941987`) / `22e741eb-afe5-45c9-b0a6-bfda35830977` |
| Parts Promo | `RP - Sandbox` / `80eab99c-...` (no longer exists in Sandbox at all) | `RP - Parts Reports` (`4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`) / `3d4f1acf-f409-41a5-acc4-7be61b101a15` |
| MD Invoices With No Freight | `RP - Sandbox` / `fd436ed4-...` (no longer exists in Sandbox at all) | `RP - Parts Reports` (`4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`) / `88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d` |

Both corrected workspaces already have the SPN as Contributor from Task 1 — no new access grant needed. The items JSON below already reflects these corrections.

- [ ] **Step 1: Build the Tier 1 `ForEach`**

Name it `ForEach_Tier1_SM_Refresh`. Settings: `Sequential` unchecked, `Batch count` = `4` (matches this org's established "4-5 concurrent" ceiling for this same F4 capacity, used elsewhere for concurrent dataflow waves — start here rather than assuming native activities allow more just because they're cheaper to trigger; the underlying refresh work itself still consumes real capacity). Items, ordered longest-duration-first (real durations pulled from `Pipeline_SemanticModels`'s run history, 2026-08-04):

```json
[
  {"name":"Inspections - V2","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"39074778-3a2e-40b7-a30a-afd21f12268c"},
  {"name":"Parts Promo","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"3d4f1acf-f409-41a5-acc4-7be61b101a15"},
  {"name":"Customer Anatomy V2","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"22e741eb-afe5-45c9-b0a6-bfda35830977"},
  {"name":"Inventory Analysis","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"bd49c7c7-4f9d-4475-ac2e-c5d19da56297"},
  {"name":"Part Sales with Low Margin","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"412c8395-7a2f-480c-996b-53af35a3ec02"},
  {"name":"Parts Adjustments","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"97fc2743-290c-46fb-a033-d12a20f8759b"},
  {"name":"First Pass Fill","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"af0e6d01-3bb2-4ac8-a41a-87a10885ba9c"},
  {"name":"Open Work Orders","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"cdb3ffdb-a3d4-4d98-aeba-2e711c360fed"},
  {"name":"Parts on Open Orders","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"beb18435-991c-40a1-82a9-0e4500c0d106"},
  {"name":"60+ Days Past Due","workspaceId":"67fefa98-9e80-4a79-afdd-c8988b6e64fc","datasetId":"2516982b-f52f-4676-b879-525e089e9b9e"},
  {"name":"Negative On Hand-On Hand No Bin","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"e0f4c5ff-8195-463f-9d10-eb1936479684"},
  {"name":"Planter Inspection Part Sales - V2","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"cb25d470-96b5-4ae0-83e9-4cef6c930fe2"}
]
```

Inside, one Semantic model refresh activity (same as Task 2 Step 3's validated pattern): Connection = SPN connection, Workspace = `@item().workspaceId`, Dataset = `@item().datasetId`, Refresh type = Full, Timeout `0:20:00` (use `0:40:00` if Inspections alone ever needs more headroom — it was the slowest at 5m55s, well under 20 min, but native-activity timing may differ slightly from the notebook's), Retry `1`, Retry interval `60` seconds.

**Note on `Parts Not Re-Ordered 24 Hours`:** intentionally excluded from this list — it's inactive in the original pipeline too (has its own separate `Pipeline_PartsNotReordered_QuickRefresh`, see Task 7).

**Discrepancy worth flagging, not silently resolving:** `Price Matrix` is in this daily list per the real JSON, but `CLAUDE.md` describes it as **Tier 3 weekly-only** alongside Bin Location. Task 7 covers checking this directly rather than guessing which is stale.

- [ ] **Step 2: Add a gate after Tier 1** — a `Wait` activity (`waitTimeInSeconds: 1`, matching the original's gate pattern), named `Wait_Tier1_Gate`, depending on `ForEach_Tier1_SM_Refresh` with condition `Succeeded`.

- [ ] **Step 3: Build the Tier 2 `ForEach`**, named `ForEach_Tier2_SM_Refresh`, depending on `Wait_Tier1_Gate` (`Succeeded`). Same settings (`Sequential` unchecked, `Batch count` = `4`, Timeout `0:20:00`, Retry `1`/`60`s). Items, longest-duration-first:

```json
[
  {"name":"Transfers","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"47405102-4966-4658-9a49-6457d0a617ff"},
  {"name":"Pin Capture","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"f7ab2948-e3ae-42c9-833e-61f5f955c790"},
  {"name":"Price Matrix","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"4ef73ecc-d314-435c-8ad8-20473eb929fb"},
  {"name":"Physical Inventory","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"80c1dc15-60b3-4c6a-9398-3c79b77a4667"},
  {"name":"Combine Vault Sales","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"6b854ef2-4115-496a-bf71-2509fce18406"},
  {"name":"MD Invoices With No Freight","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d"},
  {"name":"Labor Performance V2","workspaceId":"fa9b2eef-d507-48ad-bbeb-242037941987","datasetId":"66a341a6-48f6-41dd-8c35-b1c6e6b0baed"},
  {"name":"Unique Parts Customers","workspaceId":"4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7","datasetId":"ed4f7c28-5555-4129-aa84-28d6d1e31e1b"}
]
```

- [ ] **Step 4: Add a final gate + notification activities**

`Wait_Tier2_Gate` depending on `ForEach_Tier2_SM_Refresh` (`Succeeded`). Then, same structure as the original:

```
Success email — depends on Wait_Tier2_Gate, Succeeded
Subject: "✅ Pipeline_SemanticModels_V2 - All Reports Refreshed"

Tier 1 failure alert — depends on Wait_Tier1_Gate, [Failed, Skipped]
Subject: "❌ Pipeline_SemanticModels_V2 - Tier 1 SM Refresh Failed"

Tier 2 failure alert — depends on Wait_Tier2_Gate, [Failed, Skipped]
Subject: "❌ Pipeline_SemanticModels_V2 - Tier 2 SM Refresh Failed"
```
Reuse the same Office 365 connection the original uses (`externalReferences.connection: "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"` in the original's JSON), same recipient (`bfox@spitractor.com`).

**Expected total wall-clock time:** ~10-11 minutes (Tier 1 ~7 min + gate + Tier 2 ~3.3 min + email), versus the original's ~18.7 minutes — confirm this in Task 4's validation runs rather than taking the estimate on faith.

---

## Task 3-Alt [MANUAL, fallback only — skip if Task 3 was used]: Hand-wired duration-balanced lanes

Only build this if Task 2 Step 3's validation showed the Semantic model refresh activity's Workspace/Dataset fields don't support `@item()` dynamic content. This keeps the "group by duration to minimize wall-clock time" goal without `ForEach` — 4 explicit lanes per tier, each a simple chain where **each activity depends only on the previous activity in its own lane**, not on every other lane (this is the key difference from the original design — no monolithic wave gate forcing every lane to wait for the slowest one).

**Tier 1 lanes** (each activity uses its own real Workspace GUID/Timeout from Task 3's Step 1 list above; only the `dependsOn` chain changes):
| Lane | Sequence |
|---|---|
| 1 | Inspections - V2 → Negative On Hand-On Hand No Bin |
| 2 | Parts Promo → Open Work Orders → Planter Inspection Part Sales - V2 |
| 3 | Customer Anatomy V2 → Parts Adjustments → First Pass Fill |
| 4 | Inventory Analysis → Part Sales with Low Margin → Parts on Open Orders → 60+ Days Past Due |

**Tier 2 lanes:**
| Lane | Sequence |
|---|---|
| 1 | Transfers → Unique Parts Customers |
| 2 | Pin Capture → Labor Performance V2 |
| 3 | Price Matrix → MD Invoices With No Freight |
| 4 | Physical Inventory → Combine Vault Sales |

A `Wait_Tier1_Gate` still depends on the *last* activity in all 4 Tier 1 lanes (`Succeeded`) before Tier 2 starts, and the notification activities work the same as Task 3 Step 4 — the only structural change from the original is replacing "3-4 activities all gated together per wave" with "4 independent lane-chains gated together only at the tier boundary."

---

## Task 4 [MANUAL]: Validate — run manually several times before touching any schedule

**Where:** Fabric pipeline canvas + Capacity Metrics / CU tracking.

- [ ] **Step 1: Run `Pipeline_SemanticModels_V2` manually end-to-end**, off-hours if possible (avoid stacking with the live 6:30 AM notebook-based run). Confirm both `ForEach` tiers (or all 8 lanes, if using Task 3-Alt) complete and the success email arrives. Record the actual total wall-clock time and compare against the ~10-11 minute estimate.

- [ ] **Step 2: Spot-check 2-3 refreshed reports in the Power BI service** — open Customer Anatomy V2, Inspections - V2, and one Tier 2 report, confirm "Last Refreshed" timestamp matches this test run, not stale data.

- [ ] **Step 3: Repeat for 2-3 more days**, alongside (not replacing) the normal daily run, to build real comparison data — don't cut over after just one clean run.

- [ ] **Step 4: Compare CU cost** once a few days of data exist, using the `CU-Tracking.html` dashboard (see Task 5 first to make sure `Pipeline_SemanticModels_V2` is actually being tracked). Expect the new pipeline's total to be dramatically lower than the notebook's ~216K CU(s)/14-day figure — confirm this before cutover, don't assume it based on the theory alone.

---

## Task 5 [AUTOMATABLE]: Track the new pipeline's CU usage

**Files:**
- Modify: `projects/fabric-monitoring/scripts/enhanced/Track-ItemCU.ps1`

- [ ] **Step 1: Add `Pipeline_SemanticModels_V2` to the tracked items list**

Find the `$TrackedItems` parameter default (currently includes `Universal_SemanticModel_Refresh_WithPolling`, `Pipeline_SM_Refresh_TEST`, `Bin Location Report`, `Inspections`, `parts-lookup-app`) and add the new pipeline:

```powershell
[string[]]$TrackedItems = @(
    "Universal_SemanticModel_Refresh_WithPolling",
    "Pipeline_SM_Refresh_TEST",
    "Pipeline_SemanticModels_V2",
    "Bin Location Report",
    "Inspections",
    "parts-lookup-app"
),
```

- [ ] **Step 2: Run it once manually to confirm the new item resolves**

```powershell
.\Track-ItemCU.ps1
```
Check the output for a warning like `[WARNING] Not found in Items table` — if `Pipeline_SemanticModels_V2` appears there, it likely just needs another day for Fabric's own metrics ingestion to catch up (same "known minor gap" the memory notes happened with `Pipeline_SM_Refresh_TEST` initially) — not a real problem, just re-run tomorrow.

- [ ] **Step 3: Commit**
```bash
git add "projects/fabric-monitoring/scripts/enhanced/Track-ItemCU.ps1"
git commit -m "Track Pipeline_SemanticModels_V2 CU usage during SM refresh migration validation"
```

---

## Task 6 [MANUAL]: Cutover

**Where:** Fabric pipeline canvas, both pipelines.

Only start this task once Task 4's multi-day CU comparison actually confirms real savings — don't cut over on faith.

- [ ] **Step 1: Copy `Pipeline_SemanticModels`'s exact schedule to `Pipeline_SemanticModels_V2`**

Per `pipeline-schedule.md`: 6:30 AM CST, Monday-Friday (runs after `Pipeline_Master_Orchestrator` completes, ~5:27 AM). Set the same schedule on the new pipeline.

- [ ] **Step 2: Disable `Pipeline_SemanticModels`'s schedule** (don't delete the pipeline itself yet — keep it as a fallback for a week or two in case the new one has an issue the validation period didn't catch).

- [ ] **Step 3: Watch the first few real scheduled runs closely** — check the success email arrives each morning, spot-check a couple of reports for fresh data, and keep an eye on Capacity Metrics for `fabric1cap1` to confirm the notebook's ~216K CU(s)/14-day baseline actually starts dropping.

- [ ] **Step 4: After 1-2 clean weeks, disable (don't necessarily delete) `Pipeline_SemanticModels` and `Universal_SemanticModel_Refresh_WithPolling`** entirely, and remove them from `Track-ItemCU.ps1`'s `$TrackedItems` list (or leave them — a flatlined CU trend for a disabled item is itself useful confirmation the migration held).

---

## Task 7 [MANUAL]: Verify and migrate `Pipeline_Weekly_Tier3`

**Where:** Fabric portal (this pipeline doesn't exist in the local `fabric-workspace-docs` mirror — that repo is currently 15 commits behind `origin/dev`, so this may just be sync lag, not a real absence. Check the actual Fabric workspace directly, don't assume from the local files.)

- [ ] **Step 1: Confirm the pipeline exists and find its real name** — `pipeline-schedule.md` refers to it generically as "Weekly Pipeline (Tier 3)," scheduled Monday 5:00 AM, but the actual Fabric item name isn't confirmed anywhere in this repo. Check the `LH_Master_Data` workspace directly.

- [ ] **Step 2: If it exists and also uses `TridentNotebook` activities calling `Universal_SemanticModel_Refresh_WithPolling`**, repeat the same pattern as Tasks 2-3 above for whatever reports it actually contains (per `CLAUDE.md`, expected to be Price Matrix and Bin Location — but confirm directly, especially given Task 3's discrepancy note that Price Matrix already appears in the *daily* pipeline too. It's possible this weekly pipeline only still has Bin Location, or CLAUDE.md's tier categorization is simply out of date.) Bin Location Report already has a validated working test refresh from 2026-08-03 (`Refresh_BinLocation_TEST` in `Pipeline_SM_Refresh_TEST`) — that activity's exact configuration can likely be copied directly into whatever new/existing pipeline replaces this one.

- [ ] **Step 3: If it doesn't exist under that name, or doesn't use the notebook pattern at all**, update this plan and memory `project_sm_refresh_spn_migration.md` with what you actually find — don't leave the stale assumption in place for a future session to trip over.

---

## Task 8 [AUTOMATABLE]: Update documentation

**Files:**
- Modify: `projects/refresh-pipeline/pipeline-schedule.md`

- [ ] **Step 1: Update the "Pipeline_SemanticModels" references** in the schedule timeline to reflect the new pipeline name (`Pipeline_SemanticModels_V2`, or renamed back to `Pipeline_SemanticModels` once the old one is fully decommissioned, whichever naming Brian prefers by the time Task 6 completes).

- [ ] **Step 2: Commit**
```bash
git add "projects/refresh-pipeline/pipeline-schedule.md"
git commit -m "Update pipeline-schedule.md for SM refresh notebook-to-native-activity migration"
```

---

## Self-Review Notes

- **Spec coverage:** every "still pending" item from memory `project_sm_refresh_spn_migration.md` has a task here — build the full pipeline (Task 2-3), validate before cutover (Task 4), CU tracking (Task 5), cutover (Task 6), the Tier 3 weekly pipeline (Task 7).
- **Honesty check on things I couldn't confirm:** workspace *names* for the 4 GUIDs in Task 1 (only GUIDs are confirmed from the real JSON — resolving to names is Task 1's own first step, not assumed here), and `Pipeline_Weekly_Tier3`'s real name/existence/contents (Task 7 verifies rather than assumes). Both are flagged as verification steps rather than guessed at, on purpose — getting either wrong would send Brian chasing a workspace or pipeline that doesn't match reality.
- **Deviation from the existing recipe worth flagging:** the validated test pipeline (`Pipeline_SM_Refresh_TEST`) has two individual test activities, not the full wave structure. This plan builds a *new, complete* pipeline replicating the full production dependency graph rather than incrementally growing the test pipeline into production — cleaner to reason about and matches the "parallel, not in-place" pattern already validated on the Parts Lookup project, but means `Pipeline_SM_Refresh_TEST` itself becomes throwaway once this is built (worth deleting in Task 6 or leaving as a low-cost historical reference — Brian's call).
- **Design revision (2026-08-04, same day, before any building started):** replaced the originally-planned direct replication of the 6 hand-wired waves with a `batchCount`-driven `ForEach` per tier, after discussing with Brian that the original wave grouping's real intent was minimizing total wall-clock time by grouping longer reports together — a goal a continuous worker-pool (`ForEach`) achieves better than hard wave gates, per Microsoft's own description of `batchCount` as an upper concurrency limit rather than lockstep batching. Real run-history durations (pulled 2026-08-04) back this with concrete numbers: ~18.7 min estimated for the original design vs. ~10-11 min for the `ForEach` redesign. A hand-wired fallback (Task 3-Alt) exists in case the Semantic model refresh activity's Workspace/Dataset fields turn out not to support `@item()` dynamic content — validated as its own explicit step (Task 2 Step 3) before committing to building all 20 reports around the assumption.
- **Also confirmed with Brian directly (2026-08-04):** the reports refreshing independently outside this pipeline (Parts Not Re-Ordered on its own pipeline; Service Time Sheets, Parts Action Dashboard, Stock Check, and Job Code Parts Advisor all on Power BI's native scheduled refresh, no pipeline at all) were deliberately spread across different morning time slots (7am/8am/9:30am/10am/11am) specifically to avoid concentrating load — intentionally left out of `Pipeline_SemanticModels_V2` rather than folded in, so as not to undo that spreading.
