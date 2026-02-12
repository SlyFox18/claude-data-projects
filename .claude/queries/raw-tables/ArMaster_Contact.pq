/*
============================================================================
Query: ArMaster_Contact (Raw)
Dataflow: df_ArMaster_Contact_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Accounts Receivable Master Contact data - customer contact information
Created: [Unknown - pre-dates current documentation]
Last Modified: 10/21/2025
Output: Lakehouse table "ArMaster_Contact"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Once daily (7:30 AM)
Average Refresh Time: ~6 minutes
Refresh Strategy: Full refresh
Row Count: 53,470 rows (as of 1/14/2026)

⚠️ PERFORMANCE CONCERN:
• 6-minute refresh for ~53K rows seems HIGH
• Potential optimization opportunity - investigate why this takes so long
• Consider: Does this really need daily refresh? How frequently does contact data change?
• Action item: Analyze if incremental refresh or less frequent refresh is acceptable

🎯 BUSINESS USE CASES:
• Customer Dimension: Source data for customer contact classification
• AR Analytics: Account receivable contact segmentation
• Customer Relationship: Contact class analysis and reporting
• [Add other use cases as identified]

📊 DATA STRUCTURE (2 COLUMNS - MINIMAL):

**Contact Information:**
• ContactID: Contact code identifier (contact_code)
• ContactClass: Contact classification (contact_class)

🔧 DESIGN PRINCIPLES:

**Standardized Column Names:**
• Source field "contact_code" → "ContactID" (standardized naming)
• Source field "contact_class" → "ContactClass" (standardized naming)

**Simple Query:**
• Minimal transformation - just column renaming
• Direct SELECT with column aliasing
• No joins, filters, or complex logic

**Full Refresh Strategy:**
• Contact data likely changes infrequently
• Full refresh ensures accuracy
• Small row count (53K) should refresh quickly

⚠️ OPTIMIZATION OPPORTUNITIES:

**Performance Investigation Needed:**
• 6 minutes for 53K rows is slower than expected
• Typical causes:
  - Network latency to source database
  - Source table not indexed properly
  - ODBC driver performance issues
  - Competing queries during refresh time
  - No query folding (though this simple query should fold)

**Refresh Frequency Analysis:**
• Question: How often does contact data actually change?
• If contact data is relatively static, consider:
  - Weekly refresh instead of daily
  - Bi-weekly refresh
  - Triggered refresh on data change notification

**Potential Actions:**
1. Check source table indexes on contact_code
2. Verify query folding with diagnostics
3. Test refresh at different times of day
4. Analyze actual data change frequency
5. Consider incremental refresh if ModifiedDate field exists

Dependencies:
• None (direct source system table)

Used By:
• df_Dim_CustomerList (likely)
• [Other customer-related dimensions/facts]

============================================================================
*/

let
    // ========================================================================
    // SIMPLE CONTACT EXTRACTION WITH STANDARDIZED NAMING
    // ========================================================================
    /*
    STRATEGY: Extract contact master data with standardized column names
    APPROACH: Minimal transformation - column aliasing only
    CONCERN: 6-minute refresh for 53K rows needs investigation
    */

    SQL = "
        SELECT
            UPPER(TRIM(contact_code)) AS ContactID,
            contact_class AS ContactClass
        FROM ArMaster_Contact
    ",

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: OPERATIONAL - OPTIMIZATION NEEDED
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Minimal Column Set: Only 2 columns extracted
• Standardized Naming: contact_code → ContactID, contact_class → ContactClass
• Simple Query: Direct SELECT with column aliasing
• Full Refresh: Daily refresh at 7:30 AM

⚡ PERFORMANCE CONCERNS:
• 6 minutes for 53K rows is SLOW
• Expected refresh time: <30 seconds for this row count and query simplicity
• 10-12x slower than expected - requires investigation

🔍 SUGGESTED INVESTIGATION STEPS:

1. **Verify Query Folding:**
   - Check if query is being pushed to source database
   - Should see single SQL query in source system logs
   - This simple query should fold completely

2. **Check Source Table:**
   - Verify indexes exist on contact_code
   - Check if table has performance issues in source system
   - Test direct query in SQL Anywhere

3. **Network Analysis:**
   - Test ODBC connection speed
   - Check for network latency during refresh window
   - Compare refresh times at different times of day

4. **Data Change Analysis:**
   - How often does contact data actually change?
   - Is daily refresh necessary?
   - Could this be weekly or triggered refresh?

5. **Incremental Refresh Potential:**
   - Check if ArMaster_Contact has ModifiedDate field
   - Could implement incremental refresh if available
   - Even small dataset benefits from incremental approach

📝 OPTIMIZATION RECOMMENDATIONS:

**Short-term:**
- [ ] Investigate 6-minute refresh time root cause
- [ ] Test refresh at different times to rule out timing conflicts
- [ ] Verify query folding with diagnostics

**Medium-term:**
- [ ] Analyze actual data change frequency
- [ ] Consider reducing refresh frequency if data is static
- [ ] Check if source table needs indexing improvements

**Long-term:**
- [ ] Implement incremental refresh if ModifiedDate available
- [ ] Consider event-driven refresh instead of scheduled
- [ ] Document expected vs actual refresh performance

🚀 PRODUCTION CHARACTERISTICS:
• Refresh Schedule: 7:30 AM daily
• Data Completeness: Minimal fields - only ID and Class
• Column Standardization: Applied for consistency
• Simplicity: Straightforward query with minimal logic

💡 BUSINESS IMPACT:
• If contact data rarely changes, daily refresh may be unnecessary
• CU savings opportunity: Reduce from daily to weekly = 86% CU reduction
• Example: If data changes weekly, 6 daily refreshes are wasted CU consumption

============================================================================
*/
