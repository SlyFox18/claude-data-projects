# Inspections Report - Data Architecture

**Last Updated:** 2025-10-30  
**Architecture Version:** 1.0 (Phase 1 Complete)  
**Status:** Production-Ready Foundation

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Data Flow](#data-flow)
3. [Dimensional Model Design](#dimensional-model-design)
4. [Fact Table Architecture](#fact-table-architecture)
5. [Grain Analysis](#grain-analysis)
6. [Join Strategies](#join-strategies)
7. [Performance Architecture](#performance-architecture)
8. [Future Enhancements](#future-enhancements)

---

## 🎯 Architecture Overview

### Design Philosophy

This architecture follows **modern Lakehouse dimensional modeling** principles:

1. **Raw Layer:** Simple, fast extraction from source (ODBC)
2. **Curated Layer:** Dimensional fact tables with pre-aggregation
3. **Semantic Layer:** Power BI with DAX measures
4. **Incremental Refresh:** Only process changed records
5. **Documentation First:** Self-documenting code and comprehensive docs

### Architecture Pattern

**Pattern:** Star Schema with Fact Constellation  
**Style:** Kimball Methodology  
**Platform:** Microsoft Fabric Lakehouse  
**Refresh Strategy:** Incremental (2023+ scope)

---

## 📊 Data Flow

### High-Level Data Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                    SOURCE SYSTEM                                 │
│                   EquipRDB64 (ODBC)                             │
│                  Informix Database                               │
│                                                                  │
│  Tables: wkothsub, wkmechwk, wkrofile                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ ODBC Query (Incremental)
                          │ Filter: ModifiedDate >= 2023-01-01
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RAW LAYER (Lakehouse)                         │
│                  Simple Extraction Queries                       │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ Raw_wkothsub   │  │ Raw_wkmechwk   │  │ Raw_wkrofile   │   │
│  │ 21 columns     │  │ 19 columns     │  │ 20 columns     │   │
│  │ 2m 10s refresh │  │ 2m refresh     │  │ 1m 30s refresh │   │
│  │ Job Financial  │  │ Labor Punches  │  │ WO Master      │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                  │
│  Design: Performance-optimized column selection                 │
│  Refresh: Incremental (ModifiedDate >= 2023-01-01)             │
│  Purpose: Fast, clean data extraction only                      │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ Power Query M
                          │ • Join & Aggregate
                          │ • Business Logic
                          │ • Inspection Flag
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                 CURATED LAYER (Lakehouse)                        │
│                  Dimensional Fact Tables                         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           Fact_LaborJobSummary                           │  │
│  │                                                          │  │
│  │  Grain: One row per job per work order                  │  │
│  │  Refresh: 2m 09s                                        │  │
│  │  Fields: 31 (financial, hours, flags)                   │  │
│  │  Rows: ~50k-100k (2+ years)                            │  │
│  │                                                          │  │
│  │  Key Features:                                           │  │
│  │  • IsInspection flag (111 job codes)                    │  │
│  │  • Aggregated labor hours (from punches)                │  │
│  │  • Work order status context                            │  │
│  │  • Pre-calculated metrics                               │  │
│  │  • IsPending flag for workflow                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Design: Pre-aggregated for report performance                  │
│  Logic: Business rules and calculations applied                 │
│  Purpose: Report-ready analytical data                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          │ DirectQuery or Import
                          │ Power BI Data Model
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  SEMANTIC LAYER (Power BI)                       │
│                    DAX Measures & Reports                        │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ Page 1:        │  │ Page 2:        │  │ Page 3:        │   │
│  │ Summary        │  │ Job Breakdown  │  │ Pending        │   │
│  │ Dashboard      │  │                │  │ Inspections    │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ Page 4:        │  │ Page 5:        │  │ Page 6:        │   │
│  │ Overview       │  │ Location       │  │ Goals          │   │
│  │                │  │ Analysis       │  │ Tracking       │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                  │
│  Design: DAX measures for KPIs and calculations                 │
│  Purpose: Business user interface and analytics                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏛️ Dimensional Model Design

### Current State (Phase 1)

**Fact Tables:**
- ✅ Fact_LaborJobSummary (Complete)

**Dimensions:**
- 🚧 Date Dimension (Standard - to be built in Phase 2)
- 🚧 Branch/Location Dimension (to be built in Phase 2)
- 🚧 Customer Dimension (exists in other project, needs integration)
- 🚧 Goals Table (External - SharePoint Excel)

### Star Schema Design
```
                    ┌─────────────────┐
                    │   dim_Date      │
                    │                 │
                    │ • DateKey       │
                    │ • Year          │
            ┌───────│ • Quarter       │
            │       │ • Month         │
            │       │ • Week          │
            │       └─────────────────┘
            │
            │       ┌─────────────────┐
            │       │   dim_Branch    │
            │       │                 │
            │       │ • BranchCode    │
            ├───────│ • BranchName    │
            │       │ • Region        │
            │       │ • Manager       │
            │       └─────────────────┘
            │
            │
            │       ┌──────────────────────────────────────┐
            │       │    Fact_LaborJobSummary              │
            │       │                                      │
            │       │ Keys:                                │
            ├───────│ • BranchCode (FK)                    │
            │       │ • WorkOrderNumber                    │
            │       │ • JobCode                            │
            │       │ • InvoiceDate (FK)                   │
            │       │                                      │
            │       │ Measures:                            │
            │       │ • EstimatedLaborAmount               │
            │       │ • ActualLaborAmount                  │
            │       │ • InvoicedLaborAmount                │
            │       │ • EstimatedPartsAmount               │
            │       │ • ActualPartsAmount                  │
            │       │ • InvoicedPartsAmount                │
            │       │ • EstimatedHours                     │
            │       │ • ActualHoursWorked ⭐              │
            │       │ • InvoicedHours                      │
            │       │                                      │
            │       │ Dimensions/Attributes:               │
            │       │ • JobCode                            │
            │       │ • JobType                            │
            │       │ • WorkOrderStatus ⭐                │
            │       │ • IsInspection ⭐⭐                 │
            │       │ • IsPending ⭐                      │
            │       │ • [+ 20 more fields]                 │
            │       └──────────────────────────────────────┘
            │                    │
            │                    │
            │       ┌────────────┴──────────┐
            │       │   dim_Customer        │
            │       │                       │
            └───────│ • AccountNumber       │
                    │ • CustomerName        │
                    │ • CustomerType        │
                    │ • AccountClass        │
                    └───────────────────────┘

            ⭐ = New in Phase 1
            ⭐⭐ = Critical for Inspections Report
```

### Future Constellation Pattern

As the system grows, additional fact tables may be added:
```
        dim_Date
           │
           ├────── Fact_LaborJobSummary (Job-level)
           │          └── (Current fact table)
           │
           ├────── Fact_LaborPunches (Punch-level detail)
           │          └── (Future - if tech detail needed)
           │
           └────── Fact_WorkOrderParts (Parts transactions)
                      └── (Future - if parts detail needed)
```

**Constellation Benefits:**
- Each fact optimized for its grain
- Shared dimensions reduce duplication
- Flexible analysis at different levels
- Performance optimized per use case

---

## 🎲 Fact Table Architecture

### Fact_LaborJobSummary Design

#### Grain Definition

**Grain Statement:**  
*"One row per job code per work order"*

**Grain Example:**
- Work Order #669579 has 3 job codes = 3 rows
- Each row represents a distinct service/repair job
- Multiple techs working same job = aggregated to single row

#### Fact Type Classification

**Type:** Transaction Fact Table (with Periodic Snapshot characteristics)

**Characteristics:**
- ✅ Captures business events (job completion)
- ✅ Additive measures (amounts, hours)
- ✅ Time stamped (InvoiceDate, CreationDate)
- ⚠️ Some snapshot attributes (status, pending flag)

#### Measure Classification

**Fully Additive Measures (16):**
- All financial amounts (can sum across all dimensions)
- All hours fields (can sum across all dimensions)
- TotalInvoicedAmount, TotalEstimatedAmount

**Semi-Additive Measures (0):**
- None (no balance/inventory type measures)

**Non-Additive Measures (2):**
- HoursVariance (must calculate from components)
- All percentage calculations (derived in DAX)

**Degenerate Dimensions (4):**
- WorkOrderNumber (kept as fact attribute, not dimension)
- InvoiceNumber (transactional reference)
- ClaimNumber (optional reference)
- JobCode (kept in fact for flexibility)

**Role-Playing Dimensions:**
- Date dimension will have multiple roles:
  - InvoiceDate (when invoiced)
  - WorkOrderCreationDate (when WO created)
  - WorkOrderClosedDate (when WO closed)

---

## 🔍 Grain Analysis

### Grain Challenges & Solutions

#### Challenge 1: Multiple Technicians per Job

**Problem:**
- Raw_wkmechwk has multiple punch records per job
- Tech A: 2.5 hours on IS-TRACTOR INSPECT
- Tech B: 1.5 hours on same job
- How to represent at job-level grain?

**Solution:**
- Pre-aggregate hours BEFORE joining to fact
- SUM(HoursWorked) GROUP BY Branch, WorkOrder, JobCode
- Result: 4.0 hours total for the job
- Trade-off: Lose individual tech detail (acceptable for this report)

**Implementation:**
```powerquery
// Step 2 in Fact_LaborJobSummary.pq
AggregatedHours = Table.Group(
    Raw_wkmechwk,
    {"Branch", "WorkOrder", "JobCode"},
    {
        {"ActualHoursWorked", each List.Sum([HoursWorked])},
        {"InvoicedHours", each List.Sum([InvoiceHours])}
    }
)
```

---

#### Challenge 2: Work Order Context (One-to-Many)

**Problem:**
- Raw_wkrofile: 1 row per work order
- Fact_LaborJobSummary: Multiple jobs per work order
- How to join without duplicating work order attributes?

**Solution:**
- LEFT OUTER JOIN on Branch + WorkOrder
- Work order attributes (status, dates) replicated across jobs
- This is intentional denormalization (performance trade-off)

**Example:**
```
Work Order #12345 has 3 jobs:
  Job 1: IS-TRACTOR INSPECT  → Status = "wip"
  Job 2: REPAIR-ENGINE       → Status = "wip"  (same status)
  Job 3: PARTS-FILTER        → Status = "wip"  (same status)
```

**Why This Works:**
- Work order status applies to ALL jobs in that WO
- Denormalization reduces report-time joins
- Acceptable redundancy for query performance

---

#### Challenge 3: Parts-Only Jobs (NULL Hours)

**Problem:**
- Some jobs have no labor (parts-only)
- Raw_wkmechwk has no records for these jobs
- Should these rows exist in the fact table?

**Solution:**
- YES - keep all jobs from Raw_wkothsub
- Use LEFT OUTER JOIN to wkmechwk aggregation
- ActualHoursWorked = NULL for parts-only jobs
- This is intentional and expected

**Business Rule:**
```
IF ActualHoursWorked IS NULL
THEN Job is either:
  • Parts-only (common)
  • Not yet worked (pending)
  • Data quality issue (rare)
```

**Impact on Metrics:**
- "Total Inspections" count = includes parts-only
- "Hours Worked" sum = excludes NULL (correct)
- "Avg Hours per Inspection" = exclude NULL in calculation

---

## 🔗 Join Strategies

### Join Architecture
```
Fact_LaborJobSummary Build Process:

1. Base Table (Raw_wkothsub)
   └── Grain: 1 row per job per work order
       Rows: ~100,000

2. LEFT JOIN → InspectionCodes Lookup
   └── Adds: IsInspection flag
       Match: JobCode = job_code
       Result: All rows preserved

3. LEFT JOIN → Aggregated Labor Hours
   └── Adds: ActualHoursWorked, InvoicedHours
       Match: Branch + WorkOrder + JobCode
       Result: ~75% match, rest NULL (expected)

4. LEFT JOIN → Work Order Context
   └── Adds: WorkOrderStatus, dates
       Match: Branch + WorkOrder
       Result: 100% match (should always find WO)

Final Row Count: Same as Raw_wkothsub ✅
```

### Join Type Decisions

#### Why LEFT OUTER Joins?

**Decision:** Use LEFT OUTER for all joins  
**Rationale:** Data completeness over perfect matching

**Alternative Considered:** INNER JOIN  
**Rejected Because:**
- Would lose parts-only jobs (no labor)
- Would lose jobs if WO missing (data quality)
- Would lose visibility into orphaned records

**Trade-off:**
- ✅ Keep all jobs (complete picture)
- ⚠️ Some NULLs to handle (documented)
- ✅ Easier debugging (can see unmatched records)

---

### Join Performance Optimization

#### Pre-Aggregation Strategy

**Pattern:** Aggregate → Join (not Join → Aggregate)

**Why?**
- Reduces join cardinality
- Fewer rows to process
- Better query performance

**Example:**
```
❌ BAD: Join Raw_wkmechwk (1M rows) then aggregate
  • 1M row join
  • Then aggregate in fact table
  • Slow, memory intensive

✅ GOOD: Aggregate Raw_wkmechwk to job level (50k rows) then join
  • 50k row join (20x fewer rows!)
  • Pre-aggregated before join
  • Fast, efficient
```

**Implementation:**
```powerquery
// Aggregate FIRST
AggregatedHours = Table.Group(...)  // 50k rows

// Then JOIN
JoinLaborHours = Table.NestedJoin(
    RemoveMatchColumn,          // 100k rows
    AggregatedHours,            // 50k rows (pre-aggregated!)
    JoinKind.LeftOuter
)
```

---

## ⚡ Performance Architecture

### Refresh Performance Design

#### Target Performance Metrics

| Component | Target | Actual | Status |
|-----------|--------|--------|--------|
| Raw_wkothsub | <3 min | 2m 10s | ✅ |
| Raw_wkmechwk | <3 min | 2m | ✅ |
| Raw_wkrofile | <2 min | 1m 30s | ✅ |
| Fact_LaborJobSummary | <3 min | 2m 09s | ✅ |
| **Total Refresh** | **<15 min** | **~8 min** | ✅ |

#### Performance Design Principles

**1. Raw Layer Optimization**

**Column Threshold Discovery:**
- Tested incrementally to find database limits
- 20-21 columns: Optimal performance
- 30+ columns: Performance degrades (35+ minutes!)
- Lesson: Raw tables focused on essential columns only

**Query Folding:**
- 100% SQL-level processing
- No Power Query transformations in raw layer
- Simple SELECT with WHERE (incremental filter)
- Let database do the work

**Incremental Refresh:**
```sql
WHERE ModifiedDate >= '2023-01-01'  -- Simple date filter
  AND ModifiedDate < CURRENT_DATETIME
```

---

**2. Fact Layer Optimization**

**Pre-Aggregation:**
- Aggregate wkmechwk before joining (reduces cardinality)
- 1M punch records → 50k job summaries
- Join 50k rows instead of 1M rows (20x improvement!)

**Embedded Lookups:**
- 111 inspection codes embedded in query
- No separate dimension table lookup
- Faster than table join for small lists

**Column Selection from wkrofile:**
- Only select needed columns (5 of 20)
- Reduces data transfer
- Improves join performance

**Calculated Fields:**
- Pre-calculate common metrics (TotalInvoicedAmount, IsPending)
- Done once at refresh vs repeatedly in DAX
- Better report performance

---

### Incremental Refresh Strategy

#### Current Implementation

**Scope:** ModifiedDate >= 2023-01-01

**Rationale:**
- Captures 2+ years of history (sufficient for trends)
- Recent modifications on old work orders captured
- Balances performance vs data completeness

**Row Count Impact:**
```
Full History:   ~500k jobs (10+ years)
Incremental:    ~100k jobs (2023+)
Reduction:      80% fewer rows!
```

---

#### How Incremental Refresh Works

**Raw Tables:**
```powerquery
// Each raw table filters at source
WHERE ModifiedDate >= '2023-01-01'
  AND ModifiedDate < DateTime.LocalNow()
```

**Fact Table:**
- Inherits from Raw_wkothsub filter
- Only processes jobs modified since 2023
- Automatically stays incremental

**Daily Refresh:**
- Only NEW or CHANGED records processed
- Old records (no changes) skipped
- Typical daily refresh: <1,000 changed records

---

### Scalability Considerations

#### Current Capacity

**Row Volume:**
- Current: ~100k jobs (2023+)
- Growth: ~50k jobs per year
- 2-year window maintains ~100k rows (stable)

**Performance Headroom:**
- Currently using ~50% of 3-minute target
- Can handle 2-3x data volume growth
- Alert threshold: 5-minute refresh time

---

#### Future Optimization Opportunities

**If Performance Degrades:**

1. **Partition by Year:**
   - Create separate fact tables per year
   - Union in Power BI
   - Reduces single-table scan size

2. **Aggregate Fact Table:**
   - Pre-aggregate to daily grain
   - Keep detail table for drill-through
   - Faster for summary queries

3. **Columnstore Compression:**
   - If migrating to SQL-based lakehouse
   - Significant compression for numeric columns
   - Faster aggregation queries

4. **Partition Elimination:**
   - Implement proper partitioning scheme
   - Query only relevant partitions
   - Reduces data scan volume

---

## 🎯 Design Decisions & Trade-offs

### Key Architectural Decisions

#### Decision 1: Single Fact vs Multiple Facts

**Decision:** Single comprehensive fact table  
**Alternative:** Separate facts for labor, parts, status

**Rationale:**
- ✅ All metrics share same context (inspection jobs)
- ✅ Simpler report queries (single source)
- ✅ Better performance (one table scan)
- ✅ Easier maintenance

**Trade-off:**
- ⚠️ Lost: Individual technician detail
- ⚠️ Lost: Individual punch-level timing
- ✅ Acceptable for inspection reporting use case

---

#### Decision 2: Pre-Aggregated Hours vs Detail

**Decision:** Aggregate labor hours to job level  
**Alternative:** Keep punch-level detail

**Rationale:**
- ✅ Matches report grain (job-level, not punch-level)
- ✅ Better performance (50k vs 1M rows)
- ✅ Simpler queries (no aggregation in DAX)

**Trade-off:**
- ⚠️ Cannot analyze individual tech performance
- ⚠️ Cannot see specific punch times
- ✅ Can build separate Fact_LaborPunches if detail needed

---

#### Decision 3: Embedded Inspection Codes vs Dimension

**Decision:** Embed 111 codes in query as #table  
**Alternative:** Separate dim_InspectionCodes table

**Rationale:**
- ✅ Faster (no table join at refresh)
- ✅ Simpler (one less table to manage)
- ✅ Centralized (all codes in one place)
- ✅ Version controlled (in query code)

**Trade-off:**
- ⚠️ Query change needed to add codes
- ⚠️ Not user-maintainable
- ✅ Acceptable for stable list of 111 codes

---

#### Decision 4: Work Order Denormalization

**Decision:** Include WO attributes in fact table  
**Alternative:** Separate dim_WorkOrder table

**Rationale:**
- ✅ Better query performance (no join)
- ✅ Simpler model (fewer tables)
- ✅ Acceptable redundancy (WO attributes shared across jobs)

**Trade-off:**
- ⚠️ Redundant data (status repeated per job)
- ⚠️ Update complexity (change WO status = multiple rows)
- ✅ Acceptable for read-heavy analytical use case

---

### Technical Debt & Future Improvements

#### Known Technical Debt

**1. Missing Expected Date Field**
- **Issue:** Raw_wkrofile lacks expected_datetime
- **Impact:** Cannot calculate timeline variance
- **Workaround:** Use business rules (30-day threshold)
- **Resolution:** Investigate if field exists elsewhere

**2. Embedded Inspection Codes**
- **Issue:** Not user-maintainable
- **Impact:** Requires query change for new codes
- **Workaround:** Well-documented process
- **Resolution:** Consider dimension table if codes change frequently

**3. Status Code Assumptions**
- **Issue:** IsPending hardcoded for 3 status codes
- **Impact:** May miss other pending states
- **Workaround:** Periodic validation with business
- **Resolution:** Implement status dimension with IsPending flag

---

## 🚀 Future Enhancements

### Phase 2: Planned Enhancements

**1. Dimension Tables**
- dim_Date (standard calendar)
- dim_Branch (location hierarchy)
- dim_Customer (from existing project)
- Goals table (SharePoint integration)

**2. Additional Metrics**
- Customer retention (repeat inspections)
- Seasonal trends (harvest vs off-season)
- Technician productivity (if separate fact added)

---

### Phase 3: Potential Enhancements

**1. Additional Fact Tables**

**Fact_LaborPunches:**
- Grain: Individual tech punches
- Purpose: Detailed tech performance analysis
- When: If business requests individual tech metrics

**Fact_WorkOrderParts:**
- Grain: Individual parts transactions
- Purpose: Detailed parts analysis
- When: If inspection parts detail needed

**2. Advanced Analytics**

**Predictive Models:**
- Inspection estimate accuracy prediction
- Peak season capacity planning
- Equipment failure prediction (based on inspection findings)

**Machine Learning:**
- Anomaly detection (unusual inspection patterns)
- Clustering (customer segments)
- Forecasting (inspection volume prediction)

---

## 📊 Data Quality Architecture

### Built-in Validation

**Grain Preservation:**
- Row count validation (fact = raw_wkothsub)
- Alert if row count increases (indicates join issue)

**NULL Handling:**
- Expected NULLs documented (ActualHoursWorked)
- Unexpected NULLs flagged (WorkOrderStatus)

**Business Rule Validation:**
- TotalInvoicedAmount = Labor + Parts
- IsInspection TRUE for known codes

### Monitoring & Alerting

**Refresh Monitoring:**
- Alert if refresh > 5 minutes
- Alert if row count variance > 20%
- Alert if failure rate > 0%

**Data Quality Checks:**
- ActualHoursWorked NULL rate (expect 20-30%)
- WorkOrderStatus NULL rate (expect 0%)
- IsInspection distribution (expect 5-15%)

---

## 📞 Architecture Decisions Contact

**Architecture Owner:** [Brian Fox]  
**Last Reviewed:** 2025-10-30  
**Next Review:** 2026-01-30 (Quarterly)

For architecture questions or proposed changes:
1. Review this document
2. Check [data-dictionary.md](documentation/data-dictionary.md)
3. Review [README.md](README.md)
4. Contact project lead for discussion

---

## 📅 Architecture Evolution Log

### Version 1.0 (2025-10-30) - Phase 1 Complete

**Implemented:**
- ✅ Three-layer architecture (Raw → Curated → Semantic)
- ✅ Fact_LaborJobSummary with inspection intelligence
- ✅ Pre-aggregated labor hours strategy
- ✅ Embedded inspection code lookup
- ✅ Incremental refresh pattern (2023+)

**Performance Achieved:**
- ✅ 2m 09s fact table refresh (target: <3 min)
- ✅ 97% improvement over old query (60-120 min → 2 min)
- ✅ Zero failures in testing
- ✅ Eliminated capacity throttling

**Lessons Learned:**
- Database has 20-21 column optimization threshold
- Pre-aggregation before joins critical for performance
- LEFT OUTER joins preserve data completeness
- Embedded lookups faster than joins for small lists

---

**End of Architecture Documentation**
