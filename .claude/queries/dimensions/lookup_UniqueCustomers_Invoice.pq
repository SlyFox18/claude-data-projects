/*
============================================================================
LOOKUP_UNIQUECUSTOMERS_INVOICE - ALL UNIQUE CUSTOMER GROUPS
============================================================================

Purpose: Lookup table mapping CustomerNumber to UniqueCustomerGroup for
         ALL 11 unique customer groups across 3 identification methods.
Grain: One row per unique CustomerNumber
Source: Invoice + InTrans_Incremental + ArMaster_Customer (Lakehouse)
Result: ~513 distinct customer rows

Fabric Location:
  Dataflow: df_UniqueCustomer_Lookup
  Folder: LH_Master_Data / Dataflows / 03 - Dimensions
  Destination: LH_Master_Data.dbo.lookup_UniqueCustomers_Invoice

Used By: Customer Anatomy V2 report
  - dim_CustomerList[UniqueCustomerGroup] calculated column uses LOOKUPVALUE
    against this table (no relationship needed)
  - dim_CustomerList[IsUniqueCustomer] boolean flag derived from above
  - Customer Profile Card measure displays purple "UNIQUE" badge

CUSTOMER GROUPS (11 total):

  Invoice-Based (CustomerOrderNumber patterns):
    - Manuel/MR Tractor (300): Contains "MANUEL" or "MR TRACTOR"
    - Jim Justice (87): Contains "JIM" AND Branch = "94"
    - David Arizmendi (59): Contains "DAVID" AND Branch = "92"
    - Oscar (11): Contains "*OSCAR" (asterisk is literal)
    - Danny G (2): Contains "*DANNY G" (asterisk is literal)

  InTrans-Based (TradeType via ArMaster):
    - Dell City (18): TradeType = "T", predominant Branch != "2"
    - Tornillo (23): TradeType = "T", predominant Branch = "2"
    - Pearsall (10): TradeType = "D"

  Direct CustomerNumber:
    - Dallyn Clements (1): CustomerNumber = "36192"
    - Benny Gray (1): CustomerNumber = "38845"
    - Owen Bros. (1): CustomerNumber = "61055"

KNOWN EDGE CASES:
  - CustomerNumber 25227 matches both Manuel/MR Tractor and Oscar.
    Resolved to Manuel/MR Tractor by priority order.
  - 7 TradeType "T" customers transact at both Branch 2 and other branches.
    Assigned to predominant branch by transaction count.

MAINTENANCE:
  To add a new unique customer:
  1. Open dataflow df_UniqueCustomer_Lookup in LH_Master_Data / Dataflows / 03 - Dimensions
  2. Add identification logic to the appropriate section below
  3. Publish and refresh dataflow
  4. Refresh Customer Anatomy semantic model
  5. No DAX changes needed - LOOKUPVALUE auto-picks up new rows
  6. Also update dim_UniqueCustomers in the Unique Parts Customers report

DOCUMENTATION:
  - Customer Anatomy: projects/customer anatomy - report/UNIQUE-CUSTOMER-FLAGS.md
  - Unique Customers: projects/unique parts customers - report/CROSS-REPORT-FLAGS.md

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

    ArSource = ArMaster_Customer,

    FilterTradeTypes = Table.SelectRows(ArSource, each
        [TradeType] = "D" or [TradeType] = "T"
    ),

    TradeTypeCustomers = Table.Distinct(
        Table.SelectColumns(FilterTradeTypes, {"CustomerNumber", "TradeType"}),
        {"CustomerNumber", "TradeType"}
    ),

    TradeTypeText = Table.TransformColumnTypes(TradeTypeCustomers, {
        {"CustomerNumber", type text}
    }),

    // TradeType D: Label as Pearsall
    PearsallCustomers = Table.SelectRows(TradeTypeText, each [TradeType] = "D"),
    PearsallLabeled = Table.AddColumn(PearsallCustomers, "UniqueCustomerGroup", each "Pearsall", type text),
    PearsallFinal = Table.SelectColumns(PearsallLabeled, {"CustomerNumber", "UniqueCustomerGroup"}),

    // TradeType T: Split by predominant Branch (2 = Tornillo, other = Dell City)
    TradeTypeTCustomers = Table.SelectRows(TradeTypeText, each [TradeType] = "T"),

    InTransSource = InTrans_Incremental,

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

    AddBranchGroup = Table.AddColumn(ExpandBranch, "UniqueCustomerGroup", each
        if [InTransBranch] = "2" then "Tornillo" else "Dell City",
        type text
    ),

    GroupedByCustomer = Table.Group(
        AddBranchGroup,
        {"CustomerNumber", "UniqueCustomerGroup"},
        {{"Count", each Table.RowCount(_), Int64.Type}}
    ),

    SortedByCount = Table.Sort(GroupedByCustomer, {
        {"CustomerNumber", Order.Ascending},
        {"Count", Order.Descending}
    }),

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
