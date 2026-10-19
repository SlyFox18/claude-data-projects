# DP self-healing, phase 3b (catch-up mode, started by the watchdogs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spec 2b. When a gateway comes back, or at fixed backup times, `Pipeline_DP_Refresh` runs `mode=catchup`.
That mode works out what today's data is still missing, does exactly that, and emails once:
- **Bronze-blocked morning:** re-run JD Full, then the scheduled set.
- **Morning with gateway or claim failures:** `rerun_failed`.
- **Failed Parts Availability load during load hours:** start the Parts pipeline once.
- **Otherwise:** nothing, and no email.

**Design decisions (from the spec plus phase 1–3a experience):**
- **One generic rule, no `gateway` parameter.** Catch-up reads today's `dp_refresh_log` and the job instances, and
  decides from those, so it doesn't matter which watchdog triggered it.
- **Environmental failures only.** It re-runs `gateway` and `unclaimed` failures (via `dp_failure_kind`). Code and
  data bugs (`unknown`, e.g. 2026-10-19's duplicate key) would fail again, so they're left for a person.
- **Only after today's scheduled run, before the cutoff.** A gateway recovering at 00:47 (2026-10-19) must not start
  a refresh in the middle of the night: the 06:15 run is still to come. Catch-up acts only on weekdays, once a
  `scheduled` run has started today, and before `catchupCutoffLocal` (14:00). The Parts part follows load hours
  instead.
- **Once a day.** At most one catch-up resolves to the full scheduled set per day. `rerun_failed` catch-ups are
  allowed until the cutoff.
- **Quiet when there's nothing to do.** No email, and a log row only.
- **Another run in progress** → catch-up exits quietly (no "already running" error email). The next trigger or
  backup time picks it up.
- **The trigger is the watchdog,** running as SPN-Fabric-Refresh-Automation, already Contributor on DP - Presentation
  - Prod.
  - It starts catch-up when it sends 🟢 Recovered or 🟡 restarted-and-back.
  - The JD watchdog also starts it at 08:30 and 10:30 on weekdays. **Fabric pipeline schedules can't pass
    parameters,** so the backup times live in the watchdog.
  - Behind `CatchupEnabled` (default false: log "would start catch-up") until Brian turns it on.

**Architecture:**
- **`orchestrator_core.py`:** pure `decide_catchup(...)` and `parts_catchup(...)`; `MODES` gains `catchup`.
- **`orchestrator_glue.py` Plan phase:** resolves `catchup` to an existing mode (`scheduled` / `rerun_failed`) or
  to a quiet no-op. It starts and waits for JD Full when needed, and restarts Parts when needed. The resolved mode
  rides through the later phases.
- **`notify_core.notify_messages`:** sends nothing for a quiet run.
- **`pipeline_render.py`:** a new `reason` parameter, passed to all phases, shown in the email.
- **Watchdog:** a pure `Get-CatchupTrigger`, plus `Start-CatchupRun` (Fabric token, POST job instance).

**Repos:** fabric-workspace-docs (`deploy/`, rendered notebooks and pipeline) and data-projects (watchdog).

---

### Task 1: `decide_catchup` and `parts_catchup` (pure)

**Files:** `deploy/orchestrator_core.py`, `deploy/test_orchestrator_core.py`.

Inputs come from the glue:
- `runs_today`: run rows from `dp_refresh_log` for today (Central), each `{"run_id", "mode", "status", "start_utc",
  "end_utc"}`, where mode may be `"scheduled"`, `"catchup:scheduled"`, `"catchup:rerun_failed"`, `"catchup:none"`, …
- `latest_items`: item and dataflow rows of the latest finished run, each `{"name", "row_type", "status", "error"}`.
- `now_local`: naive Central.
- `cutoff_local`: `"14:00"`.

```python
def decide_catchup(runs_today, latest_items, now_local, cutoff_local="14:00") -> dict:
    """{"mode": "scheduled" | "rerun_failed" | None, "jd_full": bool, "why": str} for a catchup run."""
```

Rules, in order (each with a test):
1. **Weekend** → `None`, "weekend".
2. **After the cutoff** → `None`, "after the 14:00 cutoff".
3. **No run with mode `scheduled` started today** → `None`, "today's scheduled run hasn't run yet".
4. **The latest finished run today** (by `end_utc`, ignoring `catchup:none` rows) is the basis:
   - status `bronze_failed`, and no run today has mode `catchup:scheduled` → `{"mode": "scheduled",
     "jd_full": True}`, "Bronze was blocked this morning";
   - status `bronze_failed` and a catchup already did the scheduled set → `None`, "already caught up once today";
   - status `partial` with ≥1 item whose `dp_failure_kind({"tier": "staging" if row_type == "dataflow" else "gold",
     "error": error})` is `gateway` or `unclaimed` → `{"mode": "rerun_failed", "jd_full": False}`, "N items failed
     on <kinds>";
   - `partial` whose failures are all other kinds → `None`, "failures need a person (<names>)";
   - `ok`, `error`, `crashed`, `tier_done` → `None`, with a reason saying which.

```python
def parts_catchup(latest_instance, now_local) -> bool:
    """True when Pipeline_PartsAvailability's latest job instance Failed and now is inside load hours
    (weekdays 06:50-16:50 Central) - start it once."""
```

Tests: Failed in hours → True; Failed at 17:05 → False; Completed → False; Saturday → False; `None` → False.

- [ ] Steps: write the tests → see them fail → implement → pass → commit "orchestrator_core: decide_catchup /
  parts_catchup (pure)".

### Task 2: catchup in the Plan phase, quiet runs, the `reason` parameter

**Files:**
- `deploy/orchestrator_core.py` (`MODES`, `compose_summary`);
- `deploy/notify_core.py` (`notify_messages`);
- `deploy/orchestrator_glue.py` (Plan phase);
- `deploy/pipeline_render.py` (the `reason` parameter);
- the tests for these;
- the rendered notebooks and `Pipeline_DP_Refresh` JSON.

- [ ] **`MODES`** adds `"catchup"`. `select_items` must never see `catchup`: the glue replaces it before selection.
  Test that `select_items(..., "catchup", ...)` raises.
- [ ] **Plan phase (silver, phase=plan) when `mode == "catchup"`:**
  1. **Already running:** if `already_running()`, set `summary["quiet"] = True` and
     `summary["catchup"] = {"mode": None, "why": "another DP refresh is running"}`. Then select nothing, skip every
     phase's work, and finish without email. Read how the guard is applied today: it raises before the InProgress
     row. For catchup it must not raise.
  2. **Read inputs:** today's run rows and the latest finished run's item rows from `LOG_PATH`, each in one Spark
     query.
  3. **Decide:** `d = decide_catchup(...)`. Log the run row with mode `f"catchup:{d['mode'] or 'none'}"`.
  4. **Parts:** if `parts_catchup(latest Parts instance, now)` → `start_job(PRES_WS_ID, <Pipeline_PartsAvailability
     id>, "Pipeline")`, and add "started Pipeline_PartsAvailability (its last load failed)" to
     `summary["catchup_actions"]`.
  5. **Nothing to do:** `d["mode"] is None` and no Parts start → `summary["quiet"] = True`, select nothing.
  6. **JD Full:** if `d["jd_full"]`, start `JD_FULL` (`start_job(JD_WS, JD_FULL, "Pipeline")`) and
     `wait_for_instance(JD_WS, JD_FULL, since, timeout_s=3600)`. If it doesn't end Completed, abort with a clear
     error, which gets the normal error email.
  7. **Resolve:** set `mode = d["mode"]` for the rest of Plan (`select_items`, `run_jd`, …). Carry
     `summary["resolved_mode"]` so the Silver run, Gold run and Finish phases use it. Find where those phases read
     `mode` (the pipeline passes the original parameter to each phase). Each phase must use
     `upstream["resolved_mode"]` when the parameter is `catchup`.
  8. **JD Incremental:** keep `run_jd` true for a resolved `scheduled`.
- [ ] **The Bronze check after a JD Full re-run** must judge the re-run, not the midnight one. Check
  `evaluate_bronze_detail`'s "since last Central midnight" logic: it reads the Full pipeline's runs since midnight.
  Does it use the latest run or all runs? If all, a failed midnight run would still block. Make it use the latest
  Full run since midnight. Test that.
- [ ] **`notify_messages`:** return `[]` when `summary.get("quiet")`. Test it.
- [ ] **`compose_summary`:** when `run.get("catchup")`, put a first line under the header: "Catch-up (<reason>):
  <why>; ran <resolved mode>." Add `catchup_actions` as list items, and prefix the subject with "🔁 Catch-up – ".
  Tests.
- [ ] **`pipeline_render.py`:** add a pipeline parameter `reason` (string, default "") and pass it to every
  `Run_DP_Refresh` activity like `mode`. Re-render and update `test_pipeline_render.py`. This changes the pipeline
  JSON, so the next deploy re-publishes it and the claim task claims it.
- [ ] **Dev test.** Push, Git sync, then run Dev `Pipeline_DP_Refresh` with `mode=catchup, reason=dev test`:
  - expect a quiet no-op ("scheduled run hasn't run yet": Dev has no scheduled runs);
  - then, temporarily via `dry_run=true`, confirm the decision path logs a `catchup:none` row.
- [ ] Commit: "Run_DP_Refresh: mode=catchup resolves to what today still needs (quiet when nothing)".

### Task 3: Watchdog trigger

**Files:**
- data-projects `projects/jd-bronze-pipelines/gateway-watchdog/`: `GatewayWatchdog.psm1` (new
  `Get-CatchupTrigger`, `Start-CatchupRun`), `Invoke-GatewayWatchdog.ps1` (call them after the decision);
- `Install-GatewayWatchdog.ps1` (new config keys);
- `GatewayWatchdog.Tests.ps1`, `README.md`.

- [ ] **Config keys** (installer default; `-ResetConfig` not needed, missing keys read as defaults):
  - `CatchupEnabled = $false`;
  - `CatchupWorkspaceId = "7836042d-adb1-4846-b70d-bd42980054c5"`;
  - `CatchupPipelineId = "1fa19eb8-7d5f-465e-b7e7-b31e02e56a2c"` (Prod Pipeline_DP_Refresh);
  - `CatchupTimes = @("08:30", "10:30")` for `-Gateway JD`, `@()` for SPI.
- [ ] **`Get-CatchupTrigger -Decision -State -Config -NowLocal` (pure)** returns `@{ Start = $bool; Reason = "…";
  State = … }`:
  - **Start on recovery:** when `Decision.Recovered`, or `Decision.Action -ne 'None'` and the post-action check is
    Live. Reason `"<gateway> recovered <hh:mm>"`.
  - **Start at a backup time:** when NowLocal is a weekday, within 10 minutes after one of `CatchupTimes`, and
    `State.LastCatchupSlot` isn't that slot today. Reason `"backup <hh:mm>"`. Record the slot in the state.
  - **At most one start per check.**
  - **Pester tests** for each case, including no repeat within the same slot and no backup trigger on weekends.
- [ ] **`Start-CatchupRun`:**
  - gets a token for `https://api.fabric.microsoft.com/.default`, with the same client-credentials helper used for
    Power BI;
  - POSTs `v1/workspaces/{ws}/items/{id}/jobs/instances?jobType=Pipeline` with
    `{"executionData":{"parameters":{"mode":"catchup","reason":"<Reason>"}}}`;
  - logs the HTTP status;
  - never throws into the check loop.
- [ ] **When `CatchupEnabled` is false:** log `"[log-only] would start catch-up (<Reason>)"`.
- [ ] **Recovery email** gets a line: "A catch-up run was started" / "would be started (log-only)".
- [ ] **README:** a new section "Catch-up trigger": what it does, the config keys, and how to turn it on
  (`CatchupEnabled: true` in `config.json`).
- [ ] Commit (data-projects): "Gateway watchdog: start Pipeline_DP_Refresh mode=catchup on recovery and at backup
  times (log-only until enabled)".

### Task 4: Docs, release, rollout

- [ ] **fabric-workspace-docs OPERATIONS-GUIDE:** a new section "Catch-up runs":
  - what triggers them;
  - the rules (environmental failures only, after the scheduled run, the 14:00 cutoff, once a day for the full
    set);
  - quiet no-ops;
  - how to run one by hand (`mode=catchup`).
- [ ] **TROUBLESHOOTING:** the gateway rows say "a catch-up run follows the watchdog's recovery". The Bronze
  gateway row says JD Full is re-run automatically when Bronze blocked the morning.
- [ ] **`dp_refresh_dag.json`:** `orchestrator.catchupCutoffLocal = "14:00"`. `dag_config` validates it.
- [ ] **Release:** PR, deploy. The claim task claims the re-published `Pipeline_DP_Refresh`.
- [ ] **Brian, on both gateway machines:** re-run the installer (adds the config keys with `CatchupEnabled false`).
- [ ] **One week of log-only.** Check the watchdog logs for "would start catch-up" lines and compare them with
  what happened.
- [ ] **Then turn it on:** set `CatchupEnabled: true` in `C:\ProgramData\*Watchdog\config.json`.
- [ ] **Spec:** Progress update.
