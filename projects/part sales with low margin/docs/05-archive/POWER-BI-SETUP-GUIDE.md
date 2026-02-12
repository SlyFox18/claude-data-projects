# Power BI Setup Guide - Low Margin Report

## Current Status
✅ You have connected to Lakehouse and brought in tables
✅ You have existing dimensions ready: dim_BranchLocation, dim_DateTable, dim_CustomerList, dim_Parts
✅ You have raw tables: InMaster, InTrans_Incremental, jdis_Part_Information
✅ Import mode selected (good choice for flexibility)

---

## Step-by-Step Setup Instructions

### PHASE 1: Create Power Query Transformations

#### 1. Create dim_Parts_LowMargin Query

In Power Query Editor:

**Option A - Replace existing InMaster query:**
1. Click on **InMaster** query in the Queries pane
2. Click **Advanced Editor** (top ribbon)
3. **Delete all existing code**
4. **Copy and paste** the code from `dim_Parts_LowMargin_PowerBI.pq`
5. Click **Done**
6. **Rename** the query from "InMaster" to **"dim_Parts_LowMargin"**

**Option B - Create new query (if you want to keep InMaster):**
1. Right-click in Queries pane → **New Query** → **Blank Query**
2. Click **Advanced Editor**
3. **Copy and paste** the code from `dim_Parts_LowMargin_PowerBI.pq`
4. Click **Done**
5. **Rename** the query to **"dim_Parts_LowMargin"**

---

#### 2. Create Fact_InTrans Query

**Option A - Replace existing InTrans_Incremental query:**
1. Click on **InTrans_Incremental** query
2. Click **Advanced Editor**
3. **Delete all existing code**
4. **Copy and paste** the code from `Fact_InTrans_PowerBI.pq`
5. Click **Done**
6. **Rename** the query to **"Fact_InTrans"**

**Option B - Create new query:**
1. Right-click in Queries pane → **New Query** → **Blank Query**
2. Click **Advanced Editor**
3. **Copy and paste** the code from `Fact_InTrans_PowerBI.pq`
4. Click **Done**
5. **Rename** the query to **"Fact_InTrans"**

---

#### 3. Remove Unused Queries

You no longer need the raw table queries (they've been transformed):

1. Right-click on **jdis_Part_Information** → **Delete** (you already have dim_Parts)
2. If you created new queries above, delete the original **InMaster** and **InTrans_Incremental**

**Final Queries List Should Be:**
- ✅ dim_BranchLocation
- ✅ dim_CustomerList
- ✅ dim_DateTable
- ✅ dim_Parts
- ✅ dim_Parts_LowMargin (NEW)
- ✅ Fact_InTrans (NEW)

---

#### 4. Disable Load for Reference Queries (Optional Performance Optimization)

If you have any queries that are just for reference (not loaded to model):
1. Right-click query → **Enable load** (uncheck)

**Keep Load Enabled for these 6 queries above** - they all need to load to the model.

---

#### 5. Close and Apply

1. Click **Close & Apply** (top left)
2. **Wait for initial refresh** (this will take 5-8 minutes - similar to old report)
3. Watch the status bar to monitor progress

---

### PHASE 2: Create Relationships

Once data loads, go to **Model View** (left sidebar, third icon):

#### Create Active Relationships:

1. **Fact_InTrans[TransDatetime] → dim_DateTable[Date]**
   - Drag from `Fact_InTrans[TransDatetime]` to `dim_DateTable[Date]`
   - Cardinality: Many to One (\*:1)
   - Cross filter direction: Single
   - Make this relationship active: ✅

2. **Fact_InTrans[Branch] → dim_BranchLocation[Branch]**
   - Drag from `Fact_InTrans[Branch]` to `dim_BranchLocation[Branch]`
   - Cardinality: Many to One (\*:1)
   - Cross filter direction: Single
   - Make this relationship active: ✅

3. **Fact_InTrans[PartNumber] → dim_Parts[PartNumber]**
   - Drag from `Fact_InTrans[PartNumber]` to `dim_Parts[PartNumber]`
   - Cardinality: Many to One (\*:1)
   - Cross filter direction: Single
   - Make this relationship active: ✅

4. **Fact_InTrans[CustomerNo] → dim_CustomerList[CustomerNo]**
   - Drag from `Fact_InTrans[CustomerNo]` to `dim_CustomerList[CustomerNo]`
   - Cardinality: Many to One (\*:1)
   - Cross filter direction: Single
   - Make this relationship active: ✅

#### Create Inactive Relationship (for RELATED function):

5. **Fact_InTrans[PartNumber] → dim_Parts_LowMargin[PartNumber]**
   - Drag from `Fact_InTrans[PartNumber]` to `dim_Parts_LowMargin[PartNumber]`
   - Cardinality: Many to One (\*:1)
   - Cross filter direction: Single
   - **Make this relationship active: ❌ UNCHECK** (keep inactive)
   - This inactive relationship allows RELATED() to work

---

### PHASE 3: Add Calculated Columns to Fact_InTrans

Go to **Data View** (left sidebar, second icon):

1. Click on **Fact_InTrans** table in the Data pane

2. Click **New Column** (top ribbon) and add each of these:

```dax
LowMarginFlag =
    RELATED(dim_Parts_LowMargin[LowMarginFlag])
```

```dax
StockOrderPrice =
    RELATED(dim_Parts_LowMargin[StockOrderPrice])
```

```dax
ListPriceManuf =
    RELATED(dim_Parts_LowMargin[ListPrice])
```

```dax
OriginalMarginDollars =
    ([ListPriceManuf] - [StockOrderPrice]) * [Qty]
```

```dax
MarginDiscrepancyDollars =
    [ActualMarginDollars] - [OriginalMarginDollars]
```

```dax
IsLowMarginFlagged =
    [LowMarginFlag] = "LOW"
```

**After adding these columns:**
- The model will calculate them (may take 1-2 minutes for 3-6M rows)
- These are now stored columns, not calculated on every query (FAST!)

---

### PHASE 4: Create Base Measures

Create a **Measures Table** (best practice for organization):

1. **Home** ribbon → **Enter Data**
2. Leave blank, just click **Load**
3. Name it **"_Measures"** (underscore makes it sort to top)

Now add measures to this table:

**Sales Measures:**
```dax
Sale $ = SUM(Fact_InTrans[SaleValue])
```

```dax
Cost $ = SUM(Fact_InTrans[CostValue])
```

```dax
Qty = SUM(Fact_InTrans[Qty])
```

**Margin Measures (Pre-calculated - FAST!):**
```dax
Actual Margin $ = SUM(Fact_InTrans[ActualMarginDollars])
```

```dax
Original Margin $ = SUM(Fact_InTrans[OriginalMarginDollars])
```

```dax
Margin Discrepancy $ = SUM(Fact_InTrans[MarginDiscrepancyDollars])
```

**Margin Percentage Measures:**
```dax
Actual Margin % =
    DIVIDE([Actual Margin $], [Sale $], 0)
```

```dax
Original Margin % =
    DIVIDE([Original Margin $], [Sale $], 0)
```

**Format these measures:**
- Sale $, Cost $, margins: Currency ($#,##0.00)
- Margin %: Percentage (0.00%)
- Qty: Whole Number (#,##0)

---

### PHASE 5: Validation

Before building visuals, validate your data:

#### Check 1: Row Counts

Create a Card visual with:
```dax
Total Transactions = COUNTROWS(Fact_InTrans)
```

**Expected**: 3-6 million rows

#### Check 2: Verify Invoice Filter

Create a Table visual with:
- Fact_InTrans[Type]
- [Total Transactions]

**Expected**: Only "I" (invoices) should appear

#### Check 3: Spot Check Calculations

Create a Table visual with:
- Fact_InTrans[TransId] (first 10)
- Fact_InTrans[SaleValue]
- Fact_InTrans[CostValue]
- Fact_InTrans[ActualMarginDollars]

**Verify**: ActualMarginDollars = SaleValue - CostValue

#### Check 4: Compare to Old Report

Create Cards with these measures and compare to old report:
- [Sale $]
- [Cost $]
- [Actual Margin $]
- [Actual Margin %]

**Expected**: Should match old report totals (within rounding)

#### Check 5: Low Margin Flag Distribution

```dax
Low Margin Parts =
    CALCULATE(
        DISTINCTCOUNT(Fact_InTrans[PartNumber]),
        Fact_InTrans[IsLowMarginFlagged] = TRUE
    )
```

```dax
Low Margin Sales $ =
    CALCULATE(
        [Sale $],
        Fact_InTrans[IsLowMarginFlagged] = TRUE
    )
```

---

### PHASE 6: Build Report Pages

Now you're ready to replicate the old report pages! You have all the data and measures you need.

**Key advantages of this setup:**
- ✅ Fast refresh (5-8 minutes, similar to old report)
- ✅ All calculations pre-computed (calculated columns)
- ✅ Simple DAX measures (just SUM the pre-calculated columns)
- ✅ Full flexibility to add more measures
- ✅ No separate dataflow refresh to manage

---

## Troubleshooting

### Issue: Refresh takes longer than 8 minutes

**Solutions:**
1. Check if you're loading unnecessary columns in Power Query
2. Ensure you're filtering to TYPE = 'I' early in the query
3. Consider reducing the date range if 2 years is too much data

### Issue: RELATED() function returns blank

**Check:**
1. Relationship exists: Fact_InTrans[PartNumber] → dim_Parts_LowMargin[PartNumber]
2. Relationship is configured correctly (Many to One)
3. PartNumber values match between tables (check for case sensitivity, spaces)

### Issue: Calculated columns are slow

**This is normal for initial calculation:**
- 3-6M rows × 6 calculated columns = 18-36M calculations
- Should take 1-2 minutes
- Only happens once when you create the column
- After that, it's stored and FAST!

### Issue: Model size is large

**Expected:**
- 3-6M rows with 20+ columns = 500MB-1GB compressed
- This is normal for Import mode
- If too large, consider:
  - Reducing columns in Power Query (only select what you need)
  - Filtering to smaller date range
  - Using aggregations for older data

---

## Next Steps After Setup

1. ✅ Migrate remaining DAX measures from old report
2. ✅ Create report pages matching old layout
3. ✅ Extensive validation against old report
4. ✅ User acceptance testing
5. ✅ Schedule refresh (daily or as needed)

---

## Performance Expectations

| Metric | Expected Value |
|--------|----------------|
| Initial Model Load | 5-8 minutes |
| Refresh (Daily) | 5-8 minutes |
| Model Size | 500MB-1GB |
| Query Performance | Fast (pre-calculated columns) |
| CU Usage | Moderate (one refresh, no dataflow overhead) |

---

## Files Reference

- `dim_Parts_LowMargin_PowerBI.pq` - Copy this code for dim_Parts_LowMargin query
- `Fact_InTrans_PowerBI.pq` - Copy this code for Fact_InTrans query
- `Old Report Measures.csv` - Reference for migrating remaining measures

---

**You're all set! Follow these steps and you'll have a clean, fast, maintainable low margin report.** 🚀
