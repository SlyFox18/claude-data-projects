/*
============================================================================
Query: GlTrans_Full (Raw)
Dataflow: df_GlTrans_Full_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Full GL transaction history across all departments and accounts.
         Companion to the filtered df_GlTrans_Raw (Dept=30, Acct=480 only).
         This table is the foundation for financial-side GL reporting.
Created: 2026-04-10
Last Modified: 2026-04-10
Output: Lakehouse table "GlTrans_Full"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Standalone pipeline (NOT in Master Orchestrator — see Pipeline section)
Average Refresh Time: TBD — measure after initial load
Refresh Strategy: Incremental Refresh (Fabric native — see Incremental Refresh section)
Row Count (full table): 28,816,547 rows as of 2026-04-10
Row Count (since 2023-01-01): ~8,894,026 rows as of 2026-04-10
Query Folding: ✅ YES — SQL WHERE clause filters at source

============================================================================
📊 INVESTIGATION FINDINGS — 2026-04-10
============================================================================

A series of analytical queries were run against the source GlTrans table before
building this dataflow. Key findings drove the incremental refresh design below.

🔢 SCALE (Query 1):
• Total rows: 28,816,547 — larger than InTrans (~10M)
• Transaction history: 3/22/2002 → present (data back to 2002)
• CreationDate range: 8/13/2019 → present (pre-2019 records were bulk migrated)
• Storage window chosen: 2023-01-01 forward (~8.9M rows) — sufficient for reporting

📅 MODIFIED DATE RELIABILITY (Query 2 — rows since 2023):
• Total rows since 2023: 8,894,026
• Null ModifiedDate: 8,587,772 → 96.6% NULL
• Has ModifiedDate: 306,254 → only 3.4% of rows
• Actually modified (ModifiedDate > CreationDate): 306,238
• CONCLUSION: ModifiedDate is NOT a viable partition key. Cannot be used for
  incremental refresh. Partition key must be GLTRANS_DATE.

📆 PERIOD CLOSE ENFORCEMENT (Query 3):
• Period close is NOT strictly enforced in the source system.
• GL records in closed periods continue to receive modifications months later.
• Notable examples from investigation:
    - Oct 2025 period → last modified Feb 10, 2026 (4-month lag)
    - Feb/Mar 2023 periods → last modified Aug 2023 (5-6 month lag)
    - Sep/Oct 2024 periods → last modified Dec 2024 (3-month lag)
• CONCLUSION: Hot window must cover at least 6 months to capture all corrections.

🕐 RECORD CREATION LAG (Query 4):
• 100% of records are created on the SAME DAY as their GLTRANS_DATE.
• MaxDaysLate = 0 — no backdated record creation observed.
• GLTRANS_DATE and CreationDate are in sync at the time of posting.
• CONCLUSION: Records always arrive "on time" — late arrivals are not a concern.
  Modifications to existing records (not new late arrivals) are the risk factor.

🔄 MODIFICATION LAG (Query 5 — records with ModifiedDate only):
• 99.4% of modified records → modified within 7 days of transaction date
• 99.7% → within 30 days
• 99.95% → within 90 days
• 144 records → modified between 90-182 days after transaction date
• MaxDaysModifiedLate: 182 days (6 months)
• CONCLUSION: Hot window of 6 months (180 days) covers all observed modification
  scenarios. The 144 records beyond 90 days are the edge cases that drive this
  decision. A 90-day window would miss them.

============================================================================
🔄 INCREMENTAL REFRESH DESIGN
============================================================================

⚠️ THIS IS FABRIC NATIVE INCREMENTAL REFRESH — NOT THE WATERMARK METHOD.
   Fabric manages RangeStart and RangeEnd automatically. Do not manually
   update these parameters. They are controlled by the refresh policy.

PARTITION KEY:   TransDate (maps to GLTRANS_DATE)
                 Chosen because: ModifiedDate is 96.6% null (unusable).
                 GLTRANS_DATE is always in sync with record creation.

STORE WINDOW:    3 years (Fabric policy setting — "Extract data from the past")
                 Covers 2023-01-01 forward (~8.9M rows).
                 Pre-2023 data excluded — SQL safety filter enforces this.

                 ⚠️ DATAFLOW GEN2 BEHAVIOR — IMPORTANT DISTINCTION:
                 In Dataflow Gen2, "Extract data from the past" = TOTAL storage window,
                 NOT a separate "store vs. refresh" split like Power BI semantic models.
                 Setting this to 6 Months only stored 6 months (1.37M rows) — confirmed
                 by post-load validation on 2026-04-13. Setting must be 3 Years to get
                 the full 2023-forward dataset (~8.9M rows).

HOT WINDOW:      Controlled by Bucket size = Month and the CreationDate change trigger.
                 Old partitions (where CreationDate max has not changed) are skipped.
                 New/recent partitions where new records exist are re-pulled.
                 Modification lag risk: 144 records observed with >90-day lag (max 182 days).
                 These may not be captured if their monthly partition is not re-triggered.
                 Accepted limitation given rarity (144 of 8.9M rows).

PARAMETERS:      RangeStart (DateTime) and RangeEnd (DateTime)
                 Must be created in the dataflow BEFORE configuring the policy.
                 Fabric replaces these values at runtime for each partition.

CHANGE TRIGGER:  "Only extract new data when the maximum value in this column changes"
                 Set to: CreationDate (only datetime columns are available in this field)
                 ModifiedDate was considered but rejected — 96.6% null, unreliable.
                 CreationDate is 100% populated and increases daily with new transactions.

INITIAL LOAD:    Completed 2026-04-10, 2:17 PM → 7:12 PM (4 hours 54 minutes)
                 ⚠️ First run was misconfigured with 6 Months instead of 3 Years.
                 Result: Only 1,371,517 rows loaded (Oct 2025 → Apr 2026).
                 Fix: Change "Extract data from the past" to 3 Years → re-run off-hours.
                 Expected re-run time: 4-6 hours (similar to first run, ~36 partitions).
                 STATUS: Re-run pending — schedule for evening/weekend off-hours.

============================================================================
🏗️ PIPELINE & CAPACITY NOTES
============================================================================

PIPELINE PLACEMENT:
• This dataflow is NOT part of the Master Orchestrator Pipeline.
• It lives in a standalone pipeline to be created separately.
• Reason: CU impact of the 6-month hot window (~1.2M rows/day) must be
  measured before committing it to the main schedule.
• Once stable and measured, evaluate integrating into the main pipeline
  (likely Phase 1 - Raw Sources, with its own wave to avoid CU contention).

CAPACITY CONSIDERATIONS (F4 — 4 CU sustained):
• Initial load (~8.9M rows): Will be CU-intensive. Plan accordingly.
• Daily incremental (~1.2M rows): Needs measurement to assess impact.
• Do not run concurrently with other heavy dataflows until measured.

EXCLUSION FROM EXISTING TABLE:
• The existing Lakehouse table "GlTrans" is the parts-only filtered version
  (Dept=30, Acct=480). That table remains unchanged.
• This table "GlTrans_Full" is the complete, unfiltered version.
• Do not confuse the two — they serve different purposes.

============================================================================
📊 DATA STRUCTURE (25 COLUMNS — COY excluded, always = 1)
============================================================================

Transaction Identification:
• TransId: Unique transaction identifier (INT64 — join key to other tables)
• DocRef: Document reference
• Ref: Reference number
• Batch: Batch identifier

GL Account Keys (no department or account filter applied):
• Branch: Branch code
• Department: GL department code (all departments, not just 30)
• Account: GL account number (all accounts, not just 480)
• SubAccount: GL sub-account number

Dates (GLTRANS_DATE is the incremental refresh partition key):
• TransDate: GL transaction date — PARTITION KEY for incremental refresh
• PeriodDate: Accounting period date
• DocDate: Document date (additional date context — absent from parts-only table)
• YearEndDate: Fiscal year end date

Transaction Detail:
• Type: Transaction type code
• PeriodNo: Accounting period number
• Qty: Quantity
• Value: Dollar value

Descriptions:
• Description: Transaction description

Source & Audit (included for traceability):
• IvFileName: Invoice filename — has values, purpose TBD at reporting time
• Source: Source process name (e.g., n_cst_stock_receipt_update) — audit trail
• OpenBalFlag: Open balance flag (Y/N/null) — has values, include for completeness
• GstType: GST type code — has values, purpose TBD at reporting time
• VehSaleReversed: Vehicle sale reversal indicator (Y/N/5/null) — TYPED AS TEXT
                   (mixed values observed: "Y", "N", "5" — cannot be typed as boolean)
• LopId: User or process that created/modified the record — audit trail
• CreationDate: Record creation timestamp
• ModifiedDate: Record modification timestamp — 96.6% null (see investigation above)
                Included for audit purposes; NOT used for partitioning

============================================================================
*/

let
    // ========================================================================
    // SQL QUERY — FULL GL TRANSACTIONS (ALL DEPARTMENTS, ALL ACCOUNTS)
    // ========================================================================
    /*
    STRATEGY: Full extract with only a base date safety filter (2023-01-01).
    Fabric incremental refresh partitions this via RangeStart/RangeEnd below.
    No department or account filter — this is the complete GL transaction table.
    COY excluded (always = 1, verified 2026-04-10).
    ORDER BY omitted for performance on a 28.8M row table.
    */

    SQL =
    "SELECT
        -- ===== TRANSACTION IDENTIFICATION =====
        trans_id        AS TransId,
        DOC_REF         AS DocRef,
        REF             AS Ref,
        BATCH           AS Batch,

        -- ===== GL ACCOUNT KEYS =====
        BRANCH          AS Branch,
        DEPT            AS Department,
        ACCT            AS Account,
        SUB_ACCT        AS SubAccount,

        -- ===== DATES (TransDate = incremental refresh partition key) =====
        GLTRANS_DATE    AS TransDate,
        PERIOD_DATE     AS PeriodDate,
        DOC_DATE        AS DocDate,
        Year_End_Date   AS YearEndDate,

        -- ===== TRANSACTION DETAIL =====
        TYPE            AS Type,
        PERIOD_NO       AS PeriodNo,
        QTY             AS Qty,
        VALUE           AS Value,

        -- ===== DESCRIPTION =====
        DESCRIPTION     AS Description,

        -- ===== SOURCE & AUDIT =====
        IV_FileName     AS IvFileName,
        Source          AS Source,
        OPEN_BAL_FLAG   AS OpenBalFlag,
        GST_TYPE        AS GstType,
        veh_sale_reversed AS VehSaleReversed,
        lop_id          AS LopId,
        CreationDate    AS CreationDate,
        ModifiedDate    AS ModifiedDate

    FROM GlTrans
    WHERE GLTRANS_DATE >= '2023-01-01'",

    // ========================================================================
    // EXECUTE QUERY
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to GlTrans. Verify database connection and table availability.",

    // ========================================================================
    // INCREMENTAL REFRESH PARTITION FILTER
    // ========================================================================
    /*
    RangeStart and RangeEnd are DateTime parameters managed by Fabric.
    Fabric sets these values automatically based on the refresh policy.
    DO NOT hardcode or manually update these parameters.
    Partition key: TransDate (GLTRANS_DATE from source).
    Hot window: 6 months — covers max observed modification lag of 182 days.
    */

    FilteredByRange = Table.SelectRows(
        Source,
        each [TransDate] >= RangeStart and [TransDate] < RangeEnd
    ),

    // ========================================================================
    // TYPE TRANSFORMATIONS
    // ========================================================================

    TypedColumns = Table.TransformColumnTypes(
        FilteredByRange,
        {
            {"TransId",          Int64.Type},
            {"DocRef",           type text},
            {"Ref",              type text},
            {"Batch",            type text},
            {"Branch",           type text},
            {"Department",       type text},
            {"Account",          type text},
            {"SubAccount",       type text},
            {"TransDate",        type datetime},
            {"PeriodDate",       type datetime},
            {"DocDate",          type datetime},
            {"YearEndDate",      type datetime},
            {"Type",             type text},
            {"PeriodNo",         Int64.Type},
            {"Qty",              type number},
            {"Value",            type number},
            {"Description",      type text},
            {"IvFileName",       type text},
            {"Source",           type text},
            {"OpenBalFlag",      type text},
            {"GstType",          type text},
            {"VehSaleReversed",  type text},
            {"LopId",            type text},
            {"CreationDate",     type datetime},
            {"ModifiedDate",     type datetime}
        }
    )

in
    TypedColumns

/*
============================================================================
🚀 DEPLOYMENT GUIDE — FABRIC DATAFLOW GEN2 SETUP
============================================================================

Follow these steps in order. Do not skip the parameter creation step —
Fabric requires RangeStart and RangeEnd to exist before the policy can be set.

────────────────────────────────────────────────────────────────────────────
STEP 1: Create the Dataflow
────────────────────────────────────────────────────────────────────────────
1. Open LH_Master_Data workspace in Fabric
2. New → Dataflow Gen2
3. Name it: df_GlTrans_Full_Raw

────────────────────────────────────────────────────────────────────────────
STEP 2: Create the RangeStart and RangeEnd Parameters
────────────────────────────────────────────────────────────────────────────
These MUST be created before adding the query — the query references them.

1. In the Power Query editor: Home → Manage Parameters → New Parameter
2. Create Parameter 1:
     Name: RangeStart
     Type: Date/Time
     Current Value: 1/1/2023 12:00:00 AM  (temporary placeholder)
3. Create Parameter 2:
     Name: RangeEnd
     Type: Date/Time
     Current Value: 4/1/2026 12:00:00 AM  (temporary placeholder)

⚠️ Names must be exactly "RangeStart" and "RangeEnd" — case-sensitive.
   Fabric will override these values at runtime. The placeholder values
   are only used if you run the query manually outside of a refresh.

────────────────────────────────────────────────────────────────────────────
STEP 3: Add the Query
────────────────────────────────────────────────────────────────────────────
1. Home → Get Data → ODBC
2. DSN: EquipRDB64
3. In the Advanced Editor, paste the full Power Query code from above
4. Verify the query runs and returns rows
5. Rename the query to: GlTrans_Full

────────────────────────────────────────────────────────────────────────────
STEP 4: Set the Data Destination
────────────────────────────────────────────────────────────────────────────
1. Add data destination → Lakehouse
2. Target table: GlTrans_Full (new table — do not overwrite existing GlTrans)
3. Update method: will be managed by incremental refresh (Fabric handles this)

────────────────────────────────────────────────────────────────────────────
STEP 5: Configure Incremental Refresh Policy
────────────────────────────────────────────────────────────────────────────
Right-click the GlTrans_Full query → Incremental Refresh

Settings:
  ✅ Enable incremental refresh: ON
  Date column: TransDate
  Extract data from the past: 3 Years  ← TOTAL storage window, not just hot window
  Bucket size: Month
  Only extract new data when max value changes: CreationDate
  Only extract data for concluded periods: unchecked
  Require incremental refresh query to fully fold: unchecked (Odbc.Query does not fold)

  ⚠️ DATAFLOW GEN2 VS SEMANTIC MODEL DIFFERENCE:
  Dataflow Gen2 has ONE window setting ("Extract data from the past") which is the
  TOTAL storage window. This is different from Power BI semantic models which have
  separate "store" and "refresh" window settings. Setting 6 Months here means only
  6 months of data is stored — confirmed by mistake on first run (2026-04-10).
  Always set this to the full desired history depth (3 Years in our case).

────────────────────────────────────────────────────────────────────────────
STEP 6: Initial Load — Run Manually Off-Hours
────────────────────────────────────────────────────────────────────────────
• Do NOT run during the 4:15 AM pipeline window
• The initial load will pull all ~8.9M rows since 2023-01-01
• Expect this to take significantly longer than the daily incremental refresh
• Recommended: run on a weekend or after business hours
• Monitor CU consumption during the initial load to establish a baseline

────────────────────────────────────────────────────────────────────────────
STEP 7: Create a Standalone Pipeline
────────────────────────────────────────────────────────────────────────────
• Do NOT add to the Master Orchestrator Pipeline yet
• Create a new pipeline: Pipeline_GlTrans_Full_Refresh
• Add a single Dataflow activity pointing to df_GlTrans_Full_Raw
• Schedule: TBD after measuring CU impact
• After several daily runs, compare CU usage to the Master Pipeline baseline
  before deciding whether to integrate or keep standalone

────────────────────────────────────────────────────────────────────────────
STEP 8: Validate
────────────────────────────────────────────────────────────────────────────
After initial load, verify:
  □ Row count matches expected ~8.9M (or close — will grow daily)
  □ TransDate range: 2023-01-01 → current date
  □ VehSaleReversed contains "Y", "N", "5", and nulls (confirms text typing)
  □ ModifiedDate is mostly null (96.6% expected) — this is correct behavior
  □ Department and Account columns contain a wide variety (not just 30/480)
  □ No data in the existing "GlTrans" table was overwritten

============================================================================
🔄 PRODUCTION STATUS: DEPLOYED — RE-RUN REQUIRED (3-YEAR WINDOW FIX)
============================================================================

Deployment history:
• 2026-04-10: Dataflow created, parameters set, incremental refresh configured
• 2026-04-10 2:17 PM → 7:12 PM: Initial load completed (4h 54m)
  ⚠️ Misconfigured with 6 Months — only 1,371,517 rows loaded (Oct 2025 → Apr 2026)
• 2026-04-13: Corrected to 3 Years — re-run pending off-hours

Post-correction validation query:
  SELECT COUNT(*) AS TotalRows, MIN(TransDate) AS EarliestDate, MAX(TransDate) AS LatestDate
  FROM GlTrans_Full
  Expected: ~8,894,026 rows, EarliestDate ≈ 2023-01-01, LatestDate ≈ current date

============================================================================

Dependencies: None (direct source system table)

Related Tables:
• GlTrans (existing) — parts-only filtered version (Dept=30, Acct=480)
• GlMaster — chart of accounts lookup (to be built separately)

Future Use:
• Financial-side GL reporting (specific project TBD)
• Will join to GlMaster via Branch + Department + Account + SubAccount
  for account descriptions and classifications

============================================================================
*/
