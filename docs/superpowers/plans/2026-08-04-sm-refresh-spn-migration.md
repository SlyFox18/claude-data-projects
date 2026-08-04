# Semantic Model Refresh — Notebook-to-Native-Activity Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Every task except Task 5 is `[MANUAL]` — Fabric portal work (pipeline canvas, connection setup, Azure AD/Fabric admin portal) with no file-based path in `data-projects`. `data-projects` is a local reference/docs workspace, not Fabric-integrated — nothing here changes what's deployed. `fabric-workspace-docs` is the Fabric Git Integration mirror and reflects what's actually live, but even there, editing the mirrored JSON does not build the pipeline for you — Fabric pipelines are built in the portal UI; the JSON is what Fabric *exports*, not what you author by hand.

**Goal:** Stop paying full Spark-session billing for 20 semantic model refreshes/day that do zero actual Spark compute work — replace `Universal_SemanticModel_Refresh_WithPolling.ipynb` (invoked once per report inside `Pipeline_SemanticModels`) with Fabric Data Factory's native **Semantic model refresh** activity, which bills at orchestration-tier rates instead of full Spark session cost.

**Architecture:** A new, parallel pipeline (`Pipeline_SemanticModels_V2`) replicates `Pipeline_SemanticModels`'s exact wave structure and dependency graph, one native Semantic model refresh activity per report instead of one `TridentNotebook` activity per report, authenticated via the already-validated `SPN-Fabric-Refresh-Automation` service principal. Built and validated in parallel with the existing notebook-based pipeline — nothing about the current daily refresh changes until cutover (Task 6), matching the same "build parallel, don't touch the stable thing in place" approach used for the Parts Lookup incremental refresh.

**Tech Stack:** Fabric Data Factory pipeline (native Semantic model refresh activity, Wait activity, Office365Email activity), Entra ID Service Principal, Fabric Admin Portal tenant settings.

**Prerequisite context (already done, don't redo):** the SPN itself (`SPN-Fabric-Refresh-Automation`), its security group, tenant-level "Service principals can call Fabric public APIs" setting, and its Power BI Service `Tenant.ReadWrite.All` API permission are already fully set up and validated — see memory `project_sm_refresh_spn_migration.md` for the complete recipe if any of this needs re-verifying. Two real refreshes already succeeded through it: Bin Location Report (2026-08-03) and Inspections (2026-08-03). This plan is specifically about scaling that proven mechanism to all 20 reports currently on the notebook.

---

## Task 1 [MANUAL]: Confirm SPN workspace access covers every target workspace

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

- [ ] **Step 3: For each of the 4 workspaces, confirm the SPN is a Contributor**

Workspace → Manage access → search `SPN-Fabric-Refresh-Automation`. Add as **Contributor** (matching the existing recipe's least-privilege level) if not already present. The recipe notes this needs no elevated role beyond normal workspace ownership — whoever already owns/admins each of these 4 workspaces can do this step directly.

---

## Task 2 [MANUAL]: Build the new pipeline shell

**Where:** Fabric, `LH_Master_Data` workspace.

- [ ] **Step 1: Create a new Data Pipeline named `Pipeline_SemanticModels_V2`**

New item, not a modification of `Pipeline_SemanticModels` — keep the notebook-based pipeline completely untouched and running normally through Task 5's validation period. Only cut over (disable the old one, promote the new one) in Task 6.

- [ ] **Step 2: Add the SPN connection once, reuse it for every activity**

In the pipeline canvas, create one new connection: **Authentication kind = Service principal**, Tenant ID, **Application (client) ID** (not the Object ID — three different GUIDs exist per app registration, this is the one from the Azure Portal App registration's Overview page, "Application (client) ID"), and the client secret **Value** (not the Secret ID). This is the exact recipe from the validated Bin Location / Inspections tests — see memory `project_sm_refresh_spn_migration.md` if either GUID needs re-finding. Every Semantic model refresh activity in this pipeline will point at this same saved connection.

---

## Task 3 [MANUAL]: Add all 20 Semantic model refresh activities, replicating the original wave structure exactly

**Where:** `Pipeline_SemanticModels_V2` canvas.

The original pipeline runs in 6 waves, each gated by a `Wait` activity that requires every activity in the previous wave to succeed before the next wave starts (`Wait_WaveA1_Gate` → `Wait_WaveA2_Gate` → `Wait_WaveA3_Gate` → `Wait_WaveA4_Gate` → `Wait_WaveB1_Gate` → `Wait_WaveB2_Gate`). Replicate this exactly — same wave grouping, same gate names, same dependency conditions (`Succeeded`) — just with a **Semantic model refresh** activity type instead of `TridentNotebook` inside each wave.

- [ ] **Step 1: Build the first activity in full, as the template for the rest**

Search the Activities pane for **Semantic model refresh** (not Script, not Notebook). Configure:
- **Name:** `Refresh_CustomerAnatomy_SM` (same naming convention as the original — keeps the eventual cutover comparison and CU tracking consistent)
- **Connection:** the SPN connection from Task 2
- **Workspace:** the workspace containing `ba9d8de4-ef13-44e6-9156-e23a2511f3ad` (resolved in Task 1)
- **Semantic model:** Customer Anatomy V2
- **Refresh type:** Full (matches what the notebook triggered — it called the refreshes API with no partition-level scoping)
- **Policy:** Timeout `0:40:00`, Retry `1`, Retry interval `120` seconds — copy these exactly from the original's `Refresh_CustomerAnatomy_SM` activity (Customer Anatomy gets a longer timeout than the rest; everything else uses `0:20:00`/`0:30:00` per the table below)
- No `dependsOn` — this is a Wave A1 activity, runs immediately when the pipeline triggers, same as the original.

- [ ] **Step 2: Run just this one activity manually and confirm it succeeds**

This validates the connection, workspace access, and model reference all work correctly for a real report from *this* pipeline before building out the other 19. Expect roughly the same duration as the original notebook took for Customer Anatomy (check `Pipeline_SemanticModels`'s run history for a baseline), but without the Spark session startup overhead — should be faster, not slower.

- [ ] **Step 3: Build the remaining 19 activities using the exact same pattern**

Full table, sourced directly from the real `Pipeline_SemanticModels.DataPipeline/pipeline-content.json` — every workspace GUID, semantic model name, wave, timeout, and dependency below is a real value from that file, not inferred:

| Wave | Activity name | Semantic model | Workspace GUID | Timeout | Depends on (gate) |
|---|---|---|---|---|---|
| A1 | `Refresh_CustomerAnatomy_SM` | Customer Anatomy V2 | `ba9d8de4-...` | 0:40:00 | *(none — wave start)* |
| A1 | `Refresh_Inspections_SM` | Inspections - V2 | `fa9b2eef-...` | 0:30:00 | *(none — wave start)* |
| A1 | `Refresh_InventoryAnalysis_SM` | Inventory Analysis | `4f2d10c6-...` | 0:30:00 | *(none — wave start)* |
| — | `Wait_WaveA1_Gate` | — | — | — | all 3 above, `Succeeded` |
| A2 | `Refresh_60PastDue_SM` | 60+ Days Past Due | `67fefa98-...` | 0:20:00 | `Wait_WaveA1_Gate` |
| A2 | `Refresh_OpenWorkOrders_SM` | Open Work Orders | `fa9b2eef-...` | 0:20:00 | `Wait_WaveA1_Gate` |
| A2 | `Refresh_PartsOnOpenOrders_SM` | Parts on Open Orders | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA1_Gate` |
| — | `Wait_WaveA2_Gate` | — | — | — | all 3 above, `Succeeded` |
| A3 | `Refresh_FirstPassFill_SM` | First Pass Fill | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA2_Gate` |
| A3 | `Refresh_NegativeOnHand_SM` | Negative On Hand-On Hand No Bin | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA2_Gate` |
| A3 | `Refresh_PartsAdjustments_SM` | Parts Adjustments | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA2_Gate` |
| — | `Wait_WaveA3_Gate` | — | — | — | all 3 above, `Succeeded` |
| A4 | `Refresh_PartSalesLowMargin_SM` | Part Sales with Low Margin | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA3_Gate` |
| A4 | `Refresh_PartsPromo_SM` | Parts Promo | `ba9d8de4-...` | 0:20:00 | `Wait_WaveA3_Gate` |
| A4 | `Refresh_Planter_Inspection_Part_Sales_SM` | Planter Inspection Part Sales - V2 | `fa9b2eef-...` | 0:20:00 | `Wait_WaveA3_Gate` |
| — | *(`Refresh_PartsNotReordered_SM` skipped — inactive in the original too, see note below)* | | | | |
| — | `Wait_WaveA4_Gate` | — | — | — | the 3 above, `Succeeded` |
| B1 | `Refresh_LaborPerformance_SM` | Labor Performance V2 | `fa9b2eef-...` | 0:20:00 | `Wait_WaveA4_Gate` |
| B1 | `Refresh_UniquePartsCustomers_SM` | Unique Parts Customers | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA4_Gate` |
| B1 | `Refresh_CombineVault_SM` | Combine Vault Sales | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA4_Gate` |
| B1 | `Refresh_Transfers_SM` | Transfers | `4f2d10c6-...` | 0:20:00 | `Wait_WaveA4_Gate` |
| — | `Wait_WaveB1_Gate` | — | — | — | all 4 above, `Succeeded` |
| B2 | `Refresh_PinCapture_SM` | Pin Capture | `4f2d10c6-...` | 0:20:00 | `Wait_WaveB1_Gate` |
| B2 | `Refresh_PhysicalInventory_SM` | Physical Inventory | `4f2d10c6-...` | 0:20:00 | `Wait_WaveB1_Gate` |
| B2 | `Refresh_MD_Invoices_With_No_Freight_SM` | MD Invoices With No Freight | `ba9d8de4-...` | 0:20:00 | `Wait_WaveB1_Gate` |
| B2 | `Refresh_PriceMatrix_SM` | Price Matrix | `4f2d10c6-...` | 0:20:00 | `Wait_WaveB1_Gate` |
| — | `Wait_WaveB2_Gate` | — | — | — | all 4 above, `Succeeded` |

Use retry `1`, retry interval `60` seconds for every activity in this table (Customer Anatomy in Wave A1 is the one exception, at `120` seconds retry interval, per Step 1).

**Note on `Refresh_PartsNotReordered_SM`:** the original has this activity present but set to `"state": "Inactive"` with `"onInactiveMarkAs": "Succeeded"` — it's wired into the dependency graph but doesn't actually run, and its skip is treated as a pass so downstream waves aren't blocked. Don't build this one in the new pipeline; just don't make anything downstream depend on it (the table above already reflects this — `Wait_WaveA4_Gate` only waits on the 3 *active* Wave A4 activities).

**Discrepancy worth flagging, not silently resolving:** `Price Matrix` is in this daily pipeline (Wave B2) per the real JSON, but `CLAUDE.md` describes Price Matrix as a **Tier 3 weekly-only** report alongside Bin Location. Either `CLAUDE.md` is stale, or Price Matrix was moved to daily refresh at some point without updating it, or there's a second weekly refresh mechanism for it too. Don't try to resolve this by guessing — Task 7 below covers checking it directly.

- [ ] **Step 4: Add the notification activities**, same structure as the original — one success email after `Wait_WaveB2_Gate` succeeds, two failure alerts:

```
Success email — depends on Wait_WaveB2_Gate, Succeeded
Subject: "✅ Pipeline_SemanticModels_V2 - All Reports Refreshed"

Tier A failure alert — depends on Wait_WaveA4_Gate, [Failed, Skipped]
Subject: "❌ Pipeline_SemanticModels_V2 - Tier 1 SM Refresh Failed"

Tier B failure alert — depends on Wait_WaveB2_Gate, [Failed, Skipped]
Subject: "❌ Pipeline_SemanticModels_V2 - Tier 2 SM Refresh Failed"
```
Reuse the same Office 365 connection the original uses (`externalReferences.connection: "97d3696e-b886-4770-9fd0-f4aae4c6a7ed"` in the original's JSON — same connection should already be available in the connection picker), same recipient (`bfox@spitractor.com`).

---

## Task 4 [MANUAL]: Validate — run manually several times before touching any schedule

**Where:** Fabric pipeline canvas + Capacity Metrics / CU tracking.

- [ ] **Step 1: Run `Pipeline_SemanticModels_V2` manually end-to-end**, off-hours if possible (avoid stacking with the live 6:30 AM notebook-based run). Confirm all 6 waves complete and the success email arrives.

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
