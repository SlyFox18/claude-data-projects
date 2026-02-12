/*
============================================================================
DIM_PAYMENTMETHOD - PAYMENT METHOD DIMENSION
============================================================================

📋 DIMENSION OVERVIEW:
Purpose: Create standardized payment method dimension for payment analysis
Grain: One row per unique payment method type
Refresh Strategy: Full refresh (small dimension, changes infrequently)
Source Dependencies: Invoice table (extract distinct payment methods)

🎯 BUSINESS USE CASES:
• Payment Pattern Analysis: Track revenue distribution across payment types
• Cash Flow Management: Analyze cash vs card vs check payment timing
• Branch Comparison: Compare payment method preferences by location
• Risk Analysis: Identify payment method concentration risks
• Fee Analysis: Calculate processing fees by payment type
• Customer Behavior: Understand payment preferences across ModuleTypes

📊 DIMENSION STRUCTURE (5 COLUMNS):

**Primary Key:**
• PaymentMethodKey: Surrogate key (1, 2, 3, etc.)

**Descriptive Attributes:**
• PaymentMethod: Original payment method code from source
• PaymentMethodDescription: User-friendly display name
• PaymentCategory: High-level grouping (Cash, Electronic, Check, Other)

**Presentation:**
• SortOrder: Control visual display order (not alphabetical)

🔧 DESIGN APPROACH:

**Simple Structure:**
• Source PaymentMethod values are already user-friendly (no transformation needed)
• PaymentMethodDescription = PaymentMethod (maintains standard dimension structure)
• Business-logical sort order (Cash first, most important for cash flow)
• Category grouping enables high-level "Cash vs Electronic vs Check" analysis

**Extensibility:**
• Ready for additional attributes (processing fees, risk levels, etc.)
• Structure supports future payment method additions (unlikely with only 5)
• Category grouping enables strategic payment analysis

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DISTINCT PAYMENT METHODS
    // ========================================================================
    /*
    STRATEGY: Extract all unique payment methods from Invoice table
    QUALITY: Filter out nulls and empty strings for clean dimension
    SOURCE: Invoice table contains all historical payment method values
    */

    Source = Invoice,

    // Select PaymentMethod column and get distinct values
    SelectPaymentMethod = Table.SelectColumns(Source, {"PaymentMethod"}),

    // Filter out invalid values
    FilterValid = Table.SelectRows(SelectPaymentMethod,
        each [PaymentMethod] <> null and [PaymentMethod] <> ""),

    // Get unique payment methods
    DistinctPaymentMethods = Table.Distinct(FilterValid),

    // ========================================================================
    // STEP 2: ADD SURROGATE KEY
    // ========================================================================
    /*
    PURPOSE: Create unique identifier for each payment method
    LOGIC: Sequential numbering starting from 1
    BENEFIT: Enables efficient fact table relationships
    */

    AddIndex = Table.AddIndexColumn(DistinctPaymentMethods, "PaymentMethodKey", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 3: ADD PAYMENT CATEGORY GROUPING
    // ========================================================================
    /*
    PURPOSE: High-level categorization for executive reporting
    LOGIC: Group similar payment types into business categories
    BENEFIT: Enables "Cash vs Electronic" type analysis
    NOTE: Based on actual values: Account, Cheque, Credit Card, Finance, Cash
    */

    AddCategory = Table.AddColumn(AddIndex, "PaymentCategory",
        each if [PaymentMethod] = "Cash" then "Cash"
             else if [PaymentMethod] = "Credit Card" then "Electronic"
             else if [PaymentMethod] = "Cheque" then "Check"
             else if [PaymentMethod] = "Account" then "Account"
             else if [PaymentMethod] = "Finance" then "Finance"
             else "Other",
        type text),

    // ========================================================================
    // STEP 4: ADD SORT ORDER FOR VISUALIZATIONS
    // ========================================================================
    /*
    PURPOSE: Control display order in Power BI visuals
    LOGIC: Logical business order (not alphabetical)
    ORDER: Cash → Credit Card → Cheque → Account → Finance
    */

    AddSortOrder = Table.AddColumn(AddCategory, "SortOrder",
        each if [PaymentMethod] = "Cash" then 1
             else if [PaymentMethod] = "Credit Card" then 2
             else if [PaymentMethod] = "Cheque" then 3
             else if [PaymentMethod] = "Account" then 4
             else if [PaymentMethod] = "Finance" then 5
             else 6, // Other (shouldn't exist)
        Int64.Type),

    // ========================================================================
    // STEP 5: ADD PAYMENT METHOD DESCRIPTION (SAME AS SOURCE)
    // ========================================================================
    /*
    PURPOSE: Maintain consistency - source values are already user-friendly
    LOGIC: PaymentMethodDescription = PaymentMethod (no transformation needed)
    BENEFIT: Keeps dimension structure standard for future enhancements
    */

    AddDescription = Table.AddColumn(AddSortOrder, "PaymentMethodDescription",
        each [PaymentMethod],
        type text),

    // ========================================================================
    // STEP 6: FINAL STRUCTURE WITH PROPER COLUMN ORDER
    // ========================================================================

    ReorderColumns = Table.ReorderColumns(AddDescription, {
        "PaymentMethodKey",
        "PaymentMethod",
        "PaymentMethodDescription",
        "PaymentCategory",
        "SortOrder"
    }),

    // Set proper data types
    SetDataTypes = Table.TransformColumnTypes(ReorderColumns, {
        {"PaymentMethodKey", Int64.Type},
        {"PaymentMethod", type text},
        {"PaymentMethodDescription", type text},
        {"PaymentCategory", type text},
        {"SortOrder", Int64.Type}
    })

in
    SetDataTypes

/*
============================================================================
✅ DIM_PAYMENTMETHOD - PRODUCTION-READY DIMENSION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Automated extraction from Invoice table source data
• Business-friendly descriptions for reporting
• Category grouping for high-level analysis
• Sort order control for logical visual presentation
• Extensible structure for future enhancements

📊 OUTPUT STRUCTURE (5 Columns):

**Keys:**
1. PaymentMethodKey (Surrogate key: 1, 2, 3...)

**Attributes:**
2. PaymentMethod (Original code: "CA", "CC", "CK", etc.)
3. PaymentMethodDescription (Display name: "Cash", "Credit Card", "Check")
4. PaymentCategory (Grouping: "Cash", "Electronic", "Check", "Account", "Other")
5. SortOrder (Visual ordering: 1, 2, 3, 4, 5)

🔍 EXAMPLE OUTPUT:

PaymentMethodKey | PaymentMethod | PaymentMethodDescription | PaymentCategory | SortOrder
1                | Cash          | Cash                     | Cash            | 1
2                | Credit Card   | Credit Card              | Electronic      | 2
3                | Cheque        | Cheque                   | Check           | 3
4                | Account       | Account                  | Account         | 4
5                | Finance       | Finance                  | Finance         | 5

🎨 VISUALIZATION BENEFITS:
• PaymentMethodDescription for clean axis labels (same as source - already user-friendly)
• PaymentCategory for high-level grouping (Cash, Electronic, Check, Account, Finance)
• SortOrder ensures Cash appears first, then Credit Card, then others
• Consistent naming across all reports

🔧 BUSINESS LOGIC:

**Your Payment Methods (5 total):**
1. **Cash** - Cash payments (SortOrder: 1, Category: Cash)
2. **Credit Card** - Credit card payments (SortOrder: 2, Category: Electronic)
3. **Cheque** - Check payments (SortOrder: 3, Category: Check)
4. **Account** - Account charge payments (SortOrder: 4, Category: Account)
5. **Finance** - Finance payments (SortOrder: 5, Category: Finance)

**Sort Order Logic:**
- Cash first (most important for cash flow)
- Credit Card second (most common electronic)
- Cheque third
- Account fourth
- Finance fifth

**Category Grouping:**
- Enables high-level analysis: "Electronic vs Cash vs Check"
- Can create measures like "Electronic %" = Credit Card %
- Useful for executive dashboards showing payment mix trends

🔗 FACT TABLE RELATIONSHIP:
After creating this dimension:
• Fact_Invoice_InventoryAnalysis[PaymentMethodKey] → dim_PaymentMethod[PaymentMethodKey]
• Cardinality: Many-to-One
• Cross-filter: Single direction

🚀 NEXT STEPS:
1. ✅ Create this dimension in your dataflow (no customization needed!)
2. ✅ Verify 5 rows appear (Cash, Credit Card, Cheque, Account, Finance)
3. ✅ Check SortOrder is correct (1, 2, 3, 4, 5)
4. ✅ Update fact table to include PaymentMethodKey lookup
5. ✅ Create relationship in Power BI model
6. ✅ Build visualizations using PaymentMethodDescription
7. ✅ Set sort column: PaymentMethodDescription sorted by SortOrder

============================================================================
*/
