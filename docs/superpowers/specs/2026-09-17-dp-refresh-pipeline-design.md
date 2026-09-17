# DP Backend Recurring Refresh Pipeline — Design Spec

**Supersedes:** Section 7 ("Recurring Refresh Schedule") of
`docs/superpowers/specs/2026-09-16-fabric-cicd-deployment-design.md`. That section
described only enough to prove the concept for 3 reports; this spec designs the
actual long-term system, since Brian correctly pushed back that a proof-of-concept
pipeline would just need to be rebuilt as more reports migrate.

## 1. Problem Statement

The one-time `fabric-cicd` deploy (the CI/CD design spec) gets code and notebooks
into a target tier, but doesn't keep the data in those notebooks' output tables
current. Something has to re-run the Silver/Gold notebooks on a schedule, and
something has to refresh the (Import-mode, confirmed via each report's own `.tmdl`)
semantic models afterward, since Gold table refreshes alone never reach an
Import-mode report.

The first attempt at this (`Pipeline_DP_Master_Orchestrator`, built 2026-09-17)
proved the basic idea works, but was scoped incorrectly (missing 9 of the 13
notebooks the 3 Batch 0 reports actually need — see the CI/CD plan's Task 7/12
correction notes) and, more fundamentally, was built as a one-off: every future
report migration would mean manually adding pipeline activities in the portal, with
no mechanism to keep that scope in sync with the CI/CD deploy's own scope. This is
exactly the class of problem that caused the Task 7 bug in the first place — two
independently-maintained lists describing the same thing, silently drifting apart.
This spec designs the system so that doesn't happen again as ~20 more reports
migrate onto the DP backend (see `docs/architecture/report-migration-catalog.md`).

## 2. Real Precedent This Design Is Grounded In

Rather than design from scratch, this reuses proven patterns already live in
production, adapted for the new notebook-based (not Dataflow Gen2) backend:

- **Decoupled pipelines, not one big pipeline.** `REFRESH-PIPELINE.md` (the old
  `LH_Master_Data` pipeline's own documentation) deliberately split data refresh from
  semantic model refresh into separate pipelines with separate schedules, specifically
  so an SM failure doesn't block/get blocked by data refresh: *"If the master
  orchestrator fails mid-run, the 6:30 AM SM pipeline still fires and refreshes
  reports against whatever data is fresh in the Lakehouse... A stale-but-functional
  report can be silently corrected with an ad-hoc refresh. A broken-looking report
  erodes trust."*
- **Array-driven `ForEach` + `batchCount`, not one activity per item.**
  `Pipeline_SemanticModels_V2.DataPipeline` (the current, CU-efficient replacement for
  an earlier per-notebook-polling approach that Brian found to be a heavy CU consumer)
  refreshes reports via a `ForEach` fed by a literal JSON array of
  `{name, workspaceId, datasetId}`, with `batchCount: 4` controlling concurrency.
  Adding a report means adding one array entry, not a new canvas activity.
- **Failure isolation via catch-and-continue, not sequential blocking.** In that same
  pipeline, each `PBISemanticModelRefresh` activity's failure is caught by a
  dependent `AppendVariable` activity (gated on the `Failed` condition) that appends
  the failed item's name to a `FailedItems` array, rather than stopping the loop. The
  gate after the `ForEach` accepts both `Succeeded` and `Failed` from the loop, so one
  bad item never blocks the rest. A single email at the end reports any failures.
- **Cadence tiering by how often data actually changes, not "refresh everything
  daily."** `Pipeline_Dimensions_Monthly.DataPipeline` (real, live, runs the 1st of
  each month at 7:30 AM CST) refreshes 13 reference dimensions explicitly classified
  as rarely-changing in `projects/refresh-pipeline/dimension-analysis.md`. Three of
  those 13 are directly relevant here:

  | Table | Cadence | Documented reason |
  |---|---|---|
  | `dim_BranchLocation` | Monthly | "Locations don't change; most-used dimension but static" |
  | `dim_DealerGroupCode` | Monthly | "Reference codes" |
  | `dim_Franchise` | Monthly | "43 manufacturers" |

  The same analysis confirms `dim_Parts` and `dim_CustomerList` as genuinely daily
  ("Parts data changes constantly"; "Customer assignments... change").

## 3. Architecture: Three Pipelines, One Shared Config

```
DP - Presentation - Dev (and, later, - Prod)
├── Pipeline_DP_Daily_Refresh          (daily schedule)
│   ├── Lookup: dp_backend_scope.json → daily-cadence notebooks
│   ├── ForEach (batchCount 3): Silver notebooks, daily tier
│   ├── Wait gate (Succeeded OR Failed)
│   ├── ForEach (batchCount 3): Gold notebooks, daily tier
│   └── Success/failure summary email (lists any FailedItems)
│
├── Pipeline_DP_Monthly_Refresh        (monthly schedule, 1st of month)
│   ├── Lookup: dp_backend_scope.json → monthly-cadence notebooks
│   ├── ForEach (batchCount 3): Silver notebooks, monthly tier
│   ├── Wait gate
│   ├── ForEach (batchCount 3): Gold notebooks, monthly tier
│   └── Success/failure summary email
│
└── Pipeline_DP_SemanticModel_Refresh  (daily schedule, gated after Daily Refresh)
    ├── Lookup: dp_backend_scope.json → reports' {workspaceId, datasetId} for this tier
    ├── ForEach (batchCount 3): PBISemanticModelRefresh per report
    ├── AppendVariable on Failed → FailedItems
    └── Success/failure summary email
```

All three pipelines read the same shared config file (Section 4) rather than having
their own hardcoded scope, and all three use the same catch-and-continue failure
pattern (Section 2) so one bad item never blocks the rest of that pipeline's run.

**Schedule times:** `Pipeline_DP_Daily_Refresh` keeps whatever time Brian already
configured for the existing `Pipeline_DP_Master_Orchestrator` (this spec restructures
what the pipeline does, not when it runs). `Pipeline_DP_Monthly_Refresh` mirrors
`Pipeline_Dimensions_Monthly`'s own proven timing (1st of month, 7:30 AM CST) for
consistency, rather than inventing a new time. `Pipeline_DP_SemanticModel_Refresh`
needs a real dependency on `Pipeline_DP_Daily_Refresh`'s completion (an "Invoke
pipeline" activity or a fixed offset matching the old 4:15→6:30 AM gap) — exact
mechanism to be decided during implementation, not a design-level open question.

**Known, accepted gap:** on the 1st of the month, `Pipeline_DP_SemanticModel_Refresh`
runs after `Pipeline_DP_Daily_Refresh` but is not explicitly gated on
`Pipeline_DP_Monthly_Refresh` also finishing that day. If the monthly pipeline is
still running when the SM refresh fires, that day's monthly-dimension changes (e.g. a
new `dim_Franchise` row) show up in reports the *next* day's SM refresh instead of the
same day. This is a once-a-month, one-day lag on rarely-changing reference data —
deliberately not solved with cross-pipeline gating, matching this project's existing
"minor staleness beats added complexity" philosophy (Section 2).

## 4. Shared Config File

**File:** `fabric-workspace-docs/deploy/dp_backend_scope.json` — git-tracked, single
source of truth for both the CI/CD deploy scope (`deploy_backend.py`) and all three
refresh pipelines above. This directly closes the drift bug described in Section 1:
there is exactly one place that says "these are the notebooks/reports in scope," not
two or three independently-maintained ones.

```json
{
  "notebooks": [
    {"name": "Build_Silver_PartInformation", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook"},
    {"name": "Build_Silver_ArMaster", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMaster.Notebook"},
    {"name": "Build_Silver_ArMasterCustomer", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMasterCustomer.Notebook"},
    {"name": "Build_Silver_Contact", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Contact.Notebook"},
    {"name": "Build_Silver_InSalOrd", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalOrd.Notebook"},
    {"name": "Build_Silver_InSalPar", "tier": "silver", "cadence": "daily",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalPar.Notebook"},
    {"name": "Build_Silver_BranchName", "tier": "silver", "cadence": "monthly",
     "path": "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_BranchName.Notebook"},

    {"name": "Build_Gold_Parts", "tier": "gold", "cadence": "daily",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_Parts.Notebook"},
    {"name": "Build_Gold_CustomerList", "tier": "gold", "cadence": "daily",
     "path": "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_CustomerList.Notebook"},
    {"name": "Build_Gold_InSalOrdInSalPar", "tier": "gold", "cadence": "daily",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/60 Days Past Due/Build_Gold_InSalOrdInSalPar.Notebook"},
    {"name": "Build_Gold_BranchLocation", "tier": "gold", "cadence": "monthly",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_BranchLocation.Notebook"},
    {"name": "Build_Gold_DealerGroupCode", "tier": "gold", "cadence": "monthly",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_DealerGroupCode.Notebook"},
    {"name": "Build_Gold_Franchise", "tier": "gold", "cadence": "monthly",
     "path": "workspaces/DP - Presentation - Dev/Build_Gold_Franchise.Notebook"}
  ],
  "reports": [
    {
      "name": "Bin Location Report",
      "silver_notebooks": ["Build_Silver_PartInformation", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_Parts", "Build_Gold_BranchLocation", "Build_Gold_DealerGroupCode", "Build_Gold_Franchise"],
      "semantic_model": {"dev": {"workspaceId": null, "datasetId": null}, "prod": {"workspaceId": null, "datasetId": null}}
    },
    {
      "name": "Physical Inventory",
      "silver_notebooks": ["Build_Silver_PartInformation", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_BranchLocation"],
      "semantic_model": {"dev": {"workspaceId": null, "datasetId": null}, "prod": {"workspaceId": "4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7", "datasetId": "80c1dc15-60b3-4c6a-9398-3c79b77a4667"}}
    },
    {
      "name": "60+ Days Past Due",
      "silver_notebooks": ["Build_Silver_ArMaster", "Build_Silver_ArMasterCustomer", "Build_Silver_InSalOrd", "Build_Silver_InSalPar", "Build_Silver_BranchName"],
      "gold_notebooks": ["Build_Gold_CustomerList", "Build_Gold_InSalOrdInSalPar", "Build_Gold_BranchLocation"],
      "semantic_model": {"dev": {"workspaceId": null, "datasetId": null}, "prod": {"workspaceId": "67fefa98-9e80-4a79-afdd-c8988b6e64fc", "datasetId": "2516982b-f52f-4676-b879-525e089e9b9e"}}
    }
  ]
}
```

Notes on the example above (to resolve for real during implementation, not to be
taken as final values):

- `notebooks[].path` values shown match the real current paths already verified in
  `deploy_backend.py` (2026-09-17), except `Build_Gold_DealerGroupCode`/
  `Build_Gold_Franchise` which are also verified real current paths (workspace root).
- `reports[].semantic_model.prod` for Physical Inventory and 60+ Days Past Due are
  filled in from the real, live `Pipeline_SemanticModels_V2.DataPipeline` JSON
  (Section 2) since those are the reports' *current* production semantic models
  (still sourced from `LH_Master_Data` today, untouched — see Section 6's promotion
  cutover). Bin Location Report has no entry there since it isn't in that pipeline's
  arrays. These prod values are recorded here now purely for traceability of where
  they came from; they are **not** live in this config until that report is actually
  promoted per Section 6.
- `reports[].semantic_model.dev` values are `null` placeholders — need to be looked
  up for real (e.g. via `fab get`) against each report's Sandbox-deployed
  SemanticModel item during implementation, not guessed.
- The `reports` section is for traceability and for building the `dev`/`prod`
  identity used by `Pipeline_DP_SemanticModel_Refresh`'s array. The `notebooks`
  section (deduped) is what both `deploy_backend.py` and the two data-refresh
  pipelines actually iterate.
- Each report's `silver_notebooks`/`gold_notebooks` above were verified directly
  against that report's real `.tmdl` `Item=` references (2026-09-17), not inferred —
  this caught a real gap mid-draft: `60+ Days Past Due` also reads `dim_BranchLocation`
  directly (missed in an earlier pass), and `Physical Inventory` reads
  `Silver_PartInformation` directly rather than through `Build_Gold_Parts` (it does
  not use `dim_Parts` at all). All three reports depend on `dim_BranchLocation`.

**`deploy_backend.py`'s two responsibilities going forward:**

1. Read `notebooks[]` from this file (filtered to whichever tiers/cadences are being
   deployed — initially both, since a deploy pushes all notebook code regardless of
   how often it *runs*) to build its staging list, replacing the current hardcoded
   `STAGING_NOTEBOOKS`/`PRESENTATION_NOTEBOOKS` Python lists.
2. Write an environment-resolved copy of this same file into that tier's Lakehouse
   Files (e.g. `DP - Presentation - Dev`'s lakehouse, `Files/config/dp_backend_scope.json`),
   with that environment's real `reports[].semantic_model` values already resolved in
   (no `parameter.yml` find/replace needed for this file — `deploy_backend.py`
   already knows which environment it's deploying to and substitutes directly).

Each of the three pipelines' `Lookup` activity reads this Lakehouse Files JSON at the
start of every run, so they always see whatever was last deployed to that tier — no
separate sync job.

## 5. CU Sizing (Real Numbers, Not Estimated)

Pulled 2026-09-17 via `Track-ItemCU.ps1` against the live Fabric Capacity Metrics
model (14-day rolling window), for the notebooks already run this session:

| Notebook | Avg CU-seconds/run | Avg duration/run | Avg CU rate |
|---|---|---|---|
| Build_Silver_PartInformation | ~1332 | ~136s | ~9.8 CU |
| Build_Silver_InSalOrd | ~448 | ~54s | ~8.3 CU |
| Build_Silver_ArMaster | ~343 | ~48s | ~7.1 CU |
| Build_Silver_BranchName | ~146 | ~37s | ~4.0 CU |
| Build_Silver_Contact | ~156 | ~39s | ~4.0 CU |
| Build_Silver_ArMasterCustomer | ~121 | ~30s | ~4.0 CU |
| Build_Silver_InSalPar | ~145 | ~36s | ~4.0 CU |
| Build_Gold_Parts | ~863 | ~107s | ~8.1 CU |
| Build_Gold_CustomerList | ~396 | ~50s | ~7.9 CU |
| Build_Gold_DealerGroupCode | ~289 | ~45s | ~6.4 CU |
| Build_Gold_BranchLocation | ~336 | ~54s | ~6.2 CU |
| Build_Gold_Franchise | ~165 | ~41s | ~4.0 CU |
| Build_Gold_InSalOrdInSalPar | ~180 | ~39s | ~4.6 CU |

**Finding:** several of the lightest notebooks converge on almost exactly ~4.0 CU
regardless of actual data volume — this is Spark session startup overhead, not
workload. Heavier notebooks (PartInformation, InSalOrd, Parts, CustomerList) run
higher. A fully-unbatched parallel run of all 7 daily-tier Silver notebooks would
peak in the mid-30s CU — well above F8's 8 CU nominal sustained rate, repeating the
exact "too many concurrent jobs spikes CU" failure mode `REFRESH-PIPELINE.md`
documents from the old Dataflow Gen2 pipeline (4-7x slowdowns from over-parallelizing
on F4). Total footprint for one full run across all in-scope notebooks is
~4,900 CU-seconds (~82 CU-minutes) — about 0.7% of F8's 11,520 CU-minute daily
budget, so this is about smoothing bursts, not conserving scarce daily capacity.

**Decision:** `batchCount: 3` on every `ForEach` in all three pipelines (Silver,
Gold, and semantic model refresh), matching `Pipeline_SemanticModels_V2`'s own
`batchCount: 4` in spirit. Adjust up or down once real scheduled runs are observed —
same judgment-based approach already used elsewhere in this project (no fixed rule).

## 6. Prod Promotion Cutover (Checklist Addition, Not Built Now)

Physical Inventory and 60+ Days Past Due are live in production today, sourced from
`LH_Master_Data` and refreshed by the existing `Pipeline_SemanticModels_V2` on its own
schedule — both completely untouched by this project until a report is actually
promoted to Prod (CI/CD plan Task 15+). Nothing here changes that today. When a report
*is* promoted:

1. Add its real Prod `{workspaceId, datasetId}` to `dp_backend_scope.json`'s
   `reports[].semantic_model.prod`.
2. Remove that report's entry from the legacy `Pipeline_SemanticModels_V2`'s JSON
   array (its data no longer comes from `LH_Master_Data`, so that pipeline should
   stop touching it).
3. Confirm `Pipeline_DP_SemanticModel_Refresh` (Prod tier) now includes it, by
   re-reading the Lakehouse Files config after the next `deploy_backend.py --environment prod` run.

This is a documented step in each report's own promotion task, not new pipeline
logic to build ahead of time.

## 7. What This Spec Deliberately Does Not Cover

- The other 10 monthly-cadence dimensions from `dimension-analysis.md` (`dim_SLC`,
  `dim_Source`, `dim_VendorCode`, `dim_ModuleType`, `dim_CommodityCode`,
  `dim_PaymentMethod`, `dim_AdjustmentType`, `dim_PromoType`, `dim_RepairOrder`,
  `dim_JobType`) — these belong to reports not yet migrated (Price Matrix, Inventory
  Analysis V3, Parts Promo, etc.). `Pipeline_DP_Monthly_Refresh`'s config-driven shape
  is built to absorb them the same way future daily reports get absorbed into
  `Pipeline_DP_Daily_Refresh` — as config entries, not new pipeline work — but they
  are out of scope until those reports actually migrate.
- Per-notebook failure alerting beyond the existing summary email pattern (Teams
  integration, etc.) — already a deferred open question in the CI/CD design spec's
  Section 10.
- `RP - Service Reports`' own git/production drift — a separate, already-documented
  cleanup effort, unrelated to this pipeline.

## 8. Known High-Priority Follow-On: `jdis_Part_Information` Rebuild

**Not addressed by this spec, but discovered while writing it and worth flagging
loudly.** `Build_Silver_PartInformation.Notebook` (in scope above) reads from two
tables, `PartInformation_Active` and `PartInformation_Dead`, which are populated by
two Dataflow Gen2 items — `df_JDIS_PartInformation_Active_Raw` and
`df_JDIS_PartInformation_Dead_Raw` (`DP - Staging - Dev/Raw Data - Dataflows/`) —
that query the live source system directly via ODBC (`dsn=EquipRDB64`), bypassing the
JD Bronze mirror architecture entirely. Confirmed 2026-09-17:

- Both dataflows query `jdis_Part_Information`, which is itself a **SQL Anywhere
  view** (real `ALTER VIEW` SQL obtained from Brian), not a base table — it joins
  `inmaster`, `INHIST_MONTH_4_PI`, `branch_name`, `InManuf_Locale`/`InManuf`, plus
  correlated subqueries against `InHistMQT` (a 5-year rolling window), `insugor`,
  `company`, and `syscalendar` for ~200 columns including 60 months each of rolling
  sales/lost-sales/sales-activity history and fiscal-year-aware YTD sums.
- **Neither dataflow has a `.schedules` file** — no automated refresh exists at all.
  Real commit history shows only two manual refreshes, a week apart (2026-09-09 and
  2026-09-16).
- Both are Dataflow Gen2 items, outside `deploy_backend.py`'s current
  `item_type_in_scope=["Notebook"]` and outside this pipeline design's `notebooks`
  array — entirely invisible to everything built or designed this session.
- **The good news, confirmed via `fab ls` against `JD_EquipRDB_Production_Bronze`**:
  every real table the view depends on is already mirrored there as a 1:1 copy,
  including the two that matter most — `InHistMQT` and `INHIST_MONTH_4_PI` are
  mirrored as already-computed/aggregated tables, not raw transaction data needing
  re-aggregation from scratch. This makes rebuilding the view's join/selection logic
  as a proper Silver notebook (reading Bronze shortcuts, same pattern as every other
  table in this project) a tractable, real rebuild — not a from-scratch 5-year
  aggregation engineering project.

**Decision (2026-09-17):** this pipeline design proceeds as written, with
`Build_Silver_PartInformation` continuing to depend on the two unmanaged dataflows
for now. The `jdis_Part_Information` rebuild (eliminating both dataflows, sourcing
from Bronze shortcuts instead, bringing this data fully into the JD Bronze
architecture) is scoped as its **own follow-on migration effort**, to go through the
same brainstorm→spec→plan cycle as every other table in this project, once this
refresh pipeline is proven. Do not re-derive the dependency list or Bronze
availability above when that effort starts — it's already confirmed real.
