/*
============================================================================
Query: ArMaster_Customer (Raw)
Dataflow: df_ArMaster_Customer_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Accounts Receivable Master Customer data - core customer information
Created: [Unknown - pre-dates current documentation]
Last Modified: 08/11/2025
Output: Lakehouse table "ArMaster_Customer"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Once daily (7:30 AM)
Average Refresh Time: ~6-8 minutes (RECENTLY INCREASED - WAS 1-2 minutes)
Refresh Strategy: Full refresh
Row Count: 53,470 rows (as of 1/14/2026)
Query Folding: ✅ YES - Confirmed folding occurs

🚨 CRITICAL PERFORMANCE ISSUE - URGENT INVESTIGATION NEEDED:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 1-2 minutes refresh time
• Current: 6-8 minutes refresh time
• Degradation: 300-400% increase in refresh time
• Pattern: Same degradation affecting ArMaster_Contact (same time period)

**Investigation Priority: HIGH**

Potential Root Causes:
1. **Source System Issue** - SQL Anywhere database performance problem
   - Check source database performance metrics
   - Look for table locks, blocking queries, or resource contention
   - Verify database maintenance (stats, indexes) is current

2. **Gateway Issue** - Data gateway performance degradation
   - Check gateway machine resources (CPU, Memory, Network)
   - Review gateway logs for errors or warnings
   - Verify no competing workloads on gateway server
   - Check if gateway needs restart/update

3. **Network Issue** - Connection latency increased
   - Test network connectivity to source database
   - Check for network changes in last 2 weeks
   - Verify no firewall or routing changes

4. **Timing Conflict** - 7:30 AM slot now has contention
   - Check what else runs at 7:30 AM
   - ArMaster_Contact and ArMaster_Customer both run at same time
   - May be competing for same resources

5. **Source System Changes** - Something changed in SQL Anywhere
   - Verify no source table schema changes
   - Check if statistics need updating
   - Look for new processes running during refresh window

**Action Items:**
- [ ] Compare gateway performance metrics (before/after 2 weeks ago)
- [ ] Check SQL Anywhere database health and performance
- [ ] Review what else runs at 7:30 AM (potential conflicts)
- [ ] Test refresh at different time to isolate timing issue
- [ ] Check if both ArMaster tables can be combined into single refresh
- [ ] Verify ODBC driver version hasn't changed

🎯 BUSINESS USE CASES:
• Customer Dimension: Primary source for dim_CustomerList dimension
• AR Analytics: Customer account analysis and reporting
• Customer Segmentation: Trade type, account type, territory analysis
• Pricing Management: Customer-specific pricing levels and discounts
• Tax Management: Tax exemption tracking
• Billing Analysis: Bill-to account relationships
• CRM Integration: Customer alerts and notes
• Territory Management: Sales territory assignment

📊 DATA STRUCTURE (20 COLUMNS):

**Core Customer Identification:**
• ContactID: Contact code identifier (contact_code)
• CustomerNumber: Numeric customer number (Customer_No)
• CustomerNumberChar: Character customer number (customer_no_char)
• CapricornNumber: Capricorn system identifier

**Account Management:**
• StatusCode: Customer account status (STATUS_CODE)
• AccountType: Account type classification (ACC_TYPE)
• TradeType: Trade type classification (TRADE_TYPE)
• Territory: Sales territory assignment (TERRITORY)
• BillToAccount: Billing account reference (BILL_TO_ACC)

**Pricing & Discounts:**
• PriceLevel: Customer price level (PRICE_LEVEL)
• PricePercent: Price percentage adjustment (PRICE_PERCENT)
• DiscountType: Discount type classification (DISC_TYPE)
• LabourRate: Customer-specific labour rate (LABOUR_RATE)

**Tax Management:**
• TaxExemptNumber: Tax exemption number (TAX_EXEMPT_NO)
• TaxExemptType: Tax exemption type classification (Tax_Exempt_Type)

**Business Context:**
• QuotePurchaseOrder: Quote/PO tracking (QUOTE_PURCH_ORD)
• CustomerNotes: Customer notes field (NOTE)
• CustomerAlert: Alert flag/message (alert)
• AllowTransactionNoCC: Transaction without credit card flag (allow_trans_no_cc)

**Timeline Intelligence:**
• CreatedDate: Customer creation date (CreationDate)
• ModifiedDate: Last modification date (ModifiedDate)

🔧 DESIGN PRINCIPLES:

**Standardized Column Names:**
• Applied PascalCase naming convention
• Removed underscores and improved readability
• Example: contact_code → ContactID, customer_no_char → CustomerNumberChar

**Complete Customer Profile:**
• All essential customer attributes captured
• Pricing, discounting, and tax information included
• Audit trail with creation and modification dates

**Query Folding Confirmed:**
• Query does fold to source database
• Performance issue is NOT due to lack of folding
• Issue is external (source, network, gateway, timing)

⚠️ BUSINESS IMPACT OF PERFORMANCE ISSUE:

**CU Consumption:**
• 300-400% increase in refresh time = 300-400% increase in CU usage
• If 20 similar tables affected, CU impact is significant
• F4 capacity may be at risk if pattern continues

**Refresh Schedule Risk:**
• 7:30 AM refresh may delay downstream processes
• If multiple tables are slow, pipeline timing breaks down
• May need to adjust refresh schedule temporarily

**Refresh Frequency Question:**
• Does customer data really need daily refresh?
• Customer master data likely changes infrequently
• Consider: Weekly refresh or triggered refresh on changes
• If changed to weekly: 86% CU reduction for this table

⚠️ IMPORTANT NOTES:
• ModifiedDate field EXISTS - incremental refresh is possible!
• If daily refresh not needed, reduce frequency first
• If daily refresh required, implement incremental refresh
• Pattern: Both ArMaster tables have same performance issue (shared root cause likely)

Dependencies:
• None (direct source system table)

Used By:
• df_Dim_CustomerList (primary use)
• [Other customer-related dimensions/facts]

Related Tables with Same Issue:
• ArMaster_Contact (same performance degradation pattern)

============================================================================
*/

let
    // ========================================================================
    // CUSTOMER MASTER EXTRACTION WITH STANDARDIZED NAMING
    // ========================================================================
    /*
    STRATEGY: Extract complete customer master data with standardized column names
    APPROACH: Direct query with column aliasing
    ISSUE: Recent 300-400% performance degradation - source/gateway investigation needed
    OPPORTUNITY: ModifiedDate field exists - incremental refresh possible
    */

    Source = Odbc.Query("dsn=EquipRDB64", "
        SELECT
            UPPER(TRIM(contact_code)) AS ContactID,
            Customer_No AS CustomerNumber,
            customer_no_char AS CustomerNumberChar,
            STATUS_CODE AS StatusCode,
            ACC_TYPE AS AccountType,
            TRADE_TYPE AS TradeType,
            DISC_TYPE AS DiscountType,
            TAX_EXEMPT_NO AS TaxExemptNumber,
            QUOTE_PURCH_ORD AS QuotePurchaseOrder,
            TERRITORY AS Territory,
            PRICE_LEVEL AS PriceLevel,
            PRICE_PERCENT AS PricePercent,
            LABOUR_RATE AS LabourRate,
            BILL_TO_ACC AS BillToAccount,
            NOTE AS CustomerNotes,
            capricorn_number AS CapricornNumber,
            alert AS CustomerAlert,
            Tax_Exempt_Type AS TaxExemptType,
            allow_trans_no_cc AS AllowTransactionNoCC,
            CreationDate AS CreatedDate,
            ModifiedDate AS ModifiedDate
        FROM ArMaster_Customer
    ")
in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - URGENT PERFORMANCE INVESTIGATION NEEDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 20 customer master fields included
• Standardized Naming: Applied consistent PascalCase conventions
• Query Folding: ✅ Confirmed - query pushes to source database
• Full Refresh: Daily at 7:30 AM

🚨 CRITICAL ISSUE - PERFORMANCE DEGRADATION:
• Refresh time increased 300-400% in last 2 weeks
• Historical: 1-2 minutes → Current: 6-8 minutes
• Same pattern as ArMaster_Contact (shared root cause likely)
• Query folding confirmed - issue is external

🔍 INVESTIGATION ROADMAP:

**Immediate (Today/Tomorrow):**
1. Check SQL Anywhere database performance during 7:30 AM window
2. Review data gateway health and logs
3. Test refresh at different time (e.g., 10 AM) to isolate timing issue
4. Check for competing processes at 7:30 AM

**Short-term (This Week):**
1. Analyze actual customer data change frequency
2. Determine if daily refresh is truly necessary
3. If daily not needed: Change to weekly (86% CU savings)
4. If daily needed: Implement incremental refresh using ModifiedDate

**Medium-term (Next 2 Weeks):**
1. Implement incremental refresh using ModifiedDate field
2. Expected improvement: 6-8 min → <1 minute for typical daily changes
3. Consolidate ArMaster_Contact and ArMaster_Customer into single dataflow if possible
4. Optimize refresh schedule to avoid 7:30 AM conflicts

⚡ OPTIMIZATION OPPORTUNITIES:

**Priority 1: Fix Performance Issue**
• Root cause: Source system, gateway, network, or timing conflict
• Impact: Affects multiple tables (ArMaster_Contact, ArMaster_Customer, possibly others)
• Action: Systematic investigation of each potential cause

**Priority 2: Reduce Refresh Frequency (If Possible)**
• Question: How often does customer master data actually change?
• If infrequent: Weekly refresh saves 86% CU consumption
• If rare: Triggered/on-demand refresh saves even more

**Priority 3: Implement Incremental Refresh**
• ModifiedDate field exists - incremental refresh is straightforward
• Add parameters: RangeStart, RangeEnd
• Filter: WHERE ModifiedDate >= RangeStart AND ModifiedDate < RangeEnd
• Expected result: 6-8 min → <1 min for typical daily changes

📊 EXPECTED OUTCOMES AFTER OPTIMIZATION:

**Scenario 1: Weekly Refresh (if business allows)**
• Current: 6-8 min × 7 days/week = 42-56 minutes/week
• After: 6-8 min × 1 day/week = 6-8 minutes/week
• Savings: 36-48 minutes/week (86% CU reduction)

**Scenario 2: Incremental Refresh (if daily required)**
• Current: 6-8 minutes daily
• After: <1 minute daily (load only changed records)
• Savings: 5-7 minutes/day × 7 days = 35-49 minutes/week (85%+ CU reduction)

**Scenario 3: Fix Root Cause + Incremental**
• Fix issue: 6-8 min → 1-2 min (back to historical)
• Add incremental: 1-2 min → <30 sec
• Combined savings: 5.5-7.5 minutes/day (95%+ CU reduction)

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM daily
• Data Completeness: Complete customer master record
• Column Standardization: Applied for consistency across all tables
• Incremental Ready: ModifiedDate field available

💡 BUSINESS DECISION NEEDED:
• Is daily customer master refresh required?
• Customer master data typically changes infrequently
• If not critical: Weekly refresh = immediate CU savings without code changes
• If critical: Implement incremental refresh = similar CU savings with code changes

============================================================================
*/
