# DP Raw Sources — Batch 1 (Simple Shortcuts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the 9 simplest Category A raw-source tables (per `docs/architecture/jd-bronze-raw-sources-catalog.md`) from `LH_Master_Data`'s ODBC-based dataflows onto the new `DP` backend, using pure OneLake shortcuts into `JD_EquipRDB_Production_Bronze` instead of any ODBC pull.

**Architecture:** Each table already exists as a live, continuously-updating table in JD's own Fabric mirror (`JD_EquipRDB_Production_Bronze`) — no ODBC query against `EquipRDB64` is needed at all. A OneLake shortcut in `DP_Staging` gives an always-current bronze copy with zero refresh action and zero source-system load. A small Spark notebook per table reads the shortcut, applies the exact same column rename/normalize logic the old dataflow used (so nothing downstream needs to change shape), and writes a `Silver_<Name>` Delta table. This is the same pattern already proven for `InTrans` and `GlTrans`.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Scope

This batch covers exactly the 9 tables with **zero filtering logic** in their current `LH_Master_Data` dataflow (confirmed by reading every dataflow's `mashup.pq` directly this session — no date-range bound, no business-rule `WHERE`, no join/group/dedup):

| # | Bronze shortcut name (exact JD casing) | Old dataflow | Silver table | Live row count (2026-09-10) |
|---|---|---|---|---|
| 1 | `ArMaster` | `df_ARMASTER_Raw` | `Silver_ArMaster` | 54,127 |
| 2 | `ArMaster_Customer` | `df_ArMaster_Customer_Raw` | `Silver_ArMasterCustomer` | 54,129 |
| 3 | `contact` | `df_CONTACT_Raw` | `Silver_Contact` | 82,756 |
| 4 | `GLMASTER` | `df_GlMaster_Raw` | `Silver_GlMaster` | 25,924 |
| 5 | `InSalOrd` | `df_INSALORD_Raw` | `Silver_InSalOrd` | 10,134 |
| 6 | `InSalPar` | `df_INSALPAR_Raw` | `Silver_InSalPar` | 20,302 |
| 7 | `VhStockAccess` | `df_VhStockAccess_Raw` | `Silver_VhStockAccess` | 695,965 |
| 8 | `WarSubCl_Labour` | `df_WARSUBCI_LABOUR_Raw` | `Silver_WarSubClLabour` | 68,311 |
| 9 | `Branch_Name` | `df_Branch_Name_Raw` | `Silver_BranchName` | 99 |

Row counts were queried live against JD Bronze this session (via DuckDB `delta_scan`, not assumed) — they will drift slightly by the time this plan executes since the source is continuously updating. Use them as a sanity check ("is the new count in the right ballpark"), not an exact match target — the real correctness check in Task 12 is bronze-shortcut-count == silver-count, not a fixed number.

**Explicitly out of scope** (deferred to a later batch, per Brian's own framing):
- The 4 dataflows that all pull `InMaster` (consolidation candidate — needs its own design decision)
- Tables whose old dataflow has a date-range `WHERE` (`TechnicianInvoiceDetail`, `TechnicianPunchedDetail`, `VHSTOCK`, `VhTrans`, `WKINVREG`, `WKMECHWK`, `WKOTHSUB`, `WKROFILE`, `WKVEHFL`, `Invoice`, `WarClaim`) — structurally simple too, but dropping their windowing is a real scope decision not yet made
- `InHist_PmManage` (`Franchise = 'D'` business-rule filter) and `WKRODESC` (`WHERE LINE_NO = 1` grain-narrowing rule) — need more thought before treating as "just bring it in"
- Category B (Technician-family views, need rebuilt aggregation logic) and Category C (tables genuinely excluded from JD's mirror) from the catalog doc
- Any report repointing, gold-layer business logic, or refresh scheduling — this batch is Dev-tier, Silver-layer, manually-triggered only, matching every prior piece of this backend

**Source of truth for target column names:** the SQL `SELECT ... AS <name>` list in each old dataflow's `mashup.pq`, cross-checked against the *actual live JD Bronze schema* (queried directly this session — several columns' real casing differs from what the old ODBC-layer SQL assumed, since SQL Anywhere resolves column names case-insensitively but Delta/Parquet does not; the mappings below use the **confirmed real bronze column names**, not the old dataflow's SQL text, wherever the two differ).

---

### Task 1: Brian creates the 9 OneLake shortcuts

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the first shortcut (`ArMaster`) — full steps**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `ArMaster`
7. Keep the destination name as `ArMaster` (don't rename)
8. **Create**

- [ ] **Step 2: Repeat for the remaining 8 tables**

Same steps as above, substituting the table name — select each from `JD_EquipRDB_Production_Bronze` → `Tables` and keep the destination name identical to the source name:

- `ArMaster_Customer`
- `contact`
- `GLMASTER`
- `InSalOrd`
- `InSalPar`
- `VhStockAccess`
- `WarSubCl_Labour`
- `Branch_Name`

- [ ] **Step 3: Confirm all 9 shortcuts appear**

In `DP_Staging` → `Tables`, confirm all 9 names above are listed (alongside the existing `InTrans` and `GlTrans` shortcuts). Report back once done — no need to open each one.

---

### Task 2: Independently verify the 9 bronze shortcuts

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch1.py`

- [ ] **Step 1: Write the verification script**

A shortcut is a pointer to the exact same underlying Delta files as the JD Bronze source — so this check isn't really "does the data look right" (it's byte-identical by construction), it's "does the shortcut exist and resolve correctly." Compares each `DP_Staging` shortcut's row count directly against the same table read straight from `JD_EquipRDB_Production_Bronze`.

```python
"""
DP RAW SOURCES BATCH 1 - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms each of the 9 new OneLake shortcuts in DP_Staging resolves to the
exact same row count as reading the same table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch here means the shortcut itself
is broken (wrong table selected, stale metadata), not a data problem.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

TABLES = [
    "ArMaster",
    "ArMaster_Customer",
    "contact",
    "GLMASTER",
    "InSalOrd",
    "InSalPar",
    "VhStockAccess",
    "WarSubCl_Labour",
    "Branch_Name",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Table':<20} {'DP_Staging shortcut':>20} {'JD Bronze direct':>20} {'Match':>10}")
print("=" * 90)

all_match = True
for t in TABLES:
    dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{t}')").fetchone()[0]
    jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/{t}')").fetchone()[0]
    match = dp_count == jd_count
    all_match = all_match and match
    print(f"{t:<20} {dp_count:>20,} {jd_count:>20,} {'OK' if match else 'MISMATCH':>10}")

print("=" * 90)
print(f"All 9 shortcuts match their JD Bronze source exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch1.py
```

Expected: all 9 rows show `OK`. If any row shows `MISMATCH`, stop and investigate that specific shortcut before proceeding to Task 3 — don't build a Silver notebook on top of a broken shortcut.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch1.py
git commit -m "Add bronze shortcut verification for raw sources batch 1

Confirms all 9 new DP_Staging OneLake shortcuts (ArMaster,
ArMaster_Customer, contact, GLMASTER, InSalOrd, InSalPar,
VhStockAccess, WarSubCl_Labour, Branch_Name) resolve to the exact
same row count as JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_ArMaster.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMaster.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMaster.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_ArMaster"
  },
  "config": {
    "version": "2.0",
    "logicalId": "5c6444f7-bdbd-4a8c-a91c-4cb42427c8cd"
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

# Build_Silver_ArMaster
# Purpose: Part of raw-sources batch 1 (2026-09-10) - migrates ArMaster off
# the old ODBC-based df_ARMASTER_Raw dataflow in LH_Master_Data onto a
# OneLake shortcut of JD's own live mirror (JD_EquipRDB_Production_Bronze).
# No ODBC query against EquipRDB64 runs for this table anymore - the
# ArMaster shortcut in DP_Staging is always current, with zero source-
# system load and zero refresh action needed.
#
# This notebook replicates the exact column rename contract the old
# dataflow used, so nothing downstream needs to change shape. Two SQL-
# layer transforms from the old query (TRIM, UPPER+TRIM) are re-applied
# here in Spark since they can no longer happen at the ODBC/SQL layer.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule (manually triggered for now, matching every other
# notebook in this backend so far).

print("=" * 80)
print("BUILD_SILVER_ARMASTER")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("ArMaster")
bronze_count = bronze.count()
print(f"Bronze ArMaster rows: {bronze_count:,}")

silver = bronze.select(
    F.trim(F.col("ACC_NO")).alias("AccountNumber"),
    F.upper(F.trim(F.col("contact_code"))).alias("ContactID"),
    F.col("CREDIT_LIMIT").alias("CreditLimit"),
    F.col("CURRENT_VALUE").alias("AccountBalance"),
    F.col("DAYS_30").alias("Aging30"),
    F.col("DAYS_60").alias("Aging60"),
    F.col("DAYS_90").alias("Aging90"),
    F.col("DAYS_120").alias("Aging120"),
    F.col("YTD_CREDITS").alias("YTDCredits"),
    F.col("YTD_DEBITS").alias("YTDDebits"),
    F.col("LYTD_CREDITS").alias("LYTDCredits"),
    F.col("LYTD_DEBITS").alias("LYTDDebits"),
    F.col("DATE_LAST_PAY").alias("LastPaymentDate"),
    F.col("LAST_AMOUNT_PAY").alias("LastPaymentAmount"),
    F.col("user_field3").alias("Type"),
    F.col("STATEMENT_TYPE").alias("StatementType"),
    F.col("CREDIT_TERM").alias("CreditTerm"),
    F.col("Pay_Method").alias("PaymentMethod"),
    F.col("Creation_Date").alias("CreationDate"),
    F.col("Last_Modified_Date").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_ArMaster")
print("Silver build complete: Silver_ArMaster written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof
# (that's the independent DuckDB script in Task 12).
sample = spark.sql("SELECT * FROM delta.`Tables/Silver_ArMaster` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMaster.Notebook"
git commit -m "Add Build_Silver_ArMaster notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Build `Build_Silver_ArMasterCustomer.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMasterCustomer.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMasterCustomer.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_ArMasterCustomer"
  },
  "config": {
    "version": "2.0",
    "logicalId": "317c6480-cde2-4a8f-9324-4aeaca2aaff8"
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

# Build_Silver_ArMasterCustomer
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates
# ArMaster_Customer off the old ODBC-based df_ArMaster_Customer_Raw
# dataflow (used by dim_CustomerList) onto a OneLake shortcut of JD's own
# live mirror. The old dataflow's own header comments documented an
# unresolved "300-400% refresh performance degradation" investigation
# (refresh time grew from 1-2 minutes to 6-8 minutes) with no root cause
# ever found - shortcutting from JD's live mirror sidesteps that problem
# entirely, since there is no ODBC query against EquipRDB64 running for
# this table anymore at all.
#
# Replicates the old dataflow's UPPER(TRIM(contact_code)) transform in
# Spark, since it can no longer happen at the ODBC/SQL layer.
#
# NOT in scope: any gold-layer business logic, any report repointing
# (dim_CustomerList itself is a separate, larger, deferred project - see
# project memory), any refresh schedule.

print("=" * 80)
print("BUILD_SILVER_ARMASTERCUSTOMER")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("ArMaster_Customer")
bronze_count = bronze.count()
print(f"Bronze ArMaster_Customer rows: {bronze_count:,}")

silver = bronze.select(
    F.upper(F.trim(F.col("contact_code"))).alias("ContactID"),
    F.col("Customer_No").alias("CustomerNumber"),
    F.col("customer_no_char").alias("CustomerNumberChar"),
    F.col("STATUS_CODE").alias("StatusCode"),
    F.col("ACC_TYPE").alias("AccountType"),
    F.col("TRADE_TYPE").alias("TradeType"),
    F.col("DISC_TYPE").alias("DiscountType"),
    F.col("TAX_EXEMPT_NO").alias("TaxExemptNumber"),
    F.col("QUOTE_PURCH_ORD").alias("QuotePurchaseOrder"),
    F.col("TERRITORY").alias("Territory"),
    F.col("PRICE_LEVEL").alias("PriceLevel"),
    F.col("PRICE_PERCENT").alias("PricePercent"),
    F.col("LABOUR_RATE").alias("LabourRate"),
    F.col("BILL_TO_ACC").alias("BillToAccount"),
    F.col("NOTE").alias("CustomerNotes"),
    F.col("capricorn_number").alias("CapricornNumber"),
    F.col("alert").alias("CustomerAlert"),
    F.col("Tax_Exempt_Type").alias("TaxExemptType"),
    F.col("allow_trans_no_cc").alias("AllowTransactionNoCC"),
    F.col("CreationDate").alias("CreatedDate"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_ArMasterCustomer")
print("Silver build complete: Silver_ArMasterCustomer written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_ArMasterCustomer` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_ArMasterCustomer.Notebook"
git commit -m "Add Build_Silver_ArMasterCustomer notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 5: Build `Build_Silver_Contact.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Contact.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Contact.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_Contact"
  },
  "config": {
    "version": "2.0",
    "logicalId": "f0d99bfd-7408-4faf-bc32-bfeb651832d4"
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

# Build_Silver_Contact
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates `contact`
# off the old ODBC-based df_CONTACT_Raw dataflow (used alongside
# ArMaster_Customer and ArMaster_Contact by dim_CustomerList) onto a
# OneLake shortcut of JD's own live mirror. Same performance-issue family
# as ArMaster_Customer per the old dataflow's own header notes ("Related
# Tables with Same Issue") - resolved the same way, by not running any
# ODBC query against EquipRDB64 for this table at all anymore.
#
# The live bronze `contact` table has ~92 columns (JD's mirror carries the
# full source table); this notebook selects only the 14 the old dataflow
# documented and consumed downstream, same contract as before. Replicates
# the old dataflow's UPPER(TRIM(contact_code)) transform in Spark.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_CONTACT")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("contact")
bronze_count = bronze.count()
print(f"Bronze contact rows: {bronze_count:,}")

silver = bronze.select(
    F.upper(F.trim(F.col("contact_code"))).alias("ContactID"),
    F.col("surname").alias("LastName"),
    F.col("name").alias("FirstName"),
    F.col("company_name").alias("CompanyName"),
    F.col("bus_phone").alias("BusinessPhone"),
    F.col("mob_phone").alias("MobilePhone"),
    F.col("email_address").alias("Email"),
    F.col("street").alias("Street"),
    F.col("city").alias("City"),
    F.col("state").alias("State"),
    F.col("pcode").alias("PostalCode"),
    F.col("country").alias("Country"),
    F.col("Account_Class").alias("AccountClass"),
    F.col("Last_Modified_Date").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only selects/renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_Contact")
print("Silver build complete: Silver_Contact written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_Contact` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Contact.Notebook"
git commit -m "Add Build_Silver_Contact notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 6: Build `Build_Silver_GlMaster.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_GlMaster.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_GlMaster.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_GlMaster"
  },
  "config": {
    "version": "2.0",
    "logicalId": "3569652d-b03e-4980-b563-49835a96b8b7"
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

# Build_Silver_GlMaster
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates GLMASTER off
# the old ODBC-based df_GlMaster_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror. Grain is the composite key
# (Branch, Department, Account, SubAccount).
#
# COY is deliberately excluded, same as the old dataflow - its own header
# comment confirms COY is always = 1 across all records (verified
# 2026-04-10), so it carries no information. No other transforms are
# applied - this is a plain rename, nothing computed.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_GLMASTER")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("GLMASTER")
bronze_count = bronze.count()
print(f"Bronze GLMASTER rows: {bronze_count:,}")

silver = bronze.select(
    F.col("BRANCH").alias("Branch"),
    F.col("DEPT").alias("Department"),
    F.col("ACCT").alias("Account"),
    F.col("SUB_ACCT").alias("SubAccount"),
    F.col("DESCRIPTION").alias("Description"),
    F.col("ALT_DESC").alias("AltDescription"),
    F.col("SHORT_CODE").alias("ShortCode"),
    F.col("ACC_TYPE").alias("AccType"),
    F.col("CATEGORY").alias("Category"),
    F.col("balance_type").alias("BalanceType"),
    F.col("CONTROL").alias("Control"),
    F.col("ACCT_GROUP1").alias("AccountGroup1"),
    F.col("ACCT_GROUP2").alias("AccountGroup2"),
    F.col("ACCT_GROUP3").alias("AccountGroup3"),
    F.col("ACCT_GROUP4").alias("AccountGroup4"),
    F.col("ACCT_GROUP5").alias("AccountGroup5"),
    F.col("CLEAR_SUB_ACCT").alias("ClearSubAccount"),
    F.col("REL_Sales_ACCT").alias("RelSalesAccount"),
    F.col("REL_Sales_SUB").alias("RelSalesSub"),
    F.col("REL_COS_ACCT").alias("RelCosAccount"),
    F.col("REL_COS_SUB").alias("RelCosSub"),
    F.col("Cash_Flow_Code").alias("CashFlowCode"),
    F.col("GST_CATEGORY").alias("GstCategory"),
    F.col("DrCrSwitch_Ind").alias("DrCrSwitchInd"),
    F.col("Retain_Doc_Date").alias("RetainDocDate"),
    F.col("Notes").alias("Notes"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_GlMaster")
print("Silver build complete: Silver_GlMaster written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_GlMaster` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_GlMaster.Notebook"
git commit -m "Add Build_Silver_GlMaster notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 7: Build `Build_Silver_InSalOrd.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalOrd.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalOrd.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_InSalOrd"
  },
  "config": {
    "version": "2.0",
    "logicalId": "acc2362a-e024-4740-a224-7276f33783f1"
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

# Build_Silver_InSalOrd
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates InSalOrd off
# the old ODBC-based df_INSALORD_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror. The old dataflow's own header comment already
# documented this as "ALL HISTORICAL DATA (no date filters)" - a plain
# rename, no transforms.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_INSALORD")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("InSalOrd")
bronze_count = bronze.count()
print(f"Bronze InSalOrd rows: {bronze_count:,}")

silver = bronze.select(
    F.col("FILE_NO").alias("FileNumber"),
    F.col("BRANCH").alias("Branch"),
    F.col("CUST_ORD_NO").alias("CustomerOrderNumber"),
    F.col("TAX_NO").alias("TaxNumber"),
    F.col("TYPE").alias("OrderType"),
    F.col("FREIGHT").alias("Freight"),
    F.col("SALESMAN").alias("Salesperson"),
    F.col("ORD_DATE").alias("OrderDate"),
    F.col("Created_On").alias("CreatedDate"),
    F.col("DEPOSIT").alias("Deposit"),
    F.col("CUSTOMER_NO").alias("CustomerNumber"),
    F.col("VEHICLE_NO").alias("VehicleNumber"),
    F.col("SPECIAL_INST").alias("SpecialInstructions"),
    F.col("RO_BRANCH").alias("ROBranch"),
    F.col("RO_NUMBER").alias("RONumber"),
    F.col("NOTE").alias("Note"),
    F.col("auth_id").alias("AuthID"),
    F.col("auth_value").alias("AuthValue"),
    F.col("REC_CONTROL").alias("RecControl"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_InSalOrd")
print("Silver build complete: Silver_InSalOrd written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_InSalOrd` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalOrd.Notebook"
git commit -m "Add Build_Silver_InSalOrd notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 8: Build `Build_Silver_InSalPar.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalPar.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalPar.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_InSalPar"
  },
  "config": {
    "version": "2.0",
    "logicalId": "14f6f873-e463-4465-8067-fe22f1b7b566"
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

# Build_Silver_InSalPar
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates InSalPar off
# the old ODBC-based df_INSALPAR_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror. The old dataflow's own header comment already
# documented this as "ALL HISTORICAL DATA (no date filters)" - a plain
# rename, no transforms.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_INSALPAR")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("InSalPar")
bronze_count = bronze.count()
print(f"Bronze InSalPar rows: {bronze_count:,}")

silver = bronze.select(
    F.col("FILE_NO").alias("FileNumber"),
    F.col("Line_No").alias("LineNumber"),
    F.col("BRANCH").alias("Branch"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("PART_NO").alias("PartNumber"),
    F.col("ORDER_QTY").alias("OrderQty"),
    F.col("SUPPLIED_QTY").alias("SuppliedQty"),
    F.col("COMM_PART_QTY").alias("BackorderQty"),
    F.col("UNIT_PRICE").alias("UnitPrice"),
    F.col("UNIT_COST").alias("UnitCost"),
    F.col("JOB_CODE").alias("JobCode"),
    F.col("SALESMAN").alias("Salesperson"),
    F.col("PURORDER_TYPE").alias("PurOrderType"),
    F.col("Creation_Datetime").alias("CreationDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_InSalPar")
print("Silver build complete: Silver_InSalPar written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_InSalPar` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InSalPar.Notebook"
git commit -m "Add Build_Silver_InSalPar notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 9: Build `Build_Silver_VhStockAccess.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStockAccess.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStockAccess.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_VhStockAccess"
  },
  "config": {
    "version": "2.0",
    "logicalId": "d7ac216d-17a4-4f1d-80b5-2a19e6dbeb05"
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

# Build_Silver_VhStockAccess
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates
# VhStockAccess off the old ODBC-based df_VhStockAccess_Raw dataflow onto
# a OneLake shortcut of JD's own live mirror. The old dataflow defined
# RangeStart/RangeEnd/StartStr/EndStr variables in its M code but never
# actually referenced them in the SQL string (dead code - the old
# comment literally says "if date filtering is possible") - confirmed via
# direct read this session that this table was genuinely unfiltered
# despite appearances, so this migration changes nothing about scope.
#
# Column casing note: the live JD Bronze schema uses mixed case
# (Stock_No, Sale_Value, Cost_Value, Qty, Description) rather than the old
# dataflow's all-caps SQL text (STOCK_NO, SALE_VALUE, COST_VALUE, QTY,
# DESCRIPTION) - SQL Anywhere resolves column names case-insensitively so
# the old ODBC query worked regardless, but this notebook references the
# actual live column names directly (confirmed via a live schema query
# this session), not the old dataflow's SQL text.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_VHSTOCKACCESS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("VhStockAccess")
bronze_count = bronze.count()
print(f"Bronze VhStockAccess rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Stock_No").alias("StockNumber"),
    F.col("Code").alias("Code"),
    F.col("Type").alias("Type"),
    F.col("Description").alias("Description"),
    F.col("Sale_Value").alias("SaleValue"),
    F.col("Cost_Value").alias("CostValue"),
    F.col("Qty").alias("Quantity"),
    F.col("Cost_Estimate").alias("CostEstimate"),
    F.col("Make").alias("Make"),
    F.col("serial_no").alias("SerialNo"),
    F.col("CreatedBy").alias("CreatedBy"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_VhStockAccess")
print("Silver build complete: Silver_VhStockAccess written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_VhStockAccess` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStockAccess.Notebook"
git commit -m "Add Build_Silver_VhStockAccess notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 10: Build `Build_Silver_WarSubClLabour.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarSubClLabour.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarSubClLabour.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WarSubClLabour"
  },
  "config": {
    "version": "2.0",
    "logicalId": "dcfbdba1-2053-4fe7-a776-4aba899f92e8"
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

# Build_Silver_WarSubClLabour
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates
# WarSubCl_Labour off the old ODBC-based df_WARSUBCI_LABOUR_Raw dataflow
# onto a OneLake shortcut of JD's own live mirror. Plain rename, no
# transforms - the old dataflow's SQL never filtered this table.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_WARSUBCLLABOUR")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WarSubCl_Labour")
bronze_count = bronze.count()
print(f"Bronze WarSubCl_Labour rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Invoice_No").alias("InvoiceNumber"),
    F.col("Claim_No").alias("ClaimNumber"),
    F.col("Sub_Claim").alias("SubClaimNumber"),
    F.col("Sequence").alias("SequenceNumber"),
    F.col("Amount").alias("LaborAmount"),
    F.col("Type").alias("LaborType"),
    F.col("Flat_Rate_Code").alias("FlatRateCode"),
    F.col("Diagnostic_Ind").alias("IsDiagnostic"),
    F.col("Labour_Comments").alias("Comments"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WarSubClLabour")
print("Silver build complete: Silver_WarSubClLabour written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WarSubClLabour` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarSubClLabour.Notebook"
git commit -m "Add Build_Silver_WarSubClLabour notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 11: Build `Build_Silver_BranchName.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_BranchName.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_BranchName.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_BranchName"
  },
  "config": {
    "version": "2.0",
    "logicalId": "c51a5178-096c-44b4-97d7-2720220e7ce0"
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

# Build_Silver_BranchName
# Purpose: Part of raw-sources batch 1 (2026-09-10). Migrates Branch_Name
# off the old ODBC-based df_Branch_Name_Raw dataflow onto a OneLake
# shortcut of JD's own live mirror.
#
# Unlike every other notebook in this batch, the old dataflow did NO
# column selection or renaming at all - confirmed by reading its mashup.pq
# directly (schema-navigation passthrough: Source{[Name="Administrator",
# Kind="Schema"]}[Data]{[Name="Branch_Name", Kind="Table"]}[Data], with no
# Table.SelectColumns/RenameColumns step). There is no existing rename
# contract to preserve, so this notebook passes every bronze column
# through unchanged - still gets its own notebook/Silver table for
# consistency with the rest of this batch and to leave room for future
# normalization if a real need for it shows up.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_BRANCHNAME")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

bronze = spark.read.table("Branch_Name")
bronze_count = bronze.count()
print(f"Bronze Branch_Name rows: {bronze_count:,}")

# No column selection/renaming - the old dataflow passed every source
# column through unchanged, so this notebook does the same.
silver = bronze

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook is a pure passthrough, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_BranchName")
print("Silver build complete: Silver_BranchName written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_BranchName` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_BranchName.Notebook"
git commit -m "Add Build_Silver_BranchName notebook (raw sources batch 1)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 12: Brian syncs Dev and runs all 9 notebooks

**Files:** none (Fabric portal action)

- [ ] **Step 1: Sync the workspace**

`DP - Staging - Dev` → Source control → **Update all**.

- [ ] **Step 2: Run each notebook**

Open each of the 9 notebooks below (in `Data Notebooks/`) and **Run all** cells. They're independent of each other and small (largest bronze table is `VhStockAccess` at ~696k rows) - run them one at a time or back-to-back, whichever is convenient:

- `Build_Silver_ArMaster`
- `Build_Silver_ArMasterCustomer`
- `Build_Silver_Contact`
- `Build_Silver_GlMaster`
- `Build_Silver_InSalOrd`
- `Build_Silver_InSalPar`
- `Build_Silver_VhStockAccess`
- `Build_Silver_WarSubClLabour`
- `Build_Silver_BranchName`

- [ ] **Step 3: Report back each notebook's own output**

For each: the bronze row count, the silver row count (should match exactly), and the sample rows printed at the end. If any notebook's assertion fails (row count mismatch) or throws an error, stop and report the full error/stack trace rather than re-running blindly - that would mean either the shortcut or the column mapping has a real problem worth root-causing, not a transient failure.

---

### Task 13: Independently verify all 9 Silver tables

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch1.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP RAW SOURCES BATCH 1 - SILVER VERIFICATION
============================================================================
Independent check of the 9 Silver tables built in this batch - confirms
each Silver table's row count matches its bronze shortcut exactly (no loss
or duplication from the rename/select step), for every table.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name)
TABLE_PAIRS = [
    ("ArMaster", "Silver_ArMaster"),
    ("ArMaster_Customer", "Silver_ArMasterCustomer"),
    ("contact", "Silver_Contact"),
    ("GLMASTER", "Silver_GlMaster"),
    ("InSalOrd", "Silver_InSalOrd"),
    ("InSalPar", "Silver_InSalPar"),
    ("VhStockAccess", "Silver_VhStockAccess"),
    ("WarSubCl_Labour", "Silver_WarSubClLabour"),
    ("Branch_Name", "Silver_BranchName"),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Bronze':<20} {'Silver':<22} {'Bronze rows':>15} {'Silver rows':>15} {'Match':>8}")
print("=" * 90)

all_match = True
for bronze_name, silver_name in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    match = bronze_count == silver_count
    all_match = all_match and match
    print(f"{bronze_name:<20} {silver_name:<22} {bronze_count:>15,} {silver_count:>15,} {'OK' if match else 'MISMATCH':>8}")

print("=" * 90)
print(f"All 9 Silver tables match their bronze shortcut exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch1.py
```

Expected: all 9 rows show `OK`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch1.py
git commit -m "Add Silver verification for raw sources batch 1

Confirms all 9 new Silver tables match their bronze shortcut row
count exactly (ArMaster, ArMasterCustomer, Contact, GlMaster,
InSalOrd, InSalPar, VhStockAccess, WarSubClLabour, BranchName).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 14: Update reference docs

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`

- [ ] **Step 1: Add the new tables to `DP_Staging`'s Lakehouses table**

In `docs/architecture/data-platform-workspaces.md`, find the `DP_Staging` lakehouse table row and add the 9 new shortcuts and 9 new Silver tables to its listed contents (following the same format used for the existing `InTrans`/`GlTrans`/`PartInformation_Active`/`PartInformation_Dead`/`Silver_PartInformation` entries).

- [ ] **Step 2: Add a new section for this batch**

Add a `## Raw sources batch 1 (2026-09-10) — simple shortcuts` section (following the same format as the existing "jdis_Part_Information tiered refresh" section) covering:
- Why: 9 tables in `LH_Master_Data` were pulled via ODBC from `EquipRDB64` despite already existing, live, in JD's own Fabric mirror - pure waste of source-system load and CU, with `ArMaster_Customer` specifically having a long-standing unresolved "300-400% refresh degradation" investigation in the old pipeline
- What was built: 9 OneLake shortcuts (zero CU cost, always current, no refresh action needed at all) + 9 Silver notebooks replicating each old dataflow's exact column rename contract
- The 9 tables and their row counts (from Task 12's actual run output)
- Verification results (both Task 2 and Task 13's scripts, all passing)
- What's explicitly deferred: the `InMaster` consolidation (4 dataflows, one source table), the date-windowed tables (structurally simple but a real scope decision on whether to keep/drop the windowing), `InHist_PmManage`/`WKRODESC` (real business-rule filters), the Technician-family view rebuild, any report repointing, any refresh schedule

- [ ] **Step 3: Mark these 9 tables done in the catalog doc**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`, in the Category A table, add a note next to each of the 9 migrated rows (`ArMaster`, `ArMaster_Customer`, `contact`, `GLMASTER`, `InSalOrd`, `InSalPar`, `VhStockAccess`, `WarSubCl_Labour`, `Branch_Name`) marking them migrated, e.g. "**Migrated 2026-09-10** — see raw sources batch 1 section in `data-platform-workspaces.md`".

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document raw sources batch 1: 9 tables shortcut + normalized

9 Category A tables (ArMaster, ArMaster_Customer, contact, GLMASTER,
InSalOrd, InSalPar, VhStockAccess, WarSubCl_Labour, Branch_Name)
moved from ODBC-based LH_Master_Data dataflows onto OneLake shortcuts
of JD_EquipRDB_Production_Bronze + Silver notebooks replicating each
old dataflow's column rename contract. Zero CU cost, always current,
no refresh action needed. Resolves ArMaster_Customer's long-standing
unresolved refresh-performance investigation as a side effect.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 15: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into the InMaster consolidation, the date-windowed tables, `InHist_PmManage`/`WKRODESC`, the Technician-family rebuild, or any report repointing as part of this plan** — those are each their own future decision, not implied by completing this one.
