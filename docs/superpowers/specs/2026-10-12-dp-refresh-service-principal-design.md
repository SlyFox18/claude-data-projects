# DP Refresh as a Service Principal: Design

**Date:** 2026-10-12. **Status:** approved design (Brian, 2026-10-12); plan to follow.
**Code:** fabric-workspace-docs (`deploy/`, `workspaces/DP - * - Dev/`).

## Problem

`Pipeline_DP_Refresh` runs its notebooks as the pipeline's **last modifier**. That causes two problems:

1. **Re-claim after every deploy.** Every "Deploy DP backend" rewrites the Prod pipeline as SPN-Fabric-CICD-Deploy. The run then fails at setup (the Power BI workspace lookup returns 403) until Brian runs `deploy/claim_prod_pipeline.py`. A forgotten re-claim means no morning refresh.
2. **Production depends on Brian's user account.** A password, MFA, license or role change on that account can stop the nightly refresh.

## Goal

The Prod refresh runs as **SPN-Fabric-Refresh-Automation** (app `9adca971-f328-4d79-9b48-713c298a238c`, service principal object `8f71b80d-2698-42db-82cf-10ef0ffb8f12`):
- deploys don't change the run identity, so the re-claim step is retired;
- the only remaining user dependency is the one Microsoft forces (Dataflow Gen2 runs), and it is isolated and visible.

**Out of scope:** moving the 06:15 start to 04:15 (separate roadmap item), the intraday mode, and Shannon's hourly model.

## What the Dev probe proved (2026-10-12)

Probe items: `Utilities_SPN_Probe` + `Pipeline_SPN_Probe` in DP - Presentation - Dev. Their results are in `Tables/SPN_Probe_Results`.

**Works as the service principal** (Notebook activity with a service-principal connection; the token showed `idtyp=app`, `oid=8f71b80d…`):
- DP lakehouse write/read;
- JD Bronze reads through the DP_Staging shortcuts (passthrough identity);
- Silver reads through the DP_Presentation shortcuts;
- `notebookutils.notebook.runMultiple` child notebooks;
- Fabric REST from `sempy.fabric.FabricRestClient`: JD job instances, `queryactivityruns`, SQL endpoint `refreshMetadata`, item and workspace listing;
- reading `Files/config/dp_refresh_dag.json`.

**Fails as the service principal:**
- **Power BI REST with the token Fabric issues to the notebook:** HTTP 403. This covers `sempy.fabric.resolve_workspace_id` (it calls `v1.0/myorg/groups`) and `POST …/datasets/{id}/refreshes`. It's the same 403 behind today's re-claim failure.
- **Starting a Dataflow Gen2 by API:** `SPNBasedRefreshNotAllowed`. Matches Microsoft's docs: Dataflow execute does not support service principals or managed identities.

**Works in the pipeline:**
- **Semantic model refresh activity** with a service-principal connection: full refresh **Completed** for Physical Inventory (DP cloud connection, 27 s) and Aftermarket - Parts Orders (ODBC gateway + DP, 29 s). Power BI history shows refreshType `DataFactory`.
- **Dataflow activity:** both probe dataflows completed (SharePoint and gateway). **It has no connection setting**, so it runs as the pipeline's invoker.

**Connections** (tenant-level, created by Brian, both service principal). The same IDs work in every workspace:

| Connection | ID | Used by |
|---|---|---|
| Notebook | `e2b15d1e-677d-4ec4-89b6-8712a319e8eb` | Notebook activities |
| Semantic model refresh | `f647686a-acc4-40ea-a49f-d4da1bffc476` | Semantic model refresh activities |

**How Git stores it:**
- **The connection reference:** `"externalReferences": {"connection": "<id>"}` on the activity.
- **The notebook reference changes format.** Once a Notebook activity has a connection, Fabric stores the **real notebook item ID and workspace ID** instead of the logicalId and zero workspace. So Prod deploys need ID swaps for every notebook the pipeline calls.

## Design

### Pipeline shape (Dev and Prod identical)

```
Plan_Silver        Notebook (SPN)   Staging Run_DP_Refresh, phase=plan
  │  exit: {run_id, requested, dataflows:[{name,id}], run_jd, dry_run, ...}
ForEach_Dataflows  ForEach over Plan_Silver.dataflows (batchCount 6, continue on failure)
  └ Run_Dataflow   Dataflow activity, dataflowId = @item().id   ← runs as the pipeline invoker
Run_Silver         Notebook (SPN)   Staging Run_DP_Refresh, phase=run  (after ForEach completes, any outcome)
  │  starts JD Incremental, checks Bronze, reads each dataflow's latest job result, runs the Silver DAG
Run_Gold           Notebook (SPN)   Presentation Run_DP_Refresh, phase=run
  │  Gold DAG, SQL endpoint refreshMetadata
  │  exit: summary + models:[{name, groupId, datasetId}]  (no email from this step any more)
ForEach_Models     ForEach over Run_Gold.models (batchCount = orchestrator.modelRefreshParallelism, 4)
  └ Refresh_Model  Semantic model refresh activity (SPN), waitOnCompletion, retry 1
      ├ on Succeeded → Append variable model_results "name|Completed|"
      └ on Failed    → Append variable model_results "name|Failed|<error>"
Finish             Notebook (SPN)   Presentation Run_DP_Refresh, phase=finish
     inputs: Run_Gold's summary + model_results → writes model + run rows to dp_refresh_log,
     composes and sends the summary email / alert / Teams (unchanged notify_core)
Crash path         Notify_DP_Refresh (SPN) on Plan_Silver / Run_Silver / Run_Gold / Finish failure, then Fail
```

**Rules:**
- **Dry run:** `dry_run=true` makes Plan_Silver return an empty dataflow list and Run_Gold an empty model list. Finish sends the dry-run summary as today.
- **No models:** if Run_Gold reports an error or Bronze problems, it returns an empty model list. This keeps today's behavior (no model refresh after a Bronze failure).
- **Items mode:** `items` / `rerun_failed` select dataflows and models exactly as today. The selection logic stays in `orchestrator_core` and Plan/Run_Gold only output its result.

### Orchestrator code (`deploy/orchestrator_core.py`, `orchestrator_glue.py`, rendered by `render_orchestrator.py`)

- **New `phase` parameter:** `plan` / `run` for the Silver copy, `run` / `finish` for the Gold copy. It's one notebook per tier as now, so the render and deploy model doesn't change.
- **Plan phase:**
  - Runs the existing setup and selection.
  - Writes the `InProgress` run row; the `already_running` guard moves here.
  - Exits with the plan JSON.
- **Silver run phase:**
  - Takes `upstream_json` from Plan.
  - **Per dataflow:** reads the latest job instance via Fabric REST (works as the service principal), keeping the instance that started after the plan time. Missing → Failed "did not run"; Completed → Succeeded; otherwise Failed with its `failureReason`.
  - **The rest is unchanged:** JD Incremental start (see the open question below), Bronze evaluation, Silver DAG, freshness checks.
- **Gold run phase:**
  - Unchanged up to `refresh_sql_endpoint()`.
  - `model_targets()` resolves each model to `{groupId, datasetId}` with Fabric REST (`v1/workspaces`, `v1/workspaces/{id}/semanticModels`) instead of sempy.
  - Exits with summary + models. No notifications in this phase.
- **Finish phase:**
  - Parses `model_results` ("name|status|error" strings) into `summary["models"]`.
  - Writes the model and final run rows.
  - Sends notifications. A failed send still fails the notebook, so the crash path fires.
- **Lookups:**
  - Replace `fabric.resolve_workspace_id` / `resolve_item_id` with Fabric REST helpers (`v1/workspaces`, `v1/workspaces/{id}/items?type=…`) everywhere in the glue.
  - Remove `fabric.refresh_dataset` / `get_refresh_execution_details` and `refresh_model()`.
- **Tests:** pure functions in `orchestrator_core` get unit tests:
  - plan output;
  - dataflow-result evaluation from job instances;
  - `model_results` parsing (including errors containing "|");
  - the model list for dry run / Bronze failure.

  `render_orchestrator.py` renders the pipeline JSON too (activities above, with the two connection IDs). A test asserts:
  - every Notebook activity has the notebook connection;
  - every Semantic model refresh activity has the model connection.

### Deploy (`deploy/deploy_backend.py`, `parameter.yml`)

- **Notebook ID swaps:** for the Presentation copy of `Run_DP_Refresh` and `Notify_DP_Refresh`, extend the existing `append_rules` swap (Dev item ID → Prod item ID, type DataPipeline) that today covers only the Staging orchestrator. The workspace IDs are already swapped.
- **Connection IDs** are the same in both tiers, so no swap is needed.
- **Report workspace IDs** in the plan/model lists come from the config at run time. Nothing is hard-coded in the pipeline.
- **After release:**
  - delete `deploy/claim_prod_pipeline.py` and its OPERATIONS-GUIDE steps;
  - update `CLAUDE.md` in both repos;
  - update `OPERATIONS-GUIDE.md` ("Why the pipeline has to be re-claimed" becomes "Identity").

### Identity and access (Brian's steps)

| Who | Needs | Dev | Prod |
|---|---|---|---|
| SPN-Fabric-Refresh-Automation | Contributor | DP - Staging - Dev ✅, DP - Presentation - Dev ✅, RP - Dev ✅, JD_FabricOneLake ✅ | DP - Staging - Prod, DP - Presentation - Prod, RP - Parts Reports, RP - Service Reports, RP - Financial Reports |
| SPN-Fabric-CICD-Deploy | User on both connections | — | so the Prod deploy can save a pipeline that references them (confirm during the build; fabric-cicd may need it) |
| Brian (schedule owner) | Owns the Prod 06:15 schedule | — | **Remaining user dependency:** the staging dataflows run as him |

**Secrets:** the connections hold a client secret created 2026-10-12 ("Fabric notebook connection"; Brian notes its expiry date). It's separate from the Graph email secret, which expires 10/5/2027. Both go in OPERATIONS-GUIDE with rotation dates.

### Open question to settle in the build

**Can the service principal start JD's Incremental pipeline** (`jobType=Pipeline` on `JD_FabricOneLake`)? JD's copy activities use JD's gateway connections, and the probe only read status. Test it in Dev during a quiet window.
- **If it works:** keep the start in Run_Silver.
- **If not:** move it into the pipeline as an **Invoke Pipeline** activity before Run_Silver (connection: organizational account or none, so it runs as the invoker, like the dataflows). Run_Silver then reads its result the same way it reads the dataflows.

## Failure behavior

| Failure | Result |
|---|---|
| A dataflow fails (including Brian's account having a problem) | Its dependent Silver/Gold items are skipped, everything else runs, and the email names the dataflow. Same as today |
| A model refresh fails | Retried once by the activity, recorded in `model_results`, shown in the email. The other models still refresh |
| The service principal's secret expires, or it loses a role | Every notebook activity fails. The crash notifier also runs as the service principal, so **it can't email**. The pipeline itself fails, and Fabric's own failure notification is the backstop. **Mitigation:** the expiry dates are in the docs, and a pipeline-level failure alert should go to Brian through Fabric's notification settings (set up during the build) |
| Plan/Run/Finish crash | As today: the crash notifier emails, then Fail |

## Testing and rollout

1. **Unit tests:** the core functions and the rendered pipeline (connections on every activity, ForEach wiring).
2. **Dev, manual runs:**
   - `mode=items` with 1 dataflow, 1 Silver, 1 Gold and the models they feed;
   - then `mode=all`;
   - then `dry_run`;
   - then a forced dataflow failure (point an item at a dataflow that fails) and a forced model failure, to check the email and log.

   Compare `dp_refresh_log` and the email with a pre-change run.
3. **Prod:**
   - Brian adds the Prod access;
   - release (PR → Deploy DP backend). **No re-claim this time.** Check that the pipeline's notebook activities show the service-principal connection;
   - first Prod run manually with `mode=items` on a small set, then the 06:15 schedule;
   - watch three scheduled mornings.
4. **Cleanup:**
   - retire `claim_prod_pipeline.py`;
   - update docs and memory;
   - with Brian's OK, delete `Utilities_SPN_Probe`, `Pipeline_SPN_Probe` and the probe tables (`SPN_Probe_Results`, `SPN_Probe_Write`).
