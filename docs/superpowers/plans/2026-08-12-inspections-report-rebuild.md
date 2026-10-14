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

No new report, no parallel build — all directly on the current V2 model. **Dead-measure removal, renames, and folder organization are DONE (2026-08-13). Descriptions are the one remaining item, not yet started.**

### Dead-measure removal ✅ DONE

Built a full usage dependency graph rather than deleting by name-pattern guesswork: parsed every measure's DAX body, found which measures are directly referenced anywhere in the report (visuals/bookmarks, exact quoted-string match against the PBIR JSON), then computed the transitive closure by following `[OtherMeasure]` bracket references inside each live measure's own DAX — so a measure that's only used by another *unused* measure still correctly shows up as dead, not just top-level orphans. Cross-checked the full candidate list against Copilot's "Verified Answers" definitions too (a place a measure could be referenced without any visual binding).

Applied in 5 verified batches directly in Desktop (multi-select delete → full refresh → spot-check the relevant pages → commit), each batch its own git rollback point:
1. 13 design-iteration/debug measures (`Hero Card HTML - Brand Colors A-D`, `Hero Card HTML Option 2`, `Hero Cards HTML Option 3`, unsuffixed duplicates of now-versioned HTML cards, `Debug - *` ×3)
2. 8 measures (`Top 10 Parts/Services Needed` superseded by `Top 5 * Compact`; `WO Labor/Parts/Total Revenue` orphaned in *both* its original and "-Fixed" bug-fix form)
3. 12 more orphaned Work Order helper measures
4. 9 superseded base-KPI measures (`Hours Invoiced`, `Estimated Hours`, etc. — superseded by "With Inspection" variants)
5. 12 final orphans (job-code breakdown duplicates, Recommendations-page helpers, misc — `Welcome Name`, `Blur`, `CreationDateAge`, `LastPunchDateAge`, `Customer Name`, `Overall % to Goal Inspections`)

**Result: 182 → 128 measures (54 removed, ~30% of the library). Zero regressions confirmed across every page after every batch.**

### Rename cleanup ✅ DONE

6 measures renamed via Desktop's native Rename (F2) — not manual TMDL text edits — so every internal DAX cross-reference and every report visual binding cascaded automatically. Verified zero broken references on both sides afterward.
- `Revenue Breakdown Cards HTML V4` → `Revenue Breakdown Cards HTML`
- `CS690-CS770 Panel HTML V2` → `CS690-CS770 Panel HTML`
- `Discount Panel HTML V2` → `Discount Panel HTML`
- `Parts $ Total Fixed LY` → `Parts $ Total LY`
- `Avg Parts $ /Inspection` → `Avg Parts $ / Inspection` (spacing fix, matches its own Rolling-12 sibling)
- `Total` → `Total Revenue` (clarity — was far too generic a name for a flat field list)

### Display folder taxonomy ✅ DONE

11 folders, applied by editing `_Measures.tmdl` directly while Desktop was closed (Brian's suggestion — far faster and lower-risk than 128 manual property edits in the UI). The folder mapping was verified complete and exact against the actual 128-measure list (script-checked: zero measures missing from the map, zero stale map entries) before writing anything; a timestamped local backup was made before the edit (not committed — git history is the real restore point). Confirmed clean reopen in Desktop afterward, no TMDL syntax errors, no visual regressions.

| Folder | Count |
|---|---|
| Goals & % to Goal | 25 |
| Recommendations Engine | 18 |
| Core KPIs | 15 |
| Work Order List | 13 |
| Page Headers & Subtitles | 12 |
| Work Order Detail | 12 |
| Job Code Breakdown | 10 |
| HTML Cards & Visual Chrome | 9 |
| Trend - Rolling 12 | 8 |
| Pending Queue | 4 |
| _Helpers (hidden) | 2 |

The two `_Helpers` measures (`BranchPerformanceManualSort`, `IsPendingInspection`) were also marked `isHidden` — pure internal plumbing, not meant to be dragged onto a visual directly. One pre-existing hidden measure (`Trend Tooltip - HTML`, hidden before this session) was left untouched.

### Descriptions ✅ DONE (2026-08-13)

All 128 measures now have a real description, written by actually reading each measure's DAX body rather than guessing from its name — grounded in what it calculates, which filters apply, and any calculation-path quirks worth flagging (e.g. `WO List - Total Labor` uses a different formula in matrix context vs. the true grand total).

**Real TMDL gotcha hit and fixed along the way, worth knowing if this repo touches measure descriptions again:** TMDL does **not** support `description: "..."` as a measure property — Desktop hard-fails on reopen with `UnknownKeyword` / `Unsupported property`. The correct syntax is a `///` doc-comment line immediately **before** the `measure` declaration line, not a property inside the measure body. The first attempt (applied while Desktop was closed, per the same safe pattern as the folder work) caught this cleanly on reopen — Desktop refused to load the malformed project rather than corrupting anything — fixed and reverified before the second reopen succeeded.

`dax-measures-library.md` updated: flagged stale at the top (as before), but now also notes the model's own folders + tooltips are the authoritative reference going forward — a full rewrite of that file is optional, not a required follow-up, since it would just be re-documenting what's already visible in Desktop's field list.

**This closes out the full measure-library cleanup — dead-measure removal, renames, folders, and descriptions are all done.**

### Goal calculation group — NOT YET STARTED (optional, lower priority)

- [ ] Build a calculation group for the repeated Goal/%-to-Goal pattern (audit finding #8) — the "Goals & % to Goal" folder above is 25 measures, many following the identical `DIVIDE(actual, goal)` shape; a calculation group could collapse a good chunk of that to one object + a few base measures. Not blocking anything — the folder alone already made this cluster far more navigable than it was.

---

## Shelved (2026-08-13): Full V3 report/model rebuild

**Not being executed — the CU goal is achieved without it (see "Re-scope decision" at the top).** Kept here for reference in case priorities change later and a genuine visual/UX overhaul becomes worth doing on its own merits (not as a side effect of a performance fix):

- Parallel "Inspections V3" PBIP scaffolded fresh in RP-Dev, V2 stays live and untouched until V3 validates — same pattern as the original V1→V2 rebuild.
- Full report page rebuild: re-evaluate the 24-visual Home page and 30-visual Details page (16-filter pivotTable), using the `pbi-report-design` skill for layout guidance. Preserve what works — HTML card visuals with inline CSS, drill-through pages, the bookmark-driven trend toggle on Details.
- Cutover discipline: parallel-run validation against V2 (reuse `validation-doc-hours.md`'s methodology, same -0.01% tolerance bar as the original V1→V2 cutover), promote through RP-Sandbox, cut over to production, archive V2 to `reports/archive/`, update all docs.

---

## Publish and service validation — ✅ DONE (2026-08-13)

Published and refreshed for real in the Fabric service (not just Desktop). **Confirmed: full semantic model refresh in the service is now ~1 minute** (was ~7-8 min baseline immediately prior to this session's fixes, up to 14.5 min historically documented). No errors, no visual regressions on any page. `ARCHITECTURE.md` and `README.md` updated with the final numbers.

**Still open — needs the next ~2 weeks, not something to check today:**
- [ ] Watch the `Inspections` dataset's CU(s) figure in Fabric Capacity Metrics roll off the original 156K/14-day baseline as old expensive refreshes age out of the rolling window and get replaced by the new ~1-min refreshes — this is the number that ultimately proves the capacity win, since a single fast refresh doesn't retroactively change a 14-day rolling total.

## Open questions

- **Incremental refresh window (Task 0.1):** currently 30 days/3 years. Brian wants to tighten to 7 days once a few refresh cycles confirm parts data doesn't get corrected further back than that — revisit after a week or two of stable operation.
- **Task 0.5 (InTrans dedup workaround):** still open, deferred for capacity reasons, no urgency now that the CU goal is otherwise met.
- **Goal calculation group (Phase 1, optional):** confirm the exact set of Goal-family measures to consolidate before building it, since some (like the CS690-CS770-specific goals) may have slightly different business rules than a naive "same pattern" read suggests. Not blocking — the "Goals & % to Goal" folder already makes this cluster far more navigable even without it.

## Session complete (2026-08-13)

Everything from the original audit is done: Phase 0 (CU/performance fixes), Phase 0.7 (ServiceRecommendations redesign), publish + service validation, and the full measure library cleanup (dead-measure removal, renames, folders, descriptions). Only genuinely open items are the ~2-week CU(s) capacity-metrics watch (not something to check yet), Task 0.5 (low priority), and the optional Goal calculation group.
