# Inspections Report Rebuild Project

## 🎯 Project Overview

**Status:** In Development - Phase 1 Complete (Fact Table Built)  
**Priority:** High - Old report causing capacity throttling  
**Current Phase:** Foundation Complete, Moving to Report Build  
**Started:** October 2025

### Problem Statement

The existing Inspections Report uses an inefficient query (`Job_Code_Times`) that:
- Runs for 1-2 hours before completing/failing
- Causes F4 Fabric Capacity throttling for entire day
- Uses 9+ table joins with nested subqueries and aggregations
- No incremental refresh capability
- Blocks other workloads during refresh attempts

**Business Impact:** 
- Report unavailable during harvest season (peak usage period)
- Operations team cannot track inspection status
- Goals tracking impossible during capacity throttling
- Manual workarounds consuming staff time

### Solution Approach

Rebuild using modern Lakehouse architecture with dimensional modeling:

**✅ Phase 1 Complete:**
- Raw tables with incremental refresh capability (2-3 min each)
- Dimensional fact table with pre-aggregation
- Inspection job code identification via embedded lookup
- Performance validated: 2m 09s fact table refresh

**🚧 Phase 2 In Progress:**
- Power BI report rebuild (6 pages)
- External goals integration from SharePoint Excel

**🔮 Phase 3 Planned:**
- Enable incremental refresh on all remaining raw tables
- Add additional fact tables if needed
- Implement automated validation queries
- Document maintenance procedures

---

## 📊 Current Architecture

### Data Flow Diagram
```
Source Database (EquipRDB64 - ODBC)
    ↓
Raw Tables (Lakehouse) - Incremental Refresh 2023+
    ├── Raw_wkothsub (2m 10s) ← Job-level financial data (Est/Act/Inv)
    ├── Raw_wkmechwk (2m) ← Technician labor punches & hours
    └── Raw_wkrofile (1m 30s) ← Work order master & status
    ↓
Fact Tables (Lakehouse) - Pre-Aggregated Analytics
    └── Fact_LaborJobSummary (2m 09s) ← Complete inspection analytics
          • 111 inspection job codes identified
          • Labor hours aggregated to job level
          • Work order status integrated
          • Financial cycle complete (Est/Act/Inv)
    ↓
Power BI Report (6 Pages) - To Be Built
    ├── Page 1: Summary Dashboard
    ├── Page 2: Job Code Breakdown
    ├── Page 3: Pending Inspections
    ├── Page 4: Overview
    ├── Page 5: Location Analysis
    └── Page 6: Labor Goals Tracking
```

### Performance Comparison

| Metric | Old Report | New Architecture | Improvement |
|--------|-----------|------------------|-------------|
| Refresh Time | 60-120 min | ~2 min | **97% faster** |
| Success Rate | ~50% | 100% | **No failures** |
| Capacity Impact | Throttles F4 all day | Minimal | **Eliminated throttling** |
| Incremental Refresh | No | Yes | **Only changed records** |
| Query Complexity | 11+ joins, subqueries | 3 simple joins | **Maintainable** |
| Data Freshness | Stale (failed refreshes) | Daily | **Current data** |

---

## 📋 Project Phases

### ✅ Phase 1: Foundation (COMPLETE)

**Duration:** 3 weeks  
**Status:** Complete ✅

**Objectives:**
- [x] Document old report structure and requirements (6 pages, screenshots captured)
- [x] Extract table/column/measure/relationship metadata from old report
- [x] Build optimized raw table extractions with performance testing
- [x] Create Fact_LaborJobSummary with inspection identification logic
- [x] Test refresh performance and validate data quality
- [x] Document all queries with comprehensive inline documentation

**Deliverables:**
- **Raw_wkothsub:** 21-column optimized extraction (2m 10s)
  - Complete labor financial cycle (Est/Act/Inv)
  - Complete parts financial cycle (Est/Act/Inv)
  - Revenue classification and operational flags
  - Incremental refresh enabled (ModifiedDate 2023+)
  
- **Raw_wkrofile:** 20-column work order master (1m 30s)
  - Work order status and progress tracking
  - Equipment context (franchise, stock, registration)
  - Customer context and payment method
  - Timeline tracking (created, closed dates)
  - Incremental refresh enabled
  
- **Raw_wkmechwk:** 19-column labor tracking (2m)
  - Technician labor punches (start/finish times)
  - Hours worked and invoiced hours
  - Financial data (labor cost and sale)
  - Operational context (delays, rework)
  - Incremental refresh enabled

- **Fact_LaborJobSummary:** Complete inspection analytics (2m 09s)
  - 111 inspection job codes with IsInspection flag
  - Aggregated actual hours from multiple tech punches
  - Work order status integration
  - Pre-calculated metrics (totals, variance, pending flag)
  - Job-level grain (one row per job per work order)

**Performance Results:**
- Fact_LaborJobSummary: **2m 09s** ✅ (Target: <3 min)
- All raw tables: **<2m 30s** ✅
- Zero failures in testing ✅
- Capacity impact: Minimal ✅

**Key Learnings:**
- Database has 20-21 column optimization threshold
- Pre-aggregation before joins improves performance
- LEFT OUTER joins preserve data completeness
- Embedded lookups better than separate dimension tables for small lists

---

### 🚧 Phase 2: Report Build (NEXT - IN PROGRESS)

**Target Duration:** 2 weeks  
**Status:** Not Started 🚧

**Objectives:**
- [ ] Build Power BI data model connecting fact table to dimensions
- [ ] Create 6 report pages matching original functionality
- [ ] Integrate external goals Excel file from SharePoint
- [ ] Implement DAX measures for KPIs and calculations
- [ ] Test with stakeholders and gather feedback
- [ ] Deploy to production workspace
- [ ] Document report structure and measures

**Pages to Build:**

**1. Page 1 - Summary Dashboard**
   - 6 KPI cards (Inspection $$, Parts $, Labor $, Total Discount, Hours Worked, Goals)
   - Detailed work order table with drill-through capability
   - Filters: Location, Date Range, Job Code

**2. Page 2 - Job Code Breakdown**
   - Table showing counts and financial totals by job code and type
   - Columns: Branch, Job Code, Type, Count, Parts $, Labor $, Discounts
   - Sorting and filtering capabilities

**3. Page 3 - Pending Inspections**
   - Bar chart showing pending counts by job code
   - Detail table with aging analysis
   - Highlight overdue work orders (>30 days)
   - Filters: Location, Job Code

**4. Page 4 - Overview**
   - Current totals summary cards
   - Pending inspections summary table
   - Goals tracking with visual indicators
   - High-level executive view

**5. Page 5 - Location Analysis**
   - Bar chart showing total inspections by location
   - Sortable by count or revenue
   - Location comparison metrics

**6. Page 6 - Labor Goals Tracking**
   - Actual labor $ vs goal by location
   - Progress bars showing % to goal
   - Color coding (red/yellow/green) based on performance
   - YTD trending

**Dependencies:**
- External Goals Excel file (SharePoint location TBD)
- Customer dimension (already built in other project)
- Date dimension (standard calendar table)

---

### 🔮 Phase 3: Optimization & Enhancement (FUTURE)

**Target Duration:** 1 week  
**Status:** Planned 🔮

**Objectives:**
- [ ] Enable incremental refresh on remaining raw tables (7 tables)
- [ ] Evaluate need for Fact_WorkOrderParts (if parts detail required)
- [ ] Implement automated validation queries and alerting
- [ ] Create maintenance runbook for operations team
- [ ] Document troubleshooting procedures
- [ ] Add data quality monitoring
- [ ] Performance optimization if needed

**Incremental Refresh Candidates:**
- wkothsub ← Enable (has ModifiedDate)
- wkmechwk ← Enable (has ModifiedDate)
- WkInvReg ← Enable (has ModifiedDate)
- WKVEHFL ← Enable (has ModifiedDate)
- WarClaim ← Enable (has LAST_UPDATE_TS)
- TechnicianPunchedDetail ← Enable (has CreationDate)
- InTrans ← Critical! (18 min refresh, needs strategy)

**Performance Targets:**
- All raw tables: <3 min refresh
- InTrans: <5 min refresh (currently 18 min!)
- Total refresh window: <30 min for all tables

---

## 🔧 Technical Details

### Fact Table Design

**Table:** `Fact_LaborJobSummary`  
**Grain:** One row per job code per work order  
**Row Count:** ~50,000 - 100,000 rows (estimated for 2 years)  
**Refresh Time:** 2m 09s

**Key Design Decisions:**

1. **All-in-One Strategy:** Single fact table vs multiple smaller facts
   - **Decision:** Single table for simplicity and performance
   - **Rationale:** All metrics share same context (inspection work orders)
   - **Trade-off:** Aggregated labor loses individual tech detail

2. **Pre-Aggregation:** Labor hours aggregated before join
   - **Decision:** Aggregate wkmechwk to job level first, then join
   - **Rationale:** More efficient than joining then aggregating
   - **Performance:** Reduces join complexity significantly

3. **Embedded Lookup:** Inspection codes in query vs separate table
   - **Decision:** Embedded #table in M code
   - **Rationale:** 111 codes = small list, easier maintenance
   - **Trade-off:** Query change needed to add codes (acceptable)

4. **LEFT OUTER Joins:** Preserve all jobs even without labor/status
   - **Decision:** Use LEFT OUTER for both labor and status joins
   - **Rationale:** Not all jobs have labor punches (parts-only jobs)
   - **Result:** NULL handling for ActualHoursWorked expected

### Inspection Job Code Logic

**Total Codes:** 111 inspection job codes  
**Pattern Categories:**

1. **"IS-" Prefix (92 codes):** Primary inspection pattern
   - Example: IS-TRACTOR INSPECT, IS-COMBINE INSPECT, IS-CS690 INSPECT
   - Model-specific codes: IS-X300, IS-Z445, IS-D160
   - Service codes: IS-AMS SOFTWARE, IS-HARVESTREADY

2. **"/" Prefix (9 codes):** Legacy inspection format
   - Example: /TRACTOR INSPECTION, /SPRAYER INSPECTION, /COMBINE VIP INSPECT

3. **Named Codes (10 codes):** Descriptive inspection types
   - Example: COMBINE INSPECTION, ALL/9001/LEG/590

**Equipment Type Coverage:**
- Tractors (multiple models and size classes)
- Combines (various inspection levels)
- Sprayers (field and self-propelled)
- Lawn & Garden (zero-turn, lawn tractors, residential)
- Utility Vehicles (Gator, XUV series)
- Compact Equipment (compact tractors, skid steers)
- Harvest Equipment (platforms, pickers, strippers)
- Technology Services (AMS data, software)

**Service Levels:**
- VIP Inspections (premium service)
- Annual Service Inspections (scheduled maintenance)
- Pre-Rental Inspections (rental fleet)
- Seasonal Inspections (winter, harvest-ready)

**See:** `documentation/inspection-job-codes.md` for complete categorized list

### Data Sources

**Source System:** EquipRDB64 (ODBC DSN)  
**Database Type:** Informix (legacy ERP system)  
**Connection:** DSN-based ODBC connection  
**Refresh Window:** Daily (overnight preferred)

**Source Tables:**

1. **wkothsub** - Job-level financial and operational data
   - Records: ~500,000 active jobs (2023+)
   - Key Fields: Job code, Est/Act/Inv amounts for labor and parts
   - Refresh Strategy: Incremental by ModifiedDate

2. **wkmechwk** - Technician labor punch records
   - Records: ~1,000,000+ punch records (2023+)
   - Key Fields: Hours worked, invoiced hours, clock-in times
   - Grain: Individual tech punches (multiple per job)
   - Aggregation: Summed to job level in fact table

3. **wkrofile** - Work order master records
   - Records: ~250,000 work orders (2023+)
   - Key Fields: Status, creation date, closed date
   - Grain: One row per work order (many jobs per work order)

**Data Retention:** 2023+ (captures 2+ years of history for trending)

---

## 📖 Documentation Index

### Core Documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed data model design and relationships
- **[Data Dictionary](documentation/data-dictionary.md)** - Complete field definitions and business rules
- **[Inspection Job Codes](documentation/inspection-job-codes.md)** - Categorized list of 111 inspection codes
- **[Business Requirements](documentation/business-requirements.md)** - Original report specifications

### Query Documentation
- **Fact Tables:**
  - [Fact_LaborJobSummary.pq](queries/fact-tables/Fact_LaborJobSummary.pq) - Main inspection analytics fact
  
- **Raw Tables:**
  - [Raw_wkothsub.pq](queries/raw-tables/Raw_wkothsub.pq) - Job financial data extraction
  - [Raw_wkrofile.pq](queries/raw-tables/Raw_wkrofile.pq) - Work order master extraction
  - [Raw_wkmechwk.pq](queries/raw-tables/Raw_wkmechwk.pq) - Labor hours extraction

### Testing & Validation
- **[Validation Queries](validation/fact-validation-queries.md)** - Data quality testing scripts
- **[Performance Benchmarks](validation/performance-benchmarks.md)** - Refresh time baselines

---

## 🚀 Quick Start Guide

### For Developers

**Setting Up Local Environment:**

1. **Prerequisites:**
   - Power BI Desktop (latest version)
   - Access to EquipRDB64 database (ODBC DSN configured)
   - Access to Fabric Lakehouse workspace
   - Git/GitHub Desktop for version control

2. **Clone Repository:**
```powershell
   git clone [repo-url]
   cd claude-data-projects/projects/inspections-report
```

3. **Review Documentation:**
   - Start with [ARCHITECTURE.md](ARCHITECTURE.md) for data model overview
   - Read query documentation for implementation details
   - Review [data-dictionary.md](documentation/data-dictionary.md) for field definitions

4. **Access Data:**
   - Lakehouse: [Workspace Name] → [Lakehouse Name]
   - Fact Table: `Fact_LaborJobSummary`
   - Raw Tables: `Raw_wkothsub`, `Raw_wkrofile`, `Raw_wkmechwk`

5. **Run Validation:**
   - Execute queries in [validation/fact-validation-queries.md](validation/fact-validation-queries.md)
   - Verify row counts and data quality
   - Check refresh performance

### For Stakeholders

**Understanding the New Report:**

1. **What Changed:**
   - Report looks the same, performs 97% faster
   - Data refreshes daily instead of failing frequently
   - No more capacity throttling issues
   - Same 6 pages with identical metrics

2. **What's New:**
   - Real-time pending inspection tracking
   - Better performance during harvest season
   - Reliable data freshness
   - Foundation for future enhancements

3. **How to Access:**
   - Power BI Workspace: [TBD - Phase 2]
   - Report Link: [TBD - Phase 2]
   - Mobile Access: Available via Power BI app

4. **Training Materials:**
   - [TBD - Phase 2] User guide
   - [TBD - Phase 2] Video walkthrough
   - [TBD - Phase 2] FAQ document

---

## ⚠️ Known Issues & Limitations

### Current Limitations

1. **Missing Expected Date Field**
   - **Issue:** Raw_wkrofile lacks `expected_datetime` field from source system
   - **Impact:** Cannot calculate expected vs actual timeline variance
   - **Workaround:** Using CreatedOn + business rules (e.g., 30-day aging threshold)
   - **Future:** Investigate if field available in other source tables

2. **Technician Detail Lost in Aggregation**
   - **Issue:** Labor hours aggregated from multiple techs to single job total
   - **Impact:** Cannot analyze individual technician performance at this grain
   - **Mitigation:** Separate Fact_LaborPunches table available if detail needed
   - **Decision:** Trade-off accepted for simplicity and performance

3. **Punch-Level Granularity Not Preserved**
   - **Issue:** Individual clock-in/out times not maintained in fact table
   - **Impact:** Cannot track specific work session timing
   - **Mitigation:** Raw_wkmechwk available for detailed analysis if needed
   - **Decision:** Job-level aggregation sufficient for inspection reporting

4. **Status Code Mapping Assumptions**
   - **Issue:** IsPending flag assumes "wip", "bi", "va" are pending states
   - **Impact:** May miss other pending states if status codes evolve
   - **Validation:** Requires periodic review with business users
   - **Maintenance:** Update flag logic if new status codes introduced

5. **Inspection Code List Maintenance**
   - **Issue:** 111 codes embedded in M query (not separate dimension table)
   - **Impact:** Query change required to add new inspection types
   - **Mitigation:** Centralized location in query, well-documented
   - **Trade-off:** Simplicity vs flexibility (acceptable for 111 static codes)

### Known Risks

1. **Data Volume Growth**
   - **Risk:** Performance may degrade if data volume increases 10x
   - **Mitigation:** Monitoring refresh times, incremental refresh limits scope
   - **Threshold:** Alert if refresh exceeds 5 minutes

2. **Source System Changes**
   - **Risk:** Field names or structures may change in EquipRDB64
   - **Mitigation:** Comprehensive documentation, error handling in queries
   - **Response Plan:** Raw table layer isolates changes from fact tables

3. **Inspection Definition Evolution**
   - **Risk:** Business may add new inspection types frequently
   - **Mitigation:** Documented process for adding codes, centralized list
   - **Review Cadence:** Quarterly review with stakeholders

4. **Goals File Integration**
   - **Risk:** SharePoint Excel file format changes may break integration
   - **Mitigation:** [TBD - Phase 2] Document file structure requirements
   - **Validation:** Automated checks for file structure changes

### Performance Monitoring

**Alert Thresholds:**
- Fact table refresh: >5 minutes (investigate)
- Raw table refresh: >3 minutes (investigate)
- Row count variance: >20% from baseline (data quality issue)
- NULL percentage in ActualHoursWorked: >40% (data quality issue)

**Monthly Review:**
- Refresh time trending
- Row count trending
- Failure rate monitoring
- Capacity impact assessment

---

## 📞 Contacts & Support

### Project Team

**Project Lead:** [Your Name]  
**Role:** BI Developer / Data Engineer  
**Responsibilities:** Architecture, development, documentation

**Stakeholder:** [Stakeholder Name]  
**Role:** Operations Manager  
**Responsibilities:** Business requirements, UAT, report usage

**Business Analyst:** [BA Name if applicable]  
**Role:** Requirements & Validation  
**Responsibilities:** Requirements gathering, testing, training

### Support Process

**For Issues:**
1. Check [Known Issues](#known-issues--limitations) section
2. Review [validation queries](validation/fact-validation-queries.md)
3. Contact project lead with:
   - Description of issue
   - Screenshots if applicable
   - Steps to reproduce
   - Expected vs actual behavior

**For Enhancements:**
1. Submit request to project lead
2. Document business justification
3. Estimate effort and priority
4. Schedule for future phase

---

## 📅 Detailed Change Log

### 2025-10-30

**Phase 1 Completion:**
- ✅ Created Fact_LaborJobSummary with complete documentation
- ✅ Validated inspection flag logic (111 job codes)
- ✅ Tested refresh performance: 2m 09s (within target)
- ✅ Documented all architectural decisions
- ✅ Prepared for Phase 2 (report build)

**Performance Validation:**
- Fact table refresh: 2m 09s ✅
- Row count matches expected grain ✅
- IsInspection flag validated with spot checks ✅
- ActualHoursWorked populated for ~75% of jobs ✅ (expected)
- WorkOrderStatus populated for 100% of rows ✅

### 2025-10-XX (Earlier in project)

**Raw Table Development:**
- ✅ Built Raw_wkothsub (21 columns, 2m 10s)
- ✅ Learned database optimization threshold (20-21 columns)
- ✅ Built Raw_wkrofile (20 columns, 1m 30s)
- ✅ Built Raw_wkmechwk (19 columns, 2m)
- ✅ Established incremental refresh pattern (2023+)
- ✅ Created comprehensive inline documentation standard

**Requirements Gathering:**
- ✅ Captured screenshots of all 6 report pages
- ✅ Extracted metadata (tables, columns, measures, relationships)
- ✅ Documented business requirements and use cases
- ✅ Identified performance issues with old report

---

## 🔗 Related Projects

### Internal Dependencies

- **[Customer Dimension Project](../customer-dimension/)** - Shared customer dimension
  - Status: Complete
  - Usage: Customer attribution in inspection reports
  - Integration: Join on AccountNumber

### Future Integration Opportunities

- **Labor Analytics Project** - Related labor fact tables
  - Potential: Cross-project labor efficiency analysis
  - Consideration: Shared technician dimension

- **Parts Analytics Project** - Parts transaction analysis
  - Potential: Fact_WorkOrderParts if detailed parts breakdown needed
  - Decision: Phase 3 evaluation based on business need

- **Warranty Analytics Project** - Warranty claim tracking
  - Potential: Integration via ClaimNumber field
  - Consideration: Warranty vs customer pay inspection analysis

---

## 🎓 Lessons Learned

### Technical Learnings

1. **Database Optimization Thresholds:**
   - Discovery: 20-21 column limit before performance degrades
   - Learning: Test column additions incrementally
   - Application: All raw tables respect this threshold

2. **Pre-Aggregation Strategy:**
   - Discovery: Aggregating before join faster than join then aggregate
   - Learning: Reduce grain transformation complexity early
   - Application: wkmechwk aggregated to job level before joining

3. **Embedded vs Separate Lookups:**
   - Discovery: Small lists (<200 items) better embedded in query
   - Learning: Trade-off between flexibility and simplicity
   - Application: 111 inspection codes embedded successfully

4. **LEFT OUTER Join Importance:**
   - Discovery: Not all jobs have labor punches (parts-only jobs)
   - Learning: Preserve all base grain records, accept NULLs
   - Application: All joins use LEFT OUTER to maintain completeness

### Process Improvements

1. **Documentation First:** 
   - Comprehensive inline documentation saves time later
   - Future developer onboarding significantly easier
   - Business users can read queries and understand logic

2. **Incremental Development:**
   - Building raw tables before fact tables = correct approach
   - Testing each layer independently caught issues early
   - Performance validation at each step prevented surprises

3. **Stakeholder Communication:**
   - Regular updates on progress and performance wins
   - Managing expectations on limitations and trade-offs
   - Early wins (97% performance improvement) build confidence

---

## 🏆 Success Metrics

### Performance Metrics (Achieved)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Fact Refresh Time | <3 min | 2m 09s | ✅ Exceeded |
| Raw Table Refresh | <3 min | <2m 30s | ✅ Achieved |
| Failure Rate | <5% | 0% | ✅ Exceeded |
| Capacity Impact | Minimal | Minimal | ✅ Achieved |

### Business Impact (Expected - Phase 2)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Report Availability | 50% | 99%+ | 🚧 Phase 2 |
| Data Freshness | Stale | Daily | 🚧 Phase 2 |
| User Satisfaction | Low | High | 🚧 Phase 2 |
| Manual Workarounds | High | None | 🚧 Phase 2 |

---

## 📚 Additional Resources

### Microsoft Documentation
- [Power BI Incremental Refresh](https://docs.microsoft.com/power-bi/incremental-refresh)
- [Power Query M Reference](https://docs.microsoft.com/powerquery-m/)
- [Fabric Lakehouse Documentation](https://docs.microsoft.com/fabric/lakehouse)

### Internal Resources
- Company Data Governance Standards: [Link TBD]
- BI Best Practices Guide: [Link TBD]
- Fabric Capacity Management: [Link TBD]

---

**Last Updated:** 2025-10-30  
**Version:** 1.0 - Phase 1 Complete  
**Next Review:** Start of Phase 2