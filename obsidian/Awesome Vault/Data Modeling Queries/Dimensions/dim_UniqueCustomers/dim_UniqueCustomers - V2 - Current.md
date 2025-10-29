let

    /*

    ================================================================================================

    DIMENSION: dim_UniqueCustomers

    ================================================================================================

    PURPOSE:

    Master reference table defining unique customers for parts sales reporting. This dimension

    supports a dual-fact-table architecture where customer transactions come from two different

    source systems (InTrans and Invoice) with varying identification methods.

    BUSINESS CONTEXT:

    - Tracks sales, margins, and performance for specific high-value customers

    - Enables YTD vs PYTD comparisons across different customer identification patterns

    - Supports both location-based customers (Pearsall, Dell City, Tornillo) and individual

      customers (Manuel, Jim, David, etc.)

    IDENTIFICATION METHODS:

    1. TradeType: Uses ArMaster_Customer.TradeType to identify location-based customers

    2. TradeType + Branch: Splits Dell City/Tornillo by branch location  

    3. CustomerOrderNumber: Text search in Invoice.CustomerOrderNumber field

    4. CustomerOrderNumber + Branch: Text search with specific branch restriction

    5. CustomerNo: Direct match on InTrans.CustomerNo for individual customers

    FACT TABLE RELATIONSHIPS:

    - Fact_InTrans_UniqueCustomers: Links via CustomerKey (customers 1-3, 7-9)

    - Fact_Invoice_UniqueCustomers: Links via CustomerKey (customers 4-6)

    MAINTENANCE NOTES:

    - When adding customers, increment CustomerKey sequentially

    - Update corresponding fact table logic for customer identification

    - CreatedDate tracks when customer was added to dimension

    - IsActive flag allows for soft deletes without breaking historical reporting

    ================================================================================================

    */

    // Define updated unique customers with new individual customers added

    CustomersTable = #table(

        {

            "CustomerKey",

            "CustomerName",

            "DataSource",

            "IdentificationMethod",

            "IdentificationRule",

            "IsActive",

            "CreatedDate"

        },

        {

            // Location-based customers (InTrans TradeType identification)

            {1, "Pearsall", "InTrans", "TradeType", "D", true, #date(2025, 7, 31)},

            {2, "Dell City", "InTrans", "TradeType + Branch", "T and Branch <> 2", true, #date(2025, 8, 4)},

            {3, "Tornillo", "InTrans", "TradeType + Branch", "T and Branch = 2", true, #date(2025, 8, 4)},

            // Invoice-based customers (CustomerOrderNumber identification)

            {4, "Manuel/MR Tractor", "Invoice", "CustomerOrderNumber", "Contains MANUEL or MR TRACTOR", true, #date(2025, 7, 31)},

            {5, "Jim Justice", "Invoice", "CustomerOrderNumber + Branch", "Contains JIM and Branch = 94", true, #date(2025, 7, 31)},

            {6, "David Arizmendi", "Invoice", "CustomerOrderNumber + Branch", "Contains DAVID and Branch = 92", true, #date(2025, 7, 31)},

            // Individual customers (InTrans CustomerNo identification)

            {7, "Dallyn Clements", "InTrans", "CustomerNo", "36192", true, #date(2025, 9, 22)},

            {8, "Benny Gray", "InTrans", "CustomerNo", "38845", true, #date(2025, 9, 22)},

            {9, "Owen Bros.", "InTrans", "CustomerNo", "61055", true, #date(2025, 9, 22)}

        }

    ),

  

    // Set proper data types for all columns

    TypedTable = Table.TransformColumnTypes(CustomersTable, {

        {"CustomerKey", Int64.Type},

        {"CustomerName", type text},

        {"DataSource", type text},

        {"IdentificationMethod", type text},

        {"IdentificationRule", type text},

        {"IsActive", type logical},

        {"CreatedDate", type date}

    })

in

    TypedTable