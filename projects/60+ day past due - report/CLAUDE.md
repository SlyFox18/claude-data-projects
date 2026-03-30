# 60+ Days Past Due — Claude Context

## Report Overview
- **Business purpose:** Tracks overdue accounts receivable by aging bucket (30/60/90/120+ days) and surfaces open parts orders for customers with outstanding balances — giving credit/collections staff a full picture of what each customer owes.
- **Primary users:** Branch managers, credit/collections staff, finance team
- **Workspace:** RP - Financial Reports (confirm — AR is financial, not parts-specific)
- **Refresh tier:** Tier 1 — Daily by 5 AM
- **Status:** Production

## Semantic Model

### Fact / Primary Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `armaster` | One row per customer AR account | AccountNumber, ContactID, CreditLimit, AccountBalance, Aging30/60/90/120 | Raw AR aging snapshot from source system. Lowercase name — not the standard PascalCase Lakehouse convention. Direct from `dbo.armaster`. |
| `Fact_InSalOrd_InSalPar` | One row per open parts sales order line | CustomerNumber, Order_No, OrderType, Days_Open, Order_Total_$$, Backorder_Amount | Open/unfulfilled parts orders. Combined with armaster aging to compute `Total Owed`. From `dbo.Fact_InSalOrd_InSalPar`. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `ArMaster_Customer` | `dbo.ArMaster_Customer` | `ContactID` → `armaster.ContactID` (bidirectional — see gotchas) |
| `dim_CustomerList` | Shared Lakehouse dimension | `AccountNumber` → `armaster.AccountNumber` (bidirectional — see gotchas) |
| `dim_BranchLocation` | Shared Lakehouse dimension | `ArMaster_Customer.Territory` → `BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | Not directly related to armaster (no date column on armaster) |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Relationships
```
armaster ←→ ArMaster_Customer  (ContactID, bidirectional)
armaster ←→ dim_CustomerList   (AccountNumber, bidirectional)
ArMaster_Customer → dim_BranchLocation  (Territory → BranchID)
Fact_InSalOrd_InSalPar → armaster  (CustomerNumber → ContactID)
```

### Key Measures
| Measure | Description |
|---------|-------------|
| `Over 30` | Sum of Aging30 bucket (30-59 days past due), positive values only |
| `Over 60` | Sum of Aging60 bucket (60-89 days past due), positive values only |
| `Over 90` | Sum of Aging90 bucket (90-119 days past due), positive values only |
| `Over 120` | Sum of Aging120 bucket (120+ days past due), positive values only |
| `Credit Limit % 60+` | `(Over 60 + Over 90 + Over 120) / CreditLimit` — % of credit limit that is 60+ days overdue |
| `Credit Limit % Current` | Total all-aging balance / CreditLimit — full exposure as % of credit limit |
| `Total Owed` | `Fact_InSalOrd_InSalPar[Order_Total_$$] + AccountBalance + Over 30 + Over 60 + Over 90 + Over 120` — total customer exposure |
| `Credit Limit % 60+ Formatting` | Conditional format switch: Red ≥100%, Orange ≥75%, Yellow ≥50% |
| `Credit Limit % Current+ Formatting` | Same CF scale applied to current balance % |
| `Home - Header` | HTML KPI card header with username greeting and current date |
| `Details - Header` | HTML KPI card header for the Details drillthrough page |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | 60 + Days Past Due | Main summary — AR aging by customer/branch with credit limit exposure | Visible |
| d66e6fe4b27890d83419 | Details | Customer drillthrough — open parts orders + AR detail for a single customer | Hidden in view mode (drillthrough target) |
| 45596635a3706b803525 | Tooltip 1 | Hover tooltip | Hidden (tooltip) |
| bc6aee4f2f666ae09dd0 | Tooltip 2 | Hover tooltip | Hidden (tooltip) |

## Data Flow
```
EquipRDB (ODBC)
  └─ armaster (raw AR aging snapshot) ─────────────────────────────┐
  └─ ArMaster_Customer (customer master) ──────────────────────────┤
                                                                    ▼
LH_Master_Data (Lakehouse)                              Semantic Model
  └─ Fact_InSalOrd_InSalPar (open parts orders) ──────────────────►│
  └─ dim_CustomerList (shared customer dimension) ────────────────►│
  └─ dim_BranchLocation (shared branch dimension) ───────────────►│
  └─ dim_DateTable (shared date dimension) ──────────────────────►│
                                                                   ▼
                                                      60+ Days Past Due Report
```

**Non-standard pattern:** `armaster` uses a lowercase table name — it's loaded directly from the source system without the standard PascalCase normalization applied to most Lakehouse tables. This is an older pattern from before naming conventions were standardized.

## Known Issues & Gotchas

### Bidirectional Relationships (Performance Risk)
Two bidirectional relationships exist in this model:
- `dim_CustomerList.AccountNumber` ↔ `armaster.AccountNumber`
- `ArMaster_Customer.ContactID` ↔ `armaster.ContactID`

Per project conventions, bidirectional relationships carry significant performance risk and create ambiguous filter paths. These were likely set up for convenience but should be reviewed if the report shows slow render times. Consider switching to single-direction with explicit `CROSSFILTER()` in measures if needed.

### `armaster` Naming Convention
Table name is all-lowercase (`armaster`) instead of the standard PascalCase used across other Lakehouse tables. This is a legacy naming issue — do not "fix" it without also updating the dataflow output table name and all model references.

### No Date Relationship on `armaster`
`armaster` contains `LastPaymentDate`, `CreationDate`, and `ModifiedDate` but none of these are connected to `dim_DateTable`. The AR aging is a point-in-time snapshot, not a history. Date slicer, if present, likely filters via `dim_DateTable` → something else, or may not filter AR data at all.

### `Fact_InSalOrd_InSalPar` Join
Open orders join to `armaster` via `CustomerNumber → ContactID`. This means the open orders show all customers with open orders, not just past-due ones. The `Total Owed` measure correctly combines both.

## Refresh Pipeline Position
- **Phase:** Phase 4 (Facts) — `Fact_InSalOrd_InSalPar` refreshes in one of the 5 fact waves
- **`armaster`** likely refreshes in Phase 1 (Raw Sources) or Phase 3 (Dims) — confirm in pipeline
- **Dependencies:** `dim_CustomerList`, `dim_BranchLocation`, `ArMaster_Customer` must be fresh first
- **Phase 5:** Semantic model refresh after all fact/dim phases complete

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/60+ Days Past Due.md`
