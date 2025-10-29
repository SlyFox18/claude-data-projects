let
    /*
    ================================================================================================
    FACT TABLE: Fact_InTrans_UniqueCustomers
    ================================================================================================
    
    PURPOSE:
    Primary fact table for unique customer parts transactions sourced from InTrans system.
    Supports multi-method customer identification and integrates with unified dimensional model.
    
    BUSINESS CONTEXT:
    - Captures sales, costs, margins, and transaction details for strategic customers
    - Enables YTD vs PYTD performance analysis and trend reporting
    - Filters out non-customer transactions (Type P inventory purchases)
    - Supports both location-based customers and individual high-value customers
    
    CUSTOMER IDENTIFICATION METHODS:
    1. ArMaster Lookup Method: Uses ArMaster_Customer.TradeType (D=Pearsall, T=Dell City/Tornillo)
       - Captures ALL transactions for customers with specific trade type classifications
       - Branch logic splits TradeType T between Dell City and Tornillo locations
    
    2. Direct CustomerNo Method: Specific customer number matching
       - Captures ALL transactions for individually identified customers
       - Used for high-value individual customers not captured by TradeType logic
    
    DATA QUALITY CONTROLS:
    - Excludes Type P transactions (inventory/purchasing, not customer sales)
    - Text-based joins prevent SQL conversion errors (ArMaster numeric vs InTrans text)
    - Inner joins ensure only transactions for confirmed unique customers
    
    DIMENSIONAL RELATIONSHIPS:
    - CustomerKey → dim_UniqueCustomers (1:Many)
    - BranchKey → dim_BranchLocation (1:Many) 
    - DateKey → dim_DateTable (1:Many)
    
    PERFORMANCE OPTIMIZATIONS:
    - DateKey integer for efficient time intelligence
    - TransactionKey for incremental refresh capability
    - Pre-calculated margin amounts and percentages
    
    MAINTENANCE NOTES:
    - When adding new TradeType customers: Update ArMaster filter logic
    - When adding new individual customers: Update DirectCustomerNumbers list and CustomerKey logic
    - Coordinate changes with dim_UniqueCustomers for consistent CustomerKey assignments
    
    ================================================================================================
    */
    
    Source = ref_InTrans,
    
    // STEP 1: CREATE CUSTOMER LOOKUP (ArMaster-based customers)
    CustomerLookup = Table.SelectRows(ref_ArMaster_Customer, each 
        [TradeType] = "D" or [TradeType] = "T"
    ),
    
    // Convert CustomerNumber to text to match InTrans CustomerNo data type
    ConvertCustomerNumber = Table.TransformColumns(CustomerLookup, {{"CustomerNumber", each Text.From(_), type text}}),
    CustomerDedup = Table.Distinct(Table.SelectColumns(ConvertCustomerNumber, {"CustomerNumber", "TradeType"})),
    
    // STEP 2: FILTER FOR UNIQUE CUSTOMERS (Hybrid approach)
    // Include transactions that match EITHER ArMaster lookup OR specific CustomerNo values
    ArMasterCustomers = Table.NestedJoin(Source, {"CustomerNo"}, CustomerDedup, {"CustomerNumber"}, "CustomerInfo", JoinKind.Inner),
    ExpandArMasterCustomers = Table.ExpandTableColumn(ArMasterCustomers, "CustomerInfo", {"TradeType"}, {"Customer_TradeType"}),
    
    // Add individual customers by direct CustomerNo matching
    DirectCustomerNumbers = {"36192", "38845", "61055"},  // Individual unique customers
    DirectCustomers = Table.SelectRows(Source, each List.Contains(DirectCustomerNumbers, [CustomerNo])),
    AddNullTradeType = Table.AddColumn(DirectCustomers, "Customer_TradeType", each null, type text),
    
    // UNION both customer sets
    CombinedCustomers = Table.Combine({ExpandArMasterCustomers, AddNullTradeType}),
    
    // STEP 3: APPLY DATA QUALITY FILTERS
    FilteredRows = Table.SelectRows(CombinedCustomers, each [Type] <> "P"),  // Exclude inventory purchases
    
    // STEP 4: ADD CUSTOMER KEY (Multi-method identification)
    AddCustomerKey = Table.AddColumn(FilteredRows, "CustomerKey", each
        // ArMaster-based customers (TradeType method)
        if [Customer_TradeType] = "D" then 1  // Pearsall
        else if [Customer_TradeType] = "T" and [Branch] = "2" then 3  // Tornillo
        else if [Customer_TradeType] = "T" and [Branch] <> "2" then 2  // Dell City
        // Individual customers (Direct CustomerNo method)
        else if [CustomerNo] = "36192" then 7  // Dallyn Clements
        else if [CustomerNo] = "38845" then 8  // Benny Gray
        else if [CustomerNo] = "61055" then 9  // Owen Bros.
        else null, Int64.Type
    ),
    
    // STEP 5: BUSINESS LOGIC ENHANCEMENTS
    AddSalesType = Table.AddColumn(AddCustomerKey, "SalesType", each
        if Text.Contains([Description] ?? "", "Inv No.") then "Work Order"
        else "Over the Counter", type text
    ),
    
    // STEP 6: DIMENSIONAL JOINS
    JoinBranch = Table.NestedJoin(AddSalesType, {"Branch"}, ref_dim_BranchLocation, {"BranchID"}, "BranchInfo", JoinKind.LeftOuter),
    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchInfo", {"BranchKey"}, {"BranchKey"}),
    
    // STEP 7: TIME INTELLIGENCE FIELDS
    AddDateKey = Table.AddColumn(ExpandBranch, "DateKey", each 
        Date.Year(DateTime.Date([TransDatetime])) * 10000 + 
        Date.Month(DateTime.Date([TransDatetime])) * 100 + 
        Date.Day(DateTime.Date([TransDatetime])), Int64.Type),
    
    AddYear = Table.AddColumn(AddDateKey, "TransactionYear", each Date.Year([TransDatetime]), Int64.Type),
    AddMonth = Table.AddColumn(AddYear, "TransactionMonth", each Date.Month([TransDatetime]), Int64.Type),
    AddQuarter = Table.AddColumn(AddMonth, "TransactionQuarter", each Date.QuarterOfYear([TransDatetime]), Int64.Type),
    AddYearMonth = Table.AddColumn(AddQuarter, "TransactionYearMonth", each Date.Year([TransDatetime]) * 100 + Date.Month([TransDatetime]), Int64.Type),
    
    // STEP 8: BUSINESS CALCULATIONS
    AddMarginAmount = Table.AddColumn(AddYearMonth, "MarginAmount", each [SaleValue] - [CostValue], type number),
    AddMarginPercent = Table.AddColumn(AddMarginAmount, "MarginPercent", each 
        if [SaleValue] <> 0 then ([SaleValue] - [CostValue]) / [SaleValue] else 0, type number),
    
    // STEP 9: TECHNICAL ENHANCEMENTS
    AddTransactionKey = Table.AddColumn(AddMarginPercent, "TransactionKey", each 
        Text.Combine({
            Text.From([Branch]), 
            Text.From([DateKey]),
            [RONumber] ?? "",
            [PartNumber] ?? "",
            Text.From([CustomerNo])
        }, "_"), type text),
    
    // STEP 10: FINAL COLUMN SELECTION
    SelectedColumns = Table.SelectColumns(AddTransactionKey, {
        "TransactionKey", "DateKey", "TransDatetime", 
        "TransactionYear", "TransactionMonth", "TransactionQuarter", "TransactionYearMonth",
        "Branch", "BranchKey", "CustomerNo", "CustomerKey", 
        "Franchise", "PartNumber", "Description", "Qty", "Type", "TradeType", 
        "RONumber", "SaleValue", "CostValue", "MarginAmount", "MarginPercent",
        "SellPrice1", "ListPrice", "SalesType"
    })
    
in
    SelectedColumns