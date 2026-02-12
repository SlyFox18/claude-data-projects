let
    // ========================================================================
    // PHYSICAL INVENTORY - FILTERED PARTS DATA FOR COUNTING PROGRESS
    // ========================================================================
    /*
    PURPOSE:
    Extracts and transforms parts data for physical inventory tracking.
    Includes bin-level counting status and suggested week assignments.
    
    KEY FEATURES:
    - Filters to active inventory with valid bins
    - Calculates "Is Part Counted" flag (Stocktake Date in current year)
    - Calculates "Has Bin Qty" flag (BinQty > 0)
    - Calculates "Is Part with Qty Counted" flag (has qty AND counted)
    - Assigns "Suggested Week" (1-52) for even distribution of counting
    - Optimized for Import mode in Fabric Lakehouse
    
    BUSINESS RULES:
    - Part is "counted" when StocktakeDate is in current year (2025)
    - Bin is "counted" when ANY part in that bin has been counted (calculated in DAX)
    - Suggested Week distributes bins alphabetically across 52 weeks per branch
    */
    
    // Performance optimization: Calculate current year once
    CurrentYear = Date.Year(DateTime.LocalNow()),
    
    // ========================================================================
    // STEP 1: CONNECT TO LAKEHOUSE
    // ========================================================================
    
    Source = Sql.Database(
        "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", 
        "LH_Master_Data"
    ),
    
    SourceTable = Source{[Schema="dbo", Item="jdis_Part_Information"]}[Data],
    
    // ========================================================================
    // STEP 2: BUSINESS RULE FILTERING
    // ========================================================================
    /*
    Filter out:
    - Items without bin locations (null, empty, or 10 spaces)
    - Inactive franchises: ZP, S, T*, U*
    
    This ensures we only track legitimate, active inventory
    */
    
    FilteredRows = Table.SelectRows(SourceTable, each 
        // Bin must exist and not be effectively empty
        [Bin] <> null and
        [Bin] <> "" and
        [Bin] <> "          " and  // 10 spaces - data quality filter
        
        // Franchise must be operational (exclude test/inactive)
        [Franchise] <> "ZP" and
        [Franchise] <> "S" and
        not Text.StartsWith([Franchise], "T") and
        not Text.StartsWith([Franchise], "U")
    ),
    
    // ========================================================================
    // STEP 3: COLUMN SELECTION
    // ========================================================================
    /*
    Select only columns needed for physical inventory analysis
    Reduces memory footprint and improves refresh performance
    */
    
    SelectColumns = Table.SelectColumns(FilteredRows, {
        "Branch",
        "PartNumber",
        "Description",
        "Franchise",
        "Bin",
        "BinQty",
        "QuantityOnHand",
        "BulkBinQty",
        "StocktakeDate",
        "DateCreated"
    }),
    
    // ========================================================================
    // STEP 4: RENAME FOR CONSISTENCY
    // ========================================================================
    
    RenameColumns = Table.RenameColumns(SelectColumns, {
        {"QuantityOnHand", "OnHandQty"}
    }),
    
    // ========================================================================
    // STEP 5: DATA TYPE OPTIMIZATION
    // ========================================================================
    
    SetDataTypes = Table.TransformColumnTypes(RenameColumns, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"Franchise", type text},
        {"Bin", type text},
        {"BinQty", Int64.Type},
        {"OnHandQty", Int64.Type},
        {"BulkBinQty", Int64.Type},
        {"StocktakeDate", type date},
        {"DateCreated", type date}
    }),
    
    // ========================================================================
    // STEP 6: HANDLE NULL QUANTITIES
    // ========================================================================
    
    ReplaceNulls = Table.ReplaceValue(
        SetDataTypes,
        null,
        0,
        Replacer.ReplaceValue,
        {"BinQty", "OnHandQty", "BulkBinQty"}
    ),
    
    // ========================================================================
    // STEP 7: ADD COUNTING STATUS FLAG
    // ========================================================================
    /*
    CRITICAL COUNTING LOGIC:
    
    A part is considered "COUNTED" if:
    - StocktakeDate exists (not null)
    - StocktakeDate is in the CURRENT YEAR (2025)
    
    IMPORTANT: We do NOT check DateCreated year!
    - Parts created in 2020 and counted in 2025 = COUNTED ✅
    - Parts created in 2025 but not stocktaked = NOT COUNTED ❌
    
    This ensures ALL inventory (regardless of age) is properly tracked.
    */
    
    AddIsPartCounted = Table.AddColumn(
        ReplaceNulls, 
        "Is Part Counted", 
        each if [StocktakeDate] <> null and 
                Date.Year([StocktakeDate]) = CurrentYear
             then 1 
             else 0,
        Int64.Type
    ),
    
    // ========================================================================
    // STEP 7B: ADD HAS BIN QTY FLAG
    // ========================================================================
    /*
    Identifies parts that have physical inventory (BinQty > 0)
    
    PURPOSE:
    Used for tracking thoroughness of counting:
    - Are we counting actual stock vs empty bins?
    - Helps measure quality of counting process
    
    LOGIC:
    - BinQty > 0 → Flag = 1 (has inventory)
    - BinQty = 0 → Flag = 0 (empty/no stock)
    */
    
    AddHasBinQty = Table.AddColumn(
        AddIsPartCounted,
        "Has Bin Qty",
        each if [BinQty] > 0 then 1 else 0,
        Int64.Type
    ),
    
    // ========================================================================
    // STEP 7C: ADD IS PART WITH QTY COUNTED FLAG
    // ========================================================================
    /*
    Identifies parts with inventory that have been counted this year
    
    PURPOSE:
    Tracks counting progress on items with actual stock
    - Focuses on meaningful inventory (not empty bins)
    - Measures thoroughness of stocktaking process
    
    LOGIC - Must meet ALL conditions:
    1. Has physical inventory (BinQty > 0)
    2. Has been stocktaked (StocktakeDate not null)
    3. Stocktaked in current year (2025)
    
    EXAMPLES:
    - BinQty=10, StocktakeDate=2025-06-15 → Flag = 1 ✅
    - BinQty=10, StocktakeDate=2024-12-01 → Flag = 0 ❌ (old year)
    - BinQty=0, StocktakeDate=2025-06-15 → Flag = 0 ❌ (no qty)
    - BinQty=10, StocktakeDate=null → Flag = 0 ❌ (not counted)
    */
    
    AddIsPartWithQtyCounted = Table.AddColumn(
        AddHasBinQty,
        "Is Part with Qty Counted",
        each if [BinQty] > 0 and 
                [StocktakeDate] <> null and
                Date.Year([StocktakeDate]) = CurrentYear
             then 1
             else 0,
        Int64.Type
    ),
    
    // ========================================================================
    // STEP 8: ADD SUGGESTED WEEK FOR WORKFLOW DISTRIBUTION
    // ========================================================================
    /*
    SUGGESTED WEEK CALCULATION:
    
    Purpose: Distribute bin counting evenly across 52 weeks
    Method: Assign sequential week numbers (1-52) to bins alphabetically within each branch
    
    Example for Branch 94:
    - Bin A-001 → Week 1
    - Bin A-002 → Week 2
    - ...
    - Bin A-053 → Week 1 (cycles back)
    
    This creates a predictable, balanced counting schedule
    */
    
    // Get distinct Branch-Bin combinations
    DistinctBins = Table.Distinct(AddIsPartWithQtyCounted, {"Branch", "Bin"}),
    
    // Sort by Branch, then Bin (alphabetical within branch)
    SortedBins = Table.Sort(DistinctBins, {
        {"Branch", Order.Ascending}, 
        {"Bin", Order.Ascending}
    }),
    
    // Group by Branch and add sequential index within each branch
    GroupedByBranch = Table.Group(
        SortedBins, 
        {"Branch"}, 
        {{"BinData", each 
            Table.AddIndexColumn(_, "BinIndex", 1, 1, Int64.Type)
        }}
    ),
    
    // Expand back to flat table with index
    ExpandedWithIndex = Table.ExpandTableColumn(
        GroupedByBranch, 
        "BinData", 
        {"Bin", "BinIndex"}
    ),
    
    // Calculate Suggested Week: MOD((Index - 1), 52) + 1
    // This cycles through weeks 1-52 repeatedly
    AddSuggestedWeek = Table.AddColumn(
        ExpandedWithIndex, 
        "Suggested Week", 
        each Number.Mod([BinIndex] - 1, 52) + 1,
        Int64.Type
    ),
    
    // Keep only the lookup columns
    BinWeekLookup = Table.SelectColumns(AddSuggestedWeek, {
        "Branch", 
        "Bin", 
        "Suggested Week"
    }),
    
    // Merge Suggested Week back to main table
    MergeWeeks = Table.NestedJoin(
        AddIsPartWithQtyCounted,
        {"Branch", "Bin"},
        BinWeekLookup,
        {"Branch", "Bin"},
        "WeekLookup",
        JoinKind.LeftOuter
    ),
    
    // Expand to add Suggested Week column
    AddWeekColumn = Table.ExpandTableColumn(
        MergeWeeks,
        "WeekLookup",
        {"Suggested Week"}
    ),
    
    // ========================================================================
    // STEP 9: FINAL DATA TYPE VERIFICATION
    // ========================================================================
    /*
    Ensure all columns have correct data types for optimal performance
    */
    
    FinalDataTypes = Table.TransformColumnTypes(AddWeekColumn, {
        {"Is Part Counted", Int64.Type},
        {"Has Bin Qty", Int64.Type},
        {"Is Part with Qty Counted", Int64.Type},
        {"Suggested Week", Int64.Type}
    })

in
    FinalDataTypes