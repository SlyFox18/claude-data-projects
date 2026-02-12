/*
============================================================================
FACT_SERVICE_PARTS_DETAIL - PARTS LINE ITEMS FOR SERVICE INVOICES
============================================================================

Purpose: Parts transaction data for service work order invoices
Grain: One row per parts transaction line item from service invoices
Source: InTrans_Incremental (Lakehouse), filtered to service invoices
Refresh Strategy: Full refresh

BUSINESS USE CASES:
- Service Invoice Drill-Through: Show parts sold on each service invoice
- Parts Revenue on Service: Track parts sold alongside labor
- Discount Tracking: ADV, Trucking, Promotional discounts (Franchise = ZP)

RELATIONSHIP:
- Fact_Service_Parts_Detail[InvoiceNumber] → Fact_Service_Invoices[InvoiceNumber]
- Cross-filter: Both Directions (enables drill-through)

============================================================================
*/

let
    // ========================================================================
    // STEP 1: IDENTIFY SERVICE INVOICES (MODULE TYPE = 'W')
    // ========================================================================
    
    ServiceInvoices = 
        let
            Source = Invoice,
            FilterService = Table.SelectRows(Source, each 
                [ModuleType] = "W" and 
                [InvoiceDate] >= #datetime(2022, 1, 1, 0, 0, 0)
            ),
            DistinctInvoices = Table.Distinct(
                Table.SelectColumns(FilterService, {"Branch", "InvoiceNumber"})
            ),
            ConvertTypes = Table.TransformColumnTypes(DistinctInvoices, {
                {"Branch", type text},
                {"InvoiceNumber", type text}
            })
        in
            ConvertTypes,

    // ========================================================================
    // STEP 2: LOAD PARTS TRANSACTIONS FROM INTRANS_INCREMENTAL
    // ========================================================================
    
    PartsSource = InTrans_Incremental,
    
    PartsWithTextTypes = Table.TransformColumnTypes(PartsSource, {
        {"Branch", type text},
        {"RONumber", type text}
    }),

    // ========================================================================
    // STEP 3: FILTER TO SERVICE INVOICES
    // ========================================================================
    
    FilterToServiceInvoices = Table.NestedJoin(
        PartsWithTextTypes,
        {"Branch", "RONumber"},
        ServiceInvoices,
        {"Branch", "InvoiceNumber"},
        "ServiceMatch",
        JoinKind.Inner
    ),
    
    RemoveMatchTable = Table.RemoveColumns(FilterToServiceInvoices, {"ServiceMatch"}),

    // ========================================================================
    // STEP 4: RENAME COLUMNS FOR CONSISTENCY
    // ========================================================================
    
    RenameColumns = Table.RenameColumns(RemoveMatchTable, {
        {"Branch", "BranchCode"},
        {"RONumber", "InvoiceNumber"},
        {"TransDatetime", "TransactionDate"},
        {"Qty", "Quantity"},
        {"CustomerNo", "CustomerNumber"},
        {"SellPrice1", "SellPrice"}
    }),

    // ========================================================================
    // STEP 5: SELECT AND ORDER COLUMNS
    // ========================================================================
    
    SelectColumns = Table.SelectColumns(RenameColumns, {
        "BranchCode",
        "InvoiceNumber",
        "TransactionDate",
        "PartNumber",
        "Description",
        "Franchise",
        "Quantity",
        "SaleValue",
        "CostValue",
        "SellPrice",
        "ListPrice",
        "CustomerNumber",
        "TradeType"
    }),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================
    
    SetDataTypes = Table.TransformColumnTypes(SelectColumns, {
        {"BranchCode", type text},
        {"InvoiceNumber", type text},
        {"TransactionDate", type date},
        {"PartNumber", type text},
        {"Description", type text},
        {"Franchise", type text},
        {"Quantity", type number},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"SellPrice", type number},
        {"ListPrice", type number},
        {"CustomerNumber", type text},
        {"TradeType", type text}
    }),

    // ========================================================================
    // STEP 7: REMOVE DUPLICATES
    // ========================================================================
    
    RemoveDuplicates = Table.Distinct(SetDataTypes, {
        "BranchCode", 
        "InvoiceNumber", 
        "PartNumber", 
        "TransactionDate", 
        "Quantity", 
        "SaleValue"
    })

in
    RemoveDuplicates
