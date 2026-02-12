# Open Work Orders Report - Migration Plan

## Overview

**Report Name:** Open Work Orders (WIP Report)
**Department:** Service
**Purpose:** Track open work orders with aging analysis (60+ Days, 31-60 Days, 15-30 Days, 8-14 Days, 1-7 Days, Not Started)
**Current Refresh:** Weekly (~3:30 minutes)
**Target:** Migrate from old Lakehouse (ODBC) to new Lakehouse with clean star schema

---

## Current State Analysis

### Old Model Tables

| Table | Rows | Source | Purpose |
|-------|------|--------|---------|
| AgingReport | 562 | Complex ODBC SQL | Labor hours/sales aggregation with aging |
| RepairOrderDetail | 2,263 | ODBC View | Work order lifecycle, financials, status |
| TechnicianInvoiceDetail | 917,937 | ODBC View | Technician invoice details |
| TechnicianPunchedDetail | 717,237 | ODBC View | Technician punch records |
| WKROFILE | 50,569 | ODBC Table | Work order master data |
| Dim_Branch | Small | ODBC | Branch dimension |
| Technician_Code_Names | Small | ODBC | Technician lookup |
| ArMaster_Customer | Small | ODBC | Customer data |
| DimDate | Calculated | DAX | Date dimension |
| ToggleTable | 2 rows | DAX | "Hide/Show Not Started" toggle |

### Current Relationships (Problems Identified)

1. **M:M Relationships** - Multiple many-to-many relationships causing ambiguity
2. **Bidirectional Filters** - Complex cross-filtering that's hard to maintain
3. **Complex AgingReport Query** - 100+ line SQL doing heavy aggregation at source
4. **Duplicate Logic** - Aging calculated both in SQL and DAX measures

### Current Measures Pattern

The old model has **hardcoded aging measures** for each bucket:
- `1-7 Days`, `8-14 Days`, `15-30 Days`, `31-60 Days`, `60+ Days`, `Not Started`
- Sales measures duplicated per bucket: `TotalSales_1_7`, `PartSales_1_7`, `LaborSales_1_7`, etc.

---

## New Model Design

### Star Schema Architecture

```
                    dim_DateTable
                         |
                         | (DateKey)
                         |
dim_Branch ──────► Fact_OpenWorkOrders ◄────── dim_Technician
    |                    |
    |                    | (WorkOrder)
    |                    |
    └──────────► dim_Customer ◄─────────────────┘
```

### New Tables

#### Fact Table: Fact_OpenWorkOrders
**Source:** RepairOrderDetail (from new Lakehouse)
**Grain:** One row per open work order
**Key Fields:**
- Branch, WorkOrder, JobCode, JobType
- CreationDate, JobStartDate, FirstLaborPunch, LastLaborPunch
- DaysSinceCreationDate (for aging)
- LaborRevenue, PartsRevenue, SubletRevenue, OtherRevenue, TotalRevenue
- StatusDisplay, ROProgressStatus

#### Dimension Tables

| Dimension | Source | Purpose |
|-----------|--------|---------|
| dim_DateTable | DAX Calculated | Standard date dimension |
| dim_Branch | Branch_Name (Lakehouse) | Branch lookup |
| dim_Technician | Technician (Lakehouse) | Technician details |
| dim_Customer | ArMaster_Customer (Lakehouse) | Customer context |
| dim_AgingBucket | DAX Calculated | Aging category slicer |

### Aging Bucket Dimension (New Approach)

Instead of hardcoded measures per bucket, use a **disconnected slicer table**:

```dax
dim_AgingBucket =
DATATABLE(
    "AgingBucket", STRING,
    "SortOrder", INTEGER,
    "MinDays", INTEGER,
    "MaxDays", INTEGER,
    {
        {"Not Started", 1, 99999, 99999},
        {"1 - 7 Days", 2, 1, 7},
        {"8 - 14 Days", 3, 8, 14},
        {"15 - 30 Days", 4, 15, 30},
        {"31 - 60 Days", 5, 31, 60},
        {"60+ Days", 6, 61, 99998}
    }
)
```

---

## Migration Steps

### Phase 1: Data Layer (Queries)

1. **Create Fact_OpenWorkOrders.pq**
   - Source: RepairOrderDetail from new Lakehouse
   - Filter: StatusDisplay <> 'Invoiced' (open orders only)
   - Add DateKey for date dimension relationship
   - Add calculated aging column (optional - can do in DAX)

2. **Create/Reuse Dimension Queries**
   - dim_Branch (may already exist in shared dimensions)
   - dim_Technician (from Technician raw table)
   - dim_Customer (from ArMaster_Customer)

### Phase 2: Model Layer

1. **Create Relationships**
   - Fact_OpenWorkOrders[Branch] → dim_Branch[BranchID] (M:1)
   - Fact_OpenWorkOrders[DateKey] → dim_DateTable[Date] (M:1)
   - No relationship to dim_AgingBucket (disconnected slicer)

2. **Create DAX Measures**
   - Dynamic aging measures using SWITCH pattern
   - Sales by aging bucket using CALCULATE with filters

### Phase 3: Report Layer

1. **WIP Overview Page**
   - KPI cards: Total Sales, Part Sales, Labor Sales, Sublet Sales
   - Aging bucket cards with counts and sales
   - Stacked bar chart by branch and aging

2. **WIP Details Page**
   - Aging bucket tabs/buttons
   - Detail table with work order info
   - Conditional formatting for Days Since Last Labor

---

## DAX Measures (New Approach)

### Core Measures

```dax
// Count of open work orders
Open Work Orders = COUNTROWS(Fact_OpenWorkOrders)

// Total Sales
Total Sales = SUM(Fact_OpenWorkOrders[TotalRevenue])
Part Sales = SUM(Fact_OpenWorkOrders[PartsRevenue])
Labor Sales = SUM(Fact_OpenWorkOrders[LaborRevenue])
Sublet Sales = SUM(Fact_OpenWorkOrders[SubletRevenue])
```

### Dynamic Aging Measures

```dax
// Aging Bucket Assignment (calculated column or measure)
Aging Bucket =
VAR _DaysSince = Fact_OpenWorkOrders[DaysSinceCreationDate]
VAR _JobStart = Fact_OpenWorkOrders[JobStartDate]
RETURN
    IF(
        ISBLANK(_JobStart) || _JobStart = DATE(1900,1,1),
        "Not Started",
        SWITCH(
            TRUE(),
            _DaysSince >= 1 && _DaysSince <= 7, "1 - 7 Days",
            _DaysSince >= 8 && _DaysSince <= 14, "8 - 14 Days",
            _DaysSince >= 15 && _DaysSince <= 30, "15 - 30 Days",
            _DaysSince >= 31 && _DaysSince <= 60, "31 - 60 Days",
            _DaysSince > 60, "60+ Days",
            "Not Started"
        )
    )

// Count by Selected Aging Bucket
Work Orders by Aging =
VAR _SelectedBucket = SELECTEDVALUE(dim_AgingBucket[AgingBucket])
VAR _MinDays = SELECTEDVALUE(dim_AgingBucket[MinDays])
VAR _MaxDays = SELECTEDVALUE(dim_AgingBucket[MaxDays])
RETURN
    IF(
        _SelectedBucket = "Not Started",
        CALCULATE(
            COUNTROWS(Fact_OpenWorkOrders),
            ISBLANK(Fact_OpenWorkOrders[JobStartDate])
            || Fact_OpenWorkOrders[JobStartDate] = DATE(1900,1,1)
        ),
        CALCULATE(
            COUNTROWS(Fact_OpenWorkOrders),
            Fact_OpenWorkOrders[DaysSinceCreationDate] >= _MinDays,
            Fact_OpenWorkOrders[DaysSinceCreationDate] <= _MaxDays
        )
    )
```

---

## What We're NOT Migrating

1. **AgingReport table** - Complex SQL replaced by simple fact + DAX
2. **TechnicianInvoiceDetail** - Not needed for WIP overview (917K rows removed!)
3. **TechnicianPunchedDetail** - Not needed for WIP overview (717K rows removed!)
4. **WKROFILE expansion** - Contact info comes from dim_Customer instead

### Performance Improvement Expected

| Old Model | New Model |
|-----------|-----------|
| 5 large tables | 1 fact + 3-4 dimensions |
| ~1.7M rows loaded | ~3K rows loaded |
| Complex M:M relationships | Clean star schema |
| 3:30 refresh | Target: <30 seconds |

---

## Files Created

### Queries (queries/fact tables/)
- [x] **Fact_OpenWorkOrders.pq** - Main fact table sourcing from Lakehouse
  - Sources: RepairOrderDetail, WKROFILE, TechnicianPunchedDetail
  - ~2,000-3,000 rows (open work orders only)
  - Includes: AgingBucket, ProgressStatusDisplay, DaysSinceLastLabor

### Queries (queries/dimensions/)
- [x] **dim_AgingBucket.dax** - Disconnected slicer table for aging analysis
- [ ] dim_Branch.pq - **Reuse existing shared dimension**
- [ ] dim_CustomerList.pq - **Reuse existing shared dimension**

### DAX (queries/dax-measures/)
- [x] **Core_Measures.dax** - All measures for WIP report
  - Sales totals (Total, Parts, Labor, Sublet, Other)
  - Aging bucket counts and sales
  - Customer Name lookup measure
  - Conditional formatting measures

---

## Questions Resolved

1. **TechnicianPunchedDetail needed?** ✅ YES
   - Provides: EquipmentModel (Model field), TechnicianName, CustomerName fallback
   - Joined via WorkOrder in Fact_OpenWorkOrders.pq

2. **Customer Name source** ✅ RESOLVED
   - Primary: dim_CustomerList via AccountNumberText relationship
   - Fallback: CustomerNamePunch from TechnicianPunchedDetail
   - DAX measure handles the logic with cascading fallbacks

3. **Model field** ✅ RESOLVED
   - Source: TechnicianPunchedDetail[EquipmentModel]
   - Aggregated using List.Max per WorkOrder

4. **Progress Status mapping** ✅ RESOLVED
   - Added ProgressStatusDisplay calculated column in Fact_OpenWorkOrders
   - Maps all ROProgressStatus codes to friendly names

---

## Next Steps

### Completed
1. ✅ Created Fact_OpenWorkOrders.pq query from Lakehouse tables
2. ✅ Verified all needed fields (RepairOrderDetail + WKROFILE + TechnicianPunchedDetail)
3. ✅ Created dim_AgingBucket.dax dimension
4. ✅ Created Core_Measures.dax with all measures

### Remaining
5. [ ] Build Power BI report in Desktop
   - Load Fact_OpenWorkOrders
   - Load dim_CustomerList, dim_Branch (existing shared dims)
   - Create dim_AgingBucket calculated table
   - Create relationships
   - Add measures
6. [ ] Create report pages (WIP Overview, WIP Details)
7. [ ] Validate numbers against old report
8. [ ] Deploy to workspace

### Model Relationships to Create
```
dim_Branch[Branch] ←── Fact_OpenWorkOrders[Branch] (M:1)
dim_DateTable[Date] ←── Fact_OpenWorkOrders[DateKey] (M:1)
dim_CustomerList[AccountNumberText] ←── Fact_OpenWorkOrders[AccountNumberText] (M:1)
dim_AgingBucket[AgingBucket] ←── Fact_OpenWorkOrders[AgingBucket] (M:1, optional)
```
