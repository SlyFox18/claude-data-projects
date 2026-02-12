/*
============================================================================
CUSTOMERLOOKUP - UNIFIED CUSTOMER MATCHING BRIDGE TABLE
============================================================================

TABLE OVERVIEW:
Purpose: Single lookup table for customer matching from BillToAccount/AccountNumber
Grain: One row per unique matching key (AccountNumber, CustomerNumber, or ContactID)
Source: dim_CustomerList (denormalized for fast lookup)
Refresh Strategy: Rebuild each refresh (small table, fast)

WHY THIS EXISTS:
BillToAccount in Invoice/WkInvReg contains THREE different formats:
  1. Numeric AccountNumber (e.g., "52306") - AR account numbers
  2. Numeric CustomerNumber (e.g., "12345") - Customer numbers (may differ from AccountNumber)
  3. Text ContactID (e.g., "FLOYDIARC3429") - Contact codes

Instead of each fact table doing THREE joins (AccountNumber + CustomerNumber + ContactID),
this table provides a SINGLE lookup point with all keys.

PERFORMANCE BENEFIT:
- Before: Each fact table does 2-3 NestedJoins (expensive)
- After: Each fact table does 1 NestedJoin (major reduction)
- With 4 fact tables (Parts, Service, ServiceDetail, Equipment):
  * Before: 8-12 total joins per refresh
  * After: 4 total joins per refresh + 1 small table build
  * Net savings: ~60-70% reduction in join operations

STRUCTURE:
- MatchKey: The lookup value (uppercased for consistency)
- CustomerKey: The customer dimension key
- MatchType: "AccountNumber", "CustomerNumber", or "ContactID" (for debugging)
- Plus denormalized customer attributes for direct access

MATCHING PRIORITY (when same key appears multiple times):
1. AccountNumber (primary AR identifier)
2. CustomerNumber (secondary customer identifier)
3. ContactID (contact code identifier)

============================================================================
*/

let
    // ========================================================================
    // SOURCE: CUSTOMER DIMENSION
    // ========================================================================

    Source = dim_CustomerList,

    // ========================================================================
    // EXTRACT ACCOUNTNUMBER MATCHES (Priority 1)
    // ========================================================================
    // AccountNumber is the primary matching key (AR account number)

    AccountNumberRows = Table.SelectColumns(Source, {
        "CustomerKey", "AccountNumber", "ContactID", "Territory", "Account_Class", "DisplayName"
    }),

    // Filter to rows with valid AccountNumber
    ValidAccountNumbers = Table.SelectRows(AccountNumberRows, each
        [AccountNumber] <> null and [AccountNumber] <> ""),

    // Create MatchKey from AccountNumber (uppercased for consistency)
    AddAccountMatchKey = Table.AddColumn(ValidAccountNumbers, "MatchKey", each
        Text.Upper(Text.Trim(Text.From([AccountNumber]))), type text),

    AddAccountMatchType = Table.AddColumn(AddAccountMatchKey, "MatchType", each "AccountNumber", type text),

    AccountLookup = Table.SelectColumns(AddAccountMatchType, {
        "MatchKey", "CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName", "MatchType"
    }),

    // ========================================================================
    // EXTRACT CUSTOMERNUMBER MATCHES (Priority 2)
    // ========================================================================
    // CustomerNumber may be different from AccountNumber in some systems

    CustomerNumberRows = Table.SelectColumns(Source, {
        "CustomerKey", "CustomerNumber", "ContactID", "Territory", "Account_Class", "DisplayName"
    }),

    // Filter to rows with valid CustomerNumber
    ValidCustomerNumbers = Table.SelectRows(CustomerNumberRows, each
        [CustomerNumber] <> null and [CustomerNumber] <> ""),

    // Create MatchKey from CustomerNumber (uppercased for consistency)
    AddCustomerMatchKey = Table.AddColumn(ValidCustomerNumbers, "MatchKey", each
        Text.Upper(Text.Trim(Text.From([CustomerNumber]))), type text),

    AddCustomerMatchType = Table.AddColumn(AddCustomerMatchKey, "MatchType", each "CustomerNumber", type text),

    CustomerLookup = Table.SelectColumns(AddCustomerMatchType, {
        "MatchKey", "CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName", "MatchType"
    }),

    // ========================================================================
    // EXTRACT CONTACTID MATCHES (Priority 3)
    // ========================================================================
    // ContactID is text-based contact code

    ContactIDRows = Table.SelectColumns(Source, {
        "CustomerKey", "AccountNumber", "ContactID", "Territory", "Account_Class", "DisplayName"
    }),

    // Filter to rows with valid ContactID
    ValidContactIDs = Table.SelectRows(ContactIDRows, each
        [ContactID] <> null and [ContactID] <> ""),

    // Create MatchKey from ContactID (uppercased for case-insensitive matching)
    AddContactMatchKey = Table.AddColumn(ValidContactIDs, "MatchKey", each
        Text.Upper(Text.Trim(Text.From([ContactID]))), type text),

    AddContactMatchType = Table.AddColumn(AddContactMatchKey, "MatchType", each "ContactID", type text),

    ContactLookup = Table.SelectColumns(AddContactMatchType, {
        "MatchKey", "CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName", "MatchType"
    }),

    // ========================================================================
    // COMBINE ALL LOOKUP SOURCES
    // ========================================================================
    // Union in priority order: AccountNumber, CustomerNumber, ContactID
    // First occurrence wins when deduplicating

    CombinedLookup = Table.Combine({AccountLookup, CustomerLookup, ContactLookup}),

    // ========================================================================
    // DEDUPLICATE BY MATCHKEY
    // ========================================================================
    // If same MatchKey exists in multiple sources, keep first by priority order
    // Priority: AccountNumber > CustomerNumber > ContactID

    // Group by MatchKey and take first row (priority order preserved from Combine)
    GroupedLookup = Table.Group(CombinedLookup, {"MatchKey"}, {
        {"FirstRow", each Table.First(_),
            type [CustomerKey = Int64.Type, ContactID = text, Territory = text,
                  Account_Class = text, DisplayName = text, MatchType = text]}
    }),

    // Expand the first row record back to columns
    ExpandedLookup = Table.ExpandRecordColumn(GroupedLookup, "FirstRow",
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName", "MatchType"},
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName", "MatchType"}),

    // ========================================================================
    // FINAL TYPE ASSIGNMENT
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(ExpandedLookup, {
        {"MatchKey", type text},
        {"CustomerKey", Int64.Type},
        {"ContactID", type text},
        {"Territory", type text},
        {"Account_Class", type text},
        {"DisplayName", type text},
        {"MatchType", type text}
    })

in
    SetTypes

/*
============================================================================
USAGE IN FACT TABLES
============================================================================

Replace the multi-join pattern with:

// Prepare BillToAccount for matching (uppercase for consistency)
CleanBillToAccount = Table.AddColumn(Source, "BillToAccount_Upper", each
    Text.Upper(Text.Trim(Text.From([BillToAccount] ?? ""))), type text),

// Single join to CustomerLookup
JoinCustomer = Table.NestedJoin(
    CleanBillToAccount, {"BillToAccount_Upper"},
    CustomerLookup, {"MatchKey"},
    "CustomerMatch", JoinKind.LeftOuter),

// Expand customer attributes
ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
    {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName"},
    {"CustomerKey", "ContactID", "Territory", "AccountClass", "CustomerDisplayName"}),

// Handle unmatched (CustomerKey = -1 for Unknown Customer)
AddCustomerKey = Table.ReplaceValue(ExpandCustomer, null, -1,
    Replacer.ReplaceValue, {"CustomerKey"}),

RemoveMatchColumn = Table.RemoveColumns(AddCustomerKey, {"BillToAccount_Upper"})

============================================================================

EXPECTED ROW COUNT:
- dim_CustomerList: ~50-60K customers
- CustomerLookup: ~150-180K rows (each customer may have AccountNumber + CustomerNumber + ContactID)
- Very fast to build and join against

MATCHING COVERAGE:
This bridge table matches BillToAccount values against:
1. AccountNumber - Primary AR account numbers (e.g., "52306")
2. CustomerNumber - Secondary customer identifiers (may differ from AccountNumber)
3. ContactID - Text-based contact codes (e.g., "FLOYDIARC3429")

If a BillToAccount value matches multiple key types, priority order applies:
AccountNumber > CustomerNumber > ContactID

DATAFLOW DEPENDENCY:
- Requires: dim_CustomerList (must refresh before this table)
- Used by: Fact_Parts_Invoices, Fact_Service_Invoices, Fact_Service_Detail, Fact_Equipment_Sales

============================================================================
*/
