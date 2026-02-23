/*
============================================================================
LOOKUP_UNIQUECUSTOMERS - ALL UNIQUE CUSTOMER GROUPS
============================================================================

Purpose: Lookup table mapping CustomerNumber to UniqueCustomerGroup for
         ALL 11 unique customer groups across 3 identification methods.
Grain: One row per unique CustomerNumber
Source: Invoice + InTrans_Incremental + ArMaster_Customer (Lakehouse)
Refresh: Daily (before Customer Anatomy semantic model refresh)

CUSTOMER GROUPS:
  Invoice-Based (CustomerOrderNumber patterns):
    - Manuel/MR Tractor (300): Contains "MANUEL" or "MR TRACTOR"
    - Jim Justice (87): Contains "JIM" AND Branch = "94"
    - David Arizmendi (59): Contains "DAVID" AND Branch = "92"
    - Oscar (11): Contains "*OSCAR" (asterisk is literal)
    - Danny G (2): Contains "*DANNY G" (asterisk is literal)

  InTrans-Based (TradeType):
    - Pearsall (10): TradeType = "D"
    - Dell City (18): TradeType = "T", predominant Branch != "2"
    - Tornillo (23): TradeType = "T", predominant Branch = "2"

  InTrans-Based (Direct CustomerNumber):
    - Dallyn Clements (1): CustomerNumber = "36192"
    - Benny Gray (1): CustomerNumber = "38845"
    - Owen Bros. (1): CustomerNumber = "61055"

============================================================================
*/

let
    // ================================================================
    // PART 1: INVOICE-BASED CUSTOMERS (CustomerOrderNumber patterns)
    // ================================================================

    InvoiceSource = Invoice,

    FilterInvoicePatterns = Table.SelectRows(InvoiceSource, each
        let
            upper = Text.Upper([CustomerOrderNumber] ?? "")
        in
            Text.Contains(upper, "MANUEL")
            or Text.Contains(upper, "MR TRACTOR")
            or (Text.Contains(upper, "JIM") and [Branch] = "94")
            or (Text.Contains(upper, "DAVID") and [Branch] = "92")
            or Text.Contains(upper, "*DANNY G")
            or Text.Contains(upper, "*OSCAR")
    ),

    AddInvoiceGroup = Table.AddColumn(FilterInvoicePatterns, "UniqueCustomerGroup", each
        let
            upper = Text.Upper([CustomerOrderNumber] ?? "")
        in
            if Text.Contains(upper, "MANUEL") or Text.Contains(upper, "MR TRACTOR")
                then "Manuel/MR Tractor"
            else if Text.Contains(upper, "JIM") and [Branch] = "94"
                then "Jim Justice"
            else if Text.Contains(upper, "DAVID") and [Branch] = "92"
                then "David Arizmendi"
            else if Text.Contains(upper, "*DANNY G")
                then "Danny G"
            else if Text.Contains(upper, "*OSCAR")
                then "Oscar"
            else null,
        type text
    ),

    InvoiceCustomers = Table.Distinct(
        Table.SelectColumns(AddInvoiceGroup, {"CustomerNumber", "UniqueCustomerGroup"}),
        {"CustomerNumber"}
    ),

    // ================================================================
    // PART 2: TRADETYPE-BASED CUSTOMERS (Pearsall, Dell City, Tornillo)
    // ================================================================

    // Get TradeType D and T customers from ArMaster
    ArSource = ArMaster_Customer,

    FilterTradeTypes = Table.SelectRows(ArSource, each
        [TradeType] = "D" or [TradeType] = "T"
    ),

    TradeTypeCustomers = Table.Distinct(
        Table.SelectColumns(FilterTradeTypes, {"CustomerNumber", "TradeType"}),
        {"CustomerNumber", "TradeType"}
    ),

    // Convert CustomerNumber to text for joining
    TradeTypeText = Table.TransformColumnTypes(TradeTypeCustomers, {
        {"CustomerNumber", type text}
    }),

    // For TradeType D: Label as Pearsall
    PearsallCustomers = Table.SelectRows(TradeTypeText, each [TradeType] = "D"),
    PearsallLabeled = Table.AddColumn(PearsallCustomers, "UniqueCustomerGroup", each "Pearsall", type text),
    PearsallFinal = Table.SelectColumns(PearsallLabeled, {"CustomerNumber", "UniqueCustomerGroup"}),

    // For TradeType T: Need branch split from InTrans
    TradeTypeTCustomers = Table.SelectRows(TradeTypeText, each [TradeType] = "T"),

    InTransSource = InTrans_Incremental,

    // Join TradeType T customers to InTrans to get Branch
    TradeTypeTWithBranch = Table.NestedJoin(
        TradeTypeTCustomers,
        {"CustomerNumber"},
        InTransSource,
        {"CustomerNo"},
        "InTransMatch",
        JoinKind.Inner
    ),

    ExpandBranch = Table.ExpandTableColumn(
        TradeTypeTWithBranch, "InTransMatch", {"Branch"}, {"InTransBranch"}
    ),

    // Add group based on branch
    AddBranchGroup = Table.AddColumn(ExpandBranch, "UniqueCustomerGroup", each
        if [InTransBranch] = "2" then "Tornillo" else "Dell City",
        type text
    ),

    // Count transactions per customer per group to find predominant
    GroupedByCustomer = Table.Group(
        AddBranchGroup,
        {"CustomerNumber", "UniqueCustomerGroup"},
        {{"Count", each Table.RowCount(_), Int64.Type}}
    ),

    // Sort by count descending, then deduplicate to keep predominant group
    SortedByCount = Table.Sort(GroupedByCustomer, {{"CustomerNumber", Order.Ascending}, {"Count", Order.Descending}}),
    DellCityTornilloFinal = Table.SelectColumns(
        Table.Distinct(SortedByCount, {"CustomerNumber"}),
        {"CustomerNumber", "UniqueCustomerGroup"}
    ),

    // ================================================================
    // PART 3: DIRECT CUSTOMERNUMBER CUSTOMERS
    // ================================================================

    DirectCustomers = Table.FromRecords({
        [CustomerNumber = "36192", UniqueCustomerGroup = "Dallyn Clements"],
        [CustomerNumber = "38845", UniqueCustomerGroup = "Benny Gray"],
        [CustomerNumber = "61055", UniqueCustomerGroup = "Owen Bros."]
    }),

    DirectCustomersTyped = Table.TransformColumnTypes(DirectCustomers, {
        {"CustomerNumber", type text},
        {"UniqueCustomerGroup", type text}
    }),

    // ================================================================
    // COMBINE ALL THREE SOURCES
    // ================================================================

    CombineAll = Table.Combine({
        InvoiceCustomers,
        PearsallFinal,
        DellCityTornilloFinal,
        DirectCustomersTyped
    }),

    // Final deduplication (priority: Invoice > TradeType > Direct)
    FinalDedup = Table.Distinct(CombineAll, {"CustomerNumber"}),

    SetTypes = Table.TransformColumnTypes(FinalDedup, {
        {"CustomerNumber", type text},
        {"UniqueCustomerGroup", type text}
    })

in
    SetTypes