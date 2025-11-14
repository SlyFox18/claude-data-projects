# Inspections Report - Technical Architecture

> **Document Purpose:** Detailed technical design decisions, data model architecture, and system implementation patterns  
> **Last Updated:** 2025-11-14  
> **Author:** [Your Name]

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Data Model Design](#data-model-design)
3. [Fact Table Architectures](#fact-table-architectures)
4. [Dimension Table Designs](#dimension-table-designs)
5. [Goals System Integration](#goals-system-integration)
6. [Predictive Analytics Engine](#predictive-analytics-engine)
7. [Performance Optimization](#performance-optimization)
8. [Business Logic Patterns](#business-logic-patterns)
9. [Data Quality Framework](#data-quality-framework)
10. [Technical Decisions Log](#technical-decisions-log)

---

## 🏗️ Architecture Overview

### **System Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  Power BI Report (7 Pages + Drill-Through Capabilities)    │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│                    SEMANTIC LAYER                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   3 Fact     │  │     4        │  │   Service    │     │
│  │   Tables     │  │  Dimensions  │  │Recommendations│    │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│          ▲                 ▲                 ▲              │
└──────────┼─────────────────┼─────────────────┼──────────────┘
           │                 │                 │
┌──────────▼─────────────────▼─────────────────▼──────────────┐
│                    DATA INTEGRATION LAYER                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  Fabric    │  │   Excel    │  │    DAX     │            │
│  │ Dataflows  │  │  OneDrive  │  │ Calculated │            │
│  │ (6 Raw)    │  │  (Goals)   │  │   Table    │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└───────────────────────────────────────────────────────────────┘
           │                 │                 
┌──────────▼─────────────────▼──────────────────────────────────┐
│                    SOURCE SYSTEMS                              │
│  SQL Database (Work Orders, Parts, Customers, Branches)      │
└───────────────────────────────────────────────────────────────┘
```

### **Three-Layer Architecture**

#### **1. Source Layer (SQL Database)**
- **Purpose:** Operational transactional systems
- **Tables:** Work orders, labor punches, parts transactions, customer data
- **Refresh:** Real-time operational updates
- **Access:** Read-only via Fabric Dataflows

#### **2. Data Integration Layer**
- **Fabric Dataflows (6 Raw Tables):**
  - Raw_wkothsub (incremental refresh 2023+)
  - Raw_wkmechwk (incremental refresh 2023+)
  - Raw_wkrofile (incremental refresh 2023+)
  - Raw_InTrans (date filter 2024+)
  - Raw_RepairOrderDetail (full refresh)
  - Raw_TechnicianPunchedDetail (full refresh)
  
- **Excel Integration (OneDrive):**
  - Inspection Goals (manual maintenance)
  - Branch-level targets and thresholds
  
- **DAX Calculated Table:**
  - ServiceRecommendations (generated at model refresh)
  - Predictive analytics from historical patterns

#### **3. Semantic Layer (Power BI Model)**
- **Fact Tables (3):** Pre-aggregated business events
- **Dimension Tables (4):** Master data for analysis
- **Goals Table:** Performance targets
- **Calculated Table:** Predictive recommendations
- **Measures:** Business logic and KPIs
- **Hierarchies:** Drill-down paths

---

## 📊 Data Model Design

### **Star Schema Implementation**

The data model follows **dimensional modeling best practices** with a star schema design optimized for analytical queries and report performance.

### **Design Principles**

1. **Fact-Centered Design:** Business events (inspections, parts, pending work) at the center
2. **Conformed Dimensions:** Shared dimensions across fact tables
3. **Surrogate Keys:** Integer keys for optimal join performance
4. **One-Way Relationships:** Simple, predictable filter propagation
5. **Bi-Directional Only When Needed:** Minimal use for specific scenarios

### **Relationship Matrix**

| From Table | To Table | Join Column(s) | Cardinality | Cross-Filter |
|------------|----------|----------------|-------------|--------------|
| Fact_LaborJobSummary | dim_BranchLocation | BranchCode | Many-to-One | Single |
| Fact_LaborJobSummary | dim_DateTable | WorkOrderCreationDate | Many-to-One | Single |
| Fact_LaborJobSummary | dim_CustomerList | (Lookup logic) | Many-to-One | Single |
| Fact_PendingInspections | dim_BranchLocation | BranchCode | Many-to-One | Single |
| Fact_PendingInspections | dim_DateTable | CreationDate | Many-to-One | Single |
| Fact_WorkOrderParts | dim_BranchLocation | BranchCode | Many-to-One | Single |
| Fact_WorkOrderParts | dim_Parts | PartNumber | Many-to-One | Single |
| Fact_WorkOrderParts | dim_DateTable | TransactionDate | Many-to-One | Single |
| dim_BranchLocation | Inspection Goals | LocationID → LOCATION | One-to-One | Single |

### **Grain Decisions**

Each fact table grain carefully chosen for business analysis needs:

- **Fact_LaborJobSummary:** Job-level grain (one row per job code per work order)
  - *Why:* Balances detail with performance, enables job code analysis
  - *Trade-off:* Loses individual tech detail (acceptable for reporting needs)

- **Fact_PendingInspections:** Work order-level grain (one row per pending work order)
  - *Why:* Simpler structure, faster refresh, matches business view of "pending queue"
  - *Trade-off:* Only shows primary inspection code (acceptable for queue management)

- **Fact_WorkOrderParts:** Transaction-level grain (one row per part per invoice)
  - *Why:* Maximum detail for parts analysis, pricing flexibility
  - *Trade-off:* Larger row count, longer refresh (managed with proper indexing)

---

## 🎯 Fact Table Architectures

### **Fact_LaborJobSummary Architecture**

#### **Design Pattern: Multi-Source Integration**

```
┌───────────────┐
│  Raw_wkothsub │  (Primary: Job financial data)
│  Grain: Jobs  │
└───────┬───────┘
        │ LEFT JOIN
┌───────▼───────────┐
│  Raw_wkmechwk     │  (Aggregated: Tech hours → job hours)
│  Grain: Punches   │  PRE-AGGREGATE before join!
│  → Job Level      │
└───────┬───────────┘
        │ LEFT JOIN
┌───────▼───────────┐
│  Raw_wkrofile     │  (Context: Work order status)
│  Grain: Work Order│
└───────────────────┘
```

#### **Key Design Decisions**

1. **Pre-Aggregation Strategy**
   - **Decision:** Aggregate Raw_wkmechwk from punch-level to job-level BEFORE joining
   - **Rationale:** Reduces join complexity, faster performance, cleaner grain
   - **Implementation:** `Table.Group` on Branch + WorkOrder + JobCode

2. **LEFT JOIN Preservation**
   - **Decision:** Use LEFT OUTER joins for labor and work order context
   - **Rationale:** Preserves all jobs even if no labor punches or work order record
   - **Benefit:** Complete job list, NULLs indicate missing data (not missing jobs)

3. **Inspection Code Lookup**
   - **Decision:** Embed 111 inspection codes in query (inline table)
   - **Rationale:** Single source of truth, no external dependency, version controlled
   - **Maintenance:** Update in one place when new inspection codes added

4. **Refresh Strategy: Incremental**
   - **Decision:** Inherit incremental refresh from Raw_wkothsub (2023+, ModifiedDate)
   - **Rationale:** Reduces refresh time, processes only changed records
   - **Performance:** 3 minutes for ~50K rows (excellent)

### **Fact_PendingInspections Architecture**

#### **Design Pattern: Simple Filtering with Aggregation**

```
┌─────────────────────┐
│ Raw_RepairOrderDetail│  (One row per work order)
│ Filter: NOT Invoiced │
└──────────┬───────────┘
           │ INNER JOIN (Inspection Codes)
           │ LEFT JOIN (Hours)
┌──────────▼─────────────────┐
│ Raw_TechnicianPunchedDetail│  (Aggregated: Hours by WO)
│ PRE-AGGREGATE: SUM(Hours)  │
└────────────────────────────┘
```

#### **Key Design Decisions**

1. **Work Order Grain Choice**
   - **Decision:** One row per work order (not job-level like LaborJobSummary)
   - **Rationale:** RepairOrderDetail has one row per WO with primary job code
   - **Benefit:** Simpler logic, faster refresh, matches business view

2. **Status Definition**
   - **Decision:** StatusDisplay NOT "Invoiced" (includes "In Process", "WIP Finished Not Invoiced")
   - **Rationale:** Clear exclusion of completed work, flexible for new status values
   - **Validation:** Ensures no overlap with Fact_LaborJobSummary

3. **Hours Pre-Aggregation**
   - **Decision:** Aggregate TechnicianPunchedDetail to work order level before joining
   - **Rationale:** LEFT JOIN preserves WOs without hours (work not started yet)
   - **Business Value:** Shows progress on pending work

4. **Refresh Strategy: Full**
   - **Decision:** Full refresh on each load
   - **Rationale:** Small dataset (~100 rows), fast refresh (1.5 min), always current
   - **Acceptable:** Dynamic data, full refresh is still very fast

### **Fact_WorkOrderParts Architecture**

#### **Design Pattern: Invoice-Based Filtering with Parts Detail**

```
┌────────────────────┐
│   Raw_wkothsub     │  (Inspection work orders)
│   Filter: Inspection│
│   Get: Invoice #s  │
└────────┬───────────┘
         │ INNER JOIN (on Invoice Number)
         │ ⚠️ CRITICAL FIX: Was work order, now invoice!
┌────────▼───────────┐
│   Raw_InTrans      │  (Parts transactions)
│   Join Key: REF_NO │  (= Invoice Number)
│   Filter: Franchise│
└────────────────────┘
```

#### **Key Design Decisions**

1. **CRITICAL BUG FIX: Invoice Number Join**
   - **Original Bug:** Joined InTrans.REF_NO to work order numbers
   - **Problem:** InTrans.REF_NO is actually INVOICE NUMBER, not work order
   - **Result Before Fix:** Only 186 rows (incorrect join)
   - **Fix Applied:** Join InTrans to invoice numbers from inspection work orders
   - **Result After Fix:** ~150K rows (correct join)
   - **Learning:** Always verify field semantics, not just names!

2. **Two-Step Filtering Approach**
   - **Step 1:** Identify inspection work orders from Raw_wkothsub
   - **Step 2:** Get invoice numbers from those work orders
   - **Step 3:** Filter InTrans to those invoice numbers
   - **Rationale:** Ensures only parts from inspection work orders included

3. **Data Type Safety**
   - **Decision:** Explicitly convert Branch and Invoice to TEXT before joins
   - **Rationale:** Prevents SQL numeric overflow errors on large invoice numbers
   - **Implementation:** `Table.TransformColumnTypes` before `Table.NestedJoin`

4. **Refresh Strategy: Full with Date Filter**
   - **Decision:** Full refresh, but InTrans filtered to 2024+ at source
   - **Rationale:** Reduces data volume, faster refresh, recent data sufficient
   - **Performance:** 10 minutes (monitoring for optimization opportunities)

---

## 🗂️ Dimension Table Designs

### **dim_BranchLocation Design**

#### **Purpose:** Branch/location master with operational intelligence

#### **Key Features**

1. **Smart Operational Filtering**
   - **Original Issue:** Used `Table.Skip(30)` which removed legitimate branches
   - **Fix Applied:** Pattern-based filtering on BranchID
   - **Keep:** Numbered branches (1, 2, 3, 11, 12...) and specialized shops (1I, 1S, 1C...)
   - **Remove:** Hourly branches (H1, H2...) and Salary branches (S1, S2...)
   - **Impact:** Restored complete operational branch coverage

2. **Branch Type Classification**
   - **Main Branch:** Full-service operational locations
   - **IS Shop:** Inspection/service specialists
   - **Set-Up Shop:** Equipment setup specialists
   - **CP Shop:** Customer pickup specialists
   - **Business Value:** Enables specialized work assignment

3. **Geographic Intelligence**
   - **Regional Classification:** West Texas, Central Texas, Southern NM, Border Region
   - **Market Presence:** Primary vs Secondary market categorization
   - **Service Capacity:** Full Service, Inspection Specialist, Setup Specialist
   - **Business Value:** Territory management and strategic planning

4. **Data Quality Scoring**
   - **Scoring:** 0-100 scale based on field completeness
   - **Components:** Location ID (40pts), Geography (30pts), Operations (30pts)
   - **Business Value:** Identifies records needing data enhancement

### **dim_CustomerList Design**

#### **Purpose:** Customer master with financial intelligence

#### **Key Features**

1. **Multiple Naming Strategies**
   - **Customer:** Standard format (Company or "LastName, FirstName")
   - **DisplayName:** Best available name with intelligent fallbacks
   - **PrimaryName:** Company-first priority
   - **FullName:** Complete individual name
   - **Business Value:** Flexible naming for different report contexts

2. **Financial Health Indicators**
   - **Credit Utilization:** AccountBalance / CreditLimit
   - **Financial Risk Level:** Minimal / Low / Medium / High (based on utilization)
   - **Has Overdue Balance:** Boolean across all aging buckets
   - **Business Value:** Proactive credit management and risk assessment

3. **Customer Segmentation**
   - **Customer Tier:** Key Account / Premium / Standard / Basic
   - **Criteria:** Key flag + credit limit thresholds
   - **Is High Value:** Boolean for premium segments
   - **Business Value:** Differentiated service levels and prioritization

4. **Special System Customers**
   - **Purpose:** Handle work orders without standard customer assignment
   - **Negative Keys:** -1 through -8 for easy identification
   - **Types:** UNKNOWN, INTERNAL, WARRANTY, FLEET, EXCESS, POLICY, BILLING, MISC
   - **Integration:** Critical for Fact_LaborJobSummary CustomerLookupKey logic

5. **Marketing Intelligence**
   - **IsMarketingEligible:** Has email AND account is active
   - **PreferredContactMethod:** Email > Mobile > Business Phone > Mail
   - **Business Value:** Targeted campaigns and optimal communication

### **dim_DateTable Design**

#### **Purpose:** Standard date dimension for time intelligence

#### **Key Features**

1. **Complete Calendar Attributes**
   - Date, Year, Quarter, Month, Week, Day, Weekday, etc.
   - Fiscal calendar support
   - Holiday calendar (if applicable)

2. **Time Intelligence Functions**
   - YTD, QTD, MTD calculations
   - Prior period comparisons
   - Rolling windows (30/60/90 days)

3. **Date Hierarchies**
   - Year > Quarter > Month > Day
   - Year > Month > Week > Day
   - Enables drill-down analysis

### **dim_Parts Design**

#### **Purpose:** Parts master with inventory and pricing intelligence

#### **Key Features**

1. **Inventory Intelligence**
   - **Stock Status:** In Stock / Backordered / Out of Stock
   - **IsAvailable:** Boolean for quick filtering
   - **Calculation:** Based on QuantityOnHand and BackOrderQty
   - **Business Value:** Service planning and parts availability

2. **Sales Activity Indicators**
   - **HasRecentSales:** Boolean (12-month sales > 0)
   - **ActivityStatus:** Active / No Recent Sales
   - **Business Value:** Obsolescence management

3. **Business Filter Columns**
   - **Source, SLC, DealerGroupCode, CommodityCode, VendorCode**
   - **Purpose:** Advanced filtering and classification
   - **Business Value:** Procurement and inventory management

4. **Pricing Information**
   - **InventoryCost:** Cost basis
   - **SellPrice1:** Selling price
   - **ListPrice:** Manufacturer list price
   - **Business Value:** Margin analysis

5. **CRITICAL USAGE NOTE**
   - **Problem:** Fact_WorkOrderParts.Description contains "Inv No. XXXXXX"
   - **Solution:** ALWAYS use dim_Parts.Description for actual part descriptions
   - **Join:** dim_Parts.PartNumber = Fact_WorkOrderParts.PartNumber

---

## 🎯 Goals System Integration

### **Architecture Pattern: Excel as Master Data**

```
┌───────────────────────┐
│   Excel on OneDrive   │  (Manual maintenance)
│  "Inspection Goals"   │
│  15 branch locations  │
└──────────┬────────────┘
           │ Power BI Get Data
           │ (Refresh on demand)
┌──────────▼────────────┐
│  Inspection Goals     │  (Power BI Table)
│  LOCATION field       │
└──────────┬────────────┘
           │ Relationship
┌──────────▼────────────┐
│  dim_BranchLocation   │
│  LocationID field     │
└───────────────────────┘
```

### **Design Decisions**

1. **Why Excel (Not Database)?**
   - **Decision:** Excel on OneDrive as master source for goals
   - **Rationale:**
     - Business users comfortable with Excel
     - Easy goal updates without IT
     - Version control via OneDrive
     - Flexible format for business needs
   - **Trade-off:** Manual maintenance required, no automated validation

2. **Relationship Strategy**
   - **Join:** Inspection Goals.LOCATION → dim_BranchLocation.LocationID
   - **Cardinality:** One-to-One (one goal record per branch)
   - **Filter Direction:** Single direction from goals to branch
   - **Validation:** All 15 active branches have goals defined

3. **Goal Structure**
   - **General Goals:**
     - Total Inspections Goal
     - Labor $$ with Inspection Goal
     - Total Parts $$ Goal
   - **Specific Goals (CS690/770 Combines):**
     - CS690/770 Inspections Goal
     - CS690/770 Labor $$ with Inspection Goal
     - CS690/770 Total Parts $$ Goal
   - **Rationale:** Combines are high-value, merit separate tracking

4. **Goal Calculation Pattern**
   ```dax
   % to Goal = 
   DIVIDE(
       [Actual Value],
       [Goal Value],
       0  // Return 0 if goal is missing/zero
   )
   ```

5. **Performance Indicators**
   - **>120%:** 🏆 Exceptional performance
   - **100-119%:** ✅ Meeting/exceeding goal
   - **90-99%:** ⚠️ Approaching goal
   - **<90%:** 🚨 Below target (needs attention)

---

## 🔮 Predictive Analytics Engine

### **ServiceRecommendations Calculated Table**

#### **Architecture: Historical Pattern Learning**

```
┌──────────────────────────┐
│  Fact_PendingInspections │  (Current queue)
│  Get: Inspection Codes   │
└─────────┬────────────────┘
          │
          │ For Each Pending Code:
          │
┌─────────▼─────────────────┐
│  Fact_LaborJobSummary     │  (Historical data)
│  Find: Completed WOs with │
│        this inspection    │
└─────────┬─────────────────┘
          │
          │ For Each Completed WO:
          │
┌─────────▼─────────────────┐
│  Identify OTHER Services  │  (Non-inspection jobs)
│  Performed on this WO     │
└─────────┬─────────────────┘
          │
          │ Calculate Frequency:
          │
┌─────────▼─────────────────┐
│  Service Frequency =      │
│  (Times Appeared) /       │
│  (Total Completions)      │
└───────────────────────────┘
```

#### **DAX Implementation Logic**

1. **Step 1: Get Pending Inspection Codes**
   ```dax
   VAR InspectionCodes = 
       SELECTCOLUMNS(
           DISTINCT(Fact_PendingInspections[JobCode]),
           "InspectionJobCode", Fact_PendingInspections[JobCode]
       )
   ```

2. **Step 2: For Each Code, Find Historical Work Orders**
   ```dax
   VAR InspectionWorkOrders = 
       CALCULATETABLE(
           VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
           Fact_LaborJobSummary[JobCode] = CurrentInspection,
           Fact_LaborJobSummary[IsInspection] = TRUE,
           NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
       )
   ```

3. **Step 3: Find Other Services on Those Work Orders**
   ```dax
   VAR UniqueServices = 
       CALCULATETABLE(
           SUMMARIZE(
               Fact_LaborJobSummary,
               Fact_LaborJobSummary[JobCode],
               Fact_LaborJobSummary[JobType]
           ),
           Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWorkOrders,
           Fact_LaborJobSummary[IsInspection] = FALSE
       )
   ```

4. **Step 4: Calculate Frequency**
   ```dax
   "TimesAdded", 
       VAR ServiceCode = Fact_LaborJobSummary[JobCode]
       VAR WorkOrdersWithService = 
           CALCULATETABLE(
               VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
               Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWorkOrders,
               Fact_LaborJobSummary[JobCode] = ServiceCode
           )
       RETURN COUNTROWS(WorkOrdersWithService)
   ```

5. **Step 5: Calculate Total Labor Cost**
   ```dax
   "TotalLabor",
       VAR ServiceCode = Fact_LaborJobSummary[JobCode]
       RETURN
       CALCULATE(
           SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
           Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWorkOrders,
           Fact_LaborJobSummary[JobCode] = ServiceCode
       )
   ```

#### **Business Logic**

1. **Frequency Calculation**
   ```
   Frequency % = (TimesAdded / CompletedInspections) * 100
   
   Example:
   - Completed IS-CS690 inspections: 224
   - GEN REPAIR 1 appeared on: 124 of them
   - Frequency: 124 / 224 = 55%
   ```

2. **Projected Need**
   ```
   EstimatedNeed = PendingCount * Frequency%
   
   Example:
   - Pending IS-CS690 inspections: 6
   - GEN REPAIR 1 frequency: 55%
   - Estimated need: 6 * 0.55 = 3.3 → round to 3
   ```

3. **Revenue Projection**
   ```
   EstimatedRevenue = EstimatedNeed * AverageLabor
   
   Where:
   AverageLabor = TotalLabor / TimesAdded
   ```

#### **Color Coding Logic**

- **🔴 Red (50%+ frequency):** Critical - needed on most inspections
- **🟡 Yellow (30-49% frequency):** Common - often needed
- **🟢 Green (<30% frequency):** Occasional - sometimes needed

#### **Refresh Behavior**

- **When:** Calculated table refreshes with full model refresh
- **Duration:** Calculates in seconds (DAX execution)
- **Dependencies:** Requires Fact_LaborJobSummary and Fact_PendingInspections to be current

---

## ⚡ Performance Optimization

### **Refresh Time Analysis**

| Component | Time | Optimization Status |
|-----------|------|---------------------|
| Raw Tables (6) | ~3 min | ✅ Optimized (incremental where possible) |
| Fact_LaborJobSummary | 3 min | ✅ Excellent (pre-aggregation working) |
| Fact_PendingInspections | 1.5 min | ✅ Excellent (small dataset) |
| Fact_WorkOrderParts | 10 min | ⚠️ Monitoring (complex joins) |
| Dimensions (4) | ~2 min | ✅ Good (master data, infrequent changes) |
| **Total** | **~14.5 min** | **✅ Acceptable, monitoring WorkOrderParts** |

### **Optimization Strategies Implemented**

1. **Incremental Refresh (Raw Tables)**
   - **Applied To:** Raw_wkothsub, Raw_wkmechwk, Raw_wkrofile
   - **Strategy:** 2023+ scope, ModifiedDate filtering
   - **Benefit:** Only processes changed/new records
   - **Impact:** Reduced raw table refresh from 30+ min to ~3 min

2. **Pre-Aggregation Before Joins**
   - **Pattern:** Aggregate → Join (not Join → Aggregate)
   - **Example:** Raw_wkmechwk aggregated punch→job level before joining
   - **Benefit:** Fewer rows to join, faster performance
   - **Impact:** Fact_LaborJobSummary 3 min (vs 10+ min without)

3. **Strategic Column Selection**
   - **Pattern:** Select only needed columns early in query
   - **Implementation:** `Table.SelectColumns` right after source
   - **Benefit:** Reduces data transfer, memory usage
   - **Impact:** Faster processing throughout query

4. **Data Type Optimization**
   - **Pattern:** Explicit type conversion for join columns
   - **Critical:** Convert to TEXT before string joins
   - **Benefit:** Prevents SQL overflow, ensures proper joins
   - **Example:** Branch + Invoice numbers as TEXT in WorkOrderParts

5. **Query Folding Preservation**
   - **Pattern:** Structure queries to maintain folding where possible
   - **Monitoring:** Check "View Native Query" in Power Query
   - **Benefit:** Operations pushed to SQL Server (faster than M engine)
   - **Trade-off:** Balance between folding and complex transformations

### **Fact_WorkOrderParts Optimization Opportunities**

**Current Issue:** 10-minute refresh time

**Potential Optimizations to Investigate:**

1. **Incremental Refresh Evaluation**
   - Consider if ModifiedDate available on InTrans
   - Scope could be 2024+ with incremental updates
   - Risk: Invoice numbers may reference older work orders

2. **Index Optimization**
   - Ensure Branch + Invoice indexed on source tables
   - PartNumber index for dim_Parts join
   - May require DBA coordination

3. **Join Order Optimization**
   - Test different join sequences
   - Consider materializing inspection invoices list separately

4. **Parallel Processing**
   - Evaluate if partitioning possible
   - Separate by branch or date range
   - Combine results (more complex to maintain)

**Current Assessment:** 10 minutes acceptable for now, monitor CU usage

---

## 🔐 Data Quality Framework

### **Quality Dimensions Tracked**

1. **Completeness:** Are all expected fields populated?
2. **Accuracy:** Do values match business rules?
3. **Consistency:** Are values consistent across related tables?
4. **Timeliness:** Is data current and refreshing properly?
5. **Uniqueness:** Are there unexpected duplicates?

### **Data Quality Scoring Implementation**

#### **dim_BranchLocation Scoring (0-100)**
```
Score Components:
- Location ID present and not default (20 pts)
- Branch ID present (20 pts)
- City present (15 pts)
- State present (15 pts)
- Branch Name present (15 pts)
- Valid type classification (15 pts)
```

#### **dim_CustomerList Scoring (0-100)**
```
Score Components:
- Name present (Company OR FirstName) (25 pts)
- Contact info (Email OR Phone) (25 pts)
- Address complete (Street + City + State) (25 pts)
- Financial data (CreditLimit OR Balance <> 0) (25 pts)
```

#### **dim_Parts Scoring (Conceptual)**
```
Score Components:
- Part number and description (25 pts)
- Inventory data present (25 pts)
- Pricing data present (25 pts)
- Business classifications present (25 pts)
```

### **Validation Checks**

1. **Row Count Validation**
   - Expected vs actual row counts
   - Alert if variance > 10%

2. **Financial Reconciliation**
   - Sum of parts and labor vs known totals
   - Goals comparison validation

3. **Relationship Integrity**
   - All fact rows have valid dimension matches
   - No orphaned records

4. **Business Rule Validation**
   - Inspection flags applied correctly
   - Status transitions valid
   - Date logic consistent

---

## 📝 Technical Decisions Log

### **Decision 1: Fact Table Grain Choices**
- **Decision:** Job-level (Labor), Work order-level (Pending), Transaction-level (Parts)
- **Date:** 2025-10-30
- **Rationale:** Balance detail vs performance, align with business questions
- **Impact:** Optimized performance, appropriate analysis levels

### **Decision 2: Goals in Excel (Not Database)**
- **Decision:** Excel on OneDrive as master goals source
- **Date:** 2025-11-14
- **Rationale:** Business ownership, easy updates, familiar tool
- **Impact:** Flexible goal management, manual maintenance required

### **Decision 3: Calculated Table for Recommendations**
- **Decision:** DAX calculated table (not M query)
- **Date:** 2025-11-14
- **Rationale:** Depends on existing fact tables, complex logic suited for DAX
- **Impact:** Fast refresh, easy to modify, integrated with model

### **Decision 4: Invoice Join Fix (WorkOrderParts)**
- **Decision:** Join InTrans to invoice numbers (not work order numbers)
- **Date:** 2025-11-14 (Fix applied)
- **Rationale:** InTrans.REF_NO is invoice number, not work order
- **Impact:** Correct data (186 rows → 150K rows)

### **Decision 5: Pre-Aggregation Pattern**
- **Decision:** Aggregate tech hours before joining to jobs
- **Date:** 2025-10-30
- **Rationale:** Reduces join complexity, faster performance
- **Impact:** 3-minute refresh (vs 10+ minutes)

### **Decision 6: Negative Keys for Special Customers**
- **Decision:** Use -1 to -8 for system customer records
- **Date:** 2025-10-30
- **Rationale:** Easy identification, no conflict with real customers
- **Impact:** Clean handling of non-standard work order scenarios

### **Decision 7: Embedded Inspection Codes**
- **Decision:** 111 codes defined inline in queries
- **Date:** 2025-10-30
- **Rationale:** Single source of truth, version controlled, no external dependency
- **Impact:** Consistent across all fact tables, easy maintenance

---

## 🔄 Evolution & Future Enhancements

### **Potential Future Enhancements**

1. **Incremental Refresh for WorkOrderParts**
   - Reduce 10-minute refresh time
   - Requires ModifiedDate or similar field

2. **Automated Goals Calculation**
   - Generate goals from historical patterns
   - Maintain Excel as override option

3. **Tech-Level Detail Fact**
   - New fact table for individual tech analysis
   - Separate from summarized LaborJobSummary

4. **Expected Date Integration**
   - If field becomes available in source
   - Enable expected vs actual analysis

5. **Real-Time Pending Queue**
   - DirectQuery or hybrid mode
   - More frequent updates

6. **Expanded Recommendations**
   - Include parts recommendations (not just services)
   - Confidence intervals on projections

---

**Document Version:** 1.0  
**Last Major Update:** 2025-11-14  
**Next Review:** Phase 3 planning