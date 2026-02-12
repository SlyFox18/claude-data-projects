# Implementation Plan: Parts Detail Table for Service Invoices

## Overview

This plan adapts the **Inspections report pattern** (Fact_WorkOrderParts) to solve the Unknown Customer issue in Customer Anatomy V2. The key insight is that **InTrans_Incremental has a CustomerNo field** that can be used for customer matching instead of relying on Invoice.BillToAccount.

## The Inspections Report Pattern

### How Fact_WorkOrderParts Works:
```
Source: InTrans_Incremental (Lakehouse)
       ↓
CustomerNo field → Renamed to CustomerNumber
       ↓
RONumber field = InvoiceNumber (links to service invoices)
       ↓
Customer display: Join Fact_WorkOrderParts.CustomerNumber → dim_CustomerList.CustomerNumber
```

### Key Difference from Current Customer Anatomy Approach:
| Approach | Match Key Source | Match Key | Target |
|----------|------------------|-----------|--------|
| **Current (Failing)** | Invoice.BillToAccount | Text value | dim_CustomerList via CustomerLookup bridge |
| **Inspections (Working)** | InTrans.CustomerNo | Customer Number | dim_CustomerList.CustomerNumber |

---

## Proposed Solution: Fact_Service_WorkOrderParts

### Purpose
Create a parts detail table for service invoices that:
1. Sources parts transactions from **InTrans_Incremental**
2. Gets **CustomerNumber directly from InTrans** (not from Invoice.BillToAccount)
3. Provides customer matching that bypasses the BillToAccount issue
4. Enables parts drill-down on service invoices

### Table Specifications

| Attribute | Value |
|-----------|-------|
| **Grain** | One row per parts transaction on service invoices |
| **Source** | InTrans_Incremental (Lakehouse) |
| **Filter** | RONumber matches service invoice (ModuleType = 'W') |
| **Customer Key** | InTrans.CustomerNo → dim_CustomerList.CustomerNumber |
| **Refresh Strategy** | Full refresh (performance acceptable for parts data) |

### Columns

| Column | Source | Type | Description |
|--------|--------|------|-------------|
| BranchCode | InTrans.Branch | text | Branch location |
| InvoiceNumber | InTrans.RONumber | text | Service invoice number |
| TransactionDate | InTrans.TransDatetime | date | Part transaction date |
| PartNumber | InTrans.PartNumber | text | Part number |
| Description | InTrans.Description | text | Part description |
| Franchise | InTrans.Franchise | text | Franchise code |
| Quantity | InTrans.Qty | number | Quantity sold |
| SaleValue | InTrans.SaleValue | number | Sale amount |
| CostValue | InTrans.CostValue | number | Cost amount |
| SellPrice | InTrans.SellPrice1 | number | Selling price |
| ListPrice | InTrans.ListPrice | number | List price |
| **CustomerNumber** | InTrans.CustomerNo | text | **KEY: Customer identifier** |
| **CustomerKey** | Lookup | Int64 | Foreign key to dim_CustomerList |
| TradeType | InTrans.TradeType | text | Trade type indicator |

---

## Implementation Steps

### Step 1: Create Fact_Service_WorkOrderParts.pq

```powerquery
/*
============================================================================
FACT_SERVICE_WORKORDERPARTS - PARTS DETAIL FOR SERVICE INVOICES
============================================================================

Purpose: Parts transactions on service invoices with CustomerNumber-based customer matching
Grain: One row per parts transaction line item from service-module invoices
Source: InTrans_Incremental (Lakehouse)
Customer Key: Uses CustomerNo from InTrans (NOT BillToAccount from Invoice)

WHY THIS EXISTS:
Invoice.BillToAccount may not contain valid customer matching keys for service invoices.
InTrans_Incremental.CustomerNo contains the actual customer number that matches
dim_CustomerList.CustomerNumber, solving the Unknown Customer problem.

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
                [InvoiceDate] >= #datetime(2022, 1, 1, 0, 0, 0)),
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
    // STEP 5: CUSTOMER KEY LOOKUP VIA CUSTOMERNUMBER
    // ========================================================================
    // This is the KEY DIFFERENCE: Join on CustomerNumber, NOT BillToAccount

    JoinCustomer = Table.NestedJoin(
        RenameColumns,
        {"CustomerNumber"},
        dim_CustomerList,
        {"CustomerNumber"},
        "CustomerMatch",
        JoinKind.LeftOuter
    ),

    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
        {"CustomerKey", "DisplayName", "Territory", "Account_Class"},
        {"CustomerKey_Lookup", "CustomerDisplayName", "Territory", "AccountClass"}
    ),

    // Handle unmatched customers
    AddCustomerKey = Table.AddColumn(ExpandCustomer, "CustomerKey", each
        if [CustomerKey_Lookup] = null then -1 else [CustomerKey_Lookup], Int64.Type),

    RemoveLookupColumn = Table.RemoveColumns(AddCustomerKey, {"CustomerKey_Lookup"}),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================

    SetDataTypes = Table.TransformColumnTypes(RemoveLookupColumn, {
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
        {"CustomerKey", Int64.Type},
        {"CustomerDisplayName", type text},
        {"Territory", type text},
        {"AccountClass", type text},
        {"TradeType", type text}
    }),

    // ========================================================================
    // STEP 7: REMOVE DUPLICATES
    // ========================================================================

    RemoveDuplicates = Table.Distinct(SetDataTypes, {
        "BranchCode", "InvoiceNumber", "PartNumber", "TransactionDate", "Quantity", "SaleValue"
    })

in
    RemoveDuplicates
```

---

### Step 2: Alternative - Fix Fact_Service_Invoices Directly

If the investigation reveals that **Invoice.CustomerNumber** (not BillToAccount) contains the matching customer identifier, we can fix Fact_Service_Invoices directly:

```powerquery
// CURRENT (Using BillToAccount):
AddMatchKey = Table.AddColumn(AddInvoiceMonth, "BillToAccount_Upper", each
    Text.Upper(Text.Trim(Text.From([BillToAccount] ?? ""))), type text),

JoinCustomer = Table.NestedJoin(
    AddMatchKey, {"BillToAccount_Upper"},
    CustomerLookup, {"MatchKey"},
    "CustomerMatch", JoinKind.LeftOuter),

// PROPOSED FIX (Using CustomerNumber for Service):
// Option A: Match on Invoice.CustomerNumber directly to dim_CustomerList.CustomerNumber
AddMatchKey = Table.AddColumn(AddInvoiceMonth, "CustomerNumber_Upper", each
    Text.Upper(Text.Trim(Text.From([CustomerNumber] ?? ""))), type text),

JoinCustomer = Table.NestedJoin(
    AddMatchKey, {"CustomerNumber_Upper"},
    dim_CustomerList, {"CustomerNumber"},
    "CustomerMatch", JoinKind.LeftOuter),
```

---

## Semantic Model Changes

### New Relationships Required

| From Table | From Column | To Table | To Column | Cardinality |
|------------|-------------|----------|-----------|-------------|
| Fact_Service_WorkOrderParts | CustomerKey | dim_CustomerList | CustomerKey | Many-to-One |
| Fact_Service_WorkOrderParts | InvoiceNumber | Fact_Service_Invoices | InvoiceNumber | Many-to-One |

### New DAX Measures

```dax
-- Parts Sales on Service Invoices
Service Parts Sales =
SUM(Fact_Service_WorkOrderParts[SaleValue])

-- Parts Cost on Service Invoices
Service Parts Cost =
SUM(Fact_Service_WorkOrderParts[CostValue])

-- Parts Margin on Service Invoices
Service Parts Margin =
[Service Parts Sales] - [Service Parts Cost]

-- Service Invoice Customer (using Parts table for matching)
Service Customer from Parts =
LOOKUPVALUE(
    Fact_Service_WorkOrderParts[CustomerDisplayName],
    Fact_Service_WorkOrderParts[InvoiceNumber],
    SELECTEDVALUE(Fact_Service_Invoices[InvoiceNumber])
)
```

---

## Decision Matrix

Based on investigation results, choose the approach:

| Investigation Finding | Recommended Action |
|-----------------------|-------------------|
| Invoice.CustomerNumber matches dim_CustomerList | Modify Fact_Service_Invoices to match on CustomerNumber instead of BillToAccount |
| InTrans.CustomerNo matches but Invoice.CustomerNumber doesn't | Build Fact_Service_WorkOrderParts and use for customer identification |
| Both match equally well | Modify Fact_Service_Invoices (simpler, no new table) |
| Neither matches well | Investigate source data quality in WKROFILE/wkothsub |

---

## Dataflow Dependency Order

```
1. dim_CustomerList (must refresh first)
        ↓
2. CustomerLookup (depends on dim_CustomerList)
        ↓
3. Fact_Service_WorkOrderParts (depends on dim_CustomerList, InTrans_Incremental, Invoice)
        ↓
4. Fact_Service_Invoices (may need modification based on investigation)
```

---

## Testing Plan

1. **Before implementation**: Run investigation queries to confirm CustomerNumber matching works
2. **After creating table**:
   - Verify CustomerKey != -1 for expected invoices
   - Compare Unknown Customer $ between old and new approach
   - Spot-check specific invoices that were previously Unknown
3. **Validation query**:
```sql
-- Compare match rates: InTrans.CustomerNo vs Invoice.BillToAccount
SELECT
    'Via InTrans.CustomerNo' as Method,
    COUNT(*) as PartRows,
    SUM(CASE WHEN c.CustomerKey IS NOT NULL THEN 1 ELSE 0 END) as Matched,
    SUM(CASE WHEN c.CustomerKey IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as MatchRate
FROM InTrans_Incremental it
INNER JOIN Invoice i ON it.RONumber = i.InvoiceNumber AND it.Branch = i.Branch
LEFT JOIN dim_CustomerList c ON it.CustomerNo = c.CustomerNumber
WHERE i.ModuleType = 'W' AND i.InvoiceDate >= '2022-01-01'
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| InTrans.CustomerNo also doesn't match | Check wkothsub for customer identifiers |
| Performance degradation | InTrans_Incremental is optimized, expect 2-4 min refresh |
| Duplicate rows | Use Table.Distinct on business key |
| NULL CustomerNo values | Default to CustomerKey = -1 (Unknown) |

---

*Created: 2026-02-09*
*Based on: Inspections report Fact_WorkOrderParts pattern*
*Purpose: Solve Unknown Customer issue in Customer Anatomy V2 Service data*
