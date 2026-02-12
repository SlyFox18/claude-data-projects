# Cross-Report Integration: Customer Anatomy

## Overview

The Customer Anatomy report now includes `IsUniqueCustomer` and `UniqueCustomerGroup` flags on its `dim_CustomerList` dimension. These flags are derived from the identification rules in this Unique Parts Customers report, allowing users to filter and segment unique customers within Customer Anatomy.

The Unique Parts Customers report remains the primary, detailed source. Customer Anatomy provides lightweight filtering only.

## How It Works

A lookup table (`lookup_UniqueCustomers_Invoice`) in the Lakehouse maps CustomerNumbers to their UniqueCustomerGroup. This table is populated by a dataflow that replicates the identification logic from this report's fact tables.

### Fabric Components

| Component | Location |
|-----------|----------|
| **Dataflow** | `df_UniqueCustomer_Lookup` in `LH_Master_Data / Dataflows / 03 - Dimensions` |
| **Lakehouse Table** | `LH_Master_Data.dbo.lookup_UniqueCustomers_Invoice` |
| **Power Query Script** | `.claude/queries/dimensions/lookup_UniqueCustomers_Invoice.pq` |

### Customer Groups Included

All 11 groups from this report are represented in Customer Anatomy:

| CustomerKey | Group | Customer Anatomy Label |
|-------------|-------|----------------------|
| 1 | Pearsall | Pearsall |
| 2 | Dell City | Dell City |
| 3 | Tornillo | Tornillo |
| 4 | Manuel/MR Tractor | Manuel/MR Tractor |
| 5 | Jim Justice | Jim Justice |
| 6 | David Arizmendi | David Arizmendi |
| 7 | Dallyn Clements | Dallyn Clements |
| 8 | Benny Gray | Benny Gray |
| 9 | Owen Bros. | Owen Bros. |
| 10 | Danny G | Danny G |
| 11 | Oscar | Oscar |

## Important: Coordinating Changes

When modifying customer identification rules in this report, the corresponding changes must also be made in the Customer Anatomy lookup:

### Adding a new unique customer group:
1. Add the new customer to `dim_UniqueCustomers` in this report (next CustomerKey = 12)
2. Add the identification logic to the appropriate fact table in this report
3. Update the dataflow `df_UniqueCustomer_Lookup` in `LH_Master_Data / Dataflows / 03 - Dimensions`
4. Refresh the dataflow and the Customer Anatomy semantic model
5. Update documentation in both project folders

### Modifying an existing customer's rules:
1. Update the rule in this report's fact table
2. Update the matching logic in `df_UniqueCustomer_Lookup`
3. Refresh both

### Removing a unique customer:
1. Set `IsActive = FALSE` in `dim_UniqueCustomers` (this report)
2. Remove the matching logic from `df_UniqueCustomer_Lookup`
3. Customer will lose the flag in Customer Anatomy on next refresh

## Related Documentation

- **Customer Anatomy details**: `projects/customer anatomy - report/UNIQUE-CUSTOMER-FLAGS.md`
- **Power Query script**: `.claude/queries/dimensions/lookup_UniqueCustomers_Invoice.pq`
