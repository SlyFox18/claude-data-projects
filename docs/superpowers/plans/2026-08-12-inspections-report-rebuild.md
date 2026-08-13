# Inspections Report — Audit-Driven Rebuild Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task labels matter in this plan.** Tasks marked `[AUTOMATABLE]` are file edits in this repo (`.pq`/`.tmdl` reference copies) a subagent can do directly. Tasks marked `[MANUAL]` require Power BI Desktop GUI work (Incremental Refresh dialog, drag-drop visuals, Publish) or the Fabric portal — `data-projects` is a local reference workspace, not Fabric-integrated, so editing a file here does not change what's deployed. `[MANUAL]` steps still get exact instructions; Brian executes them and reports back.

**Goal:** Cut the Inspections semantic model's CU footprint (currently #2 consumer on the capacity, 156K CU(s)/14 days) and refresh time (currently ~14.5 min). **Status update (2026-08-13): the CU goal is being achieved via targeted in-place fixes, not a rebuild — see "Re-scope" below.**

**Re-scope decision (2026-08-13):** The original plan paired the CU fix with a full parallel "V3" rebuild, reasoning that the measure/report disorganization problem might need a ground-up rebuild to solve alongside the performance problem. Phase 0 execution proved otherwise: `Fact_WorkOrderParts`'s incremental refresh fix alone took that table from 10-18 minutes to **15 seconds**, and isolated single-table refresh testing identified `ServiceRecommendations` (a DAX calculated table, recomputed in full on every refresh because it depends on `Fact_LaborJobSummary`/`Fact_PendingInspections`) as the dominant remaining cost at **8-9 minutes** — confirmed directly by Brian via single-table refresh timing in Desktop. Once that's fixed, the CU goal — the actual driver of this whole effort — is achieved without a rebuild. **The parallel V3 rebuild (old Phases 1-4) is shelved, not deleted** — reconsider it later if the report ever needs a genuine visual/UX overhaul, but it's not needed to hit today's goal. The measure-organization complaint ("I can't keep up with what's what") gets addressed with in-place cleanup on the current report instead: continue removing dead objects (already underway), add display folders and descriptions to the existing 182 measures, consolidate the repeated Goal/%-to-Goal pattern into a calculation group — all directly on live V2, no parallel build.

**Architecture:** Single track now — everything happens in place on the current V2 model/report:
1. **Phase 0 (mostly done):** Surgical CU/performance fixes — incremental refresh, calculated-column fixes, relationship fix, dead-object removal.
2. **Phase 0.7 (new, top priority):** Redesign `ServiceRecommendations` — this is now the single highest-value remaining task, since it dwarfs everything else Phase 0 already fixed. Needs a dedicated design pass (DAX optimization vs. moving the logic to a Dataflow Gen2 query) before implementation — not detailed yet, pick this up next.
3. **Phase 1 (re-scoped, was "V3 measure rebuild"):** In-place measure library cleanup on the current model — display folders, descriptions, calculation group for the Goal pattern, continued dead-measure removal. No new report, no parallel build.

**Tech Stack:** Power BI Desktop (TMDL/PBIR — confirmed this project's `reports/current/` folder is the live PBIP Desktop has open, edits sync directly, no separate "reference copy" sync step needed for this project), Fabric Dataflow Gen2 (Power Query M), Fabric Lakehouse `LH_Master_Data`, DAX calculation groups, `pbir`/`pbi`/`fab` CLIs.

---

## Audit Summary (full detail was posted in chat 2026-08-12 — condensed here for reference during execution)

| # | Finding | Severity | Where |
|---|---|---|---|
| 1 | `Fact_WorkOrderParts` semantic-model partition does a full re-import every refresh — no incremental refresh policy | 🔴 Critical | `Fact_WorkOrderParts.tmdl:143-150` |
| 2 | Bidirectional relationship `Fact_PendingInspections.JobCode ↔ ServiceRecommendations.InspectionJobCode` | 🔴 Critical | `relationships.tmdl:26-30` |
| 3 | `ServiceRecommendations` calculated table: nested `GENERATE`/`CALCULATETABLE` over ~50K rows, fully recomputed every refresh | 🔴 Critical | `ServiceRecommendations.tmdl:56-124` |
| 4 | Dead/test measures live in production (`Test - *` ×5, `Revenue Breakdown Cards HTML V2`/`V3` orphaned) | 🔴 High | `_Measures.tmdl` |
| 5 | `TransactionDateKey` calculated column uses row-context `FORMAT()` instead of integer math | 🔴 High | `Fact_WorkOrderParts.tmdl:130-141` |
| 6 | 4 hidden `INFO.VIEW.*()` self-documentation calculated tables (`New Report Tables/Columns/Measures/Relationships`) — unreferenced, reprocess every refresh | 🟡 Medium | `model.tmdl:18-22` |
| 7 | 0 of 189 measures have a `displayFolder`; 0 have a `description`; only 1 is hidden | 🟡 Medium | `_Measures.tmdl` |
| 8 | 12 near-identical Goal/%-to-Goal measures — collapsible into one calculation group | 🟡 Medium | `_Measures.tmdl` |
| 9 | Dense pages (Home 24 visuals, Details 30 visuals, one pivotTable with 16 visual-level filters) | 🟡 Medium | `pbir tree` output |
| 10 | *(New, found while drafting this plan)* `Fact_WorkOrderParts.pq` Step 9 does a downstream `Table.Distinct` dedup workaround for a Dec31/Jan1 `InTrans_Incremental` duplication bug — that bug was root-fixed at the source on 2026-08-11 (see memory `project_intrans_incremental_dedup_2026-08-11`). This workaround may now be redundant dead weight. | 🟡 Medium | `Fact_WorkOrderParts.pq:397-417` |

What's already good (preserve in V3): auto date/time disabled, `DIVIDE()` used everywhere, upstream incremental refresh already correct on `wkothsub`/`wkmechwk`/`WKROFILE`, star schema otherwise clean, Fact_LaborJobSummary/Fact_PendingInspections are already fast (3 min / 1.5 min).

---

## Phase 0: Immediate CU relief — ✅ DONE (2026-08-13)

**Target:** Cut Inspections dataset refresh CU cost and the ~10-18 min Fact_WorkOrderParts bottleneck, without touching report layout or measure names — zero risk to what users see.

### Task 0.1 ✅: Add incremental refresh policy to Fact_WorkOrderParts (semantic model)

Done. Window locked in at **30 days incremental / 3 years archive** (started wide per Brian's call, tighten to 7 days later once a few cycles confirm nothing outside that window changes). Required an unplanned prerequisite step not in the original plan: Desktop won't enable incremental refresh until `RangeStart`/`RangeEnd` parameters exist in the query first (Manage Parameters, both typed `Date/Time`), and the filter step has to reference those parameters directly in the M formula bar, not just the UI's date-filter dialog. Also hit and fixed a real type mismatch: `TransactionDate`'s underlying SQL type is `Date`, not `DateTime` (confirmed by the `UnderlyingDateTimeDataType = Date` annotation already in the model) — comparing it directly against the `DateTime`-typed `RangeStart`/`RangeEnd` throws `Expression.Error`. Fixed by inserting a `Table.TransformColumnTypes(..., {{"TransactionDate", type datetime}})` step before the range filter. Final M partition (confirmed synced to `Fact_WorkOrderParts.tmdl`):

```m
let
    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_Fact_WorkOrderParts = Source{[Schema="dbo",Item="Fact_WorkOrderParts"]}[Data],
    #"Changed Type" = Table.TransformColumnTypes(dbo_Fact_WorkOrderParts,{{"TransactionDate", type datetime}}),
    #"Filtered Rows" = Table.SelectRows(#"Changed Type", each [TransactionDate] >= RangeStart and [TransactionDate] < RangeEnd)
in
    #"Filtered Rows"
```

TMDL `refreshPolicy` block confirmed present: `rollingWindowGranularity: year`, `rollingWindowPeriods: 3`, `incrementalGranularity: day`, `incrementalPeriods: 30`.

**Result: confirmed via isolated single-table refresh in Desktop — Fact_WorkOrderParts alone now refreshes in 15 seconds (was 10-18 minutes).** Total model refresh (all tables) also dropped from the prior ~7-8 min baseline to ~5m18s-5m38s on the two post-publish on-demand refreshes — smaller overall improvement than hoped for at the whole-model level, because Phase 0.7 below (ServiceRecommendations) turned out to be the larger remaining cost, not yet fixed at time of this refresh.

One unrelated finding surfaced during first live publish attempt: the automated 6:30 AM Data Factory refresh failed once (`DM_GWPipeline_Gateway_MashupDataAccessInternalError`, cascading operation-cancelled errors via `SPI-Data-Gateway` gateway) — confirmed this predates the republish (still running the old model) and looks like a transient gateway issue, not caused by this work. Matches the pre-existing "Check Fact Table Pipeline" item on Brian's to-do list from before this session started — treat as a separate issue, not in scope here.

### Task 0.2 ✅: Replace `TransactionDateKey`'s `FORMAT()` calculated column with integer math

Done and confirmed synced to `Fact_WorkOrderParts.tmdl`. Spot-checked: `12/24/2024` → `20241224`.

```dax
TransactionDateKey =
    IF(
        ISBLANK(Fact_WorkOrderParts[TransactionDate]),
        BLANK(),
        YEAR(Fact_WorkOrderParts[TransactionDate]) * 10000
            + MONTH(Fact_WorkOrderParts[TransactionDate]) * 100
            + DAY(Fact_WorkOrderParts[TransactionDate])
    )
```

### Task 0.3 ✅: Fix the bidirectional relationship

Done. Cross-filter direction changed from Both to Single (`Fact_PendingInspections` → `ServiceRecommendations`). Verified safe first: every measure that touches `ServiceRecommendations` filters it explicitly via `CALCULATETABLE(ServiceRecommendations, ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode)` rather than relying on automatic cross-filter propagation, and only one visual (the Recommendations table) references the table at all — grep-confirmed against both `_Measures.tmdl` and the report's `definition/` folder.

**Correction to original audit:** the relationship's **Many-to-Many cardinality** (not just its bidirectionality) is legitimate and should stay — both `ServiceRecommendations[InspectionJobCode]` and `Fact_PendingInspections[JobCode]` genuinely contain repeating values (multiple recommended-service rows per inspection code; multiple pending work orders per job code), so neither side qualifies as a "one" side. Only the `bothDirections` cross-filter setting was the actual problem, and that's fixed. Worth testing later (low priority) whether the relationship can be removed entirely, since nothing appears to use it at query time — but not urgent.

### Task 0.4 ✅: Remove dead measures and scaffolding tables

Done. Verified via grep against both `_Measures.tmdl` (internal DAX references) and the report's `definition/` folder (visual/bookmark references) that none of the following were referenced anywhere before deleting:
- `Test - Selected JobCode`, `Test - WO Count`, `Test - Parts Revenue`, `WO List - Total Parts Test`, `Parts Discount Test`
- `Revenue Breakdown Cards HTML V2`, `Revenue Breakdown Cards HTML V3` (V4 confirmed as the only one any visual references)
- `New Report Tables`, `New Report Columns`, `New Report Measures`, `New Report Relationships` (also removed from `model.tmdl`'s `ref table` list)

**Confirmed post-deletion: measure count dropped from 189 to 182 (exactly the 7 deleted), all 4 scaffolding tables' files gone from the repo.**

### Task 0.6 ✅ (new task, found 2026-08-13): Same `FORMAT()` fix on Fact_LaborJobSummary.WorkOrderCreationDateKey

While investigating the ServiceRecommendations slowness, Brian checked `Fact_LaborJobSummary`'s calculated columns and found the identical `INT(FORMAT(..., "YYYYMMDD"))` pattern as Task 0.2, plus two lower-priority notes:

- **`WorkOrderCreationDateKey`** — same anti-pattern, same fix, **done**, confirmed synced, spot-checked (`7/10/2024` → `20240710`, `2/10/2025` → `20250210`):

```dax
WorkOrderCreationDateKey =
IF(
    ISBLANK(Fact_LaborJobSummary[WorkOrderCreationDate]),
    BLANK(),
    YEAR(Fact_LaborJobSummary[WorkOrderCreationDate]) * 10000
        + MONTH(Fact_LaborJobSummary[WorkOrderCreationDate]) * 100
        + DAY(Fact_LaborJobSummary[WorkOrderCreationDate])
)
```

- **`CreationMonthYear`** (`FORMAT(..., "MMM-YY")`, line ~295) — also row-context `FORMAT()`, but produces a text label, not a numeric key, so a pure integer-math swap doesn't apply the same way. Lower priority, not the current bottleneck — revisit later, possibly via a lookup against `dim_DateTable` instead of computing per-row.
- **`IsPendingInspection`** (line ~330) — a calculated column doing a row-by-row `FILTER()` scan of the entire `Fact_PendingInspections` table per row. Technically the "filter a table instead of a relationship" anti-pattern, but `Fact_PendingInspections` is tiny (~100 rows), so real-world cost is low. Not worth touching now.

### Task 0.5 [MANUAL, needs source-data verification, deferred]: Re-check the InTrans dedup workaround in Fact_WorkOrderParts.pq

Not started — deferred pending capacity headroom, since this needs a live query against the dataflow/warehouse.

- [ ] **Step 1:** Now that `InTrans_Incremental`'s root duplication bug is fixed (2026-08-11, see memory), pull a fresh row count from `Fact_WorkOrderParts` before and after removing Step 9's `Table.Distinct` dedup in a dataflow test copy — do **not** edit the production dataflow directly.
- [ ] **Step 2:** If row counts match with the dedup removed, it's confirmed dead weight from the pre-fix era — remove it in the real `df_Fact_WorkOrderParts` dataflow and update `Fact_WorkOrderParts.pq` in this repo to match.
- [ ] **Step 3:** If row counts differ, the dedup is still catching something real — leave it in place and note why in the file header instead of removing it.

**Phase 0 status:** Fact_WorkOrderParts itself is fully solved (15 sec). Whole-model refresh time has not yet dropped to the target range because Phase 0.7 (below) — not originally part of Phase 0 — turned out to be the larger remaining cost. Task 0.5 still open, low priority, no capacity impact from leaving it as-is.

---

## Phase 0.7: Redesign `ServiceRecommendations` — ✅ DONE (2026-08-13)

**Result: whole-model refresh in Desktop dropped to ~10 seconds** (was ~7-8 min baseline, up to 14.5 min historically documented). Combined with Phase 0's Fact_WorkOrderParts fix, both of the model's real cost centers are now resolved.

**What was built:** Option A (Dataflow Gen2/M rewrite) was chosen and executed. The DAX calculated table's exact logic (co-occurrence frequency of services on completed inspection work orders) was translated to a set-based SQL query and validated **before** anything was built in Fabric — prototyped via DuckDB directly against the Lakehouse (`LH_Master_Data`, workspace `b48cdb35-7ce3-46de-96df-d70db77649cb`, same pattern as `.claude/queries/adhoc/kurt-sales/`), and cross-checked row-for-row against the live DAX table's actual output for `IS-CS690 INSPECT` (10 rows checked, every value matched exactly including floating-point totals) before writing a single line of production M.

- New dataflow: `df_Fact_ServiceRecommendations` in `LH_Master_Data → Dataflows → 04 - Fact`, query saved to this repo at `projects/inspections - report/queries/fact-tables/Fact_ServiceRecommendations.pq`. Uses `Value.NativeQuery` against the same SQL Analytics Endpoint the semantic model already connects through, pushing the join/aggregation down to the warehouse engine rather than the M engine.
- Output: Lakehouse table `dbo.Fact_ServiceRecommendations`. First dataflow run: **53 seconds**, row count **9,688** — exact match to the old DAX table's row count on the same day.
- Model cutover: old calculated `ServiceRecommendations` table deleted, new table renamed from `Fact_ServiceRecommendations` to `ServiceRecommendations` in Desktop (so all ~15 existing measures and the relationship needed zero changes — they reference the table by name, not by source). Relationship to `Fact_PendingInspections` rebuilt (Many-to-many cardinality kept, single cross-filter direction, same as the Phase 0 fix).
- Confirmed via TMDL: exactly one `ServiceRecommendations.tmdl` remains, `m`-partition sourced, correct lineage tag carried through from the build.

**Not yet done:** this has only been validated in Desktop against local refreshes — not yet published to the service. See "Next: publish everything" below.

---

## (superseded — kept for history) Original Phase 0.7 plan

**Why this jumped the queue:** isolated single-table refresh testing in Desktop (2026-08-13) measured `ServiceRecommendations` alone at **8 min 11 sec**, and confirmed that refreshing `Fact_LaborJobSummary` (whose own data load is fast) also triggers a full `ServiceRecommendations` recalculation as a dependency (`Fact_LaborJobSummary` refresh alone: 8 min 40 sec — consistent with LaborJobSummary's own fast load plus the same ~8 min ServiceRecommendations recalc tacked on). With Fact_WorkOrderParts now at 15 seconds, `ServiceRecommendations` is unambiguously the dominant remaining cost in the whole model — by a wide margin. This is also why the original audit (finding #3) already flagged it as expensive; what's new is the confirmation that it's not just theoretically expensive, it's *the* bottleneck now.

**Root cause (from `ServiceRecommendations.tmdl`):** it's a DAX calculated table — `GENERATE` over all distinct pending inspection job codes (111 total codes exist in the business logic), and for each one, nested `CALCULATETABLE`/`SUMMARIZE`/`CALCULATE` operations scanning `Fact_LaborJobSummary` (~50K rows) to find co-occurring services and their frequency/revenue. DAX calculated tables cannot be partitioned or incrementally refreshed — this always fully recomputes on every single model refresh, regardless of whether the pending queue actually changed.

**Not detailed task-by-task yet — this needs a real design decision before implementation, not a quick edit.** Two candidate approaches to evaluate:

- **Option A — move the logic to a Dataflow Gen2 / M query.** The underlying logic (for each pending inspection code, find historical work orders with that code, self-join to find other job codes on those same work orders, group and count) is expressible as a self-join + group-by, which a warehouse-side SQL/M query should execute far faster as a set-based operation than DAX's per-row nested table evaluation. This also moves the cost out of the semantic model's refresh entirely, matching the pattern already used for the other fact tables. Bigger effort: needs the co-occurrence logic translated from DAX to M/SQL and validated against the current DAX output before cutover.
- **Option B — keep it in DAX but optimize the expression.** Lower effort, keeps the logic in a language that's easier to maintain in Power BI, but calculated tables can never be incrementally refreshed no matter how well-optimized the expression is — this caps how much Option B can ever improve refresh time, even in the best case.

- [ ] Decide between Option A and Option B (needs a focused design conversation — see "Open questions" below)
- [ ] Validate whichever approach is chosen produces identical output to the current `ServiceRecommendations` table before cutover (reuse the frequency/revenue worked example already in `ARCHITECTURE.md`: IS-CS690 → GEN REPAIR 1 at 55% frequency, as a known-good check)
- [ ] Re-measure isolated refresh time after the fix, same method as this session's diagnostic (single-table refresh in Desktop)

**Exit criteria:** `ServiceRecommendations` (or its replacement) refreshes in well under a minute, whole-model refresh drops to genuinely low single digits, and the `Inspections` dataset's CU(s) figure on the next 14-day capacity window drops materially from the 156K baseline.

---

## Phase 1 (re-scoped 2026-08-13, was "V3 measure rebuild"): In-place measure library cleanup

No new report, no parallel build — all directly on the current V2 model, once Phase 0.7 is done. Not detailed task-by-task yet. At a minimum:

- Inventory all 182 remaining measures (post-Task 0.4 deletions), sort into: keep as-is / fold into a calculation group / merge with a duplicate / delete (dead).
- Add a `displayFolder` to every measure (0 of 182 have one today) — folder taxonomy TBD, something like `Inspections/`, `Labor/`, `Parts/`, `Goals/`, `_Helpers/` for hidden intermediate measures.
- Add a `description` to every measure that isn't obviously self-explanatory from its name — this is what actually solves "I can't keep up with what is what," since descriptions surface as tooltips in the field list.
- Build a calculation group for the repeated Goal/%-to-Goal pattern (audit finding #8) — 12 near-identical measures collapsible into one calculation group + a handful of base measures.
- Hide every intermediate/helper measure that isn't meant to be dragged onto a visual directly (currently only 1 of 182 is hidden).
- Adopt a naming rule going forward: no `V2`/`V3`/`Test` suffixes land in the committed model — WIP measures get finished or deleted before leaving them in place "just in case" (directly caused Task 0.4's cleanup).

**Deliverable:** an updated `dax-measures-library.md` reflecting the cleaned-up measure set (folder, description, and whether it replaced/merged an old measure) — same doc convention as today, not a new format.

---

## Shelved (2026-08-13): Full V3 report/model rebuild

**Not being executed — the CU goal is achieved without it (see "Re-scope decision" at the top).** Kept here for reference in case priorities change later and a genuine visual/UX overhaul becomes worth doing on its own merits (not as a side effect of a performance fix):

- Parallel "Inspections V3" PBIP scaffolded fresh in RP-Dev, V2 stays live and untouched until V3 validates — same pattern as the original V1→V2 rebuild.
- Full report page rebuild: re-evaluate the 24-visual Home page and 30-visual Details page (16-filter pivotTable), using the `pbi-report-design` skill for layout guidance. Preserve what works — HTML card visuals with inline CSS, drill-through pages, the bookmark-driven trend toggle on Details.
- Cutover discipline: parallel-run validation against V2 (reuse `validation-doc-hours.md`'s methodology, same -0.01% tolerance bar as the original V1→V2 cutover), promote through RP-Sandbox, cut over to production, archive V2 to `reports/archive/`, update all docs.

---

## Next: publish everything and validate in the service

Phase 0 and Phase 0.7 are both done and confirmed **in Desktop only** — nothing has been published to the Fabric service since these fixes landed. Before calling the CU goal achieved:

- [ ] Publish the model (RP-Dev or wherever Brian validates first)
- [ ] Trigger a full refresh, time it, confirm it completes without error
- [ ] Trigger a second refresh, confirm it stays fast (not just the first-run number)
- [ ] Open the Recommendations page and a few others in the published report, confirm everything renders correctly against real service data (not just Desktop's local cache)
- [ ] After a few nightly pipeline cycles, check the `Inspections` dataset's CU(s) figure in Fabric Capacity Metrics against the original 156K/14-day baseline — this is the number that actually proves the goal was hit, since whole-model refresh time in Desktop and CU cost in the service are related but not identical measurements
- [ ] Once stable, update `ARCHITECTURE.md`'s Performance Optimization table and `README.md` with the new numbers (this session's results: Fact_WorkOrderParts 15 sec, whole model ~10 sec in Desktop)

## Open questions

- **Incremental refresh window (Task 0.1):** currently 30 days/3 years. Brian wants to tighten to 7 days once a few refresh cycles confirm parts data doesn't get corrected further back than that — revisit after a week or two of stable operation.
- **Task 0.5 (InTrans dedup workaround):** still open, deferred for capacity reasons, no urgency now that the CU goal is otherwise met.
- **Goal calculation group design (Phase 1):** confirm the exact set of Goal-family measures to consolidate before building the calc group, since some (like the CS690-CS770-specific goals) may have slightly different business rules than a naive "same pattern" read suggests. Phase 1 (measure cleanup) is now unblocked and can start whenever Brian wants — it's no longer gated on anything.
