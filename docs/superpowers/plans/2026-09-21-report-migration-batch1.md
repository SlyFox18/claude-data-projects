# Report Migration Batch 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repoint 6 confirmed-clean Tier 1 reports (32 tables total) from the old
`LH_Master_Data` Fabric warehouse to the new `DP_Presentation` Gold-layer warehouse,
continuing the report migration project this session already proved on Batch 0
(Bin Location Report, Physical Inventory, 60+ Days Past Due — complete 2026-09-16).

**Architecture:** Each table's M-query `partition` source in its `.tmdl` file gets a
one- or two-line edit swapping the `Sql.Database(...)` connection string/database
name from `LH_Master_Data` to `DP_Presentation`. 31 of 32 tables keep the exact same
`Item="<TableName>"` (the Gold layer was built under identical real table names,
confirmed by this project's own history). The one exception, `jdis_Part_Information`
in Parts Adjustments, is repointed to `Item="Silver_PartInformation"` (the notebook
rebuilt earlier this same session) — confirmed to need no column changes since its
existing 33-column model already matches `Silver_PartInformation`'s real schema
exactly.

**Tech Stack:** Power BI Desktop (`.pbip`/TMDL text format), DuckDB + `delta_scan()`
for pre/post verification against live `DP_Presentation` data, Fabric Git integration
for publishing `RP - Dev` changes back to `fabric-workspace-docs`.

**Reference:** `docs/architecture/report-migration-catalog.md` (the approved,
existing design for this whole multi-batch project — no new brainstorming needed).

---

## Real process correction (2026-09-21) — read before executing Tasks 3-7 again

**Tasks 2-7's original Steps 1-3 (Claude directly editing/committing the
`Sql.Database(...)` connection-string swap in `data-projects`) turned out to be the
wrong layer, and were reverted for 5 of the 6 reports** (commits `9acce508`,
`566136ee`, `1230ac95`, `2d7d8fe2`, `93c31482` — reverting `54d0c1f8`, `82003bf1`,
`25b3c766`, `1957ca97`, `4ed253d5` respectively). Unique Parts Customers' edit
(`34e40766`) was left as-is since Brian was already mid-workflow on it when this was
caught and it's moot regardless of file content.

**The real, established workflow (confirmed directly by Brian, matching how Batch 0
actually worked, not how this plan originally assumed):**
1. Brian opens the report from its `data-projects` folder in Power BI Desktop.
2. Brian makes any needed minor adjustments himself in Desktop (e.g., deleting
   unused `INFO.VIEW.*`-backed helper tables like `Current-Columns`/`Current-Measures`/
   `Current-Relationships`/`Current-Tables` if they're just taking up space) — this
   is Brian's own review pass, not something Claude pre-edits.
3. **Brian switches the data source himself**, interactively, inside Desktop's own
   Power Query / Data Source Settings UI — this is the actual point where the
   `LH_Master_Data` → `DP_Presentation` switch happens. Claude pre-editing the TMDL
   text file ahead of this step doesn't help and can actively confuse things: if
   Desktop already has the report open (loaded with the old model in memory) when
   Claude's edit lands on disk, Desktop's own state — not the edited file — wins the
   moment Desktop writes anything back to disk, silently reverting the edit and
   making it look like something broke when nothing did.
4. Brian publishes to `RP - Dev`.
5. Once published, Claude creates the `.pbip` at
   `fabric-workspace-docs/workspaces/RP - Dev/<Report>.pbip` (Fabric's own Git
   integration never creates this file) — this becomes the new working copy.
6. **All future edits to that report happen by opening Desktop from the `RP - Dev`
   location going forward** — the `data-projects` copy is frozen from this point on,
   kept only as a fallback/reference copy to verify the migrated report against, and
   is eventually archived (Task 8).

**Corrected Tasks 3-7 (Stock Check, Negative On Hand-On Hand No Bin, Parts Not
Re-Ordered 24 Hours, Parts Adjustments, Planter Inspection Part Sales):** Steps 1-3
are no longer Claude's job. Brian opens each from `data-projects`, does his own
cleanup pass, switches the source himself, and publishes — exactly like Task 2 and
exactly like Batch 0. The specific real mapping/column-rename knowledge already
gathered for each report (the exact old/new table names, the `jdis_Part_Information`
→ `Silver_PartInformation` rename and why no column changes are needed, the two
`dim_Parts.PartNumber`-relationship-exposed reports, etc.) stays valuable as
reference/verification context — Brian can cross-check what Desktop shows against it
— it's just not something Claude pre-applies to the files anymore.

**Once Brian publishes each report to `RP - Dev`, Claude's role resumes:** create the
`.pbip`, then run that report's post-publish verification script (already written
per-task below) against the live `DP_Presentation` data to confirm the real numbers
match.

## Real process correction #2 (2026-09-21) — how this batch actually finished

**What actually happened, for all 6 reports at once (not per-report as originally
planned):** Brian opened each report from `data-projects`, did his own cleanup pass,
and published each to `RP - Dev` **as-is, still pointed at `LH_Master_Data`** —
deliberately, so the published `RP - Dev` copy matches production exactly and the
`data-projects` copy stays a clean, unmodified fallback. He then explicitly asked
Claude to do the connection-string repoint on the `RP - Dev` copies directly.

This is a real, load-bearing distinction from the "Real process correction" section
above: **once a report's data-source switch hasn't happened yet AND nobody has it
open in Desktop, Claude editing the TMDL files directly is safe** (confirmed with
Brian before proceeding — none of the 6 were open in Desktop at this point). The
earlier problem was specifically about Desktop's in-memory state winning over an
external file edit — that risk doesn't exist when Desktop isn't running against the
file at all. **The actual final pattern for this and future batches:** Brian
publishes the unmodified report to `RP - Dev` first (creating the clean baseline +
preserving the fallback), confirms nothing's open in Desktop, then Claude does the
repoint directly on the `RP - Dev` copy and creates the `.pbip` if missing.

**Real result:** all 6 reports repointed directly in `fabric-workspace-docs`
(commits `6d9c4918`, `3c956739`, `a817a8e3`, `37617707`, `1bdcf64c`, `adde403d` —
Unique Parts Customers, Stock Check, Negative On Hand-On Hand No Bin, Parts Not
Re-Ordered 24 Hours, Planter Inspection Part Sales, Parts Adjustments
respectively), pushed to `origin/dev`. 5 new `.pbip` files created (Parts
Adjustments already had one). A consolidated review (spec + code-quality) passed
all 6 with nothing flagged — connection strings byte-identical, all
business-logic steps (`Filtered Rows`, `Extracted Date`, `FilterValidCustomers`)
confirmed untouched, `jdis_Part_Information` → `Silver_PartInformation` rename
confirmed correct with no extra column-handling steps added, `dim_PAType.tmdl`
confirmed excluded.

**Real, still-open next step, not yet done:** these commits only update the
*Git-tracked* content in `fabric-workspace-docs` — the live `RP - Dev` Fabric
workspace itself still needs a **Source control → Update** (in the Fabric portal)
to actually pull this change into the live semantic models. Given this session's
own real precedent earlier today (the `DMTS_MonikerWithUnboundDataSources`
incident — a semantic model's SQL data-source credentials can come back unbound
after a redeploy even when previously set), **it's plausible each of these 6
reports' new `DP_Presentation` connection will need its Data source credentials
set/confirmed in the Fabric portal** (Settings → Data source credentials) before a
real refresh succeeds — flagging this now so it isn't a surprise, not confirmed
either way yet.

---

## Real facts this plan relies on (verified 2026-09-21, not assumed)

- **Old connection:** `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- **New connection (confirmed via Batch 0's already-migrated Bin Location Report):**
  `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`
- **Real folder paths for each report's SemanticModel** (confirmed via direct
  directory listing — these do NOT all follow the same `reports/current/` pattern
  the catalog doc assumes):
  - Report 1: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/`
  - Report 2: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/` (no `current` subfolder)
  - Report 3: `projects/negative on hand - on hand no bin - report/reports/current/Negative On Hand-On Hand No Bin.SemanticModel/definition/tables/`
  - Report 4: `projects/parts not re-orderd 24 hours - report/report/current/Parts Not Re-Ordered 24 Hours.SemanticModel/definition/tables/` (singular `report/`, and note the real folder's misspelling "re-orderd")
  - Report 5: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/`
  - Report 6: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/` (`new report/`, not `current/` — an `old report/` folder also exists with stale V1 content, not in scope)
- **No `DateTime.LocalNow()` bugs found** across all 32 tables or any of the 6
  reports' `Data Refresh` utility tables — every one already uses the fixed
  `DateTimeZone.UtcNow()`/`SwitchZone()` pattern from `.claude/queries/DATA-REFRESH-TEMPLATE.pq`.
  Confirmed via direct read, not assumed. No action needed in this plan for that bug
  class. (One DAX-layer analog exists in Report 4's `Fact_PartsNotReordered[Business
  Hours Since Sale]` calculated column using `NOW()` — already independently
  DST-fixed there too. Do not touch it.)
- **No column-trimming-without-`Table.SelectColumns` bugs found** — every table's
  M-query is currently a straight passthrough (or has only row filters/date-extraction
  transforms, never column drops), and every model's declared column list matches its
  M-query's real output 1:1. No action needed for that bug class either, **except** see
  the `jdis_Part_Information` note below.
- **`jdis_Part_Information` → `Silver_PartInformation` (Parts Adjustments only):**
  Parts Adjustments' `jdis_Part_Information` table declares exactly 33 columns —
  `Branch, PartNumber, Description, Franchise, Source, SLC, CommodityCode,
  DealerGroupCode, QuantityOnHand, BinQty, BulkBin, Bin, BackOrderQty, Returnable,
  PackageQty, InventoryCost, Cost, SellPrice1, ListPrice, Current12MoSales,
  Current12MoDollars, Previous12MoSales, Previous12MoDollars, VendorCode,
  DateCreated, DateLastRequested, StocktakeDate, BulkBinQty, PendingQty, SuperTo,
  SuperFrom, OnOrder, Weight` — confirmed to be the **exact same 33-column set**
  `Silver_PartInformation` now has (per this session's own `jdis_Part_Information`
  rebuild, `docs/superpowers/plans/2026-09-18-jdis-part-information-rebuild.md`),
  just in a different column order. **No `Table.SelectColumns` or
  `Table.TransformColumnTypes` step is needed** — a straight connection+`Item=` swap
  is correct and sufficient. (This is a genuinely different situation from Bin
  Location Report's own `jdis_Part_Information → Silver_PartInformation` repoint,
  which narrows to 18 columns and casts `PackageQty` to `Int64.Type` — do not copy
  that pattern here. Parts Adjustments' own `PackageQty` is already typed `string` in
  its model, matching `Silver_PartInformation.PackageQty`'s real `VARCHAR` type
  exactly — no cast needed.)
- **Two reports are exposed to this project's known `dim_Parts.PartNumber`
  control-character relationship bug** (a stray `\r`/`\t` in 3 of 316,365
  `PartNumber` values that `Table.Trim()`/`F.trim()` doesn't strip, found and fixed
  in `Build_Gold_Parts.Notebook` during the dims catalog work) — both because they
  have real fact-to-`dim_Parts.PartNumber` relationships, not just a `PartNumber`
  column:
  - Report 5 (Parts Adjustments): `Fact_PartsAdjustments`, `Fact_AdjustmentPairs`,
    `Fact_AdjPairs_Summary` all relate to `dim_Parts.PartNumber`.
  - Report 6 (Planter Inspection Part Sales): `Fact_PlanterInspectionParts`,
    `Fact_PlanterPartSales`, `Fact_PlanterInvoiceAllParts` all relate to
    `dim_Parts.PartNumber`.
  The bug itself is already fixed at the source (`Build_Gold_Parts.Notebook`), so
  this shouldn't recur — but Tasks 6 and 7 (below) include an explicit relationship
  cardinality check as a real verification step for these two reports specifically,
  since they're the ones that would show a symptom if it ever did.
- Reports 1–4 have **no** `dim_Parts.PartNumber` relationship (some have a
  `PartNumber` column on a fact table, but it isn't used as a join key anywhere) —
  not exposed to that bug class, no special check needed for them.
- **Established real workflow (confirmed via Batch 0, and memory of a real mistake
  to avoid repeating):** the file edits in this plan happen directly in the
  `data-projects` repo copy (`projects/<report>/reports/...`) — **not** in
  `fabric-workspace-docs`. Brian's actual Desktop workflow opens reports from
  `data-projects`. After Brian confirms a report looks right and publishes it to
  `RP - Dev` from Desktop, and commits via Fabric Git integration in the portal, the
  `fabric-workspace-docs` mirror updates automatically — editing that mirror
  directly, as happened by mistake once during Batch 0, is the wrong file to touch.

---

### Task 1: Pre-migration verification — confirm all 32 target tables are real and match expectations

**Files:** none — verification only.

- [x] **Step 1: Write and run a DuckDB check confirming every target table/column exists in `DP_Presentation`**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# DP - Presentation - Dev workspace/lakehouse IDs (confirmed earlier this session)
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"

tables = [
    "Fact_InTrans_UniqueCustomers", "Fact_Invoice_UniqueCustomers", "dim_BranchLocation",
    "dim_CustomerList", "dim_DateTable", "dim_UniqueCustomers",
    "Fact_InternalWorkOrders", "dim_Salesperson",
    "Fact_NegativeOnHand_OnHandNoBin",
    "Fact_PartsNotReordered",
    "Fact_AdjPairs_Summary", "Fact_AdjustmentPairs", "Fact_PartsAdjustments",
    "dim_AdjustmentType", "dim_Parts", "Silver_PartInformation",
    "Fact_PlanterInspectionParts", "Fact_PlanterInspections",
    "Fact_PlanterInvoiceAllParts", "Fact_PlanterPartSales",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

Expected: every table prints a real row count, none print `MISSING/ERROR`. This is
the actual proof every table this batch depends on genuinely exists in
`DP_Presentation` before touching any report file — don't skip this and assume the
catalog doc's dependency list is still accurate.

- [x] **Step 2: If anything is missing, stop and report back before proceeding**

Do not start editing report files if any table from Step 1 is missing — that means
the catalog doc's assumption for that report is stale and needs to be re-investigated
before this plan can proceed for that specific report.

**Real result (2026-09-21):** all 20 unique tables across the 6 reports confirmed
present in `DP_Presentation` with real row counts (e.g. `dim_Parts`: 316,634,
`Silver_PartInformation`: 1,112,990, `Fact_PartsAdjustments`: 278,467). Nothing
missing — proceeding to Task 2.

---

### Task 2: Repoint Unique Parts Customers (6 tables)

**Files:**
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/Fact_InTrans_UniqueCustomers.tmdl`
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/Fact_Invoice_UniqueCustomers.tmdl`
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/dim_UniqueCustomers.tmdl`

- [x] **Step 1: Edit each table's partition source**

All 6 tables in this report use the identical simple pattern — find this exact line
in each file:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No other line changes — every `Item="<TableName>"` stays exactly as-is (`Fact_InTrans_UniqueCustomers`, `Fact_Invoice_UniqueCustomers`, `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_UniqueCustomers` respectively).

- [x] **Step 2: Confirm no other `LH_Master_Data` references remain in this report**

```bash
grep -rn "LH_Master_Data" "projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/"
```
Expected: no output.

- [x] **Step 3: Commit the file changes**

```bash
git add "projects/unique parts customers - report/reports/current/Unique Parts Customers.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Unique Parts Customers to DP_Presentation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Real result (2026-09-21):** commit `34e40766` passed both reviews, but turned out
to be the wrong layer entirely — see "Real process correction" above. Brian already
had this report open in Desktop when this was caught, so the edit is moot regardless
of file content (Desktop's own loaded state governs what gets written back, not the
file on disk). **Not reverted** (no need to — Brian proceeds with his own normal
workflow below either way, superseding it).

- [ ] **Step 4: Brian — clean up, switch source yourself, and publish**

In the already-open `Unique Parts Customers.pbip` session, finish your cleanup pass
(e.g. removing the unused `Current-*`/`INFO.VIEW.*` helper tables), switch the data
source for all 6 tables from `LH_Master_Data` to `DP_Presentation` yourself in
Desktop's Data Source Settings (keeping each `Item=`/table name the same — no
renames in this report), confirm the report's visuals still render sensibly (row
counts, customer names, branch names all look real). Publish to `RP - Dev`, then in
the Fabric portal for that workspace, **Source control → Commit** to push the
change into `fabric-workspace-docs`.

- [ ] **Step 5: Post-publish verification — real row counts match what Desktop showed**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
for t in ["Fact_InTrans_UniqueCustomers", "Fact_Invoice_UniqueCustomers", "dim_BranchLocation",
          "dim_CustomerList", "dim_DateTable", "dim_UniqueCustomers"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{t}')").fetchone()[0]
    print(f"  {t}: {n:,} rows")
```

Compare these real counts against what the refreshed report's own visuals/table
view show in Desktop (check via a card visual or the Data pane's row count) — they
should match exactly, since the semantic model does no row-dropping transforms on
any of these 6 tables. A mismatch means the Desktop refresh didn't actually pick up
the new source, not a data problem.

---

### Task 3: Repoint Stock Check (4 tables)

**Files:**
- Modify: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/Fact_InternalWorkOrders.tmdl`
- Modify: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `projects/stock-check - report/reports/Stock Check.SemanticModel/definition/tables/dim_Salesperson.tmdl`

- [ ] **Step 1-3 (superseded — see "Real process correction" above):** ~~Claude
edits the connection string, verifies, commits~~. Claude's edit (commit `54d0c1f8`)
was reverted in `9acce508` — this is Brian's own action inside Desktop now, per the
corrected workflow.

- [ ] **Step 4: Brian — open, clean up, switch source, and publish**

Open `Stock Check.pbip` from `data-projects` (note: this project has no
`current`/`archive` subfolder split yet — the `.pbip` sits directly under
`reports/`). Make any needed cleanup adjustments, switch the data source for all 4
tables (`Fact_InternalWorkOrders`, `dim_BranchLocation`, `dim_DateTable`,
`dim_Salesperson`) from `LH_Master_Data` to `DP_Presentation` yourself in Desktop's
Data Source Settings, keeping each `Item=`/table name the same, validate visuals
render real data, publish to `RP - Dev`, commit via Fabric Git integration.

- [ ] **Step 5: Post-publish verification — real row counts match what Desktop showed**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
for t in ["Fact_InternalWorkOrders", "dim_BranchLocation", "dim_DateTable", "dim_Salesperson"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{t}')").fetchone()[0]
    print(f"  {t}: {n:,} rows")
```

Compare against what Desktop's Data pane shows for the refreshed report — should
match exactly (no row-dropping transforms on any of these 4 tables).

---

### Task 4: Repoint Negative On Hand-On Hand No Bin (3 tables)

**Files:**
- Modify: `projects/negative on hand - on hand no bin - report/reports/current/Negative On Hand-On Hand No Bin.SemanticModel/definition/tables/Fact_NegativeOnHand_OnHandNoBin.tmdl`
- Modify: `projects/negative on hand - on hand no bin - report/reports/current/Negative On Hand-On Hand No Bin.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/negative on hand - on hand no bin - report/reports/current/Negative On Hand-On Hand No Bin.SemanticModel/definition/tables/dim_DateTable.tmdl`

- [ ] **Step 1-3 (superseded — see "Real process correction" above):** ~~Claude
edits the connection string, verifies, commits~~. Claude's edit (commit `82003bf1`)
was reverted in `566136ee` — this is Brian's own action inside Desktop now.

- [ ] **Step 4: Brian — open, clean up, switch source, and publish**

Open `Negative On Hand-On Hand No Bin.pbip` from `data-projects`. Make any needed
cleanup adjustments, switch the data source for all 3 tables
(`Fact_NegativeOnHand_OnHandNoBin`, `dim_BranchLocation`, `dim_DateTable`) from
`LH_Master_Data` to `DP_Presentation` yourself in Desktop, keeping each
`Item=`/table name the same, validate visuals (branch names, part numbers, issue
severity all look real), publish to `RP - Dev`, commit via Fabric Git integration.

- [ ] **Step 5: Post-publish verification — real row counts match what Desktop showed**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
for t in ["Fact_NegativeOnHand_OnHandNoBin", "dim_BranchLocation", "dim_DateTable"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{t}')").fetchone()[0]
    print(f"  {t}: {n:,} rows")
```

Compare against what Desktop's Data pane shows for the refreshed report — should
match exactly (no row-dropping transforms on any of these 3 tables).

---

### Task 5: Repoint Parts Not Re-Ordered 24 Hours (3 tables)

**Files:**
- Modify: `projects/parts not re-orderd 24 hours - report/report/current/Parts Not Re-Ordered 24 Hours.SemanticModel/definition/tables/Fact_PartsNotReordered.tmdl`
- Modify: `projects/parts not re-orderd 24 hours - report/report/current/Parts Not Re-Ordered 24 Hours.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/parts not re-orderd 24 hours - report/report/current/Parts Not Re-Ordered 24 Hours.SemanticModel/definition/tables/dim_DateTable.tmdl`

- [ ] **Step 1-3 (superseded — see "Real process correction" above):** ~~Claude
edits the connection string, verifies, commits~~. Claude's edit (commit `25b3c766`)
was reverted in `1230ac95` — this is Brian's own action inside Desktop now.

**Do not touch** the `Fact_PartsNotReordered[Business Hours Since Sale]` DAX
calculated column when switching the source — it already has its own independent,
correct DST-aware `NOW()` fix and is unrelated to this migration. Same for the
`#"Filtered Rows" = Table.SelectRows(dbo_Fact_PartsNotReordered, each ([Type] = "C" or [Type] = "I"))`
step — switching the source shouldn't disturb it.

- [ ] **Step 4: Brian — open, clean up, switch source, and publish**

Open `Parts Not Re-Ordered 24 Hours.pbip` from `data-projects`. Make any needed
cleanup adjustments, switch the data source for all 3 tables
(`Fact_PartsNotReordered`, `dim_BranchLocation`, `dim_DateTable`) from
`LH_Master_Data` to `DP_Presentation` yourself in Desktop, confirm the `Filtered
Rows` step still correctly limits to Type C/I rows and the `Business Hours Since
Sale` measure still computes sensible values, publish to `RP - Dev`, commit via
Fabric Git integration.

- [ ] **Step 5: Post-publish verification — real filtered row count matches what Desktop showed**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
total = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/Fact_PartsNotReordered')").fetchone()[0]
filtered = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Tables/Fact_PartsNotReordered')
    WHERE Type = 'C' OR Type = 'I'
""").fetchone()[0]
print(f"  Fact_PartsNotReordered: {total:,} total, {filtered:,} after Type C/I filter (this is what the report should show)")
for t in ["dim_BranchLocation", "dim_DateTable"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/{t}')").fetchone()[0]
    print(f"  {t}: {n:,} rows")
```

Compare the `filtered` count against what Desktop's Data pane shows for
`Fact_PartsNotReordered` in the refreshed report — should match exactly, since the
M-query's `Table.SelectRows` step reproduces this same `Type = "C" or Type = "I"`
filter.

---

### Task 6: Repoint Parts Adjustments (8 tables, including the `Silver_PartInformation` rename)

**Files:**
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/Fact_AdjPairs_Summary.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/Fact_AdjustmentPairs.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/Fact_PartsAdjustments.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/dim_AdjustmentType.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/dim_Parts.tmdl`
- Modify: `projects/parts adjustments - report/reports/current/Parts Adjustments.SemanticModel/definition/tables/jdis_Part_Information.tmdl`

(`dim_PAType.tmdl` also exists in this folder but is a hardcoded 7-row
`calculated`/DATATABLE table with no `Sql.Database` reference — do not touch it,
not part of this migration.)

- [ ] **Step 1-4 (superseded — see "Real process correction" above):** ~~Claude
edits the connection strings + `jdis_Part_Information` rename, verifies,
commits~~. Claude's edit (commit `1957ca97`) was reverted in `2d7d8fe2` — this is
Brian's own action inside Desktop now.

**Important reference for Brian's own switch:** in `jdis_Part_Information`
specifically, the new source table is named `Silver_PartInformation` — not the same
name as the old `jdis_Part_Information` raw table, so Desktop's "Change Source"
flow needs the table picked explicitly (it won't auto-match by name like the other
7 tables in this report will). **No column changes are needed** — this report's
existing 33-column model already matches `Silver_PartInformation`'s real schema
exactly, including `PackageQty` already being typed `string` in both places (don't
add a `Table.SelectColumns`/`Int64.Type` cast like Bin Location Report's version of
this same table has — that doesn't apply to this report's own column set).

**Real finding, still valid and worth watching for regardless of who makes the
edit:** `Weight` is declared `string` in this report's model, but the real
`Silver_PartInformation.Weight` column is actually `DECIMAL(14,4)` (confirmed via
DuckDB) — a genuine, pre-existing type mismatch (unlike `PackageQty`, which the
Gold notebook explicitly casts to match). If Desktop errors or complains about the
`Weight` column during the switch/refresh, this is almost certainly why — the fix
is adding a `Table.TransformColumnTypes` step to cast it.

- [ ] **Step 5: Brian — open, clean up, switch source (including the
`jdis_Part_Information` rename), and publish**

Open `Parts Adjustments.pbip` from `data-projects`. Make any needed cleanup
adjustments, switch the data source for all 8 tables (7 simple ones plus
`jdis_Part_Information` → `Silver_PartInformation`, per the note above) from
`LH_Master_Data`/`DP_Presentation` yourself in Desktop. Pay particular attention to
`jdis_Part_Information` actually loading real part data (not blank/erroring), since
this is the one table with a real name change, not just a connection swap. Confirm
the `dim_Parts` relationship still resolves correctly (this report is one of the
two in this batch exposed to the historical `PartNumber` control-character
relationship bug — see Step 6 below). Publish to `RP - Dev`, commit via Fabric Git
integration.

- [ ] **Step 6: Post-publish verification — relationship integrity check**

Since `Fact_PartsAdjustments`, `Fact_AdjustmentPairs`, and `Fact_AdjPairs_Summary`
all relate to `dim_Parts.PartNumber`, and this project has a real history of a
stray `\r`/`\t` control character silently breaking that exact relationship (fixed
in `Build_Gold_Parts.Notebook`, but worth re-confirming here rather than assuming):

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"

for fact in ["Fact_PartsAdjustments", "Fact_AdjustmentPairs", "Fact_AdjPairs_Summary"]:
    row = con.execute(f"""
        SELECT COUNT(*) AS total,
               COUNT(*) FILTER (WHERE p.PartNumber IS NULL) AS unmatched
        FROM delta_scan('{base}/Tables/{fact}') f
        LEFT JOIN delta_scan('{base}/Tables/dim_Parts') p ON f.PartNumber = p.PartNumber
    """).fetchone()
    print(f"  {fact}: total={row[0]:,}  unmatched to dim_Parts={row[1]:,}")
```

Expected: `unmatched` should be 0 or very close to it (a real business-data gap, not
a join bug) for all three fact tables — confirms the relationship resolves cleanly
with today's real `dim_Parts` data.

---

### Task 7: Repoint Planter Inspection Part Sales (8 tables)

**Files:**
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/Fact_PlanterInspectionParts.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/Fact_PlanterInspections.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/Fact_PlanterInvoiceAllParts.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/Fact_PlanterPartSales.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `projects/planter inspection part sales - report/reports/new report/Planter Inspection Part Sales.SemanticModel/definition/tables/dim_Parts.tmdl`

(Work only in the `new report/` folder — `old report/` has a stale `V1` copy and a
stale duplicate, neither in scope.)

- [ ] **Step 1-3 (superseded — see "Real process correction" above):** ~~Claude
edits the connection string, verifies, commits~~. Claude's edit (commit `4ed253d5`)
was reverted in `93c31482` — this is Brian's own action inside Desktop now.

- [ ] **Step 4: Brian — open, clean up, switch source, and publish**

Open `Planter Inspection Part Sales.pbip` from the `new report` folder in
`data-projects`. Make any needed cleanup adjustments, switch the data source for
all 8 tables from `LH_Master_Data` to `DP_Presentation` yourself in Desktop
(keeping each `Item=`/table name the same — no renames in this report), confirm the
`FilterValidCustomers` step still excludes blank customer numbers and `dim_Parts`
relationships resolve correctly (this is the second of the two reports in this
batch exposed to the historical `PartNumber` control-character relationship bug —
see Step 5 below). Publish to `RP - Dev`, commit via Fabric Git integration.

- [ ] **Step 5: Post-publish verification — relationship integrity check**

Same real check as Task 6 Step 6, for this report's three `dim_Parts`-related fact
tables:

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"

for fact in ["Fact_PlanterInspectionParts", "Fact_PlanterPartSales", "Fact_PlanterInvoiceAllParts"]:
    row = con.execute(f"""
        SELECT COUNT(*) AS total,
               COUNT(*) FILTER (WHERE p.PartNumber IS NULL) AS unmatched
        FROM delta_scan('{base}/Tables/{fact}') f
        LEFT JOIN delta_scan('{base}/Tables/dim_Parts') p ON f.PartNumber = p.PartNumber
    """).fetchone()
    print(f"  {fact}: total={row[0]:,}  unmatched to dim_Parts={row[1]:,}")
```

Expected: `unmatched` should be 0 or very close to it for all three fact tables.

---

## Real, significant finding (2026-09-21) — a genuine dimension-schema gap, not a repoint bug

After the repoint (commits `6d9c4918`/`3c956739`/`a817a8e3`/`37617707`/`1bdcf64c`/`adde403d`)
and credentials fix, **all 6 semantic model refreshes failed** with `Data source
error: The '<column>' column does not exist in the rowset` — a different missing
column per report (`ServiceCapacity`, `BranchKey`, `DayOfWeekName`, `Street`).

**Real root cause:** not a mistake in this batch's work — a genuine gap between
what these 6 reports' models declare for `dim_BranchLocation`/`dim_DateTable`/
`dim_CustomerList` and what the Gold-layer versions of those tables actually carry.
The Gold dimensions were deliberately trimmed during an earlier project phase (the
LH_Master_Data dimensions catalog's column-usage-depth audit, `docs/architecture/lh-master-data-dimensions-catalog.md`)
based on usage across the reports checked *at that time* — which didn't include
these 6, since they hadn't been migrated yet.

**Investigation, not a guess:** Brian asked "figure out if these are actually
needed or just there but unused" before any Gold-layer or model change was made.
Two independent checks, cross-verified against each other:
1. `pbir fields list` (a real CLI tool for this project, not a text grep) scanned
   every visual/measure binding across all 6 reports for the ~72 flagged columns.
2. Brian independently opened the real, confirmed-production versions of each
   report in Desktop and visually checked for any use of the flagged columns,
   catching a hidden dependency the text scan alone couldn't fully confirm: a
   `sortByColumn` property (`MonthYear -> SortableMonthYear`) with no direct visual
   binding of its own, but load-bearing for a column (`MonthYear`) that IS visually
   used (Unique Parts Customers' "Rolling 12" visual, confirmed spanning Sep
   2025 -> Sep 2026 in real chronological order — only possible with a real
   year-aware sort key, not `MonthName`'s own plain-`Month` sort).

**Real result: ~71 of ~72 flagged columns were confirmed genuinely unused** (only
ever appearing in their own column declaration and the auto-generated
`cultures/en-US.tmdl` translation file — never in any visual, measure, or
relationship). **`SortableMonthYear` was the one real exception.**

**`ContactClass` specifically** (flagged by Brian as "used for the key customer
flag in other reports") was traced to the real Gold `dim_CustomerList` build logic
(`.claude/queries/dimensions/dim_CustomerList.pq`): `IsKeyCustomer` is computed
*from* `ContactClass` at build time (`([ContactClass] ?? "") = "KEY"`) and
`IsKeyCustomer` is already a real, present Gold column — the business need is
already served without exposing the raw `ContactClass` text column. Confirmed
none of these 6 reports reference raw `ContactClass` directly.

**Fix, in two parts:**
1. Added `SortableMonthYear` back to the real Gold `dim_DateTable`
   (`Build_Gold_DateTable.Notebook`, commit `73fef14d`) — using the exact real
   logic from the original production dataflow
   (`.claude/queries/dimensions/dim_DateTable.pq`), not guessed:
   `Text.From([Year]) & "-" & Text.PadStart(Text.From([Month]), 2, "0") & " " & [MonthNameShort]`,
   e.g. `"2026-09 Sep"`. Brian ran the notebook; verified live via DuckDB — 14
   columns, correct value (`"2025-12 Dec"` for 2025-12-25), and correct sort order
   across the Sep 2025 -> Sep 2026 boundary matching the real production visual
   exactly. This is a real, working precedent for what this same notebook's own
   header comment already anticipated: *"add any of these back later if a real,
   identified need for one shows up during a report's actual migration."*
2. Trimmed all 6 reports' models directly in `fabric-workspace-docs` (not
   `data-projects` — these are edits to the already-published `RP - Dev` copies,
   the same "safe to edit directly since nothing's open in Desktop" situation as
   the original repoint) — commits `ccf3afae`/`ab3361f8`/`ee18395a`/`dfc0f144`/
   `ec2651fe`/`0603a701`. Removed 7 `dim_BranchLocation` columns (all 6 reports),
   53 `dim_DateTable` columns (all 6 reports, keeping the now-14-column real
   schema including `SortableMonthYear`), and 11 `dim_CustomerList` columns
   (Unique Parts Customers and Planter Inspection Part Sales only — the only 2
   reports with this dimension). Independently reviewed: pure deletions confirmed
   (zero unexpected added/modified lines in any of the 6 diffs), exact column
   counts matched, `SortableMonthYear` and both real `sortByColumn` dependencies
   confirmed intact everywhere, zero references to any removed column found in any
   report's relationships or measures. One non-blocking, pre-existing finding: all
   6 reports' `cultures/en-US.tmdl` files still have stale Q&A linguistic-metadata
   entries for the removed columns — harmless (doesn't affect refresh, only Power
   BI's optional Q&A feature), deliberately left alone rather than risk editing
   that file's embedded JSON structure for a cosmetic-only cleanup.

**Real, still-open next step:** Brian needs to pull these 6 model-trim commits into
each live `RP - Dev` semantic model (Source control → Update) and re-attempt each
refresh — this plan's original per-task post-publish verification scripts (Task
2-7, Step 5/6) are still the right next check once refresh succeeds.

## Round 2 (2026-09-21) — the first trim was incomplete, now fully audited

3 of 6 reports refreshed clean after the first trim. 3 hit **new** real errors:
`VendorCode` (Parts Adjustments, Planter Inspection Part Sales — both from
`dim_Parts`, not one of the 3 dimensions originally investigated) and
`CustomerNumberText` (Unique Parts Customers, `dim_CustomerList` — genuinely
missed in the original diff against that dimension, a real oversight, not a
deliberate exclusion like the other 71).

**Real lesson: the original investigation checked only the 3 dimensions the
initial error messages happened to name first, not every dimension every report
actually depends on.** Rather than keep fixing these one refresh-failure at a
time, ran an exhaustive audit — every `dim_*`/`Fact_*`/other Sql.Database-backed
table in all 6 reports' current models, diffed column-by-column against its real
Gold table (resolving `jdis_Part_Information` → `Silver_PartInformation` correctly
for Parts Adjustments) — confirming **zero remaining gaps anywhere** before
declaring this done, not just the 2 that happened to surface via a refresh
attempt.

Both `VendorCode` and `CustomerNumberText` confirmed genuinely unused via the same
method as the original 71 (pbir scan + full-file text reference check) — removed,
not added to Gold. Commits `f0e31e00`/`2524bfaf`/`d90a42c7`. `VendorCode` also
legitimately exists on `jdis_Part_Information`/`Silver_PartInformation` in Parts
Adjustments (a different, real column on a different table, same name by
coincidence) — confirmed untouched.

**Real, still-open next step:** Brian pulls these 3 additional commits and
re-attempts the 3 still-failing refreshes.

---

### Task 8: Archive the data-projects copies and update the catalog doc

**Files:**
- Move: all 6 reports' `data-projects` folders to `report(s)/archive/` (matching the
  established Batch 0 pattern — the `fabric-workspace-docs/workspaces/RP - Dev/`
  copy becomes the real working copy going forward)
- Modify: `docs/architecture/report-migration-catalog.md`

- [ ] **Step 1: Confirm all 6 reports published and verified successfully**

Do not archive anything until every report in Tasks 2–7 has a confirmed-working
published version in `RP - Dev` with its post-publish verification step passed.

- [ ] **Step 2: Archive each report's `data-projects` copy**

Following the exact Batch 0 precedent (see `git log --oneline` for
`a370cc28`/`d7e4c3d7`/`c82cb3e8`, "Archive `<Report>`'s data-projects copy (migrated
to DP backend)"), move each of the 6 reports' folders into their own archive
location and commit with the same message pattern, one commit per report.

- [ ] **Step 3: Update the catalog doc**

Mark all 6 reports as complete in `docs/architecture/report-migration-catalog.md`'s
Batch 1 section, documenting the real per-report verification results (row counts,
relationship-integrity check results for Parts Adjustments/Planter Inspection Part
Sales) the same way Batch 0's section documents its own real findings.

- [ ] **Step 4: Commit**

```bash
git add docs/architecture/report-migration-catalog.md
git commit -m "Update report migration catalog: Batch 1 complete

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## What this plan deliberately does not cover

- Customer Anatomy V2, Inspections - V2, Price Matrix — explicitly held back by
  Brian's own call ("need special care"); a future Batch 2.
- The remaining Tier 2/Tier 3 reports from the catalog doc — future batches.
- Any fabric-cicd/Variable Library deployment automation for these 6 reports — this
  plan uses the same manual Desktop-publish workflow proven in Batch 0. Automating
  the publish step itself is a separate, not-yet-scoped piece of work.
- Any change to `Build_Gold_Parts.Notebook` or the `dim_Parts.PartNumber`
  control-character fix itself — already fixed; Tasks 6/7 only re-verify it holds
  for these two newly-migrated reports' real data.

## Addendum (2026-09-21) — Parts Promo, discovered while checking for other issues

While verifying nothing else in `RP - Dev` was affected by the dimension-schema
work above, Brian found `Parts Promo` (a different, older report — the actual
original DP backend pilot, predating this whole project's Batch 0/Batch 1
structure) failing the same way. Real investigation, not assumed:

- `Parts Promo` had only ever had its **fact tables**
  (`Fact_InTrans_AllPromo`, `Fact_PartsPromo`) and `dim_RepairOrder` repointed to
  `DP_Presentation` at the time of the original pilot. `dim_BranchLocation`,
  `dim_CustomerList`, `dim_DateTable`, `dim_Parts` were still on `LH_Master_Data`
  the entire time — a real, pre-existing gap, unrelated to anything from this
  batch's own work, just never caught until now.
- A full exhaustive audit (every `Sql.Database`-backed table in Parts Promo,
  diffed column-by-column against its real Gold schema) found: the 4 stale
  dimensions needed the exact same repoint + trim already proven across this
  whole batch (confirmed via a fresh pbir + text-reference usage check specific
  to Parts Promo, not assumed from the other 6 reports' results) — fixed,
  reviewed, and approved (commit `faad6ae2`).
- **`dim_RepairOrder` is a genuinely different, bigger problem**, deliberately
  NOT touched here: the real Gold `dim_RepairOrder` only has 2 columns
  (`REF_NO`, `CustomerNo`) against Parts Promo's declared 15, and — unlike every
  other trim in this whole project — 5 of those 13 missing columns
  (`NetMargin`, `NetOrderValue`, `OriginalMargin`, `TotalPartsCost`,
  `TotalPartsSales`) are confirmed genuinely used in live, real DAX measures
  computing this report's own core margin/discount analysis. This is real,
  necessary Gold-layer rebuild work, not a safe trim — deliberately deferred as
  its own separate, focused piece of work rather than rushed here. The real
  original source logic for these columns is at
  `projects/parts promo - report/queries/new report/dimensions/dim_RepairOrder.pq`.
- Also confirmed a completely separate, real Fabric platform issue while
  investigating: `LH_Master_Data`'s own SQL analytics endpoint had a stale
  metadata cache (a documented Fabric behavior — the SQL endpoint's schema view
  can lag behind the underlying Delta table). Not caused by anything in this
  project; real fix is the endpoint's own portal **Refresh** button.
