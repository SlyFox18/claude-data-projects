# Inspections Report - Page Documentation

**Report Name:** South Plains Implement - Inspections Report  
**Last Updated:** November 2025  
**Total Pages:** 7 (5 main pages + 2 drill-through pages)

---

## 📊 Report Architecture Overview

### Page Navigation Structure
```
Home Page (Landing)
├── Details Page (Analysis)
├── Goals Page (Performance)
├── Pending Inspections (Queue Management)
└── Recommendations (Predictive Analysis)
    ├── → Work Order List (Drill-through)
    └── → Work Order Details (Drill-through)
```

### Global Filters (Available on All Pages)
- **Branch Location Slicer** - Multi-select dropdown (left sidebar)
- **Date Range** - Contextual to each page's purpose

---

## 📄 Page 1: Home Page

![Home Page](images/Inspections_Report__page_1.jpg)

### Purpose
Executive dashboard providing high-level KPI summary and goal performance tracking across all branches.

### Key Metrics (Cards)
- **Total Inspections** - Count of all completed inspections
- **Total Labor** - Sum of invoiced labor for inspections
- **Total Parts** - Sum of parts sold with inspections
- **Total Revenue** - Combined labor + parts revenue
- **Performance %** - Actual vs goal performance (color-coded: green ≥100%, red <100%)

### Visualizations

#### 1. Performance by Branch (Bar Chart)
- **Y-Axis:** Branch locations
- **X-Axis:** Inspection count with goal line overlay
- **Color:** Performance % (green/red conditional formatting)
- **Purpose:** Quick identification of branches above/below inspection goals

#### 2. Inspection Type Distribution (Donut Chart)
- **Breakdown:** Count by inspection job code category
- **Common Categories:** 
  - Tractor Inspections
  - Sprayer Inspections
  - Combine Inspections
  - Harvest Equipment Inspections
  - Winter Inspections
- **Purpose:** Understand inspection mix and seasonality

#### 3. Monthly Trend (Line Chart)
- **X-Axis:** Month
- **Y-Axis:** Inspection count
- **Purpose:** Identify seasonal patterns and trends

### Business Use Cases
- Daily executive review of branch performance
- Quick identification of underperforming locations
- High-level financial summary for management reporting
- Goal attainment tracking

---

## 📄 Page 2: Details Page

![Details Page](images/Inspections_Report__page_2.jpg)

### Purpose
Detailed analysis of inspection performance with branch and job code breakdowns, including financial metrics and discounts.

### Key Features

#### 1. Main Data Table
**Columns:**
- Branch
- Job Code
- Type (Retail/Internal/Warranty)
- Count (number of inspections)
- Parts $ Total
- Parts Discount
- Avg Part $ /Inspection
- Avg Part Discount
- Labor $ w/ Inspection
- Avg Labor w/ Inspection
- Total Labor Discount
- Avg Labor Discount
- Avg Labor & Parts
- Total $ - Discounts
- Avg % Total $ Discounted

**Key Insights:**
- Financial performance by inspection type
- Discount analysis (are we discounting too much?)
- Average ticket values per inspection type
- Profitability analysis by job code

#### 2. Branch Location Slicer
- Multi-select filter (left sidebar)
- Allows drill-down to specific branches

#### 3. Summary Row
- **Total** row at bottom showing aggregated metrics across all visible rows

### Business Use Cases
- Branch manager review of financial performance
- Identify high-value vs low-value inspection types
- Discount management and pricing strategy
- Cross-sell analysis (parts attached to inspections)

### Navigation
- Drill-through capability to Work Order List and Details pages

### Trend View (added 2026-07)

The Details page now defaults to a **rolling 24-month trend view** on open, layered on top of the existing Jobcode/Branch matrix toggle. It was requested by Casey to give a quick "where are we headed" read before drilling into the pivot tables.

**Visuals:**
- **Combined trend chart** (line chart, visual `935cc195e3ccbf08509c`) — plots `Parts $ Total (Filtered)` and `Labor $$` by `dim_DateTable[MonthYear]`, filtered to `dim_DateTable[IsRolling24Months] = True`. `MonthYear` now has `sortByColumn: SortableMonthYear` set at the model/column level (not just a visual-level sort), so it sorts chronologically everywhere it's used in the model, not only on this chart.
- **Two-stat card** (modern Card visual, `cardVisual` type, visual `976f6918c97268c9b9a1`) — a single visual container showing `Avg Parts $ / Inspection (Rolling 24)` and `Avg Labor $ / Inspection (Rolling 24)` side by side as two stat callouts (not two separate card visuals).

**Page-wide Job Code filter:** The `InspectionCategory` slicer (visual `c7a00a20c7eeb649d99b`) was built earlier and independently, at Casey's direct request, as a page-wide filter driven by the existing `InspectionCategory` calculated column. It is **not** trend-specific — it's intentionally visible and active across all three states of the page (Jobcode matrix, Branch matrix, and Trend).

**Date-filter exclusion:** The page already had an Inforiver Filter custom visual (a date-range panel, visual `be0d6015c5b591d81118`) that was found to interfere with the new trend visuals when both were active. Fix: two `NoFilter` entries were added to `page.json`'s `visualInteractions` (via Power BI Desktop's Edit Interactions feature) — from `be0d6015c5b591d81118` to the line chart and to the card — so the trend visuals ignore that date panel while the pivot tables continue to respond to it normally.

**Show/Hide Trend toggle (layers with the Jobcode/Branch toggle):** Two independent bookmark pairs now control this page:
- `Matrix - Jobcode` / `Matrix - Branch` (pre-existing, extended) — toggles which pivot table is shown, driven by "Button - Jobcode" / "Button - Branch"
- `Show Trend Chart` / `Hide Trend Chart` (new) — toggles the trend chart/card overlay, driven by two new action buttons: `e15e719cd9f592bf1e0f` (shown when Trend is not active — click to show it) and `b53865ec704bf4af41ae` (shown when Trend is active — click to hide it)

When Trend is showing, both pivot tables (`1401aa2e094056908a34` Jobcode, `bd2912d19640de5c6eca` Branch) and both matrix-switch buttons ("Button - Jobcode", "Button - Branch") are hidden, so the two toggle systems don't visually collide. **Known minor quirk:** "Hide Trend Chart" always returns to the Branch matrix specifically, not whichever of Jobcode/Branch was showing before Trend was opened — this is a known limitation, not a bug, and may be revisited.

**Default landing state:** Opening the Details page (before any bookmark is applied) now shows the **Trend view first**, not a pivot table — both pivot tables and "Button - Jobcode" default to `isHidden: true` at the base visual level. This is a deliberate, if not-yet-final, choice so Casey sees the trend chart immediately on page load.

---

## 📄 Page 3: Goals Page

![Goals Page](images/Inspections_Report__page_3.jpg)

### Purpose
Track branch performance against inspection goals with visual indicators for management review.

### Key Visualizations

#### 1. Performance Matrix (Table)
**Columns:**
- **Branch** - Location name
- **Goal** - Target number of inspections
- **Actual** - Completed inspections
- **Performance %** - (Actual / Goal) × 100
- **Status Indicator** - Visual icon/color coding

**Color Coding:**
- 🟢 Green: ≥100% (meeting/exceeding goal)
- 🟡 Yellow: 90-99% (close to goal)
- 🔴 Red: <90% (below goal threshold)

#### 2. Performance Gauge/Bar Chart
- Visual representation of each branch's progress toward goal
- Sorted by performance % (lowest to highest or highest to lowest)

### Goal Source
- Goals imported from Excel file "Inspection Goals"
- Joined on: `LOCATION → dim_BranchLocation.LocationID`
- Updated: Monthly or quarterly (per management)

### Business Use Cases
- Monthly/quarterly performance reviews
- Branch manager accountability
- Bonus calculation support
- Strategic planning for underperforming locations

### Filters
- Date range (to view performance over different periods)
- Branch location slicer

---

## 📄 Page 4: Pending Inspections

![Pending Inspections](images/Inspections_Report__page_4.jpg)

### Purpose
Real-time queue management for work orders with pending inspection codes, prioritized by aging and revenue potential.

### Data Source
- **Fact_PendingInspections** (1:30 min refresh)
- Captures work orders with inspection codes but no completed labor

#### 1. Pending Inspections - WIP (Summary Bar Chart)
**Visualization:**
- **Y-Axis:** Inspection job code
- **X-Axis:** Count of pending work orders
- **Sort:** Descending by count

**Purpose:** 
- Quick identification of which inspection types have the largest backlog
- Resource allocation planning

#### 2. Detailed Work Order Table
**Columns:**
- **Branch** - Location number/name
- **Job Code** - Inspection type
- **RO Number** - Repair order identifier
- **Creation Date** - When work order was created
- **Last Labor Punch** - Most recent activity timestamp
- **Hours Worked** - Labor hours logged so far

**Color Coding:**
- 🔴 Red highlight: `Last Labor Punch = 1/1/1900` (no recent activity - stale work order)
- 🟡 Orange highlight: Older creation dates (aging work orders)
- ⚪ White: Recent activity

**Sort:** Default by Creation Date (oldest first) to highlight aged work orders

### Key Business Metrics
- **Total Hours Worked:** 851.4 (shown at bottom of table)
- Average age of pending inspections
- Branches with highest pending counts

### Business Use Cases
- Daily shop floor management
- Prioritize which inspections to complete
- Identify stale work orders requiring follow-up
- Capacity planning (how much inspection backlog exists?)
- Customer communication (when will my inspection be done?)

### Critical Insight
- Red-highlighted rows (1/1/1900 date) indicate work orders created but never started - require immediate attention

---

## 📄 Page 5: Recommendations

![Recommendations](images/Inspections_Report__page_5.jpg)

### Purpose
**Predictive analytics** - Suggest additional services commonly performed with specific inspection types to increase revenue capture.

### Data Source
- **ServiceRecommendations** (Calculated DAX Table)
- Logic: For each pending inspection type, analyze historical completed inspections to identify frequently added services

### Algorithm Logic
```
For each pending inspection code:
1. Find all completed work orders with this inspection
2. Identify other services performed on those work orders
3. Calculate:
   - TimesAdded: How many times this service was added
   - CompletedInspections: Total inspections of this type
   - Frequency %: (TimesAdded / CompletedInspections) × 100
   - TotalLabor: Revenue generated by this service
```

### Visualization

#### Recommendations Table
**Columns:**
- **Inspection Type** - Pending inspection job code
- **Recommended Service** - Job code frequently performed with this inspection
- **Frequency %** - How often this service is added
- **Times Added** - Count of occurrences
- **Total Labor $** - Revenue from this service historically
- **Avg Labor $** - Average revenue per occurrence

**Example:**
```
Inspection: IS-TRACTOR INSPECT
Recommended: LUBRICATE IMPLEMENT → 73% frequency, $2,850 total labor
```

### Business Use Cases
- **Proactive Service Selling:** When customer comes in for inspection, recommend high-frequency services
- **Advisor Training:** Teach service advisors what to look for with each inspection type
- **Revenue Optimization:** Don't miss common repair opportunities
- **Parts Pre-staging:** Stock commonly needed parts for inspections
- **Technician Training:** Pattern recognition for inspection-related issues

### Strategic Value
This is **predictive analytics in action** - using historical data to drive future revenue. This page turns data into actionable selling strategies.

---

## 📄 Page 6: Work Order List (Drill-Through)

![Work Order List](images/Inspections_Report__page_6.jpg)

### Purpose
Drill-through page showing individual work orders with inspection and service job codes.

### Access Method
- **Drill through** from Details Page or other analysis pages
- Right-click on a data point → "Drill through" → "Work Order List"

### Table Structure
**Columns:**
- **RO Number** - Work order identifier
- **Branch** - Location
- **Customer** - Customer name
- **Inspection Job Code** - Primary inspection type
- **Service Job Codes** - Other services performed (comma-separated if multiple)
- **Labor $** - Total labor amount
- **Parts $** - Total parts amount
- **Total $** - Labor + Parts
- **Date** - Work order completion date

### Business Use Cases
- Audit specific work orders
- Verify inspection + service combinations
- Quality control review
- Invoice verification
- Customer dispute resolution

### Filters Passed Through
When drilling through, context filters are maintained:
- Branch selection
- Date range
- Job code selection (if applicable)

---

## 📄 Page 7: Work Order Details (Drill-Through)

![Work Order Details](images/Inspections_Report__page_7.jpg)

### Purpose
Most detailed drill-through page showing line-by-line breakdown of a specific work order.

### Access Method
- **Drill through** from Work Order List page
- Right-click on specific RO Number → "Drill through" → "Work Order Details"

### Detail Table
**Columns:**
- **Line Number** - Sequence on work order
- **Job Code** - Specific job/service code
- **Description** - Job description
- **Labor Hours** - Time spent
- **Labor Rate** - Hourly rate
- **Labor Amount** - Hours × Rate
- **Part Number** - If parts used
- **Part Description** - Part name
- **Quantity** - Parts quantity
- **Part Price** - Unit price
- **Part Amount** - Quantity × Price
- **Line Total** - Labor + Parts for this line

### Summary Metrics (Top Cards)
- **RO Number**
- **Customer Name**
- **Branch**
- **Total Labor $**
- **Total Parts $**
- **Grand Total $**
- **Completion Date**

### Business Use Cases
- Deep dive into specific work order profitability
- Verify technician time allocations
- Parts usage analysis
- Customer billing questions
- Identify inefficient job code usage
- Training opportunities (did tech use correct codes?)

### Navigation
- **Back button** to return to previous page
- Maintains all context filters

---

## 🔄 Report Refresh Schedule

### Automatic Refresh
- **Frequency:** Scheduled refresh in Power BI Service
- **Timing:** Daily at 6:00 AM CST (recommended)
- **Total Refresh Time:** ~14.5 minutes
  - Fact_LaborJobSummary: 3 min
  - Fact_PendingInspections: 1.5 min
  - Fact_WorkOrderParts: 10 min

### Manual Refresh
- Available in Power BI Desktop: Home → Refresh
- Should complete in under 15 minutes

---

## 🎯 Cross-Page Interactions

### Filter Context Flow
1. **Global Filters** (Branch, Date) persist across all pages
2. **Drill-through** pages inherit parent page filters
3. **Back navigation** returns to previous page with filters intact

### Drill-Through Paths
```
Details Page
    └─→ Work Order List
            └─→ Work Order Details

Recommendations Page
    └─→ Work Order List
            └─→ Work Order Details
```

---

## 📈 Performance Optimization Notes

### Why This Performs Well
1. **Pre-aggregated fact tables** - Heavy lifting done at data refresh
2. **Star schema** - Clean relationships, efficient filtering
3. **Calculated tables** (ServiceRecommendations) - Generated at refresh, not runtime
4. **Minimal complex visuals** - Tables and simple charts load fast
5. **Aggregations at grain** - No row-by-row calculations in visuals

### Capacity Unit (CU) Monitoring
- **Fact_WorkOrderParts** taking 10 minutes - monitor this
- If CU usage spikes, consider:
  - Incremental refresh strategy
  - Further pre-aggregation
  - Partition optimization

---

## 🎓 User Training Recommendations

### For Service Advisors
- **Page 4 (Pending Inspections):** Daily queue management
- **Page 5 (Recommendations):** Selling strategies
- Focus: Revenue generation through service recommendations

### For Shop Managers
- **Page 1 (Home):** Daily KPI review
- **Page 3 (Goals):** Performance tracking
- **Page 4 (Pending):** Shop capacity management
- Focus: Operations efficiency

### For Branch Managers
- **Page 2 (Details):** Financial analysis
- **Page 3 (Goals):** Performance accountability
- Focus: Branch profitability and goal attainment

### For Executives
- **Page 1 (Home):** Executive summary
- **Page 3 (Goals):** Multi-branch comparison
- Focus: Strategic oversight

---

## 🔐 Row-Level Security (If Applicable)

### Current State
- Report shows all branches (no RLS implemented)

### Future Consideration
If branch managers should only see their own branch:
1. Create security roles in Power BI
2. Filter on `dim_BranchLocation[LocationID]`
3. Map users to branches
4. Deploy RLS in Power BI Service

---

## 📞 Support & Questions

### For Report Issues
- Contact: [Your Name/Data Team]
- Documentation: See `README.md` and `ARCHITECTURE.md`

### For Data Issues
- Check source system (Fusion/ERP)
- Verify data refresh status
- Review error logs in Power BI Service

### For Enhancement Requests
- Submit via [your process - GitHub issues, email, etc.]
- Document: Business need, proposed solution, expected value

---

**End of Report Documentation**