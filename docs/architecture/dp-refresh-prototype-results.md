# DP Refresh Redesign — Phase 0 Prototype Results

**Date:** 2026-09-28
**Plan:** `docs/superpowers/plans/2026-09-28-dp-refresh-phase0-prototype.md`
**Spec:** `docs/superpowers/specs/2026-09-28-dp-refresh-pipeline-redesign-design.md`
**Decision needed:** Option 2 (`runMultiple` orchestrators) or Option A (pipeline ForEach with waves)

---

## 1. What was tested

- **Chain:** Labor Performance: 5 Silver notebooks in DP - Staging - Dev (WkMechFl, Contact, WkMechAdj,
  WkMechWk, WkOthSub) and 4 Gold notebooks in DP - Presentation - Dev (TechnicianCodeNames,
  TechnicianAttendance, TechnicianPunchedTime, TechnicianEfficiency).
- **Baseline:** today's method. Each notebook is its own job and its own Spark session, 3 at a time,
  and all Silver finishes before Gold starts (`tools/dp-migration/proto_baseline.py`).
- **Prototype:** `Proto_RunMultiple`, one identical copy per workspace. Each runs its tier with
  `notebookutils.notebook.runMultiple` in one shared Spark session, concurrency 4, 2 retries per notebook.
  Silver's copy ran first, then Gold's.
- All runs happened 2026-09-28 between 4:22 and 5:05 PM CDT, with nothing else running in the DP workspaces.

## 2. Results

| | Baseline (1 job per notebook, 3 at a time) | Prototype (runMultiple, 1 session per tier) |
|---|---|---|
| Spark sessions | 9 | **2** |
| Wall clock (first start → last end) | 402 s (6 min 42 s) | **258 s (4 min 18 s)**, 36% faster |
| Summed Spark session running time | 640 s | **235 s**, 63% less |
| **Capacity used, CU (s)** | **3,406.7** | **2,195.0**, 36% less |
| … Silver tier | 1,588.4 | 792.0 (includes a 17-second failed first attempt, see §5) |
| … Gold tier | 1,818.3 | 1,403.0 |
| Share of F8's daily budget (691,200 CU s) | 0.49% | 0.32% |

CU comes from the Capacity Metrics model (`Metrics By Item And Hour`, 16:00 CDT hour). The baseline's
cost is billed to the 9 notebooks; the prototype's children are billed to the orchestrator that ran
them (the 9 Build_* notebooks show no second charge).

## 3. Correctness

- **Row counts identical** for all 9 output tables between the baseline and the prototype
  (`tools/dp-migration/proto_counts.py`): Silver_WkMechFl 1,454 · Silver_Contact 82,835 ·
  Silver_WkMechAdj 1,588,909 · Silver_WkMechWk 1,537,363 · Silver_WkOthSub 1,175,739 ·
  dim_Technician_Code_Names 1,453 · TechnicianAttendance 13,157 · TechnicianPunchedTime 5,068 ·
  TechnicianEfficiency 2,546.
- **No table landed in the wrong lakehouse.** The 5 Silver_* entries in DP_Presentation are its
  intended OneLake shortcuts to DP_Staging, not real tables.
- **Shared-session settings are compatible:** the only `spark.conf.set` calls in the 9 notebooks are
  the Parquet datetime rebase (CORRECTED), the UTC session time zone, and the Delta retention check.
  TechnicianEfficiency and TechnicianCodeNames don't pin UTC themselves and inherit it in a shared
  session; the counts show no effect.

## 4. Failure drill

The DAG was `Proto_FailProbe` (always raises, retry 1) → `Proto_AfterFail` (depends on it), plus the
unrelated `Build_Gold_TechnicianAttendance`.

| Check | Result |
|---|---|
| The orchestrator survives a child failure | ✅ The orchestrator job **Completed**; its summary recorded the failure |
| An unrelated item still runs | ✅ TechnicianAttendance succeeded |
| The dependent of a failed item never runs | ✅ Proto_AfterFail didn't run (its marker file was never written) |
| How a skipped item is reported | Reported as failed, with the exception text `Job Proto_AfterFail failed due to upstream job Proto_FailProbe failed`. Phase 2 must classify this message as **Skipped** |
| Retry | Not directly visible in the results. The 64 s run time is consistent with one failure + 30 s wait + a second attempt. Treat as *likely*, and confirm in Phase 3's drill via the run snapshot |

## 5. Surprises and limits found

1. **The documented exception import doesn't exist in our runtime.** `from notebookutils.common.exceptions
   import RunMultipleFailedException` (as Microsoft's docs show) failed with `ModuleNotFoundError`. The
   real class is `notebookutils.mssparkutils.handlers.notebookHandler.RunMultipleFailedException`.
   Fixed by catching `Exception` and reading `ex.result` (commit `56b7e4d3`).
2. **One orchestrator per lakehouse is required.** `runMultiple` blocks children whose default lakehouse
   differs from the orchestrator's (see the spec revision). The prototype confirmed the per-lakehouse
   design works.
3. **CU saved (36%) is much less than session time saved (63%).** Spark bills allocated capacity, and a
   shared session holds a larger allocation. The failure drill shows it: one small notebook plus two
   tiny probes cost 829 CU(s), versus 250 CU(s) when Attendance ran alone in the baseline. So:
   - the shared session pays off more as the DAG grows (more work to keep the allocation busy), and the
     full run has ~90 items, not 9;
   - **the orchestrator's session size is a tuning lever** (executor count / autoscale limits and
     `concurrency`). Phase 1 should tune it on a larger chain before the full rollout.
4. **Monitoring tools learned:** Spark driver logs must be fetched with a direct REST call (the `fab` CLI
   can't download non-JSON), and Python cell errors are in the driver's *stdout*. Capacity Metrics'
   hourly table uses upper-case item IDs and local time, and lags about an hour.

## 6. Recommendation

**Proceed with Option 2 (runMultiple orchestrators, one per lakehouse).**

- It works end to end on real notebooks, with identical results.
- It's faster (36% less wall clock) and cheaper (36% less CU) even on a small 9-notebook chain. The
  saving should grow with the full DAG, and session sizing gives further room.
- Failure handling behaves as the design needs: failures are contained, dependents are skipped, and
  unrelated work continues.
- Option A would keep one Spark session per notebook: ~90 session start-ups per run, the most CU, and
  hand-maintained waves.

**Carry into the Phase 1–3 plan:**
- Catch `Exception` around `runMultiple` and classify "failed due to upstream job" as Skipped.
- Tune the orchestrator's session size and `concurrency` on a larger chain (e.g. Customer Anatomy's 4
  levels), measuring CU with the same tools.
- Confirm the retry count in the Phase 3 drill.
- Delete `Proto_FailProbe` / `Proto_AfterFail` when `Run_DP_Refresh` replaces `Proto_RunMultiple`.
