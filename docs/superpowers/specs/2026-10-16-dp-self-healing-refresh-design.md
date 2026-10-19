# DP refresh: fix known failures automatically

> **Progress:** approved by Brian 2026-10-16. Phase 1 plan: `docs/superpowers/plans/2026-10-16-dp-self-healing-phase1.md`.
> - **Phase 1 live in Prod 2026-10-16:** Layer 1 + Parts retry (fabric-workspace-docs PR #38, merge `b387fe00`).
>   - Dev-tested: the Parts alert and an injected Gold failure.
>   - Deployed 13:21 CT; claimed afterwards.
>   - Prod Parts load verified: timeout 15 min, retry after 1,500 s.
> - **0c answered 2026-10-16:** Workspace Identity is **not available** on the Dataflow activity, so 2a is built.
>   - **Fixer:** a scheduled task on Brian's PC (his choice), not a Power Automate flow.
>   - **Phase 2 plan:** `docs/superpowers/plans/2026-10-16-dp-self-healing-phase2.md` (marker, skip unchanged
>     pipelines, claim task, Finish warning).
>   - **Phase 2 LIVE 2026-10-19.** Claim task installed on Brian's PC. Prod deploy run 39257305075 (13:07Z)
>     re-published both pipelines (`claimed:no`), and the task claimed both at 08:10 CT, about 3 min later. Nothing
>     needed a re-run.
>     Still to prove: a deploy with no pipeline change reports "unchanged → still claimed".
>   - **Phase 2 code done 2026-10-16:** fabric-workspace-docs PR #40 (331 tests, reviewed, Dev dry run OK).
>     - The pending marker goes in the staged `.platform`: fabric-cicd 1.3.0 rewrites the description from it.
>     - The claim task runs 05:10–20:55 every 15 min, with a pending.json rerun window (deploy..claim + 2 min).
>     - Release = merge, deploy, then Brian installs the task.
>   - **Phase 3a, 2026-10-19 (from that morning's emails):**
>     - **Notebook warning channel:** a `WARN:` exit value shows in the summary.
>     - **InMaster exact-duplicate guard** in both Silver InMaster readers. JD's Full copy had returned
>       8/D/E63245 twice.
>     - **Dev-tested on the real duplicate.** Both builds succeeded with a warning. fabric-workspace-docs PR #41.
>     - **Watchdog:** the Equip-test alert fires after 2 failures in a row, or 3 in 2 h, and stays one open
>       problem while flapping (data-projects `53ba40c9..f385e088`). Brian re-installs it on both machines.
>     - **2c (capacity retry) deferred:** no Prod occurrences yet.
>   - **Phase 3b code done 2026-10-19:** fabric-workspace-docs PR #42, plus the watchdog trigger in data-projects
>     (`6af7e0a3`, `4f94f348`). Plan: `docs/superpowers/plans/2026-10-19-dp-self-healing-phase3b.md`.
>     - `mode=catchup`. Quiet runs write no log rows. Only `gateway` failures are re-run; `unclaimed` is left to
>       the claim task.
>     - A failed JD Full re-run doesn't use up the day's catch-up.
>     - `Pipeline_DP_Refresh` gets `concurrency: 1`.
>     - Dev-tested: quiet, plus a dry run.
>     - **Rollout:** deploy, then re-install both watchdogs (log-only), one week, then `CatchupEnabled`.
>   - **Phase 3c:** maintenance helper. **Layer 3:** diagnosis agent.
> - Later phases get their own plans once phase 1 ships and 0c is answered.

## Goal

When a DP refresh, the Parts Availability load or a JD Bronze load fails for a reason we already understand, the
system fixes the cause, or waits for the watchdog to fix it, then re-runs what was missed and sends **one** email
saying what it did. Failures we don't understand are left alone, and an agent emails Brian a diagnosis.

Three rules hold throughout:

- **No scraping emails or Teams.** The alerts are written from data the system already has (`dp_refresh_log`, the
  Bronze check, the pipeline run results, the watchdog's state). The fixes read that same data.
- **Fixes are code, not agents.** Every automatic action is a known step, tested in `deploy/`, released through
  dev → main like any other change. An LLM agent never takes an action in Prod.
- **Few actions, all limited.** The only automatic actions are starting known pipelines, re-saving two pipeline
  descriptions as Brian (the claim), and restarting a gateway service, which the watchdogs already do.

## Background: three incidents in two days

| When | What broke | What fixed it | Time stale | Could it fix itself today? |
|---|---|---|---|---|
| 2026-10-15 00:00 → 09:09 | JD gateway (SPI01SR2034W) offline from before midnight. JD Full 0/98, Incremental failed, the 06:15 DP refresh blocked by the Bronze check | Brian restarted the service ~07:30, ran JD Full by hand, re-ran the DP refresh | ~3 h after 06:15 | No. The watchdog didn't exist yet |
| 2026-10-16 06:15 | All 5 staging dataflows failed `SPNBasedRefreshNotAllowed`, 7 items downstream skipped, 7 reports partly stale. The 10/15 Prod deploy had re-saved `Pipeline_DP_Refresh` as SPN-Fabric-CICD-Deploy, and dataflow activities run as the pipeline's last modifier | Brian ran `claim_prod_pipeline.py`, then `rerun_failed` (fabric-workspace-docs `b97d14fe`) | ~2 h | No. The claim has to be saved **as Brian**, and every automated identity is a service principal |
| 2026-10-16 ~11:34 → 11:54 | Watchdog drill on SPI00T4022W11 stopped `PBIEgwService`. The 11:50 Parts load and its 2-minute retry failed `EvaluationGatewayUnreachable`, and so did `df_InMaster_PartsLookup_Raw` | The watchdog started the service at 11:54 (2nd stopped check) and Fabric showed Live | ~1 h (until the 12:50 load) | Half. The gateway healed itself, but nothing re-ran the missed loads |

**The gap all three share:** the system detects problems and reports them well, and with the watchdogs it can now
fix a broken gateway, but it never re-runs the work that was missed.

## What exists today (to build on)

- **Gateway watchdogs** (data-projects `projects/jd-bronze-pipelines/gateway-watchdog/`), live on both gateway
  machines since 2026-10-16:
  - JD's `049694-Gateway` on SPI01SR2034W; `SPI-Data-Gateway` on SPI00T4022W11.
  - **Checks:** every 10 min as SYSTEM. A stopped service or a non-Live gateway on two checks in a row gets a
    start or restart. Most 3 restarts in 6 hours. Nightly restart at 23:30. Hands off while the gateway installer
    runs.
  - **Alerts:** emails 🔴/🟡/🟢 through Graph as `dp-refresh@`.
  - **Identity:** SPN-Fabric-Refresh-Automation, with one secret per machine.
  - **State:** `state.json` holds the failure count, recent restarts and the last alert.
- **`Pipeline_DP_Refresh` / `Run_DP_Refresh`**, rendered from `deploy/orchestrator_core.py` and
  `orchestrator_glue.py`:
  - **Modes:** `scheduled`, `all`, `intraday`, `items`, `rerun_failed`.
  - **Writes:** `dp_refresh_log`.
  - **Guards:** the Bronze check; an InProgress guard against overlapping runs (4 h).
  - **Identity:** notebooks and models run as SPN-Fabric-Refresh-Automation; dataflows run as the pipeline's last
    modifier.
- **`Pipeline_PartsAvailability`** (`pipeline_render.py`'s `parts_pipeline()`): hourly at :50 during business
  hours. One retry after 120 s. Custom failure email classified by `deploy/parts_alert.py`, which already
  recognises `SPNBasedRefreshNotAllowed` and gateway errors.
- **`deploy/claim_prod_pipeline.py`:** PATCHes both Prod pipelines' descriptions as the operator (`fab api`).
  Brian must run it after every Prod backend deploy; the deploy workflow's run summary reminds him.
- **`notify_core.py`:** the DP summary email. For failed items it says only "Fix the cause, then run …
  rerun_failed" (`orchestrator_core.py:444`); unlike `parts_alert` it doesn't name the cause.

## Design

The work is in four layers. Each layer is useful without the ones after it, and they ship in this order.

```
Layer 0  Prevent      watchdogs (live) · skip unchanged pipelines on deploy · Workspace Identity test
Layer 1  Name it      the alerts name the failure type and its exact fix
Layer 2  Fix it       the claim fixer (runs as Brian) · catchup mode, started by the watchdogs' recovery
Layer 3  Diagnose     an agent reports on unknown failures; read-only
```

### Failure types

One table drives the alerts (Layer 1) and the automatic fixes (Layer 2). Patterns are matched on the error text
or code the orchestrator and `parts_alert` already capture.

| Type | Matched by | Automatic fix | Who acts |
|---|---|---|---|
| `jd_gateway` | Bronze check failure whose activity errors mention the gateway (`ncu.frontend.clouddatahub.net`, `on-premises data gateway`, `DMTS_…Unreachable`) | JD watchdog restarts the gateway → `catchup gateway=JD` | watchdog, then Run_DP_Refresh |
| `spi_gateway` | Dataflow / Parts load failure `EvaluationGatewayUnreachable`, or other gateway wording, on an item marked `gateway: "SPI"` | SPI watchdog restarts the gateway → `catchup gateway=SPI` | watchdog, then Run_DP_Refresh |
| `unclaimed` | `SPNBasedRefreshNotAllowed`, or the "unclaimed" marker (below) | Claim fixer claims as Brian → `rerun_failed` | claim fixer |
| `transient` | Capacity throttling or memory pressure, `TooManyRequests`, timeouts. The exact strings come from dp_refresh_log history while planning | One `rerun_failed` 15 min after the run ends | Run_DP_Refresh (notify step starts it) |
| `unknown` | anything else | none. Layer 3 diagnosis | agent (read-only) |

Classification is a pure function in a new `deploy/failure_types.py`, with tests, shared by `notify_core`,
`parts_alert` and the catch-up logic. `parts_alert`'s existing cause buckets move into it, so there is only one copy.

**As built in phase 1** (fabric-workspace-docs `9b7423a8..90345e73`):
- **Kinds:** `failure_kind()` returns `unclaimed`, `overlap`, `credentials`, `timeout`, `capacity`, `gateway` or
  `unknown`.
- **Which gateway:** decided by context. Bronze problems → JD; DP dataflows and the Parts load → SPI.
- **Dataflows only:** `orchestrator_core.dp_failure_kind()` gives `gateway`/`unclaimed` only for dataflow items.
  Spark tracebacks contain `py4j/java_gateway.py`, so a notebook's "gateway" is noise.
- **`transient` = `AUTO_RETRY_KINDS = {"capacity"}`,** matched on throttling text only. A bare "capacity" matched
  column names such as `ServiceCapacity`. `timeout` is **not** auto-retried yet: DP's own waits time out while the
  job may still be running, and a cell timeout is often slow code. 2c decides which timeouts are safe.
- **Prod failure history (checked 2026-10-16):** every real failure was gateway, claim or a code/data bug. No
  temporary failures yet.

### Layer 0: prevention

**0a. Watchdogs.** Already live. No change except the recovery trigger (2b) and the maintenance helper (2d).

**0b. Deploy skips pipelines whose content hasn't changed.**

- **Why:** `Pipeline_DP_Refresh`'s definition changed 8 times between 2026-09-15 and 2026-10-16, and some Prod
  deploys don't touch either pipeline. Skipping them means those deploys never need a claim.
- **How:** `deploy_backend.py` hashes each staged pipeline's `pipeline-content.json` after the Dev→Prod ID
  replacements and compares it with the hash stored on the Prod pipeline (see the marker in 2a).
  - Equal: the pipeline is left out of the `DataPipeline` publish.
  - Different, or no hash stored: publish as today.
- **To confirm while planning:** fabric-cicd has a way to publish only some items (an item filter or a staged
  folder holding only the changed pipelines). Building the stage folder per pipeline already works
  (`stage_items`).

**0c. Test the Workspace Identity option on the Dataflow activity (Dev, about 30 min).** The Dataflow activity docs
(Known issues) mention a "Workspace Identity (WI) dropdown" that some tenants can't see. If it exists for us and a
dataflow runs under it, dataflows would no longer depend on who last saved the pipeline. The claim, the fixer and
0b would then be unnecessary. Test it first. If it works, drop 2a and replace this section with the migration.

### Layer 1: alerts name the fix

- **DP summary email** (`notify_core` / `orchestrator_core` render): failed items are grouped by type, each with
  its exact fix:
  - `unclaimed`: "Run `python deploy/claim_prod_pipeline.py`, then `mode=rerun_failed`" (later: "the claim fixer
    was started at hh:mm"; see 2a).
  - `spi_gateway` / `jd_gateway`: "The watchdog on <machine> will restart the gateway; a catch-up runs when it's
    back."
  - `transient`: "An automatic rerun_failed starts at hh:mm."
- **Parts alert:** when the cause is a gateway type, it reads nothing new. It points to the watchdog ("a re-run
  starts when the gateway is back") instead of telling Brian to check the gateway by hand.

### Layer 2: automatic fixes

#### 2a. The claim fixer (runs as Brian)

**Marker.** Every Prod pipeline description carries a status line. The claim script and the deploy both rewrite it:

```
<existing text> | deploy:<utc> run:<github run id> hash:<sha12> | claimed:no
```

`claim_prod_pipeline.py` keeps the `deploy`/`hash` part and sets `claimed:<utc>`. A deploy that skips a pipeline
(0b) leaves its description alone, so the pipeline stays claimed.

**Fixer.** Something that holds Brian's identity unattended, does exactly one job, and can be started by the
deploy workflow and by the notifiers.

- **Preferred: a Power Automate cloud flow, "DP – Claim Prod pipelines",** owned by Brian:
  - **Trigger:** HTTP request (a SAS URL). It's stored as GitHub secret `CLAIM_FLOW_URL` and in Key Vault or
    notebook config for the notifiers.
  - **Actions:** PATCH the descriptions of `Pipeline_DP_Refresh` and `Pipeline_PartsAvailability` (fixed IDs;
    nothing comes from the request). Then, if the request body says `rerun: true`, start `Pipeline_DP_Refresh`
    with `mode=rerun_failed`.
  - **Called by:**
    - the deploy workflow's last Prod step, so a claim follows every deploy within minutes;
    - `Notify_DP_Refresh` and `Notify_PartsAvailability`, on an `unclaimed` failure (`rerun: true`).
  - **Open question (decides 2a):** which connector can call `api.fabric.microsoft.com` as Brian. Candidates:
    - "HTTP with Microsoft Entra ID (preauthorized)", if Fabric's API is on its list;
    - a custom connector with OAuth to an app registration Brian owns, with the delegated Fabric scope
      `Item.ReadWrite.All`.
- **Fallback: a scheduled task on Brian's PC.** Runs every 15 min, 05:00–18:00 weekdays. It reads the marker;
  when it says `claimed:no`, it runs `claim_prod_pipeline.py` with Brian's `fab` login and, if a run failed
  `unclaimed` today, starts `rerun_failed`. It only works while the PC is on and the login is valid, and it emails
  if the login has expired.

**Early warning.** The Plan step of `Run_DP_Refresh` reads its own pipeline's description (the SPN has
Contributor). On `claimed:no` it starts the fixer before the dataflows run, and says so in the summary. If the fixer
isn't configured or fails, the run continues as today. The dataflows fail fast, and Layer 1 names the fix.

#### 2b. `catchup` mode, started by the watchdogs' recovery

**New mode `catchup`** in `Pipeline_DP_Refresh`, with parameters `gateway` (`JD` | `SPI`) and `since` (UTC; when
the outage began). It works out what was missed and does only that:

| `gateway` | Decision (all inputs: `dp_refresh_log`, the JD pipeline runs, the Parts pipeline runs, since `since`) |
|---|---|
| `JD` | 1. Today's JD Full has failed copies of tables DP reads (the existing Bronze-check logic) → start JD Full and wait. 2. Then: no successful `scheduled` run today → run the scheduled set (it triggers Incremental itself). A scheduled run today with failed or skipped items → `rerun_failed`. Otherwise nothing |
| `SPI` | 1. DP items marked `gateway: "SPI"` that failed since `since`, plus their skipped dependents → `rerun_failed` scoped to them. 2. `Pipeline_PartsAvailability`'s latest run since `since` failed, and we're inside the Parts load hours → start it |

- **No-op is the normal outcome.** The catch-up exits after Plan when there's nothing to do, logs one
  `catchup: nothing missed` row, and sends no email.
- **Gateway per item:** add `"gateway": "SPI" | "JD" | null` to every dataflow item in `dp_refresh_dag.json`.
  Notebooks get it implicitly through the `jd_gateway` Bronze check. `dag_check.py` requires the field on every
  dataflow. Fill it in from each dataflow's connections while planning (the ODBC ones and `df_JDPriceFiles_Raw`'s
  network share use SPI-Data-Gateway; the SharePoint ones probably use none).
- **Out of scope:**
  - `df_InMaster_PartsLookup_Raw` (LH, retiring). It's a dataflow, so an SPN can't start it; its next hourly run
    catches up.
  - Shannon's Aftermarket ODBC model. It runs hourly; the next refresh catches up.

  Say so in the catch-up email.

**Trigger: the watchdog.** When a watchdog's check finds the gateway healthy after an outage (the moment it sends
🟡 "restarted and it came back" or 🟢 "Recovered"), it also:

- POSTs `…/workspaces/{prodPresentation}/items/{Pipeline_DP_Refresh}/jobs/instances?jobType=Pipeline` with
  `mode=catchup, gateway=<JD|SPI>, since=<first failed check, UTC>`;
- records `catchupStartedUtc` in `state.json`, and says in the email that a catch-up was started.

Watchdog details:

- **New `config.json` keys:** `CatchupPipeline` (workspace and item IDs) and `CatchupEnabled` (default `false`, so
  the trigger first runs in a log-only mode: "would start catch-up").
- **Permission:** SPN-Fabric-Refresh-Automation is already Contributor on DP - Presentation - Prod. Starting a
  pipeline needs nothing new. To confirm while planning: that the DP pipeline's dataflow activities still run as
  the last modifier (Brian) when an SPN starts the run, not as the starter. One run in Dev answers it.
- **Pester tests** for the new decision: trigger only on the healthy-after-outage transition, never on a plain
  healthy check, at most once per outage.

**Backup schedule.** `Pipeline_DP_Refresh` also runs `mode=catchup gateway=JD` at **08:30 weekdays**. It covers
recoveries the watchdog didn't see (Brian fixing something by hand, the watchdog machine down). Since the no-op
case stops after Plan, it costs one short notebook session on good days. (Measure that cost in Dev; if it's
noticeable, move the "anything to do?" check into a pipeline Lookup before the notebook.)

**Guardrails** (in `orchestrator_core`, tested):

- **Overlap:** never starts while another DP run is InProgress (existing guard). The watchdog trigger is dropped,
  not queued; the 08:30 backup or the next trigger picks it up.
- **Once a day:** at most one automatic `catchup` per gateway per day runs the full scheduled set. Later triggers
  that day may only run `rerun_failed`.
- **Cutoff:** no full scheduled-set catch-up starts after **14:00** Central (`catchupCutoffLocal` in the DAG
  config). After the cutoff, email "catch-up needed, not started (after cutoff)". Parts loads aren't affected by
  the cutoff; they're already bound to business hours.
- **Dry runs:** `dry_run=true` works as in every other mode.

**One email per incident.** The catch-up summary leads with the outage and what was done:

> 🟢 [Prod] Caught up after SPI-Data-Gateway outage (11:34–11:54, restarted by the watchdog). Re-ran:
> Pipeline_PartsAvailability ✔. Not re-run (next scheduled run covers it): df_InMaster_PartsLookup_Raw.

#### 2c. Automatic retry for transient failures

When the summary step classifies every failure in a run as `transient`, it starts one `rerun_failed` with a 15-min
delay (a Wait activity in a small `Pipeline_DP_Retry`, or the notify notebook's scheduled job; pick one while
planning). At most once per run. Two in a row are reported as `unknown`.

#### 2d. Planned gateway maintenance helper

`Start-GatewayMaintenance.ps1 -Minutes 30 [-Reason "…"]` in the watchdog folder:

1. Lists the scheduled jobs that use this gateway and fall inside the window (a static list in `config.json`: Parts
   :50, ODBC models hourly, DP 06:15 / JD 00:00 / JD Incremental 06:30) and asks for confirmation.
2. Disables the Check task and registers a one-time task to re-enable it after `-Minutes`.
3. Writes `maintenanceUntilUtc` to `state.json`, so the watchdog's emails say "maintenance" rather than "problem".

When maintenance ends, the first healthy check fires the catch-up trigger as after any outage, so anything that
failed during the window re-runs.

**Small related change (done in phase 1):** `Pipeline_PartsAvailability`'s load now has a 15-min timeout (a
load normally takes ~2 min) and retries once after **1,500 s (25 min)** instead of 120 s. A gateway failure fails
fast, so the retry lands after the watchdog's ~20–25-min heal; on 10/16 it would have succeeded. Worst case
15 + 25 + 15 = 55 min keeps the load inside its hour (the notifier adds a few minutes; `concurrency: 1` queues the
next run). The catch-up trigger makes this mostly redundant, but it doesn't depend on Layer 2.

### Layer 3: diagnosis agent (read-only, last)

Build it only after Layers 1–2 have run for a few weeks, and only for what still reaches Brian as `unknown`.

- **Where:** a scheduled `claude -p` on Brian's PC (has his tools, the repos, DuckDB access), or a Claude Code
  routine. A cloud routine can't reach the gateway machines or the on-prem network, and would need its own
  read-only SPN secret.
- **Input:** today's `dp_refresh_log` rows with type `unknown`, `jd_bronze_check.py` output, the watchdog
  logs/state, `docs/TROUBLESHOOTING.md`.
- **Output:** one email/Teams post: what failed, the likely cause with evidence, the proposed fix (a command, or
  a draft branch on `dev`). It never runs a Prod action. A diagnosis that keeps repeating becomes a new failure
  type in Layer 2.

## Rollout

1. **0c Workspace Identity test** (Dev). Its result decides whether 2a is built.
2. **Layer 1** + `failure_types.py` + the Parts retry interval. A normal dev → main release.
3. **0b** skip unchanged pipelines + the description marker + claim script update.
4. **2a** fixer: prove the connector in Dev on the Dev pipeline, then point it at Prod. Wire the deploy workflow
   step.
5. **2b** catchup mode in Dev:
   - test with `dry_run` against today's real log rows;
   - then one real SPI drill in Dev, with the watchdog trigger pointed at the Dev pipeline;
   - then Prod with `CatchupEnabled: false` (log-only) for a week;
   - then on.
6. **2c, 2d.**
7. **Layer 3,** after a few weeks of Layer 2 data.

Each step updates the docs it touches: OPERATIONS-GUIDE (release steps, Identity), TROUBLESHOOTING (the
failure-type table becomes a section), the watchdog README, this spec's Progress block.

## Open questions to settle while planning

1. Does the Dataflow activity's Workspace Identity option exist and work for us (0c)?
2. Which Power Automate connector can call the Fabric REST API as Brian (2a)?
3. When an SPN starts `Pipeline_DP_Refresh` through the API, do its dataflow activities still run as the last
   modifier (2b)?
4. The exact error strings for `transient` (from `dp_refresh_log` history).
5. Which gateway each dataflow uses (the `gateway` field).
6. What a no-op `catchup` run costs in CU, to decide between a notebook and a Lookup pre-check.

## Not doing

- Parsing emails or Teams messages.
- Letting an agent restart services, start pipelines or deploy.
- Changing JD's pipeline definitions (JD pipeline edits stay with Brian in the UI).
- Retrying failures of type `unknown`.
