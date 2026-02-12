# InMaster Load - Validation Results

**Date**: January 9, 2026
**Load Status**: ✅ SUCCESS
**Total Rows Loaded**: 1,081,109

---

## Validation Summary

| Validation Check | Status | Notes |
|-----------------|--------|-------|
| Row Count Match | ✅ PASS | Exact match: 1,081,109 rows |
| LowMarginFlag Distribution | ✅ PASS | 1,320 parts flagged as "LOW" (0.12%) |
| Pricing Completeness | ⚠️ REVIEW | 3.29% missing StockOrderPrice |
| Join Success with InTrans | ⚠️ REVIEW | 1,642 orphaned parts (0.43%) |

---

## 1. Row Count Validation ✅ PASS

**Result**: EXACT MATCH
- **Source (InMaster)**: 1,081,109 parts
- **Lakehouse (RAW_InMaster)**: 1,081,109 parts
- **Variance**: 0 (100% match)

**Analysis**: Perfect data transfer, no rows lost or duplicated.

---

## 2. LowMarginFlag Distribution ✅ PASS

**Total Parts**: 1,081,109

| LowMarginFlag Value | Count | Percentage | Status |
|---------------------|-------|------------|--------|
| NULL | 1,034,967 | 95.73% | Normal - not flagged |
| Blank ("") | 44,822 | 4.15% | Normal - not flagged |
| **LOW** | **1,320** | **0.12%** | ⭐ Low margin parts |

**Key Findings**:

✅ **1,320 parts actively flagged as "LOW" margin** (0.12% of total inventory)
- This is the critical filter for the low margin report
- These are parts that parts managers have manually identified as problematic

✅ **Three distinct values**: NULL, Blank, and "LOW"
- NULL and Blank are functionally equivalent (not flagged)
- Only "LOW" indicates a flagged part

**Business Insight**:
- 0.12% flagged rate suggests selective flagging (quality over quantity)
- Parts managers are targeting specific problem parts, not blanket flagging
- This is likely the tip of the iceberg - report will calculate margins to find more

**Recommendation**: ✅ Data looks good for business use

---

## 3. Pricing Completeness ⚠️ REVIEW NEEDED

**Total Parts**: 1,081,109

| Field | Missing Count | Missing % | Status |
|-------|--------------|-----------|--------|
| StockOrderPrice | 35,576 | 3.29% | ⚠️ Acceptable |
| ListPrice | 34,316 | 3.17% | ⚠️ Acceptable |
| SellPrice1 | 29,654 | 2.74% | ✅ Good |

**Price Range Analysis**:
- **Min StockOrderPrice**: -$900 (⚠️ NEGATIVE PRICE!)
- **Max StockOrderPrice**: $154,785
- **Avg StockOrderPrice**: $191.59

### 🚨 Data Quality Issues Found

#### Issue #1: Negative Prices (-$900)

**Problem**: Some parts have negative StockOrderPrice

**Impact**:
- Will cause incorrect margin calculations
- Could be data entry errors or credits/returns

**Investigation Needed**:
```sql
-- Find parts with negative StockOrderPrice
SELECT
    Branch,
    PartNumber,
    PartDescription,
    StockOrderPrice,
    ListPrice,
    SellPrice1,
    OnHandQty
FROM RAW_InMaster
WHERE StockOrderPrice < 0
ORDER BY StockOrderPrice ASC
```

**Recommended Fix**:
- Investigate with stakeholders
- Likely data quality issue in source system
- May need to exclude or correct these parts

---

#### Issue #2: Missing StockOrderPrice (3.29%)

**Problem**: 35,576 parts missing StockOrderPrice

**Impact**:
- Cannot calculate "Original Margin" for these parts
- Measures like `Original Margin $` will exclude these parts
- May affect completeness of low margin analysis

**Investigation Needed**:
```sql
-- Analyze parts missing StockOrderPrice
SELECT
    COUNT(*) AS missing_stock_price_count,
    SUM(CASE WHEN OnHandQty > 0 THEN 1 ELSE 0 END) AS with_inventory,
    SUM(CASE WHEN LowMarginFlag = 'LOW' THEN 1 ELSE 0 END) AS flagged_as_low
FROM RAW_InMaster
WHERE StockOrderPrice IS NULL OR StockOrderPrice = 0
```

**Questions for Stakeholders**:
1. Is 3.29% missing rate acceptable? (Likely yes, if these are inactive parts)
2. Are any of the 1,320 "LOW" flagged parts missing StockOrderPrice?
3. Should we use ListPrice or another field as fallback?

**Recommended Approach**:
- ✅ Accept 3.29% missing rate for initial migration
- Document as known limitation
- Use COALESCE in measures to handle NULLs gracefully
- Monitor if flagged parts are affected

---

## 4. Join Success with InTrans ⚠️ REVIEW NEEDED

**Transaction Analysis (Last 2 Years)**:

| Metric | Count | Percentage |
|--------|-------|------------|
| Distinct parts in InTrans | 381,630 | 100% |
| Parts found in InMaster | 379,988 | 99.57% ✅ |
| **Orphaned parts** | **1,642** | **0.43%** ⚠️ |

### Analysis

✅ **99.57% join success rate** - Very good!
- 379,988 out of 381,630 parts matched
- Strong data integrity between systems

⚠️ **1,642 orphaned parts** (0.43%)
- These parts exist in InTrans transactions but not in InMaster
- Could be:
  - Parts deleted/purged from InMaster
  - Data sync issues between systems
  - Special order parts that bypass master data
  - Historical parts no longer in system

### Business Impact Assessment

**Need to determine**:
1. What is the transaction volume for these 1,642 orphaned parts?
2. What is the dollar value (Sale $, Cost $)?
3. Are these recent transactions or old data?

**Investigation Query**:
```sql
-- Analyze orphaned parts - transaction volume and value
SELECT
    COUNT(*) AS orphan_transaction_count,
    SUM(t.Qty) AS total_qty,
    SUM(t.SaleValue) AS total_sales,
    SUM(t.CostValue) AS total_cost,
    MIN(t.TransDatetime) AS earliest_trans,
    MAX(t.TransDatetime) AS latest_trans
FROM RAW_InTrans t
LEFT JOIN RAW_InMaster m
    ON t.Branch = m.Branch
    AND t.PartNumber = m.PartNumber
WHERE
    m.PartNumber IS NULL
    AND t.TransDatetime >= DATEADD(YEAR, -2, GETDATE())
```

**Sample Orphaned Parts**:
```sql
-- Get sample of orphaned parts for review
SELECT TOP 100
    t.Branch,
    t.PartNumber,
    t.Description,
    COUNT(*) AS transaction_count,
    SUM(t.SaleValue) AS total_sales,
    MAX(t.TransDatetime) AS last_transaction
FROM RAW_InTrans t
LEFT JOIN RAW_InMaster m
    ON t.Branch = m.Branch
    AND t.PartNumber = m.PartNumber
WHERE
    m.PartNumber IS NULL
    AND t.TransDatetime >= DATEADD(YEAR, -2, GETDATE())
GROUP BY t.Branch, t.PartNumber, t.Description
ORDER BY total_sales DESC
```

### Recommended Action Plan

**Immediate (This Week)**:
1. ✅ Run investigation queries above
2. ⚠️ Determine financial impact of orphaned parts
3. ⚠️ Check if any orphaned parts are flagged as "LOW" in transactions

**Decision Point**:
- **If Impact < 1% of total sales**: ✅ Accept as data quality limitation, document
- **If Impact > 1% of total sales**: ⚠️ Investigate further, may need data fix

**Likely Outcome**:
- Most orphaned parts are probably inactive/deleted parts
- Should have minimal financial impact
- Document as known limitation in report

---

## Data Quality Issues Summary

### Critical Issues 🚨
None - all issues are minor and manageable

### Issues Requiring Investigation ⚠️

#### 1. Negative StockOrderPrice
- **Severity**: Medium
- **Count**: Unknown (need query)
- **Impact**: Incorrect margin calculations
- **Action**: Investigate and document/fix

#### 2. Missing StockOrderPrice (3.29%)
- **Severity**: Low
- **Count**: 35,576 parts
- **Impact**: Cannot calculate original margin for these parts
- **Action**: Accept as limitation, handle in DAX with COALESCE

#### 3. Orphaned Parts in InTrans (0.43%)
- **Severity**: Low to Medium (depends on financial impact)
- **Count**: 1,642 parts
- **Impact**: Parts in transactions but not in InMaster dimension
- **Action**: Run impact analysis, likely acceptable

### Acceptable Data Characteristics ✅

#### 1. LowMarginFlag Distribution
- ✅ 1,320 parts flagged as "LOW" (0.12%)
- ✅ Clean data (only 3 values: NULL, Blank, LOW)
- ✅ Ready for business use

#### 2. Join Success Rate (99.57%)
- ✅ Very high match rate
- ✅ Strong data integrity
- ✅ Minor orphan rate manageable

---

## Recommendations for Next Steps

### Immediate Actions (Today)

#### 1. Run Impact Analysis Queries ⭐ CRITICAL
```sql
-- QUERY 1: Negative prices investigation
SELECT
    COUNT(*) AS negative_price_count,
    MIN(StockOrderPrice) AS min_price,
    SUM(CASE WHEN OnHandQty > 0 THEN 1 ELSE 0 END) AS with_inventory
FROM RAW_InMaster
WHERE StockOrderPrice < 0

-- QUERY 2: Orphaned parts financial impact
SELECT
    COUNT(*) AS orphan_transaction_count,
    SUM(t.SaleValue) AS total_orphan_sales,
    SUM(t.SaleValue) * 100.0 / (SELECT SUM(SaleValue) FROM RAW_InTrans WHERE TransDatetime >= DATEADD(YEAR, -2, GETDATE())) AS pct_of_total_sales
FROM RAW_InTrans t
LEFT JOIN RAW_InMaster m
    ON t.Branch = m.Branch AND t.PartNumber = m.PartNumber
WHERE
    m.PartNumber IS NULL
    AND t.TransDatetime >= DATEADD(YEAR, -2, GETDATE())

-- QUERY 3: Check if flagged parts missing StockOrderPrice
SELECT COUNT(*) AS flagged_missing_price
FROM RAW_InMaster
WHERE LowMarginFlag = 'LOW'
  AND (StockOrderPrice IS NULL OR StockOrderPrice = 0)
```

**Goal**: Determine if data quality issues are acceptable or need fixing

---

#### 2. Document Baseline Metrics 📊

Record these for later validation:
- ✅ Total parts: 1,081,109
- ✅ Parts flagged "LOW": 1,320 (0.12%)
- ✅ Join success rate: 99.57%
- ⏳ Financial impact of orphans: TBD
- ⏳ Count of negative prices: TBD

---

#### 3. Prepare for dim_Parts Build 🏗️

**Decision Needed**: How to handle orphaned InTrans parts?

**Option A - LEFT JOIN from InTrans** (RECOMMENDED):
```sql
-- Fact table can have parts even if not in InMaster
-- Missing StockOrderPrice/LowMarginFlag will be NULL
-- Ensures ALL transactions included
```

**Option B - INNER JOIN** (Stricter):
```sql
-- Only include parts that exist in InMaster
-- Exclude 0.43% orphaned transactions
-- Cleaner data but some transactions excluded
```

**Recommendation**: Use Option A (LEFT JOIN) to preserve all transaction data, document orphans as limitation

---

### Short-Term Actions (This Week)

#### 4. Build dim_Parts Dimension
Once impact analysis complete:
- Join RAW_jdis_Part_Information (main part master)
- LEFT JOIN RAW_InMaster (for LowMarginFlag, StockOrderPrice)
- Handle NULLs gracefully with COALESCE

#### 5. Create Fact_Part_Sales_Txns
- Source: RAW_InTrans
- LEFT JOIN to dim_Parts for enrichment
- Calculate margin metrics in DAX measures

#### 6. Replicate Old Report Measures
- Migrate all measures from Old Report Measures.csv
- Update table references
- Test calculations

---

### Long-Term Actions (Next Iteration)

#### 7. Data Quality Improvements
- Work with source system team on:
  - Negative price investigation
  - InMaster orphan cleanup
  - Missing price population

#### 8. Performance Optimization
- Monitor refresh times
- Consider incremental refresh if needed
- Optimize SQL views if slow

---

## Overall Assessment

### Status: ✅ READY TO PROCEED

**Strengths**:
- ✅ Complete data load (100% row count match)
- ✅ 1,320 parts flagged as "LOW" - clean and usable
- ✅ 99.57% join success rate - excellent data integrity
- ✅ Pricing data 96%+ complete - acceptable

**Manageable Issues**:
- ⚠️ 3.29% missing StockOrderPrice - handle with COALESCE in DAX
- ⚠️ 0.43% orphaned parts - pending impact analysis
- ⚠️ Negative prices - need investigation, likely small impact

**Recommendation**:
✅ **PROCEED to next phase** (build dim_Parts and fact tables)

The data quality is good enough for initial migration. Document limitations and monitor in production. Can address data quality issues in source system as separate initiative.

---

## Questions for Stakeholders

Before building fact tables, confirm:

1. **Orphaned Parts**: Is 0.43% orphan rate acceptable if financial impact is <1%?
2. **Missing Prices**: Is 3.29% missing StockOrderPrice acceptable for "Original Margin" calculations?
3. **Negative Prices**: Should we exclude parts with negative StockOrderPrice, or investigate/fix?
4. **LowMarginFlag**: Confirm that only "LOW" value should filter low margin parts (not Blank)?

---

**Next Step**: Run the 3 impact analysis queries and report back results! 🚀
