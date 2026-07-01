/*
============================================================================
Fact Table: Fact_MDInvoices_NoFreight
Dataflow:   df_Fact_MDInvoices_NoFreight
Location:   LH_Master_Data → Dataflows → 04 - Fact
============================================================================

📋 METADATA:
Purpose:  Line-item detail for open Machine Down (emergency) parts orders,
          with actual freight charged (part 3750 lines) aggregated at the
          order level. Supports the MD Invoices With No Freight report.
Grain:    One row per part line on an open MD order
          (insalpar rows where PurOrderType = 'E')
Created:  2026-03-31
Output:   Lakehouse table "Fact_MDInvoices_NoFreight"

🔑 KEY DESIGN DECISIONS:
- PurOrderType = 'E' identifies Emergency/Machine Down part lines
- Freight is NOT in Insalord.Freight (field is unused in source system)
- Freight is stored as a line item: PartNumber = '3750', PurOrderType = NULL
- Multiple 3750 lines can exist per order (one per shipment or per part line)
  → TotalFreightCharged = SUM of all 3750 UnitPrices for that FileNumber
- Weight sourced from jdis_Part_Information on Branch + PartNumber (branch-specific)
  → Falls back to 0 if part not found in jdis (discontinued parts)
- CalculatedFreight is DEFERRED — pending freight pricing matrix from stakeholder
- FreightStatus is order-level: "No Freight" / "No Freight Charged" / "Has Freight"

⚠️ KNOWN ANOMALIES (from investigation 09):
- Some orders have FreightLineCount = PartLineCount (freight entered per part line)
  e.g., Order 1407466: 41 parts, 41 freight lines, $14,692 freight vs $5,695 parts
  These are valid data — SUM aggregation handles correctly
- Rare negative 3750 values exist (freight credits/adjustments) — included in sum
- Some older orders (2018-2019) have NULL UnitCost — expected

📊 COLUMNS:
FileNumber          int       — Invoice/order number (FK to Insalord)
LineNumber          int       — Part line number within order
Branch              varchar   — Branch code (FK to dim_BranchLocation)
Franchise           varchar   — Manufacturer code (FK to dim_Franchise)
CustomerNumber      varchar   — Customer code (FK to dim_CustomerList)
OrderDate           datetime  — Order creation date (FK to dim_DateTable)
CustomerOrderNumber varchar   — Customer PO / reference
RONumber            int       — Repair order number (nullable)
OrderType           varchar   — Order type code from Insalord (e.g. 'E' = Emergency/MD)
PartNumber          varchar   — Part number (FK to dim_Parts)
OrderQty            decimal   — Quantity ordered
UnitPrice           decimal   — Unit selling price
UnitCost            decimal   — Unit cost (nullable for older orders)
LineTotal           decimal   — Calculated: UnitPrice * OrderQty
Weight              decimal   — Part weight from jdis (branch-specific, 0 if not found)
TotalLineWeight     decimal   — Calculated: Weight * OrderQty
TotalFreightCharged decimal   — SUM of all 3750 lines for this FileNumber (order-level)
FreightLineCount    int       — Count of 3750 lines on this order
FreightStatus       varchar   — "No Freight" / "No Freight Charged" / "Has Freight"
Salesperson         varchar   — Salesperson code
JobCode             varchar   — Job code
SuppliedQty         decimal   — Quantity already supplied
BackorderQty        decimal   — Quantity on backorder

🔗 DEPENDENCIES:
- insalpar (Lakehouse raw table) — must have PurOrderType column
- Insalord (Lakehouse raw table)
- jdis_Part_Information (Lakehouse raw table) — must have Weight column

🔗 RELATIONSHIPS IN SEMANTIC MODEL:
- FileNumber → (no direct dim, used in DAX measures)
- Branch → dim_BranchLocation.BranchID
- OrderDate → dim_DateTable.Date
- PartNumber → dim_Parts.PartNumber
- Franchise → dim_Franchise.Franchise
- CustomerNumber → dim_CustomerList.CustomerNumber

============================================================================
*/

let

    // ========================================================================
    // STEP 1: GET MD PART LINES
    // Filter insalpar to Emergency/Machine Down lines only
    // ========================================================================

    RawInsalpar = insalpar,

    MDPartLines = Table.SelectRows(RawInsalpar, each [PurOrderType] = "E"),


    // ========================================================================
    // STEP 2: AGGREGATE FREIGHT (part 3750) BY ORDER
    // Freight is a line item — PurOrderType = NULL, PartNumber = "3750"
    // SUM handles multiple freight lines per order (multiple shipments)
    // ========================================================================

    FreightLines = Table.SelectRows(RawInsalpar, each [PartNumber] = "3750"),

    FreightByOrder = Table.Group(
        FreightLines,
        {"FileNumber"},
        {
            {"TotalFreightCharged", each List.Sum(List.Transform([UnitPrice], each _ ?? 0)), type number},
            {"FreightLineCount",    each Table.RowCount(_), Int64.Type}
        }
    ),


    // ========================================================================
    // STEP 3: JOIN INSALORD FOR ORDER HEADER DATA
    // Left join — preserve all MD lines even if Insalord row is missing
    // ========================================================================

    JoinInsalord = Table.NestedJoin(
        MDPartLines,    {"FileNumber"},
        Insalord,       {"FileNumber"},
        "InsalordRow",  JoinKind.LeftOuter
    ),

    ExpandInsalord = Table.ExpandTableColumn(
        JoinInsalord,
        "InsalordRow",
        {"CustomerNumber", "OrderDate", "CustomerOrderNumber", "RONumber", "OrderType"},
        {"CustomerNumber", "OrderDate", "CustomerOrderNumber", "RONumber", "OrderType"}
    ),


    // ========================================================================
    // STEP 4: JOIN FREIGHT AGGREGATION
    // Left join — MD lines with no 3750 freight line get TotalFreight = 0
    // ========================================================================

    JoinFreight = Table.NestedJoin(
        ExpandInsalord,  {"FileNumber"},
        FreightByOrder,  {"FileNumber"},
        "FreightRow",    JoinKind.LeftOuter
    ),

    ExpandFreight = Table.ExpandTableColumn(
        JoinFreight,
        "FreightRow",
        {"TotalFreightCharged", "FreightLineCount"},
        {"TotalFreightCharged", "FreightLineCount"}
    ),

    FillNullFreight = Table.TransformColumns(ExpandFreight, {
        {"TotalFreightCharged", each _ ?? 0, type number},
        {"FreightLineCount",    each _ ?? 0, Int64.Type}
    }),


    // ========================================================================
    // STEP 5: JOIN jdis_Part_Information FOR BRANCH-SPECIFIC WEIGHT
    // Join on Branch + PartNumber composite key for accurate weight
    // Left join — returns Weight = null if part not in jdis (handled in step 6)
    // ========================================================================

    JdisWeightOnly = Table.SelectColumns(
        jdis_Part_Information,
        {"Branch", "PartNumber", "Weight"}
    ),

    // Deduplicate jdis on Branch+PartNumber before join
    JdisDeduped = Table.Distinct(JdisWeightOnly, {"Branch", "PartNumber"}),

    JoinWeight = Table.NestedJoin(
        FillNullFreight,    {"Branch", "PartNumber"},
        JdisDeduped,        {"Branch", "PartNumber"},
        "WeightRow",        JoinKind.LeftOuter
    ),

    ExpandWeight = Table.ExpandTableColumn(
        JoinWeight,
        "WeightRow",
        {"Weight"},
        {"Weight"}
    ),


    // ========================================================================
    // STEP 6: ADD CALCULATED COLUMNS
    // ========================================================================

    // Convert Weight from varchar to numeric (stored as varchar in jdis)
    ConvertWeight = Table.TransformColumns(ExpandWeight, {
        {"Weight", each try Number.From(_) otherwise 0, type number}
    }),

    // LineTotal = UnitPrice × OrderQty
    AddLineTotal = Table.AddColumn(ConvertWeight, "LineTotal", each
        ([UnitPrice] ?? 0) * ([OrderQty] ?? 0),
        type number
    ),

    // TotalLineWeight = Weight × OrderQty
    // NOTE: Weight is assumed per-unit. If stakeholder confirms per-package,
    // update to: (Weight / (PackageQty ?? 1)) * OrderQty
    AddTotalLineWeight = Table.AddColumn(AddLineTotal, "TotalLineWeight", each
        ([Weight] ?? 0) * ([OrderQty] ?? 0),
        type number
    ),

    // FreightStatus at the order level:
    //   "No Freight"         = no 3750 line exists on the order at all
    //   "No Freight Charged" = 3750 line exists but amount is $0
    //   "Has Freight"        = 3750 line(s) exist with positive total
    AddFreightStatus = Table.AddColumn(AddTotalLineWeight, "FreightStatus", each
        if ([FreightLineCount] ?? 0) = 0 then "No Freight"
        else if ([TotalFreightCharged] ?? 0) <= 0 then "No Freight Charged"
        else "Has Freight",
        type text
    ),


    // ========================================================================
    // STEP 7: SELECT FINAL COLUMNS IN LOGICAL ORDER
    // ========================================================================

    SelectFinalColumns = Table.SelectColumns(AddFreightStatus, {
        "FileNumber",
        "LineNumber",
        "Branch",
        "Franchise",
        "CustomerNumber",
        "OrderDate",
        "CustomerOrderNumber",
        "RONumber",
        "OrderType",
        "PartNumber",
        "OrderQty",
        "UnitPrice",
        "UnitCost",
        "LineTotal",
        "Weight",
        "TotalLineWeight",
        "TotalFreightCharged",
        "FreightLineCount",
        "FreightStatus",
        "Salesperson",
        "JobCode",
        "SuppliedQty",
        "BackorderQty"
    }),


    // ========================================================================
    // STEP 8: SET FINAL COLUMN TYPES
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(SelectFinalColumns, {
        {"FileNumber",           Int64.Type},
        {"LineNumber",           Int64.Type},
        {"Branch",               type text},
        {"Franchise",            type text},
        {"CustomerNumber",       type text},
        {"OrderDate",            type datetime},
        {"CustomerOrderNumber",  type text},
        {"RONumber",             Int64.Type},
        {"OrderType",            type text},
        {"PartNumber",           type text},
        {"OrderQty",             type number},
        {"UnitPrice",            type number},
        {"UnitCost",             type number},
        {"LineTotal",            type number},
        {"Weight",               type number},
        {"TotalLineWeight",      type number},
        {"TotalFreightCharged",  type number},
        {"FreightLineCount",     Int64.Type},
        {"FreightStatus",        type text},
        {"Salesperson",          type text},
        {"JobCode",              type text},
        {"SuppliedQty",          type number},
        {"BackorderQty",         type number}
    })

in
    SetTypes

/*
============================================================================
✅ VALIDATION CHECKLIST (run after first dataflow refresh)
============================================================================

At Lakehouse SQL endpoint:

-- 1. Row count should equal count of PurOrderType='E' lines in insalpar
SELECT COUNT(*) FROM Fact_MDInvoices_NoFreight;
SELECT COUNT(*) FROM insalpar WHERE PurOrderType = 'E';

-- 2. Order-level freight breakdown should match investigation query 09 results
--    386 orders with freight, 60 with no freight
SELECT FreightStatus, COUNT(DISTINCT FileNumber) AS OrderCount
FROM Fact_MDInvoices_NoFreight
GROUP BY FreightStatus;

-- 3. No duplicate FileNumber + LineNumber combinations
SELECT FileNumber, LineNumber, COUNT(*) AS Cnt
FROM Fact_MDInvoices_NoFreight
GROUP BY FileNumber, LineNumber
HAVING COUNT(*) > 1;

-- 4. Weight coverage
SELECT
    SUM(CASE WHEN Weight > 0 THEN 1 ELSE 0 END) AS HasWeight,
    COUNT(*) AS Total
FROM Fact_MDInvoices_NoFreight;

============================================================================
*/
