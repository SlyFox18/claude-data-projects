/*
============================================================================
FACT_CUSTOMERPERFORMANCE - AGGREGATED CUSTOMER PERFORMANCE (LEVEL 1)
============================================================================

TABLE OVERVIEW:
Purpose: Aggregated customer performance for Customer Anatomy report - Level 1 summary
Grain: One row per Customer + Year + Month (CustomerKey + Year + Month is unique)
Source: Aggregated from Level 2 fact tables (single source of truth)
Refresh Strategy: Combines and aggregates from Lakehouse fact tables

DATA FLOW - SINGLE SOURCE OF TRUTH:
This table aggregates from the Level 2 fact tables to ensure numbers always match:
- Fact_Parts_Invoices -> PartsSales, PartsCost, PartsMargin, PartsInvoiceCount
- Fact_Service_Invoices -> ServiceSales, ServiceCost, ServiceMargin, ServiceInvoiceCount
- Fact_Equipment_Sales -> EquipmentSales, EquipmentCost, EquipmentMargin, EquipmentCount

BUSINESS USE CASES:
* Customer Anatomy - Summary View (Level 1): "Customer X spent $15000 total this month"
* Cross-Department Analysis: Compare Parts vs Service vs Equipment by customer
* Customer Value Ranking: Top customers by total spend
* Territory Performance: Roll up to territory/class level
* Trend Analysis: Month-over-month, year-over-year comparisons
* Drill-through entry point to Level 2 (invoice detail)

KEY METRICS ENABLED:
* Total Sales = PartsSales + ServiceSales + EquipmentSales
* Total Cost = PartsCost + ServiceCost + EquipmentCost
* Total Margin = TotalSales - TotalCost
* Total GP% = TotalMargin / TotalSales
* Department breakdowns (Parts, Service, Equipment)
* Invoice/Transaction counts by department

DIMENSIONAL RELATIONSHIPS:
* CustomerKey -> dim_CustomerList (primary relationship)
* Territory -> dim_BranchLocation (for Branch slicer filtering - see note below)
* Year + Month -> dim_DateTable (via DAX or calculated date key)

TERRITORY/BRANCH FILTERING (Added 2026-02-09):
The Territory column is denormalized from dim_CustomerList to enable Branch slicer
filtering on the Executive Summary page. This solves the "ambiguous paths" problem:

WHY DENORMALIZE TERRITORY?
- Level 2 fact tables (Parts, Service, Equipment) have direct Branch relationships
  to dim_BranchLocation (via the invoice's actual branch)
- If we created dim_CustomerList[Territory] -> dim_BranchLocation, it would create
  ambiguous paths (e.g., Fact_Parts_Invoices could reach dim_BranchLocation via
  two paths: direct Branch, or through dim_CustomerList)
- By adding Territory directly to Fact_CustomerPerformance, we create a single
  unambiguous path: Fact_CustomerPerformance[Territory] -> dim_BranchLocation

HOW THE BRANCH SLICER WORKS:
- Executive Summary (Fact_CustomerPerformance): Filters by customer's HOME territory
- Drill-through pages (Level 2 facts): Filters by invoice's ACTUAL branch
- This means a customer based in Territory 1 who transacted at Branch 16 would:
  - Appear on Executive Summary when Branch 1 is selected (home territory)
  - Have their Branch 16 transactions visible on drill-through when Branch 16 selected

CUSTOMER ANATOMY INTEGRATION (3-Level Drill-Through):
- Level 1: Fact_CustomerPerformance (THIS TABLE - "Customer X spent $15000 total")
- Level 2: Fact_Parts_Invoices, Fact_Service_Invoices, Fact_Equipment_Sales (invoice detail)
- Level 3: Fact_Parts_Detail, Fact_Service_Detail (line item detail)

DATAFLOW REQUIREMENTS:
This query requires these Lakehouse table references in the dataflow:
1. Fact_Parts_Invoices - Parts Counter invoice aggregates
2. Fact_Service_Invoices - Service/Workshop invoice aggregates
3. Fact_Equipment_Sales - Equipment sales aggregates
4. dim_CustomerList - Customer dimension (for Territory lookup)

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA - LEVEL 2 FACT TABLES FROM LAKEHOUSE
    // ========================================================================
    // Strategy: Normalize each source to common columns, append, then group
    // This avoids full outer join column name conflicts

    // ========================================================================
    // PARTS DEPARTMENT - NORMALIZE FROM FACT_PARTS_INVOICES
    // ========================================================================

    PartsSource = Fact_Parts_Invoices,

    // Select and rename columns to standard format
    PartsNormalized = Table.SelectColumns(PartsSource, {
        "CustomerKey", "InvoiceYear", "InvoiceMonth",
        "PartsSaleValue", "PartsCostValue", "PartsMargin"
    }),

    PartsRenamed = Table.RenameColumns(PartsNormalized, {
        {"InvoiceYear", "Year"},
        {"InvoiceMonth", "Month"},
        {"PartsSaleValue", "PartsSales"},
        {"PartsCostValue", "PartsCost"}
    }),

    // Add placeholder columns for other departments
    PartsWithPlaceholders = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    Table.AddColumn(
                        Table.AddColumn(PartsRenamed, "ServiceSales", each 0, type number),
                        "ServiceCost", each 0, type number),
                    "ServiceMargin", each 0, type number),
                "EquipmentSales", each 0, type number),
            "EquipmentCost", each 0, type number),
        "EquipmentMargin", each 0, type number),

    // ========================================================================
    // SERVICE DEPARTMENT - NORMALIZE FROM FACT_SERVICE_INVOICES
    // ========================================================================

    ServiceSource = Fact_Service_Invoices,

    // Select and rename columns to standard format
    ServiceNormalized = Table.SelectColumns(ServiceSource, {
        "CustomerKey", "InvoiceYear", "InvoiceMonth",
        "TotalNetSales", "TotalCost", "TotalMargin"
    }),

    ServiceRenamed = Table.RenameColumns(ServiceNormalized, {
        {"InvoiceYear", "Year"},
        {"InvoiceMonth", "Month"},
        {"TotalNetSales", "ServiceSales"},
        {"TotalCost", "ServiceCost"},
        {"TotalMargin", "ServiceMargin"}
    }),

    // Add placeholder columns for other departments
    ServiceWithPlaceholders = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    Table.AddColumn(
                        Table.AddColumn(ServiceRenamed, "PartsSales", each 0, type number),
                        "PartsCost", each 0, type number),
                    "PartsMargin", each 0, type number),
                "EquipmentSales", each 0, type number),
            "EquipmentCost", each 0, type number),
        "EquipmentMargin", each 0, type number),

    // ========================================================================
    // EQUIPMENT DEPARTMENT - NORMALIZE FROM FACT_EQUIPMENT_SALES
    // ========================================================================

    EquipmentSource = Fact_Equipment_Sales,

    // Select and rename columns to standard format
    // Note: Fact_Equipment_Sales uses SalesValue and TotalBaseCost, no Margin column
    EquipmentNormalized = Table.SelectColumns(EquipmentSource, {
        "CustomerKey", "SaleYear", "SaleMonth",
        "SalesValue", "TotalBaseCost"
    }),

    EquipmentRenamed = Table.RenameColumns(EquipmentNormalized, {
        {"SaleYear", "Year"},
        {"SaleMonth", "Month"},
        {"SalesValue", "EquipmentSales"},
        {"TotalBaseCost", "EquipmentCost"}
    }),

    // Calculate Equipment Margin (not in source table)
    EquipmentWithMargin = Table.AddColumn(EquipmentRenamed, "EquipmentMargin", each
        (if [EquipmentSales] = null then 0 else [EquipmentSales]) -
        (if [EquipmentCost] = null then 0 else [EquipmentCost]),
        type number),

    // Add placeholder columns for other departments
    EquipmentWithPlaceholders = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    Table.AddColumn(
                        Table.AddColumn(EquipmentWithMargin, "PartsSales", each 0, type number),
                        "PartsCost", each 0, type number),
                    "PartsMargin", each 0, type number),
                "ServiceSales", each 0, type number),
            "ServiceCost", each 0, type number),
        "ServiceMargin", each 0, type number),

    // ========================================================================
    // COMBINE ALL DEPARTMENTS - APPEND APPROACH
    // ========================================================================
    // Append all rows, then group to combine by CustomerKey + Year + Month

    AllDepartments = Table.Combine({
        PartsWithPlaceholders,
        ServiceWithPlaceholders,
        EquipmentWithPlaceholders
    }),

    // ========================================================================
    // GROUP BY CUSTOMER + YEAR + MONTH
    // ========================================================================
    // Sum all metrics to combine department contributions

    Grouped = Table.Group(AllDepartments, {"CustomerKey", "Year", "Month"}, {
        {"PartsSales", each List.Sum([PartsSales]), type number},
        {"PartsCost", each List.Sum([PartsCost]), type number},
        {"PartsMargin", each List.Sum([PartsMargin]), type number},
        {"ServiceSales", each List.Sum([ServiceSales]), type number},
        {"ServiceCost", each List.Sum([ServiceCost]), type number},
        {"ServiceMargin", each List.Sum([ServiceMargin]), type number},
        {"EquipmentSales", each List.Sum([EquipmentSales]), type number},
        {"EquipmentCost", each List.Sum([EquipmentCost]), type number},
        {"EquipmentMargin", each List.Sum([EquipmentMargin]), type number},
        {"TotalTransactionCount", each Table.RowCount(_), Int64.Type}
    }),

    // ========================================================================
    // CALCULATE TOTALS
    // ========================================================================

    // Total Sales
    AddTotalSales = Table.AddColumn(Grouped, "TotalSales", each
        [PartsSales] + [ServiceSales] + [EquipmentSales],
        type number),

    // Total Cost
    AddTotalCost = Table.AddColumn(AddTotalSales, "TotalCost", each
        [PartsCost] + [ServiceCost] + [EquipmentCost],
        type number),

    // Total Margin
    AddTotalMargin = Table.AddColumn(AddTotalCost, "TotalMargin", each
        [PartsMargin] + [ServiceMargin] + [EquipmentMargin],
        type number),

    // Note: TotalTransactionCount is already calculated in the Group step above

    // ========================================================================
    // ADD DATE KEY FOR RELATIONSHIP
    // ========================================================================
    // Create a DateKey as YYYYMM01 (first of month) for date table relationship

    AddDateKey = Table.AddColumn(AddTotalMargin, "PeriodDateKey", each
        if [Year] = null or [Month] = null then null
        else [Year] * 10000 + [Month] * 100 + 1,
        Int64.Type),

    // ========================================================================
    // FILTER OUT NULL CUSTOMER KEYS
    // ========================================================================
    // Remove rows where CustomerKey couldn't be determined

    FilterValidCustomers = Table.SelectRows(AddDateKey, each [CustomerKey] <> null and [CustomerKey] <> 0),

    // ========================================================================
    // ADD TERRITORY FROM DIM_CUSTOMERLIST (Added 2026-02-09)
    // ========================================================================
    // Denormalize Territory (customer's home branch) to enable Branch slicer filtering.
    //
    // WHY: We cannot create a relationship dim_CustomerList[Territory] -> dim_BranchLocation
    // because it would create ambiguous paths for Level 2 fact tables that already have
    // direct Branch relationships to dim_BranchLocation.
    //
    // SOLUTION: Add Territory directly to this table, then create relationship:
    // Fact_CustomerPerformance[Territory] -> dim_BranchLocation[BranchID]
    //
    // This allows the Branch slicer to filter the Executive Summary by customer's
    // home territory, while drill-through pages filter by actual invoice branch.

    JoinCustomerForTerritory = Table.NestedJoin(
        FilterValidCustomers,
        {"CustomerKey"},
        dim_CustomerList,
        {"CustomerKey"},
        "CustomerLookup",
        JoinKind.LeftOuter
    ),

    ExpandTerritory = Table.ExpandTableColumn(
        JoinCustomerForTerritory,
        "CustomerLookup",
        {"Territory"},
        {"Territory"}
    ),

    // ========================================================================
    // FINAL COLUMN SELECTION AND ORDERING
    // ========================================================================

    SelectColumns = Table.SelectColumns(ExpandTerritory, {
        // Keys
        "CustomerKey", "Year", "Month", "PeriodDateKey",

        // Territory - for Branch slicer filtering (denormalized from dim_CustomerList)
        "Territory",

        // Parts Department
        "PartsSales", "PartsCost", "PartsMargin",

        // Service Department
        "ServiceSales", "ServiceCost", "ServiceMargin",

        // Equipment Department
        "EquipmentSales", "EquipmentCost", "EquipmentMargin",

        // Totals
        "TotalSales", "TotalCost", "TotalMargin", "TotalTransactionCount"
    }),

    // Set final data types
    SetTypes = Table.TransformColumnTypes(SelectColumns, {
        {"CustomerKey", Int64.Type},
        {"Year", Int64.Type},
        {"Month", Int64.Type},
        {"PeriodDateKey", Int64.Type},
        {"Territory", type text},
        {"PartsSales", type number},
        {"PartsCost", type number},
        {"PartsMargin", type number},
        {"ServiceSales", type number},
        {"ServiceCost", type number},
        {"ServiceMargin", type number},
        {"EquipmentSales", type number},
        {"EquipmentCost", type number},
        {"EquipmentMargin", type number},
        {"TotalSales", type number},
        {"TotalCost", type number},
        {"TotalMargin", type number},
        {"TotalTransactionCount", Int64.Type}
    })

in
    SetTypes

/*
============================================================================
FACT_CUSTOMERPERFORMANCE - IMPLEMENTATION NOTES
============================================================================

DATAFLOW SETUP REQUIREMENTS:

This query requires these Lakehouse table references:

1. **Fact_Parts_Invoices** (already exists)
   - Reference to: LH_Master_Data > Fact_Parts_Invoices
   - Query name in dataflow: Fact_Parts_Invoices

2. **Fact_Service_Invoices** (already exists)
   - Reference to: LH_Master_Data > Fact_Service_Invoices
   - Query name in dataflow: Fact_Service_Invoices

3. **Fact_Equipment_Sales** (already exists)
   - Reference to: LH_Master_Data > Fact_Equipment_Sales
   - Query name in dataflow: Fact_Equipment_Sales

4. **dim_CustomerList** (REQUIRED for Territory lookup - Added 2026-02-09)
   - Reference to: LH_Master_Data > dim_CustomerList
   - Query name in dataflow: dim_CustomerList
   - Used to get customer's home Territory for Branch slicer filtering

DATAFLOW STRUCTURE:
```
Dataflow: df_CustomerAnatomy_Facts (or similar)
├── Fact_Parts_Invoices (Lakehouse reference)
├── Fact_Service_Invoices (Lakehouse reference)
├── Fact_Equipment_Sales (Lakehouse reference)
├── dim_CustomerList (Lakehouse reference) - for Territory lookup
└── Fact_CustomerPerformance (this query - aggregates from above)
```

EXPECTED PERFORMANCE:
- Aggregates from ~500K parts invoices + ~200K service invoices + ~25K equipment sales
- Output: ~50-100K rows (unique Customer + Year + Month combinations)
- Refresh time: 2-4 min expected (depends on Level 2 table sizes)

============================================================================

REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_CustomerPerformance[CustomerKey] -> dim_CustomerList[CustomerKey] (Many-to-One)
2. Fact_CustomerPerformance[PeriodDateKey] -> dim_DateTable[DateKey] (Many-to-One)
   NOTE: PeriodDateKey is YYYYMM01 format (first of month)
3. Fact_CustomerPerformance[Territory] -> dim_BranchLocation[BranchID] (Many-to-One)
   NOTE: Added 2026-02-09 to enable Branch slicer filtering on Executive Summary.
   This filters by customer's HOME territory, not transaction branch.
   See header comments for full explanation of why this is denormalized.

KEY DAX MEASURES TO CREATE:

-- Customer Count
Active Customers = DISTINCTCOUNT(Fact_CustomerPerformance[CustomerKey])

-- Total Revenue
Total Revenue = SUM(Fact_CustomerPerformance[TotalSales])

-- Total Margin
Total Margin = SUM(Fact_CustomerPerformance[TotalMargin])

-- Total GP%
Total GP% = DIVIDE([Total Margin], [Total Revenue], 0)

-- Parts Revenue
Parts Revenue = SUM(Fact_CustomerPerformance[PartsSales])

-- Service Revenue
Service Revenue = SUM(Fact_CustomerPerformance[ServiceSales])

-- Equipment Revenue
Equipment Revenue = SUM(Fact_CustomerPerformance[EquipmentSales])

-- Revenue Mix %
Parts Mix % = DIVIDE([Parts Revenue], [Total Revenue], 0)
Service Mix % = DIVIDE([Service Revenue], [Total Revenue], 0)
Equipment Mix % = DIVIDE([Equipment Revenue], [Total Revenue], 0)

-- YTD/PYTD MEASURES:
Total Revenue YTD =
CALCULATE(
    [Total Revenue],
    DATESYTD(dim_DateTable[Date])
)

Total Revenue PYTD =
CALCULATE(
    [Total Revenue],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

-- YoY Growth
Revenue YoY Growth =
DIVIDE(
    [Total Revenue YTD] - [Total Revenue PYTD],
    [Total Revenue PYTD],
    0
)

============================================================================

EXECUTIVE INTELLIGENCE MEASURES (DAX):

These replace the calculated columns from the test queries.
They respond to filter context and are more flexible:

-- Customer Health Score (composite metric)
Customer Health Score =
VAR Revenue = [Total Revenue]
VAR Margin = [Total Margin]
VAR GPPct = [Total GP%]
VAR TransactionCount = SUM(Fact_CustomerPerformance[TotalTransactionCount])
VAR DeptCount =
    (IF([Parts Revenue] > 0, 1, 0) +
     IF([Service Revenue] > 0, 1, 0) +
     IF([Equipment Revenue] > 0, 1, 0))
RETURN
    -- Normalize and weight factors (adjust weights as needed)
    (DIVIDE(Revenue, 100000, 0) * 0.3) +  -- Revenue factor
    (DIVIDE(Margin, 50000, 0) * 0.3) +     -- Margin factor
    (GPPct * 0.2) +                         -- GP% factor
    (DeptCount / 3 * 0.2)                   -- Cross-sell factor

-- Cross-Sell Opportunity
Cross-Sell Opportunity =
VAR HasParts = IF([Parts Revenue] > 0, 1, 0)
VAR HasService = IF([Service Revenue] > 0, 1, 0)
VAR HasEquipment = IF([Equipment Revenue] > 0, 1, 0)
VAR DeptCount = HasParts + HasService + HasEquipment
RETURN
    SWITCH(
        TRUE(),
        DeptCount = 3, "Full Engagement",
        DeptCount = 2, "Growth Potential",
        DeptCount = 1, "Cross-Sell Target",
        "No Activity"
    )

-- Strategic Value
Strategic Value =
VAR Revenue = [Total Revenue]
VAR GPPct = [Total GP%]
RETURN
    SWITCH(
        TRUE(),
        Revenue > 100000 && GPPct > 0.25, "Premium",
        Revenue > 50000 && GPPct > 0.20, "High Value",
        Revenue > 20000, "Standard",
        Revenue > 5000, "Developing",
        "Low Activity"
    )

============================================================================

WHY THIS ARCHITECTURE:

1. **Single Source of Truth**: Numbers in Level 1 will ALWAYS match Level 2
   - No discrepancies between summary and detail views
   - Easier troubleshooting and validation

2. **Consistent CustomerKey**: All tables use the same CustomerKey pattern
   - dim_CustomerList is the hub
   - No orphaned or mismatched customer records

3. **Flexible Analysis via DAX**: Executive intelligence as measures means:
   - Scores update when filters change (date, territory, etc.)
   - Easy to adjust thresholds without re-processing data
   - Time intelligence works naturally

4. **Performance**: Aggregating pre-filtered Level 2 tables is faster than
   re-querying ODBC for each department

============================================================================
*/
