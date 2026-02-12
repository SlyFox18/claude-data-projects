/*
============================================================================
DIM_UNIQUECUSTOMERS - HIGH-VALUE CUSTOMER TRACKING DIMENSION
============================================================================

📋 METADATA:
Table Name: dim_UniqueCustomers
Dataflow: df_Dim_UniqueCustomers
Purpose: Master reference table for tracking specific high-value customers with complex identification rules
Grain: One row per unique customer definition
Last Modified: 11/04/2025

🔄 REFRESH CHARACTERISTICS:
Row Count: 11 customers
Avg Refresh Time: ~1:30 minutes
Refresh Schedule: Daily weekdays (~7:45 AM pipeline - after raw data refresh)
Refresh Strategy: Full refresh (static reference data with manual updates)
Source: In-memory table (manually maintained)

📊 DIMENSION TYPE: Type 1 (Overwrite) with Soft Deletes
Changes: Manual additions/updates only
History: Preserved via IsActive flag (never delete rows)
Updates: Overwrite existing records, use IsActive=false to hide

🎯 BUSINESS CONTEXT:

**Purpose:**
Tracks sales, margins, and performance for specific high-value customers across
dual-fact-table architecture where customer transactions come from two different
source systems (InTrans and Invoice) with varying identification methods.

**Why Multiple Identification Methods:**
- Some customers identified by location (TradeType in ArMaster)
- Some customers identified by text patterns in order numbers
- Some customers identified by specific customer numbers
- Different source systems require different matching strategies

**Business Value:**
- YTD vs PYTD comparisons for key customers
- Location-based customer analysis (Pearsall, Dell City, Tornillo)
- Individual customer performance tracking
- Flexible identification supports diverse business patterns

📊 DATA STRUCTURE (7 Columns):

**Primary Key:**
• CustomerKey: Surrogate key (1-11, sequential integers)

**Descriptive Attributes:**
• CustomerName: Display name shown in reports (e.g., "Pearsall", "Manuel/MR Tractor")
• DataSource: Which source system contains transactions ("InTrans" or "Invoice")
• IdentificationMethod: How customer is identified in source data
• IdentificationRule: Business rule description for identification

**Management Attributes:**
• IsActive: Boolean flag for soft deletes (false hides without breaking history)
• CreatedDate: Audit trail - when customer was added to dimension

🔧 IDENTIFICATION METHODS (5 Types):

**Method 1: TradeType**
- Uses: ArMaster_Customer.TradeType field
- Example: TradeType = "D" identifies all Pearsall customers
- Fact Table: Fact_InTrans_UniqueCustomers
- Customers: Pearsall (TradeType "D")

**Method 2: TradeType + Branch**
- Uses: ArMaster_Customer.TradeType + Branch location
- Example: TradeType = "T" + Branch = "2" identifies Tornillo
- Purpose: Splits trade types by location
- Fact Table: Fact_InTrans_UniqueCustomers
- Customers: Dell City (TradeType "T" + Branch <> "2"), Tornillo (TradeType "T" + Branch = "2")

**Method 3: CustomerOrderNumber**
- Uses: Text search in Invoice.CustomerOrderNumber field
- Example: Contains "MANUEL" or "MR TRACTOR"
- Matching: Case-insensitive using Text.Upper()
- Fact Table: Fact_Invoice_UniqueCustomers
- Customers: Manuel/MR Tractor, Danny G, Oscar

**Method 4: CustomerOrderNumber + Branch**
- Uses: Text search in CustomerOrderNumber + specific branch restriction
- Example: Contains "JIM" AND Branch = "94"
- Purpose: Prevent matching orders from wrong locations
- Fact Table: Fact_Invoice_UniqueCustomers
- Customers: Jim Justice (Branch 94), David Arizmendi (Branch 92)

**Method 5: CustomerNo**
- Uses: Direct match on InTrans.CustomerNo
- Example: CustomerNo = "36192" for Dallyn Clements
- Purpose: Exact customer number matching
- Fact Table: Fact_InTrans_UniqueCustomers
- Customers: Dallyn Clements (36192), Benny Gray (38845), Owen Bros. (61055)

🔗 RELATIONSHIPS:

**Fact Table Relationships:**

1. **Fact_InTrans_UniqueCustomers** (Customers 1-3, 7-9)
   - Used for: Location-based customers (Pearsall, Dell City, Tornillo)
   - Used for: Individual InTrans customers (Dallyn, Benny, Owen)
   - Identification: ArMaster TradeType lookup or direct CustomerNo match
   - Relationship: Fact_InTrans_UniqueCustomers[CustomerKey] → dim_UniqueCustomers[CustomerKey]

2. **Fact_Invoice_UniqueCustomers** (Customers 4-6, 10-11)
   - Used for: Invoice-based text pattern matching
   - Used for: Manuel, Jim, David, Danny G, Oscar
   - Identification: Text.Contains() on CustomerOrderNumber
   - Relationship: Fact_Invoice_UniqueCustomers[CustomerKey] → dim_UniqueCustomers[CustomerKey]

Relationship Pattern:
• Cardinality: Many-to-One (many transactions to one customer)
• Cross-filter Direction: Single (dimension filters facts)

📋 CURRENT CUSTOMERS (11 Total):

**Location-Based Customers (InTrans - TradeType):**
1. **Pearsall** - TradeType "D"
2. **Dell City** - TradeType "T" + Branch ≠ "2"
3. **Tornillo** - TradeType "T" + Branch = "2"

**Invoice Text-Pattern Customers:**
4. **Manuel/MR Tractor** - Contains "MANUEL" or "MR TRACTOR"
5. **Jim Justice** - Contains "JIM" + Branch = "94"
6. **David Arizmendi** - Contains "DAVID" + Branch = "92"
10. **Danny G** - Starts with "*DANNY G"
11. **Oscar** - Starts with "*OSCAR"

**Individual InTrans Customers (CustomerNo):**
7. **Dallyn Clements** - CustomerNo = "36192"
8. **Benny Gray** - CustomerNo = "38845"
9. **Owen Bros.** - CustomerNo = "61055"

📋 ADDING NEW CUSTOMERS - STEP-BY-STEP GUIDE:

**Step 1: Determine Identification Method**
Ask: How is this customer identified in the source system?
- By TradeType? → Add to InTrans section (Method 1 or 2)
- By CustomerOrderNumber text? → Add to Invoice section (Method 3 or 4)
- By specific CustomerNo? → Add to InTrans individual section (Method 5)

**Step 2: Assign Next CustomerKey**
- Current highest key: 11
- New customers: Use 12, 13, 14, etc. (sequential)
- **NEVER reuse deleted customer keys** (breaks historical data)

**Step 3: Add Row to CustomersTable**
Format: {Key, "Name", "Source", "Method", "Rule", true, #date(YYYY, M, D)}

Examples:
```powerquery
// New Invoice customer (text pattern)
{12, "New Customer", "Invoice", "CustomerOrderNumber", "Contains NEWCUST", true, #date(2025, 12, 19)}

// New InTrans customer (CustomerNo)
{12, "Company ABC", "InTrans", "CustomerNo", "12345", true, #date(2025, 12, 19)}

// New Invoice customer with branch restriction
{12, "Jane Doe", "Invoice", "CustomerOrderNumber + Branch", "Contains JANE and Branch = 95", true, #date(2025, 12, 19)}
```

**Step 4: Update Corresponding Fact Table**
- If DataSource = "InTrans" → Update Fact_InTrans_UniqueCustomers query
- If DataSource = "Invoice" → Update Fact_Invoice_UniqueCustomers query
- Add matching logic to AddCustomerKey step (see fact table documentation)

**Step 5: Refresh and Validate**
- Refresh this dimension table
- Refresh the corresponding fact table
- Check transaction counts and sales totals match expectations
- Verify relationships in model view

📋 MAINTENANCE BEST PRACTICES:

**Adding Customers:**
- Increment CustomerKey sequentially (never skip numbers)
- Update corresponding fact table logic for customer identification
- Use today's date for CreatedDate when adding new customers
- Keep IdentificationRule descriptions clear and detailed
- Document any special business rules or exceptions in comments

**Hiding Customers:**
- Set IsActive to false to hide customers (don't delete rows - breaks history)
- Historical transactions remain linked via CustomerKey
- Reports can filter on IsActive = TRUE to show only current customers

**Data Integrity:**
- Never delete customer rows (orphans historical fact records)
- Never reuse CustomerKey values (corrupts historical analysis)
- Always test fact table logic after adding new customers
- Verify transaction counts before/after changes

📋 COMMON SCENARIOS:

**Scenario 1: Add customer identified by CustomerOrderNumber text**
```powerquery
{12, "John Doe", "Invoice", "CustomerOrderNumber", "Contains JOHN", true, #date(2025, 12, 19)}
```
Then update Fact_Invoice_UniqueCustomers with Text.Contains logic.

**Scenario 2: Add customer only in specific branch**
```powerquery
{12, "Jane Doe", "Invoice", "CustomerOrderNumber + Branch", "Contains JANE and Branch = 95", true, #date(2025, 12, 19)}
```
Then update Fact_Invoice_UniqueCustomers with combined text + branch logic.

**Scenario 3: Add customer by specific CustomerNo from InTrans**
```powerquery
{12, "Company ABC", "InTrans", "CustomerNo", "12345", true, #date(2025, 12, 19)}
```
Then update Fact_InTrans_UniqueCustomers with CustomerNo list logic.

**Scenario 4: Temporarily hide a customer from reporting**
Change: IsActive from true to false
Result: Customer hidden in reports but historical relationships preserved

📋 IMPORTANT NOTES:

**Daily Refresh Strategy:**
- Unlike most reference dimensions (monthly), this refreshes DAILY
- Reason: Must stay in sync with fact table refreshes for accurate reporting
- Scheduled: ~7:45 AM (immediately after raw data pipeline completes)
- Dependencies: Must refresh before Fact_InTrans_UniqueCustomers and Fact_Invoice_UniqueCustomers

**Dual-Fact-Table Architecture:**
- Single dimension serves TWO different fact tables
- Each fact table has different customer identification logic
- CustomerKey is the common link between dimension and facts
- Design enables unified reporting across different source systems

**Text Matching Notes:**
- All text matching is case-insensitive (Text.Upper() in fact tables)
- Contains "MANUEL" matches: "manuel", "MANUEL", "Manuel/Order", etc.
- Asterisk in "*DANNY G" is literal character, not wildcard
- Branch codes are text type (e.g., "94", "92", "2")

**Performance:**
- ~1:30 for 11 rows is normal (simple in-memory table)
- No complex transformations or source queries
- Fast refresh supports daily schedule

============================================================================
*/

let
    /*
    ================================================================================================
    DIMENSION: dim_UniqueCustomers
    ================================================================================================

    PURPOSE:
    Master reference table defining unique customers for parts sales reporting. This dimension
    supports a dual-fact-table architecture where customer transactions come from two different
    source systems (InTrans and Invoice) with varying identification methods.

    BUSINESS CONTEXT:
    - Tracks sales, margins, and performance for specific high-value customers
    - Enables YTD vs PYTD comparisons across different customer identification patterns
    - Supports both location-based customers (Pearsall, Dell City, Tornillo) and individual
      customers (Manuel, Jim, David, Danny G, Oscar, etc.)

    IDENTIFICATION METHODS:
    1. TradeType: Uses ArMaster_Customer.TradeType to identify location-based customers
       - Example: TradeType = "D" identifies all Pearsall customers

    2. TradeType + Branch: Splits customers by both trade type and branch location
       - Example: TradeType = "T" + Branch = "2" identifies Tornillo

    3. CustomerOrderNumber: Text search in Invoice.CustomerOrderNumber field
       - Example: Contains "MANUEL" or "MR TRACTOR"
       - Case-insensitive matching using Text.Upper() in fact table logic

    4. CustomerOrderNumber + Branch: Text search with specific branch restriction
       - Example: Contains "JIM" AND Branch = "94"

    5. CustomerNo: Direct match on InTrans.CustomerNo for individual customers
       - Example: CustomerNo = "36192" for Dallyn Clements

    FACT TABLE RELATIONSHIPS:
    - Fact_InTrans_UniqueCustomers: Links via CustomerKey
      Used for: Customers 1-3 (Pearsall, Dell City, Tornillo), 7-9 (individual InTrans customers)

    - Fact_Invoice_UniqueCustomers: Links via CustomerKey
      Used for: Customers 4-6, 10-11 (Invoice-based identification)

    COLUMN DEFINITIONS:
    - CustomerKey: Unique integer identifier (surrogate key) - used for fact table relationships
    - CustomerName: Display name shown in reports
    - DataSource: Which source system contains the transactions (InTrans or Invoice)
    - IdentificationMethod: How the customer is identified in source data
    - IdentificationRule: Business rule description for identification
    - IsActive: Boolean flag for soft deletes (set to false to hide without breaking history)
    - CreatedDate: When the customer was added to the dimension (for audit trail)

    ADDING NEW CUSTOMERS - STEP BY STEP:

    Step 1: Determine identification method
    --------
    Ask: How is this customer identified in the source system?
    - If by TradeType → Add to InTrans section
    - If by CustomerOrderNumber → Add to Invoice section
    - If by specific CustomerNo → Add to InTrans individual section

    Step 2: Assign next CustomerKey
    --------
    - Current highest key is 11
    - New customers should use 12, 13, 14, etc. (sequential)
    - NEVER reuse deleted customer keys (breaks historical data)

    Step 3: Add row to CustomersTable
    --------
    Format: {Key, "Name", "Source", "Method", "Rule", true, #date(YYYY, M, D)}
    Example: {12, "New Customer", "Invoice", "CustomerOrderNumber", "Contains NEWCUST", true, #date(2025, 12, 19)}

    Step 4: Update corresponding fact table
    --------
    - If DataSource = "InTrans" → Update Fact_InTrans_UniqueCustomers query
    - If DataSource = "Invoice" → Update Fact_Invoice_UniqueCustomers query
    - Add matching logic to AddCustomerKey step (see fact table documentation)

    Step 5: Refresh and validate
    --------
    - Refresh this dimension table
    - Refresh the corresponding fact table
    - Check transaction counts and sales totals match expectations
    - Verify relationships in model view

    MAINTENANCE NOTES:
    - When adding customers, increment CustomerKey sequentially (never skip numbers)
    - Update corresponding fact table logic for customer identification
    - Use today's date for CreatedDate when adding new customers
    - Set IsActive to false to hide customers (don't delete rows - breaks history)
    - Keep IdentificationRule descriptions clear and detailed
    - Document any special business rules or exceptions in comments

    COMMON SCENARIOS:

    Scenario: Add customer identified by CustomerOrderNumber containing specific text
    Solution: Add to Invoice section, use Text.Contains() in fact table
    Example: {12, "John Doe", "Invoice", "CustomerOrderNumber", "Contains JOHN", true, #date(2025, 12, 19)}

    Scenario: Add customer only in specific branch
    Solution: Add with "CustomerOrderNumber + Branch" method, include branch in rule
    Example: {12, "Jane Doe", "Invoice", "CustomerOrderNumber + Branch", "Contains JANE and Branch = 95", true, #date(2025, 12, 19)}

    Scenario: Add customer by specific CustomerNo from InTrans
    Solution: Add to InTrans individual section, use exact CustomerNo
    Example: {12, "Company ABC", "InTrans", "CustomerNo", "12345", true, #date(2025, 12, 19)}

    Scenario: Temporarily hide a customer from reporting
    Solution: Change IsActive from true to false (preserves historical relationships)

    ================================================================================================
    */

    // STEP 1: Define customer table structure and data
    // ================================================
    // Creates an in-memory table with all unique customers
    // Each row represents one customer with their identification rules
    CustomersTable = #table(
        // Column definitions - these define the structure
        {
            "CustomerKey",              // Surrogate key - used in fact table joins
            "CustomerName",             // Display name for reports
            "DataSource",               // Which system has the transactions (InTrans or Invoice)
            "IdentificationMethod",     // How we identify this customer
            "IdentificationRule",       // Business rule description
            "IsActive",                 // Boolean - false hides customer without breaking history
            "CreatedDate"               // Audit trail - when customer was added
        },

        // Data rows - each customer entry
        {
            // ============================================================================
            // LOCATION-BASED CUSTOMERS (InTrans TradeType identification)
            // ============================================================================
            // These customers are identified by their TradeType in ArMaster_Customer
            // Fact table: Fact_InTrans_UniqueCustomers uses ArMaster lookup method

            {1, "Pearsall", "InTrans", "TradeType", "D", true, #date(2025, 7, 31)},
            // TradeType "D" in ArMaster identifies all Pearsall customer transactions
            // Fact table filters InTrans for ANY customer with TradeType = "D"

            {2, "Dell City", "InTrans", "TradeType + Branch", "T and Branch <> 2", true, #date(2025, 8, 4)},
            // TradeType "T" + Branch NOT "2" identifies Dell City transactions
            // Splits the "T" trade type between Dell City and Tornillo by location

            {3, "Tornillo", "InTrans", "TradeType + Branch", "T and Branch = 2", true, #date(2025, 8, 4)},
            // TradeType "T" + Branch = "2" identifies Tornillo transactions
            // Branch code "2" is the specific Tornillo location identifier

            // ============================================================================
            // INVOICE-BASED CUSTOMERS (CustomerOrderNumber text matching)
            // ============================================================================
            // These customers are identified by text patterns in Invoice.CustomerOrderNumber
            // Fact table: Fact_Invoice_UniqueCustomers uses Text.Contains() with Text.Upper()

            {4, "Manuel/MR Tractor", "Invoice", "CustomerOrderNumber", "Contains MANUEL or MR TRACTOR", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "MANUEL" OR "MR TRACTOR" (case-insensitive)
            // Combined into single customer per business requirement
            // Examples: "MANUEL-123", "manuel/order", "MR TRACTOR PARTS" all match

            {5, "Jim Justice", "Invoice", "CustomerOrderNumber + Branch", "Contains JIM and Branch = 94", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "JIM" AND Branch = "94" (both conditions required)
            // Branch restriction prevents matching Jim orders from other locations
            // Examples: "JIM-001" in Branch 94 matches, but "JIM-001" in Branch 92 does NOT match

            {6, "David Arizmendi", "Invoice", "CustomerOrderNumber + Branch", "Contains DAVID and Branch = 92", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "DAVID" AND Branch = "92"
            // Similar to Jim Justice but for Branch 92

            {10, "Danny G", "Invoice", "CustomerOrderNumber", "Starts with *DANNY G", true, #date(2025, 11, 04)},
            // Matches if CustomerOrderNumber contains "*DANNY G" (asterisk is literal, not wildcard)
            // Case-insensitive: "*DANNY G", "*danny g", "*Danny G" all match
            // Examples: "*DANNY G-001", "*danny g order" match

            {11, "Oscar", "Invoice", "CustomerOrderNumber", "Starts with *OSCAR", true, #date(2025, 11, 04)},
            // Matches if CustomerOrderNumber contains "*OSCAR" (asterisk is literal character)
            // Case-insensitive matching via Text.Upper() in fact table
            // Examples: "*OSCAR-123", "*oscar parts" match

            // ============================================================================
            // INDIVIDUAL CUSTOMERS (InTrans CustomerNo direct matching)
            // ============================================================================
            // These customers are identified by exact CustomerNo match in InTrans
            // Fact table: Fact_InTrans_UniqueCustomers uses List.Contains() for matching

            {7, "Dallyn Clements", "InTrans", "CustomerNo", "36192", true, #date(2025, 9, 22)},
            // Exact match: InTrans.CustomerNo = "36192"
            // Captures ALL transactions for this specific customer number

            {8, "Benny Gray", "InTrans", "CustomerNo", "38845", true, #date(2025, 9, 22)},
            // Exact match: InTrans.CustomerNo = "38845"

            {9, "Owen Bros.", "InTrans", "CustomerNo", "61055", true, #date(2025, 9, 22)}
            // Exact match: InTrans.CustomerNo = "61055"

            // ============================================================================
            // TO ADD NEW CUSTOMERS: Insert new row above this line
            // ============================================================================
            // Next available CustomerKey: 12
            // Format: {Key, "Name", "Source", "Method", "Rule", true, #date(YYYY, M, D)}
        }
    ),

    // STEP 2: Apply data types to all columns
    // ========================================
    // Converts text-based table structure into properly typed columns
    // This improves query performance and ensures data integrity
    TypedTable = Table.TransformColumnTypes(CustomersTable, {
        {"CustomerKey", Int64.Type},        // Integer - used for fact table joins
        {"CustomerName", type text},        // Text - display name
        {"DataSource", type text},          // Text - "InTrans" or "Invoice"
        {"IdentificationMethod", type text}, // Text - method description
        {"IdentificationRule", type text},  // Text - business rule
        {"IsActive", type logical},         // Boolean - true/false flag
        {"CreatedDate", type date}          // Date - audit timestamp
    })

    // STEP 3: Return the typed table as final output
    // ===============================================
    // This becomes the dim_UniqueCustomers dimension in the data model
in
    TypedTable

/*
============================================================================
📋 VALIDATION & TESTING
============================================================================

✅ POST-REFRESH VALIDATION:

1. **Row Count Verification:**
   - Should have 11 rows (current customer count)
   - Verify: SELECT COUNT(*) FROM dim_UniqueCustomers

2. **Active Customers:**
   - All customers should have IsActive = TRUE (unless intentionally hidden)
   - Verify: SELECT COUNT(*) FROM dim_UniqueCustomers WHERE IsActive = TRUE

3. **No Duplicate Keys:**
   - CustomerKey values must be unique
   - Verify: SELECT CustomerKey, COUNT(*) FROM dim_UniqueCustomers
             GROUP BY CustomerKey HAVING COUNT(*) > 1

4. **Data Source Distribution:**
   - Should have mix of "InTrans" and "Invoice" customers
   - Verify: SELECT DataSource, COUNT(*) FROM dim_UniqueCustomers GROUP BY DataSource

5. **Identification Methods:**
   - Should have 5 different methods represented
   - Verify: SELECT IdentificationMethod, COUNT(*) FROM dim_UniqueCustomers
             GROUP BY IdentificationMethod

✅ RELATIONSHIP VALIDATION:

After refresh, verify fact table relationships:
```sql
-- Check Fact_InTrans_UniqueCustomers relationships
SELECT COUNT(*)
FROM Fact_InTrans_UniqueCustomers f
LEFT JOIN dim_UniqueCustomers d ON f.CustomerKey = d.CustomerKey
WHERE d.CustomerKey IS NULL
-- Should return 0 (no orphaned records)

-- Check Fact_Invoice_UniqueCustomers relationships
SELECT COUNT(*)
FROM Fact_Invoice_UniqueCustomers f
LEFT JOIN dim_UniqueCustomers d ON f.CustomerKey = d.CustomerKey
WHERE d.CustomerKey IS NULL
-- Should return 0 (no orphaned records)
```

✅ BUSINESS LOGIC VALIDATION:

Verify customer distribution matches expectations:
```sql
-- Check customer transaction counts
SELECT
    d.CustomerName,
    d.DataSource,
    COUNT(*) as TransactionCount
FROM (
    SELECT CustomerKey FROM Fact_InTrans_UniqueCustomers
    UNION ALL
    SELECT CustomerKey FROM Fact_Invoice_UniqueCustomers
) f
JOIN dim_UniqueCustomers d ON f.CustomerKey = d.CustomerKey
WHERE d.IsActive = TRUE
GROUP BY d.CustomerName, d.DataSource
ORDER BY TransactionCount DESC
```

============================================================================
🚀 DEPLOYMENT NOTES
============================================================================

**Prerequisites:**
1. ✅ This is an in-memory table (no external dependencies)
2. ✅ Fact tables must exist and be configured for customer matching

**Deployment Steps:**
1. Create df_Dim_UniqueCustomers dataflow with this query
2. Schedule DAILY refresh at ~7:45 AM (after raw data, before facts)
3. Create relationships in Power BI model:
   - Fact_InTrans_UniqueCustomers[CustomerKey] → dim_UniqueCustomers[CustomerKey]
   - Fact_Invoice_UniqueCustomers[CustomerKey] → dim_UniqueCustomers[CustomerKey]
4. Verify row count (11 customers)
5. Test reports with customer filter

**Scheduling - CRITICAL:**
- **MUST refresh DAILY** (unlike most reference dimensions)
- Scheduled: ~7:45 AM weekdays
- Sequence: After raw data pipeline, BEFORE fact tables
- Dependency chain: Raw Data → dim_UniqueCustomers → Fact Tables

**Refresh Dependencies:**
- Must refresh BEFORE: Fact_InTrans_UniqueCustomers, Fact_Invoice_UniqueCustomers
- No upstream dependencies (in-memory table)
- Critical for daily reporting accuracy

**Adding New Customers:**
1. Add row to CustomersTable with next sequential CustomerKey
2. Update corresponding fact table query with matching logic
3. Test refresh of both dimension and fact table
4. Validate transaction counts and relationships
5. Document change in version control/notes

============================================================================
*/
