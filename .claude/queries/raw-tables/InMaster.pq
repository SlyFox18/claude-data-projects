/*
Query: InMaster (Raw)
Dataflow: df_InMaster_Raw
Source: SQL Anywhere Database (ODBC)
Purpose: Inventory master table - core inventory data
Created: [Date]
Last Updated: [Date]
Output: Lakehouse table "InMaster"
Refresh Schedule: [Daily/Hourly/etc.]
Average Refresh Time: [X minutes/seconds]
Row Count (Approx): [Number of rows]

Notes:
- Core inventory table
- Contains inventory quantities, locations, costs
- StockOrderPrice field used for Original Margin calculations (Page 1)
- [Add other important notes]

Dependencies:
- None (direct source system table)

Key Columns:
- PartNumber
- Branch
- Franchise
- OnHandQty
- StockOrderPrice
- [Add other important columns]
*/

let
    // [PASTE YOUR QUERY CODE HERE]
    // Remove this comment and add your actual M code

    Source = null
in
    Source
