# Part Sales with Low Margin - Complete Implementation Guide

## Overview

This guide walks you through the complete implementation of the migrated "Part Sales with Low Margin" report using the corrected hybrid approach that merges InMaster + jdis_Part_Information.

**Key Architecture Decision:**
- **dim_Parts_LowMargin**: Hybrid of jdis (for current pricing/inventory) + InMaster (for LOW flag)
- **Fact_InTrans**: Direct import from InTrans_Incremental (2-year filter, TYPE='I' only)
- **No separate dataflow**: All Power Query runs in Power BI Desktop

---

## Phase 1: Power Query Setup

### Step 1.1: Create Fact_InTrans Query

1. Open Power BI Desktop
2. Go to **Home** > **Transform Data** (Power Query Editor)
3. Click **New Source** > **SQL Server**
4. Enter connection:
   - Server: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com`
   - Database: `LH_Master_Data`
5. Find and select: `dbo.InTrans_Incremental`
6. Click **Transform Data**
7. Click **Advanced Editor**
8. Replace ALL code with contents from: `Fact_InTrans_PowerBI.pq`
9. Click **Done**
10. Rename query to: `Fact_InTrans`
11. Wait for preview to load (should take 30-60 seconds)

**Validation:**
- Preview shows transactions with TransDatetime in last 2 years only
- All rows have `Type = "I"`
- Columns include: PartNumber, TransDatetime, SaleValue, CostValue, Qty, ActualMarginDollars

### Step 1.2: Create dim_Parts_LowMargin Query (HYBRID)

1. Still in Power Query Editor
2. Click **New Source** > **SQL Server** (same connection as above)
3. Find and select: `dbo.jdis_Part_Information`
4. Click **Transform Data**
5. Click **Advanced Editor**
6. Replace ALL code with contents from: `dim_Parts_LowMargin_PowerBI_CORRECTED.pq`
7. Click **Done**
8. Rename query to: `dim_Parts_LowMargin`
9. Wait for preview to load (should take 30-60 seconds)

**Validation:**
- Preview shows parts with columns from BOTH tables:
  - From jdis: PartNumber, ListPrice, SellPrice1, QuantityOnHand, InventoryCost
  - From InMaster: LowMarginFlag, StockOrderPrice, BulkBinQty
  - Calculated: IsLowMarginFlagged, OnHandQty
- Most rows will have blank/null LowMarginFlag (normal - only ~1,320 flagged)
- All rows should have InventoryCost values (from jdis)

### Step 1.3: Close & Apply

1. Click **Close & Apply**
2. Wait for initial refresh (3-5 minutes expected)
3. Model will load with both tables

---

## Phase 2: Data Model Configuration

### Step 2.1: Verify/Create Relationships

1. Click **Model** view (left sidebar)
2. Look for relationship: `Fact_InTrans[PartNumber]` → `dim_Parts_LowMargin[PartNumber]`

**If relationship exists:**
- Right-click the relationship line
- Select **Properties**
- Set to **Inactive** (critical for RELATED() to work)
- Set Cardinality: **Many to One (*:1)**
- Set Cross filter direction: **Single**

**If relationship does NOT exist:**
- Drag `Fact_InTrans[PartNumber]` to `dim_Parts_LowMargin[PartNumber]`
- In relationship properties:
  - Set to **Inactive**
  - Cardinality: **Many to One (*:1)**
  - Cross filter direction: **Single**

**Why Inactive?**
- RELATED() function requires inactive relationship when tables are not directly filtered
- Prevents automatic filter propagation that could cause performance issues

### Step 2.2: Add Calculated Columns to Fact_InTrans

1. Stay in **Model** view
2. Click on `Fact_InTrans` table
3. Click **New Column** in ribbon
4. Add these 6 calculated columns:

**Column 1: LowMarginFlag**
```dax
LowMarginFlag =
RELATED(dim_Parts_LowMargin[LowMarginFlag])
```

**Column 2: IsLowMarginFlagged**
```dax
IsLowMarginFlagged =
RELATED(dim_Parts_LowMargin[IsLowMarginFlagged])
```

**Column 3: StockOrderPrice**
```dax
StockOrderPrice =
RELATED(dim_Parts_LowMargin[StockOrderPrice])
```

**Column 4: ListPriceManuf**
```dax
ListPriceManuf =
RELATED(dim_Parts_LowMargin[ListPrice])
```

**Column 5: OriginalMarginDollars**
```dax
OriginalMarginDollars =
VAR UnitSellPrice = [SaleValue] / [Qty]
VAR UnitCost = RELATED(dim_Parts_LowMargin[StockOrderPrice])
VAR OriginalMarginPerUnit = UnitSellPrice - UnitCost
RETURN
    OriginalMarginPerUnit * [Qty]
```

**Column 6: MarginDiscrepancyDollars**
```dax
MarginDiscrepancyDollars =
[ActualMarginDollars] - [OriginalMarginDollars]
```

**Validation:**
- All 6 columns should appear in Fact_InTrans table
- LowMarginFlag will be blank for most rows (normal)
- IsLowMarginFlagged will be TRUE/FALSE
- StockOrderPrice, ListPriceManuf should have dollar values
- OriginalMarginDollars and MarginDiscrepancyDollars should calculate

---

## Phase 3: DAX Measures (TMDL Method)

### Option A: Direct TMDL File Edit (Faster)

1. Close Power BI Desktop (MUST close first!)
2. Navigate to: `Part Sales with Low Margin.SemanticModel\definition\tables\`
3. Open `_Measures.tmdl` in VS Code or text editor
4. Find line 80 (the line BEFORE `column Value`)
5. Copy ALL measures from `DAX-MEASURES-TMDL.txt` (lines 10-254)
6. Paste them ABOVE the `column Value` line
7. Save `_Measures.tmdl`
8. Open Power BI Desktop
9. Power BI will reload the model with all measures

### Option B: Manual Measure Creation (Slower)

1. In Power BI Desktop, click **Report** view
2. Right-click `_Measures` table in Fields pane
3. Click **New Measure**
4. Copy measure formula from `DAX-MEASURES-TMDL.txt`
5. Paste into formula bar
6. Press Enter
7. Right-click the new measure > **Format** > set format string
8. Repeat for all 25+ measures

**Recommendation:** Use Option A (TMDL) - much faster!

**Validation:**
- All measures appear in `_Measures` table
- Test a few measures in a card visual to verify they calculate
- Key measures to test:
  - `Sale $` - should show total sales dollars
  - `Actual Margin $` - should show margin dollars
  - `Total SOH Qty` - should show inventory quantity

---

## Phase 4: Report Page Layout

### Page 1: Parts Sales with Low Margins

**Purpose:** Show all transactions for parts flagged as LOW margin, with margin analysis

**Key Visuals:**
1. **Table visual** with columns:
   - Fact_InTrans[PartNumber]
   - Fact_InTrans[LowMarginFlag]
   - [Sale $]
   - [Cost $]
   - [Actual Margin $]
   - [Margin Value %]
   - [Original Margin $]
   - [Original Margin %]
   - [Margin Discrepancy $]

2. **Slicer** for Fact_InTrans[LowMarginFlag]
   - Pre-filter to "LOW" only

3. **Card visuals** for KPIs:
   - Total [Sale $]
   - Total [Actual Margin $]
   - Avg [Margin Value %]

**Conditional Formatting:**
- Apply `Margin Color Code` measure to `Margin Value %` column
- Apply `Margin $ Discrepancy Color Code` to `Margin Discrepancy $` column

### Page 2: Inventory Cost Discrepancy

**Purpose:** Compare current inventory cost vs MDP (Manufacturer's Designated Price)

**Key Visuals:**
1. **Table visual** with columns:
   - dim_Parts_LowMargin[PartNumber]
   - dim_Parts_LowMargin[LowMarginFlag]
   - [Total SOH Qty]
   - [Inventory Cost]
   - [MDP Value]
   - [Desired Margin $]
   - [Actual Margin $ (INV)]
   - [Desired Margin %]
   - [Actual Margin % (INV)]

2. **Card visuals**:
   - [Positive Margin $ Discrepancy]
   - [Negative Margin $ Discrepancy]
   - [Net Margin $ Discrepancy]

3. **Slicer** for dim_Parts_LowMargin[IsLowMarginFlagged]

### Page 3: Low Action Items

**Purpose:** Identify parts where inventory cost is higher than MDP (action needed)

**Key Visuals:**
1. **Table visual** with columns:
   - dim_Parts_LowMargin[PartNumber]
   - [Stock Order Price]
   - [Inventory Cost]
   - [% Difference]
   - [Total SOH Qty]
   - [List Price]
   - [Sell Price]

2. **Filter** on table:
   - `[% Difference] < 0` (show only parts where cost > MDP)

**Conditional Formatting:**
- Apply `% Diff Discr (Low) Color Code` to `% Difference` column

---

## Phase 5: Validation

### Validation Checklist

**Data Volume:**
- [ ] Fact_InTrans row count: 3-6M rows (2 years of TYPE='I' transactions)
- [ ] dim_Parts_LowMargin row count: Similar to jdis_Part_Information active parts
- [ ] Low margin parts count (~1,320): `CALCULATE(COUNTROWS(dim_Parts_LowMargin), dim_Parts_LowMargin[IsLowMarginFlagged] = TRUE)`

**Data Quality:**
- [ ] Run `Type Check` measure - should show "✅ All TYPE = I"
- [ ] Run `Margin Calc Check` measure - should show "✅ Margins match"
- [ ] Verify LowMarginFlag values: Only "LOW" or blank (no other values)
- [ ] Verify InventoryCost: No nulls in dim_Parts_LowMargin (from jdis)

**Performance:**
- [ ] Initial refresh: 3-5 minutes
- [ ] Subsequent refreshes: 2-4 minutes
- [ ] Visual rendering: <5 seconds for most visuals
- [ ] Slicer interactions: <2 seconds

**Compare to Old Report:**
- [ ] Total Sales $ matches old report (±1% acceptable due to date filter differences)
- [ ] Low margin parts count matches (~1,320)
- [ ] Margin calculations match for sample parts
- [ ] Inventory cost totals match for Pages 2 & 3

---

## Phase 6: Optimization Tips

### If Refresh is Slow (>5 minutes):

1. **Check Query Folding:**
   - In Power Query Editor, right-click last step
   - Select "View Native Query"
   - If grayed out, folding is broken - review transformations

2. **Reduce Column Count:**
   - Remove unused columns in Power Query
   - Only load columns actually used in visuals/measures

3. **Verify Date Filter:**
   - Confirm FilterDateRange step in Fact_InTrans is working
   - Should only load 2 years of data, not all 6+ years

### If Visuals are Slow:

1. **Use Pre-calculated Columns:**
   - Margin calculations already in Fact_InTrans calculated columns
   - Measures just SUM() the columns (very fast)

2. **Limit Visual Rows:**
   - Use Top N filter on table visuals
   - Default to 1000 rows, use "Load More" if needed

3. **Reduce Cross-filtering:**
   - Keep relationships inactive where possible
   - Use RELATED() instead of active relationships

---

## Troubleshooting

### Error: "The column 'StockOrderPrice' of the table wasn't found"

**Cause:** Using old HYBRID query instead of CORRECTED version

**Fix:**
- Use `dim_Parts_LowMargin_PowerBI_CORRECTED.pq`
- This version has correct column names from each source table

### Error: Relationship validation failed

**Cause:** Active relationship preventing RELATED() from working

**Fix:**
- Set Fact_InTrans → dim_Parts_LowMargin relationship to **Inactive**
- Verify Cardinality is Many to One (*:1)

### Warning: Circular dependency in calculated column

**Cause:** OriginalMarginDollars or MarginDiscrepancyDollars referencing each other

**Fix:**
- Ensure OriginalMarginDollars is created BEFORE MarginDiscrepancyDollars
- MarginDiscrepancyDollars should reference [OriginalMarginDollars], not calculate it again

### Numbers don't match old report

**Possible causes:**
1. Date filter difference (verify 2-year filter in Fact_InTrans)
2. Type filter missing (verify TYPE='I' only)
3. Low margin flag missing (verify LowMarginFlag calculated column)
4. Margin calculation difference (verify OriginalMarginDollars formula)

**Debugging steps:**
1. Compare row counts: Fact_InTrans vs old report source
2. Spot-check 5-10 specific PartNumbers in both reports
3. Verify calculated columns populated correctly
4. Check for null handling in margin calculations

---

## Files Reference

**Power Query:**
- `Fact_InTrans_PowerBI.pq` - Transaction fact table (2-year filter)
- `dim_Parts_LowMargin_PowerBI_CORRECTED.pq` - Hybrid dimension (jdis + InMaster)

**DAX:**
- `DAX-MEASURES-TMDL.txt` - All measures in TMDL format for copy/paste
- `_Measures.tmdl` - Target file for TMDL measures

**Documentation:**
- `COLUMN-SOURCE-DECISION.md` - Explains column source mapping
- `POWER-BI-SETUP-GUIDE.md` - Original setup guide
- `DAX-MIGRATION-GUIDE.md` - Old measure to new measure mapping

---

## Success Criteria

Report is ready for production when:

✅ All 3 pages render correctly
✅ Low margin flag shows ~1,320 parts
✅ Margins match old report (±1%)
✅ Refresh completes in <5 minutes
✅ Visuals respond in <5 seconds
✅ Stakeholders confirm numbers are accurate
✅ Validation measures show green checkmarks

---

## Next Steps After Implementation

1. **Schedule Refresh:**
   - Publish to Power BI Service
   - Set daily refresh at 6:00 AM
   - Monitor refresh success/failures

2. **User Training:**
   - Walk stakeholders through new report
   - Explain any layout changes
   - Gather feedback on additional features

3. **Add Enhancements:**
   - User mentioned stakeholders want to add features
   - Capture requirements in separate document
   - Prioritize based on impact

4. **Decommission Old Report:**
   - After 1 week of validation
   - Archive old report (don't delete)
   - Redirect users to new report

---

**Questions or Issues?**
Refer to troubleshooting section or check documentation files in project folder.
