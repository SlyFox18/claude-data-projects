# 60+ Days Past Due — Project Summary

## Overview
This report tracks overdue accounts receivable across all branches, broken into aging buckets (30/60/90/120+ days). It also surfaces open parts orders for customers carrying past-due balances, giving credit and collections staff a single view of total customer exposure — what's already past due on account plus what's still on open order.

**Status:** Production
**Workspace:** RP - Financial Reports
**Refreshed:** Daily by 5 AM (Tier 1)

## Report Pages

| Page | Purpose |
|------|---------|
| 60 + Days Past Due | Main summary — AR aging by customer and branch with credit limit utilization |
| Details | Drillthrough page — open parts orders + AR detail for a selected customer |

*Two tooltip pages exist (hidden) for hover context on the main page.*

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| `armaster` | AR Snapshot | `dbo.armaster` (Lakehouse) | Point-in-time AR aging: balance, credit limit, aging buckets (30/60/90/120), last payment |
| `Fact_InSalOrd_InSalPar` | Fact | `dbo.Fact_InSalOrd_InSalPar` (Lakehouse) | Open parts sales orders with days open, order total, backorder amounts |
| `ArMaster_Customer` | Customer Detail | `dbo.ArMaster_Customer` (Lakehouse) | Customer attributes: territory, trade type, credit terms, price level |
| `dim_CustomerList` | Shared Dimension | `dbo.dim_CustomerList` (Lakehouse) | Master customer list with CSM, engagement level, route day |
| `dim_BranchLocation` | Shared Dimension | `dbo.dim_BranchLocation` (Lakehouse) | Branch/location reference |
| `dim_DateTable` | Shared Dimension | `dbo.dim_DateTable` (Lakehouse) | Universal date dimension |

### Relationships
- `armaster` ↔ `ArMaster_Customer` via ContactID (bidirectional)
- `armaster` ↔ `dim_CustomerList` via AccountNumber (bidirectional)
- `ArMaster_Customer` → `dim_BranchLocation` via Territory → BranchID
- `Fact_InSalOrd_InSalPar` → `armaster` via CustomerNumber → ContactID

## Key Measures
| Measure | Description |
|---------|-------------|
| Over 30 | Total AR balance 30–59 days past due |
| Over 60 | Total AR balance 60–89 days past due |
| Over 90 | Total AR balance 90–119 days past due |
| Over 120 | Total AR balance 120+ days past due |
| Credit Limit % 60+ | How much of a customer's credit limit is tied up in 60+ day overdue balances |
| Credit Limit % Current | Total AR balance as a percentage of credit limit (full exposure) |
| Total Owed | Combined open order value + all AR aging buckets — total customer exposure |

*Conditional formatting measures (`Credit Limit % 60+ Formatting`, `Credit Limit % Current+ Formatting`) apply color thresholds: Red ≥100%, Orange ≥75%, Yellow ≥50% of credit limit.*

## Source System Tables
| ERP Table | Description |
|-----------|-------------|
| `armaster` | Accounts receivable master — aging buckets, credit limits, payment history |
| `InSalOrd` / `InSalPar` | Sales order header and parts lines — open/unfulfilled orders |
| `ArMaster_Customer` | Customer master — territory, trade type, credit terms |

## Notes
- **`armaster` naming:** Lowercase table name is a legacy convention — differs from the standard PascalCase used elsewhere. Do not rename without updating the dataflow and all model references.
- **Bidirectional relationships:** Two bidirectional relationships (`armaster` ↔ `dim_CustomerList`, `armaster` ↔ `ArMaster_Customer`) exist in this model. These are a known performance risk per project conventions — monitor render times.
- **Point-in-time data:** AR aging is a daily snapshot, not a history. There is no date filter on `armaster`; it always shows the most recent refresh state.
