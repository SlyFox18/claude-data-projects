/*
============================================================================
DIAGNOSTIC QUERY: Find Duplicate PartNumbers in dim_Parts Source
============================================================================
PURPOSE: Identify which PartNumbers have duplicates in jdis_Part_Information
USE THIS: Run this query in Power Query to see what's causing duplicates

This will show you all PartNumbers that appear more than once in the source
============================================================================
*/

let
    // Load source
    Source = jdis_Part_Information,

    // Clean PartNumber the same way dim_Parts does
    CleanPartNumber = Table.TransformColumns(Source, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // Group by PartNumber and count occurrences
    GroupedByPartNumber = Table.Group(
        CleanPartNumber,
        {"PartNumber"},
        {
            {"Count", each Table.RowCount(_), Int64.Type},
            {"Records", each _, type table}
        }
    ),

    // Filter to only duplicates (Count > 1)
    OnlyDuplicates = Table.SelectRows(GroupedByPartNumber, each [Count] > 1),

    // Sort by count descending to see worst offenders first
    SortByCount = Table.Sort(OnlyDuplicates, {{"Count", Order.Descending}}),

    // Expand the Records to see what's different between duplicates
    ExpandRecords = Table.ExpandTableColumn(
        SortByCount,
        "Records",
        {"PartNumber", "Description", "Franchise", "QuantityOnHand", "Branch"},
        {"PartNumber.1", "Description", "Franchise", "QuantityOnHand", "Branch"}
    ),

    // Reorder for clarity
    Reorder = Table.ReorderColumns(ExpandRecords, {
        "PartNumber",
        "Count",
        "PartNumber.1",
        "Description",
        "Franchise",
        "Branch",
        "QuantityOnHand"
    })

in
    Reorder

/*
============================================================================
HOW TO USE THIS DIAGNOSTIC:
============================================================================

1. In Power BI Desktop, go to Transform Data (Power Query Editor)
2. Click New Source > Blank Query
3. Click Advanced Editor
4. Paste this entire query
5. Click Done
6. Look at the results

WHAT TO LOOK FOR:
- PartNumber: The duplicate part number (like '10MN')
- Count: How many times it appears
- Descri, Franchise, Branch: What's different between the duplicates

LIKELY CAUSES:
- Same part in multiple branches (need to add Branch to deduplication key)
- Same part with different franchises (need to decide which to keep)
- Data quality issue in jdis_Part_Information source

RECOMMENDED FIX:
If duplicates are caused by Branch differences:
  Change dim_Parts.pq line 221 from:
    RemoveDuplicates = Table.Distinct(AddIsHighValue, {"PartNumber"})
  To:
    RemoveDuplicates = Table.Distinct(AddIsHighValue, {"PartNumber", "Branch"})

But this changes the grain! Only do this if PartNumber alone isn't unique.
============================================================================
*/
