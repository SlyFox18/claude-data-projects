# DP Backend Refresh Pipeline — Current State & Assessment

**Date:** 2026-09-25
**Status:** Schedules PAUSED. The design fix is deferred until Inspections and Customer Anatomy are migrated.
**Related:** `report-migration-catalog.md`, `data-platform-workspaces.md`, `fabric-workspace-docs/deploy/dp_backend_scope.json`

---

## 1. Where we stand (summary)

- Every other in-scope report now reads from DP_Presentation in `RP - Dev` (see `report-migration-catalog.md`). Only **Inspections** and **Customer Anatomy** remain.
- None of the production workspaces (Parts, Service, Financial Reports) reads DP yet. `RP - Sandbox` holds 4 DP reports: 60+ Days Past Due, Bin Location, Parts Promo, and Physical Inventory.
- The DP refresh pipelines work mechanically, but they only know about **38 of roughly 91 producers**. **53 producers have no schedule at all:**
  - 15 Silver notebooks
  - 2 Staging dataflows
  - 36 Gold notebooks

  So "migrated" reports refresh unevenly. Some don't refresh at all, and some run Gold daily on top of Silver that stopped updating around 09-10.
- **All 3 DP pipeline schedules were paused on 2026-09-25.** Only `enabled` was changed; the schedule configurations are kept. The reason is to stop spending capacity twice (old LH_Master_Data orchestrator + DP) before cutover. From now on, pipelines run manually when needed.

| Pipeline | Item ID | Schedule (kept, disabled) |
|---|---|---|
| `Pipeline_DP_Daily_Refresh` | `1aa4e9c9-53b2-4662-9fb2-2408ec448c4f` | Weekly Mon–Fri 04:15 CST |
| `Pipeline_DP_Monthly_Refresh` | `b29af004-05f9-487f-ba51-e602cd99ca25` | Monthly, day 1, 07:30 |
| `Pipeline_DP_SemanticModel_Refresh` | `ab8acd2f-3c19-4156-993d-a6a2270718ed` | Weekly Mon–Fri 06:30 |

To re-enable a schedule, send `PATCH workspaces/73fd5443-…/items/{id}/jobs/Pipeline/schedules/{scheduleId}` with `{"enabled": true, "configuration": <existing>}`.

---

## 2. How the pipeline works today

```
Lookup_Config  (reads DP_Presentation Files/config/dp_backend_scope.json)
  → Filter tier=silver & cadence=daily → ForEach (batchCount 3, parallel) → run notebook
  → gate
  → Filter tier=gold & cadence=daily   → ForEach (batchCount 3, parallel) → run notebook
  → email summary
```

- **Config-driven.** Each entry in the config supplies `notebookId`, `workspaceId`, `tier` and `cadence`. The notebook activity binds `@item().notebookId` and `@item().workspaceId` dynamically.
- **The pipeline reads a deployed copy of the config**, which sits in the Lakehouse *Files* area. It does not read the repo file (`fabric-workspace-docs/deploy/dp_backend_scope.json`). The copy is refreshed automatically: every push to `dev` runs GitHub Actions (`deploy.yml` → `deploy_backend.py`). That run rewrites the config in both Dev lakehouses. (Corrected 2026-09-25; this doc originally said the copy needed a manual re-upload.)
- **Single writer per workspace (changed 2026-09-25).** Until then, CI also published every registered notebook into the Git-connected Dev workspaces with fabric-cicd. That made two writers, and it left 16 notebooks unlinked from their Git files ("split identity", Added on both sides), which were repaired by re-committing them from the workspace with their object IDs preserved. Now:
  - Dev notebook code arrives **only through Fabric Git sync** (Update from Git; scripted as `tools/dp-migration/git_sync.py`).
  - CI's Dev job only writes the config and checks that the registered folders exist.
  - New notebooks are created by pushing their folder and syncing, never with `fab import`.
  - fabric-cicd publishing is reserved for Prod, which is not Git-connected.
- **It runs notebooks only.** It cannot run a Dataflow Gen2, which matters because two Staging pulls are ODBC dataflows (see §3).
- **Two ordering levels only: Silver then Gold.** Nothing orders Gold notebooks among themselves (see §3).
- **Catch-and-continue:** one failed notebook doesn't stop the rest, and the email reports the failures.
- `Pipeline_DP_SemanticModel_Refresh` refreshes the report semantic models after the data pipeline.

---

## 3. Problems found (dependency map, 2026-09-24)

### 3a. Unscheduled producers (53)

| Layer | Count | Items |
|---|---|---|
| Silver notebooks | 15 | WkOthSub, WkRoFile, Invoice, TechnicianPunchedDetail, WkMechWk, WkMechFl, WkRoDesc, VhStock, VhSalman, WkMechAdj, WkCodeFl, WKCDPART, InHist_PmManage, WkVehFl, WkInvReg |
| Staging Dataflow Gen2 (ODBC) | 2 | `df_RepairOrderDetail_Raw`, `df_InSalPar_Audit_Raw`. Neither has a schedule; both last ran 09-10. |
| Gold notebooks | 36 | Includes most of the fact notebooks from the facts-catalog audit (Customer Anatomy's chain among them) |

### 3b. Report impact

- **No refresh since mid-September:** Inventory Analysis, Price Matrix, Parts Adjustments, Parts Promo, Unique Parts Customers, Negative On Hand, Parts Not Re-Ordered, Planter, Stock Check.
- **Gold runs daily but its Silver inputs are frozen:** First Pass Fill, Job Code Parts Advisor, Labor Performance, MD Invoices, Open Parts Tickets, Open Work Orders, Pin Capture. These look fresh but aren't. Labor Performance matched production on 09-24 only because its Silver inputs had been run by hand that afternoon.

### 3c. Gold→Gold race conditions

These notebooks read another Gold table, but all Gold notebooks run in parallel in one ForEach:

- `Branch12Transactions` → `Branch12Parts`
- `Branch12Transactions` → `BranchPartInventory`
- `Parts` (dim) → `FirstPassFill`
- Customer Anatomy chain, **4 levels deep** (dims → detail facts → performance/aggregate facts)

Today the downstream table can build from the previous run's upstream data, a race that no one can see.

### 3d. Cadence mismatches

Two monthly dims feed daily facts: `dim_Technician_Code_Names` and `dim_Salesperson`. When a new technician or salesperson appears mid-month, the daily facts show them as unmatched until the 1st. **Recommendation:** make any dim that a daily fact joins to a daily dim too. Both are small and cheap to rebuild.

### 3e. Orphans and leftovers (to clean up)

- `dim_JobCodes_v2`: a test build from the Job Code Parts Advisor work
- `BranchOperational`
- `Silver_ArMasterCustomer_1`: a duplicate-suffix table
- the Utilities notebooks
- `Pipeline_DP_Master_Orchestrator` (`5aa9cecf-…`): points at notebook IDs that no longer exist
- Gold `OpenOrders` / `OpenOrderParts`: confirm whether any report still reads them before deleting
- **Fixed 2026-09-25: CI deploy flattened folders.** `deploy/lib.py` `stage_items` staged every notebook flat, and fabric-cicd mirrors the staged structure, so every deploy moved all registered notebooks to the workspace root. Items are now staged at their workspace-relative path, and `fabric-cicd` is pinned to 1.3.0.

### 3f. CI/CD blocker: hard-coded Dev IDs

Every config entry carries Dev `notebookId` and `workspaceId` GUIDs. When fabric-cicd promotes the pipeline to `DP - Presentation - Prod`, the Prod copy would still run the **Dev** notebooks. This has to be solved before Stage 3 (Prod workspaces).

---

## 4. Improvement options

### Option A: Keep the pipeline and fix the config (smallest change)

- Register all 53 producers.
- Split Gold into explicit **waves**: a new `wave` field (1, 2, 3…) with one Filter+ForEach per wave, run in order.
- Add a Dataflow activity ahead of Silver for the 2 ODBC staging pulls.
- **Pros:** familiar, visible in the Fabric monitor, and there's little new to learn.
- **Cons:**
  - Waves are hand-maintained, so dependencies are implicit and easy to get wrong when a table is added.
  - Each ForEach iteration starts its own notebook session, which is slow and costly in CU on F8.
  - The pipeline JSON grows with every wave.

### Option B: Orchestrator notebook with a dependency DAG (recommended to evaluate)

- A single `Run_DP_Refresh` notebook calls `notebookutils.notebook.runMultiple(dag)`. Each activity declares its `dependencies`, and Fabric runs everything in the right order with parallelism where it's safe.
- The DAG is generated from the config: add a `dependsOn` list per entry, or derive it.
- The pipeline shrinks to: Dataflow activity (staging pulls) → orchestrator notebook → semantic-model refresh → email.
- **Pros:**
  - Dependencies are explicit and live in git.
  - Notebooks share one Spark session (high concurrency), which cuts startup time and CU. That matters on F8.
  - Races like the ones in §3c become impossible to express accidentally.
  - Notebooks are referenced **by name**, which removes most of the hard-coded-GUID problem.
- **Cons:**
  - A newer pattern to learn.
  - Per-notebook results show inside the notebook run, not as separate pipeline activities, so the email summary has to come from the run's output.
  - Needs a prototype to confirm cross-workspace behaviour: the orchestrator would sit in Presentation while Silver notebooks sit in Staging.

### Option C: Per-report pipelines

One pipeline per report chain. **Not recommended:** it duplicates shared Silver and dim runs and multiplies the maintenance burden.

### Supporting fixes (apply with either A or B)

1. **Registration is already one step** (push to dev → CI deploys notebooks and config). Keep it that way; don't add manual upload steps.
2. **Resolve IDs by environment.** With Option B, name-based references cover notebooks. For anything still ID-based, use the existing `DP - Environment Config` Variable Library (see below) or fabric-cicd `parameter.yml` find/replace.
3. **Daily cadence** for dims that daily facts join to (§3d).
4. **Delete the orphans** in §3e.
5. **Standard notebook hygiene check:** every Gold notebook has the UTC pin and VACUUM after overwrite. Audit all 65 during registration; don't wait to discover gaps one report at a time.

### About the Variable Library (review at the CI/CD stage, per Brian)

What exists today: `DP - Environment Config` in `DP - Staging - Dev`, with `staging_lakehouse_id` and `presentation_lakehouse_id` and `Dev`/`Prod` value sets, both populated as of 09-08. The 09-08 finding still holds: `notebookutils.variableLibrary` **can't be read across workspaces**. That's why notebooks read Silver through shortcuts rather than GUIDs, and why the library has so far been a record rather than a runtime dependency. Pipelines, however, *can* consume Variable Library values. That makes it a candidate for the remaining ID-based pipeline references. Decide during the promotion work, alongside the fabric-cicd `parameter.yml` approach.

---

## 5. Next steps (in order)

1. ✅ Pause the schedules (done 2026-09-25).
2. **Migrate Inspections, then Customer Anatomy.** Validate each by running its own chain manually, in dependency order: Staging dataflow → Silver → Gold. Register each report's notebooks as part of its migration.
3. **Choose between Option A and Option B.** Recommendation: build a small prototype of B first (one report chain, e.g. Labor Performance: 5 Silver → dim → 3 facts) and compare runtime and CU against the current ForEach.
4. **Implement the chosen design.** Register all producers, fix cadence, delete orphans, and run the hygiene audit.
5. **Run the full refresh manually, then re-validate every RP-Dev report** against production. The reports listed in §3b are the ones most likely to have drifted.
6. **RP-Sandbox promotion and stakeholder validation.**
7. **Prod tier:** fabric-cicd, and resolve IDs by environment (Variable Library review happens here).
8. **Cutover:** re-enable the DP schedules and retire the LH_Master_Data orchestrator.
