# Unique Customer Flags - Customer Anatomy Report

## Overview

The Customer Anatomy report includes flags to identify "Unique Customers" from the dedicated Unique Parts Customers report. This provides a simple slicer-based filter (`IsUniqueCustomer`) and group label (`UniqueCustomerGroup`) on `dim_CustomerList`, allowing users to segment and analyze these special customer groups within Customer Anatomy.

The Unique Parts Customers report remains the primary source for detailed unique customer analysis. Customer Anatomy provides a lightweight integration for cross-reference and filtering.

## Customer Groups (11 Total)

| Group | Customers | Identification Method | Source |
|-------|-----------|----------------------|--------|
| Manuel/MR Tractor | 300 | CustomerOrderNumber contains "MANUEL" or "MR TRACTOR" | Invoice |
| Jim Justice | 87 | CustomerOrderNumber contains "JIM" AND Branch = "94" | Invoice |
| David Arizmendi | 59 | CustomerOrderNumber contains "DAVID" AND Branch = "92" | Invoice |
| Dell City | 18 | TradeType = "T", predominant Branch != "2" | InTrans + ArMaster |
| Tornillo | 23 | TradeType = "T", predominant Branch = "2" | InTrans + ArMaster |
| Oscar | 11 | CustomerOrderNumber contains "\*OSCAR" (asterisk is literal) | Invoice |
| Pearsall | 10 | TradeType = "D" | InTrans + ArMaster |
| Danny G | 2 | CustomerOrderNumber contains "\*DANNY G" (asterisk is literal) | Invoice |
| Dallyn Clements | 1 | CustomerNumber = "36192" | Direct |
| Benny Gray | 1 | CustomerNumber = "38845" | Direct |
| Owen Bros. | 1 | CustomerNumber = "61055" | Direct |

**Total: ~513 distinct customers**

## Architecture

### Lookup Table Approach

All 11 customer groups are consolidated into a single lookup table in the Lakehouse. The DAX on `dim_CustomerList` uses `LOOKUPVALUE` to cross-reference (no model relationship needed).

```
lookup_UniqueCustomers_Invoice (Lakehouse table)
    |
    |-- LOOKUPVALUE (no relationship)
    |
    v
dim_CustomerList[UniqueCustomerGroup]  (calculated column - text label)
dim_CustomerList[IsUniqueCustomer]     (calculated column - boolean flag)
```

### Fabric Components

| Component | Location |
|-----------|----------|
| **Dataflow** | `df_UniqueCustomer_Lookup` in `LH_Master_Data / Dataflows / 03 - Dimensions` |
| **Lakehouse Table** | `LH_Master_Data.dbo.lookup_UniqueCustomers_Invoice` |
| **Power Query Script** | `.claude/queries/dimensions/lookup_UniqueCustomers_Invoice.pq` |

### DAX Calculated Columns (on dim_CustomerList)

**UniqueCustomerGroup**: Returns the group name via LOOKUPVALUE against the lookup table. Returns BLANK() for non-unique customers.

**IsUniqueCustomer**: `NOT ISBLANK(dim_CustomerList[UniqueCustomerGroup])` - simple boolean derived from above.

### Report Integration

- `IsUniqueCustomer` slicer on report pages for filtering
- `UniqueCustomerGroup` column in customer tables
- Purple badge on Customer Profile Card HTML visual: `UNIQUE: [group name]`
- Works alongside existing `IsKeyCustomer` gold badge (both display when applicable)

## Known Edge Cases

- **CustomerNumber 25227**: Matches both Manuel/MR Tractor and Oscar patterns. Resolved to Manuel/MR Tractor by priority order.
- **Dell City / Tornillo split**: 7 customers transact at both Branch 2 and other branches. Assigned to predominant branch by transaction count.
- **Customers can be both Key and Unique**: Both badges display on the Customer Profile Card.

## How to Add a New Unique Customer

### New CustomerOrderNumber-based customer:
1. Open dataflow `df_UniqueCustomer_Lookup` in `LH_Master_Data / Dataflows / 03 - Dimensions`
2. Add new pattern matching logic to the Power Query (see FilterPatterns and AddGroup steps)
3. Publish and refresh the dataflow
4. Refresh the Customer Anatomy semantic model
5. No DAX changes needed - LOOKUPVALUE auto-picks up new rows

### New TradeType or direct CustomerNumber-based customer:
1. Open dataflow `df_UniqueCustomer_Lookup` in `LH_Master_Data / Dataflows / 03 - Dimensions`
2. Add new records to the appropriate section (TradeType query or DirectCustomers table)
3. Publish and refresh the dataflow
4. Refresh the Customer Anatomy semantic model

### In all cases, also update:
- `dim_UniqueCustomers` table in the Unique Parts Customers report
- Corresponding fact table in the Unique Parts Customers report
- This documentation file
- `.claude/queries/dimensions/lookup_UniqueCustomers_Invoice.pq`

## Refresh Dependencies

The dataflow `df_UniqueCustomer_Lookup` must refresh **before** the Customer Anatomy V2 semantic model to ensure the lookup table has current data.

```
df_UniqueCustomer_Lookup (dataflow refresh)
    → lookup_UniqueCustomers_Invoice (Lakehouse table updated)
        → Customer Anatomy V2 semantic model (imports table, recalculates columns)
```

## Related Documentation

- **Unique Parts Customers report**: `projects/unique parts customers - report/CROSS-REPORT-FLAGS.md`
- **Power Query script**: `.claude/queries/dimensions/lookup_UniqueCustomers_Invoice.pq`
- **Implementation plan**: `.claude/plans/hashed-gathering-wombat.md`
