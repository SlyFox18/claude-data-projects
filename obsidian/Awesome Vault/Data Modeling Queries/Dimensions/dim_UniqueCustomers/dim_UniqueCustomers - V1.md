let

    // Define updated unique customers with Dell City and Tornillo split

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

            {1, "Pearsall", "InTrans", "TradeType", "D", true, #date(2025, 7, 31)},

            {2, "Dell City", "InTrans", "TradeType + Branch", "T and Branch <> 2", true, #date(2025, 8, 4)},

            {3, "Tornillo", "InTrans", "TradeType + Branch", "T and Branch = 2", true, #date(2025, 8, 4)},

            {4, "Manuel/MR Tractor", "Invoice", "CustomerOrderNumber", "Contains MANUEL or MR TRACTOR", true, #date(2025, 7, 31)},

            {5, "Jim Justice", "Invoice", "CustomerOrderNumber + Branch", "Contains JIM and Branch = 94", true, #date(2025, 7, 31)},

            {6, "David Arizmendi", "Invoice", "CustomerOrderNumber + Branch", "Contains DAVID and Branch = 92", true, #date(2025, 7, 31)}

        }

    ),

  

    // Set proper data types

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