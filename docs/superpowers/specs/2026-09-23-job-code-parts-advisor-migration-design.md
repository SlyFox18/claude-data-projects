# Job Code Parts Advisor Migration — Design Spec

## 1. Problem Statement

`Job Code Parts Advisor` is the first of 2 Service reports Brian is working
through next (Job Code Parts Advisor, then Labor Performance), per his own
"easiest first" sequencing confirmed after a real complexity comparison
this session. Both reports are already published to `RP - Dev` and
confirmed closed in Desktop.

Real investigation (direct TMDL reads, `fab ls` against `DP_Presentation`
and JD's Bronze mirror, `dp_backend_scope.json` grep, job-history checks,
full reads of both real production dataflows) found:

- **The catalog's open question is resolved.** `dim_JobCodes` (plural) is
  a real, actively-used table — 2 model relationships
  (`Fact_GapAnalysis.JobCode`/`Fact_BranchAnalysis.JobCode` →
  `dim_JobCodes.JobCode`) and 4 `LOOKUPVALUE(dim_JobCodes[...])` calls
  inside those 2 calculated tables' DAX. It is **not** a stale reference
  to the already-built `dim_JobCode` (singular) — that table is a
  completely different, derived business-categorization dimension (grain,
  columns, and source all differ). `dim_JobCodes` needs its own real Gold
  build.
- **Both raw sources already exist in JD's Bronze mirror** (`WkCodeFl`
  575,887 rows, `WKCDPART` 1,846 rows — confirmed via direct `fab ls`
  against `JD_FabricOneLake.Workspace/JD_EquipRDB_Production_Bronze
  .Lakehouse`). No new ODBC/Dataflow Gen2 pull needed — this resolves the
  one real open question from the initial complexity assessment.
- **Both production dataflows are trivial.** `df_Dim_WkCodeFl.Dataflow`
  (misleadingly named after its source table, not its `dim_JobCodes`
  output) is a plain 13-column `SELECT ... FROM WkCodeFl` with renames,
  incremental via `ModifiedDate >= 2023-01-01`. `df_Dim_WKCDPART.Dataflow`
  is an 8-column `SELECT ... FROM WKCDPART` with renames, full refresh, no
  filter. Neither has any business logic to reverse-engineer.
- **Both fact tables are already built but unregistered and stale.**
  `Build_Gold_JobCodePartFrequency.Notebook` and
  `Build_Gold_JobCodePartFrequencyBranch.Notebook` already exist in
  `DP_Presentation` (real, complete PySpark, correctly replicate the
  production `wkothsub.InvoiceNumber = InTrans.RONumber` join gotcha) but
  are missing from `deploy/dp_backend_scope.json` — the same
  never-registered-notebook bug class found repeatedly this project.
  Confirmed via job history: last run `2026-09-14`, 9 days stale as of
  this investigation.
- **`dim_FrequencyFilter`** confirmed a static 4-row calculated DAX table
  — no backend work needed.

## 2. Scope

**In scope:**
1. Register `Build_Gold_JobCodePartFrequency` and
   `Build_Gold_JobCodePartFrequencyBranch` in `deploy/dp_backend_scope.json`
   (tier=gold, cadence=daily); run each once to catch up from their
   9-day-stale state.
2. Add 2 new OneLake shortcuts (`WkCodeFl`, `WKCDPART`) from JD's Bronze
   mirror into `DP_Staging`.
3. Build 2 new thin Silver notebooks (`Build_Silver_WkCodeFl`,
   `Build_Silver_WKCDPART`), following this project's established
   Bronze→Silver convention even where there's no real normalization work
   yet needed (matching the precedent set by comparably simple tables like
   `Build_Silver_BranchName`).
4. Build 2 new Gold notebooks (`Build_Gold_JobCodes` → `dim_JobCodes`,
   `Build_Gold_WkcdPart` → `dim_WkcdPart`), faithfully porting each
   production dataflow's column rename/cast logic.
5. Repoint the report's 7 real data tables (`dim_JobCodes`, `dim_WkcdPart`,
   `Fact_JobCodePartFrequency`, `Fact_JobCodePartFrequency_Branch`,
   `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`), with the same
   exhaustive usage-audit-before-trim discipline used on every prior
   report this project.

**Explicitly out of scope:**
- Any change to the real production `df_Dim_WkCodeFl.Dataflow`,
  `df_Dim_WKCDPART.Dataflow`, `Build_Gold_JobCodePartFrequency.Notebook`,
  or `Build_Gold_JobCodePartFrequencyBranch.Notebook` — the 2 existing
  fact notebooks are left exactly as-is, only registered.
- `Fact_GapAnalysis` and `Fact_BranchAnalysis` — confirmed calculated DAX
  tables, no backend dependency (they consume `dim_JobCodes` via
  `LOOKUPVALUE` at the report layer, which is why `dim_JobCodes` must be
  correct before they'll work right, but no notebook work is needed for
  them directly).
- `dim_FrequencyFilter` — confirmed calculated-only, nothing to migrate.
- Labor Performance — the second report in this pair, deliberately
  sequenced after this one.

## 3. Architecture

### 3.1 Registration fix

Straightforward `deploy/dp_backend_scope.json` entries for both
already-built, already-correct fact notebooks — no code changes, just
wiring into the existing `Pipeline_DP_Daily_Refresh`. Each gets run once
manually after registering to catch up to current data immediately.

### 3.2 `Build_Silver_WkCodeFl.Notebook` / `Build_Silver_WKCDPART.Notebook`

Thin passthrough notebooks off the new Bronze shortcuts, matching the
established convention (e.g. `Build_Silver_BranchName.Notebook`) —
preserves every Bronze column unchanged, gets its own Silver table for
consistency with the rest of the backend and to leave room for future
normalization if a real need shows up. Neither table needs deduplication
or any other cleanup — confirmed via the real Bronze schema reads this
session (no obvious data-quality issues surfaced, unlike `jdis_Part_Information`'s
known Weight-duplication issue found on other reports).

### 3.3 `Build_Gold_JobCodes.Notebook`

Faithful port of `df_Dim_WkCodeFl.Dataflow`'s real column selection:
`CODE→JobCode, FACTORY_CODE→FactoryCode, DESCRIPTION→Description,
PART_BRANCH→Branch, EST_HOURS→EstHours, SALE_MTD_QTY→SaleMTDQty,
SALE_YTD_QTY→SaleYTDQty, Make→Make, Model→Model, Work_Cat→WorkCategory,
SERVICE_TYPE→ServiceType, CreationDate→CreationDate,
ModifiedDate→ModifiedDate`, off `Silver_WkCodeFl`. Keeps the same
`ModifiedDate >= 2023-01-01` date-scope filter as the original for parity
(as a plain filter on the full Delta table, not a true incremental fetch —
this is a full-overwrite Gold build like every other Gold notebook in this
project, not an incremental-refresh pattern). No row-level filtering on
`FactoryCode IS NOT NULL` — the original dataflow's own note describing
that filter is guidance for report/DAX-layer consumers, not something
baked into the ETL itself; confirmed the dataflow keeps all rows including
null `FactoryCode`.

### 3.4 `Build_Gold_WkcdPart.Notebook`

Faithful port of `df_Dim_WKCDPART.Dataflow`'s real column selection:
`JOB_CODE→JobCode, FRANCHISE→Franchise, PART_NUMBER→PartNumber, QTY→Qty,
value→Value, Part_Freq→PartFreq, CreationDate→CreationDate,
ModifiedDate→ModifiedDate`, off `Silver_WKCDPART`. Full refresh, no date
filter — matches the original exactly.

### 3.5 Report-layer repoint

Standard exhaustive real-usage audit (`pbir` + DAX-grep against
`_Measures.tmdl` + bookmark check + `relationships.tmdl` cross-reference +
`sortByColumn` inspection) across all 7 real data tables. Particular
attention to `dim_JobCodes` and `dim_WkcdPart` since they're brand new —
confirm the report's real column usage matches what Section 3.3/3.4 build,
and confirm the 4 `LOOKUPVALUE(dim_JobCodes[...])` calls in
`Fact_GapAnalysis`/`Fact_BranchAnalysis` reference columns that genuinely
exist in the new `dim_JobCodes` build.

## 4. Verification Plan

1. **Registration fix**: row-count/freshness comparison for both fact
   tables against real production, confirming the 9-day gap is closed.
2. **`dim_JobCodes`**: row count and a sample of `FactoryCode`/`JobCode`
   pairs compared against real production, via DuckDB.
3. **`dim_WkcdPart`**: row count (~1,846 expected) and a spot-check of a
   few `JobCode`×`PartNumber` assignments against real production.
4. **Post-migration**: Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then the standard post-publish DuckDB
   row-count check across all 7 backend tables.

## 5. What This Spec Deliberately Does Not Cover

- Labor Performance — separate, later work in this same pair.
- Any change to `Fact_GapAnalysis`/`Fact_BranchAnalysis`'s own DAX —
  confirmed calculated-only, out of scope.
- A broader audit of every other already-migrated report's notebooks for
  the same registration gap — already flagged as a standing candidate
  follow-up project in the catalog doc, not undertaken here.
