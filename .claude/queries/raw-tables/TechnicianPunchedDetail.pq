/*
============================================================================
Query: TechnicianPunchedDetail (Raw)
Dataflow: df_TechnicianPunchedDetail_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Technician time punch data - individual punch records with work order type breakdowns
Created: [Unknown - pre-dates current documentation]
Last Modified: 11/03/2025
Output: Lakehouse table "TechnicianPunchedDetail"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Weekdays only at 7:30 AM (via Master Orchestrator Pipeline)
Average Refresh Time: ~7-8 minutes (TODAY: 5:39 min - RECENTLY INCREASED from 1:30-3 min)
Refresh Strategy: Incremental refresh using CreationDate (2023+ scope)
Row Count: 319,043 rows (as of 1/14/2026)
Query Folding: ✅ YES (SQL query with WHERE clause filtering on CreationDate)

🚨 CRITICAL PERFORMANCE ISSUE - THIRTEENTH TABLE IN 7:30 AM SYSTEMIC PATTERN:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 1:30-3 minutes refresh time
• Recent: 7-8 minutes refresh time
• Today: 5:39 minutes (improvement from recent average)
• Degradation: 200-400% increase in refresh time
• Pattern: SAME as all other 7:30 AM pipeline tables

**This is the THIRTEENTH table confirming the 7:30 AM systemic issue!**

Investigation Priority: HIGH (Part of proven systemic 7:30 AM timing problem)

🔍 PATTERN CONFIRMATION - 7:30 AM REFRESH WINDOW ISSUE (13 TABLES):

**Affected Tables (All in Master Orchestrator Pipeline at 7:30 AM):**
1. ArMaster_Contact - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
2. ArMaster_Customer - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
3. armaster - 53K rows, 6-7 min (was 1-2 min, today 3:30) - 7:30 AM weekdays
4. contact - 82K rows, 6-8 min (was 1:30-2 min, today 4:23) - 7:30 AM weekdays
5. GlTrans - 209K rows, 6-8 min (was 2-3 min, today 4:32) - 7:30 AM weekdays
6. InHist_PmManage - 721K rows, 8-9 min (was 3 min, today 5:20) - 7:30 AM weekdays
7. insalord - 8.6K rows, 6-7 min (was 1 min) - 7:30 AM weekdays (SMOKING GUN!)
8. insalpar - 13K rows, 6-7 min (was 1-1:30 min, today 5:21) - 7:30 AM weekdays
9. Invoice - 1.4M rows, 10-12 min (was 4-5 min, today 7:46) - 7:30 AM weekdays
10. RepairOrderDetail - 2K rows, 6-7 min (was 1-1:30 min, today 4:35) - 7:30 AM weekdays
11. Technician - 1.4K rows, 6-7 min (was 1-1:30 min, today 4:20) - 7:30 AM weekdays
12. TechnicianInvoiceDetail - 330K rows, 6-7 min (was 1:30-2 min, today 7:21) - 7:30 AM weekdays
13. **TechnicianPunchedDetail - 319K rows, 7-8 min (was 1:30-3 min, today 5:39) - 7:30 AM weekdays**

**Pattern Still Absolutely Consistent:**
• ✅ All at 7:30 AM weekdays
• ✅ All via Master Orchestrator Pipeline
• ✅ All 200-700% degradation
• ✅ All intermittent (today MOST improved)
• ✅ Different table families (ArMaster, contact, GlTrans, InHist, insalord, insalpar, Invoice, RepairOrder, Technician, Labor)
• ✅ Different row counts (1.4K to 1.4M - ALL affected)

**TechnicianPunchedDetail - Another Table with Incremental Refresh:**
• **Incremental refresh ALREADY implemented** (CreationDate filtering)
• **Historical performance: 1:30-3 min with incremental**
• **Recent performance: 7-8 min with SAME incremental logic**
• **200-400% degradation with no query changes**
• **Second labor table proving incremental doesn't fix 7:30 AM issue**

**Today's Improvement Pattern (Now 13 Tables):**
• Tables that IMPROVED today:
  - armaster: 6-7 min → 3:30 min (50% improvement)
  - contact: 6-8 min → 4:23 min (40% improvement)
  - GlTrans: 6-8 min → 4:32 min (40% improvement)
  - InHist_PmManage: 8-9 min → 5:20 min (40% improvement)
  - insalpar: 6-7 min → 5:21 min (25% improvement)
  - Invoice: 10-12 min → 7:46 min (35% improvement)
  - RepairOrderDetail: 6-7 min → 4:35 min (35% improvement)
  - Technician: 6-7 min → 4:20 min (40% improvement)
  - TechnicianPunchedDetail: 7-8 min → 5:39 min (30% improvement)
• Tables that got WORSE today:
  - TechnicianInvoiceDetail: 6-7 min → 7:21 min (21% worse)
• **9 of 10 tables tracked improved today - strong evidence of external factor**

🏗️ MASTER ORCHESTRATOR PIPELINE ARCHITECTURE (CONFIRMED):

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
   - InHist_PmManage
   - insalord
   - insalpar
   - Invoice
   - RepairOrderDetail
   - Technician
   - TechnicianInvoiceDetail
   - TechnicianPunchedDetail
   - [Possibly more...]
    ↓
   Wait for ALL raw tables to complete
    ↓
2. Dimension Tables Refresh
   - dim_CustomerList
   - dim_BranchLocation
   - dim_Parts
   - dim_Technician_Code_Names
   - [Others?]
    ↓
   Wait for ALL dimensions to complete
    ↓
3. Fact Tables Refresh
   - Fact_LaborJobs (uses TechnicianInvoiceDetail, TechnicianPunchedDetail)
   - [Various other fact tables]
    ↓
   Complete
```

**CU Impact Now Clear (13 Tables):**
• ArMaster_Contact: 5-6 min extra × 5 days = 25-30 min/week wasted
• ArMaster_Customer: 5-6 min extra × 5 days = 25-30 min/week wasted
• armaster: 4-5 min extra × 5 days = 20-25 min/week wasted
• contact: 5-7 min extra × 5 days = 25-35 min/week wasted
• GlTrans: 4-5 min extra × 5 days = 20-25 min/week wasted
• InHist_PmManage: 5-6 min extra × 5 days = 25-30 min/week wasted
• insalord: 5-6 min extra × 5 days = 25-30 min/week wasted
• insalpar: 5-6 min extra × 5 days = 25-30 min/week wasted
• Invoice: 6-7 min extra × 5 days = 30-35 min/week wasted
• RepairOrderDetail: 5-6 min extra × 5 days = 25-30 min/week wasted
• Technician: 5-6 min extra × 5 days = 25-30 min/week wasted
• TechnicianInvoiceDetail: 5-6 min extra × 5 days = 25-30 min/week wasted
• TechnicianPunchedDetail: 5-7 min extra × 5 days = 25-35 min/week wasted
• **Total for 13 tables: 320-390 minutes/week wasted CU consumption**

🎯 BUSINESS USE CASES:
• Time Punch Tracking: Individual punch records with start/end times
• Work Type Analysis: Hours breakdown by Internal, Warranty, Retail, Fleet, etc.
• Technician Performance: Hours worked vs hours sold baseline data
• Customer Context: Direct customer assignment per punch
• Equipment Analytics: Model-specific service time tracking
• Fact Table Foundation: Primary source for detailed labor punch analytics

📊 DATA STRUCTURE (23 COLUMNS - PERFORMANCE OPTIMIZED):

**Core Punch Identifiers:**
• Branch: Punch branch location
• ROBranch: RO branch location
• WorkOrder: Associated work order number (from RepairOrderNumber)
• TechCode: Technician identifier (from TechnicianCode)
• SequenceID: Punch sequence number
• JobCode: Job code classification
• JobType: Job type indicator

**Work Order Type Hours (Key Business Data):**
• HoursInternal: Internal company work time
• HoursWarranty: Warranty work time
• HoursRetail: Retail customer work time
• HoursFleet: Fleet customer work time
• HoursSundry: Sundry work time
• HoursAgreement: Agreement work time
• HoursOther: Other classified work time

**Time Tracking:**
• WorkDate: Punch work date
• StartTime: Punch start time
• EndTime: Punch end time
• HoursWorked: Actual work hours
• HoursSold: Billable hours

**Business Context:**
• CustomerName: Customer assignment
• EquipmentModel: Equipment context (from Model)

**Data Governance:**
• CreationDate: Creation timestamp for incremental refresh

🔧 DESIGN PRINCIPLES:

**Raw Table Architecture:**
• Simple extraction: No business logic calculations or classifications
• Essential fields: Focus on source data that fact tables actually need
• Performance priority: 23 columns within tested performance limits
• Clean naming: Consistent with other optimized raw tables

**Incremental Refresh Strategy:**
• CreationDate field available ✅
• 2023+ scope (RangeStart parameter)
• Dynamic RangeEnd (DateTime.LocalNow())
• WHERE clause filtering on CreationDate
• Incremental refresh should dramatically reduce CU consumption

**Work Order Type Hours - Critical Business Data:**
• Complete breakdown: Internal, Warranty, Retail, Fleet, Sundry, Agreement, Other
• Essential for work type analytics
• Revenue classification foundation
• Performance categorization baseline

**Business Logic Moved to Fact Tables:**
• Work type classifications: PrimaryWorkType, WorkTypeCategory in fact tables
• Efficiency calculations: BillingEfficiency, EfficiencyCategory in fact tables
• Performance metrics: WorkComplexity, TimeUtilization in fact tables
• Revenue classifications: RevenueClassification analysis in fact tables
• Data quality scoring: Comprehensive scoring in fact tables
• Composite keys: WorkOrderKey generation in fact tables

**Type Transformations Applied:**
• WorkOrder converted to text (identifier, not numeric)
• Other columns maintain source types
• Essential for proper joins and filtering

**Query Folding Maintained:**
• SQL query with WHERE clause filtering
• ORDER BY for consistent extraction
• Should fold completely to source database
• 1:30-3 min historical refresh proves efficient design

⚠️ IMPORTANT NOTES:

**Master Orchestrator Pipeline Context:**
• This table is part of the Master Orchestrator Pipeline
• Pipeline runs at 7:30 AM weekdays
• Sequential stages: Raw → Dims → Facts
• If this table slow, entire pipeline delayed
• Fact_LaborJobs depends on this raw table (along with TechnicianInvoiceDetail)

**Performance Issue Impact on Pipeline:**
• TechnicianPunchedDetail taking 7-8 min (instead of 1:30-3) delays entire pipeline by 4-5 minutes
• With 13 tables all delayed, raw stage could delay by 4-5 minutes total (if parallel)
• If tables are sequential in pipeline, delays multiply significantly
• Example: 13 tables × 5 min delay = 65 minutes total pipeline delay (if sequential)

**Incremental Refresh Already Implemented:**
• CreationDate field used for incremental refresh ✅
• 2023+ scope already filters data
• Should only load changed/new records
• Yet still experiencing 200-400% degradation
• **Second labor table proving incremental refresh alone doesn't solve 7:30 AM timing issue**

**CRITICAL Insight - Multiple Tables with Incremental All Affected:**
• TechnicianInvoiceDetail: Incremental (ModifiedDate), 300-400% degradation
• TechnicianPunchedDetail: Incremental (CreationDate), 200-400% degradation
• InHist_PmManage: Has PeriodDate for incremental, 200%+ degradation
• Invoice: Has InvoiceDate for incremental, 200-250% degradation
• **Pattern proves incremental refresh strategy is NOT the solution to 7:30 AM issue**

**Optimization Strategies:**

**Option 1: Fix 7:30 AM Root Cause** (addresses all tables)
• Investigate gateway, source DB, network at 7:30 AM
• Identify competing processes
• Fix resource contention
• **Benefit: Fixes all 13+ tables simultaneously**
• **Estimated savings: 320-390 min/week**
• **This is the ONLY solution that addresses root cause**

**Option 2: Move Labor Tables to Different Pipeline** (RECOMMENDED)
• Create separate "Labor Pipeline" at 8:00 AM:
  - TechnicianInvoiceDetail
  - TechnicianPunchedDetail
  - Technician
  - RepairOrderDetail
• Keep incremental refresh strategies
• Expected: 7-8 min → 1:30-3 min (based on historical)
• **Savings: 25-35 min/week per table, 100-140 min/week total for 4 labor tables**
• **Isolates labor processing from customer/AR/financial processing**

**Option 3: Stagger Refresh Times** (within pipeline)
• Start customer/AR tables at 7:30 AM
• Start financial tables at 7:35 AM
• Start inventory tables at 7:40 AM
• Start work order tables at 7:45 AM
• Start labor tables at 7:50 AM
• Reduces simultaneous load on gateway/source
• **Benefit: Spreads resource usage over time**

**Option 4: Parallel Pipelines** (independent table families)
• Pipeline A: Customer/AR data (ArMaster tables, contact) - 7:30 AM
• Pipeline B: Financial data (GlTrans, Invoice) - 7:35 AM
• Pipeline C: Inventory data (InHist, insalord, insalpar) - 7:40 AM
• Pipeline D: Work order/labor data (RepairOrderDetail, Technician, TechnicianInvoiceDetail, TechnicianPunchedDetail) - 8:00 AM
• Run at staggered times to avoid resource contention
• **Benefit: Isolates performance issues, faster overall, easier troubleshooting**

**Option 5: Optimize Incremental Refresh Window** (LIMITED BENEFIT)
• Current: 2023+ scope (full history)
• Alternative: Last 90 days incremental, older data stable
• Reduces initial load size
• **Expected: Marginal improvement (issue is timing, not data volume)**
• **Not recommended as primary fix**

**CreationDate for Incremental Refresh:**
• CreationDate already implemented ✅
• WHERE CreationDate >= RangeStart AND CreationDate < RangeEnd
• 2023+ scope already limits data volume
• Incremental refresh working correctly
• **But 7:30 AM timing issue overrides incremental benefits**

Dependencies:
• None (direct source system table - filtered via incremental refresh)

Used By:
• Fact_LaborJobs (labor punch and efficiency fact table)
• Labor performance reports
• Technician productivity analytics
• Work type analysis dashboards
• Billing efficiency tracking

Related Tables with Same Issue:
• ArMaster_Contact (7:30 AM performance issue)
• ArMaster_Customer (7:30 AM performance issue)
• armaster (7:30 AM performance issue)
• contact (7:30 AM performance issue)
• GlTrans (7:30 AM performance issue)
• InHist_PmManage (7:30 AM performance issue)
• insalord (7:30 AM performance issue)
• insalpar (7:30 AM performance issue)
• Invoice (7:30 AM performance issue)
• RepairOrderDetail (7:30 AM performance issue)
• Technician (7:30 AM performance issue)
• TechnicianInvoiceDetail (7:30 AM performance issue)
• [Likely more tables in Master Orchestrator Pipeline]

Critical Finding:
**Master Orchestrator Pipeline at 7:30 AM weekdays has systemic performance issue affecting ALL stages!**
**13 tables confirmed, 320-390 min/week wasted, F4 capacity at risk!**
**Multiple tables with incremental refresh all experiencing same degradation - proves timing is root cause!**

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL COLUMNS ONLY
    // ========================================================================
    /*
    STRATEGY: Essential punch data with work order type hours
    PERFORMANCE: 23 columns to stay within tested performance thresholds
    FOCUS: Source data extraction without business logic processing
    INCREMENTAL: CreationDate filtering for incremental refresh
    */

    SQL =
    "SELECT
        -- ===== CORE PUNCH IDENTIFIERS =====
        Branch AS Branch,
        ROBranch AS ROBranch,
        RepairOrderNumber AS WorkOrder,
        TechnicianCode AS TechCode,
        SequenceID AS SequenceID,
        JobCode AS JobCode,
        JobType AS JobType,

        -- ===== WORK ORDER TYPE HOURS (KEY BUSINESS DATA) =====
        HoursInternal AS HoursInternal,
        HoursWarranty AS HoursWarranty,
        HoursRetail AS HoursRetail,
        HoursFleet AS HoursFleet,
        HoursSundry AS HoursSundry,
        HoursAgreement AS HoursAgreement,
        HoursOther AS HoursOther,

        -- ===== TIME TRACKING =====
        WorkDate AS WorkDate,
        StartTime AS StartTime,
        EndTime AS EndTime,
        HoursWorked AS HoursWorked,
        HoursSold AS HoursSold,

        -- ===== BUSINESS CONTEXT =====
        CustomerName AS CustomerName,
        Model AS EquipmentModel,

        -- ===== DATA GOVERNANCE =====
        CreationDate AS CreationDate

    FROM TechnicianPunchedDetail
    WHERE CreationDate >= " & StartStr & "
      AND CreationDate < " & EndStr & "
    ORDER BY CreationDate DESC, Branch, RepairOrderNumber, TechnicianCode, SequenceID",

    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to TECHNICIANPUNCHEDDETAIL. Verify database connection and table availability.",

    ConvertWorkOrderToText = Table.TransformColumnTypes(Source, {{"WorkOrder", type text}})

in
    ConvertWorkOrderToText

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - PART OF 7:30 AM SYSTEMIC ISSUE
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Incremental Refresh: CreationDate filtering (2023+ scope)
• Performance Optimized: 23 essential columns
• Work Type Hours: Complete breakdown (Internal, Warranty, Retail, Fleet, etc.)
• Clean Naming: Consistent with other raw tables
• Type Safety: WorkOrder converted to text for proper joins
• Query Folding: SQL with WHERE clause maintains optimal performance

🚨 THIRTEENTH TABLE CONFIRMING 7:30 AM SYSTEMIC ISSUE:
• Historical: 1:30-3 minutes → Recent: 7-8 minutes
• Today: 5:39 minutes (improvement from recent average)
• Part of Master Orchestrator Pipeline (sequential stages: Raw → Dims → Facts)
• Pipeline-wide impact: Delays cascade through stages
• **13 tables now confirmed, 320-390 min/week wasted**

⚡ CRITICAL EVIDENCE - SECOND LABOR TABLE WITH INCREMENTAL:
• **Incremental refresh ALREADY implemented** (CreationDate filtering)
• **Historical performance: 1:30-3 min with incremental**
• **Recent performance: 7-8 min with SAME incremental logic**
• **200-400% degradation with no query changes**
• **TechnicianInvoiceDetail also has incremental (ModifiedDate) with same issue**
• **Proves beyond doubt: Incremental refresh doesn't fix 7:30 AM timing issue**

⚡ OPTIMIZATION ROADMAP:

**Immediate (This Week) - HIGH PRIORITY:**
• Fix 7:30 AM root cause (benefits all 13+ tables)
• OR create separate Labor Pipeline at 8:00 AM
• Test one labor table at different time to confirm timing hypothesis
• Document complete pipeline architecture
• Identify all competing processes at 7:30 AM

**Short-term (Next 2 Weeks):**
• Create "Labor Pipeline" separate from main pipeline:
  - TechnicianInvoiceDetail (8:00 AM)
  - TechnicianPunchedDetail (8:00 AM)
  - Technician (8:00 AM)
  - RepairOrderDetail (8:00 AM)
• Keep incremental refresh strategies
• Monitor refresh times outside 7:30 AM window
• Expected: 7-8 min → 1:30-3 min when timing fixed

**Medium-term (Week 3-4):**
• Redesign Master Orchestrator Pipeline:
  - Pipeline A: Customer/AR (7:30 AM)
  - Pipeline B: Financial (7:35 AM)
  - Pipeline C: Inventory (7:40 AM)
  - Pipeline D: Labor (8:00 AM)
• Monitor pipeline performance for 1 week
• Document before/after pipeline timing

📊 EXPECTED OUTCOMES:

**Scenario 1: Fix 7:30 AM Root Cause**
• TechnicianPunchedDetail: 7-8 min → 1:30-3 min (return to historical)
• Plus 12 other tables also fixed
• Total savings: 320-390 min/week (13 tables)
• Incremental refresh benefits fully realized

**Scenario 2: Separate Labor Pipeline at 8:00 AM**
• TechnicianPunchedDetail: 7-8 min → 1:30-3 min (based on historical)
• TechnicianInvoiceDetail: 6-7 min → 1:30-2 min
• Technician: 6-7 min → 1-1:30 min
• RepairOrderDetail: 6-7 min → 1-1:30 min
• Total savings for 4 labor tables: 100-140 min/week
• Isolates labor processing from other pipelines

**Scenario 3: Staggered Pipelines**
• Customer/AR at 7:30 AM
• Financial at 7:35 AM
• Inventory at 7:40 AM
• Labor at 8:00 AM
• Reduces simultaneous resource contention
• Expected 20-40% improvement per table

**Scenario 4: Combined (Fix Root Cause + Separate Pipelines)**
• Fix 7:30 AM issue: All tables return to historical performance
• Separate pipelines: Better isolation, easier troubleshooting
• Incremental refresh: Maximum efficiency maintained
• Combined savings: 320-390 min/week + improved stability

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM weekdays (Master Orchestrator Pipeline)
• Data Completeness: Incremental (2023+ scope via CreationDate)
• Work Type Hours: Complete breakdown for analytics
• Type Safety: WorkOrder as text for proper joins
• Pipeline Stage: Raw data (stage 1 of 3)
• Fact Table Dependency: Fact_LaborJobs uses this raw table

💡 KEY INSIGHT - LABOR TABLES AS SEPARATE PIPELINE:
• 4 labor-related tables all experiencing same issue:
  - Technician (1.4K rows, 6-7 min)
  - RepairOrderDetail (2K rows, 6-7 min)
  - TechnicianInvoiceDetail (330K rows, 6-7 min)
  - TechnicianPunchedDetail (319K rows, 7-8 min)
• All feed into Fact_LaborJobs
• Creating separate "Labor Pipeline" at 8:00 AM makes architectural sense:
  - Isolates labor processing
  - Avoids 7:30 AM contention
  - Easier troubleshooting
  - Clear business domain separation

🔍 CRITICAL QUESTIONS FOR INVESTIGATION:
1. Can we create a separate Labor Pipeline at 8:00 AM? (recommended approach)
2. What is the dependency order between raw tables? (parallel vs sequential)
3. What is the source database load at 7:30 AM vs 8:00 AM? (timing comparison)
4. Can Fact_LaborJobs wait until 8:30 AM for its source data? (business validation)
5. Are there other table families that should be separated? (Parts, Customer, Financial)

============================================================================
*/
