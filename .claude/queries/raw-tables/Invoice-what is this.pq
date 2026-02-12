/*
============================================================================
Query: Invoice (Raw)
Dataflow: df_Invoice_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Invoice transaction data for financial and sales analytics
Created: [Unknown - pre-dates current documentation]
Last Modified: 08/28/2025
Output: Lakehouse table "Invoice"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Weekdays only at 7:30 AM (via Master Orchestrator Pipeline)
Average Refresh Time: ~10-12 minutes (TODAY: 7:46 min - RECENTLY INCREASED from 4-5 min)
Refresh Strategy: Filtered full refresh (3-year scope: InvoiceDate >= 2022-01-01)
Row Count: 1,402,683 rows (as of 1/14/2026)
Query Folding: ✅ YES (SQL query with WHERE clause filtering)

🚨 CRITICAL PERFORMANCE ISSUE - NINTH TABLE IN 7:30 AM SYSTEMIC PATTERN:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 4-5 minutes refresh time
• Recent: 10-12 minutes refresh time
• Today: 7:46 minutes (improvement matching pattern of other tables)
• Degradation: 200-250% increase in refresh time
• Pattern: SAME as all other 7:30 AM pipeline tables

**This is the NINTH table confirming the 7:30 AM systemic issue!**

Investigation Priority: HIGH (Part of proven systemic 7:30 AM timing problem)

🔍 PATTERN CONFIRMATION - 7:30 AM REFRESH WINDOW ISSUE (9 TABLES):

**Affected Tables (All in Master Orchestrator Pipeline at 7:30 AM):**
1. ArMaster_Contact - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
2. ArMaster_Customer - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
3. armaster - 53K rows, 6-7 min (was 1-2 min, today 3:30) - 7:30 AM weekdays
4. contact - 82K rows, 6-8 min (was 1:30-2 min, today 4:23) - 7:30 AM weekdays
5. GlTrans - 209K rows, 6-8 min (was 2-3 min, today 4:32) - 7:30 AM weekdays
6. InHist_PmManage - 721K rows, 8-9 min (was 3 min, today 5:20) - 7:30 AM weekdays
7. insalord - 8.6K rows, 6-7 min (was 1 min) - 7:30 AM weekdays (SMOKING GUN!)
8. insalpar - 13K rows, 6-7 min (was 1-1:30 min, today 5:21) - 7:30 AM weekdays
9. **Invoice - 1.4M rows, 10-12 min (was 4-5 min, today 7:46) - 7:30 AM weekdays**

**Pattern Still Absolutely Consistent:**
• ✅ All at 7:30 AM weekdays
• ✅ All via Master Orchestrator Pipeline
• ✅ All 200-700% degradation
• ✅ All intermittent (today ALL improved)
• ✅ Different table families (ArMaster, contact, GlTrans, InHist, insalord, insalpar, Invoice)
• ✅ Different row counts (8.6K to 1.4M - ALL affected)

**Today's Consistent Improvement Pattern (Now 9 Tables):**
• armaster: 6-7 min → 3:30 min (50% improvement)
• contact: 6-8 min → 4:23 min (40% improvement)
• GlTrans: 6-8 min → 4:32 min (40% improvement)
• InHist_PmManage: 8-9 min → 5:20 min (40% improvement)
• insalpar: 6-7 min → 5:21 min (25% improvement)
• Invoice: 10-12 min → 7:46 min (35% improvement)
• **Six tables improved on same day - overwhelming evidence of external factor**

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
   - [Possibly more...]
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

**CU Impact Now Clear (9 Tables):**
• ArMaster_Contact: 5-6 min extra × 5 days = 25-30 min/week wasted
• ArMaster_Customer: 5-6 min extra × 5 days = 25-30 min/week wasted
• armaster: 4-5 min extra × 5 days = 20-25 min/week wasted
• contact: 5-7 min extra × 5 days = 25-35 min/week wasted
• GlTrans: 4-5 min extra × 5 days = 20-25 min/week wasted
• InHist_PmManage: 5-6 min extra × 5 days = 25-30 min/week wasted
• insalord: 5-6 min extra × 5 days = 25-30 min/week wasted
• insalpar: 5-6 min extra × 5 days = 25-30 min/week wasted
• Invoice: 6-7 min extra × 5 days = 30-35 min/week wasted
• **Total for 9 tables: 220-270 minutes/week wasted CU consumption**

🎯 BUSINESS USE CASES:
• Financial Reporting: Complete invoice transaction history
• Revenue Analytics: Sales tracking across branches and franchises
• Parts vs Labour Analysis: Revenue mix and margin analysis
• Payment Method Tracking: Cash, credit card, cheque intelligence
• Customer Billing: Invoice details for customer statements
• Accounting Reconciliation: GL integration via invoice values
• Sales Performance: Branch and salesperson performance tracking

📊 DATA STRUCTURE (30 COLUMNS):

**Invoice Identification:**
• InvoiceNumber: Unique invoice identifier
• InvoiceDate: Invoice transaction date
• TransactionID: Transaction reference ID
• ARAccountNumber: Customer AR account number
• CustomerName: Customer name
• CustomerNumber: Customer identifier

**Branch & Organization:**
• Branch: Branch location code
• Franchise: Franchise identifier

**Financial Summary (Parts):**
• PartsCost: Cost of parts sold
• PartsMarkup: Markup amount on parts
• PartsNetSales: Net sales value for parts
• TaxExemptPartsSales: Tax-exempt parts sales

**Financial Summary (Labour):**
• LabourCost: Cost of labour
• LabourMarkup: Markup amount on labour
• LabourNetSales: Net sales value for labour
• TaxExemptLabourSales: Tax-exempt labour sales

**Financial Summary (Sublet & Other):**
• SubletCost: Cost of sublet work
• SubletMarkup: Markup amount on sublet
• SubletNetSales: Net sales value for sublet
• TaxExemptSubletSales: Tax-exempt sublet sales
• OtherChargesCost: Cost of other charges
• OtherChargesMarkup: Markup on other charges
• OtherChargesNetSales: Net sales for other charges
• TaxExemptOtherChargesSales: Tax-exempt other charges

**Payment Intelligence:**
• CashReceived: Cash payment amount
• CreditCardReceived: Credit card payment amount
• ChequeReceived: Cheque payment amount

**Classification:**
• InvoiceType: Type of invoice (e.g., Parts, Service, etc.)
• ModuleType: Department module type ('I' = Parts/Inventory, 'W' = Workshop/Service)
• SalespersonCode: Salesperson identifier

🔧 DESIGN PRINCIPLES:

**3-Year Incremental Scope (Focused):**
• WHERE InvoiceDate >= '2022-01-01'
• Reduces data volume significantly (full table likely 10M+ rows)
• 1.4M rows over 3 years is manageable
• Business typically focuses on recent transactions
• Older invoices archived or rarely accessed

**Complete Financial Breakdown:**
• Separate cost, markup, net sales for each category
• Parts, Labour, Sublet, Other Charges tracked independently
• Tax-exempt sales tracked separately (compliance)
• Enables margin analysis by category

**Payment Method Tracking:**
• Cash, credit card, cheque amounts captured
• Important for payment reconciliation
• Cash flow analysis capabilities

**Type Transformations Applied:**
• Explicit type conversions for all columns
• Int64 for IDs and codes
• Text for names and classifications
• Number for financial values
• Datetime for dates

**Normalized Column Names:**
• Applied consistent PascalCase conventions
• Improved readability (e.g., INV_NO → InvoiceNumber)
• Consistent with other raw table naming patterns

⚠️ IMPORTANT NOTES:

**Master Orchestrator Pipeline Context:**
• This table is part of the Master Orchestrator Pipeline
• Pipeline runs at 7:30 AM weekdays
• Sequential stages: Raw → Dims → Facts
• If this table slow, entire pipeline delayed
• Optimization of this table benefits entire pipeline

**Performance Issue Impact on Pipeline:**
• Invoice taking 10-12 min (instead of 4-5) delays entire pipeline by 5-7 minutes
• With 9 tables all delayed, raw stage could delay by 5-7 minutes total (if parallel)
• If tables are sequential in pipeline, delays multiply significantly
• Example: 9 tables × 5 min delay = 45 minutes total pipeline delay (if sequential)

**Large Table with Incremental Scope:**
• 1.4M rows is significant but filtered dataset (2022+)
• Full Invoice table likely 10M+ rows historically
• 3-year scope is business decision (how far back do reports need to go?)
• Consider annual archiving strategy (move pre-2022 to separate archive table)

**Optimization Strategies:**

**Option 1: Fix 7:30 AM Root Cause** (addresses all tables)
• Investigate gateway, source DB, network at 7:30 AM
• Identify competing processes
• Fix resource contention
• **Benefit: Fixes all 9+ tables simultaneously**
• **Estimated savings: 220-270 min/week**

**Option 2: Implement Incremental Refresh**
• InvoiceDate field available ✅
• Filter to current month + prior month for daily refresh
• Full refresh monthly or quarterly for complete history
• **Expected: 10-12 min → <1 min for typical daily invoices**
• **Savings: 9-11 min/day × 5 days = 45-55 min/week**

**Option 3: Reduce 3-Year Scope to 2-Year**
• Business validation: Do we really need 3 years of invoice data?
• 2022-2026 = 3 years (current scope)
• 2023-2026 = 2 years (33% data reduction)
• **Expected: 10-12 min → 7-8 min (25-30% improvement)**
• **Savings: 3-4 min/day × 5 days = 15-20 min/week**

**Option 4: Stagger Refresh Times** (within pipeline)
• Start ArMaster tables at 7:30 AM
• Start contact/Invoice at 7:35 AM
• Start GlTrans/InHist at 7:40 AM
• Reduces simultaneous load on gateway/source
• **Benefit: Spreads resource usage over time**

**Option 5: Parallel Pipelines** (independent table families)
• Pipeline A: Customer/AR data (ArMaster tables, contact)
• Pipeline B: Financial data (GlTrans, Invoice)
• Pipeline C: Inventory data (InHist, insalord, insalpar)
• Run at different times or truly parallel
• **Benefit: Isolates performance issues, faster overall**

**InvoiceDate for Incremental Refresh:**
• InvoiceDate is reliable date field ✅
• Most invoices finalized same day (daily changes minimal)
• Perfect candidate for incremental refresh
• Implement with RangeStart/RangeEnd parameters
• Refresh last 30-60 days daily, full refresh monthly

Dependencies:
• None (direct source system table - filtered view)

Used By:
• Financial reports (revenue, margin, sales analysis)
• Customer billing and statements
• Salesperson performance reports
• Payment reconciliation
• GL integration and reconciliation

Related Tables with Same Issue:
• ArMaster_Contact (7:30 AM performance issue)
• ArMaster_Customer (7:30 AM performance issue)
• armaster (7:30 AM performance issue)
• contact (7:30 AM performance issue)
• GlTrans (7:30 AM performance issue)
• InHist_PmManage (7:30 AM performance issue)
• insalord (7:30 AM performance issue)
• insalpar (7:30 AM performance issue)
• [Likely more tables in Master Orchestrator Pipeline]

Critical Finding:
**Master Orchestrator Pipeline at 7:30 AM weekdays has systemic performance issue affecting ALL stages!**
**9 tables confirmed, 220-270 min/week wasted, F4 capacity at risk!**

============================================================================
*/

let
    // ========================================================================
    // SQL QUERY - INVOICE TRANSACTIONS (3-YEAR SCOPE)
    // ========================================================================
    /*
    STRATEGY: Extract invoice transaction data with 3-year scope
    FILTERS: InvoiceDate >= 2022-01-01
    SCOPE: Complete financial breakdown (Parts, Labour, Sublet, Other)
    PAYMENT: Cash, credit card, cheque tracking
    PERFORMANCE: Filtered query reduces data volume significantly
    */

    SQL =
    "SELECT
        -- ===== INVOICE IDENTIFICATION =====
        INV_NO AS InvoiceNumber,
        INV_DATE AS InvoiceDate,
        TRANS_ID AS TransactionID,
        AR_ACCT_NO AS ARAccountNumber,
        CUST_NAME AS CustomerName,
        CUST_NO AS CustomerNumber,

        -- ===== BRANCH & ORGANIZATION =====
        BRANCH AS Branch,
        FRANCHISE AS Franchise,

        -- ===== FINANCIAL SUMMARY (PARTS) =====
        PARTS_COST AS PartsCost,
        PARTS_MARKUP AS PartsMarkup,
        PARTS_NET_SALES AS PartsNetSales,
        TAX_EXEMPT_PARTS_SALES AS TaxExemptPartsSales,

        -- ===== FINANCIAL SUMMARY (LABOUR) =====
        LABOUR_COST AS LabourCost,
        LABOUR_MARKUP AS LabourMarkup,
        LABOUR_NET_SALES AS LabourNetSales,
        TAX_EXEMPT_LABOUR_SALES AS TaxExemptLabourSales,

        -- ===== FINANCIAL SUMMARY (SUBLET & OTHER) =====
        SUBLET_COST AS SubletCost,
        SUBLET_MARKUP AS SubletMarkup,
        SUBLET_NET_SALES AS SubletNetSales,
        TAX_EXEMPT_SUBLET_SALES AS TaxExemptSubletSales,
        OTHER_CHARGES_COST AS OtherChargesCost,
        OTHER_CHARGES_MARKUP AS OtherChargesMarkup,
        OTHER_CHARGES_NET_SALES AS OtherChargesNetSales,
        TAX_EXEMPT_OTHER_CHARGES_SALES AS TaxExemptOtherChargesSales,

        -- ===== PAYMENT INTELLIGENCE =====
        CASH_RECEIVED AS CashReceived,
        CREDIT_CARD_RECEIVED AS CreditCardReceived,
        CHEQUE_RECEIVED AS ChequeReceived,

        -- ===== CLASSIFICATION =====
        INV_TYPE AS InvoiceType,
        MODULE_TYPE AS ModuleType,
        SALESMAN_CODE AS SalespersonCode

    FROM Invoice
    WHERE INV_DATE >= '2022-01-01'
    ORDER BY INV_DATE DESC, INV_NO",

    // ========================================================================
    // EXECUTE QUERY
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to Invoice table. Verify database connection and table availability.",

    // ========================================================================
    // TYPE TRANSFORMATIONS
    // ========================================================================

    TypedColumns = Table.TransformColumnTypes(
        Source,
        {
            {"InvoiceNumber", type text},
            {"InvoiceDate", type datetime},
            {"TransactionID", Int64.Type},
            {"ARAccountNumber", type text},
            {"CustomerName", type text},
            {"CustomerNumber", type text},
            {"Branch", type text},
            {"Franchise", type text},
            {"PartsCost", type number},
            {"PartsMarkup", type number},
            {"PartsNetSales", type number},
            {"TaxExemptPartsSales", type number},
            {"LabourCost", type number},
            {"LabourMarkup", type number},
            {"LabourNetSales", type number},
            {"TaxExemptLabourSales", type number},
            {"SubletCost", type number},
            {"SubletMarkup", type number},
            {"SubletNetSales", type number},
            {"TaxExemptSubletSales", type number},
            {"OtherChargesCost", type number},
            {"OtherChargesMarkup", type number},
            {"OtherChargesNetSales", type number},
            {"TaxExemptOtherChargesSales", type number},
            {"CashReceived", type number},
            {"CreditCardReceived", type number},
            {"ChequeReceived", type number},
            {"InvoiceType", type text},
            {"ModuleType", type text},
            {"SalespersonCode", type text}
        }
    )

in
    TypedColumns

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - PART OF 7:30 AM SYSTEMIC ISSUE
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• 3-Year Scope: Only invoices since 2022-01-01
• Complete Financial Breakdown: Parts, Labour, Sublet, Other tracked separately
• Payment Intelligence: Cash, credit card, cheque amounts captured
• Normalized Naming: Column names match standard conventions
• Type Safety: Explicit type transformations applied
• Performance: Filtering reduces dataset significantly

🚨 NINTH TABLE CONFIRMING 7:30 AM SYSTEMIC ISSUE:
• Historical: 4-5 minutes → Recent: 10-12 minutes
• Today: 7:46 minutes (improvement matching pattern of other 8 tables)
• Part of Master Orchestrator Pipeline (sequential stages: Raw → Dims → Facts)
• Pipeline-wide impact: Delays cascade through stages
• **9 tables now confirmed, 220-270 min/week wasted**

⚡ OPTIMIZATION ROADMAP:

**Immediate (This Week):**
• Document ALL tables in Master Orchestrator Pipeline
• Map complete pipeline dependencies and timing
• Business validation: Does Invoice need daily refresh?
• Check InvoiceDate reliability for incremental refresh
• Validate 3-year scope requirement (2022+) vs 2-year scope

**Short-term (Next 2 Weeks):**
• Fix 7:30 AM root cause (benefits all 9+ tables)
• OR stagger refresh times within pipeline
• OR implement incremental refresh (InvoiceDate available)
• Test pipeline optimization strategies

**Medium-term (Week 3-4):**
• Redesign Master Orchestrator Pipeline:
  - Parallel pipelines for independent table families
  - Staggered start times (not all 7:30 AM)
  - Incremental refresh for all date-based tables
• Monitor pipeline performance for 1 week
• Document before/after pipeline timing

📊 EXPECTED OUTCOMES:

**Scenario 1: Fix 7:30 AM Root Cause**
• Invoice: 10-12 min → 4-5 min (return to historical)
• Plus 8 other tables also fixed
• Total savings: 220-270 min/week (9 tables)

**Scenario 2: Incremental Refresh (InvoiceDate)**
• Invoice: 10-12 min → <1 min (only recent invoices)
• Daily changes likely minimal (today's invoices only)
• Savings: 9-11 min/day × 5 days = 45-55 min/week

**Scenario 3: Pipeline Optimization**
• Parallel pipelines: Reduce total pipeline time by 30-50%
• Staggered starts: Reduce individual table times by 20-40%
• Combined: Significant CU savings and faster data availability

**Scenario 4: Reduce Scope to 2 Years**
• Invoice: 10-12 min → 7-8 min (33% data reduction)
• If business allows: 2023+ instead of 2022+
• Savings: 3-4 min/day × 5 days = 15-20 min/week

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM weekdays (Master Orchestrator Pipeline)
• Data Completeness: 3-year scope (2022+)
• Financial Breakdown: Complete margin analysis by category
• Payment Tracking: All payment methods captured
• Type Safety: Explicit transformations ensure consistency
• Pipeline Stage: Raw data (stage 1 of 3)

💡 KEY INSIGHT - PIPELINE ARCHITECTURE:
• Master Orchestrator Pipeline orchestrates Raw → Dims → Facts
• Sequential stages create dependencies
• If any raw table slow, entire pipeline delayed
• Optimization benefits all downstream stages
• 9 tables confirmed affected (likely more undocumented)
• Evidence overwhelming: 7:30 AM timing/resource contention issue

🔍 BUSINESS VALIDATION QUESTIONS:
1. Do we really need 3 years of invoice data? (2022+)
2. Would 2 years (2023+) be sufficient for reporting needs?
3. Can we implement incremental refresh (last 30-60 days daily)?
4. Do we need daily invoice refresh or would weekly work?
5. What reports depend on Invoice table? How fresh must data be?

============================================================================
*/
