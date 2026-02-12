# Part Sales with Low Margin - Migration Analysis

**Report Name**: Part Sales with Low Margin
**Status**: Analysis Phase - Planning Migration to New Lakehouse
**Analysis Date**: January 8, 2026
**Analyst**: B.Fox with Claude Code Assistant

---

## Executive Summary

This document analyzes the current "Part Sales with Low Margin" report to plan its migration from the old Lakehouse structure to a new optimized Fabric Lakehouse with proper star schema architecture.

**Report Importance**: ⭐⭐⭐⭐⭐ **HIGHEST PRIORITY**
- Stakeholders report this as "the single most impactful report"
- Currently working with good data quality
- Requires careful migration with extensive validation

**Current Status**: ✅ Working (old Lakehouse)
**Target**: Migrate to new Lakehouse with optimization

---

## Table of Contents

1. [Current Data Architecture](#current-data-architecture)
2. [Data Source Analysis](#data-source-analysis)
3. [Business Logic Breakdown](#business-logic-breakdown)
4. [Required Raw Data](#required-raw-data)
5. [Proposed New Architecture](#proposed-new-architecture)
6. [Migration Strategy](#migration-strategy)
7. [Validation Plan](#validation-plan)
8. [Risks & Mitigations](#risks--mitigations)
9. [Next Steps](#next-steps)

---

## Current Data Architecture

### Current Tables (Old Lakehouse)

The report currently uses **2 main tables**:

1. **InTrans_Low_Margin** - Transaction/Sales data
2. **Parts_Low_Margin_jdis_InMaster** - Part master data with inventory

### High-Level Current Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Source System: EquipRDB64 (ODBC Connection)                │
│                                                              │
│  Tables:                                                     │
│  • InTrans (transactions)                                   │
│  • jdis_Part_Information (part master)                      │
│  • InMaster (additional part data)                          │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ Power Query M Code (Direct ODBC queries)
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ Old Lakehouse Tables (via Power Query)                      │
│                                                              │
│  1. InTrans_Low_Margin                                      │
│     • 2 years of transaction history                        │
│     • Sales, cost, margin data                              │
│                                                              │
│  2. Parts_Low_Margin_jdis_InMaster                          │
│     • Part master with current inventory                    │
│     • Only parts with On_Hand_Qty > 0                       │
│     • Joined from 2 source tables                           │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ Power BI Report: Part Sales with Low Margin                │
│                                                              │
│  Analysis: Identifies parts selling below optimal margin   │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Source Analysis

### Table 1: InTrans_Low_Margin

**Source Query Type**: Direct SQL via ODBC
**Source Tables**: `InTrans`
**Connection**: `dsn=EquipRDB64`

#### Power Query M Code:
```powerquery
let
  Source = Odbc.Query("dsn=EquipRDB64", "
    SELECT
      BRANCH,
      REF_NO,
      FRANCHISE,
      PART_NO,
      Trans_Datetime,
      customer_no,
      TYPE,
      REF_NO,
      QTY,
      SALE_VAL,
      COST_VAL,
      TRADE_TYPE,
      DESCRIPTION,
      LIST_PRICE,
      Salesman
    FROM
      InTrans
    WHERE
      Trans_Datetime >= DATEADD(YEAR, -2, GETDATE())
  ")
in
  Source
```

#### Columns Retrieved (15 columns):

| Column Name | Purpose | Business Logic |
|------------|---------|----------------|
| **BRANCH** | Branch identifier | Which location made the sale |
| **REF_NO** | Reference number (appears twice - likely error) | Transaction/invoice reference |
| **FRANCHISE** | Franchise code | Equipment/part manufacturer |
| **PART_NO** | Part number | Unique part identifier |
| **Trans_Datetime** | Transaction timestamp | When the sale occurred |
| **customer_no** | Customer ID | Who bought the part |
| **TYPE** | Transaction type | Sale, return, etc. |
| **QTY** | Quantity sold | Number of units |
| **SALE_VAL** | Sale value ($) | Dollar amount of sale |
| **COST_VAL** | Cost value ($) | Dollar cost of goods sold |
| **TRADE_TYPE** | Trade classification | Type of trade/transaction |
| **DESCRIPTION** | Part description | What the part is |
| **LIST_PRICE** | Manufacturer list price | MSRP |
| **Salesman** | Salesperson | Who made the sale |

#### Data Filters:
- ✅ **Time Range**: Last 2 years of data (`Trans_Datetime >= DATEADD(YEAR, -2, GETDATE())`)
- ✅ **Dynamic**: Rolls forward daily (always 2 years trailing)

#### Estimated Row Count:
- Assuming ~10,000-100,000 transactions per year
- **Total**: ~20,000-200,000 rows

---

### Table 2: Parts_Low_Margin_jdis_InMaster

**Source Query Type**: SQL CTE (Common Table Expression) via ODBC
**Source Tables**: `jdis_Part_Information`, `InMaster`
**Connection**: `dsn=EquipRDB64`

#### Power Query M Code:
```powerquery
let
  Source = Odbc.Query("dsn=EquipRDB64", "
    WITH jdis_Part_Info_Filtered AS (
      SELECT
        pi_Branch AS \"Branch\",
        pi_List_Price_Manuf_File AS \"List Price Manuf\",
        pi_Franchise AS \"Franchise\",
        pi_Part_No AS \"Part No\",
        pi_Description AS \"Description\",
        pi_Bin AS \"Bin\",
        pi_Bin_Qty AS \"Bin Qty\",
        pi_Bulk_Bin AS \"Bulk Bin\",
        pi_Bulk_Bin_Qty AS \"Bulk Bin Qty\",
        pi_On_Hand_Qty AS \"On Hand Qty\",
        pi_Pending_Qty AS \"Pending Qty\",
        pi_Date_Last_Request AS \"Date Last Requested\",
        pi_Stocktake_Date AS \"Stock Take Date\",
        pi_Cost AS \"Cost\",
        pi_List_Price_Master_File AS \"List Price\",
        pi_Inventory_Cost AS \"Inventory Cost\",
        pi_Sell_Price_1_Master_File AS \"Sell Price\"
      FROM
        jdis_Part_Information
      WHERE
        pi_On_Hand_Qty > 0
    ),

    InMaster_Filtered AS (
      SELECT
        PART_NO,
        user_field_3,
        STK_ORDER_PRICE,
        Branch
      FROM
        InMaster
    )

    SELECT
      jdis_Part_Info_Filtered.Branch,
      jdis_Part_Info_Filtered.Franchise,
      jdis_Part_Info_Filtered.\"Part No\",
      jdis_Part_Info_Filtered.Description,
      jdis_Part_Info_Filtered.Bin,
      jdis_Part_Info_Filtered.\"Bin Qty\",
      jdis_Part_Info_Filtered.\"Bulk Bin\",
      jdis_Part_Info_Filtered.\"Bulk Bin Qty\",
      jdis_Part_Info_Filtered.\"On Hand Qty\",
      jdis_Part_Info_Filtered.\"Pending Qty\",
      jdis_Part_Info_Filtered.\"Date Last Requested\",
      jdis_Part_Info_Filtered.\"Stock Take Date\",
      jdis_Part_Info_Filtered.\"List Price Manuf\",
      jdis_Part_Info_Filtered.Cost,
      jdis_Part_Info_Filtered.\"List Price\",
      jdis_Part_Info_Filtered.\"Inventory Cost\",
      jdis_Part_Info_Filtered.\"Sell Price\",
      COALESCE(InMaster_Filtered.user_field_3, '') AS user_field_3,
      COALESCE(InMaster_Filtered.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE
    FROM
      jdis_Part_Info_Filtered
    LEFT JOIN
      InMaster_Filtered
    ON
      jdis_Part_Info_Filtered.\"Part No\" = InMaster_Filtered.PART_NO
      AND jdis_Part_Info_Filtered.Branch = InMaster_Filtered.Branch
  ")
in
  Source
```

#### Columns Retrieved (19 columns):

| Column Name | Source Table | Purpose |
|------------|--------------|---------|
| **Branch** | jdis_Part_Information | Branch location |
| **Franchise** | jdis_Part_Information | Manufacturer/franchise |
| **Part No** | jdis_Part_Information | Part identifier |
| **Description** | jdis_Part_Information | Part description |
| **Bin** | jdis_Part_Information | Primary bin location |
| **Bin Qty** | jdis_Part_Information | Quantity in primary bin |
| **Bulk Bin** | jdis_Part_Information | Bulk storage location |
| **Bulk Bin Qty** | jdis_Part_Information | Quantity in bulk bin |
| **On Hand Qty** | jdis_Part_Information | Total quantity on hand |
| **Pending Qty** | jdis_Part_Information | Quantity pending (on order?) |
| **Date Last Requested** | jdis_Part_Information | Last time part was requested |
| **Stock Take Date** | jdis_Part_Information | Last inventory count date |
| **List Price Manuf** | jdis_Part_Information | Manufacturer's list price |
| **Cost** | jdis_Part_Information | Cost of the part |
| **List Price** | jdis_Part_Information | Standard list price |
| **Inventory Cost** | jdis_Part_Information | Inventory valuation cost |
| **Sell Price** | jdis_Part_Information | Standard sell price |
| **user_field_3** | InMaster | Custom field (unknown purpose) |
| **STK_ORDER_PRICE** | InMaster | Stock order price |

#### Data Filters:
- ✅ **Inventory Filter**: Only parts with `On_Hand_Qty > 0` (active inventory)
- ✅ **Join Logic**: LEFT JOIN ensures all parts from jdis_Part_Information included
- ✅ **NULL Handling**: COALESCE for InMaster fields (defaults: '' for user_field_3, 0 for STK_ORDER_PRICE)

#### Estimated Row Count:
- Assuming ~5,000-50,000 active SKUs across all branches
- **Total**: ~5,000-50,000 rows

---

## Business Logic Breakdown

### Report Purpose: **Identify Parts Selling Below Optimal Margin**

Based on the data structure, here's what the report likely does:

### 1. Margin Calculation Logic (Inferred)

**Margin Formula**:
```
Margin = (SALE_VAL - COST_VAL) / SALE_VAL × 100%

OR

Margin $ = SALE_VAL - COST_VAL
Margin % = Margin $ / SALE_VAL
```

**Low Margin Threshold** (Unknown - need to verify):
- Likely: Margin % < 20% or 25%
- Or: Margin $ below a certain dollar amount
- Possibly: Compared to target margin based on List Price

### 2. Transaction Analysis (InTrans_Low_Margin)

**What it provides**:
- Historical sales performance (2 years)
- Actual sale prices vs. cost
- Which parts are being sold at low margins
- Which branches/salespeople have low margin issues
- Which customers are getting low margins

**Key Metrics**:
- Total sales value
- Total cost value
- Calculated margin
- Quantity sold
- Number of transactions

### 3. Current Inventory Context (Parts_Low_Margin_jdis_InMaster)

**What it provides**:
- Which low-margin parts are still in stock
- Current pricing structure:
  - Cost (what we paid)
  - List Price (MSRP)
  - Sell Price (our standard price)
  - Inventory Cost (current valuation)
- Inventory levels (On Hand Qty, Pending Qty)
- Location information (Bin, Bulk Bin)

**Key Business Questions**:
- "Which parts in our current inventory have been selling at low margins?"
- "Should we adjust pricing on these parts?"
- "Do we have too much inventory of low-margin parts?"

### 4. Likely Report Features

Based on typical "low margin" reports:

**Filters/Slicers**:
- Branch
- Franchise (manufacturer)
- Date range (within 2 years)
- Salesman
- Margin threshold

**Visuals**:
- Table of parts with lowest margins
- Margin trend over time
- Branch comparison (which branches have margin issues)
- Salesman performance (who's giving too many discounts)
- Inventory value tied up in low-margin parts

**KPIs**:
- Total sales at low margin
- Lost profit (could have charged more)
- Count of low-margin transactions
- Average margin %
- Inventory at risk (low margin parts still in stock)

---

## Required Raw Data

To recreate this report in the new Lakehouse, you need these **source tables**:

### 1. InTrans (Transaction Table)

**Critical for**: Sales history, margin calculation

**Required Columns**:
- BRANCH
- REF_NO (transaction reference)
- FRANCHISE
- PART_NO
- Trans_Datetime
- customer_no
- TYPE (transaction type)
- QTY (quantity sold)
- SALE_VAL (sale dollar amount)
- COST_VAL (cost dollar amount)
- TRADE_TYPE
- DESCRIPTION
- LIST_PRICE
- Salesman

**Time Range**: Last 2 years (rolling window)

**Row Count**: All transaction records from InTrans

---

### 2. jdis_Part_Information (Part Master)

**Critical for**: Current inventory, pricing structure

**Required Columns**:
- pi_Branch
- pi_List_Price_Manuf_File
- pi_Franchise
- pi_Part_No
- pi_Description
- pi_Bin
- pi_Bin_Qty
- pi_Bulk_Bin
- pi_Bulk_Bin_Qty
- pi_On_Hand_Qty (**FILTER**: > 0)
- pi_Pending_Qty
- pi_Date_Last_Request
- pi_Stocktake_Date
- pi_Cost
- pi_List_Price_Master_File
- pi_Inventory_Cost
- pi_Sell_Price_1_Master_File

**Filters**: Only parts with on-hand quantity > 0

---

### 3. InMaster (Additional Part Data)

**Critical for**: Supplemental part information

**Required Columns**:
- PART_NO
- user_field_3 (custom field - need to determine purpose)
- STK_ORDER_PRICE (stock order price)
- Branch

**Join Logic**: LEFT JOIN to jdis_Part_Information on Part_No + Branch

---

### Optional/Supporting Tables (May Be Needed)

Based on typical parts reporting:

4. **Customer** table (for customer names, details)
5. **Salesperson** table (for salesperson names, territories)
6. **Branch** table (for branch names, locations)
7. **Franchise** lookup (for manufacturer names)

---

## Proposed New Architecture

### Star Schema Design for Low Margin Report

```
┌────────────────────────────────────────────────────────────┐
│ NEW LAKEHOUSE ARCHITECTURE                                 │
└────────────────────────────────────────────────────────────┘

┌──────────────────────────┐
│ dim_Parts                │
│ (Dimension)              │
├──────────────────────────┤
│ PK: Part_No + Branch    │
│     Description         │
│     Franchise           │
│     List_Price_Manuf    │
│     Cost                │
│     List_Price          │
│     Inventory_Cost      │
│     Sell_Price          │
│     Bin                 │
│     Bin_Qty             │
│     Bulk_Bin            │
│     Bulk_Bin_Qty        │
│     On_Hand_Qty         │
│     Pending_Qty         │
│     Date_Last_Requested │
│     Stock_Take_Date     │
│     user_field_3        │
│     STK_ORDER_PRICE     │
└──────────────┬───────────┘
               │
               │ 1:* (Part_No+Branch → Part_No+Branch)
               │
┌──────────────▼───────────┐          ┌─────────────────────────┐
│ Fact_Part_Sales_Txns     │          │ dim_Branch              │
│ (Fact - Transactions)    │          │ (Dimension)             │
├──────────────────────────┤          ├─────────────────────────┤
│ PK: REF_NO (or SK)      │◄─────────┤ PK: Branch              │
│ FK: Part_No + Branch    │  1:*     │     Branch_Name         │
│ FK: Trans_Date          │          │     Location            │
│ FK: Customer_No         │          │     ... (attrs)         │
│ FK: Salesman            │          └─────────────────────────┘
│                         │
│ Trans_Datetime          │          ┌─────────────────────────┐
│ Transaction_Type        │          │ dim_DateTable           │
│ Trade_Type              │          │ (Dimension)             │
│ QTY                     │          ├─────────────────────────┤
│ SALE_VAL                │◄─────────┤ PK: Date               │
│ COST_VAL                │  1:*     │     Year, Quarter       │
│ LIST_PRICE              │          │     Month, Day          │
│ Margin_$$ (calc)        │          │     ... (time attrs)    │
│ Margin_Pct (calc)       │          └─────────────────────────┘
│ Low_Margin_Flag (calc)  │
└─────────────────────────┘          ┌─────────────────────────┐
                                     │ dim_Customer            │
                                     │ (Dimension)             │
                                     ├─────────────────────────┤
                                     │ PK: Customer_No        │
                                     │     Customer_Name       │
                                     │     ... (attrs)         │
                                     └─────────────────────────┘

                                     ┌─────────────────────────┐
                                     │ dim_Salesman            │
                                     │ (Dimension)             │
                                     ├─────────────────────────┤
                                     │ PK: Salesman           │
                                     │     Salesman_Name       │
                                     │     Territory           │
                                     │     ... (attrs)         │
                                     └─────────────────────────┘
```

### Proposed Fact Tables

#### Fact_Part_Sales_Txns (Transaction-Level Fact)

**Grain**: One row per part sale transaction

**Source**: InTrans table (filtered to last 2 years)

**Key Columns**:
```sql
CREATE VIEW vw_Fact_Part_Sales_Txns AS
SELECT
    -- Keys
    REF_NO AS Transaction_Ref,
    BRANCH AS Branch_ID,
    PART_NO AS Part_No,
    CAST(Trans_Datetime AS DATE) AS Trans_Date,
    customer_no AS Customer_ID,
    Salesman AS Salesman_ID,

    -- Attributes
    Trans_Datetime AS Transaction_DateTime,
    TYPE AS Transaction_Type,
    TRADE_TYPE AS Trade_Type,
    FRANCHISE AS Franchise,
    DESCRIPTION AS Part_Description,

    -- Measures
    QTY AS Quantity_Sold,
    SALE_VAL AS Sale_Value_$$,
    COST_VAL AS Cost_Value_$$,
    LIST_PRICE AS List_Price,

    -- Calculated Columns (consider doing in DAX instead)
    (SALE_VAL - COST_VAL) AS Margin_$$,
    CASE
        WHEN SALE_VAL > 0
        THEN (SALE_VAL - COST_VAL) / SALE_VAL
        ELSE 0
    END AS Margin_Pct,

    -- Low Margin Flag (adjust threshold as needed)
    CASE
        WHEN SALE_VAL > 0 AND ((SALE_VAL - COST_VAL) / SALE_VAL) < 0.20
        THEN 1
        ELSE 0
    END AS Is_Low_Margin

FROM InTrans
WHERE Trans_Datetime >= DATEADD(YEAR, -2, GETDATE())
```

**Estimated Rows**: 20,000-200,000 transactions

---

#### dim_Parts (Part Dimension)

**Grain**: One row per Part_No + Branch combination (parts currently in stock)

**Source**: jdis_Part_Information LEFT JOIN InMaster

**Key Columns**:
```sql
CREATE VIEW vw_dim_Parts AS
WITH Part_Info AS (
    SELECT
        pi_Branch AS Branch,
        pi_Franchise AS Franchise,
        pi_Part_No AS Part_No,
        pi_Description AS Description,
        pi_Bin AS Bin,
        pi_Bin_Qty AS Bin_Qty,
        pi_Bulk_Bin AS Bulk_Bin,
        pi_Bulk_Bin_Qty AS Bulk_Bin_Qty,
        pi_On_Hand_Qty AS On_Hand_Qty,
        pi_Pending_Qty AS Pending_Qty,
        pi_Date_Last_Request AS Date_Last_Requested,
        pi_Stocktake_Date AS Stock_Take_Date,
        pi_List_Price_Manuf_File AS List_Price_Manuf,
        pi_Cost AS Cost,
        pi_List_Price_Master_File AS List_Price,
        pi_Inventory_Cost AS Inventory_Cost,
        pi_Sell_Price_1_Master_File AS Sell_Price
    FROM jdis_Part_Information
    WHERE pi_On_Hand_Qty > 0
),
InMaster_Subset AS (
    SELECT
        PART_NO,
        Branch,
        user_field_3,
        STK_ORDER_PRICE
    FROM InMaster
)

SELECT
    Part_Info.*,
    COALESCE(InMaster_Subset.user_field_3, '') AS user_field_3,
    COALESCE(InMaster_Subset.STK_ORDER_PRICE, 0) AS STK_ORDER_PRICE
FROM Part_Info
LEFT JOIN InMaster_Subset
    ON Part_Info.Part_No = InMaster_Subset.PART_NO
    AND Part_Info.Branch = InMaster_Subset.Branch
```

**Estimated Rows**: 5,000-50,000 parts

---

### Proposed Dimension Tables

These may already exist in your Lakehouse:

- **dim_Branch** (if not already created)
- **dim_DateTable** (should already exist from Parts on Open Orders project)
- **dim_Customer** (if available)
- **dim_Salesman** (if available)
- **dim_Franchise** (optional - could be attribute in dim_Parts)

---

## Migration Strategy

### Phase 1: Data Foundation (Week 1)

**Objective**: Get raw data into new Lakehouse

**Tasks**:
1. ✅ Confirm source tables exist in EquipRDB64
2. Create SQL views in new Lakehouse:
   - `vw_Fact_Part_Sales_Txns` (from InTrans)
   - `vw_dim_Parts` (from jdis_Part_Information + InMaster)
3. Set up data refresh:
   - Daily refresh for Fact_Part_Sales_Txns
   - Daily refresh for dim_Parts (inventory changes)
4. Initial data load and validation

**Validation Checkpoints**:
- Row counts match old queries
- Date ranges correct (2 years for transactions)
- JOIN logic produces same results

---

### Phase 2: Semantic Model Build (Week 1-2)

**Objective**: Create Power BI semantic model with star schema

**Tasks**:
1. Create new semantic model in Fabric
2. Import tables:
   - Fact_Part_Sales_Txns
   - dim_Parts
   - dim_Branch (if exists)
   - dim_DateTable (reuse from other projects)
3. Configure relationships:
   - Fact → dim_Parts (Part_No + Branch)
   - Fact → dim_Branch (Branch)
   - Fact → dim_DateTable (Trans_Date)
4. Create DAX measures (migrate from old report)
5. Test measure calculations

**Validation Checkpoints**:
- Relationship cardinality correct
- Measure totals match old report
- Filters propagate correctly

---

### Phase 3: Report Replication (Week 2)

**Objective**: Rebuild report pages using new semantic model

**Tasks**:
1. Document old report structure:
   - Export screenshots
   - Document all visuals, filters, slicers
   - Record current metric values for validation
2. Build new report pages
3. Apply same filters, slicers, formatting
4. Side-by-side validation

**Validation Checkpoints**:
- Visual placement matches old report
- All filters/slicers work correctly
- Metric values match (within acceptable variance)

---

### Phase 4: Extended Validation (Week 2-3)

**Objective**: Ensure data accuracy across all scenarios

**Tasks**:
1. Test edge cases:
   - Different date ranges
   - Different branch selections
   - Different margin thresholds
2. Validate with stakeholders
3. Document any discrepancies
4. Fix any data quality issues

**Validation Checkpoints**:
- Stakeholders approve accuracy
- All known use cases tested
- Performance acceptable

---

### Phase 5: Deployment (Week 3)

**Objective**: Go live with new report

**Tasks**:
1. Final stakeholder sign-off
2. Schedule refresh (daily)
3. Deploy to production workspace
4. User training (if needed)
5. Monitor for issues
6. Archive old report

---

## Validation Plan

### Critical Validation Points

#### 1. Row Count Validation

**Transactions (InTrans_Low_Margin)**:
```sql
-- OLD (via Power Query)
SELECT COUNT(*) FROM InTrans
WHERE Trans_Datetime >= DATEADD(YEAR, -2, GETDATE())

-- NEW (Lakehouse view)
SELECT COUNT(*) FROM vw_Fact_Part_Sales_Txns
```

**Parts (Parts_Low_Margin_jdis_InMaster)**:
```sql
-- OLD (via Power Query CTE)
WITH Part_Info AS (
  SELECT * FROM jdis_Part_Information WHERE pi_On_Hand_Qty > 0
)
SELECT COUNT(*) FROM Part_Info
LEFT JOIN InMaster ON ...

-- NEW (Lakehouse view)
SELECT COUNT(*) FROM vw_dim_Parts
```

**Tolerance**: Exact match expected (0 variance)

---

#### 2. Financial Validation

**Total Sales Value**:
```dax
-- OLD Report
Total Sales = SUM(InTrans_Low_Margin[SALE_VAL])

-- NEW Report
Total Sales = SUM(Fact_Part_Sales_Txns[Sale_Value_$$])
```

**Total Cost Value**:
```dax
-- OLD Report
Total Cost = SUM(InTrans_Low_Margin[COST_VAL])

-- NEW Report
Total Cost = SUM(Fact_Part_Sales_Txns[Cost_Value_$$])
```

**Total Margin**:
```dax
-- OLD Report
Total Margin = SUM(InTrans_Low_Margin[SALE_VAL]) - SUM(InTrans_Low_Margin[COST_VAL])

-- NEW Report
Total Margin = SUM(Fact_Part_Sales_Txns[Margin_$$])
-- OR calculate in measure:
Total Margin = [Total Sales] - [Total Cost]
```

**Tolerance**: <0.1% variance acceptable (rounding differences)

---

#### 3. Low Margin Count Validation

**Count of Low Margin Transactions**:
- Need to determine threshold from old report
- Compare counts at various thresholds (10%, 15%, 20%, 25%)
- Validate flag logic matches

---

#### 4. Inventory Validation

**Parts On Hand**:
```dax
-- OLD Report
Total On Hand = SUM(Parts_Low_Margin_jdis_InMaster[On Hand Qty])

-- NEW Report
Total On Hand = SUM(dim_Parts[On_Hand_Qty])
```

**Inventory Value**:
```dax
-- OLD Report
Inventory Value = SUM(Parts_Low_Margin_jdis_InMaster[Inventory Cost] * [On Hand Qty])

-- NEW Report
Inventory Value = SUMX(dim_Parts, [Inventory_Cost] * [On_Hand_Qty])
```

**Tolerance**: Exact match expected (inventory is point-in-time)

---

### Validation Testing Matrix

| Test Scenario | Old Report Value | New Report Value | Variance | Status |
|--------------|------------------|------------------|----------|--------|
| Total Transaction Count | TBD | TBD | TBD | ⏳ |
| Total Sales ($) | TBD | TBD | TBD | ⏳ |
| Total Cost ($) | TBD | TBD | TBD | ⏳ |
| Total Margin ($) | TBD | TBD | TBD | ⏳ |
| Average Margin % | TBD | TBD | TBD | ⏳ |
| Low Margin Txn Count | TBD | TBD | TBD | ⏳ |
| Parts On Hand Count | TBD | TBD | TBD | ⏳ |
| Total Inventory Value | TBD | TBD | TBD | ⏳ |
| Branch Breakdown | TBD | TBD | TBD | ⏳ |
| Franchise Breakdown | TBD | TBD | TBD | ⏳ |

---

## Risks & Mitigations

### Risk 1: Unknown Business Logic in Old Report

**Risk**: We don't have complete visibility into DAX measures and calculations in the old report

**Impact**: HIGH - Could miss critical business logic

**Mitigation**:
1. Export all measures from old report (Model Measures.csv)
2. Document all visuals and filters
3. Interview stakeholders about key calculations
4. Validate edge cases thoroughly

**Status**: ⚠️ Need to export old report metadata

---

### Risk 2: Data Quality Issues in Migration

**Risk**: Source data may have quirks that current report handles

**Impact**: HIGH - Stakeholders say this is most important report

**Mitigation**:
1. Start with exact replication (no optimization initially)
2. Extensive validation before any changes
3. Keep old report running in parallel during transition
4. Phased rollout (pilot users first)

**Status**: ⚠️ Plan for parallel running

---

### Risk 3: Performance Degradation

**Risk**: New architecture may be slower than direct ODBC queries

**Impact**: MEDIUM - User experience could suffer

**Mitigation**:
1. Use Import mode (cache data)
2. Implement incremental refresh (2-year rolling window)
3. Optimize SQL views with proper indexing
4. Monitor query performance closely

**Status**: ✅ Architecture designed for performance

---

### Risk 4: Unknown Purpose of user_field_3

**Risk**: We don't know what this custom field is used for

**Impact**: MEDIUM - Could be critical for some analysis

**Mitigation**:
1. Ask stakeholders what this field represents
2. Review old report visuals for usage
3. Include in new architecture regardless
4. Document once purpose is known

**Status**: ⚠️ Need stakeholder input

---

### Risk 5: Margin Threshold Not Documented

**Risk**: Don't know what defines "low margin" in the report

**Impact**: HIGH - Core report logic unknown

**Mitigation**:
1. Review old report for threshold values
2. Ask stakeholders for business rules
3. Validate with historical data
4. Make threshold configurable (parameter)

**Status**: ⚠️ Need to determine from old report

---

## Next Steps

### Immediate Actions (This Week)

#### 1. Information Gathering ⭐ CRITICAL

**Tasks**:
- [ ] Export old report metadata:
  - [ ] Model Measures.csv
  - [ ] Model Columns.csv
  - [ ] Model Tables.csv
  - [ ] Model Relationships.csv
- [ ] Take screenshots of all report pages
- [ ] Document current metric values for validation baseline
- [ ] Record row counts from current tables

**Owner**: B.Fox
**Due**: End of Week 1

---

#### 2. Stakeholder Interview ⭐ CRITICAL

**Questions to Ask**:
1. What defines "low margin" in this report? (threshold %)
2. What is the purpose of `user_field_3` in InMaster table?
3. What are the top 5 most critical metrics in this report?
4. What are typical use cases for this report?
5. Are there any known data quality issues we should watch for?
6. What is acceptable downtime for migration?
7. What level of variance from old report is acceptable?

**Owner**: B.Fox
**Due**: Week 1

---

#### 3. Source Data Access Verification

**Tasks**:
- [ ] Confirm access to EquipRDB64 from Fabric
- [ ] Test query performance on source tables
- [ ] Identify primary keys and indexes
- [ ] Document any data quality issues in source

**Owner**: B.Fox
**Due**: Week 1

---

### Week 1 Deliverables

1. ✅ **MIGRATION-ANALYSIS.md** (this document)
2. ⏳ **OLD-REPORT-DOCUMENTATION.md** (screenshots, measures, current values)
3. ⏳ **STAKEHOLDER-REQUIREMENTS.md** (business rules, thresholds, validation criteria)
4. ⏳ **SQL Views V1**:
   - `Create_vw_Fact_Part_Sales_Txns.sql`
   - `Create_vw_dim_Parts.sql`

---

### Week 2 Deliverables

1. ⏳ Semantic model created and tested
2. ⏳ Initial validation results
3. ⏳ DAX measures migrated
4. ⏳ Sample report pages built

---

### Week 3 Deliverables

1. ⏳ Complete report built
2. ⏳ Full validation completed
3. ⏳ Stakeholder sign-off
4. ⏳ Deployment to production

---

## Questions for Resolution

### Data Questions
1. ❓ What is the business rule for "low margin"? (percentage threshold)
2. ❓ What is `user_field_3` in InMaster? (purpose, values)
3. ❓ Are there any transaction types to exclude from analysis?
4. ❓ Should we include returns in the analysis? (TYPE field)
5. ❓ Is `REF_NO` unique per transaction, or do we need a composite key?

### Architecture Questions
6. ❓ Should we create separate fact tables for sales vs. returns?
7. ❓ Do we need a separate aggregated fact table for performance?
8. ❓ Should margin calculations be in SQL view or DAX measures?
9. ❓ Do we need Customer and Salesman dimensions, or are IDs sufficient?

### Migration Questions
10. ❓ What is acceptable variance during validation? (0.1%? 1%?)
11. ❓ How long can old report run in parallel? (1 week? 1 month?)
12. ❓ Who are the pilot users for initial testing?

---

## Success Criteria

### Data Accuracy
- ✅ Row counts match within 0.1%
- ✅ Financial totals match within 0.1%
- ✅ Low margin counts match exactly (once threshold defined)
- ✅ Inventory values match exactly

### Performance
- ✅ Report loads in <5 seconds
- ✅ Visuals render in <2 seconds
- ✅ Refresh completes in <10 minutes
- ✅ No degradation from old report

### Functionality
- ✅ All old report features replicated
- ✅ All filters and slicers work correctly
- ✅ Drill-through and interactions work
- ✅ Mobile layout functional

### Stakeholder Acceptance
- ✅ Stakeholders verify accuracy
- ✅ All critical use cases tested
- ✅ Training completed (if needed)
- ✅ Sign-off received

---

**Document Version**: 1.0 - Initial Analysis
**Last Updated**: January 8, 2026
**Created By**: B.Fox with Claude Code Assistant
**Next Review**: After stakeholder interview and old report export
