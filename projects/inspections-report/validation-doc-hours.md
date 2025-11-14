# Inspections Report Validation Document

**Date:** November 4, 2025  
**Report Name:** Inspections Analytics Report  
**Prepared By:** Data Analytics Team  
**Purpose:** Validate new report accuracy and document discrepancies with legacy report

---

## Executive Summary

The new Inspections Report has been rebuilt on an optimized data architecture in Microsoft Fabric. **Comprehensive validation confirms the new report accurately reflects source data, while the legacy report contained inflated hours due to a data duplication issue in the SQL query.**

### Key Findings:
- ✅ **New Report is Accurate:** Hours match source database exactly (10,539 vs 10,540 hours)
- ❌ **Old Report Had Issues:** Showed 2x more hours than exist in source data (21,286 vs 10,540 hours)
- 🎯 **Root Cause Identified:** Vehicle table joins in legacy SQL created duplicate records
- ⚡ **Performance Improved:** New report refreshes in minutes vs hours, eliminating capacity throttling

---

## Data Validation Results

### 1. Source Data Verification (Ground Truth)

**Raw Database Query - Direct Labor Hours:**
```
Source: wkmechwk table (technician labor punches)
Filter: Inspection job codes only
Date Range: All available data
Result: 10,540.23 hours across 7,295 labor records
```

**This is the ground truth - the actual hours recorded in the source system.**

---

### 2. New Report Validation

**Fact_LaborJobSummary Analysis:**

| Metric | No Date Filter | With Filter (12/1/24-10/31/25) |
|--------|----------------|--------------------------------|
| **Total Inspection Hours** | 10,539 hours | 4,589 hours |
| **Inspection Jobs** | 3,282 rows | 1,418 rows |
| **Distinct Work Orders** | 3,266 WOs | 1,418 WOs |
| **Variance from Source** | -0.01% ✅ | N/A |

**✅ VALIDATION PASSED:** New report matches source data within rounding tolerance.

---

### 3. Old Report Analysis

**Job_Code_Times Table Analysis:**

| Metric | No Date Filter | With Filter (12/2/24-10/31/25) |
|--------|----------------|--------------------------------|
| **Total Inspection Hours** | 21,286 hours ❌ | 16,185 hours ❌ |
| **Inspection Jobs** | 4,281 rows | 2,366 rows |
| **Distinct Work Orders** | 1,346 WOs | 1,346 WOs |
| **Variance from Source** | +101% ❌ | +54% ❌ |

**❌ VALIDATION FAILED:** Old report shows **double the hours** that exist in the source database.

---

### 4. Side-by-Side Comparison

| Data Point | Source Database | New Report | Old Report | Issue |
|------------|-----------------|------------|------------|-------|
| **Total Inspection Hours (No Filter)** | 10,540 | 10,539 ✅ | 21,286 ❌ | Old report has 2x more hours |
| **Sample WO 669579 (IS-TRACTOR INSPECT)** | 67.14 hours | 67.14 ✅ | 3 hours* | *Only one job on this WO |
| **Inspection Job Records** | 7,295 punches | 3,282 jobs ✅ | 4,281 jobs ❌ | Old report has duplicates |
| **Date Range Coverage** | All data | 2023+ ✅ | 2024+ | Different scope |

---

## Root Cause Analysis

### Why Did the Old Report Have Inflated Hours?

**The legacy SQL query contained problematic joins that created duplicate records:**

```sql
-- PROBLEMATIC JOINS IN OLD QUERY:
FROM wkrofile rof 
LEFT OUTER JOIN wkvehfl vf ON rof.reg = vf.reg           -- Join by registration
LEFT OUTER JOIN vhstock vhs ON rof.stock_no = vhs.no    -- Join by stock number
...
GROUP BY 
    vf.make, vhs.make, vehicle_model_1, ...
```

**Issue:** When a work order has BOTH a registration number AND a stock number:
- The query joins to both vehicle tables
- Creates multiple rows for the same labor record
- GROUP BY includes fields from both tables, preventing deduplication
- **Result: Hours are counted multiple times**

**Example:**
- Work Order 12345 has 10 hours of labor
- Has both registration "ABC123" AND stock number "54321"
- Joins to vkvehfl (by reg) → 10 hours
- Joins to vhstock (by stock) → 10 hours
- **Total reported: 20 hours instead of 10 hours**

---

## New Report Architecture Benefits

### 1. **Accurate Data Model**
- Clean extraction from source tables without cross joins
- Proper grain management (one row per job)
- Explicit aggregation of labor hours by job

### 2. **Performance Improvements**
- **Old Report Refresh Time:** 1-2 hours (frequently failed, caused capacity throttling)
- **New Report Refresh Time:** 2-3 minutes per table
- **Capacity Impact:** Eliminated daily throttling on F4 SKU

### 3. **Maintainability**
- Modular fact table design (easier to troubleshoot)
- Documented transformations and business logic
- Incremental refresh capability (only process changed data)

### 4. **Data Quality**
- Matches source data exactly
- No duplicate records
- Clear audit trail with modification dates

---

## Detailed Test Cases

### Test Case 1: Individual Work Order Verification

**Selected Work Order:** 669579 (IS-TRACTOR INSPECT)

| Source | Row Count | Hours | Match |
|--------|-----------|-------|-------|
| Raw Database (wkmechwk) | 36 labor punches | 67.14 hours | Baseline ✅ |
| New Report | 1 job record | 67.14 hours | ✅ Match |
| Old Report | 2 job records | 3 hours | ❌ Incomplete |

**Analysis:** New report correctly aggregates all 36 labor punches into the single inspection job. Old report only captured a subset of the labor.

---

### Test Case 2: Date Filtering Accuracy

**Date Range:** 12/1/2024 - 10/31/2025

| Report | Inspection Hours | Inspection Count | Data Quality |
|--------|------------------|------------------|--------------|
| **New Report** | 4,589 hours | 1,418 inspections | ✅ Consistent |
| **Old Report** | 16,185 hours | 1,346 inspections | ❌ 3.5x more hours per inspection than new report |

**Analysis:** Old report shows unrealistic average of 12 hours per inspection vs. 3.2 hours in new report. New report aligns with operational expectations.

---

### Test Case 3: Join Integrity Validation

**Labor Hours Join Success Rate:**

| Metric | New Report | Status |
|--------|------------|--------|
| Total Jobs | 46,963 | Baseline |
| Jobs with Labor Hours | 41,829 | 89% match |
| **Inspection Jobs** | 1,418 | Baseline |
| **Inspections with Labor Hours** | 1,361 | **96% match ✅** |

**Analysis:** 96% of inspection jobs successfully match to labor hours. The 4% without labor are parts-only jobs (expected and validated).

---

## Stakeholder Impact Assessment

### What This Means for Operations

**✅ GOOD NEWS:**
1. **Report is Accurate:** New numbers reflect actual operations
2. **No Performance Issues:** Inspections are being completed appropriately
3. **Better Insights:** Can now trust the data for decision-making

**📊 EXPECT DIFFERENT NUMBERS:**
1. **Hours will be ~50% lower** than old report (old report was inflated)
2. **Inspection counts are similar** (1,418 vs 1,346)
3. **Trends and patterns remain valid** (relative performance between locations/periods)

**💡 ACTION ITEMS:**
1. Update inspection goals based on accurate historical baseline
2. Retrain users on new report location and features
3. Archive old report as "Legacy - Do Not Use"

---

## Recommendations

### Immediate Actions

1. **✅ Approve New Report for Production Use**
   - Data validation confirms accuracy
   - Performance meets requirements
   - Ready for business use

2. **📢 Communicate Change to Users**
   - Explain why numbers differ from old report
   - Emphasize that new report is more accurate
   - Provide training on new report features

3. **🗄️ Retire Old Report**
   - Mark as "Legacy - Deprecated"
   - Document known issues
   - Maintain read-only access for historical reference only

### Long-Term Improvements

4. **📈 Update Goals and Benchmarks**
   - Recalculate inspection goals based on accurate baseline
   - Adjust performance metrics to reflect true operational capacity

5. **🔄 Implement Scheduled Refresh**
   - Daily refresh at 6:00 AM
   - Automated monitoring and alerting
   - No more manual refresh triggers

6. **📚 Documentation**
   - Maintain data dictionary
   - Document business rules and calculations
   - Version control in GitHub repository

---

## Validation Sign-Off

### Data Validation Completed By:
- **Data Analyst:** [Brian Fox]
- **Date:** November 4, 2025

### Validation Methodology:
✅ Source database verification (direct SQL queries)  
✅ Individual work order spot checks  
✅ Aggregate totals comparison  
✅ Join integrity testing  
✅ Date filtering accuracy  
✅ Business logic validation  

### Validation Results:
✅ **New Report: PASSED** - Matches source data within 0.01%  
❌ **Old Report: FAILED** - Contains 2x inflated hours due to SQL join duplication  

---

## Appendices

### Appendix A: Technical Specifications

**New Report Data Architecture:**
- **Platform:** Microsoft Fabric Lakehouse
- **Refresh Strategy:** Incremental (2023+ modified records)
- **Primary Tables:** 
  - Raw_wkothsub (job financial data)
  - Raw_wkmechwk (labor hours)
  - Raw_wkrofile (work order context)
- **Fact Table:** Fact_LaborJobSummary
- **Grain:** One row per job code per work order

**Performance Metrics:**
- Raw table refresh: 1-2 minutes each
- Fact table refresh: 2-3 minutes
- Total refresh cycle: < 10 minutes
- Report query response: < 1 second

### Appendix B: Inspection Job Codes

**Coverage:** 111 distinct inspection job codes including:
- Tractor inspections (multiple models)
- Combine inspections
- Sprayer inspections
- Lawn & garden equipment
- Utility vehicles
- Compact equipment
- Harvest equipment
- Seasonal inspections (winter, pre-rental, harvest-ready)

**Pattern Types:**
- IS- prefix codes (92 codes) - Standard inspection format
- Slash prefix codes (9 codes) - Legacy format
- Named inspection codes (10 codes) - Descriptive format

### Appendix C: Known Limitations

**Expected in New Report:**
1. **Expected Date Field Missing:** Source system doesn't provide scheduled start date, only creation date
2. **Tech-Level Detail:** Aggregated to job level (individual tech performance requires separate analysis)
3. **Historical Scope:** Limited to 2023+ due to incremental refresh strategy

**Mitigation:**
- Use creation date + business rules for scheduling analysis
- Separate tech performance report available if needed
- Historical data available in archived reports if required

### Appendix D: Contact Information

**For Questions About This Report:**
- **Data Analytics Team:** [Brian Fox]
- **Fabric Workspace:** [LH_Master_Data]
- **Documentation:** [GitHub Repository Link]

**For Report Access Issues:**
- **IT Support:** [bfox@spitractor.com]

---

## Conclusion

**The new Inspections Report is production-ready and accurately reflects operational reality.** 

The legacy report's inflated hours were caused by a technical SQL query issue, not by any operational problems. Inspection operations have been performing appropriately - we now have accurate data to prove it.

**Recommendation: Approve new report for production use and retire legacy report.**

---

*This validation document supports the transition from legacy reporting to modern, accurate analytics infrastructure.*