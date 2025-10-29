/*

============================================================================

RAW_REPAIRORDERDETAIL - PERFORMANCE-OPTIMIZED WORK ORDER LIFECYCLE EXTRACTION

============================================================================

  

📋 TABLE OVERVIEW:

Purpose: Clean, efficient extraction of work order lifecycle data from RepairOrderDetail

Grain: One row per work order with essential lifecycle and financial data

Refresh Strategy: Full refresh (maintains 1-minute performance with optimized extraction)

Performance: Target 1m refresh time with essential column selection

Source Dependencies: RepairOrderDetail view/table (work order lifecycle system)

  

🎯 BUSINESS USE CASES:

• Fact Table Foundation: Primary data source for work order lifecycle and WIP fact tables

• Financial Summary: Complete revenue breakdown by service category

• Timeline Data: Essential dates for aging and progression analysis (calculated in fact tables)

• Status Tracking: Work order progress and completion status

• Revenue Analysis: Service mix and financial performance baseline data

  

📊 ESSENTIAL DATA STRUCTURE (17 COLUMNS - PERFORMANCE OPTIMIZED):

  

**Core Work Order Identifiers:**

• Branch: Work order branch location

• WorkOrder: Work order number

• JobCode: Primary job classification

• JobType: Job type indicator

• InvoiceNumber: Invoice identifier (if invoiced)

  

**Status Intelligence:**

• StatusDisplay: Business status description

• ROProgressStatus: System progress status code

  

**Essential Timeline (Source Data for Aging Calculations):**

• CreationDate: Work order creation date

• JobStartDate: Job start date

• FirstLaborPunch: First labor activity date

• LastLaborPunch: Last labor activity date

• DaysSinceCreationDate: Age in days (source calculation)

  

**Complete Financial Summary:**

• LaborRevenue: Labor billing amount

• PartsRevenue: Parts billing amount

• SubletRevenue: Sublet billing amount

• OtherRevenue: Other services billing amount

• TotalRevenue: Complete revenue total

  

**Business Context:**

• NonRevenueIndicator: Non-revenue work flag

  

🔧 DESIGN PRINCIPLES APPLIED:

  

**Raw Table Architecture:**

• Simple extraction: Essential source data for fact table aging and business logic

• Performance focus: Maintains 1-minute refresh with reduced complexity

• Timeline foundation: Provides all dates needed for fact table aging calculations

• Financial completeness: Complete revenue breakdown for service mix analysis

  

============================================================================

*/

  

let

    // ========================================================================

    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL COLUMNS ONLY

    // ========================================================================

    /*

    STRATEGY: Essential work order lifecycle data with timeline foundation

    PERFORMANCE: Maintain 1-minute refresh by focusing on source data extraction

    AGING LOGIC: Provide source dates for fact table aging calculations

    */

    SQL =

    "SELECT #(lf)

        -- ===== CORE WORK ORDER IDENTIFIERS ===== #(lf)

        Branch AS Branch, #(lf)

        RONumber AS WorkOrder, #(lf)

        JobCode AS JobCode, #(lf)

        JobType AS JobType, #(lf)

        InvoiceNumber AS InvoiceNumber, #(lf)

        -- ===== STATUS INTELLIGENCE ===== #(lf)

        StatusDisplay AS StatusDisplay, #(lf)

        ROProgressStatus AS ROProgressStatus, #(lf)

        -- ===== TIMELINE FOUNDATION (FOR FACT TABLE AGING LOGIC) ===== #(lf)

        CreationDate AS CreationDate, #(lf)

        JobStartDate AS JobStartDate, #(lf)

        FirstLaborPunch AS FirstLaborPunch, #(lf)

        LastLaborPunch AS LastLaborPunch, #(lf)

        DaysSinceCreationDate AS DaysSinceCreationDate, #(lf)

        -- ===== COMPLETE FINANCIAL SUMMARY ===== #(lf)

        LaborSale AS LaborRevenue, #(lf)

        PartSale AS PartsRevenue, #(lf)

        SubletSale AS SubletRevenue, #(lf)

        OtherSale AS OtherRevenue, #(lf)

        TotalSale AS TotalRevenue, #(lf)

        -- ===== BUSINESS CONTEXT ===== #(lf)

        NonRevenueIndicator AS NonRevenueIndicator #(lf)

    FROM RepairOrderDetail #(lf)

    ORDER BY CreationDate DESC, Branch, RONumber",

    // ========================================================================

    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE

    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise

        error "Failed to connect to REPAIRORDERDETAIL. Verify database connection and table availability."

  

in

    Source

  

/*

============================================================================

✅ RAW_REPAIRORDERDETAIL - OPTIMIZED FOR PERFORMANCE & FACT TABLE SUPPORT

============================================================================

  

🎯 OPTIMIZATION RESULTS:

• Removed Complex Business Logic: All aging calculations moved to fact table layer

• Essential Fields Only: 17 columns focused on source data and timeline foundation

• Performance Priority: Maintains 1-minute refresh with simplified extraction

• Fact Table Ready: Provides all source dates needed for aging and business logic

  

🔍 BUSINESS LOGIC MOVED TO FACT TABLES:

• Aging Calculations: 1-7 days, 8-14 days, etc. categories calculated in fact tables

• Progress Status Mapping: BI→"Booked In" transformations in fact tables

• Work Started Logic: 1/1/1900 date handling in fact tables

• Revenue Categorizations: High/Medium/Low value analysis in fact tables

• Service Mix Classifications: Labor Heavy, Parts Heavy analysis in fact tables

• AgingSortOrder: Priority ordering logic in fact tables

  

🚀 ESSENTIAL TIMELINE DATA PRESERVED:

• CreationDate: Base date for all aging calculations

• JobStartDate: Work initiation tracking

• FirstLaborPunch: First activity indicator

• LastLaborPunch: Last activity tracking

• DaysSinceCreationDate: Age calculation foundation (source provides this)

  

🔧 FACT TABLE AGING IMPLEMENTATION:

The fact table can now implement your aging logic using the timeline data:

  

```

Aging =

if [JobStartDate] = null or [JobStartDate] = DATE(1900,1,1) then "Not Started"

else

    let days = [DaysSinceCreationDate] in

    if days >= 1 && days <= 7 then "1 - 7 Days"

    else if days >= 8 && days <= 14 then "8 - 14 Days"

    else if days >= 15 && days <= 30 then "15 - 30 Days"

    else if days >= 31 && days <= 60 then "31 - 60 Days"

    else if days > 60 then "60+ Days"

    else "Not Started"

```

  

This approach provides better performance, maintainability, and architectural consistency.

  

============================================================================

*/