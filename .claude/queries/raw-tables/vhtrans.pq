/*
============================================================================
Query: VhTrans (Raw)
Dataflow: df_VhTrans_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Vehicle/Equipment transaction history - tracks all cost activities for sold units
Created: 01/28/2026
Last Modified: 01/28/2026
Output: Lakehouse table "vhtrans"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: [TBD - recommend aligning with VhStock refresh]
Average Refresh Time: [TBD - monitor initial refresh]
Refresh Strategy: Full refresh with 3-year date filter (2022+) - matches VhStock scope
Row Count: [TBD - check after initial load]
Query Folding: ✅ YES (SQL query with column aliasing)

🎯 BUSINESS USE CASES:
• Customer Anatomy Report: After-sales activity costs (where AfterSalesActivity = 'Y')
• Equipment Sales Analysis: Complete cost breakdown for sold units
• Post-Sale Cost Tracking: Repairs, accessories, and other costs after initial sale
• Financial Reconciliation: GST tracking, floor plan values, unit debtors
• Period Reporting: Cost allocation by accounting period

📊 DATA STRUCTURE (45 COLUMNS):

**Transaction Identification:**
• StockNumber: Equipment stock number (links to VhStock.NO)
• TransactionId: Unique transaction identifier
• TransactionDate: Date of transaction
• Type: Transaction type code
• ReferenceNumber: Transaction reference number
• Description: Transaction description

**Document & Period:**
• DocumentDate: Document date
• PeriodDate: Accounting period date
• Period: Accounting period number
• PriorYear: Prior year indicator

**Cost Components (14 fields) - CRITICAL FOR CUSTOMER ANATOMY:**
• PredeliveryCost: Pre-delivery inspection costs
• RepairCost: Repair and reconditioning costs
• AccessoryCost: Accessory costs
• OtherCost: Other miscellaneous costs
• WholesaleCost: Wholesale cost component
• RetailCost: Retail cost component
• OptionCost: Optional equipment costs
• PaintCost: Paint/body costs
• TrimCost: Interior trim costs
• ChargeCost: Charge costs
• AfterMarketCost: Aftermarket accessory costs
• SurchargeCost: Surcharge costs
• RegistrationFees: Registration/rego fees
• LotFees: Lot/auction fees
• StampDuty: Stamp duty
• TransferFees: Transfer fees

**Financial Tracking:**
• FloorValue: Floor plan value
• UnitDebtors: Unit debtors amount
• GSTIn: GST input (purchases)
• GSTOut: GST output (sales)
• SalesInvoice: Sales invoice reference
• CapitalizedInterest: Capitalized interest amount
• RentalDepreciationMemo: Rental depreciation memo amount
• ExpenseCode: Expense classification code
• ExpenseValue: Expense amount

**Activity Classification:**
• AfterSalesActivity: After-sales activity flag ('Y'/'N') - KEY FOR CUSTOMER ANATOMY
• AllocatedIndicator: Allocation indicator ('Y'/'N')
• Company: Company code

**Trade-In Integration:**
• TJSequenceNumber: Trade-in journal sequence number
• TJCancelNumber: Trade-in journal cancellation number
• TJXML: Trade-in journal XML data

**Audit Trail:**
• CreationDate: Record creation date
• CreatedBy: Created by user
• ModifiedDate: Last modification date
• ModifiedBy: Modified by user

⚠️ CRITICAL FOR CUSTOMER ANATOMY:
The AfterSalesActivity field (after_sales_act = 'Y') is used in Customer Anatomy
Sales calculations to add post-sale costs to the total cost of equipment sold.

From Sales_Data_YTD.pq:
- Sums: wholesale + retail + predel_cost + repair_cost + access_cost + rego_fees +
        lot_fees + transfer_fees + other_cost + option_cost + paint_cost +
        trim_cost + charge_cost + after_market_cost
- WHERE: stock_no = vhstock.no AND after_sales_act = 'Y'

Dependencies:
• Links to VhStock via StockNumber = VhStock.StockNumber (NO column)

Used By:
• Customer Anatomy Report (Equipment Sales cost calculations)
• Fact_Equipment_Sales (for complete cost analysis)
• Equipment profitability analysis

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - 3-YEAR SCOPE
    // ========================================================================

    // Define date range (3-year window to match VhStock scope)
    RangeStart = #datetime(2022, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL string format
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd") & "'",

    // ========================================================================
    // VHTRANS EXTRACTION WITH STANDARDIZED NAMING
    // ========================================================================
    /*
    STRATEGY: Extract complete vehicle transaction data with standardized column names
    APPROACH: Direct query with column aliasing for PascalCase consistency
    KEY FIELD: AfterSalesActivity - used by Customer Anatomy for post-sale costs
    DATE FILTER: 3-year scope (2022+) to match VhStock refresh strategy
    */

    SQL = "
        SELECT
            -- ===== TRANSACTION IDENTIFICATION =====
            stock_no AS StockNumber,
            trans_id AS TransactionId,
            vhtrans_date AS TransactionDate,
            type AS Type,
            ref AS ReferenceNumber,
            description AS Description,

            -- ===== DOCUMENT & PERIOD =====
            doc_date AS DocumentDate,
            period_date AS PeriodDate,
            period AS Period,
            prior_year AS PriorYear,

            -- ===== COST COMPONENTS (14 FIELDS) =====
            predel_cost AS PredeliveryCost,
            repair_cost AS RepairCost,
            access_cost AS AccessoryCost,
            other_cost AS OtherCost,
            wholesale AS WholesaleCost,
            retail AS RetailCost,
            Option_Cost AS OptionCost,
            Paint_Cost AS PaintCost,
            Trim_Cost AS TrimCost,
            Charge_Cost AS ChargeCost,
            After_Market_Cost AS AfterMarketCost,
            Surcharge_Cost AS SurchargeCost,

            -- ===== FEES =====
            rego_fees AS RegistrationFees,
            lot_fees AS LotFees,
            stamp_duty AS StampDuty,
            transfer_fees AS TransferFees,

            -- ===== FINANCIAL TRACKING =====
            floorval AS FloorValue,
            unit_debtors AS UnitDebtors,
            gst_in AS GSTIn,
            gst_out AS GSTOut,
            sales_inv AS SalesInvoice,
            Capitalized_Interest AS CapitalizedInterest,
            Rental_Depreciation_Memo AS RentalDepreciationMemo,
            Expense_Code AS ExpenseCode,
            Expense_Value AS ExpenseValue,

            -- ===== ACTIVITY CLASSIFICATION =====
            after_sales_act AS AfterSalesActivity,
            Allocated_Ind AS AllocatedIndicator,
            Company AS Company,

            -- ===== TRADE-IN INTEGRATION =====
            tj_seqno AS TJSequenceNumber,
            tj_cancel_no AS TJCancelNumber,
            tj_xml AS TJXML,

            -- ===== AUDIT TRAIL =====
            CreationDate AS CreationDate,
            CreatedBy AS CreatedBy,
            ModifiedDate AS ModifiedDate,
            ModifiedBy AS ModifiedBy

        FROM VhTrans
        WHERE vhtrans_date >= " & StartStr & "
          AND vhtrans_date < " & EndStr & "
    ",

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in
    Source

/*
============================================================================
✅ PRODUCTION STATUS: NEW - CREATED FOR CUSTOMER ANATOMY SUPPORT
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Column Set: All 45 VhTrans fields included
• Standardized Naming: Applied consistent PascalCase conventions
• Key Business Field: AfterSalesActivity for post-sale cost identification
• Audit Trail: CreationDate, CreatedBy, ModifiedDate, ModifiedBy included

🔗 CUSTOMER ANATOMY INTEGRATION:

**How VhTrans is Used in Sales Calculations:**
1. Join VhTrans to VhStock on StockNumber
2. Filter: AfterSalesActivity = 'Y' (after-sales transactions only)
3. Sum cost components for each sold unit:
   - WholesaleCost + RetailCost
   - PredeliveryCost + RepairCost + AccessoryCost + OtherCost
   - RegistrationFees + LotFees + StampDuty + TransferFees
   - OptionCost + PaintCost + TrimCost + ChargeCost + AfterMarketCost

**DAX Pattern for Fact_Equipment_Sales:**
```dax
After Sales Cost =
CALCULATE(
    SUMX(
        RELATEDTABLE(VhTrans),
        [WholesaleCost] + [RetailCost] + [PredeliveryCost] + [RepairCost] +
        [AccessoryCost] + [OtherCost] + [RegistrationFees] + [LotFees] +
        [TransferFees] + [OptionCost] + [PaintCost] + [TrimCost] +
        [ChargeCost] + [AfterMarketCost]
    ),
    VhTrans[AfterSalesActivity] = "Y"
)
```

⚡ OPTIMIZATION CONSIDERATIONS:

**If Row Count is Large:**
• Consider incremental refresh using ModifiedDate
• Filter by date range if historical data not needed
• Index TransactionDate and StockNumber in source

**Refresh Alignment:**
• Should refresh with or after VhStock
• Both tables needed for complete equipment sales analysis

============================================================================
*/
