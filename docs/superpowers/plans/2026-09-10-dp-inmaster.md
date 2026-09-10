# DP InMaster Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `InMaster` — the plain base table fed by the old `df_InMaster_Raw` dataflow — onto the `DP` backend as a OneLake shortcut plus a Silver notebook.

**Architecture:** Same shortcut + Silver notebook pattern as every other table in this backend. Replicates the old dataflow's exact 19-column contract, plus one deliberate addition (`IN_TRANSIT_QTY`) proven necessary by a real, already-identified consumer discovered this session.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Scope clarification (read before building — this matters)

`InMaster` (this plan) is a **completely separate Fabric object** from two other things with confusingly similar names, neither of which this plan touches:

- **`InMaster_PartsLookup_Raw`** — mission-critical, live, feeds the production Parts Availability tool. Do not touch.
- **`InMaster_Parts_Ordering_Raw`** (which, confusingly, writes to a table literally named `InMaster_Raw`) — belongs to the Non-JD Parts Order Tool, a real project deliberately paused since 2026-08-04. Do not touch. See `project_nonjd_parts_order_tool_paused.md` in project memory.

This plan is the plain `InMaster` table — what `df_InMaster_Raw` pulls today, feeding the live "Part Sales with Low Margin" report. Bringing it in is purely additive; it doesn't interact with either of the above.

## Why now (two reasons, both real)

1. Matches the exact same raw+Silver pattern as every other table this session — no new complexity.
2. It's a real, proven dependency for `Parts_InterbranchTransfers` — one of the Category C raw-sources catalog tables, confirmed this session (via its actual SQL Anywhere view definition, pulled directly by Brian through SQL Central) to be a VIEW joining `InSalPar` + `InMaster` + `InSalOrd` — not a table genuinely excluded from JD's mirror after all. Two of those three inputs (`InSalPar`, `InSalOrd`) are already migrated (raw sources batch 1); this plan brings in the third.

Brian's own reasoning, endorsed: "whatever we do with the InMaster it will happen downstream from the raw silver layer anyway so we might as well scope this in as well."

**This plan is raw + Silver only.** No Gold-layer logic, no `Parts_InterbranchTransfers` rebuild (that stays deferred — a separate future piece of work, still additionally blocked on a broader decision about the InMaster group), no report work.

---

### Task 1: Brian creates the `InMaster` OneLake shortcut

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `InMaster`
7. Keep the destination name as `InMaster` (don't rename)
8. **Create**

- [ ] **Step 2: Confirm it appears**

In `DP_Staging` → `Tables`, confirm `InMaster` is listed. Report back once done.

---

### Task 2: Independently verify the bronze shortcut

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_inmaster.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INMASTER - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the new InMaster OneLake shortcut in DP_Staging resolves to the
exact same row count as reading the table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch means the shortcut itself is
broken (wrong table selected, stale metadata), not a data problem.

Run manually after Brian creates the shortcut (plan Task 1).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InMaster')").fetchone()[0]
jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/InMaster')").fetchone()[0]

print(f"DP_Staging shortcut row count:  {dp_count:,}")
print(f"JD Bronze direct row count:     {jd_count:,}")
print(f"Match: {dp_count == jd_count}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_inmaster.py
```

Expected: `Match: True`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_inmaster.py
git commit -m "Add bronze shortcut verification for InMaster

Confirms the new DP_Staging InMaster OneLake shortcut resolves to
the exact same row count as JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_InMaster.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InMaster.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InMaster.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_InMaster"
  },
  "config": {
    "version": "2.0",
    "logicalId": "626a913f-b67e-487a-8a9e-18350222e358"
  }
}
```

- [ ] **Step 2: Create the notebook content**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
# META       "known_lakehouses": [
# META         {
# META           "id": "876255e0-d462-4697-adc1-4a655f5bb101"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_InMaster
# Purpose: Migrates InMaster off the old ODBC-based df_InMaster_Raw
# dataflow onto a OneLake shortcut of JD's own live mirror.
#
# *** SCOPE NOTE - READ BEFORE ASSUMING THIS TOUCHES SOMETHING ELSE ***
# This is the PLAIN InMaster table - a completely separate Fabric object
# from InMaster_PartsLookup_Raw (mission-critical, live, feeds the
# production Parts Availability tool - NOT touched by this notebook) and
# InMaster_Parts_Ordering_Raw (which confusingly writes to a table named
# InMaster_Raw, belonging to the Non-JD Parts Order Tool - a real project
# deliberately paused since 2026-08-04, also NOT touched here - see
# project memory project_nonjd_parts_order_tool_paused.md). This
# notebook only rebuilds what df_InMaster_Raw already does today: feed
# the live "Part Sales with Low Margin" report.
#
# Replicates the old dataflow's exact 19-column contract - it already had
# NO WHERE clause (full master pull already, nothing to drop) and every
# selected source column matched the live bronze schema's real casing
# exactly, no corrections needed.
#
# ONE deliberate addition beyond the old 19 columns: IN_TRANSIT_QTY. Not
# in the old dataflow's SELECT list, but proven necessary by a real,
# already-identified consumer discovered this session -
# Parts_InterbranchTransfers's actual SQL Anywhere view definition
# (pulled directly via SQL Central) references inm.in_transit_qty. This
# is not speculative scope creep - it's a specific, known need, unlike
# WKRODESC's unused DETAIL column (deliberately left out in an earlier
# plan) which had no identified consumer.
#
# Business context (from the old dataflow's own documentation):
# LowMarginFlag (user_field_3) is a manually-maintained flag parts
# managers set to "Low" to mark margin-problem parts - the key field for
# the live "Part Sales with Low Margin" report (which already reads
# dbo.InMaster directly via the SQL Analytics Endpoint). This migration
# doesn't change that report's behavior, just gives it - and any future
# consumer - a non-ODBC path to the same data.
#
# RAW + SILVER ONLY - no Gold-layer logic, no Parts_InterbranchTransfers
# rebuild (that stays a separate, deferred future piece of work).
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_INMASTER")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("InMaster")
bronze_count = bronze.count()
print(f"Bronze InMaster rows: {bronze_count:,}")

silver = bronze.select(
    F.col("BRANCH").alias("Branch"),
    F.col("PART_NO").alias("PartNumber"),
    F.col("PART_DESC").alias("PartDescription"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("PROD_GROUP").alias("ProductGroup"),
    F.col("SALES_CLASS").alias("SalesClass"),
    F.col("CATEGORY").alias("Category"),
    F.col("MANUF_CODE").alias("ManufacturerCode"),
    F.col("LIST_PRICE").alias("ListPrice"),
    F.col("SELL_PRICE1").alias("SellPrice1"),
    F.col("STK_ORDER_PRICE").alias("StockOrderPrice"),
    F.col("ON_HAND_QTY").alias("OnHandQty"),
    F.col("BACK_ORD_QTY").alias("BackOrderQty"),
    F.col("IN_TRANSIT_QTY").alias("InTransitQty"),
    F.col("user_field_3").alias("LowMarginFlag"),
    F.col("user_field_1").alias("UserField1"),
    F.col("user_field_2").alias("UserField2"),
    F.col("Last_Upd_Datetime").alias("LastUpdatedDatetime"),
    F.col("CREATION_DATE").alias("CreationDate"),
    F.col("LAST_DEM_DATE").alias("LastDemandDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_InMaster")
print("Silver build complete: Silver_InMaster written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_InMaster` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

low_margin_breakdown = spark.sql("""
    SELECT LowMarginFlag, COUNT(*) AS RowCount
    FROM delta.`Tables/Silver_InMaster`
    GROUP BY LowMarginFlag
    ORDER BY RowCount DESC
    LIMIT 10
""").toPandas()
print("\nLowMarginFlag breakdown (confirms real values, matches the live report's own field):")
print(low_margin_breakdown.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InMaster.Notebook"
git commit -m "Add Build_Silver_InMaster notebook

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Brian syncs Dev and runs the notebook

**Files:** none (Fabric portal action)

- [ ] **Step 1: Sync the workspace**

`DP - Staging - Dev` → Source control → **Update all**.

- [ ] **Step 2: Run the notebook**

Open `Build_Silver_InMaster` (in `Data Notebooks/`) and **Run all** cells.

- [ ] **Step 3: Report back the notebook's own output**

Bronze row count, Silver row count, the sample rows, and the `LowMarginFlag` breakdown. If the assertion fails or the write throws an error, stop and report the full error rather than re-running blindly.

---

### Task 5: Independently verify `Silver_InMaster`

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_inmaster.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INMASTER - SILVER VERIFICATION
============================================================================
Independent check of Silver_InMaster - confirms the row count matches the
bronze shortcut exactly (pure select/rename, no filtering).

Run manually after Brian runs the notebook (plan Task 4).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InMaster')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_InMaster')").fetchone()[0]

print(f"Bronze InMaster rows:  {bronze_count:,}")
print(f"Silver InMaster rows:  {silver_count:,}")
print(f"Match: {bronze_count == silver_count}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_inmaster.py
```

Expected: `Match: True`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_inmaster.py
git commit -m "Add Silver verification for InMaster

Confirms Silver_InMaster matches its bronze shortcut row count exactly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Write the Category C project memory file

**Files:**
- Create: `C:\Users\bfox\.claude\projects\c--Users-bfox-Documents-Git-Projects-data-projects\memory\project_category_c_views_resolved.md`
- Modify: `C:\Users\bfox\.claude\projects\c--Users-bfox-Documents-Git-Projects-data-projects\memory\MEMORY.md`

- [ ] **Step 1: Write the memory file**

Following the exact same pattern as `project_labor_performance_technician_views_resolved.md`, write a new memory file capturing this session's Category C investigation:

```markdown
---
name: project-category-c-views-resolved
description: "Category C of the JD Bronze raw-sources catalog (tables genuinely excluded from JD's mirror) partially resolved via real SQL Anywhere table-type/view-definition checks - ArMaster_Contact and Parts_InterbranchTransfers turned out to be views over already-available tables, not excluded base tables; InSalPar_Audit and RepairOrderDetail confirmed genuine base tables, original assessment holds"
metadata:
  type: project
originSessionId: unknown
---

2026-09-10: applied the same lesson from [[project_labor_performance_technician_views_resolved]]
(don't trust the old dataflow's own querying style to prove something is a base
table - check the real SQL Anywhere system catalog directly) to the 4 Category C
tables in [[project_jd_bronze_data_platform_redesign]]'s raw-sources catalog
(`docs/architecture/jd-bronze-raw-sources-catalog.md`). Brian ran
`SELECT table_name, table_type FROM SYS.SYSTABLE WHERE table_name IN (...)`
directly in SQL Central. Result: 2 of the 4 are actually views, not excluded
base tables.

## `ArMaster_Contact` — a view, fully unblocked

```sql
ALTER VIEW "Administrator"."ARMASTER_CONTACT" as select
  contact.contact_code as contact_code, ... (52 contact.* columns, all prefixed "contact_")
  armaster.acc_no as armaster_acc_no, ... (24 armaster.* columns, all prefixed "armaster_")
from Administrator.ArMaster, Administrator.contact
where ArMaster.contact_code = contact.contact_code
```
A plain implicit join, no aggregation. Both inputs are already migrated
(`Silver_ArMaster`, `Silver_Contact`, both raw sources batch 1) - this is fully
unblocked today, zero new dependencies. Not built yet (Brian's own call, staying
focused on raw/Silver work) - a real, cheap Gold-layer join whenever picked up.
Also explains why `ArMaster_Contact` shared the "7:30 AM performance degradation"
issue documented on `ArMaster_Customer`/`contact` in batch 1 - same underlying
ODBC strain, same fix once rebuilt from the shortcut-based Silver tables.

## `Parts_InterbranchTransfers` — a view, partially unblocked

```sql
ALTER VIEW "Administrator"."Parts_InterbranchTransfers"
  (SupplyingBranch,RequestingBranch,PartTicket,OrderQuantity,ShippedQuantity,InTransitQuantity,OrderAge) AS
 select distinct Isnull(par.branch,'') as SupplyingBranch,
        Isnull(ord.trf_to_branch,'') as RequestingBranch,
        Isnull(par.file_no,0) as PartTicket,
        Isnull(par.order_qty,0) as OrderQuantity,
        Isnull(par.shipped_qty,0) as ShippedQuantity,
        Isnull(inm.in_transit_qty,0) as InTransitQuantity,
        Datediff(dd,Isnull(ord.ord_date,'1900-01-01'),Getdate()) as OrderAge
   from Administrator.insalpar as par
   left outer join Administrator.inmaster as inm on inm.branch = par.branch and inm.franchise = par.franchise and inm.part_no = par.part_no
   left outer join Administrator.insalord as ord on ord.file_no = par.file_no
  where ord.type = 'T'
```
Three inputs: `InSalPar` (have, `Silver_InSalPar`, batch 1), `InSalOrd` (have,
`Silver_InSalOrd`, batch 1), `InMaster` (have, `Silver_InMaster`, this session's
own dedicated plan). All three now migrated at raw+Silver - the view itself is
not yet rebuilt (deliberately deferred, matching every other Gold-layer decision
this session).

Two things worth knowing if/when this gets built:
- `WHERE ord.type = 'T'` is a real business-rule filter (transfers only) baked
  into the source view - same category as `InHist_PmManage`'s `Franchise='D'`
  and `WKRODESC`'s `LINE_NO=1`, worth the same scrutiny before blindly
  replicating.
- `OrderAge = DATEDIFF(dd, ord_date, GETDATE())` is computed **relative to query
  time** - this cannot be frozen into a static ETL-written table the way
  everything else in this backend has been; it would go stale the instant it's
  written. If this view is ever rebuilt, `OrderAge` needs to become a report-time
  calculation (a DAX measure, or computed at query time), not a stored column.

## `InSalPar_Audit` and `RepairOrderDetail` — confirmed genuine base tables

Both came back `table_type = 'BASE'` from the direct system-catalog query -
Category C's original assessment holds for these two. No shortcut path exists;
the only way in remains a direct ODBC pull (Dataflow Gen2), same pattern as
`jdis_Part_Information`/`BranchOperational`. Not attempted this session - no
strong pull to prioritize these two the way `InMaster`/`ArMaster_Contact` had a
concrete reason to move now.
```

- [ ] **Step 2: Add a pointer in `MEMORY.md`**

Add a one-line pointer under the "In Progress" section, near the JD Bronze project line:

```markdown
- [Category C views partially resolved](project_category_c_views_resolved.md) — 2026-09-10: `ArMaster_Contact` and `Parts_InterbranchTransfers` turned out to be views over already-available tables (not excluded base tables); `InSalPar_Audit`/`RepairOrderDetail` confirmed genuine base tables, still need a direct ODBC pull if ever pursued
```

---

### Task 7: Update reference docs

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`

- [ ] **Step 1: Add `InMaster`/`Silver_InMaster` to `DP_Staging`'s Lakehouses table**

In `docs/architecture/data-platform-workspaces.md`, find the `DP_Staging` lakehouse row and add a mention of the new `InMaster` shortcut and `Silver_InMaster` table, pointing to the new section below.

- [ ] **Step 2: Add a new section**

Add a `## InMaster (2026-09-10) — the plain base table, separate from PartsLookup/Parts-Ordering` section (after the "WKMECHADJ and WKMECHFL" section) covering:
- The scope clarification: this is the plain `InMaster` table, a separate Fabric object from `InMaster_PartsLookup_Raw` (mission-critical, untouched) and the Non-JD Parts Order Tool's `InMaster_Parts_Ordering_Raw` (paused, untouched)
- Why now: the `Parts_InterbranchTransfers` dependency (found to be a view, not excluded after all) + Brian's own "downstream from raw/Silver anyway" reasoning
- The `IN_TRANSIT_QTY` addition and why (proven need, not speculative)
- The `LowMarginFlag` business context and its live report connection
- Verification results (both scripts, all passing)
- Explicit note: raw+Silver only — no Gold logic, no `Parts_InterbranchTransfers` rebuild, no report work

- [ ] **Step 3: Update the catalog doc's Category C section**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`'s Category C section, note that `ArMaster_Contact` and `Parts_InterbranchTransfers` were found this session (via their real SQL Anywhere definitions) to be views, not excluded base tables — point to `project_category_c_views_resolved.md` in project memory for the full detail. Note `ArMaster_Contact` is now fully unblocked and `Parts_InterbranchTransfers` is unblocked for all three of its inputs as of this plan. Note `InSalPar_Audit` and `RepairOrderDetail` were confirmed genuine base tables — the catalog's original assessment holds for those two.

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document InMaster migration, update Category C catalog entries

InMaster (the plain base table - separate from InMaster_PartsLookup_Raw
and the paused Non-JD Parts Order Tool pipeline) moved onto a OneLake
shortcut + Silver notebook. Replicates the old df_InMaster_Raw
dataflow's 19-column contract exactly, plus IN_TRANSIT_QTY - proven
necessary by Parts_InterbranchTransfers's real view SQL, not
speculative scope creep.

Also updates the raw-sources catalog's Category C section: ArMaster_Contact
and Parts_InterbranchTransfers were found this session to be views over
already-available tables (not excluded base tables as originally
catalogued) - ArMaster_Contact is now fully unblocked, Parts_InterbranchTransfers
unblocked for all 3 inputs as of this plan. InSalPar_Audit and
RepairOrderDetail confirmed genuine base tables, original assessment
holds. Full findings in project memory project_category_c_views_resolved.md.

This is raw+Silver only - no Gold-layer logic, no view rebuilds, no
report work.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 8: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into the `Parts_InterbranchTransfers` view rebuild, `ArMaster_Contact`'s view rebuild, `InSalPar_Audit`/`RepairOrderDetail`'s direct ODBC pulls, or any report repointing as part of this plan** — each of those is its own future decision, not implied by completing this one.
