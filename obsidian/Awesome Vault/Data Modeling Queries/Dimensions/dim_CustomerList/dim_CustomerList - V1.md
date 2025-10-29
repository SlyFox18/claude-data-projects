// Enhanced dim_CustomerList - Working with Current Field Names

let

    // Step 1: Start with ArMaster as the base table

    ArMaster = Raw_ARMaster,

    // Step 2: INNER JOIN with Contact using ContactID

    JoinArMasterContact = Table.NestedJoin(

        ArMaster, {"ContactID"},

        Raw_Contact, {"ContactID"},

        "ContactInfo", JoinKind.Inner),

    ExpandContact = Table.ExpandTableColumn(JoinArMasterContact, "ContactInfo", {

        "LastName", "FirstName", "CompanyName", "BusinessPhone", "MobilePhone",

        "Email", "Street", "City", "State", "PostalCode", "Country"

    }),

    // Step 3: INNER JOIN with ArMaster_Customer using ContactID

    JoinCustomerMaster = Table.NestedJoin(

        ExpandContact, {"ContactID"},

        Raw_ArMaster_Customer, {"ContactID"},

        "CustomerInfo", JoinKind.Inner),

    ExpandCustomerMaster = Table.ExpandTableColumn(JoinCustomerMaster, "CustomerInfo", {

        "CustomerNumber", "StatusCode", "AccountType", "TradeType", "DiscountType",

        "TaxExemptNumber", "Territory", "PriceLevel", "CustomerNotes"

    }),

    // Step 4: INNER JOIN with ArMaster_Contact - now with consistent ContactID

    JoinContactClass = Table.NestedJoin(

        ExpandCustomerMaster, {"ContactID"},

        Raw_ArMaster_Contact, {"ContactID"},  // ← Now using ContactID consistently

        "ContactClassInfo", JoinKind.Inner),

  

    ExpandContactClass = Table.ExpandTableColumn(JoinContactClass, "ContactClassInfo", {"ContactClass"}),

    // Step 5: Add surrogate key

    AddSurrogateKey = Table.AddIndexColumn(ExpandContactClass, "CustomerKey", 1, 1, Int64.Type),

    // Step 6: Build customer naming logic (exactly matching original SQL CASE statement)

    AddCustomerName = Table.AddColumn(AddSurrogateKey, "Customer", each

        if [CompanyName] <> null and [CompanyName] <> "" then [CompanyName]

        else [LastName] & ", " & [FirstName], type text),

    // Step 7: Add Key Customer flag and business classifications

    AddBusinessFields = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(

                Table.AddColumn(

                    Table.AddColumn(AddCustomerName,

                        "IsKeyCustomer", each [ContactClass] = "KEY", type logical),

                    "CustomerTypeDescription", each

                        if [TradeType] = "E" then "Excess"

                        else if [TradeType] = "F" then "Fleet"

                        else if [TradeType] = "I" then "Internal"

                        else if [TradeType] = "P" then "Policy"

                        else if [TradeType] = "B" then "Billing"

                        else if [TradeType] = "R" then "Retail"

                        else if [TradeType] = "S" then "Misc"

                        else if [TradeType] = "W" then "Warranty"

                        else if [TradeType] <> null and [TradeType] <> "" then [TradeType]

                        else "Unknown", type text),

                "AccountStatus", each

                    if [StatusCode] = "A" then "Active"

                    else if [StatusCode] = "I" then "Inactive"

                    else if [StatusCode] = "H" then "Hold"

                    else if [StatusCode] = "C" then "Closed"

                    else if [StatusCode] <> null and [StatusCode] <> "" then [StatusCode]

                    else "Unknown", type text),

            "IsCompany", each

                [CompanyName] <> null and [CompanyName] <> "", type logical),

        "HasCreditLimit", each

            [CreditLimit] <> null and [CreditLimit] > 0, type logical),

    // Step 7.5: Add Customer Risk & Financial Health Indicators

    AddFinancialHealth = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(AddBusinessFields,

                "CreditUtilization", each

                    if [CreditLimit] <> null and [CreditLimit] > 0

                    then [AccountBalance] / [CreditLimit]

                    else 0, type number),

            "FinancialRiskLevel", each

                if [CreditUtilization] > 0.9 then "High"

                else if [CreditUtilization] > 0.7 then "Medium"

                else if [CreditUtilization] > 0.5 then "Low"

                else "Minimal", type text),

        "HasOverdueBalance", each

            ([Aging30] <> null and [Aging30] > 0) or

            ([Aging60] <> null and [Aging60] > 0) or

            ([Aging90] <> null and [Aging90] > 0), type logical),

    // Step 7.6: Add Customer Value & Segmentation Tiers

    AddCustomerTiers = Table.AddColumn(

        Table.AddColumn(AddFinancialHealth,

            "CustomerTier", each

                if [IsKeyCustomer] then "Key Account"

                else if [CreditLimit] <> null and [CreditLimit] >= 50000 then "Premium"

                else if [CreditLimit] <> null and [CreditLimit] >= 10000 then "Standard"

                else "Basic", type text),

        "IsHighValue", each

            [CustomerTier] = "Key Account" or [CustomerTier] = "Premium", type logical),

    // Step 7.7: Add Communication & Marketing Readiness

    AddMarketingFlags = Table.AddColumn(

        Table.AddColumn(AddCustomerTiers,

            "IsMarketingEligible", each

                [Email] <> null and [Email] <> "" and [AccountStatus] = "Active", type logical),

        "PreferredContactMethod", each

            if [Email] <> null and [Email] <> "" then "Email"

            else if [MobilePhone] <> null and [MobilePhone] <> "" then "Mobile"

            else if [BusinessPhone] <> null and [BusinessPhone] <> "" then "Business Phone"

            else "Mail", type text),

    // Step 8: Add derived fields for enhanced reporting

    AddDerivedFields = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(

                Table.AddColumn(AddMarketingFlags,

                    "FullName", each

                        if [FirstName] <> null and [LastName] <> null and [FirstName] <> "" and [LastName] <> ""

                        then [FirstName] & " " & [LastName]

                        else if [LastName] <> null and [LastName] <> "" then [LastName]  

                        else if [FirstName] <> null and [FirstName] <> "" then [FirstName]

                        else "", type text),

                "PrimaryName", each

                    if [CompanyName] <> null and [CompanyName] <> "" then [CompanyName]

                    else if [Customer] <> null and [Customer] <> "" then [Customer]

                    else "Account " & Text.From([AccountNumber]), type text),

            "DisplayName", each

                if [PrimaryName] <> null and [PrimaryName] <> ("Account " & Text.From([AccountNumber])) then [PrimaryName]

                else [CustomerTypeDescription] & " " & Text.From([AccountNumber]), type text),

        "PrimaryPhone", each

            if [MobilePhone] <> null and [MobilePhone] <> "" then [MobilePhone]

            else if [BusinessPhone] <> null and [BusinessPhone] <> "" then [BusinessPhone]

            else "", type text),

    // Step 9: Clean and standardize text fields

    CleanTextFields = Table.TransformColumns(AddDerivedFields, {

        {"Customer", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"CompanyName", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"FirstName", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"LastName", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"Street", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"City", each Text.Proper(Text.Trim(_ ?? "")), type text},

        {"State", each Text.Upper(Text.Trim(_ ?? "")), type text},

        {"PostalCode", each Text.Trim(_ ?? ""), type text},

        {"Email", each Text.Lower(Text.Trim(_ ?? "")), type text},

        {"TradeType", each Text.Upper(Text.Trim(_ ?? "")), type text},

        {"ContactClass", each Text.Upper(Text.Trim(_ ?? "")), type text}

    }),

    // Step 10: Add text versions of numeric fields for lookups

    AddTextFields = Table.AddColumn(

        Table.AddColumn(CleanTextFields,

            "AccountNumberText", each Text.From([AccountNumber]), type text),

        "CustomerNumberText", each

            if [CustomerNumber] <> null then Text.From([CustomerNumber]) else "", type text),

    // Step 11: Add missing columns to match original structure

    AddMissingColumns = Table.AddColumn(

        Table.AddColumn(AddTextFields, "Street2", each "", type text),

        "HomePhone", each "", type text),

    // Step 12: Add Account_Class field placeholder

    AddAccountClass = Table.AddColumn(AddMissingColumns, "Account_Class", each "", type text),

    // Step 13: Select final columns matching your desired structure

    SelectFinalColumns = Table.SelectColumns(AddAccountClass, {

        "CustomerKey", "AccountNumber", "AccountNumberText", "CustomerNumber", "CustomerNumberText", "ContactID",

        "DisplayName", "Customer", "PrimaryName", "CompanyName", "FirstName", "LastName", "FullName",

        "TradeType", "CustomerTypeDescription", "StatusCode", "AccountStatus", "AccountType", "Territory",

        "CreditLimit", "AccountBalance", "Aging30", "Aging60", "Aging90", "CreditTerm", "PaymentMethod", "PriceLevel",

        "Street", "Street2", "City", "State", "PostalCode", "Country",

        "Email", "PrimaryPhone", "BusinessPhone", "MobilePhone", "HomePhone",

        "IsCompany", "HasCreditLimit", "Account_Class", "ContactClass", "IsKeyCustomer",

        "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance",

        "CustomerTier", "IsHighValue", "IsMarketingEligible", "PreferredContactMethod",

        "DiscountType", "TaxExemptNumber", "CustomerNotes"

    }),

    // Step 14: Rename Customer column to CustomerName for consistency

    RenameCustomerColumn = Table.RenameColumns(SelectFinalColumns, {{"Customer", "CustomerName"}}),

    // Step 15: Set final data types

    SetDataTypes = Table.TransformColumnTypes(RenameCustomerColumn, {

        {"CustomerKey", Int64.Type}, {"AccountNumber", type text}, {"AccountNumberText", type text},

        {"CustomerNumber", type text}, {"CustomerNumberText", type text}, {"ContactID", type text},

        {"DisplayName", type text}, {"CustomerName", type text}, {"PrimaryName", type text},

        {"CompanyName", type text}, {"FirstName", type text}, {"LastName", type text}, {"FullName", type text},

        {"TradeType", type text}, {"CustomerTypeDescription", type text},

        {"StatusCode", type text}, {"AccountStatus", type text}, {"AccountType", type text}, {"Territory", type text},

        {"CreditLimit", type number}, {"AccountBalance", type number}, {"Aging30", type number}, {"Aging60", type number}, {"Aging90", type number}, {"CreditTerm", type text},

        {"PaymentMethod", type text}, {"PriceLevel", type text},

        {"Street", type text}, {"Street2", type text}, {"City", type text}, {"State", type text}, {"PostalCode", type text}, {"Country", type text},

        {"Email", type text}, {"PrimaryPhone", type text}, {"BusinessPhone", type text}, {"MobilePhone", type text}, {"HomePhone", type text},

        {"IsCompany", type logical}, {"HasCreditLimit", type logical}, {"Account_Class", type text}, {"ContactClass", type text}, {"IsKeyCustomer", type logical},

        {"CreditUtilization", type number}, {"FinancialRiskLevel", type text}, {"HasOverdueBalance", type logical},

        {"CustomerTier", type text}, {"IsHighValue", type logical}, {"IsMarketingEligible", type logical}, {"PreferredContactMethod", type text},

        {"DiscountType", type text}, {"TaxExemptNumber", type text}, {"CustomerNotes", type text}

    }),

    // Step 16: Sort by account number for consistency

    SortByAccount = Table.Sort(SetDataTypes, {{"AccountNumber", Order.Ascending}}),

    // Add your special customer records (keeping your existing logic)

    ExistingCustomerData = SortByAccount,

    // Create special customer records for system scenarios

    SpecialCustomers = Table.FromRows({

        {-1, "UNKNOWN", "UNKNOWN", "", "", "",

         "Unknown Customer", "Unknown Customer", "Unknown Customer", "Unknown Customer", "", "", "",

         "U", "Unknown", "", "Unknown", "", "",

         0, 0, 0, 0, 0, "", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-2, "INTERNAL", "INTERNAL", "", "", "",

         "Internal Work", "Internal Work", "Internal Work", "Internal", "", "", "",

         "I", "Internal", "A", "Active", "INT", "",

         null, null, null, null, null, "", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "INT", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-3, "WARRANTY", "WARRANTY", "", "", "",

         "Warranty Work", "Warranty Work", "Warranty Work", "Warranty", "", "", "",

         "W", "Warranty", "A", "Active", "WAR", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "WAR", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-4, "FLEET", "FLEET", "", "", "",

         "Fleet Account", "Fleet Account", "Fleet Account", "Fleet", "", "", "",

         "F", "Fleet", "A", "Active", "FLT", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "FLT", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-5, "EXCESS", "EXCESS", "", "", "",

         "Excess Work", "Excess Work", "Excess Work", "Excess", "", "", "",

         "E", "Excess", "A", "Active", "EXC", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "EXC", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-6, "POLICY", "POLICY", "", "", "",

         "Policy Work", "Policy Work", "Policy Work", "Policy", "", "", "",

         "P", "Policy", "A", "Active", "POL", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "POL", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-7, "BILLING", "BILLING", "", "", "",

         "Billing Account", "Billing Account", "Billing Account", "Billing", "", "", "",

         "B", "Billing", "A", "Active", "BIL", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "BIL", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""},

        {-8, "MISC", "MISC", "", "", "",

         "Miscellaneous", "Miscellaneous", "Miscellaneous", "Miscellaneous", "", "", "",

         "S", "Misc", "A", "Active", "MSC", "",

         null, null, null, null, null,"", "", "",

         "", "", "", "", "", "", "", "", "", "", "",

         false, false, "MSC", "", false, 0, "Minimal", false, "Basic", false, false, "Mail", "", "", ""}

    },

        {"CustomerKey", "AccountNumber", "AccountNumberText", "CustomerNumber", "CustomerNumberText", "ContactID",

        "DisplayName", "CustomerName", "PrimaryName", "CompanyName", "FirstName", "LastName", "FullName",

        "TradeType", "CustomerTypeDescription", "StatusCode", "AccountStatus", "AccountType", "Territory",

        "CreditLimit", "AccountBalance", "Aging30", "Aging60", "Aging90", "CreditTerm", "PaymentMethod", "PriceLevel",

        "Street", "Street2", "City", "State", "PostalCode", "Country",

        "Email", "PrimaryPhone", "BusinessPhone", "MobilePhone", "HomePhone",

        "IsCompany", "HasCreditLimit", "Account_Class", "ContactClass", "IsKeyCustomer",

        "CreditUtilization", "FinancialRiskLevel", "HasOverdueBalance",

        "CustomerTier", "IsHighValue", "IsMarketingEligible", "PreferredContactMethod",

        "DiscountType", "TaxExemptNumber", "CustomerNotes"}),

    // Convert special customers to proper types

    SpecialCustomersTyped = Table.TransformColumnTypes(SpecialCustomers, {

        {"CustomerKey", Int64.Type}, {"AccountNumber", type text}, {"AccountNumberText", type text},

        {"CustomerNumber", type text}, {"CustomerNumberText", type text}, {"ContactID", type text},

        {"DisplayName", type text}, {"CustomerName", type text}, {"PrimaryName", type text},

        {"CompanyName", type text}, {"FirstName", type text}, {"LastName", type text}, {"FullName", type text},

        {"TradeType", type text}, {"CustomerTypeDescription", type text},

        {"StatusCode", type text}, {"AccountStatus", type text}, {"AccountType", type text}, {"Territory", type text},

        {"CreditLimit", type number}, {"AccountBalance", type number}, {"Aging30", type number}, {"Aging60", type number}, {"Aging90", type number}, {"CreditTerm", type text},

        {"PaymentMethod", type text}, {"PriceLevel", type text},

        {"Street", type text}, {"Street2", type text}, {"City", type text}, {"State", type text}, {"PostalCode", type text}, {"Country", type text},

        {"Email", type text}, {"PrimaryPhone", type text}, {"BusinessPhone", type text}, {"MobilePhone", type text}, {"HomePhone", type text},

        {"IsCompany", type logical}, {"HasCreditLimit", type logical}, {"Account_Class", type text}, {"ContactClass", type text}, {"IsKeyCustomer", type logical},

        {"CreditUtilization", type number}, {"FinancialRiskLevel", type text}, {"HasOverdueBalance", type logical},

        {"CustomerTier", type text}, {"IsHighValue", type logical}, {"IsMarketingEligible", type logical}, {"PreferredContactMethod", type text},

        {"DiscountType", type text}, {"TaxExemptNumber", type text}, {"CustomerNotes", type text}}),

    // Combine special records with regular customers

    CombinedCustomers = Table.Combine({SpecialCustomersTyped, ExistingCustomerData}),

    // Final sort to put special records at top

    FinalSort = Table.Sort(CombinedCustomers, {{"CustomerKey", Order.Ascending}})

in

    FinalSort