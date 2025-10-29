/*

======================================================================================

PHYSICAL INVENTORY QUERY - ENHANCED VERSION

======================================================================================

  

PURPOSE:

This query extracts physical inventory data from the jdis_Part_Information table and

creates calculated fields to support comprehensive inventory tracking and analysis.

  

DATA SOURCE:

ODBC connection to EquipRDB64 database, jdis_Part_Information table

  

BUSINESS LOGIC:

- Filters out inactive franchises (ZP, T*, U*, S)

- Excludes records with empty or null bin locations

- Tracks counting progress for both bins and parts

- Supports quantity-based analysis for physical inventory processes

  

USAGE:

- Physical Inventory Dashboard reporting

- Cycle count planning and tracking

- Inventory accuracy measurement

- Parts management and bin optimization

  

PERFORMANCE NOTES:

- Uses single ODBC query to minimize database round trips

- Year calculations cached in variable for efficiency

- Filtered at source level to reduce data transfer

  

DEPENDENCIES:

- EquipRDB64 ODBC connection

- jdis_Part_Information table access permissions

  

LAST MODIFIED: [Current Date]

AUTHOR: [Your Name]

======================================================================================

*/

  

let

    // Performance optimization: Calculate current year once

    CurrentYear = Date.Year(DateTime.LocalNow()),

    /*

    ======================================================================================

    STEP 1: SOURCE DATA EXTRACTION

    ======================================================================================

    Extract base inventory data from jdis_Part_Information table

    FILTERS APPLIED AT SOURCE:

    - pi_Bin IS NOT NULL AND pi_Bin <> '' : Exclude items without bin assignments

    - pi_Franchise <> 'ZP' : Exclude ZP franchise (inactive/test data)

    - pi_Franchise NOT LIKE 'T%' : Exclude test franchises starting with 'T'

    - pi_Franchise NOT LIKE 'U%' : Exclude user/training franchises starting with 'U'

    - pi_Franchise <> 'S' : Exclude 'S' franchise (system/special)

    */

    Source = Odbc.Query("dsn=EquipRDB64", "SELECT

        pi_Branch AS ""Branch"",

        pi_Franchise AS ""Franchise"",

        pi_Description AS ""Description"",

        pi_Part_No AS ""Part No"",

        pi_Bin AS ""Bin"",

        pi_Bin_Qty AS ""Bin Qty"",

        pi_On_Hand_Qty AS ""On Hand Qty"",

        pi_Bulk_Bin_Qty AS ""Bulk Bin Qty"",

        pi_Stocktake_Date,

        pi_Date_Created

    FROM

        jdis_Part_Information

    WHERE

        pi_Bin IS NOT NULL AND pi_Bin <> '' AND

        pi_Franchise <> 'ZP' AND

        pi_Franchise NOT LIKE 'T%' AND

        pi_Franchise NOT LIKE 'U%' AND

        pi_Franchise <> 'S'"),

  

    /*

    ======================================================================================

    STEP 2: DATA QUALITY FILTERING

    ======================================================================================

    Remove records with bin codes that are only whitespace (10 spaces)

    This catches bins that technically have content but are effectively empty

    */

    #"Filtered rows" = Table.SelectRows(Source, each ([Bin] <> "          ")),

  

    /*

    ======================================================================================

    STEP 3: DATA TYPE STANDARDIZATION

    ======================================================================================

    Convert date fields to proper date types for calculations and filtering

    Convert quantity fields to numbers and handle nulls

    */

    #"Changed column type" = Table.TransformColumnTypes(#"Filtered rows", {

        {"pi_Stocktake_Date", type date},

        {"pi_Date_Created", type date},

        {"Bin Qty", Int64.Type},

        {"On Hand Qty", Int64.Type},

        {"Bulk Bin Qty", Int64.Type}

    }),

  

    /*

    ======================================================================================

    STEP 4: COLUMN STANDARDIZATION

    ======================================================================================

    Rename columns to user-friendly names while maintaining consistency with existing reports

    CRITICAL: Do not change these names - they are used by existing measures and reports

    */

    #"Renamed columns" = Table.RenameColumns(#"Changed column type", {

        {"pi_Stocktake_Date", "Stocktake Date"},

        {"pi_Date_Created", "Date Created"}

    }),

  

    /*

    ======================================================================================

    STEP 5: NULL HANDLING FOR QUANTITIES

    ======================================================================================

    Replace null values in quantity fields with 0 for reliable calculations

    */

    #"Replaced nulls" = Table.ReplaceValue(#"Renamed columns", null, 0, Replacer.ReplaceValue, {"Bin Qty", "On Hand Qty", "Bulk Bin Qty"}),

  

    /*

    ======================================================================================

    STEP 6: CORE COUNTING LOGIC (EXISTING - DO NOT MODIFY)

    ======================================================================================

    These calculated columns support the existing dashboard functionality

    */

    // EXISTING: Tracks if a bin location has been counted in the current year

    // Logic: Bin is counted if both stocktake and creation dates exist, are in current year, and bin is not null

    #"Added custom" = Table.AddColumn(#"Replaced nulls", "Is Bin Counted", each

        if [Stocktake Date] <> null and [Date Created] <> null and

           Date.Year([Stocktake Date]) = CurrentYear and

           Date.Year([Date Created]) = CurrentYear and

           [Bin] <> null

        then 1 else 0

    ),

  

    // EXISTING: Tracks if a specific part has been counted in the current year

    // Logic: Part is counted if stocktake date, creation date, and part number all exist and are current year

    #"Added custom 1" = Table.AddColumn(#"Added custom", "Is Part Counted", each

        if [Stocktake Date] <> null and [Date Created] <> null and

           [Part No] <> null and

           Date.Year([Stocktake Date]) = CurrentYear and

           Date.Year([Date Created]) = CurrentYear

        then 1 else 0

    ),

  

    /*

    ======================================================================================

    STEP 7: NEW QUANTITY-BASED COUNTING LOGIC

    ======================================================================================

    Enhanced counting logic that considers inventory quantities

    */

    // NEW: Identifies parts that have physical inventory (Bin Qty > 0)

    // Used for: Tracking how many items actually have stock vs empty locations

    #"Added Has Bin Qty" = Table.AddColumn(#"Added custom 1", "Has Bin Qty", each

        if [Bin Qty] > 0 then 1 else 0

    ),

  

    // NEW: Tracks parts with quantities that have been physically counted

    // Logic: Must have bin qty > 0 AND have been counted in current year

    // Used for: Measuring progress on counting actual inventory vs empty bins

    #"Added Part with Qty Counted" = Table.AddColumn(#"Added Has Bin Qty", "Is Part with Qty Counted", each

        if [Bin Qty] > 0 and

           [Stocktake Date] <> null and

           Date.Year([Stocktake Date]) = CurrentYear

        then 1 else 0

    ),

  

    // NEW: Captures the actual quantity counted for items that have been stocktaked

    // Logic: If item was counted this year, use its bin qty, otherwise 0

    // Used for: Calculating percentage of total inventory quantity that has been verified

    #"Added Bin Qty Counted" = Table.AddColumn(#"Added Part with Qty Counted", "Bin Qty Counted", each

        if [Stocktake Date] <> null and

           Date.Year([Stocktake Date]) = CurrentYear

        then [Bin Qty] else 0

    ),

  

    /*

    ======================================================================================

    STEP 8: BUSINESS IDENTIFIER FIELDS (EXISTING - DO NOT MODIFY)

    ======================================================================================

    These composite keys support existing relationships and filtering

    */

    // EXISTING: Creates unique identifier combining bin and part number

    // Used for: Detailed drill-down analysis and duplicate detection

    #"Added custom 2" = Table.AddColumn(#"Added Bin Qty Counted", "Bin-Part No", each

        [Bin] & "-" & [Part No]

    ),

  

    // EXISTING: Creates unique identifier combining branch, bin, and part

    // Used for: Cross-branch analysis and ensuring global uniqueness

    #"Added custom 3" = Table.AddColumn(#"Added custom 2", "Combined", each

        [Branch] & "-" & [#"Bin-Part No"]

    ),

  

    /*

    ======================================================================================

    STEP 9: DATA QUALITY AND VALIDATION FLAGS

    ======================================================================================

    Additional flags to help identify data quality issues

    */

    // NEW: Flags records where bin qty doesn't match on-hand qty (potential discrepancy)

    #"Added Qty Variance Flag" = Table.AddColumn(#"Added custom 3", "Has Qty Variance", each

        if [Bin Qty] <> [On Hand Qty] then 1 else 0

    ),

  

    // NEW: Identifies the most recent activity date for prioritization

    #"Added Last Activity" = Table.AddColumn(#"Added Qty Variance Flag", "Last Activity Date", each

        if [Stocktake Date] <> null and [Date Created] <> null then

            if [Stocktake Date] > [Date Created] then [Stocktake Date] else [Date Created]

        else if [Stocktake Date] <> null then [Stocktake Date]

        else [Date Created]

    ),

  

    // NEW: Calculates days since last activity (useful for prioritizing old inventory)

    #"Added Days Since Activity" = Table.AddColumn(#"Added Last Activity", "Days Since Last Activity", each

        if [Last Activity Date] <> null then

            Duration.Days(DateTime.LocalNow() - DateTime.From([Last Activity Date]))

        else null

    ),

  

    /*

    ======================================================================================

    STEP 10: FINAL DATA TYPE STANDARDIZATION

    ======================================================================================

    Ensure all calculated fields have proper data types for optimal performance

    */

    #"Changed column type 1" = Table.TransformColumnTypes(#"Added Days Since Activity", {

        {"Is Bin Counted", Int64.Type},

        {"Is Part Counted", Int64.Type},

        {"Bin-Part No", type text},

        {"Combined", type text},

        {"Has Bin Qty", Int64.Type},

        {"Is Part with Qty Counted", Int64.Type},

        {"Bin Qty Counted", Int64.Type},

        {"Has Qty Variance", Int64.Type},

        {"Last Activity Date", type date},

        {"Days Since Last Activity", Int64.Type}

    })

  

in

    #"Changed column type 1"

  

/*

======================================================================================

SUGGESTED MEASURES FOR POWER BI MODEL

======================================================================================

  

Add these measures to your model to support the new gauges:

  

// For Parts with Bin Qty > 0 gauge

Total Parts with Qty = SUM('jdis_Phy_Inv'[Has Bin Qty])

Parts with Qty Counted = SUM('jdis_Phy_Inv'[Is Part with Qty Counted])

Parts with Qty % Counted = DIVIDE([Parts with Qty Counted], [Total Parts with Qty], 0)

  

// For Total Bin Qty % counted gauge

Total Bin Qty = SUM('jdis_Phy_Inv'[Bin Qty])

Total Bin Qty Counted = SUM('jdis_Phy_Inv'[Bin Qty Counted])

Bin Qty % Counted = DIVIDE([Total Bin Qty Counted], [Total Bin Qty], 0)

  

// Additional useful measures

Avg Days Since Activity = AVERAGE('jdis_Phy_Inv'[Days Since Last Activity])

Items with Qty Variance = SUM('jdis_Phy_Inv'[Has Qty Variance])

Qty Variance % = DIVIDE([Items with Qty Variance], COUNTROWS('jdis_Phy_Inv'), 0)

  

======================================================================================

*/