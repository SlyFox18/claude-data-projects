# InMaster Table Analysis - Low Margin Report

**Date**: January 9, 2026
**Analyst**: B.Fox with Claude Code Assistant

---

## Critical Discovery: user_field_3 = Low Margin Flag ⭐⭐⭐

Based on your input, the **user_field_3** column in InMaster is THE critical field for this report. Parts managers use this field to manually mark parts as having margin issues.

**Business Logic**:
- When `user_field_3 = "Low"` → Part is flagged as low margin
- This is a manual flag set by parts managers
- Provides human oversight on margin issues

---

## InMaster Table Structure

### Sample Row from Source

From your top 1 sample, here's what we see:

| Field | Value | Normalized Name | Include? |
|-------|-------|----------------|----------|
| BRANCH | 2 | Branch | ✅ Yes |
| FRANCHISE | D | Franchise | ✅ Yes |
| PART_NO | DZ119061 | PartNumber | ✅ Yes |
| PART_DESC | V-Belt | PartDescription | ✅ Yes |
| PROD_GROUP | null | ProductGroup | ✅ Yes |
| SALES_CLASS | 11B | SalesClass | ✅ Yes |
| CATEGORY | RG | Category | ✅ Yes |
| MANUF_CODE | DZ119061 | ManufacturerCode | ✅ Yes |
| **user_field_3** | **null** | **LowMarginFlag** | ✅ **CRITICAL** |
| **STK_ORDER_PRICE** | **35.42** | **StockOrderPrice** | ✅ **CRITICAL** |
| LIST_PRICE | 52.87 | ListPrice | ✅ Yes |
| SELL_PRICE1 | 55.95 | SellPrice1 | ✅ Yes |
| ON_HAND_QTY | 0 | OnHandQty | ✅ Yes |
| BACK_ORD_QTY | 0 | BackOrderQty | ✅ Yes |
| Last_Upd_Datetime | 9/9/2025 8:46:22 PM | LastUpdatedDatetime | ✅ Yes |
| CREATION_DATE | 2/15/2021 5:46:21 AM | CreationDate | ✅ Yes |
| LAST_DEM_DATE | 10/19/2022 1:02:28 PM | LastDemandDate | ✅ Yes |

---

## Critical Fields for Low Margin Analysis

### 1. LowMarginFlag (user_field_3) ⭐⭐⭐

**Purpose**: Manual low margin indicator set by parts managers

**Values**:
- `"Low"` = Part flagged as having margin issues
- `NULL` or `""` = Not flagged / normal margin
- Possibly other values (need to verify)

**Usage in Report**:
- Primary filter for identifying low margin parts
- Parts managers update this as they monitor margins
- Provides qualitative overlay on quantitative margin calculations

**Validation Needed**:
```sql
-- Check distinct values in user_field_3
SELECT
    user_field_3,
    COUNT(*) AS part_count
FROM InMaster
GROUP BY user_field_3
ORDER BY part_count DESC
```

---

### 2. StockOrderPrice (STK_ORDER_PRICE) ⭐⭐

**Purpose**: Original/base price used for stocking the part

**Business Logic** (from measures analysis):
- Used to calculate **Original Margin**: `ListPrice - StockOrderPrice`
- Represents baseline pricing expectation
- Compared to actual cost to find margin discrepancies

**Measures Using This Field**:
```dax
Original MDP Value = [Stock Order Price] * [Total SOH Qty]

% Difference =
DIVIDE(
    ([Original MDP Value] - [Inventory Cost]),
    ([Original MDP Value] + [Inventory Cost]) / 2,
    0
)

Original Margin $ =
CALCULATE(
    SUMX(
        'InTrans_Low_Margin',
        ([List Price Manuf] - [Stock Order Price]) * [Qty]
    ),
    'InTrans_Low_Margin'[TYPE] = "I"
)
```

**Validation Needed**:
```sql
-- Check for NULL or 0 values
SELECT
    COUNT(*) AS total_parts,
    SUM(CASE WHEN STK_ORDER_PRICE IS NULL OR STK_ORDER_PRICE = 0 THEN 1 ELSE 0 END) AS missing_price,
    MIN(STK_ORDER_PRICE) AS min_price,
    MAX(STK_ORDER_PRICE) AS max_price,
    AVG(STK_ORDER_PRICE) AS avg_price
FROM InMaster
```

---

### 3. Pricing Fields

**ListPrice (LIST_PRICE)**:
- Manufacturer's list price
- Used as reference for margin calculations
- Compared to SellPrice1 to determine pricing strategy

**SellPrice1 (SELL_PRICE1)**:
- Current selling price (primary price level)
- What customers are actually charged
- Used in margin calculations

**Comparison**:
```
Original/Expected Margin = ListPrice - StockOrderPrice
Actual Margin (from InMaster) = SellPrice1 - Cost (need from jdis_Part_Information)
Margin Discrepancy = Actual Margin - Original Margin
```

---

## Recommended Column Set (20 Columns)

Based on the old report measures and your requirements, I've included these 20 columns in the Power Query:

### Core Identification (4 columns)
1. Branch
2. PartNumber
3. PartDescription
4. Franchise

### Classification (4 columns)
5. ProductGroup
6. SalesClass
7. Category
8. ManufacturerCode

### Pricing & Cost (3 columns)
9. ListPrice
10. SellPrice1
11. **StockOrderPrice** ⭐

### Inventory (2 columns)
12. OnHandQty
13. BackOrderQty

### Critical Flag (1 column)
14. **LowMarginFlag** (user_field_3) ⭐⭐⭐

### Custom Fields (2 columns)
15. UserField1 (user_field_1)
16. UserField2 (user_field_2)

### Timeline (3 columns)
17. LastUpdatedDatetime
18. CreationDate
19. LastDemandDate

---

## Historical Data Range Recommendation

### Option 1: Full Master (RECOMMENDED) ✅

**Load**: All parts from InMaster (no date filter)

**Rationale**:
- InMaster is a master/dimension table, not transactional
- Need all parts to join with 2 years of InTrans transactions
- Risk: Missing parts if we filter too aggressively
- Size: Manageable (5K-50K rows estimated)

**SQL**: No WHERE clause (load all)

```sql
SELECT ... FROM InMaster
ORDER BY Branch, PART_NO
```

---

### Option 2: Active Parts Only (Alternative)

**Load**: Only parts with recent activity or current inventory

**Filter Logic**:
```sql
SELECT ... FROM InMaster
WHERE
    ON_HAND_QTY > 0  -- Current inventory
    OR LAST_DEM_DATE >= DATEADD(YEAR, -2, GETDATE())  -- Recent demand
    OR user_field_3 = 'Low'  -- Flagged as low margin
ORDER BY Branch, PART_NO
```

**Risk**: May miss parts that:
- Were recently sold out (OnHandQty = 0)
- Had transactions in last 2 years but LAST_DEM_DATE not updated
- Are in InTrans but not captured by filters

---

## My Recommendation: START WITH OPTION 1 ✅

**Reasoning**:
1. **Safety First**: This is the "most impactful report" - can't risk missing data
2. **Master Table**: InMaster is not huge, full load is manageable
3. **Easy Validation**: Compare to old report more easily with all data
4. **Optimize Later**: Can add filters after initial validation if needed
5. **JOIN Safety**: Ensures all InTrans parts can find matching InMaster records

**Next Steps After Initial Load**:
1. Validate row counts
2. Check join success rate with InTrans
3. Analyze actual data volume
4. Add filters if needed (unlikely)

---

## Power Query Implementation

I've created `RAW_InMaster.pq` with:

✅ **20 Essential Columns** for low margin analysis
✅ **Full Master Load** (no date filter)
✅ **Normalized Column Names** (matching your other raw tables)
✅ **Proper Data Types** (typed table transformation)
✅ **Error Handling** (try/otherwise for connection issues)
✅ **Comprehensive Documentation** (inline comments)

---

## Validation Checklist

After loading InMaster into your Lakehouse, run these checks:

### 1. Row Count Validation
```sql
-- Compare source to Lakehouse
-- Source (via ODBC):
SELECT COUNT(*) AS total_parts FROM InMaster

-- Lakehouse:
SELECT COUNT(*) AS total_parts FROM RAW_InMaster
```

**Expected**: Exact match

---

### 2. LowMarginFlag Distribution
```sql
SELECT
    LowMarginFlag,
    COUNT(*) AS part_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS percentage
FROM RAW_InMaster
GROUP BY LowMarginFlag
ORDER BY part_count DESC
```

**Expected Output Example**:
```
LowMarginFlag | part_count | percentage
NULL          | 45,000     | 90.00%
Low           | 5,000      | 10.00%
```

---

### 3. Pricing Completeness
```sql
SELECT
    COUNT(*) AS total_parts,
    SUM(CASE WHEN StockOrderPrice IS NULL OR StockOrderPrice = 0 THEN 1 ELSE 0 END) AS missing_stock_price,
    SUM(CASE WHEN ListPrice IS NULL OR ListPrice = 0 THEN 1 ELSE 0 END) AS missing_list_price,
    SUM(CASE WHEN SellPrice1 IS NULL OR SellPrice1 = 0 THEN 1 ELSE 0 END) AS missing_sell_price
FROM RAW_InMaster
```

**Expected**: Very few (< 1%) missing prices

---

### 4. Join Success with InTrans
```sql
-- Check if all InTrans parts have InMaster records
SELECT
    COUNT(DISTINCT t.Branch + '|' + t.PartNumber) AS distinct_parts_in_trans,
    COUNT(DISTINCT CASE WHEN m.PartNumber IS NOT NULL THEN t.Branch + '|' + t.PartNumber END) AS parts_found_in_master,
    COUNT(DISTINCT CASE WHEN m.PartNumber IS NULL THEN t.Branch + '|' + t.PartNumber END) AS orphaned_parts
FROM RAW_InTrans t
LEFT JOIN RAW_InMaster m
    ON t.Branch = m.Branch
    AND t.PartNumber = m.PartNumber
WHERE t.TransDatetime >= DATEADD(YEAR, -2, GETDATE())
```

**Expected**: orphaned_parts should be 0 (all InTrans parts found in InMaster)

---

## Next Steps After Loading

### Step 1: Load RAW_InMaster to Lakehouse
- Use the Power Query I created: `RAW_InMaster.pq`
- Run initial load (full refresh)
- Add to your daily refresh pipeline

### Step 2: Validate Data Quality
- Run validation queries above
- Document row counts
- Check LowMarginFlag distribution
- Verify join success with InTrans

### Step 3: Build dim_Parts
- Join RAW_jdis_Part_Information with RAW_InMaster
- Include LowMarginFlag as critical dimension
- Include StockOrderPrice for margin calculations

### Step 4: Create Fact Table
- Build Fact_Part_Sales_Txns from RAW_InTrans
- Join to dim_Parts for enrichment
- Calculate margin metrics

---

## Questions to Answer After Initial Load

1. **LowMarginFlag Values**: What distinct values exist in user_field_3?
   - Is it just "Low" and NULL?
   - Or are there other values like "High", "Medium", etc.?

2. **Row Count**: How many total parts in InMaster?
   - Is it 5K? 50K? 500K?
   - Helps determine if full master is practical

3. **Join Success**: Do all InTrans parts have InMaster records?
   - Should be 100% join success
   - If orphans exist, need to investigate

4. **Pricing Coverage**: What % of parts have StockOrderPrice?
   - Should be very high (>99%)
   - Missing prices need investigation

---

## Power Query File Ready

The file `RAW_InMaster.pq` is ready to use in your Fabric pipeline:

**To Implement**:
1. Open Fabric workspace
2. Create new dataflow or pipeline
3. Copy the Power Query M code from `RAW_InMaster.pq`
4. Set destination to your Lakehouse table: `RAW_InMaster`
5. Run initial load
6. Add to daily refresh schedule

**Expected Performance**:
- Initial load: 2-5 minutes (depends on row count)
- Daily refresh: Same (full refresh)
- Row count: 5K-50K estimated (need to verify)

---

**Ready to proceed with loading InMaster!** 🚀

Let me know once you've loaded it and I can help with the next steps (validation and building dim_Parts).
