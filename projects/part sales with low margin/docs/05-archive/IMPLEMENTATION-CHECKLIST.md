# Implementation Checklist - Low Margin Report Migration

## Current Status: Ready to Build Model

✅ **Completed:**
- Power BI report created with connection to Lakehouse
- Fact_InTrans_PowerBI.pq created with 2-year date filter
- dim_Parts_LowMargin_PowerBI.pq updated with inventory fields
- Existing dimensions loaded (dim_Parts, dim_BranchLocation, dim_DateTable, dim_CustomerList)
- DAX Migration Guide created
- Home header measure created

---

## PHASE 1: Update Power Query (IN POWER BI)

### Step 1.1: Update dim_Parts_LowMargin Query

1. Open Power Query Editor (Transform Data button)
2. Find the **dim_Parts_LowMargin** query
3. Click **Advanced Editor**
4. **Replace all code** with contents from: `dim_Parts_LowMargin_PowerBI.pq`
5. Click **Done**
6. Verify preview shows these columns:
   - PartNumber
   - Franchise
   - Branch
   - LowMarginFlag
   - IsLowMarginFlagged
   - StockOrderPrice
   - ListPrice
   - BulkBinQty
   - OnHandQty
   - Cost

### Step 1.2: Verify Fact_InTrans Query

1. Click on **Fact_InTrans** query
2. Verify it has the date filter step: `FilterDateRange`
3. Verify preview shows ~3-6M rows (not 15M+)
4. Verify columns include:
   - TransId, RONumber, TransDatetime
   - Branch, PartNumber, Franchise, CustomerNo, Salesman
   - Type, Qty, SaleValue, CostValue
   - Description, TradeType
   - ActualMarginDollars (pre-calculated)

### Step 1.3: Clean Up Unnecessary Queries

Delete these queries (right-click → Delete):
- ❌ jdis_Part_Information (raw table - not needed)
- ❌ InMaster (if loaded separately - dim_Parts_LowMargin references it directly)
- ❌ InTrans_Incremental (if loaded separately - Fact_InTrans references it directly)

### Step 1.4: Close & Apply

1. Click **Close & Apply** (top left)
2. **Wait 5-10 minutes** for initial model refresh
3. Watch status bar for progress
4. **Expected outcome:** Model loads successfully with 3-6M transaction rows

**✅ Checkpoint:** Model loaded, no errors in Power Query

---

## PHASE 2: Fix Relationships (MODEL VIEW)

Go to **Model View** (left sidebar, third icon from top)

### Current Relationship Issue:

You currently have:
- ✅ Fact_InTrans → dim_BranchLocation (ACTIVE)
- ✅ Fact_InTrans → dim_DateTable (ACTIVE)
- ⚠️ Fact_InTrans → dim_Parts_LowMargin (ACTIVE) - **SHOULD BE INACTIVE**
- ⚠️ dim_Parts → dim_Parts_LowMargin (ACTIVE) - **DELETE THIS**

### Step 2.1: Delete Unwanted Relationship

1. Click on the relationship line between **dim_Parts** and **dim_Parts_LowMargin**
2. Press **Delete** key
3. Confirm deletion

**Why:** This relationship creates ambiguity and isn't needed

### Step 2.2: Make Fact_InTrans → dim_Parts_LowMargin INACTIVE

1. **Double-click** the relationship line between **Fact_InTrans[PartNumber]** and **dim_Parts_LowMargin[PartNumber]**
2. **Uncheck** "Make this relationship active"
3. Click **OK**

**Why:** We want RELATED() function to use this relationship in calculated columns

### Step 2.3: Create Missing Relationships

If not already created, add these **ACTIVE** relationships:

#### Fact_InTrans → dim_Parts
1. Drag from `Fact_InTrans[PartNumber]` to `dim_Parts[PartNumber]`
2. Cardinality: Many to One (*:1)
3. Cross filter direction: Single
4. **Make this relationship active:** ✅ CHECK

#### Fact_InTrans → dim_CustomerList
1. Drag from `Fact_InTrans[CustomerNo]` to `dim_CustomerList[CustomerNo]`
2. Cardinality: Many to One (*:1)
3. Cross filter direction: Single
4. **Make this relationship active:** ✅ CHECK

### Final Relationship Diagram:

```
┌─────────────────┐
│ dim_DateTable   │
└────────┬────────┘
         │ (ACTIVE)
         │ Date
         │
┌─────────────────┐      ┌──────────────────┐
│dim_BranchLocation│      │   dim_Parts      │
└────────┬────────┘      └────────┬─────────┘
         │ (ACTIVE)               │ (ACTIVE)
         │ Branch                 │ PartNumber
         │                        │
         ├────────────────────────┼────────────────────┐
         │                        │                    │
┌────────▼────────────────────────▼────────────────────▼──────┐
│                   Fact_InTrans                               │
│  TransId, RONumber, TransDatetime, Branch, PartNumber,       │
│  Franchise, CustomerNo, Salesman, Qty, SaleValue,            │
│  CostValue, ActualMarginDollars, Description, TradeType      │
└────────┬─────────────────────────┬──────────────────┬────────┘
         │ (ACTIVE)                │ (INACTIVE)       │ (ACTIVE)
         │ CustomerNo              │ PartNumber       │
         │                         │                  │
┌────────▼────────┐     ┌──────────▼─────────────┐   │
│dim_CustomerList │     │dim_Parts_LowMargin     │   │
└─────────────────┘     │ (for RELATED() lookup) │   │
                        └────────────────────────┘   │
```

**✅ Checkpoint:** Relationships configured correctly

---

## PHASE 3: Add Calculated Columns to Fact_InTrans (DATA VIEW)

Go to **Data View** (left sidebar, second icon from top)

Click on **Fact_InTrans** table in the Data pane

For each calculated column below:
1. Click **New Column** (top ribbon)
2. Copy the DAX formula
3. Press Enter
4. **Wait** for calculation to complete (1-2 minutes per column for 3-6M rows)

### Column 1: LowMarginFlag
```dax
LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])
```
**Expected:** Values like "LOW", "NORMAL", blank

---

### Column 2: StockOrderPrice
```dax
StockOrderPrice = RELATED(dim_Parts_LowMargin[StockOrderPrice])
```
**Expected:** Numeric values (manufacturer default price)

---

### Column 3: ListPriceManuf
```dax
ListPriceManuf = RELATED(dim_Parts_LowMargin[ListPrice])
```
**Expected:** Numeric values (list price from manufacturer)

---

### Column 4: OriginalMarginDollars
```dax
OriginalMarginDollars = ([ListPriceManuf] - [StockOrderPrice]) * [Qty]
```
**Expected:** Numeric values (expected margin based on list price)

---

### Column 5: MarginDiscrepancyDollars
```dax
MarginDiscrepancyDollars = [ActualMarginDollars] - [OriginalMarginDollars]
```
**Expected:** Positive/negative values (difference between actual and expected margin)

---

### Column 6: IsLowMarginFlagged
```dax
IsLowMarginFlagged = [LowMarginFlag] = "LOW"
```
**Expected:** TRUE/FALSE values

---

**⏱️ Time Estimate:** 6-12 minutes total (calculation time for all columns)

**✅ Checkpoint:** All 6 calculated columns added and calculated

---

## PHASE 4: Create Base Measures (_Measures Table)

Click on **_Measures** table in the Data pane

For each measure below:
1. Click **New Measure** (top ribbon)
2. Copy the DAX formula
3. Press Enter
4. **Format the measure** (see format string below each)

### Transaction Sales Measures

#### Measure 1: Sale $
```dax
Sale $ = SUM(Fact_InTrans[SaleValue])
```
**Format:** Home → Format → Currency → Custom → `$#,##0.00`

---

#### Measure 2: Cost $
```dax
Cost $ = SUM(Fact_InTrans[CostValue])
```
**Format:** Currency → `$#,##0.00`

---

#### Measure 3: Qty
```dax
Qty = SUM(Fact_InTrans[Qty])
```
**Format:** Whole Number → `#,##0`

---

### Margin Measures (Pre-calculated - FAST!)

#### Measure 4: Actual Margin $
```dax
Actual Margin $ = SUM(Fact_InTrans[ActualMarginDollars])
```
**Format:** Currency → `$#,##0.00`

---

#### Measure 5: Original Margin $
```dax
Original Margin $ = SUM(Fact_InTrans[OriginalMarginDollars])
```
**Format:** Currency → `$#,##0.00`

---

#### Measure 6: Margin Discrepancy $
```dax
Margin Discrepancy $ = SUM(Fact_InTrans[MarginDiscrepancyDollars])
```
**Format:** Currency → `$#,##0.00`

---

### Margin Percentage Measures

#### Measure 7: Margin Value %
```dax
Margin Value % = DIVIDE([Actual Margin $], [Sale $], 0)
```
**Format:** Percentage → Custom → `0.00%`

---

#### Measure 8: Original Margin %
```dax
Original Margin % = DIVIDE([Original Margin $], [Sale $], 0)
```
**Format:** Percentage → `0.00%`

---

**✅ Checkpoint:** 8 base measures created and formatted

---

## PHASE 5: Validation (TEST YOUR MEASURES)

### Create Validation Card Visuals

Create a new blank page called "Validation"

Add **Card** visuals with these measures:

1. **Total Transactions** (create new measure):
```dax
Total Transactions = COUNTROWS(Fact_InTrans)
```
**Expected:** 3-6M rows (2 years of invoice data)

---

2. **Sale $**
**Compare to old report total** - should be similar (within date range differences)

---

3. **Cost $**
**Compare to old report total**

---

4. **Actual Margin $**
**Compare to old report "Actual Margin" or "Margin Value"**

---

5. **Margin Value %**
**Compare to old report overall margin %**

---

### Create Spot Check Table

Add **Table** visual with these fields:
- Fact_InTrans[TransId] (first 10 rows)
- Fact_InTrans[SaleValue]
- Fact_InTrans[CostValue]
- Fact_InTrans[ActualMarginDollars]

**Manual calculation check:**
- Pick one row
- Verify: ActualMarginDollars = SaleValue - CostValue

---

### Verify Type Filter

Add **Table** visual:
- Fact_InTrans[Type]
- [Total Transactions]

**Expected:** Only "I" (invoices) should appear

---

**✅ Checkpoint:** Validation checks pass, numbers make sense

---

## PHASE 6: Create Conditional Formatting Measures

Back to **_Measures** table

### Measure 9: Margin Color Code
```dax
Margin Color Code =
SWITCH(
    TRUE(),
    [Margin Value %] < 0, 1,                                    // Red (negative margin)
    [Margin Value %] >= 0 && [Margin Value %] < 0.05, 2,       // Pink (0-5%)
    [Margin Value %] >= 0.05 && [Margin Value %] < 0.10, 3,    // Orange (5-10%)
    [Margin Value %] >= 0.10 && [Margin Value %] <= 0.1499, 4, // Yellow (10-14.99%)
    BLANK()                                                     // No color for 15%+
)
```
**Format:** Whole Number → `0`

---

### Measure 10: Margin $ Discrepancy Color Code
```dax
Margin $ Discrepancy Color Code =
SWITCH(
    TRUE(),
    [Margin Discrepancy $] > 1, 1,                                              // Dark Green
    [Margin Discrepancy $] >= 0.75 && [Margin Discrepancy $] <= 1, 2,           // Green
    [Margin Discrepancy $] >= 0.50 && [Margin Discrepancy $] < 0.75, 3,         // Light Green
    [Margin Discrepancy $] >= 0.25 && [Margin Discrepancy $] < 0.50, 4,         // Lighter Green
    [Margin Discrepancy $] > 0 && [Margin Discrepancy $] < 0.25, 5,             // Even Lighter Green
    [Margin Discrepancy $] = 0, 6,                                               // White (neutral)
    [Margin Discrepancy $] < 0 && [Margin Discrepancy $] >= -0.25, 7,           // Real Light Red
    [Margin Discrepancy $] < -0.25 && [Margin Discrepancy $] >= -0.50, 8,       // Lighter Red
    [Margin Discrepancy $] < -0.50 && [Margin Discrepancy $] >= -0.75, 9,       // Light Red
    [Margin Discrepancy $] < -0.75 && [Margin Discrepancy $] >= -1, 10,         // Red
    [Margin Discrepancy $] < -1, 11,                                             // Dark Red
    BLANK()
)
```
**Format:** Whole Number → `0`

---

**✅ Checkpoint:** Conditional formatting measures created

---

## PHASE 7: Create Inventory Analysis Measures

### Measure 11: Total SOH Qty
```dax
Total SOH Qty = SUM(dim_Parts_LowMargin[BulkBinQty]) + SUM(dim_Parts_LowMargin[OnHandQty])
```
**Format:** Whole Number → `#,##0`

---

### Measure 12: Inventory Cost
```dax
Inventory Cost = SUM(dim_Parts_LowMargin[Cost])
```
**Format:** Currency → `$#,##0.00`

---

### Measure 13: MDP Value
```dax
MDP Value = SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]
```
**Format:** Currency → `$#,##0.00`

**Business Logic:** Expected cost based on manufacturer default price

---

### Measure 14: Sell Price 1
```dax
Sell Price 1 = SUM(dim_Parts_LowMargin[ListPrice])
```
**Format:** Currency → `$#,##0.00`

---

### Measure 15: Desired Margin %
```dax
Desired Margin % =
DIVIDE(
    ([Sell Price 1] - [MDP Value]),
    [Sell Price 1],
    0
)
```
**Format:** Percentage → `0.0%`

---

### Measure 16: % Difference (Cost Variance)
```dax
% Difference =
DIVIDE(
    ([MDP Value] - [Inventory Cost]),
    ([MDP Value] + [Inventory Cost]) / 2,
    0
)
```
**Format:** Percentage → `0.0%`

**Business Logic:**
- Positive % = Inventory cost is LOWER than MDP (good!)
- Negative % = Inventory cost is HIGHER than MDP (investigate!)

---

### Measure 17: % Diff Discr (Low) Color Code
```dax
% Diff Discr (Low) Color Code =
SWITCH(
    TRUE(),
    [% Difference] >= 0, 1,                                         // Green (cost lower than MDP)
    [% Difference] <= -0.000001 && [% Difference] > -0.05, 2,      // Light yellow (-0.1% to -5%)
    [% Difference] <= -0.051 && [% Difference] > -0.1, 3,          // Yellow (-5.1% to -10%)
    [% Difference] <= -0.10 && [% Difference] > -0.15, 8,          // Light orange (-10.1% to -15%)
    [% Difference] <= -0.15, 4,                                     // Red (-15% and worse)
    BLANK()
)
```
**Format:** Whole Number → `0`

---

**✅ Checkpoint:** All inventory measures created

---

## PHASE 8: Build Report Pages

Now you're ready to replicate the old report visuals!

### Page 1: Parts Sales with Low Margins

**Table Visual:**
- Columns (from left to right):
  - dim_BranchLocation[Branch]
  - Fact_InTrans[Franchise]
  - Fact_InTrans[PartNumber]
  - Fact_InTrans[Qty]
  - Fact_InTrans[TransDatetime] (Date)
  - Fact_InTrans[RONumber] (Ref No)
  - Fact_InTrans[Salesman]
  - [Cost $]
  - [Sale $]
  - [Actual Margin $] (Margin Value)
  - [Margin Value %]
  - Fact_InTrans[CustomerNo] (Cust No)
  - Fact_InTrans[Description]

**Conditional Formatting:**
- [Margin Value %] column → Background color → Field value → [Margin Color Code]

**Filters:**
- [Margin Value %] < 0 (show only negative margins)

---

### Page 2: Inventory Cost Discrepancy

**Card Visuals (top):**
1. Positive Margin $ Discrepancy (create measure - see DAX Guide)
2. Negative Margin $ Discrepancy (create measure)
3. Net Margin $ Discrepancy (create measure)

**Table Visual:**
- Columns:
  - dim_Parts_LowMargin[Branch]
  - dim_Parts_LowMargin[Franchise]
  - dim_Parts_LowMargin[PartNumber]
  - dim_Parts[Description]
  - [Total SOH Qty]
  - [Inventory Cost]
  - [MDP Value]
  - [Sell Price 1]
  - [Desired Margin %]
  - [Actual Margin %] (INV Cost)
  - [Desired Margin $]
  - [Actual Margin $] (INV Cost)
  - [Margin $ Discrepancy]
  - dim_Parts_LowMargin[LowMarginFlag]
  - Calculate: New Sell Price (see DAX Guide)

**Conditional Formatting:**
- Various columns with color codes (see old report for mapping)

---

### Page 3: Low Action Items

**Table Visual:**
- Columns:
  - dim_Parts_LowMargin[Branch]
  - dim_Parts_LowMargin[Franchise]
  - dim_Parts_LowMargin[PartNumber]
  - dim_Parts[Description]
  - [Total SOH Qty]
  - [MDP Value]
  - [Inventory Cost]
  - [% Difference]

**Conditional Formatting:**
- [% Difference] → Background color → Field value → [% Diff Discr (Low) Color Code]

**Filters:**
- [% Difference] < -0.15 (show significant cost increases)

---

**✅ Checkpoint:** All three report pages created

---

## PHASE 9: Final Testing & Comparison

### Compare to Old Report

Open old report side-by-side with new report

**Check these totals match (within date range differences):**
1. Total Sale $
2. Total Cost $
3. Total Actual Margin $
4. Average Margin %
5. Count of low margin parts
6. Count of transactions

### Test Slicers/Filters

If old report has slicers:
1. Add same slicers to new report
2. Test filtering works correctly
3. Verify totals update properly

### Test Date Filtering

1. Add date slicer using dim_DateTable[Date]
2. Filter to specific month
3. Verify transaction counts make sense

---

## PHASE 10: Publish & Schedule Refresh

### Publish to Workspace

1. File → Publish → Select workspace
2. Wait for publish to complete
3. Click "Open in Power BI service"

### Schedule Refresh

In Power BI Service:
1. Go to dataset settings
2. Schedule refresh → Daily (early morning)
3. Configure credentials for Lakehouse connection

---

## Success Criteria

✅ Model refreshes in 5-8 minutes (similar to old report)
✅ All three report pages match old report layout
✅ Totals match old report (within date range)
✅ Conditional formatting colors match old report
✅ Stakeholders can navigate and use report
✅ Report published and refresh scheduled

---

## Troubleshooting

### If RELATED() returns blank:
- Check relationship exists: Fact_InTrans → dim_Parts_LowMargin
- Check relationship is configured Many to One
- Check PartNumber values match (case, spaces)

### If totals don't match old report:
- Check date range filter (2 years vs different range in old report)
- Verify TYPE = 'I' filter is working
- Compare row counts between reports

### If refresh takes too long:
- Check date filter is working (should be 3-6M rows, not 15M+)
- Verify only needed columns are selected in Power Query
- Check for duplicate rows in Fact_InTrans

---

## Next Steps After Implementation

1. User acceptance testing with stakeholders
2. Training session on new report
3. Gather feedback on improvements
4. Implement requested enhancements
5. Decommission old report

---

**You're ready to start! Begin with PHASE 1 and work through each phase systematically.**

**Estimated Total Time:**
- Power Query setup: 15 minutes
- Model refresh (first time): 5-10 minutes
- Calculated columns: 10-15 minutes
- Measures: 20-30 minutes
- Report pages: 1-2 hours
- Testing: 30-60 minutes

**Total: 3-4 hours** (plus refresh wait time)
