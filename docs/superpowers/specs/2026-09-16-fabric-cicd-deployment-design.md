# fabric-cicd Deployment Pipeline — Design

## 1. Problem Statement

The original data-platform redesign spec
(`docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md`,
Section 5) called for `fabric-cicd` as the one deployment mechanism for both the new
DP backend and the report layer, but left two things unresolved: whether it applies to
the *existing* report promotion flow or only the new backend, and the actual
implementation shape. Neither has been built — every promotion so far (Batches A–D of
the backend, and Batch 0 of the report migration) has been entirely manual: Brian
publishing from Desktop, Claude committing/pushing by hand, notebooks run one at a
time in the Fabric portal.

Batch 0 (`Bin Location Report`, `Physical Inventory`, `60+ Days Past Due` — see
`docs/architecture/report-migration-catalog.md`) surfaced the concrete gap this design
closes: all 3 reports are live in `RP - Dev`, correctly pointed at `DP_Presentation`,
but that's the **Dev-tier** lakehouse. The Prod-tier workspaces (`DP - Staging - Prod`,
`DP - Presentation - Prod`) exist and were proven once, manually, for the original
Parts Promo pilot (2026-09-08) — and never touched again. There is currently no
repeatable path from "proven in Dev" to "live in real production, on Prod-tier data."

## 2. Scope

**In scope:**
- One GitHub Actions workflow in `fabric-workspace-docs` (the repo Fabric actually
  reads/writes — `data-projects` is out of scope for this pipeline entirely)
- Deploying and running the DP backend's Gold/Silver notebooks into the Prod-tier
  workspaces (`DP - Staging - Prod`, `DP - Presentation - Prod`)
- **A recurring, scheduled refresh of that same backend data** — the one-time CI/CD
  promotion run is not a substitute for ongoing daily refresh, and this project has
  never had one for the new backend (every Silver/Gold run so far, Dev or Prod tier,
  has been manually triggered — see `project_jd_bronze_data_platform_redesign.md` in
  memory, "refresh scheduling: still manual, the most visible gap")
- Deploying the 3 Batch 0 reports through `RP - Sandbox` and into their real
  production workspaces (`RP - Parts Reports`, `RP - Financial Reports`), with each
  report's `DP_Presentation` connection repointed from Dev-tier to Prod-tier as part
  of the Prod deploy
- A manual approval gate before anything touches a real production workspace — and,
  specifically, before any report is promoted, confirmation that the recurring
  refresh schedule is itself proven reliable (Section 7), not just that the one-time
  deploy succeeded
- Independent verification of Prod-tier backend tables after each scheduled refresh
  run, not just the one-time deploy run

**Explicitly out of scope (this iteration):**
- Any report beyond the 3 Batch 0 reports — the `fabric-cicd` config is an explicit
  allowlist, not "deploy everything in the repo"
- `RP - Service Reports` — separately known to have production content that matches
  neither git branch; needs its own cleanup before any deployment automation targets
  it (Brian's own call, 2026-09-16 — see the report migration catalog's Batch 0 notes)
- Retrofitting this pipeline onto the ~20 reports still on `LH_Master_Data` — those
  aren't part of the DP backend yet, so there's nothing here for them to deploy
- Any change to the existing `LH_Master_Data` refresh pipeline

## 3. Architecture

```
push to dev
  └─ auto-deploy: DP - Staging/Presentation - Dev (backend), RP - Sandbox (reports)
     no approval needed — matches the existing "Sandbox is for internal validation,
     not gated" norm
  └─ a daily scheduled Fabric Data Pipeline (built once, in Dev tier) keeps re-running
     the Silver/Gold notebooks on an ongoing basis, independent of any git push — this
     is what actually proves the backend stays fresh, not just that it deployed once
     (Section 7)

PR merged to main
  └─ workflow runs, deploys up through an approval gate
  └─ Brian clicks Approve in GitHub — gated not just on the one-time deploy succeeding,
     but on the Dev-tier scheduled refresh having already run reliably (Section 7)
  └─ deploys, in order:
       1. DP - Staging - Prod / DP - Presentation - Prod: notebook code (Silver then
          Gold), each notebook's default_lakehouse rebound to the Prod-tier lakehouse
       2. Run each notebook via the Fabric Jobs API, in dependency order, polling for
          completion (this first Prod run is the one-time deploy — the recurring
          schedule, promoted the same way, is what keeps it fresh afterward)
       3. Independent verification of the resulting Prod-tier tables (row counts,
          uniqueness) — same style as `.claude/queries/adhoc/dp-bronze-verify/`.
          Verification failure stops the workflow here; reports are not touched.
       4. Promote the same scheduled Data Pipeline to Prod tier, pointed at the
          Prod-tier lakehouses, and confirm it runs successfully at least once before
          proceeding
       5. RP - Parts Reports / RP - Financial Reports: the report itself, with its
          DP_Presentation connection string repointed from Dev-tier to Prod-tier
          lakehouse ID as part of this deploy — this is the last step, only reached
          once both one-time deploy AND recurring refresh are confirmed working
```

A single Python script, using `fabric-cicd` as a library, does the actual deployment
work. The workflow YAML is orchestration only — it doesn't contain deployment logic
itself.

## 4. Service Principal

New App Registration, `SPN-Fabric-CICD-Deploy` — separate from the existing
`SPN-Fabric-Refresh-Automation` (see `project_sm_refresh_spn_migration.md` in memory),
because "deploy items to a workspace" is a meaningfully larger permission than
"trigger a refresh," and least-privilege says these shouldn't share a credential.

Reuses the tenant-level groundwork already proven for the refresh SPN — no new
tenant-level configuration needed:
- Added to the existing `SG-Fabric-ServicePrincipals` security group
- Tenant setting "Service principals can call Fabric public APIs" is already scoped to
  that group

New work specific to this SPN:
- Granted **Contributor** on all 7 target workspaces: `DP - Staging - Dev/Prod`,
  `DP - Presentation - Dev/Prod`, `RP - Sandbox`, `RP - Parts Reports`,
  `RP - Financial Reports`
- API permissions: Power BI Service → Application permissions →
  `Tenant.ReadWrite.All` → admin consent granted (same easy-to-miss step documented
  for the refresh SPN — the deploy will 403 without it)
- Client ID / secret / tenant ID stored as GitHub Actions repo secrets
  (`FABRIC_CICD_CLIENT_ID`, `FABRIC_CICD_CLIENT_SECRET`, `FABRIC_CICD_TENANT_ID`) —
  never committed to the repo

## 5. `fabric-cicd` Configuration

Explicit allowlist, not a blanket "deploy the whole repo" — extending it later (Batch
1 and beyond) is adding lines, not changing the mechanism.

```yaml
environments:
  dev:
    workspace_ids:
      staging: ab15d64d-c7ba-415d-9bcf-7feb1ef9b201       # DP - Staging - Dev
      presentation: 73fd5443-240e-410a-990a-98827f32c087   # DP - Presentation - Dev
      reports: ba9d8de4-ef13-44e6-9156-e23a2511f3ad         # RP - Sandbox
  prod:
    workspace_ids:
      staging: 189e5c0a-548a-4feb-93d6-dda9ebbe96c1         # DP - Staging - Prod
      presentation: 7836042d-adb1-4846-b70d-bd42980054c5    # DP - Presentation - Prod
      reports_parts: 4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7    # RP - Parts Reports
      reports_financial: 67fefa98-9e80-4a79-afdd-c8988b6e64fc # RP - Financial Reports

items_in_scope:
  staging_notebooks:
    - Build_Silver_InTrans.Notebook
  presentation_notebooks:
    - Build_Gold_Parts.Notebook
    - Build_Gold_DealerGroupCode.Notebook
    - Build_Gold_Franchise.Notebook
    - Build_Gold_BranchLocation.Notebook
  reports:
    - {name: "Bin Location Report", target: reports_parts}
    - {name: "Physical Inventory", target: reports_parts}
    - {name: "60+ Days Past Due", target: reports_financial}
```

**Connection repoint at deploy time**: `fabric-cicd`'s find/replace parameterization
swaps each report's `Sql.Database(...)` connection string (host stays the same — both
tiers share `xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4...`; only the
database/lakehouse differs) and each notebook's `default_lakehouse` METADATA binding,
per environment. The `.pbip`/notebook content in git never needs two versions — one
config, environment-aware, matching the pattern already manually proven for Parts
Promo's notebooks (cell code byte-identical between Dev and Prod tiers, only the
METADATA binding differs).

## 6. Backend Promotion Mechanics

Follows the exact pattern already proven manually once for Parts Promo
(2026-09-08, see `docs/architecture/data-platform-workspaces.md`'s "Prod tier"
section), now automated:

1. **Deploy notebook code** — `fabric-cicd` deploys the notebooks listed in Section 5,
   each rebound to its Prod-tier lakehouse via find/replace on the METADATA block.
2. **Run them, in dependency order** — the workflow calls the Fabric REST API
   directly (`POST /workspaces/{id}/items/{id}/jobs/instances?jobType=RunNotebook` —
   same endpoint pattern already documented in this project's own known gotchas for
   Gen2 dataflow refreshes), Silver first (Gold depends on it via OneLake shortcut),
   then the 4 Gold dims. Polls for completion after each.
3. **Verify independently before proceeding** — after each notebook run succeeds, the
   workflow runs an independent DuckDB check (row counts, uniqueness) against the
   Prod-tier table, matching the `.claude/queries/adhoc/dp-bronze-verify/` scripts'
   established pattern. A verification failure stops the workflow — reports are not
   deployed on a backend that hasn't been independently confirmed correct.

This is a one-time-per-deploy notebook run, not a recurring refresh loop, so it
doesn't carry the CU-waste concern that made the old semantic-model-refresh polling
pattern expensive (`project_sm_refresh_spn_migration.md`) — the Spark session is doing
real Gold-build work the entire time it's billed, not sleeping.

## 7. Recurring Refresh Schedule

This is the piece the original design spec never covered and this project has never
actually had for the new backend — a way for Silver/Gold data to stay current on its
own, without someone manually re-running a notebook. Confirmed with Brian
(2026-09-17): **no report gets promoted to real production until this is proven
working, independent of whether the one-time CI/CD deploy itself succeeded.**

**Mechanism**: a new Fabric Data Pipeline (e.g. `Pipeline_DP_Master_Orchestrator`),
built in Dev tier first, with a daily schedule trigger. Orchestrates, in dependency
order: `Build_Silver_InTrans.Notebook` → the 4 Gold dim notebooks in scope (Section
5). One shared daily schedule for everything in scope for now — not per-report tiers
like the old `LH_Master_Data` pipeline's Tier 1/2/3 cadence. Revisit per-report
cadence once more of the backend is on this pipeline and the orchestration itself is
proven; not worth the added complexity for 3 reports today.

**Proof bar before Prod promotion**: no fixed number of consecutive clean runs —
Brian watches it run for a handful of days and uses his own judgment on when it's
reliable enough to trust, same as every other verification gate in this project
(deliberately not a rigid "5/5 green" rule, since a flaky-but-fixable failure early on
shouldn't reset a counter and a boringly-reliable pipeline shouldn't need to prove
itself for an arbitrary fixed window either).

**Then, and only then**: the same pipeline definition gets promoted to Prod tier via
this same `fabric-cicd` deploy (Section 3, step 4), repointed at the Prod-tier
lakehouses the same way notebooks and reports are repointed (Section 5), and given
its own daily schedule there. A report is not promoted to real production (Section 8)
until the Prod-tier copy of this pipeline has also run successfully at least once —
proving the one-time deploy and the recurring schedule are two different things that
both need to work, not assuming the second because the first succeeded.

**Verification per run**: same independent DuckDB checks as the one-time deploy
(Section 6.3), but now running after every scheduled execution, not just the first
one — this is what actually catches a schedule that "works" once and then silently
breaks (a stale source, a permissions expiry, a shortcut going stale).

## 8. Report Promotion Mechanics

Once backend verification passes AND the recurring refresh schedule is proven
(Section 7) for the relevant tier:
1. `fabric-cicd` deploys the report + semantic model to the target production
   workspace (`RP - Parts Reports` for Bin Location/Physical Inventory,
   `RP - Financial Reports` for 60+ Days Past Due), with the connection string
   repointed to the Prod-tier lakehouse as described in Section 5.
2. No further manual Desktop-publish step is needed for these 3 reports once this is
   proven — publishing to production directly from Desktop is retired for them, per
   the original design spec's intended end state (Section 5: "Power BI Desktop
   publish is only ever pointed at a Dev workspace, never at production").

## 9. Testing / Validation Plan

- **Dry run first**: point the pipeline at `dev` → `RP - Sandbox` only, with the
  approval-gated Prod step disabled, and confirm a real push correctly deploys
  `Bin Location Report` (simplest of the 3) end-to-end into Sandbox with no errors.
- **Stand up and watch the Dev-tier recurring schedule** (Section 7) — build
  `Pipeline_DP_Master_Orchestrator` in Dev tier, let it run daily, watch it for a
  handful of days. This is a real waiting period, not a same-day step — nothing below
  proceeds until Brian judges it reliable.
- **First real Prod run**: `Bin Location Report` — lowest stakes, weekly-refresh
  report today, `RP - Parts Reports`. Confirm the full chain: Silver/Gold notebooks
  deploy and run once in Prod tier, independent verification passes, the recurring
  pipeline promotes to Prod tier and runs successfully at least once there, report
  connection repoints correctly, report lands in `RP - Parts Reports` pointed at
  Prod-tier data that's now refreshing on its own.
- **Extend to the other 2**: `Physical Inventory` next (same workspace, proves
  nothing was Bin-Location-specific), then `60+ Days Past Due` (different workspace —
  `RP - Financial Reports` — proves the config generalizes across workspaces, not
  just reports). The Prod-tier recurring pipeline is shared infrastructure at this
  point, so these two don't each need their own multi-day proof window — only the
  first one does.
- **Rollback check**: confirm a mid-deploy notebook-run failure stops the workflow
  before the report step, leaves Prod-tier data at its last-known-good state, and
  surfaces clearly in the GitHub Actions run which step failed. Separately, confirm a
  scheduled-run failure (not a deploy-triggered one) alerts somehow rather than
  failing silently — exact mechanism (Teams notification, matching the existing
  Fabric Monitoring channel pattern in `projects/fabric-monitoring/`, is the likely
  candidate) is an implementation-planning question, not fixed here.

No stage is considered proven until its own verification passes — Section 6.3's
independent DuckDB check for the backend (now run after every scheduled refresh, not
just the first deploy), a visual/data spot-check in Desktop for each report (same
discipline used throughout Batch 0) — and Brian approves each stage manually via
GitHub Actions before it's treated as done.

## 10. Open Questions / Risks / Follow-ups

- `RP - Service Reports`' production/git drift (Batch 0 finding) needs its own
  resolution before this pipeline — or any deployment automation — targets that
  workspace. Explicitly out of scope here (Section 2).
- Whether this pipeline's `items_in_scope` allowlist grows report-by-report (as each
  new report migrates) or gets restructured once Batch 1 begins is an
  implementation-planning question, not resolved here.
- `RP - Parts Reports`' git sync is currently a week stale (last synced 2026-09-09,
  per Batch 0 verification) — worth a manual "Update all" before the first real Prod
  deploy run, so the workflow's diff against `main` reflects current production state
  accurately.
- Notebook run timeout/retry behavior (how long the workflow waits before declaring a
  Fabric Jobs API poll "failed" rather than "still running") is an implementation
  detail not fixed here.
- The shared daily schedule (Section 7) is a deliberate simplification for these 3
  reports — revisiting per-report cadence (matching `CLAUDE.md`'s existing Tier 1/2/3
  distinctions) is expected once more of the backend sits behind this pipeline, not
  resolved here.
- Failure alerting for the recurring schedule (as opposed to the one-time CI/CD
  deploy, which already surfaces failures in the GitHub Actions run itself) needs a
  real mechanism — likely a Teams notification via the existing Fabric Monitoring
  pattern (`projects/fabric-monitoring/`) — not designed here.
