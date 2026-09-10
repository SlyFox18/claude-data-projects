# DP Invoice Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `Invoice` — the table deliberately excluded from raw sources batch 2 for its own dedicated treatment — onto the `DP` backend as a OneLake shortcut plus a Silver notebook, and document a real grain bug found in the old dataflow's own (false) documentation.

**Architecture:** Same shortcut + Silver notebook pattern as every other table in this backend. The one thing genuinely specific to this table: a real, confirmed grain bug in the source data (`InvoiceNumber` is not unique, despite the old dataflow's own header claiming it is) gets documented prominently — in the notebook, and in the platform reference doc — rather than silently carried forward.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Design decisions (read before building)

**Full history, no date filter.** Same reasoning as batch 2: the old dataflow's `RangeStart`/`RangeEnd` was Brian's own unfinished incremental-refresh attempt, and date-scoping is a Gold-layer decision, not Silver's. `Invoice`'s old filter column (`invo_datetime`) happened to be 0% NULL — not replicated anyway, for consistency and because the reasoning holds regardless of whether the old column was reliable.

**No partitioning of `Silver_Invoice`.** Explicitly discussed and rejected this session, even though this is by far the largest table this backend has touched (6.5M rows). Partitioning by year would be betting on a specific future Gold-layer consumer's query pattern before any such consumer exists — the same category of premature decision as date-filtering at Silver. Every real optimization built in this backend so far (`jdis_Part_Information`'s tiering, the ancient-date config, the grain fixes) came from a measured, already-documented problem, not speculation — `Invoice` doesn't have one yet, since it isn't feeding anything today. If a real Fact table is later built on top of `Silver_Invoice` and shows an actual, measured need, partitioning (or Delta `OPTIMIZE`/`ZORDER`, a lighter-weight alternative) is the natural fix to reach for then, informed by that consumer's real query pattern — not decided now. `Silver_Invoice` is written as a plain, unpartitioned Delta table, exactly like every other Silver table in this backend.

**Keeps the old dataflow's two data-quality filters** (`document_no IS NOT NULL AND document_no <> ''`) — confirmed via real data this session these have zero current impact (0 rows excluded out of 6,505,866), kept as cheap, harmless insurance against a future bad row.

**The real finding this plan exists to carry forward:** the old dataflow's own header comment claims `Grain: One row per invoice (unique by InvoiceNumber)`. This is false. Confirmed via direct query against live data: 6,505,866 total rows but only 3,806,166 distinct `document_no` values. Two real examples, pulled directly:
- `document_no = '900022'` has 4 completely unrelated records spanning **2012, 2020, 2021, and 2023** — different customers (`JOHNDEERV2`, `22253`, a null, `HERITAGE-CRYS26`), different branches, different module/invoice types.
- `document_no = '2331659999'` has 3 unrelated records across **2014, 2015, 2016**.

This is the same reused-reference-number bug class already confirmed 3 times this session in this exact source system (`TransId`, `GlTrans.DocRef`, `RONumber`) — the source system recycles document numbers over the years. `document_no` alone is never a safe join/dedup key. The real, confirmed-unique grain is **`(document_no, Branch, module_type, invo_type)`** — tested directly this session: `SELECT COUNT(*) FROM (SELECT DISTINCT document_no, Branch, module_type, invo_type FROM Invoice)` returns exactly 6,505,866, matching the total row count exactly.

This is not fixed here — Silver stays a faithful passthrough of the source, deduplication/grain-correction is explicitly Gold's job if/when it's ever needed (matching how the `InTrans`/`GlTrans` reused-key bugs were ultimately handled: a closest-date-match join at the point of actual use, not a magic key baked into Silver). What matters for this plan is that the finding survives — in the notebook's own header, and in the platform reference doc, prominently, not buried — since `Invoice` is a foundational table other future Fact tables will be built on, and this is exactly the kind of thing that silently causes a wrong report later if nobody remembers it (see: Parts Adjustments' PA Type misclassification bug from earlier this session, caused by the same class of mistake with a different table).

---

### Task 1: Brian creates the `Invoice` OneLake shortcut

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `Invoice`
7. Keep the destination name as `Invoice` (don't rename)
8. **Create**

- [ ] **Step 2: Confirm it appears**

In `DP_Staging` → `Tables`, confirm `Invoice` is listed alongside everything else already there. Report back once done.

---

### Task 2: Independently verify the bronze shortcut

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_invoice.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INVOICE - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the new Invoice OneLake shortcut in DP_Staging resolves to the
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

dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Invoice')").fetchone()[0]
jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/Invoice')").fetchone()[0]

print(f"DP_Staging shortcut row count:  {dp_count:,}")
print(f"JD Bronze direct row count:     {jd_count:,}")
print(f"Match: {dp_count == jd_count}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_invoice.py
```

Expected: `Match: True`. If not, stop and check the shortcut was pointed at the right table before proceeding.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_invoice.py
git commit -m "Add bronze shortcut verification for Invoice

Confirms the new DP_Staging Invoice OneLake shortcut resolves to the
exact same row count as JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_Invoice.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Invoice.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Invoice.Notebook/notebook-content.py`

- [ ] **Step 1: Generate a logical ID**

```bash
python -c "import uuid; print(uuid.uuid4())"
```

- [ ] **Step 2: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_Invoice"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<LOGICAL_ID from Step 1>"
  }
}
```

- [ ] **Step 3: Create the notebook content**

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

# Build_Silver_Invoice
# Purpose: Migrates Invoice off the old ODBC-based df_Invoice_Raw dataflow
# onto a OneLake shortcut of JD's own live mirror. Brings in FULL history,
# no date filter - the old dataflow's RangeStart/RangeEnd was Brian's own
# unfinished incremental-refresh attempt, and date-scoping is a Gold-layer
# decision, not Silver's (same reasoning as every other table in this
# backend since raw sources batch 2).
#
# DELIBERATELY UNPARTITIONED, despite this being the largest table this
# backend has touched (6.5M+ rows) - discussed and rejected this session.
# Partitioning (e.g. by year) would bet on a specific future Gold-layer
# consumer's query pattern before any such consumer exists - the same
# category of premature decision as date-filtering at Silver. Every real
# optimization built in this backend so far (jdis_Part_Information's
# tiering, the ancient-date config, the various grain fixes) came from a
# measured, already-documented problem, not speculation - this table
# isn't feeding anything yet. If a real Fact table is later built on top
# of this and shows an actual measured need, partitioning or Delta
# OPTIMIZE/ZORDER is the fix to reach for then, informed by that
# consumer's real query pattern - not decided here.
#
# Keeps the old dataflow's two data-quality filters (document_no IS NOT
# NULL AND document_no <> '') - confirmed this session these have ZERO
# current impact (0 of 6,505,866 rows excluded), kept as cheap insurance
# against a future bad row.
#
# *** REAL GRAIN BUG FOUND THIS SESSION - READ BEFORE BUILDING ANYTHING
# ON TOP OF THIS TABLE ***
# The old dataflow's own header comment claims "Grain: One row per
# invoice (unique by InvoiceNumber)". This is FALSE. Confirmed via direct
# query against live data: 6,505,866 total rows but only 3,806,166
# distinct document_no values. Two real examples pulled directly:
#   - document_no = '900022': 4 completely unrelated records spanning
#     2012, 2020, 2021, and 2023 (different customers - JOHNDEERV2,
#     22253, a null, HERITAGE-CRYS26 - different branches, different
#     module/invoice types)
#   - document_no = '2331659999': 3 unrelated records across
#     2014/2015/2016
# This is the same reused-reference-number bug class already confirmed
# in this exact source system on TransId, GlTrans.DocRef, and RONumber -
# the source system recycles document numbers over the years.
# document_no (InvoiceNumber) ALONE IS NEVER A SAFE JOIN OR DEDUP KEY.
# The real, confirmed-unique grain is (document_no, Branch, module_type,
# invo_type) - tested this session: SELECT COUNT(*) FROM (SELECT DISTINCT
# document_no, Branch, module_type, invo_type FROM Invoice) returns
# exactly 6,505,866, matching the total row count exactly.
# NOT fixed here - Silver stays a faithful passthrough of the source,
# deduplication/grain-correction is Gold's job if/when it's ever needed
# (same pattern as the InTrans/GlTrans reused-key fixes: a closest-date-
# match join at the point of actual use, not a magic key baked into
# Silver). Any future Fact table built on Silver_Invoice MUST account for
# this - joining or grouping on InvoiceNumber alone will silently produce
# wrong results, the same class of bug that caused Parts Adjustments' PA
# Type misclassification earlier this session.
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_INVOICE")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("Invoice")
bronze_count = bronze.count()
print(f"Bronze Invoice rows: {bronze_count:,}")

filtered = bronze.filter(
    F.col("document_no").isNotNull() & (F.col("document_no") != "")
)
filtered_count = filtered.count()
excluded_count = bronze_count - filtered_count
print(f"Rows excluded (missing or empty InvoiceNumber): {excluded_count:,}")

silver = filtered.select(
    F.col("invo_type").alias("InvoiceType"),
    F.col("module_type").alias("ModuleType"),
    F.col("document_no").alias("InvoiceNumber"),
    F.col("ro_number").alias("WorkOrderNumber"),
    F.col("Branch").alias("Branch"),
    F.col("customer_no").alias("CustomerNumber"),
    F.trim(F.col("bill_to_acc")).alias("BillToAccount"),
    F.col("cust_ord_no").alias("CustomerOrderNumber"),
    F.col("company_name").alias("CompanyName"),
    F.col("name").alias("FirstName"),
    F.col("surname").alias("LastName"),
    F.col("stock_no").alias("StockNumber"),
    F.col("vehicle_no").alias("VehicleNumber"),
    F.col("parts_sale_val").alias("PartsSaleValue"),
    F.col("parts_cost_val").alias("PartsCostValue"),
    F.col("labour_sale_val").alias("LabourSaleValue"),
    F.col("labour_cost_val").alias("LabourCostValue"),
    F.col("sublet_sal_val").alias("SubletSaleValue"),
    F.col("sublet_cost_val").alias("SubletCostValue"),
    F.col("other_sale_val").alias("OtherSaleValue"),
    F.col("gst").alias("GST"),
    F.col("paid_cash").alias("PaidCash"),
    F.col("paid_credit_card").alias("PaidCreditCard"),
    F.col("paid_cheque").alias("PaidCheque"),
    F.col("Payment_Method").alias("PaymentMethod"),
    F.col("invo_datetime").alias("InvoiceDate"),
    F.col("cancel_date").alias("CancelDate"),
    F.col("Last_Update_TS").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == filtered_count, (
    f"Row count mismatch after column selection: filtered {filtered_count:,} "
    f"vs silver {silver_count:,} - the select step should never add or drop "
    f"rows beyond the explicit IS NOT NULL/empty filter already applied above."
)
print(f"Silver rows: {silver_count:,} (bronze {bronze_count:,} minus {excluded_count:,} excluded)")

# Deliberately NOT partitioned - see the notebook header for why.
silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_Invoice")
print("Silver build complete: Silver_Invoice written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof
# (that's the independent DuckDB script). Also re-confirms the grain
# finding from the header comment directly against what was just written,
# so it's never trusted secondhand.

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_Invoice` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

grain_check = spark.sql("""
    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT InvoiceNumber) AS distinct_invoice_number,
        COUNT(DISTINCT CONCAT(InvoiceNumber, '|', Branch, '|', ModuleType, '|', InvoiceType)) AS distinct_real_grain
    FROM delta.`Tables/Silver_Invoice`
""").toPandas()
print("\nGrain check (InvoiceNumber alone is NOT unique - see header comment):")
print(grain_check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_Invoice.Notebook"
git commit -m "Add Build_Silver_Invoice notebook

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

Open `Build_Silver_Invoice` (in `Data Notebooks/`) and **Run all** cells.

- [ ] **Step 3: Report back the notebook's own output**

Bronze row count, excluded-row count (expect close to 0), Silver row count, the sample rows, and the grain check cell's output (expect `total_rows` to equal `distinct_real_grain` but be noticeably larger than `distinct_invoice_number` — that's the grain bug, confirmed again on the actual Silver data). If the assertion fails or the write throws an error, stop and report the full error rather than re-running blindly.

---

### Task 5: Independently verify `Silver_Invoice`

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_invoice.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INVOICE - SILVER VERIFICATION
============================================================================
Independent check of Silver_Invoice - confirms the row count matches the
bronze shortcut exactly (this table's IS NOT NULL/empty filter had zero
real-world impact when checked this session, so an exact match is the
expected outcome, not just a close one - if a real difference shows up
here, it means either a genuinely bad row now exists in the source or
something is wrong with the notebook, and it's worth checking which
before assuming it's fine).

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

bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Invoice')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_Invoice')").fetchone()[0]

print(f"Bronze Invoice rows:  {bronze_count:,}")
print(f"Silver Invoice rows:  {silver_count:,}")
print(f"Difference:           {bronze_count - silver_count:,} (expect close to 0 - the IS NOT NULL/empty filter had zero real-world impact when checked this session)")

print("\n=== Independent re-confirmation of the grain finding ===")
distinct_invoice_number = con.execute(f"SELECT COUNT(DISTINCT InvoiceNumber) FROM delta_scan('{dp_base}/Silver_Invoice')").fetchone()[0]
distinct_real_grain = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT DISTINCT InvoiceNumber, Branch, ModuleType, InvoiceType
        FROM delta_scan('{dp_base}/Silver_Invoice')
    )
""").fetchone()[0]

print(f"Distinct InvoiceNumber alone:                      {distinct_invoice_number:,}")
print(f"Distinct (InvoiceNumber, Branch, ModuleType, InvoiceType): {distinct_real_grain:,}")
print(f"Silver row count:                                  {silver_count:,}")
print(f"Real grain matches row count exactly: {distinct_real_grain == silver_count}")
print(f"InvoiceNumber alone is NOT a safe key (expect distinct_invoice_number < silver_count): {distinct_invoice_number < silver_count}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_invoice.py
```

Expected: bronze and Silver row counts match exactly (or within a handful of rows of live source drift), the real grain matches the row count exactly, and `InvoiceNumber` alone is confirmed not unique.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_invoice.py
git commit -m "Add Silver verification for Invoice

Confirms Silver_Invoice matches its bronze shortcut row count exactly,
and independently re-confirms the (InvoiceNumber, Branch, ModuleType,
InvoiceType) grain finding directly against the written Silver data.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Update reference docs

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`

- [ ] **Step 1: Add `Invoice`/`Silver_Invoice` to `DP_Staging`'s Lakehouses table**

In `docs/architecture/data-platform-workspaces.md`, find the `DP_Staging` lakehouse row and add a mention of the new `Invoice` shortcut and `Silver_Invoice` table, pointing to the new section below for the full writeup.

- [ ] **Step 2: Add a new, prominent section**

Add a `## Invoice (2026-09-10) — the grain bug and why Silver stays unpartitioned` section, placed after the "Raw sources batch 2" section, covering:
- The full grain-bug writeup: the old dataflow's false "unique by InvoiceNumber" claim, the real numbers (6,505,866 rows / 3,806,166 distinct `document_no`), both real duplicate examples (`900022` across 2012/2020/2021/2023, `2331659999` across 2014/2015/2016), the confirmed real grain `(document_no, Branch, module_type, invo_type)`, and an explicit warning that any future Fact table built on `Silver_Invoice` must account for this - joining or grouping on `InvoiceNumber` alone will silently produce wrong results, the same bug class as the `InTrans`/`GlTrans`/`RONumber` reuse issues found earlier this session.
- The partitioning decision: why `Silver_Invoice` is deliberately unpartitioned despite being the largest table this backend has touched, and what would justify reconsidering (a real, measured need from an actual Gold-layer consumer - not speculation).
- The two data-quality filters kept (`document_no IS NOT NULL AND document_no <> ''`), confirmed zero current impact.
- Verification results (both scripts, all passing, including the grain re-confirmation).
- What's NOT done here: no deduplication, no gold-layer logic, no report repointing, no refresh schedule, no partitioning.

- [ ] **Step 3: Mark `Invoice` done in the catalog doc**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`, change the `Invoice` row's note from "**Deliberately deferred**" to "**Migrated 2026-09-10**" and point to the new dedicated section (not "see batch N" like the others, since this wasn't part of a batch) - also mention the grain bug finding briefly in this row's note, since it's the most important thing anyone skimming this table would need to know.

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document Invoice migration and the InvoiceNumber grain bug

Invoice (6.5M rows, the largest table this backend has touched) moved
from an ODBC-based LH_Master_Data dataflow onto a OneLake shortcut +
Silver notebook - full history, no date filter, deliberately
unpartitioned (no measured need yet - partitioning is a Gold-layer
decision to make when a real consumer shows a real need, not
speculation).

Real finding, documented prominently: the old dataflow's own header
claimed InvoiceNumber was a unique key. It isn't - confirmed via live
data (6,505,866 rows, only 3,806,166 distinct InvoiceNumber values).
The real grain is (InvoiceNumber, Branch, ModuleType, InvoiceType).
Same reused-reference-number bug class already found on TransId,
GlTrans.DocRef, and RONumber this session.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 7: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into deduplication, gold-layer logic, partitioning, refresh scheduling, or any report repointing as part of this plan** — those are each their own future decision, not implied by completing this one.
