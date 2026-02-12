# Part Sales with Low Margin - Quick Start Checklist

## ⚡ Fast Implementation (30-45 minutes)

### ☐ Phase 1: Power Query (10 min)

1. ☐ Open Power BI Desktop
2. ☐ Transform Data > New Source > SQL Server
   - Server: `xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com`
   - Database: `LH_Master_Data`

3. ☐ Create **Fact_InTrans** query:
   - Select `dbo.InTrans_Incremental` table
   - Advanced Editor > Paste code from `Fact_InTrans_PowerBI.pq`
   - Rename to `Fact_InTrans`

4. ☐ Create **dim_Parts_LowMargin** query:
   - New Source > Same SQL Server connection
   - Select `dbo.jdis_Part_Information` table
   - Advanced Editor > Paste code from `dim_Parts_LowMargin_PowerBI_CORRECTED.pq`
   - Rename to `dim_Parts_LowMargin`

5. ☐ Close & Apply (wait 3-5 minutes)

**✓ Validation:** Both tables load without errors

---

### ☐ Phase 2: Data Model (5 min)

1. ☐ Switch to Model view
2. ☐ Find/Create relationship: `Fact_InTrans[PartNumber]` → `dim_Parts_LowMargin[PartNumber]`
3. ☐ Set relationship to **Inactive** (CRITICAL!)
4. ☐ Set Cardinality: **Many to One (*:1)**

**✓ Validation:** Relationship line is dotted (inactive)

---

### ☐ Phase 3: Calculated Columns (10 min)

Click Fact_InTrans table > New Column > Add these 6 columns:

1. ☐ `LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])`
2. ☐ `IsLowMarginFlagged = RELATED(dim_Parts_LowMargin[IsLowMarginFlagged])`
3. ☐ `StockOrderPrice = RELATED(dim_Parts_LowMargin[StockOrderPrice])`
4. ☐ `ListPriceManuf = RELATED(dim_Parts_LowMargin[ListPrice])`
5. ☐ `OriginalMarginDollars = VAR UnitSellPrice = [SaleValue] / [Qty] VAR UnitCost = RELATED(dim_Parts_LowMargin[StockOrderPrice]) VAR OriginalMarginPerUnit = UnitSellPrice - UnitCost RETURN OriginalMarginPerUnit * [Qty]`
6. ☐ `MarginDiscrepancyDollars = [ActualMarginDollars] - [OriginalMarginDollars]`

**✓ Validation:** All 6 columns visible in Fact_InTrans table, no errors

---

### ☐ Phase 4: DAX Measures (5 min)

**FAST METHOD (Recommended):**
1. ☐ Close Power BI Desktop
2. ☐ Open `_Measures.tmdl` in text editor
3. ☐ Copy lines 10-254 from `DAX-MEASURES-TMDL.txt`
4. ☐ Paste ABOVE line 81 (`column Value`)
5. ☐ Save file
6. ☐ Reopen Power BI Desktop

**SLOW METHOD (If TMDL doesn't work):**
- ☐ Manually create each measure from `DAX-MEASURES-TMDL.txt`

**✓ Validation:** ~25 measures appear in _Measures table

---

### ☐ Phase 5: Build Report Pages (10 min)

**Page 1: Parts Sales with Low Margins**
- ☐ Table visual with: PartNumber, LowMarginFlag, Sale $, Cost $, Actual Margin $, Margin Value %, Margin Discrepancy $
- ☐ Slicer: LowMarginFlag = "LOW"
- ☐ Cards: Sale $, Actual Margin $, Margin Value %
- ☐ Apply conditional formatting using color code measures

**Page 2: Inventory Cost Discrepancy**
- ☐ Table visual with: PartNumber, Total SOH Qty, Inventory Cost, MDP Value, Desired Margin $, Actual Margin $ (INV)
- ☐ Cards: Positive/Negative/Net Margin $ Discrepancy
- ☐ Slicer: IsLowMarginFlagged

**Page 3: Low Action Items**
- ☐ Table visual with: PartNumber, Stock Order Price, Inventory Cost, % Difference, Total SOH Qty
- ☐ Filter: % Difference < 0
- ☐ Apply % Diff color code to % Difference column

**✓ Validation:** All 3 pages render without errors

---

### ☐ Phase 6: Final Validation (5 min)

**Data Checks:**
- ☐ Row count: Fact_InTrans ~3-6M rows
- ☐ Low margin parts: ~1,320 (use `CALCULATE(COUNTROWS(dim_Parts_LowMargin), [IsLowMarginFlagged] = TRUE)`)
- ☐ Type Check measure: Shows "✅ All TYPE = I"
- ☐ Margin Calc Check measure: Shows "✅ Margins match"

**Performance Checks:**
- ☐ Refresh time: <5 minutes
- ☐ Visual response: <5 seconds
- ☐ Slicer interactions: <2 seconds

**Accuracy Checks (Compare to Old Report):**
- ☐ Total Sales $ matches (±1%)
- ☐ Low margin count matches (~1,320)
- ☐ Sample part margins match

**✓ Validation:** All checks pass

---

## 🚨 Common Issues & Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| "Column 'StockOrderPrice' not found" | Use `dim_Parts_LowMargin_PowerBI_CORRECTED.pq` (not HYBRID) |
| RELATED() returns blank | Set relationship to **Inactive** |
| Refresh takes >10 minutes | Verify 2-year date filter in Fact_InTrans |
| Numbers don't match old report | Check TYPE='I' filter and date range |
| Circular dependency error | Create OriginalMarginDollars BEFORE MarginDiscrepancyDollars |

---

## 📁 File Locations

**Power Query Code:**
- `queries/power bi queries/Fact_InTrans_PowerBI.pq`
- `queries/power bi queries/dim_Parts_LowMargin_PowerBI_CORRECTED.pq`

**DAX Measures:**
- `DAX-MEASURES-TMDL.txt` (copy/paste into TMDL)
- `Part Sales with Low Margin.SemanticModel/definition/tables/_Measures.tmdl` (target file)

**Documentation:**
- `IMPLEMENTATION-GUIDE-FINAL.md` (detailed walkthrough)
- `COLUMN-SOURCE-DECISION.md` (explains column sources)

---

## ✅ Success Criteria

You're done when:
- ✅ All 3 pages show data
- ✅ ~1,320 low margin parts
- ✅ Margins match old report
- ✅ Refresh <5 minutes
- ✅ Stakeholders approve

---

## 🎯 Critical Notes

**Column Names Matter:**
- InMaster has: `StockOrderPrice`, `BulkBinQty`, `OnHandQty`
- jdis has: `InventoryCost`, `QuantityOnHand` (NOT OnHandQty!)
- Use **CORRECTED** query that knows the difference!

**Relationship Must Be Inactive:**
- RELATED() won't work with active relationship
- Check in Model view - line should be dotted

**Date Filter Required:**
- Fact_InTrans MUST filter to 2 years
- Without filter: 15M+ rows, 60-minute refresh
- With filter: 3-6M rows, 3-5 minute refresh

---

**Time to Complete:** 30-45 minutes
**Next Step:** Start with Phase 1 - Power Query setup
