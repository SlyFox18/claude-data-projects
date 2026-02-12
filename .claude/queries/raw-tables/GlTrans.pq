/*
============================================================================
Query: GlTrans (Raw) - Parts Adjustments
Dataflow: df_GlTrans_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: GL transaction records for parts inventory adjustments
Created: [Unknown - pre-dates current documentation]
Last Modified: 12/22/2025
Output: Lakehouse table "GlTrans"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Weekdays only at 7:30 AM (via Master Orchestrator Pipeline)
Average Refresh Time: ~6-8 minutes (TODAY: 4:32 min - RECENTLY INCREASED from 2-3 min)
Refresh Strategy: Full refresh (filtered dataset since 2023-01-01)
Row Count: 208,637 rows (as of 1/14/2026)
Query Folding: ✅ YES (SQL query with WHERE clause filtering)

🚨 CRITICAL PERFORMANCE ISSUE - FIFTH TABLE IN 7:30 AM SYSTEMIC PATTERN:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 2-3 minutes refresh time
• Recent: 6-8 minutes refresh time
• Today: 4:32 minutes (improvement but still 2x historical)
• Degradation: 200-300% increase in refresh time
• Pattern: SAME as ArMaster tables and contact table

**This is the FIFTH table confirming the 7:30 AM systemic issue!**

Investigation Priority: HIGH (Part of proven systemic 7:30 AM timing problem)

🔍 PATTERN CONFIRMATION - 7:30 AM REFRESH WINDOW ISSUE:

**Affected Tables (Now 5 tables across multiple families):**
1. ArMaster_Contact - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
2. ArMaster_Customer - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
3. armaster - 53K rows, 6-7 min (was 1-2 min, today 3:30) - 7:30 AM weekdays
4. contact - 82K rows, 6-8 min (was 1:30-2 min, today 4:23) - 7:30 AM weekdays
5. **GlTrans - 209K rows, 6-8 min (was 2-3 min, today 4:32) - 7:30 AM weekdays**

**Pattern Still Holds:**
• ✅ All at 7:30 AM weekdays
• ✅ All via pipeline (now confirmed: Master Orchestrator Pipeline)
• ✅ All 200-400% degradation
• ✅ All intermittent (today all improved: 3:30, 4:23, 4:32)
• ✅ Different table families (ArMaster, contact, GlTrans)
• ✅ Different row counts (53K, 82K, 209K all affected)

**Today's Consistent Improvement Pattern:**
• armaster: 6-7 min → 3:30 min (50% improvement)
• contact: 6-8 min → 4:23 min (40% improvement)
• GlTrans: 6-8 min → 4:32 min (40% improvement)
• **All three improved on same day - strong evidence of external factor**

🏗️ MASTER ORCHESTRATOR PIPELINE ARCHITECTURE:

**Pipeline Flow (Sequential):**
```
Master Orchestrator Pipeline (7:30 AM weekdays)
    ↓
1. Raw Data Tables Refresh (multiple tables in parallel?)
   - ArMaster_Contact
   - ArMaster_Customer
   - armaster
   - contact
   - GlTrans
   - [Others?]
    ↓
   Wait for ALL raw tables to complete
    ↓
2. Dimension Tables Refresh
   - dim_CustomerList
   - dim_BranchLocation
   - dim_Parts
   - [Others?]
    ↓
   Wait for ALL dimensions to complete
    ↓
3. Fact Tables Refresh
   - [Various fact tables]
    ↓
   Complete
```

**Pipeline Design Characteristics:**
• Sequential stages: Raw → Dims → Facts
• Waits between stages for completion
• All raw tables likely start at same time (7:30 AM)
• If any raw table slow, entire pipeline delays
• Ripple effect: Raw delays → Dim delays → Fact delays

**Optimization Opportunities:**
• Stagger raw table start times (don't all start at 7:30 AM exactly)
• Parallel pipelines for independent table families
• Incremental refresh for tables with ModifiedDate
• Reduce refresh frequency for rarely-changing tables
• Move some refreshes outside 7:30 AM window

🎯 BUSINESS USE CASES:
• Parts Adjustment Classification: SUB_ACCT provides adjustment type classification
  - 1=Stock Check, 2=Customer BIN, 3=Damaged, 4=Lost, 5=Overage, 6=Count Off
• Financial Reconciliation: GL value tracking for parts adjustments
• Audit Trail: Batch and reference tracking for compliance
• Fact Table Integration: Joins to InTrans via trans_id for unified fact table

📊 DATA STRUCTURE (17 COLUMNS):

**Transaction Identification:**
• TransId: Unique transaction identifier (JOIN KEY to InTrans - critical!)
• DocRef: Document reference number (batch identifier)
• Ref: Reference number
• Batch: Batch number for grouped transactions

**Classification & Categorization:**
• Branch: Branch location
• SubAccount: Sub-account code (adjustment type - 1-6)
• Department: GL department (filtered to 30 = Parts only)
• Account: GL account (filtered to 480 = Parts Adjustments only)
• Type: Transaction type code

**Transaction Details:**
• TransDate: GL transaction date
• PeriodDate: Accounting period date
• PeriodNo: Accounting period number
• Qty: Quantity (GL side)
• Value: Dollar value of transaction

**Context & Audit:**
• Description: Transaction description
• CreationDate: Record creation timestamp
• ModifiedDate: Record modification timestamp (may be null)

🔧 DESIGN PRINCIPLES:

**Focused Filtering (Efficient):**
• WHERE DEPT = 30 (Parts department only)
• WHERE ACCT = 480 (Parts adjustments GL account only)
• WHERE GLTRANS_DATE >= '2023-01-01' (historical data limit)
• Filtering dramatically reduces data volume from GlTrans table
• Only 209K rows instead of potentially millions

**Type Transformations Applied:**
• Explicit type conversions for all columns
• Ensures data type consistency
• Int64 for IDs and codes
• Datetime for dates
• Number for quantities and values
• Text for descriptions and references

**Full Refresh Strategy:**
• Filtered dataset is relatively small (209K rows)
• 2-3 minute historical refresh time was acceptable
• 6-8 minute current time is NOT acceptable (due to external factor)
• ModifiedDate may be null (not reliable for incremental refresh)
• Date filter (>= 2023-01-01) provides natural partitioning

**Join Key for Fact Table:**
• TransId is the critical join key to InTrans
• One-to-one relationship expected
• Used to enrich InTrans with GL classification (SubAccount → PAType)

⚠️ IMPORTANT NOTES:

**Master Orchestrator Pipeline Context:**
• This table is part of the Master Orchestrator Pipeline
• Pipeline runs at 7:30 AM weekdays
• Sequential stages: Raw → Dims → Facts
• If this table slow, entire pipeline delayed
• Optimization of this table benefits entire pipeline

**Performance Issue Impact on Pipeline:**
• GlTrans taking 6-8 min (instead of 2-3) delays entire pipeline by 3-5 minutes
• If 5+ tables all delayed 3-5 minutes, raw stage delays 3-5 minutes total (if parallel)
• If tables are sequential in pipeline, delays multiply
• Example: 5 tables × 4 min delay = 20 minutes total pipeline delay

**CU Impact Calculation:**
• GlTrans alone: 4-5 min extra × 5 days/week = 20-25 min/week wasted
• Plus 4 other confirmed tables: 95-120 min/week wasted (from previous analysis)
• **Total for 5 tables: 115-145 minutes/week wasted CU consumption**
• If more tables affected: Could be 200+ minutes/week

**Optimization Strategies:**

**Option 1: Fix 7:30 AM Root Cause** (addresses all tables)
• Investigate gateway, source DB, network at 7:30 AM
• Identify competing processes
• Fix resource contention
• **Benefit: Fixes all 5+ tables simultaneously**

**Option 2: Stagger Refresh Times** (within pipeline)
• Start ArMaster tables at 7:30 AM
• Start contact at 7:32 AM
• Start GlTrans at 7:34 AM
• Reduces simultaneous load on gateway/source
• **Benefit: Spreads resource usage over time**

**Option 3: Parallel Pipelines** (independent table families)
• Pipeline A: ArMaster tables (customer/AR data)
• Pipeline B: GlTrans (financial data)
• Pipeline C: Other independent tables
• Run at different times or truly parallel
• **Benefit: Isolates performance issues, faster overall**

**Option 4: Reduce Refresh Frequency** (business validation needed)
• Do customer/contact tables need daily refresh?
• Does GlTrans need daily refresh (financial data typically batched)
• Consider weekly or end-of-month refresh
• **Benefit: Immediate CU savings with no code changes**

**Option 5: Incremental Refresh** (where possible)
• contact has ModifiedDate ✅
• ArMaster_Customer has ModifiedDate ✅
• armaster has ModifiedDate ✅
• GlTrans: ModifiedDate may be null ❌ (check reliability)
• **Benefit: Dramatic CU reduction even with daily refresh**

**ModifiedDate Reliability:**
• GlTrans has ModifiedDate field
• May be null (need to verify percentage of nulls)
• If reliable, incremental refresh possible with date filter as fallback
• If unreliable, use CreationDate or TransDate for incremental logic

Dependencies:
• None (direct source system table - filtered view)

Used By:
• Fact_PartsAdjustment (joins via TransId)
• Parts adjustment analytics
• GL reconciliation reports

Related Tables with Same Issue:
• ArMaster_Contact (7:30 AM performance issue)
• ArMaster_Customer (7:30 AM performance issue)
• armaster (7:30 AM performance issue)
• contact (7:30 AM performance issue)
• [Likely more tables in Master Orchestrator Pipeline]

Critical Finding:
**Master Orchestrator Pipeline at 7:30 AM weekdays has systemic performance issue affecting multiple stages!**

============================================================================
*/

let
    // ========================================================================
    // SQL QUERY - PARTS ADJUSTMENTS GL TRANSACTIONS
    // ========================================================================
    /*
    STRATEGY: Extract GL transactions for parts adjustments only
    FILTERS: Dept=30 (Parts), Acct=480 (Adjustments), Since 2023-01-01
    JOIN KEY: trans_id links to InTrans for fact table creation
    PERFORMANCE: Filtered query reduces data volume significantly
    */

    SQL =
    "SELECT
        -- ===== TRANSACTION IDENTIFICATION =====
        trans_id AS TransId,
        DOC_REF AS DocRef,
        REF AS Ref,
        BATCH AS Batch,

        -- ===== CLASSIFICATION & CATEGORIZATION =====
        BRANCH AS Branch,
        SUB_ACCT AS SubAccount,
        DEPT AS Department,
        ACCT AS Account,
        TYPE AS Type,

        -- ===== TRANSACTION DETAILS =====
        GLTRANS_DATE AS TransDate,
        PERIOD_DATE AS PeriodDate,
        PERIOD_NO AS PeriodNo,
        QTY AS Qty,
        VALUE AS Value,

        -- ===== CONTEXT & AUDIT =====
        DESCRIPTION AS Description,
        CreationDate AS CreationDate,
        ModifiedDate AS ModifiedDate

    FROM GlTrans
    WHERE DEPT = 30
      AND ACCT = 480
      AND GLTRANS_DATE >= '2023-01-01'
    ORDER BY trans_id",

    // ========================================================================
    // EXECUTE QUERY
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to GlTrans. Verify database connection and table availability.",

    // ========================================================================
    // TYPE TRANSFORMATIONS
    // ========================================================================

    TypedColumns = Table.TransformColumnTypes(
        Source,
        {
            {"TransId", Int64.Type},
            {"DocRef", type text},
            {"Ref", type text},
            {"Batch", type text},
            {"Branch", type text},
            {"SubAccount", Int64.Type},
            {"Department", Int64.Type},
            {"Account", Int64.Type},
            {"Type", type text},
            {"TransDate", type datetime},
            {"PeriodDate", type datetime},
            {"PeriodNo", Int64.Type},
            {"Qty", type number},
            {"Value", type number},
            {"Description", type text},
            {"CreationDate", type datetime},
            {"ModifiedDate", type datetime}
        }
    )

in
    TypedColumns

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - PART OF 7:30 AM SYSTEMIC ISSUE
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Filtered Scope: Only parts adjustments (Dept=30, Acct=480, since 2023)
• Normalized Naming: Column names match InTrans convention
• Join Ready: TransId is the key to link with InTrans
• Type Safety: Explicit type transformations applied
• Performance: Filtering reduces dataset significantly

🚨 FIFTH TABLE CONFIRMING 7:30 AM SYSTEMIC ISSUE:
• Historical: 2-3 minutes → Recent: 6-8 minutes
• Today: 4:32 minutes (improvement matching pattern of other tables)
• Part of Master Orchestrator Pipeline (sequential stages: Raw → Dims → Facts)
• Pipeline-wide impact: Delays cascade through stages

⚡ OPTIMIZATION ROADMAP:

**Immediate (This Week):**
• Document ALL tables in Master Orchestrator Pipeline
• Map pipeline dependencies and timing
• Business validation: Does GlTrans need daily refresh?
• Check ModifiedDate reliability for incremental refresh

**Short-term (Next 2 Weeks):**
• Fix 7:30 AM root cause (benefits all 5+ tables)
• OR stagger refresh times within pipeline
• OR reduce refresh frequency based on business needs
• Test pipeline optimization strategies

**Medium-term (Week 3-4):**
• Redesign Master Orchestrator Pipeline:
  - Parallel pipelines for independent table families
  - Staggered start times (not all 7:30 AM)
  - Incremental refresh where possible
• Monitor pipeline performance for 1 week
• Document before/after pipeline timing

📊 EXPECTED OUTCOMES:

**Scenario 1: Fix 7:30 AM Root Cause**
• GlTrans: 6-8 min → 2-3 min (return to historical)
• Plus 4 other tables also fixed
• Total savings: 115-145 min/week (5 tables)

**Scenario 2: Incremental Refresh (if ModifiedDate reliable)**
• GlTrans: 6-8 min → <1 min (only changed records)
• Daily changes likely minimal for GL data
• Savings: 5-7 min/day × 5 days = 25-35 min/week

**Scenario 3: Pipeline Optimization**
• Parallel pipelines: Reduce total pipeline time by 30-50%
• Staggered starts: Reduce individual table times by 20-40%
• Combined: Significant CU savings and faster data availability

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM weekdays (Master Orchestrator Pipeline)
• Data Completeness: Filtered to parts adjustments only
• Join Key: TransId links to InTrans (one-to-one)
• Type Safety: Explicit transformations ensure consistency
• Pipeline Stage: Raw data (stage 1 of 3)

💡 KEY INSIGHT - PIPELINE ARCHITECTURE:
• Master Orchestrator Pipeline orchestrates Raw → Dims → Facts
• Sequential stages create dependencies
• If any raw table slow, entire pipeline delayed
• Optimization benefits all downstream stages
• Consider redesigning for parallel execution where possible

============================================================================
*/
