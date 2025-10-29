/*

============================================================================

RAW_INTRANS - INVENTORY TRANSACTIONS SOURCE DATA

============================================================================

  

📋 TABLE OVERVIEW:

Purpose: Extract parts/inventory transaction data from SQL Anywhere database

Grain: One row per parts transaction (sales, returns, transfers, adjustments)

Refresh Strategy: Date-filtered extraction with 7-day future buffer

Current Performance: ~3-5 minutes depending on date range

Dependencies: SQL Anywhere InTrans table via ODBC connection

  

🎯 BUSINESS USE CASES:

• Parts Sales Analysis: Revenue, margins, and customer purchasing patterns

• Inventory Management: Stock movement tracking and demand analysis

• Work Order Parts: Parts used in service and repair work

• Customer Analysis: Parts purchasing behavior and pricing optimization

• Manufacturer Analysis: Parts sales by equipment brand (franchise)

• Financial Reporting: Parts revenue, cost of goods sold, and margin analysis

  

📊 KEY DATA PROVIDED:

• Transaction Details: Date, quantities, pricing, and customer information

• Financial Metrics: Sale value, cost value, list price, and sell price

• Work Order Context: Job codes, job types, and invoice linkage

• Customer Context: Customer numbers and trade type classification

• Inventory Context: Part numbers, descriptions, and franchise brands

• Business Intelligence: Transaction types and trade classifications

  

🔗 DATA RELATIONSHIPS & LINKAGE:

• Work Order Integration: JobCode + JobType + RONumber links to wkothsub

• Customer Analysis: CustomerNo links to customer master data

• Parts Master: PartNumber links to parts inventory data

• Franchise Analysis: Franchise links to equipment manufacturer data

• Invoice Tracking: RONumber links to invoice register and billing

  

📈 DOWNSTREAM USAGE:

• Fact_WorkOrderParts: Work order-specific parts analysis

• Fact_Part_Transactions: Comprehensive parts transaction analysis

• Customer Performance: Parts purchasing patterns by customer

• Inventory Analysis: Stock movement and demand forecasting

• Financial Reporting: Parts revenue and margin analysis

  

⚡ PERFORMANCE OPTIMIZATION NOTES:

• Date filtering in SQL reduces data extraction volume

• 7-day future buffer accommodates system clock variations

• Essential columns only to minimize data transfer

• ODBC connection optimized for bulk data extraction

• Incremental refresh capability via date range parameters

  

🔧 MAINTENANCE NOTES:

• Monitor date range performance if transaction volume increases

• Validate column mappings if source schema changes

• Review future buffer period based on business requirements

• Consider partitioning strategy for very large date ranges

  

============================================================================

🔍 CRITICAL DATA LINEAGE NOTES

============================================================================

  

⚠️ IMPORTANT FIELD MAPPINGS:

• RONumber = REF_NO (Invoice Number, NOT Work Order Number!)

• JobCode + JobType = Required for work order parts linkage

• Type = Transaction type classification

• TradeType = Customer trade classification

  

🔗 WORK ORDER PARTS LINKAGE:

Parts transactions link to work orders via this path:

InTrans (Invoice + Job + Type) → wkothsub (Jobs) → wkrofile (Work Orders)

  

The join logic matches the original complex query:

- Branch = Branch (Location)

- RONumber = Invoice Number (os.invoice_no = it.REF_NO)

- JobCode = Job Code (os.job_code = it.JOB_CODE)

- JobType = Job Type (os.type = it.TYPE)

  

📝 NAMING CONVENTION NOTES:

• RONumber field contains Invoice Numbers (historical naming)

• Cannot rename to InvoiceNumber due to downstream dependencies

• Future enhancement: Standardize field names across all queries

• Document this mapping clearly in all dependent fact tables

  

============================================================================

*/

  

let

    // ========================================================================

    // STEP 1: DATE RANGE PARAMETERS & EXTRACTION STRATEGY

    // ========================================================================

    /*

    PURPOSE: Define extraction date range for incremental refresh capability

    BUSINESS LOGIC: Extract sufficient historical data while managing performance

    STRATEGY: Wide range (2020+) with future buffer for system clock variations

    */

    Source = let

        // Define extraction date range parameters

        RangeStart = #datetime(2020, 1, 1, 0, 0, 0),              // Start: Beginning of relevant data

        RangeEnd = DateTime.LocalNow() + #duration(7, 0, 0, 0),   // End: Current + 7 day buffer

        // ========================================================================

        // STEP 2: SQL STRING PREPARATION FOR ODBC QUERY

        // ========================================================================

        /*

        PURPOSE: Convert Power Query datetime to SQL Anywhere compatible format

        FORMAT: 'YYYY-MM-DD HH:MM:SS' for SQL Anywhere datetime filtering

        */

        // Convert Power Query datetime to SQL string format

        StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

        EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

        // ========================================================================

        // STEP 3: SQL QUERY CONSTRUCTION WITH FIELD MAPPING

        // ========================================================================

        /*

        PURPOSE: Extract essential transaction data with standardized column names

        STRATEGY: Server-side filtering for performance, column aliasing for consistency

        FIELDS: Core transaction data required for downstream fact table construction

        */

        // Construct parameterized SQL query with date filtering

        SQL =

        "SELECT #(lf)

            Trans_Datetime AS TransDatetime, #(lf)          -- Transaction timestamp (PRIMARY DATE)

            BRANCH AS Branch, #(lf)                         -- Location identifier for territory analysis

            customer_no AS CustomerNo, #(lf)                -- Customer account for customer analysis

            FRANCHISE AS Franchise, #(lf)                   -- Equipment manufacturer/brand

            PART_NO AS PartNumber, #(lf)                    -- Parts inventory identifier

            DESCRIPTION AS Description, #(lf)               -- Parts description for reporting

            QTY AS Qty, #(lf)                              -- Transaction quantity (+ sales, - returns)

            TYPE AS Type, #(lf)                            -- Transaction type classification

            TRADE_TYPE AS TradeType, #(lf)                 -- Customer trade classification

            REF_NO AS RONumber, #(lf)                      -- ⚠️ INVOICE NUMBER (not work order!)

            JOB_CODE AS JobCode, #(lf)                     -- Work order job code for linkage

            JOB_TYPE AS JobType, #(lf)                     -- Work order job type for linkage

            SALE_VAL AS SaleValue, #(lf)                   -- Transaction revenue amount

            COST_VAL AS CostValue, #(lf)                   -- Transaction cost for margin calculation

            SELL_PRICE1 AS SellPrice1, #(lf)               -- Standard selling price

            LIST_PRICE AS ListPrice #(lf)                  -- Manufacturer list price

        FROM InTrans #(lf)

        WHERE Trans_Datetime >= " & StartStr & " #(lf)     -- Date range filter (start)

          AND Trans_Datetime < " & EndStr,                

        // ========================================================================

        // STEP 4: ODBC QUERY EXECUTION

        // ========================================================================

        /*

        PURPOSE: Execute SQL query against SQL Anywhere database

        CONNECTION: Uses pre-configured DSN for database connection

        PERFORMANCE: Server-side date filtering minimizes data transfer

        */

        Source = Odbc.Query("dsn=EquipRDB64", SQL)

    in

        Source

in

    Source

  

/*

============================================================================

📊 FIELD DEFINITIONS & BUSINESS CONTEXT

============================================================================

  

🕒 DATE & TIME FIELDS:

• TransDatetime: Transaction timestamp (primary date for time analysis)

  

🏢 LOCATION & ORGANIZATION:

• Branch: Physical location where transaction occurred

• Franchise: Equipment manufacturer/brand (John Deere, Case, Caterpillar, etc.)

  

👥 CUSTOMER FIELDS:

• CustomerNo: Customer account number for customer analysis

• TradeType: Customer trade classification (C=Customer, W=Warranty, etc.)

  

📦 INVENTORY FIELDS:

• PartNumber: Parts inventory identifier (links to parts master)

• Description: Human-readable parts description

• Qty: Transaction quantity (positive=sale, negative=return)

  

💰 FINANCIAL FIELDS:

• SaleValue: Actual transaction revenue amount

• CostValue: Cost basis for margin calculations

• SellPrice1: Standard selling price for pricing analysis

• ListPrice: Manufacturer suggested retail price

  

🔧 WORK ORDER INTEGRATION:

• RONumber: Invoice number (despite name, this is NOT work order number!)

• JobCode: Specific job code within work order

• JobType: Job type classification (R=Retail, W=Warranty, etc.)

• Type: Transaction type classification

  

============================================================================

🔗 INTEGRATION PATTERNS

============================================================================

  

WORK ORDER PARTS ANALYSIS:

InTrans → (Branch + RONumber + JobCode + JobType) → wkothsub → Work Orders

  

CUSTOMER ANALYSIS:

InTrans → (CustomerNo) → Customer Master → Customer Analytics

  

PARTS ANALYSIS:

InTrans → (PartNumber) → Parts Master → Inventory Analytics

  

FINANCIAL ANALYSIS:

InTrans → (SaleValue - CostValue) → Margin Analysis → Profitability Reports

  

============================================================================

🚀 FUTURE ENHANCEMENTS

============================================================================

  

FIELD NAMING STANDARDIZATION:

• RONumber → InvoiceNumber (requires coordination with dependent queries)

• Standardize all field names across raw tables

• Implement consistent naming conventions

  

INCREMENTAL REFRESH:

• Implement true incremental refresh using ModifiedDate

• Optimize date range based on business requirements

• Consider change data capture for real-time updates

  

PERFORMANCE OPTIMIZATION:

• Add additional filtering criteria if needed

• Consider columnstore indexing on source tables

• Implement parallel processing for large date ranges

  

DATA QUALITY:

• Add data validation rules

• Implement null handling strategies  

• Add business rule validation

  

============================================================================

*/