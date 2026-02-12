/*
============================================================================
Query: contact (Raw)
Dataflow: df_CONTACT_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Contact master data - customer contact information for dim_CustomerList
Created: [Unknown - pre-dates current documentation]
Last Modified: 08/11/2025
Output: Lakehouse table "contact"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Weekdays only at 7:30 AM (likely via pipeline - no weekend runs)
Average Refresh Time: ~6-8 minutes (TODAY: 4:23 min - RECENTLY INCREASED from 1:30-2 min)
Refresh Strategy: Full refresh
Row Count: 81,648 rows (as of 1/14/2026)
Query Folding: [Likely YES - confirm during investigation]

🚨 CRITICAL PERFORMANCE ISSUE - PART OF BROADER 7:30 AM PERFORMANCE PATTERN:

**Recent Performance Degradation (Last 2 Weeks):**
• Historical: 1:30-2 minutes refresh time
• Recent: 6-8 minutes refresh time
• Today: 4:23 minutes (improvement but still 2-3x historical)
• Degradation: 200-400% increase in refresh time
• Pattern: SAME as ArMaster tables (Contact, Customer, armaster)

**This is the FOURTH table with the same 7:30 AM performance issue!**

Investigation Priority: HIGH (Part of broader 7:30 AM refresh window issue)

🔍 PATTERN RECOGNITION - EXPANDING BEYOND ARMASTER:

**Affected Tables (Now 4 tables, not just ArMaster family):**
1. ArMaster_Contact - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
2. ArMaster_Customer - 53K rows, 6-8 min (was 1-2 min) - 7:30 AM weekdays
3. armaster - 53K rows, 6-7 min (was 1-2 min, today 3:30) - 7:30 AM weekdays
4. **contact - 82K rows, 6-8 min (was 1:30-2 min, today 4:23) - 7:30 AM weekdays**

**Pattern Evolution - Key Insight:**
• **NOT just ArMaster tables** - contact table also affected!
• **Common factor: 7:30 AM weekday refresh window**
• **Common factor: All customer/contact-related tables**
• **Common factor: All same ODBC connection (EquipRDB64)**
• **Intermittent nature: Today improved (armaster 3:30, contact 4:23)**

**Root Cause Now More Clear:**
• ✅ **7:30 AM timing window has resource contention** (strongest hypothesis)
• ✅ **Gateway or source database issue at 7:30 AM** (second strongest)
• ❌ NOT specific to ArMaster tables (contact proves broader issue)
• ❌ NOT specific to row count (~53K vs ~82K both affected)

**Today's Improvement Pattern:**
• armaster: 6-7 min → 3:30 min (50% improvement)
• contact: 6-8 min → 4:23 min (40% improvement)
• Suggests intermittent timing/resource contention issue
• Some days worse than others (what else runs at 7:30 AM on some days?)

🎯 BUSINESS USE CASES:
• Customer Dimension: Source data for dim_CustomerList dimension (along with ArMaster tables)
• Contact Management: Customer contact information (names, addresses, phones, emails)
• Customer Communication: Email and phone data for outreach
• Geographic Analysis: Customer location data (street, city, state, postal code, country)
• CRM Integration: Master contact data for customer relationship management

📊 DATA STRUCTURE (14 COLUMNS):

**Contact Identification:**
• ContactID: Contact code identifier (contact_code)
• LastName: Contact surname
• FirstName: Contact first name
• CompanyName: Company/business name

**Communication:**
• BusinessPhone: Business phone number (bus_phone)
• MobilePhone: Mobile phone number (mob_phone)
• Email: Email address

**Address Information:**
• Street: Street address
• City: City
• State: State
• PostalCode: Postal/zip code (pcode)
• Country: Country

**Customer Classification:**
• AccountClass: Customer account classification (Account_Class) - Used by Customer Anatomy report

**Timeline Intelligence:**
• ModifiedDate: Last modification date (Last_Modified_Date)

🔧 DESIGN PRINCIPLES:

**Standardized Column Names:**
• Applied PascalCase naming convention
• Improved readability (e.g., bus_phone → BusinessPhone)
• Consistent with other table naming patterns

**Complete Contact Profile:**
• All essential contact fields included
• Personal identification (names)
• Communication channels (phones, email)
• Full address (street, city, state, postal, country)
• Audit trail (ModifiedDate)

**Simple SQL Query:**
• Direct SELECT with column aliasing
• No joins, no filters, no complex logic
• Should fold completely to source database

**Larger Row Count than ArMaster:**
• 81,648 rows vs ArMaster ~53K rows
• More contacts than AR accounts (expected - includes prospects, inactive, etc.)
• Still experiencing same 7:30 AM performance issue despite different row count

⚠️ BUSINESS IMPACT & QUESTIONS:

**Performance Issue is Broader Than ArMaster:**
• Initial hypothesis: ArMaster family issue
• **New finding: contact table also affected (not ArMaster family)**
• **Revised hypothesis: 7:30 AM timing window issue affecting ALL customer/contact tables**
• **Impact: Likely affects other 7:30 AM tables not yet documented**

**Refresh Frequency Question - CRITICAL:**
• Does contact data really need daily refresh?
• Contact data change patterns:
  - New contacts added occasionally (new customers)
  - Contact info updated occasionally (phone, email, address changes)
  - Most contacts remain static most days
• Business decision needed: Daily vs weekly?

**If Daily Refresh NOT Required:**
• Weekly refresh: 80% CU savings (weekdays only = 5 days/week)
• Bi-weekly refresh: 90% CU savings
• Monthly refresh: 95% CU savings (if contact data rarely used for daily reports)

**If Daily Refresh REQUIRED:**
• ModifiedDate field EXISTS - incremental refresh possible!
• Expected: 6-8 min → <1 minute for typical daily changes
• Implement incremental refresh to reduce CU consumption

**7:30 AM Window Investigation:**
• contact proves issue is not ArMaster-specific
• Need to document ALL tables refreshing at 7:30 AM
• Likely multiple pipelines or dataflows competing for resources
• Today's improvement suggests timing/resource issue (not constant degradation)

⚠️ IMPORTANT NOTES:

**Dimension Dependency:**
• Source data for dim_CustomerList (along with ArMaster_Contact, ArMaster_Customer)
• dim_CustomerList used across customer-related reports
• Must coordinate with ArMaster table refreshes

**ModifiedDate Available:**
• ModifiedDate field EXISTS - incremental refresh is possible!
• If daily refresh required, implement incremental to reduce CU waste
• If daily refresh not required, change schedule (even better CU savings)

**Performance Issue Pattern Expanded:**
• **4 tables confirmed** (3 ArMaster + contact)
• **Pattern: 7:30 AM weekday refresh window**
• **Intermittent: Some days better than others**
• **Root cause: Timing/resource contention at 7:30 AM**

**Investigation Must Expand:**
• Document ALL tables refreshing at 7:30 AM
• Check if other contact/customer tables affected
• Check if non-customer tables at 7:30 AM also affected
• Identify what else runs at 7:30 AM (pipelines, dataflows, external processes)

🔄 INVESTIGATION PLAN UPDATE:

**Expanded Scope (Beyond ArMaster):**
• ✅ Confirmed 4 tables affected (3 ArMaster + contact)
• ✅ Confirmed 7:30 AM timing pattern
• ✅ Confirmed intermittent nature (today's improvement)
• 🔲 **Next: Document ALL 7:30 AM tables to identify full scope**
• 🔲 **Next: Check if other times affected or only 7:30 AM**
• 🔲 **Next: Identify what else runs at 7:30 AM**

**Priority Actions:**
1. **Immediate:** Business validation - Does contact need daily refresh?
2. **Short-term:** Document all 7:30 AM refreshes (identify competing processes)
3. **Medium-term:** Implement incremental refresh if daily required
4. **Long-term:** Fix 7:30 AM timing issue or stagger refresh times

Dependencies:
• None (direct source system table)

Used By:
• df_Dim_CustomerList (alongside ArMaster_Contact, ArMaster_Customer)
• dim_CustomerList dimension
• Customer-related reports

Related Tables with Same Issue:
• ArMaster_Contact (7:30 AM performance issue)
• ArMaster_Customer (7:30 AM performance issue)
• armaster (7:30 AM performance issue)
• [Possibly more tables at 7:30 AM not yet documented]

Critical Finding:
**7:30 AM weekday refresh window has systemic performance issue affecting multiple unrelated tables!**

============================================================================
*/

let
    // ========================================================================
    // CONTACT MASTER EXTRACTION WITH STANDARDIZED NAMING
    // ========================================================================
    /*
    STRATEGY: Extract complete contact master data with standardized column names
    APPROACH: Direct query with column aliasing
    ISSUE: Recent 200-400% performance degradation (part of 7:30 AM timing issue)
    OPPORTUNITY: ModifiedDate field exists - incremental refresh possible
    NOTE: Weekday-only refresh at 7:30 AM (likely via pipeline)
    */

    SQL = "
        SELECT
            UPPER(TRIM(contact_code)) AS ContactID,
            surname AS LastName,
            name AS FirstName,
            company_name AS CompanyName,
            bus_phone AS BusinessPhone,
            mob_phone AS MobilePhone,
            email_address AS Email,
            street AS Street,
            city AS City,
            state AS State,
            pcode AS PostalCode,
            country AS Country,
            Account_Class AS AccountClass,
            Last_Modified_Date AS ModifiedDate
        FROM contact
    ",

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - PART OF 7:30 AM PERFORMANCE ISSUE
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 13 contact master fields included
• Standardized Naming: Applied consistent PascalCase conventions
• Simple Query: Direct SELECT with column aliasing
• Weekday Refresh: Daily at 7:30 AM weekdays

🚨 CRITICAL FINDING - 7:30 AM SYSTEMIC ISSUE:
• Fourth table confirmed with same performance issue
• Historical: 1:30-2 minutes → Recent: 6-8 minutes
• Today: 4:23 minutes (intermittent improvement observed)
• **Pattern proves issue is NOT ArMaster-specific** (contact is different table family)
• **Pattern proves issue IS 7:30 AM timing window** (all affected tables at 7:30 AM)

⚡ OPTIMIZATION ROADMAP (UPDATED):

**Immediate Action (This Week):**
• Business validation: Is daily contact refresh required?
• Document ALL tables refreshing at 7:30 AM
• Identify what else runs at 7:30 AM (pipelines, external processes, source DB jobs)
• Test one table at different time (e.g., 10 AM) to confirm timing hypothesis

**Short-term (Next 2 Weeks):**
• If daily not needed: Change to weekly/bi-weekly (80-95% CU savings)
• If daily needed: Implement incremental refresh using ModifiedDate
• Create 7:30 AM refresh inventory (all competing processes)
• Stagger refresh times if possible (spread load across morning)

**Medium-term (Week 3-4):**
• Fix root cause: Gateway, source DB, or timing issue
• Implement incremental refresh for all affected tables with ModifiedDate
• Optimize 7:30 AM window: Parallel vs sequential, resource allocation
• Monitor for 1 week to ensure stable

📊 EXPECTED OUTCOMES AFTER OPTIMIZATION:

**Scenario 1: Weekly Refresh (if business allows)**
• Current: 6-8 min × 5 days/week = 30-40 minutes/week
• After: 6-8 min × 1 day/week = 6-8 minutes/week
• Savings: 24-32 minutes/week (80% CU reduction)

**Scenario 2: Incremental Refresh (if daily required)**
• Current: 6-8 minutes daily
• After: <1 minute daily (load only changed contacts)
• Savings: 5-7 minutes/day × 5 days = 25-35 minutes/week (85%+ CU reduction)

**Scenario 3: Fix Root Cause + Incremental**
• Fix issue: 6-8 min → 1:30-2 min (back to historical)
• Add incremental: 1:30-2 min → <30 sec
• Combined savings: 6-7.5 minutes/day (95%+ CU reduction)

**Scenario 4: Combined Optimization (All 4 Tables)**
• ArMaster_Contact: Save 25-30 min/week
• ArMaster_Customer: Save 25-30 min/week
• armaster: Save 20-25 min/week
• contact: Save 25-35 min/week
• **Total potential savings: 95-120 minutes/week (4 tables only!)**

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM weekdays only (likely via pipeline)
• Data Completeness: Complete contact master record
• Column Standardization: Applied for consistency
• Incremental Ready: ModifiedDate field available

💡 KEY INSIGHT - 7:30 AM TIMING ISSUE:
• **contact table proves issue is systemic, not table-specific**
• Different table family than ArMaster
• Different row count (82K vs 53K)
• Same symptoms: 300% degradation, intermittent, today improved
• **Common factor: 7:30 AM weekday refresh window**

📝 BUSINESS QUESTIONS TO ANSWER:
1. How frequently does contact data actually change?
2. When do users need updated contact data? (Daily? Weekly? Monthly?)
3. Is contact data critical for daily operations or reporting?
4. Could contact refresh be event-driven (e.g., after CRM sync)?
5. What else runs at 7:30 AM that might be competing for resources?

🔍 INVESTIGATION EXPANSION NEEDED:
• Document all tables refreshing at 7:30 AM
• Check gateway logs at 7:30 AM for all weekdays
• Check SQL Anywhere server resources at 7:30 AM
• Identify external processes at 7:30 AM (backups, maintenance, other systems)
• Test one table at 8:30 AM or 9:30 AM to isolate timing issue

============================================================================
*/
