# DP self-healing, phase 3a (quieter Equip alerts, notebook warnings, exact-duplicate collapse) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn two kinds of 2026-10-19 morning noise into either silence or self-healing.
- **Watchdog Equip blips.** The watchdog alerted on a single failed Equip test: JD gateway 00:37, back healthy by
  00:47. It should alert only after two failed checks in a row, like its other checks.
- **Duplicate row in Bronze.** JD's midnight Full copy returned one InMaster row twice: part 8/D/E63245, identical in
  all 73 columns. Equip had it once. `Build_Gold_PartMasterHistory` refused to write.
  - **Fix:** Silver collapses rows that are identical in every column, and says so in the summary email. Rows that
    share a key but differ still fail.
  - **The "says so" part** becomes a general channel: any notebook can end with
    `notebookutils.notebook.exit("WARN: …")`, and the summary lists it under Warnings.

**Architecture:**
- **Watchdog:** a separate `SourceFailures` counter in its state, gated by the existing `FailuresBeforeRestart` (2).
- **Warning channel:** `orchestrator_core.classify_results` reads each runMultiple result's exit value; a value
  starting `WARN:` becomes an item `warning`. The glue adds `"<item>: <text>"` to `summary["warnings"]`.
- **Silver:** `Build_Silver_PartInformation` finds duplicate InMaster keys. If every duplicate row is identical, it
  applies `distinct()` to InMaster before the joins and exits with a `WARN:` line. Otherwise it raises.

**Tech Stack:** Windows PowerShell 5.1 + Pester 3.4 (watchdog), Python/pytest (deploy), PySpark (notebook).

**Repos:**
- watchdog: **data-projects** `projects/jd-bronze-pipelines/gateway-watchdog/`;
- everything else: **fabric-workspace-docs** (`dev`);
- notebook rules doc: data-projects `docs/architecture/dp-notebook-rules.md`.

**Not in 3a:**
- 2b catch-up + watchdog trigger (phase 3b);
- 2d maintenance helper (3c);
- 2c capacity retry, deferred: Prod has never had one, and a delayed re-run inside Fabric is awkward. Revisit
  when one happens.

---

### Task 1: Watchdog: Equip test alerts after two failures in a row

**Files:** `projects/jd-bronze-pipelines/gateway-watchdog/GatewayWatchdog.psm1` (`New-WatchdogState`,
`Get-WatchdogDecision` Live branch), `GatewayWatchdog.Tests.ps1`, `README.md` (the "Each check" step 3 line).

Today (`Get-WatchdogDecision`, branch `elseif ($o.Gateway -eq 'Live')`): `Source -eq 'Failed'` sets problem
`source-failed` immediately.

- [ ] **Step 1: Pester tests** (follow the file's existing style and helpers):
  - first `Source=Failed` (Live, Running) → no problem, no alert. Summary mentions "check 1 of 2". State
    `SourceFailures = 1`.
  - second consecutive → problem `source-failed`, `Alert = $true`.
  - `Source=Ok` after one failure → `SourceFailures = 0`, no "Recovered" (nothing was alerted).
  - after an alerted `source-failed`, `Source=Ok` → `Recovered = $true` (unchanged behaviour).
  - a state file without `SourceFailures` (from today's installs) works (treated as 0).
- [ ] **Step 2:** run `powershell -NoProfile -Command "Invoke-Pester .\projects\jd-bronze-pipelines\gateway-watchdog"`
  → new tests fail.
- [ ] **Step 3: Implement.**
  - `New-WatchdogState` adds `SourceFailures = 0`.
  - `$new` copies `SourceFailures = [int]$State.SourceFailures`. A missing key reads as `$null` → 0 under
    StrictMode 2? Check: hashtable lookups of missing keys return `$null` without error; `[int]$null` = 0.
  - In the Live branch: if `Source -eq 'Failed'`, increment. Below `FailuresBeforeRestart`, set summary
    `"Equip test through the gateway failed (check $n of $($Config.FailuresBeforeRestart) before alerting)"` and no
    problem. At or above it, keep today's `source-failed` problem/summary/detail. Otherwise reset to 0.
  - Every non-Live branch resets `SourceFailures` to 0, since the source isn't checked there.
  - Windows PowerShell 5.1 only: no `??`, no ternary.
- [ ] **Step 4:** Pester → all pass.
- [ ] **Step 5: README** step 3: "Failure on two checks in a row (about 20 min) → alert only; a single failed test
  (Equip busy overnight, e.g. 2026-10-19 00:37) is logged, not emailed."
- [ ] **Step 6: Commit** (data-projects, on `dev`): the three files → "Gateway watchdog: alert on the Equip test
  only after two failures in a row".
- [ ] **Step 7 (Brian, after merge):** re-run the installer on both machines to update the scripts.
  - SPI01SR2034W: `.\Install-GatewayWatchdog.ps1 -Live`
  - SPI00T4022W11: `.\Install-GatewayWatchdog.ps1 -Gateway SPI -Live`

  Config, secret and state are kept.

### Task 2: Notebook warning channel

**Files:** `deploy/orchestrator_core.py` (`classify_results`), `deploy/test_orchestrator_core.py`,
`deploy/orchestrator_glue.py` (where Silver/Gold results are copied into `summary["items"]`, ~lines 399-442), rendered
`Run_DP_Refresh` notebooks.

- [ ] **Step 1: Find the exit-value key.** Check how `notebookutils.notebook.runMultiple` reports a child's exit
  value. Fabric docs: each activity result is a dict with `exitVal` and `exception`. Confirm the key name in
  Microsoft Learn ("NotebookUtils runMultiple") and note it in a comment. If unsure, accept both `exitVal` and
  `exitValue`.
- [ ] **Step 2: Tests**

```python
def test_classify_results_carries_notebook_warnings():
    res = classify_results({"A": {"exitVal": "WARN: collapsed 1 exact duplicate row", "exception": None},
                            "B": {"exitVal": "some other value", "exception": None},
                            "C": {"exitVal": None, "exception": None}}, ["A", "B", "C"])
    assert res["A"] == {"status": "Succeeded", "error": None, "skipped_because": None,
                        "warning": "collapsed 1 exact duplicate row"}
    assert "warning" not in res["B"] and "warning" not in res["C"]


def test_item_warnings_reach_the_summary_without_changing_status():
    items = {"Build_Silver_PartInformation": {"status": "Succeeded", "tier": "silver", "warning": "collapsed 1 row"}}
    assert item_warnings(items) == ["Build_Silver_PartInformation: collapsed 1 row"]
```

- [ ] **Step 3: Implement.**
  - **`classify_results`:** for a succeeded result, `ev = r.get("exitVal", r.get("exitValue"))`. If it's a str
    starting `"WARN:"`, add `"warning": ev[5:].strip()[:500]`.
  - **New pure `item_warnings(items) -> list`:** sorted by item name.
  - **Glue:** in the Silver run and Gold run phases, after the items are put into `summary["items"]`, extend
    `summary["warnings"]` with `item_warnings` for that phase's items only, so nothing is duplicated across
    phases.
  - **Confirm:** the dp_refresh_log row builder (`row(...)` in glue) ignores unknown keys, so `warning` doesn't
    break the log write.
- [ ] **Step 4:** `python deploy/render_orchestrator.py; python -m pytest deploy -q` → pass.
- [ ] **Step 5: Commit** core, test, glue and both rendered notebooks → "Run_DP_Refresh: notebooks can report
  warnings (exit value 'WARN: …') to the summary email".

### Task 3: `Build_Silver_PartInformation` collapses exact duplicates

**Files:** `workspaces/DP - Staging - Dev/Build_Silver_PartInformation.Notebook/notebook-content.py`.

- [ ] **Step 1: Add a cell right after `in_master = spark.read.table("InMaster")`:**

```python
# JD's Full copy has returned an InMaster row twice (2026-10-19: 8/D/E63245, identical in all 73 columns; Equip had
# it once). Rows identical in EVERY column are collapsed - that keeps no arbitrary survivor - and reported as a
# warning. Rows that share the key but differ still fail: that's a real conflict.
_KEY = ["BRANCH", "FRANCHISE", "PART_NO"]
_dup_keys = in_master.groupBy(*_KEY).count().filter("count > 1")
_n_dup_keys = _dup_keys.count()
inmaster_warning = None
if _n_dup_keys:
    _dupe_rows = in_master.join(_dup_keys.select(*_KEY), _KEY)
    _distinct_per_key = _dupe_rows.distinct().groupBy(*_KEY).count().filter("count > 1").count()
    if _distinct_per_key:
        raise ValueError(f"InMaster has {_distinct_per_key} key(s) whose rows differ - refusing to pick one "
                         f"(dp-notebook-rules: no arbitrary survivors)")
    _before = in_master.count()
    in_master = in_master.distinct()
    _examples = ", ".join("/".join(str(r[k]) for k in _KEY) for r in _dup_keys.limit(5).collect())
    inmaster_warning = (f"Bronze InMaster had {_before - in_master.count()} exact duplicate row(s) on "
                        f"{_n_dup_keys} key(s) (e.g. {_examples}); collapsed. Equip has each once - a JD copy "
                        f"read issue; tonight's Full load normally replaces it.")
    print(inmaster_warning)
```

- [ ] **Step 2: Row-count assertion.** The existing `assert silver_count == in_master_count` already uses
  `in_master.count()` after the collapse. Check it's computed from the collapsed DataFrame, and move it if not.
- [ ] **Step 3: Exit value.** Add a final cell at the very end of the notebook, after the verification cell:

```python
if inmaster_warning:
    notebookutils.notebook.exit("WARN: " + inmaster_warning)
```

  `exit` stops the notebook, so it must be the last cell. Check the repo's other notebooks for how
  `notebookutils` is referenced, and make sure the cell has the standard `# METADATA` block.
- [ ] **Step 4: Dev test.** Push, Git sync Dev staging, then run the notebook in Dev:
  `python C:\Users\bfox\Documents\Git-Projects\data-projects\tools\dp-migration\run_item.py` (check its usage)
  or Dev `Pipeline_DP_Refresh` `mode=items, items=Build_Silver_PartInformation`. Dev Bronze may have no
  duplicate: then expect a normal success with no warning. That proves the clean path. The duplicate path is
  proven by the next real occurrence, or by Prod tomorrow if tonight's Full doesn't clean it.
- [ ] **Step 5:** `python deploy/dag_check.py; python deploy/hygiene_audit.py; python -m pytest deploy -q`.
- [ ] **Step 6: Commit** the notebook → "Build_Silver_PartInformation: collapse InMaster rows identical in every
  column, warn; differing duplicates still fail".

### Task 4: Rules doc, troubleshooting, release

- [ ] **data-projects `docs/architecture/dp-notebook-rules.md`:** under the "no arbitrary survivors" rule, add the
  exception: "Rows identical in **every** column may be collapsed with `distinct()`; nothing is chosen. Report it
  with `notebookutils.notebook.exit("WARN: …")` so the summary email shows it. Rows that share a key but differ
  must still fail." Commit with Task 1's watchdog change, or separately.
- [ ] **fabric-workspace-docs `docs/TROUBLESHOOTING.md`:** add a row.
  - **Symptom:** `Build_Gold_PartMasterHistory`: "Silver key … has duplicates or nulls".
  - **Cause:** JD's Full copy returned an InMaster row twice (2026-10-19).
  - **Fix:** Silver now collapses exact duplicates and warns; if the rows differ, compare Bronze against Equip for
    the key. Tonight's Full load normally replaces it.
- [ ] **`docs/REPORT-DEVELOPMENT.md` or `NEW-DATA-SOURCE.md`** (whichever lists notebook conventions): one line on
  the `WARN:` exit value.
- [ ] **Release:** `merge_preview.py`, PR dev → main. Brian merges and deploys; the claim task claims anything
  re-published (this release shouldn't change the pipelines). Brian re-runs the watchdog installer on both
  machines (Task 1 Step 7).
- [ ] **Spec:** Progress note "phase 3a live …", and the 2c deferral with its reason.
