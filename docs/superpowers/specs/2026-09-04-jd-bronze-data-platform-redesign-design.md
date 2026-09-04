# JD Bronze Migration & Data Platform Redesign — Design Spec

**Date:** 2026-09-04
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

Ben reported one wrong dollar value on the Parts Promo report (RO 1985073: Original Sale Value showed $229.18, should be $627.64). Root-cause investigation traced this to a real, confirmed bug in the `df_InTrans_Incremental` dataflow that feeds `LH_Master_Data`'s `InTrans_Incremental` table — not a bug in the report's Power Query or DAX.

**Confirmed root cause:** The dataflow (`fabric-workspace-docs/workspaces/LH_Master_Data/Dataflows/01 - Raw Sources/df_InTrans_Incremental.Dataflow/mashup.pq`) pulls source rows with `WHERE Trans_Datetime > '<watermark>'`. A companion notebook (`Update_InTrans_Watermark.Notebook`) then sets the watermark to `MAX(TransDatetime)` across everything already loaded. When a row commits to the source `InTrans` table *after* a later-timestamped row from the same burst has already been pulled and used to advance the watermark, that earlier row is permanently excluded — the watermark has already moved past its timestamp, so it can never satisfy `>` again. Verified directly:
- Source `EquipRDB` (via `dsn=EquipRDB64`) has 9 rows for RONumber 1985073, matching the printed invoice ($627.64 in non-promo parts) exactly.
- `InTrans_Incremental` in `LH_Master_Data` has only 6 — missing the 3 chronologically-earliest lines.
- Every other affected order shows the identical pattern: earliest lines of a burst missing, later lines present.

**Scope of the bug, quantified (not guessed):** compared source vs. `InTrans_Incremental` for all 1,429 promo-active repair orders since 2026-07-01. **11 orders affected (~0.8%)**, totaling **$18,890.49** understated non-promo sales. One order (1986996) was missing entirely. List: `promo_ro_mismatches.csv` (session scratchpad, not yet committed anywhere permanent).

**What changed the direction of the fix:** While investigating, discovered a second, independent Fabric pipeline already running on the tenant — `JD_FabricOneLake` workspace, `JD_EquipRDB_Production_Bronze` lakehouse — set up by John Deere as prep for their Purview data-sharing program. It's a near-complete 1:1 mirror of the source `EquipRDB` database (140+ raw tables, back to 2010), fed by a proper Fabric Data Pipeline copy mechanism rather than a hand-rolled Power Query watermark. **Verified this data does not have the bug:** `JD_EquipRDB_Production_Bronze.InTrans` has all 9 rows for RO 1985073, matching source exactly.

Given John Deere is retiring the on-prem Equip system (a forced future migration to Fabric + Dynamics 365 + TBD, no full specifics yet), and this JD-provided pipeline already gives a head start on a properly-sourced backend, the decision was made to treat this as an opportunity to redesign the data backend around JD's Bronze mirror rather than just patch the existing watermark bug in place.

**Also discovered along the way (both addressed by this design):**
- **Capacity:** `PL_EquipRDB_To_Fabric_Incremental` was running every 30 minutes, 24/7, with zero known consumers — the single largest CU consumer on the F8 capacity over the trailing 14 days (301,784 CU-s), ahead of everything else including our own entire refresh pipeline. Brian paused this trigger directly (workspace Admin; this is our data, our call). `PL_EquipRDB_To_Fabric_Full` (nightly, ~30 min, complete reload) was left untouched.
- **Git integration audit:** confirmed real, existing misconfiguration — `RP - Service Reports` and `RP - Financial Reports` (both production) are git-connected to `dev`, not `main`; `RP - Dev` (private staging) is connected to `main`, backwards from intent; its git folder is still named `/workspaces/RP - Service Sandbox`, stale since the April rename. `LH_Master_Data` — the single production backend workspace — has no dev/sandbox tier at all and is connected to `dev`. **This design does not fix the existing mismatches** (see Non-Goals) but is built to not repeat them.

---

## 2. Scope

### In scope
- New bronze/silver/gold backend architecture sourced from `JD_EquipRDB_Production_Bronze`, replacing `LH_Master_Data`'s home-grown ingestion for Equip-sourced data
- New Fabric workspace topology for that backend, connected to git correctly from creation
- Variable Library for environment-specific parameterization (replacing hardcoded workspace/lakehouse GUIDs)
- Report deployment process redesign (`fabric-cicd` adoption), since it shares the same underlying parameterization and git-promotion mechanism as the backend work and was confirmed to directly relate to why reports have been manually republished over production
- Pilot: rebuild Parts Promo (`dim_RepairOrder` + `Fact_PartsPromo`) on the new backend as the first real validation of the whole design, confirming the 11 known-bad orders compute correctly afterward
- A path to retire or narrow `LH_Master_Data` over time as reports migrate off it

### Out of scope / explicitly deferred
- **Direct Lake mode** for gold-layer semantic models — agreed as a separate phase 2, since it changes report-layer behavior (not just backend), not folded into this design
- **Materialized Lake Views** — newer declarative Fabric feature that could eventually replace hand-rolled notebook transforms for silver/gold; not mature enough to commit to yet, revisit later
- **Untangling the existing git mismatches** found in `RP - Service Reports`, `RP - Financial Reports`, and `RP - Dev` — live production workspaces, real risk of a bad Fabric git reconnect; deserves its own careful pass, not a rider on this design
- **Data mesh / domains** — considered via research, not relevant at this scale (one-person data team, single dealer)
- Fixing Parts Promo's report content/measures beyond what naturally follows from correct source data — this is a backend fix, not a report redesign
- Deciding `PL_EquipRDB_To_Fabric_Incremental`'s eventual re-enabled cadence — deferred until the new silver layer actually needs fresher-than-nightly bronze data; it stays paused until then

---

## 3. New Backend Architecture

Confirmed via current Microsoft Fabric documentation (not stale assumption) that medallion architecture (bronze/silver/gold) remains Microsoft's own current recommended pattern for this exact scenario. The redesign is not "abandon medallion," it's "implement it with the Fabric capabilities the current `LH_Master_Data` setup never used."

### Workspace topology (4 new workspaces)

| Workspace | Contents | Git branch |
|---|---|---|
| `DP - Staging - Dev` | Bronze shortcuts + silver tables (dev) | `dev` |
| `DP - Staging - Prod` | Bronze shortcuts + silver tables (prod) | `main` |
| `DP - Presentation - Dev` | Gold tables + semantic models (dev) | `dev` |
| `DP - Presentation - Prod` | Gold tables + semantic models (prod) | `main` |

(`DP` = Data Platform; naming is a strawman, easy to change before creation.) This follows Microsoft's own recommended staging/presentation split — a security boundary so business users can eventually get gold-only access without touching bronze/silver — and gives the backend the Dev/Prod tier it has never had. A separate backend "Sandbox" tier was explicitly decided against: reports already have their own Sandbox validation gate (`RP - Sandbox`), and the backend rarely needs a stakeholder-facing staging step the way reports do.

### Bronze layer — shortcuts, not copies

Microsoft's own bronze-layer guidance: if the source is already in OneLake, use a shortcut instead of copying. `JD_EquipRDB_Production_Bronze` already holds the Equip-sourced tables we need (`InTrans`, `ArMaster`, `InMaster`, etc.) in OneLake. Each `DP - Staging` workspace gets **OneLake shortcuts** into that lakehouse — zero duplicate storage, zero duplicate ingestion pipeline to maintain or debug, and JD's copy mechanism (already verified not to have the watermark-drop bug) becomes someone else's problem to keep correct.

Confirmed gap: `jdis_Part_Information` is not in JD's Bronze mirror (it's sourced from a different JD system, not the Equip DB dump) — nor are `dim_EngagedAcres` (external CSV) or Commodity Code Groups (SharePoint CSV), which were never Equip-sourced anyway. These keep their own small, existing-style ingestion into the Staging lakehouse's bronze area. A full inventory of what else `LH_Master_Data` ingests that ISN'T Equip-sourced (and therefore needs to keep its own ingestion path) is a task for the implementation plan, not fully enumerated here.

### Silver layer — PK-based, not watermark-based

Fabric notebooks read the bronze shortcuts and produce cleaned, deduped, properly-typed Delta tables. **Key design principle, direct response to the root-cause bug:** builds use merge/upsert keyed on the table's true primary key (`TransId` for InTrans-equivalent), not an append-plus-advancing-watermark. This makes the original failure mode (a row commits late, the watermark has already moved past its timestamp, the row is dropped forever) structurally impossible — worst case a full rebuild converges to the correct state, it never permanently loses a row.

### Gold layer

Same dimension/fact pattern already in use today (`dim_RepairOrder`, `Fact_PartsPromo`, `dim_CustomerList`, etc.), rebuilt from the new silver tables instead of `InTrans_Incremental`. Tooling choice (Dataflow Gen2 vs. notebook) is deferred to the implementation plan.

---

## 4. Git & Environment Strategy

- **Repo model unchanged:** keep the existing two-repo split (`data-projects` for local dev/docs, `fabric-workspace-docs` as the Fabric git-integration mirror). Decided against a third dedicated repo — no new tooling to learn, and the actual problem (wrong branch bindings, not the repo model itself) gets fixed by doing the new workspaces correctly from creation.
- **Branch mapping:** `DP - Staging - Dev` and `DP - Presentation - Dev` connect to `dev`; `DP - Staging - Prod` and `DP - Presentation - Prod` connect to `main`. Correct from day one — no retrofitting, unlike the existing report workspaces.
- **Variable Library:** one library defining environment-specific values (workspace IDs, lakehouse IDs, connection details), with Dev and Prod value sets, activated per workspace. Replaces every hardcoded GUID currently baked into `LH_Master_Data`'s `.pq` files (confirmed present in every raw-table/dimension query inspected during this investigation — `dim_RepairOrder.pq`, `Fact_PartsPromo*.pq`, `Fact_InTrans_AllPromo.pq` all hardcode `workspaceId`/`lakehouseId` literals).

---

## 5. Report Deployment Process

**Confirmed via current Fabric documentation, not assumption:**
- A workspace can still only be assigned to one Deployment Pipeline at a time — the exact limitation Brian hit originally when `RP - Dev` held reports destined for both `RP - Service Reports` and `RP - Parts Reports`. Unchanged.
- Native Deployment Pipelines **do not support PBIR reports at all** (current documented limitation) — the format this repo's reports are actually authored in. This is likely the deeper reason manual Desktop-republish became the de facto production promotion method, independent of the workspace-fan-out problem.

**Adopted fix: `fabric-cicd`** — the Microsoft-officially-supported, product-team-recommended Python library for exactly this case (git-driven, PBIP/PBIR-aware, one branch → many target workspaces via config, reads the same Variable Library as the backend). This becomes the one deployment mechanism used consistently for both the new backend and the report layer.

**Workflow change:** Power BI Desktop publish is only ever pointed at a Dev workspace, never at production. Promotion from Dev onward — Sandbox, and each of the three production workspaces — happens through git (commit → PR → merge to `main`), with `fabric-cicd` (triggered via GitHub Actions) performing the actual deploy to the correct target workspace(s). This removes the "open Desktop, make a fix, republish over whatever's in production" pattern entirely, since production is never a Desktop publish target once this is in place.

Scope of applying this to the *existing* `RP - Parts/Service/Financial Reports` promotion flow — versus building it fresh only for whatever the new backend eventually feeds — is an implementation-planning question, not resolved here.

---

## 6. Migration & Rollout Plan

1. Stand up the 4 `DP -` workspaces + Variable Library + git connections (empty shells, correct branch mapping from creation)
2. Bronze: OneLake shortcuts into `JD_EquipRDB_Production_Bronze` for Equip-sourced tables; confirm `PL_EquipRDB_To_Fabric_Full`'s nightly reload cadence is sufficient before deciding whether `PL_EquipRDB_To_Fabric_Incremental` needs re-enabling
3. Silver: first table built is the InTrans replacement (PK-merge based, per Section 3)
4. Gold: first tables built are `dim_RepairOrder` + `Fact_PartsPromo`, rebuilt on the new silver
5. **Pilot validation:** repoint Parts Promo's semantic model at the new gold tables, validate in `RP - Dev` — specifically confirming all 11 known-bad orders from Section 1 now compute correctly, and that unaffected orders/totals are unchanged
6. Once proven, pick the next report to migrate. `LH_Master_Data` is narrowed and eventually retired as reports move off it — end state is no remaining reason for it to exist once every report that depended on Equip-sourced data is on the new backend and any non-Equip sources have moved to `DP - Staging`'s bronze area

**Expected mixed state during rollout:** some reports reading from the new `DP - Presentation` gold layer, others still reading from `LH_Master_Data`, until migration completes. This is expected and acceptable — nothing breaks for a report until it's deliberately migrated.

---

## 7. Open Questions / Risks / Follow-ups

- Full inventory of `LH_Master_Data` content that is NOT Equip-sourced (and therefore needs its own bronze ingestion path in `DP - Staging` rather than a JD shortcut) is not yet enumerated — needed before Section 3's bronze layer is fully built out
- `PL_EquipRDB_To_Fabric_Incremental`'s re-enable decision (whether/when, and at what cadence) is explicitly deferred per Section 2
- Whether `fabric-cicd`-based deployment gets applied to the *existing* report promotion flow, or only to whatever the new backend eventually feeds, is unresolved — implementation-planning question
- The existing git branch mismatches (`RP - Service Reports`, `RP - Financial Reports`, `RP - Dev`) remain unfixed by design; worth its own future spec
- Silver/gold tooling choice (notebooks vs. Dataflow Gen2 for gold specifically) not locked in
- Workspace naming (`DP - Staging/Presentation - Dev/Prod`) is a strawman pending Brian's confirmation before creation

---

## 8. Testing / Validation Plan

- Confirm bronze shortcuts expose the same row counts/date ranges as querying `JD_EquipRDB_Production_Bronze` directly (sanity check the shortcut mechanism itself before building anything on top)
- Confirm the new silver InTrans-equivalent reproduces `LH_Master_Data`'s existing historical totals **except** for the 11 known-bad orders, which should now match source exactly (cross-check against `promo_ro_mismatches.csv`)
- Re-run the same source-vs-backend row/dollar comparison methodology used in Section 1's investigation against the new silver table, across a wider historical window, to confirm no new gaps were introduced
- Validate Parts Promo in `RP - Dev` against the printed-invoice ground truth for RO 1985073 and at least 2-3 of the other 10 known-bad orders before promoting further
- Confirm Variable Library value sets resolve correctly per workspace (Dev value set active in `DP - * - Dev`, Prod in `DP - * - Prod`) — a wrong activation would silently point one environment at another's data
- Confirm a `fabric-cicd` deployment run correctly targets only its intended workspace(s) with no cross-contamination, before relying on it for anything production-facing
