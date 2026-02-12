/*
============================================================================
Query: armaster (Raw)
Dataflow: df_armaster_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Accounts Receivable Master - AR balances, aging, and payment history
Created: [Unknown - pre-dates current documentation]
Last Modified: 12/23/2025
Output: Lakehouse table "armaster"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Weekdays only at 7:30 AM (via pipeline - no weekend runs)
Average Refresh Time: ~6-7 minutes (TODAY: 3:30 min - RECENTLY INCREASED from 1-2 min)
Refresh Strategy: Full refresh
Row Count: 53,470 rows (as of 1/14/2026)
Query Folding: [Likely YES - confirm during investigation]

🚨 CRITICAL PERFORMANCE ISSUE - SAME PATTERN AS OTHER ARMASTER TABLES:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 1-2 minutes refresh time
• Recent: 6-7 minutes refresh time
• Today: 3:30 minutes (improvement but still 2x historical)
• Degradation: 200-350% increase in refresh time
• Pattern: SAME as ArMaster_Contact and ArMaster_Customer

**This is the THIRD ArMaster table with the same issue!**

Investigation Priority: HIGH (Part of broader ArMaster performance issue)

🔍 PATTERN RECOGNITION - ALL ARMASTER TABLES AFFECTED:

**Affected Tables (All ArMaster family):**
1. ArMaster_Contact - 53K rows, 6-8 min (was 1-2 min)
2. ArMaster_Customer - 53K rows, 6-8 min (was 1-2 min)
3. armaster - 53K rows, 6-7 min (was 1-2 min, today 3:30 min)

**Common Characteristics:**
• All ArMaster family tables
• All ~53K rows (same row count!)
• All at 7:30 AM weekday refresh
• All via same pipeline
• All same ODBC connection (EquipRDB64)
• All same 2-week timeframe for degradation
• Today one table showed improvement (3:30 vs 6-7) - may indicate intermittent issue

**Root Cause is Definitely:**
• SQL Anywhere database issue with ArMaster tables specifically
• Data gateway issue affecting all ODBC connections
• Source system timing conflict at 7:30 AM
• Network issue during 7:30 AM window on weekdays

**Today's Improvement (3:30 min) Suggests:**
• Intermittent issue (not constant degradation)
• Timing-sensitive problem (7:30 AM window may have conflicts some days)
• Resource contention that varies day-to-day
• Possible: Other processes competing for resources on some days but not others

🎯 BUSINESS USE CASES:
• AR Reporting: Account receivable balances and aging analysis
• Credit Management: Credit limit tracking and utilization
• Collection Management: Aging buckets (30/60/90/120 days)
• Payment Analysis: Payment history and patterns
• Customer Financial Health: YTD and LYTD credits/debits tracking
• Cash Flow Forecasting: Current balances and aging trends
• Risk Assessment: Overdue accounts and credit exposure

📊 DATA STRUCTURE (20 COLUMNS):

**Account Identification:**
• AccountNumber: AR account number (ACC_NO)
• ContactID: Contact code reference (contact_code)

**Credit Management:**
• CreditLimit: Customer credit limit (CREDIT_LIMIT)
• AccountBalance: Current account balance (CURRENT_VALUE)
• CreditTerm: Credit terms (CREDIT_TERM)

**Aging Buckets:**
• Aging30: 0-30 days aging amount (DAYS_30)
• Aging60: 31-60 days aging amount (DAYS_60)
• Aging90: 61-90 days aging amount (DAYS_90)
• Aging120: 91-120+ days aging amount (DAYS_120)

**Year-to-Date Activity:**
• YTDCredits: Year-to-date credits (YTD_CREDITS)
• YTDDebits: Year-to-date debits (YTD_DEBITS)
• LYTDCredits: Last year-to-date credits (LYTD_CREDITS)
• LYTDDebits: Last year-to-date debits (LYTD_DEBITS)

**Payment History:**
• LastPaymentDate: Date of last payment (DATE_LAST_PAY)
• LastPaymentAmount: Amount of last payment (LAST_AMOUNT_PAY)
• PaymentMethod: Payment method (Pay_Method)

**Account Management:**
• Type: Account type classification (user_field3)
• StatementType: Statement type classification (STATEMENT_TYPE)

**Timeline Intelligence:**
• CreationDate: Account creation date (Creation_Date)
• ModifiedDate: Last modification date (Last_Modified_Date)

🔧 DESIGN PRINCIPLES:

**Standardized Column Names:**
• Applied PascalCase naming convention
• Improved readability (e.g., DAYS_30 → Aging30)
• Consistent with other table naming patterns

**Complete AR Profile:**
• All account balance and aging information
• Payment history included
• YTD and LYTD activity for trend analysis
• Audit trail with creation and modification dates

**Pipeline-Driven Refresh:**
• Refreshes via pipeline (not standalone dataflow)
• Weekdays only - no weekend refresh
• 7:30 AM execution window
• Pipeline orchestrates multiple ArMaster tables together

⚠️ BUSINESS IMPACT & QUESTIONS:

**Refresh Frequency Question - CRITICAL:**
• Does AR data really need daily refresh?
• Typical AR data change patterns:
  - Balances update as invoices are paid (throughout day)
  - Aging buckets recalculate daily
  - Payment history updates as payments received
• Business decision needed: Daily vs less frequent?

**If Daily Refresh NOT Required:**
• Weekly refresh: 80% CU savings (weekdays only = 5 days/week)
• Bi-weekly refresh: 90% CU savings
• End-of-month refresh: 95% CU savings

**If Daily Refresh REQUIRED:**
• ModifiedDate field EXISTS - incremental refresh possible!
• Expected: 6-7 min → <1 minute for typical daily changes
• Implement incremental refresh to reduce CU consumption

**Pipeline Consideration:**
• Pipeline likely refreshes multiple ArMaster tables together
• All tables likely experiencing same performance issue
• Optimization should consider entire pipeline, not individual tables
• Stagger refresh times within pipeline if possible

⚠️ IMPORTANT NOTES:
• Part of broader ArMaster table performance issue (3 tables confirmed)
• ModifiedDate field EXISTS - incremental refresh is possible!
• Pipeline-driven refresh (weekdays only)
• Today's improvement (3:30 vs 6-7) suggests intermittent timing/resource issue
• All ArMaster tables should be investigated together (shared root cause)

🔄 INVESTIGATION PLAN (For All ArMaster Tables):

**Phase 1: Confirm Pattern (DONE)**
• ✅ Identified 3 ArMaster tables with same issue
• ✅ Confirmed timing (7:30 AM weekdays)
• ✅ Confirmed row counts (~53K each)
• ✅ Noted intermittent nature (today's improvement)

**Phase 2: Source System Investigation (NEXT)**
• Check SQL Anywhere ArMaster table indexes
• Review database statistics and query plans
• Check for blocking queries or locks at 7:30 AM
• Verify no database maintenance running at 7:30 AM
• Test direct query performance in SQL Anywhere

**Phase 3: Pipeline & Gateway Investigation**
• Review pipeline execution logs
• Check data gateway health during 7:30 AM window
• Verify no other processes competing for gateway
• Test refresh at different time (e.g., 10 AM) to isolate timing

**Phase 4: Network & Infrastructure**
• Check network latency during 7:30 AM window
• Verify ODBC driver version and configuration
• Review gateway machine resources (CPU, Memory, Network)
• Check for any infrastructure changes in last 2 weeks

**Phase 5: Business Requirement Validation**
• Validate daily refresh requirement with business
• Analyze actual data change frequency
• Determine if less frequent refresh acceptable
• If daily required, plan incremental refresh implementation

Dependencies:
• None (direct source system table)

Used By:
• AR reporting and analytics
• Customer financial health dashboards
• Collection management reports
• [Specific dimension/fact tables to be documented]

Related Tables with Same Issue:
• ArMaster_Contact (same performance degradation)
• ArMaster_Customer (same performance degradation)
• [Possibly other ArMaster family tables in pipeline]

============================================================================
*/

let
    // ========================================================================
    // AR MASTER EXTRACTION WITH STANDARDIZED NAMING
    // ========================================================================
    /*
    STRATEGY: Extract complete AR balance and aging data with standardized column names
    APPROACH: Direct query with column aliasing
    ISSUE: Recent 200-350% performance degradation (part of ArMaster family issue)
    OPPORTUNITY: ModifiedDate field exists - incremental refresh possible
    NOTE: Weekday-only refresh via pipeline (no weekends)
    */

    SQL = "
        SELECT
            TRIM(ACC_NO) AS AccountNumber,
            UPPER(TRIM(contact_code)) AS ContactID,
            CREDIT_LIMIT AS CreditLimit,
            CURRENT_VALUE AS AccountBalance,
            DAYS_30 AS Aging30,
            DAYS_60 AS Aging60,
            DAYS_90 AS Aging90,
            DAYS_120 AS Aging120,
            YTD_CREDITS AS YTDCredits,
            YTD_DEBITS AS YTDDebits,
            LYTD_CREDITS AS LYTDCredits,
            LYTD_DEBITS AS LYTDDebits,
            DATE_LAST_PAY AS LastPaymentDate,
            LAST_AMOUNT_PAY AS LastPaymentAmount,
            user_field3 AS Type,
            STATEMENT_TYPE AS StatementType,
            CREDIT_TERM AS CreditTerm,
            Pay_Method AS PaymentMethod,
            Creation_Date AS CreationDate,
            Last_Modified_Date AS ModifiedDate
        FROM armaster
    ",

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - PART OF ARMASTER PERFORMANCE ISSUE
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 20 AR balance and aging fields included
• Standardized Naming: Applied consistent PascalCase conventions
• Pipeline-Driven: Refreshes via pipeline, weekdays only (no weekends)
• Full Refresh: Daily at 7:30 AM weekdays

🚨 CRITICAL FINDING - ARMASTER FAMILY PATTERN:
• Third ArMaster table confirmed with same performance issue
• Historical: 1-2 minutes → Recent: 6-7 minutes
• Today: 3:30 minutes (intermittent improvement observed)
• Suggests timing/resource contention issue (not constant degradation)

⚡ OPTIMIZATION ROADMAP:

**Immediate Action:**
• Document all ArMaster tables in pipeline
• Create consolidated investigation plan
• Test one ArMaster table at different time (10 AM) to isolate timing issue

**Short-term (This Week):**
• Business validation: Is daily AR refresh required?
• If not: Change to weekly/bi-weekly/monthly (80-95% CU savings)
• If yes: Plan incremental refresh implementation

**Medium-term (Next 2 Weeks):**
• Implement incremental refresh using ModifiedDate field
• Expected: 6-7 min → <1 minute for typical daily changes
• Optimize pipeline: Stagger ArMaster table refreshes if possible
• Fix root cause: Gateway, source system, or timing issue

📊 EXPECTED OUTCOMES AFTER OPTIMIZATION:

**Scenario 1: Weekly Refresh (if business allows)**
• Current: 6-7 min × 5 days/week = 30-35 minutes/week
• After: 6-7 min × 1 day/week = 6-7 minutes/week
• Savings: 24-28 minutes/week (80% CU reduction)

**Scenario 2: Incremental Refresh (if daily required)**
• Current: 6-7 minutes daily
• After: <1 minute daily (load only changed records)
• Savings: 5-6 minutes/day × 5 days = 25-30 minutes/week (85%+ CU reduction)

**Scenario 3: Fix Root Cause + Incremental**
• Fix issue: 6-7 min → 1-2 min (back to historical)
• Add incremental: 1-2 min → <30 sec
• Combined savings: 6-6.5 minutes/day (95%+ CU reduction)

**Scenario 4: Monthly Refresh (if AR reporting is monthly)**
• Current: 6-7 min × 20 days/month = 120-140 minutes/month
• After: 6-7 min × 1 day/month = 6-7 minutes/month
• Savings: 114-133 minutes/month (95% CU reduction)

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM weekdays only (via pipeline)
• Data Completeness: Complete AR balance, aging, and payment history
• Column Standardization: Applied for consistency
• Incremental Ready: ModifiedDate field available

💡 KEY INSIGHT - TODAY'S IMPROVEMENT:
• Today's 3:30 min (vs usual 6-7 min) suggests issue is intermittent
• Not a constant degradation - timing or resource contention issue
• May be related to what else runs at 7:30 AM on specific days
• Investigation should focus on identifying competing processes/resources

📝 BUSINESS QUESTIONS TO ANSWER:
1. How frequently does AR data actually change?
2. When do users need updated AR data? (Daily? Weekly? Monthly?)
3. Is end-of-day AR data sufficient, or needed multiple times per day?
4. Could AR refresh be event-driven (e.g., after batch payment processing)?
5. Is 7:30 AM the right time, or could it be moved to off-peak?

============================================================================
*/
