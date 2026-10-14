# Labor Performance Migration — Design

**Goal:** Migrate the `Labor Performance` report from `LH_Master_Data` to the `DP_Presentation` backend, faithfully porting its 3 fact tables and 1 dimension, trimmed to real column usage.

**Naming note:** the report is called `Labor Performance` (not "Labor Performance V2") going forward. Confirmed via `fab ls` that both production (`RP - Service Reports`) and `RP - Dev` already carry the Fabric item under this plain name — the "V2" suffix only survives as a stale git folder name in `RP - Service Reports` (`Labor Performance V2.Report`/`.SemanticModel`), never synced back via a Fabric Git Integration commit. This is part of that workspace's already-flagged, separately-deferred git/production drift cleanup (see `project_report_migration_catalog.md`'s Batch 0 notes) — not something this migration needs to fix, just something to be aware doesn't need re-doing.

**Scope decision:** faithful port, not a redesign. The real production `TechnicianEfficiency` source view has a permanent 2-year history window baked into its own SQL (not a Fabric-side limitation), and Brian previously flagged wanting to revisit the report's overall design once a fuller-history rebuild becomes possible. That redesign is explicitly deferred — this migration reproduces the existing 3-fact-table model and its existing history window as-is, matching how every other report in this project has been migrated (build the backend faithfully first, prove the plumbing, consider redesigns later).

---

## Current state (verified, not assumed)

**Report location:** `RP - Dev/Labor Performance.{Report,SemanticModel}` (already correctly named, currently on `LH_Master_Data`). Production mirror is `RP - Service Reports/Labor Performance V2.{Report,SemanticModel}` in git (stale folder name; live Fabric item is already "Labor Performance").

**8 real tables in the semantic model:** `Data Refresh`, `TechnicianAttendance`, `TechnicianPunchedTime`, `TechnicianEfficiency`, `_Measures`, `dim_BranchLocation`, `dim_DateTable`, `dim_Technician_Code_Names`. All 4 backend-sourced tables (`TechnicianAttendance`, `TechnicianPunchedTime`, `TechnicianEfficiency`, `dim_Technician_Code_Names`) are still on `LH_Master_Data`; `dim_BranchLocation`/`dim_DateTable` already point at `DP_Presentation` (standard shared dims, already migrated project-wide).

**Backend build state (checked directly via DuckDB + `fab ls`, not assumed from old scoping notes):**
- `dim_Technician_Code_Names` — **already built and populated** (1,456 rows) in `DP_Presentation`, leftover completed work from the earlier Dimensions catalog audit project (`Build_Gold_TechnicianCodeNames.Notebook`, `DP - Presentation - Dev/Dimensions/`). It's a genuine improvement over production, not just a port: production's own `IsActive` column is a hardcoded-always-`"Active"` literal (its own header even has a `// TODO: Could integrate with HR status...` comment), so the Gold build wires up the real `WkMechFl.IsTerminated` value instead. Trimmed to the 4 columns actually used project-wide (`TechnicianKey`, `TechnicianCode`, `TechnicianDisplayName`, `IsActive`) out of production's 16. **Not registered in `dp_backend_scope.json`** — same "leftover completed work never wired into the pipeline" pattern found on Job Code Parts Advisor's 2 fact notebooks.
- `TechnicianAttendance`, `TechnicianPunchedTime`, `TechnicianEfficiency` — **none exist yet** in `DP_Presentation`. Confirmed via direct `delta_scan` attempts, not just absence from a file listing.
- Silver-layer inputs are all already present: `Silver_Contact`, `Silver_WkMechAdj`, `Silver_WkMechFl`, `Silver_WkMechWk` (all in `DP - Staging - Dev`), and `Silver_WkOthSub` (migrated earlier in this project). This is a Gold-layer-only build — no raw/Silver work needed.

**Real source-view lineage** (resolved 2026-09-10 directly from Brian's own SQL Anywhere `CREATE/ALTER VIEW` pulls — see `project_labor_performance_technician_views_resolved.md` for the full derivation):
- `Technician` = `Contact` (have) JOIN `WkMechFl` (have) on `WkMechFl.Code = Contact.contact_code`.
- `TechnicianAttendance` = `WkMechAdj` grouped by Branch/TechCode/Year/Month, `WHERE end_time IS NOT NULL AND Branch IS NOT NULL`.
- `TechnicianPunchedTime` = `WkMechWk` gated to (date, tech) combos with a same-day `WkMechAdj` attendance record, `WHERE finish_time IS NOT NULL`, with job-type-bucketed hour columns (Internal/Warranty/Retail/Sundry/Fleet/Agreement/Other).
- `TechnicianInvoice` (intermediate, not a report-facing table) = `WkMechWk` LEFT JOIN `WkOthSub` on `(ro_branch, ro_number, job_code, job_type=type)`, `WHERE invoice_no <> ''` and `WHERE year(invoice_date) >= year(getdate())-1` — **the permanent 2-year window**, baked into the source view itself.
- `TechnicianEfficiency` = a plain passthrough of `TechnicianInvoice`, LEFT JOINed to `Technician` only for the display name. Full formula: `EfficiencyRateNumerator = InvoiceHours − OtherHours − ReworkHours`, `EfficiencyRateDenominator = HoursWorked − OtherHours − DelayHours`, where `OtherHours` means "hours on a `WkOthSub` `TYPE='S'` job that isn't a rework job code."

Confirmed via a direct read of `df_TechnicianAttendance_Raw.Dataflow`'s real mashup.pq that production's own "Raw" dataflows are direct ODBC reads of these exact source views (not a from-scratch reimplementation) — the resolved SQL in the memory note is trustworthy and current, not stale.

**Real column usage in the report** (cross-checked via DAX grep, `relationships.tmdl`, `pbir fields list`, a full bookmark grep, and a raw visual-JSON grep for every candidate "maybe unused" column — the 4-method check this project has used on every prior migration, since any single method alone has a known blind spot):
- `TechnicianAttendance`: `AttendanceHours`, `TechCode`, `Branch`, `DateKey`. `Year`/`Month` exist on the table but are never referenced anywhere in the report.
- `TechnicianPunchedTime`: `HoursWorked`, `TechCode`, `Branch`, `DateKey`. None of the 8 job-type-bucketed hour columns (`HoursRetail`/`HoursWarranty`/`HoursInternal`/`HoursSold`/`HoursSundry`/`HoursFleet`/`HoursAgreement`/`HoursOther`) or `JobCode`/`JobType`/`Year`/`Month` are referenced anywhere.
- `TechnicianEfficiency`: `Branch`, `TechCode`, `DateKey`, `InvoiceHours`, `ReworkHours`, `EfficiencyRateNumerator`, `EfficiencyRateDenominator`, `AvailableHours` (the last one only surfaced via `pbir fields list` — a direct visual aggregation, not a named `_Measures` DAX measure, so the DAX-grep-only check alone would have missed it). `WorkedHours`/`BilledHours`/`DelayHours`/`GainLossHours`/`OtherHours`/`LostHours`/`TechnicianName`/`Year`/`Month` are unused.
- Relationships use `TechCode` → `dim_Technician_Code_Names.TechnicianCode` (business key), **not** `TechnicianKey` — confirmed via `relationships.tmdl`. `dim_Technician_Code_Names` itself is already correctly scoped from the earlier Dimensions catalog audit work; no further trim needed there.

**Two "Detail" raw dataflows exist but are out of scope**: `df_TechnicianInvoiceDetail_Raw.Dataflow` and `df_TechnicianPunchedDetail_Raw.Dataflow` produce separate, finer (JobCode/JobType-level) Bronze tables. Since the confirmed real column usage never touches `JobCode`/`JobType`, these are not needed for this report and are not part of this migration.

---

## What gets built

1. **Register `Build_Gold_TechnicianCodeNames.Notebook`** in `dp_backend_scope.json` (no code changes — the notebook is already correct). Confirm it's registered as a `dimensions`/`gold` tier entry matching the existing `Build_Gold_JobCodes` pattern, and re-run once to confirm it's current (it's already populated, but unregistered means it's never been on a schedule).

2. **`Build_Gold_TechnicianAttendance.Notebook`** (`Fact Tables/Labor Performance/`) — from `Silver_WkMechAdj`: group by Branch/TechCode/Year/Month, `WHERE end_time IS NOT NULL AND Branch IS NOT NULL`, filter `Year >= 2023` (matching production's own scope-down), add `DateKey = date(Year, Month, 1)`. Output columns: `Year`, `Month`, `DateKey`, `Branch`, `TechCode`, `AttendanceHours` (all 6 — this table's full column set is already the real-usage set, nothing to trim beyond what production itself already trimmed to).

3. **`Build_Gold_TechnicianPunchedTime.Notebook`** (`Fact Tables/Labor Performance/`) — from `Silver_WkMechWk`, semi-joined to `Silver_WkMechAdj` on matching (date, tech) attendance records, `WHERE finish_time IS NOT NULL`, `Year >= 2023`, `DateKey` added the same way. Output trimmed to `Year`, `Month`, `DateKey`, `Branch`, `TechCode`, `HoursWorked` — dropping the 8 job-type-bucketed hour columns and `JobCode`/`JobType` since confirmed unused (the full bucketed computation doesn't need to happen at all if nothing downstream reads the buckets).

4. **`Build_Gold_TechnicianEfficiency.Notebook`** (`Fact Tables/Labor Performance/`) — the most involved: builds `TechnicianInvoice` as an in-notebook intermediate DataFrame (never persisted as its own table, matching how `Fact_GapAnalysis`/`Fact_BranchAnalysis` build intermediates inline elsewhere in this project) from `Silver_WkMechWk` LEFT JOIN `Silver_WkOthSub` on `(ro_branch, ro_number, job_code, job_type=type)`, `WHERE invoice_no <> ''` and `WHERE year(invoice_date) >= year(current_date)-1` (the real 2-year window). Computes the full derived formula (`hwork`, `invoice`, `rework`, `delay`, `other`, `available`, `gainloss`, `hrs_billed`/`EfficiencyRateNumerator`, `EfficiencyRateDenominator`) per the resolved algebra, LEFT JOINs to the `Technician` view-equivalent (`Silver_Contact` + `Silver_WkMechFl`) only for display purposes if needed, then persists only the 8 real-usage columns: `Branch`, `TechCode`, `DateKey`, `InvoiceHours`, `ReworkHours`, `EfficiencyRateNumerator`, `EfficiencyRateDenominator`, `AvailableHours`.

5. **Report-layer repoint** (Brian's own action in Desktop, per the established process — Claude never pre-edits the TMDL connection string): switch all 4 backend-sourced tables from `LH_Master_Data` to `DP_Presentation`, trim `TechnicianAttendance`/`TechnicianPunchedTime`/`TechnicianEfficiency`'s TMDL column definitions to match the trimmed Gold tables above (`dim_Technician_Code_Names`'s TMDL will naturally shrink to the Gold table's already-correct 4 columns once repointed).

6. Claude creates the `.pbip` in `RP - Dev` — confirmed via direct check that none exists yet for this report (`Report`/`SemanticModel` folders are present but ungrouped into a `.pbip`) — and runs post-publish DuckDB verification once Brian confirms the report looks correct.

---

## Known risks / things to watch for, based on this project's history

- **`dim_JobCodes`-class refresh bug**: the `TechCode`/`TechnicianCode` relationship is a standard many-to-one onto `dim_Technician_Code_Names.TechnicianCode`, which is already deduplicated by construction in its existing Gold notebook (`dropDuplicates(["TechnicianCode"])`). No reason to expect the same unexplained refresh-time "duplicate" phantom seen on Job Code Parts Advisor, but worth keeping in mind if Brian hits anything similar during his own refresh/publish pass.
- **Orphaned-Parquet-files-from-overwrite bug**: confirmed project-wide, not yet fixed everywhere. Every new notebook in this plan should include a `VACUUM ... RETAIN 0 HOURS` step after each write, matching the fix already applied to `Build_Gold_JobCodes`.
- **`DateTime.LocalNow()` UTC bug**: if any of these notebooks compute "current" dates (e.g., `TechnicianInvoice`'s `year(current_date)-1` window), use the already-established UTC-safe pattern, not a naive current-date call.
