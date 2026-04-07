# Technical Reference - Open Parts Tickets Report

**Report Name**: Open Parts Tickets
**Version**: 2.0 (Modernized Star Schema)
**Last Updated**: January 8, 2026
**Platform**: Microsoft Fabric (F4 Capacity)
**Author**: B.Fox with Claude Code Assistant

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Data Model](#data-model)
3. [Fact Tables](#fact-tables)
4. [Dimension Tables](#dimension-tables)
5. [Relationships](#relationships)
6. [DAX Measures](#dax-measures)
7. [Data Refresh Architecture](#data-refresh-architecture)
8. [Performance Optimization](#performance-optimization)
9. [Security & Access](#security--access)
10. [Dependencies](#dependencies)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Microsoft Fabric Workspace                  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ LH_Master_Data Lakehouse (Data Warehouse)                 │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │ SQL Views (Data Layer)                               │ │  │
│  │  │  • vw_Fact_Parts_Open_Tickets (V2 - Fixed)           │ │  │
│  │  │  • vw_Fact_Parts_Open_Tickets_Details                │ │  │
│  │  │  • dim_BranchLocation                                │ │  │
│  │  │  • dim_DateTable                                     │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ▲                                   │
│                              │ SQL Connection (Import Mode)      │
│                              │                                   │
│  ┌───────────────────────────┴───────────────────────────────┐  │
│  │ Open Parts Tickets.SemanticModel                        │  │
│  │                                                            │  │
│  │  • Fact_Parts_Open_Tickets (1,121 orders)                 │  │
│  │  • Fact_Parts_Open_Tickets_Details (line items)           │  │
│  │  • dim_BranchLocation (branches)                          │  │
│  │  • dim_DateTable (date dimension)                         │  │
│  │  • TopN Selector (disconnected table)                     │  │
│  │  • 35 DAX Measures                                        │  │
│  │  • 3 Relationships                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ▲                                   │
│                              │                                   │
│  ┌───────────────────────────┴───────────────────────────────┐  │
│  │ Open Parts Tickets.Report                               │  │
│  │                                                            │  │
│  │  • Page 1: Overview (Aging Matrix + KPIs)                 │  │
│  │  • Page 2: Details (Line Item Table)                      │  │
│  │  • Page 3: Comparison (Branch/Customer/Salesman)          │  │
│  │  • Page 4: Score Card (Charts & Trends)                   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Star Schema Architecture**: Optimized for analytical queries with clear fact and dimension separation
2. **Import Mode**: Data cached in semantic model for fast query performance
3. **Single Source of Truth**: All calculations performed in DAX measures (no calculated columns)
4. **Incremental Refresh Ready**: Fact tables partitioned by Order_Date for efficient refresh
5. **F4 Capacity Optimized**: Designed to minimize CU consumption and refresh time

---

## Data Model

### Model Diagram (Text Representation)

```
┌──────────────────────────┐
│ dim_BranchLocation       │
│ (Dimension)              │
├──────────────────────────┤
│ PK: BranchID            │
│     Branch              │
│     Location_Name       │
│     ... (branch attrs)  │
└──────────────┬───────────┘
               │
               │ 1:* (BranchID → Location)
               │
┌──────────────▼───────────┐          ┌─────────────────────────┐
│ Fact_Parts_Open_Tickets  │          │ dim_DateTable           │
│ (Fact - Order Summary)   │          │ (Dimension)             │
├──────────────────────────┤          ├─────────────────────────┤
│ PK: Order_No            │◄─────────┤ PK: Date               │
│ FK: Location            │  1:*     │     Year, Quarter       │
│ FK: Order_Date          │          │     Month, Day          │
│                         │          │     ... (time attrs)    │
│ Order_Total_$$          │          └─────────────────────────┘
│ #_Parts_On_Order        │                     ▲
│ #_On_Back_Order         │                     │
│ $$_Available            │                     │ 1:* (Date → Order_Date)
│ $$_BackOrdered          │                     │
│ Days_Open               │          ┌──────────┴──────────────┐
│ Aging                   │          │ Fact_Parts_Open_        │
│ Customer                │          │ Tickets_Details         │
│ Salesman                │          │ (Fact - Line Items)     │
│ ... (order attrs)       │          ├─────────────────────────┤
└──────────────┬───────────┘          │ FK: Order_No           │
               │                      │ FK: Location           │
               │ 1:* (Order_No)       │ FK: Order_Date         │
               │                      │                         │
               └──────────────────────┤ Part_No                │
                                      │ Quantity_Ordered       │
                                      │ BackOrdered_QTY        │
                                      │ Unit_Price             │
                                      │ Line_Total             │
                                      │ ... (line attrs)       │
                                      └─────────────────────────┘

┌─────────────────────────┐
│ TopN Selector           │
│ (Disconnected)          │
├─────────────────────────┤
│ TopN (5,10,15,20,-1)   │
│ Label (Top 5, All...)  │
│ SortOrder              │
└─────────────────────────┘
```

### Cardinality Summary

| Relationship | From Table | From Column | To Table | To Column | Cardinality | Active |
|--------------|-----------|-------------|----------|-----------|-------------|--------|
| 1 | Fact_Parts_Open_Tickets_Details | Order_No | Fact_Parts_Open_Tickets | Order_No | Many-to-One | ✓ |
| 2 | Fact_Parts_Open_Tickets | Location | dim_BranchLocation | BranchID | Many-to-One | ✓ |
| 3 | Fact_Parts_Open_Tickets | Order_Date | dim_DateTable | Date | Many-to-One | ✓ |

**Note**: TopN Selector is a disconnected table (no relationships) used for slicer-based filtering

---

## Fact Tables

### Fact_Parts_Open_Tickets (Order Summary Level)

**Purpose**: One row per order, containing aggregated order-level metrics

**Grain**: One row per unique order (Order_No)

**Source**: `LH_Master_Data.dbo.vw_Fact_Parts_Open_Tickets` (V2 - Fixed as of Jan 7, 2026)

**Key Business Rules**:
- Orders with different deposit amounts are kept as separate rows (fixed in V2)
- Work Orders age from RepairOrderDetail.CreationDate when available, with fallback to Created_On or Order_Date
- Aging buckets calculated using proper date logic (fixed in V2)

**Columns** (21 total):

| Column Name | Data Type | Description | Business Logic |
|------------|-----------|-------------|----------------|
| **Location** | String | Branch ID (FK to dim_BranchLocation) | Identifies which branch owns this order |
| **Location_Name** | String | Branch display name | Denormalized for convenience |
| **Order_No** | Integer | Primary Key - Unique order identifier | RONumber when available, else FileNumber |
| **Invoice_Type** | String | Order type (Work Order, Pending Ticket, Quote, etc.) | Determines aging logic |
| **Order_Date** | Date | Date order was placed | Used as final fallback for aging |
| **Created_On** | Date | Date order entered in system | Used for aging (most order types) |
| **WO_Creation_Date** | Date | Work Order creation date from RepairOrderDetail | Primary aging date for Work Orders |
| **Days_Open** | Integer | Days between aging base date and today | Calculated in SQL view |
| **Aging** | String | Aging bucket (0-7, 8-14, 15-30, 31-60, 61-90, 90+ days) | Text representation, sorted by Aging_Sort_Order |
| **Aging_Sort_Order** | Integer | Numeric sort for Aging (1-6) | Used to sort Aging column |
| **Aging_Date_Source** | String | Which date was used for aging | 'WO_Creation_Date', 'Created_On', or 'Order_Date' |
| **Aging_Base_Date** | Date | Actual date used for aging calculation | Diagnostic column added in V2 |
| **#_Parts_On_Order** | Number | Total quantity of parts on this order | Sum from detail lines |
| **#_On_Back_Order** | Number | Total quantity on backorder | Sum from detail lines |
| **Order_Total_$$** | Currency | Total dollar amount of order | Sum of line totals |
| **$$_Available** | Currency | Dollar amount not on backorder | Order_Total - $$_BackOrdered |
| **$$_BackOrdered** | Currency | Dollar amount on backorder | Calculated from backordered items |
| **Backorder_Pct** | Decimal | Percentage of order on backorder | $$_BackOrdered / Order_Total |
| **Deposit** | Currency | Deposit amount paid | **CRITICAL**: Must be in GROUP BY (V2 fix) |
| **Salesman** | String | Salesperson assigned to order | Used for salesman rankings |
| **Contact_Code** | String | Contact code | Additional filter dimension |
| **AR_Acct** | Integer | Accounts Receivable account | Financial reference |
| **Customer** | String | Customer name | Used for customer rankings |

**Refresh Strategy**:
- **Mode**: Import (cached)
- **Schedule**: 6:00 AM, 1:00 PM daily
- **Incremental Refresh**: Partition by Order_Date, refresh last 30 days
- **Full Refresh**: Quarterly

**Known Issues (Resolved)**:
- ✅ V1 Bug: Missing Deposit in GROUP BY caused incorrect aggregation (21 missing orders)
- ✅ V1 Bug: Incorrect aging logic for Work Orders without RepairOrderDetail
- ✅ V2 Fix: Applied January 7, 2026

---

### Fact_Parts_Open_Tickets_Details (Line Item Level)

**Purpose**: One row per part per order, containing detailed line-level information

**Grain**: One row per part on an order (Part_No within Order_No)

**Source**: `LH_Master_Data.dbo.vw_Fact_Parts_Open_Tickets_Details`

**Key Business Rules**:
- Each part line can have its own backorder status
- Total quantities and dollars roll up to Fact_Parts_Open_Tickets
- Joins to Fact_Parts_Open_Tickets via Order_No for order-level attributes

**Columns** (21 total):

| Column Name | Data Type | Description | Business Logic |
|------------|-----------|-------------|----------------|
| **Location** | String | Branch ID (FK to dim_BranchLocation) | Same as parent order |
| **Location_Name** | String | Branch display name | Denormalized |
| **Order_No** | Integer | FK to Fact_Parts_Open_Tickets | Links to order summary |
| **RO_Number** | Integer | Repair Order number | For Work Orders |
| **File_No** | Integer | File number | Alternative order identifier |
| **Invoice_Type** | String | Order type | Duplicated from parent for convenience |
| **Order_Date** | Date | Order date (FK to dim_DateTable) | Duplicated from parent |
| **Created_On** | Date | Created date | Duplicated from parent |
| **WO_Creation_Date** | Date | Work Order creation date | Duplicated from parent |
| **Days_Open** | Integer | Days open | Duplicated from parent |
| **Aging** | String | Aging bucket | Duplicated from parent |
| **Aging_Sort_Order** | Integer | Aging sort | Duplicated from parent |
| **Aging_Date_Source** | String | Date source indicator | Duplicated from parent |
| **Part_No** | String | Part number | Primary attribute at detail level |
| **Quantity_Ordered** | Number | Quantity of this part ordered | Line-level quantity |
| **Unit_Price** | Currency | Price per unit | Line-level pricing |
| **Line_Total** | Currency | Total for this line | Quantity * Unit_Price |
| **BackOrdered_QTY** | Number | Quantity on backorder for this part | 0 if available |
| **Available_QTY** | Number | Quantity available (not backordered) | Quantity - BackOrdered_QTY |
| **Line_Backorder_Pct** | Decimal | Percentage of line on backorder | BackOrdered_QTY / Quantity |
| **Contact_Code** | String | Contact code | Duplicated from parent |
| **Customer** | String | Customer name | Duplicated from parent |
| **Salesman** | String | Salesman | Duplicated from parent |

**Usage**:
- **Backordered Line Count** measure uses this table to count lines with BackOrdered_QTY > 0
- **Parts Line Count** measure counts Part_No from this table
- Detail page shows all columns in table visual
- Relationships to parent order enable filtering both ways

**Refresh Strategy**:
- **Mode**: Import (cached)
- **Schedule**: Same as Fact_Parts_Open_Tickets (6 AM, 1 PM)
- **Incremental Refresh**: Partition by Order_Date

---

## Dimension Tables

### dim_BranchLocation

**Purpose**: Branch master data for filtering and grouping

**Grain**: One row per branch location

**Source**: `LH_Master_Data.dbo.dim_BranchLocation`

**Key Business Rules**:
- Slowly Changing Dimension (Type 1 - overwrite)
- Branch codes are standardized across all systems

**Columns**:

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| **BranchID** | String | Primary Key - Branch identifier |
| **Branch** | String | Branch display name |
| **Location_Name** | String | Full location name |
| ... | ... | (Additional branch attributes) |

**Usage**:
- Slicer for filtering by branch
- Branch comparison matrix rows
- Location hierarchy (if implemented)

---

### dim_DateTable

**Purpose**: Complete date dimension for time-based analysis

**Grain**: One row per date

**Source**: Generated date table (likely DAX or SQL)

**Key Business Rules**:
- Covers full range of order dates plus historical comparison range
- Enables time intelligence functions

**Columns**:

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| **Date** | Date | Primary Key - Date value |
| **Year** | Integer | Year (YYYY) |
| **Quarter** | Integer | Quarter (1-4) |
| **Month** | Integer | Month (1-12) |
| **MonthName** | String | Month name (January, February...) |
| **Day** | Integer | Day of month (1-31) |
| **DayOfWeek** | Integer | Day of week (1-7) |
| **DayName** | String | Day name (Monday, Tuesday...) |
| **IsWeekend** | Boolean | True if Saturday/Sunday |
| **FiscalYear** | Integer | Fiscal year (if applicable) |
| **FiscalQuarter** | Integer | Fiscal quarter (if applicable) |

**Usage**:
- Order Date slicer with date range picker
- Time intelligence measures (Same Period Last Year)
- Trend charts over time
- Aging calculations base reference

---

### TopN Selector (Disconnected Table)

**Purpose**: Enables dynamic Top N filtering for customer and salesman rankings

**Grain**: One row per Top N option

**Source**: DAX calculated table (DATATABLE function)

**Definition**:
```dax
DATATABLE(
    "TopN", INTEGER,
    "Label", STRING,
    "SortOrder", INTEGER,
    {
        {5,  "Top 5",    1},
        {10, "Top 10",   2},
        {15, "Top 15",   3},
        {20, "Top 20",   4},
        {25, "Top 25",   5},
        {-1, "Show All", 6}
    }
)
```

**Columns**:

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| **TopN** | Integer | Number of top items to show (-1 = all) |
| **Label** | String | Display label for slicer |
| **SortOrder** | Integer | Ensures proper sort order in slicer |

**Usage**:
- Slicer on Comparison page
- Used by measures: `Selected Top N`, `Filtered Order Count`, `Filtered Order Total`, etc.
- Filters customer and salesman ranking tables based on user selection

---

## Relationships

### Relationship 1: Details to Summary

**From**: `Fact_Parts_Open_Tickets_Details[Order_No]`
**To**: `Fact_Parts_Open_Tickets[Order_No]`
**Cardinality**: Many-to-One
**Cross Filter Direction**: Single (Details → Summary)
**Active**: Yes

**Purpose**: Links line items to their parent order for aggregation and filtering

**Use Cases**:
- Drill-through from Overview page to Details page
- Backordered Line Count calculation (filter detail table, count rows)
- Parts Line Count calculation

---

### Relationship 2: Orders to Branch

**From**: `Fact_Parts_Open_Tickets[Location]`
**To**: `dim_BranchLocation[BranchID]`
**Cardinality**: Many-to-One
**Cross Filter Direction**: Single (Facts → Dimension)
**Active**: Yes

**Purpose**: Enables filtering and grouping by branch

**Use Cases**:
- Branch slicer filtering
- Branch comparison matrix
- Location-based KPIs

---

### Relationship 3: Orders to Date

**From**: `Fact_Parts_Open_Tickets[Order_Date]`
**To**: `dim_DateTable[Date]`
**Cardinality**: Many-to-One
**Cross Filter Direction**: Single (Facts → Dimension)
**Active**: Yes

**Purpose**: Enables time-based filtering and time intelligence

**Use Cases**:
- Order Date slicer
- Time intelligence (Same Period Last Year)
- Trend analysis over time
- Year/Quarter/Month hierarchies

---

## DAX Measures

### Measure Organization

Measures are organized into **display folders** for easy navigation:

1. **Core Metrics** (14 measures): Basic business calculations
2. **Percentages** (3 measures): Percentage-based KPIs
3. **Customer Analysis** (9 measures): Customer ranking and filtering
4. **Salesman Analysis** (6 measures): Salesman ranking and filtering
5. **Time Intelligence** (1 measure): Year-over-year comparisons
6. **UI & Navigation** (4 measures): Header SVG measures for pages
7. **KPI Visuals** (Multiple SVG measures): Visual KPI cards

### Measure Dependencies

```
Core Metrics (Foundation Layer)
    ├─ # Parts On Order
    ├─ Order Total
    ├─ $$ not BO
    ├─ # on Back Order
    ├─ Backordered $$
    ├─ Order Count
    └─ Parts Line Count
              │
              ├──> Percentages (Derived Layer)
              │      ├─ % of Parts on Back Order (uses # on Back Order, # Parts On Order)
              │      ├─ % # of Parts by line count (uses Parts Line Count, # Parts On Order)
              │      └─ % # Backordered by Line Count (uses Backordered Line Count, # on Back Order)
              │
              ├──> Customer Analysis (Advanced Layer)
              │      ├─ Selected Top N (base measure)
              │      ├─ Customer Rank - Order Count (uses Order Count)
              │      ├─ Customer Rank - Order Total (uses Order Total)
              │      ├─ Filtered Order Count (uses Customer Rank, Selected Top N)
              │      └─ Filtered Order Total (uses Customer Rank, Order Total, Selected Top N)
              │
              └──> Salesman Analysis (Advanced Layer)
                     ├─ Salesman Rank - Order Count (uses Order Count)
                     ├─ Salesman Rank - Order Total (uses Order Total)
                     ├─ Filtered Order Count - Salesman (uses Salesman Rank, Selected Top N)
                     └─ Filtered Order Total - Salesman (uses Salesman Rank, Order Total, Selected Top N)
```

### Core Metrics (14 measures)

| Measure Name | Formula Pattern | Format | Usage |
|-------------|----------------|---------|-------|
| `# Parts On Order` | `SUM(Fact_Parts_Open_Tickets[#_Parts_On_Order])` | `0` | Total parts quantity ordered |
| `Order Total` | `SUM(Fact_Parts_Open_Tickets[Order_Total_$$])` | `$#,0.00` | Total dollar value of all orders |
| `$$ not BO` | `SUM(Fact_Parts_Open_Tickets[$$_Available])` | `$#,0.00` | Dollar value not on backorder |
| `Deposit` | `SUM(Fact_Parts_Open_Tickets[Deposit])` | `$#,0.00` | Total deposits collected |
| `# on Back Order` | `SUM(Fact_Parts_Open_Tickets[#_On_Back_Order])` | `0` | Quantity on backorder |
| `Backordered $$` | `SUM(Fact_Parts_Open_Tickets[$$_BackOrdered])` | `$#,0.00` | Dollar value on backorder |
| `Backordered Line Count` | `CALCULATE(COUNTROWS(...), BackOrdered_QTY > 0)` | `0` | Count of backordered line items |
| `Parts Line Count` | `COUNT(Fact_Parts_Open_Tickets_Details[Part_No])` | `0` | Total number of part lines |
| `Line Count` | `COUNT(Fact_Parts_Open_Tickets_Details[Part_No])` | `0` | Synonym for Parts Line Count |
| `Order Count` | `COUNTROWS(Fact_Parts_Open_Tickets)` | `0` | Total number of orders |
| `Total # of Orders` | `COUNTROWS(Fact_Parts_Open_Tickets)` | `0` | Synonym for Order Count |
| `Orders with Backordered Parts` | `CALCULATE(COUNTROWS(...), #_On_Back_Order > 0)` | `0` | Count of orders with backorders |
| `Average Days Open` | `AVERAGE(Fact_Parts_Open_Tickets[Days_Open])` | Auto | Average aging across all orders |
| `Total Backorder Impact` | `SUM(Fact_Parts_Open_Tickets[$$_BackOrdered])` | `$#,0.00` | Synonym for Backordered $$ |

### Customer Analysis Measures (9 measures)

| Measure Name | Purpose | Key Logic |
|-------------|---------|-----------|
| `Selected Top N` | Retrieves user's Top N selection | `SELECTEDVALUE('TopN Selector'[TopN], -1)` |
| `Customer Rank - Order Count` | Ranks customers by order count | `RANKX(ALL(...[Customer]), COUNT(...[Order_No]), DESC)` |
| `Customer Rank - Order Total` | Ranks customers by order dollars | `RANKX(ALL(...[Customer]), [Order Total], DESC)` |
| `Filtered Order Count` | Shows order count only for Top N customers | Uses `IF([Customer Rank] <= [Selected Top N])` |
| `Filtered Order Total` | Shows order total only for Top N customers | Uses `IF([Customer Rank] <= [Selected Top N])` |
| `Order Count 1` | Helper measure for customer ranking | `CALCULATE(COUNT(...[Order_No]))` |
| `Customer Rank` | Alternative ranking logic | Uses ADDCOLUMNS + RANKX |
| `Is In Top N` | Boolean flag for Top N filter | Returns TRUE/FALSE |
| `Bar Color Hex - Customer Count` | Conditional formatting for customer table | Returns color hex based on max/min |
| `Bar Color Hex - Customer Total` | Conditional formatting for customer totals | Returns 0 or 1 for highlighting |

### Salesman Analysis Measures (6 measures)

Same pattern as Customer Analysis, applied to Salesman dimension:
- `Salesman Rank - Order Count`
- `Salesman Rank - Order Total`
- `Filtered Order Count - Salesman`
- `Filtered Order Total - Salesman`
- `Bar Color Hex - Salesman Count`
- `Bar Color Hex - Salesman Total`

### Time Intelligence Measures (1 measure)

| Measure Name | Formula | Purpose |
|-------------|---------|---------|
| `Order Total Same Period Last Year` | `CALCULATE([Order Total], SAMEPERIODLASTYEAR(...[Order_Date]))` | Year-over-year comparison |

### UI & Navigation Measures (4 measures)

SVG-based headers for each page:
- `Home - Header` - Overview page header
- `Page 2 - Details - Header` - Details page header
- `Page 3 - Comparison - Header` - Comparison page header
- `Page 4 - Score Card - Header` - Score Card page header

**Features**:
- Dynamic greeting based on time of day
- Displays current user name (formatted)
- Shows current date
- Gradient background styling
- Responsive SVG design

### KPI Visual Measures

Complex SVG measures that create visual KPI cards:
- `KPI SVG - Parts On Order vs Back Order (Modern)` - Visual comparison of parts on order vs backordered

**Note**: Additional SVG KPI measures can be added from old report if desired (4 optional measures documented in DAX-MEASURES-REFERENCE.md)

---

## Data Refresh Architecture

### Refresh Flow

```
┌────────────────────────────────────────────────────────┐
│ 1. Fabric Pipeline Trigger                            │
│    • Scheduled: 6:00 AM, 1:00 PM daily                 │
│    • Manual: On-demand from Fabric workspace          │
└──────────────────┬─────────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────┐
│ 2. SQL Views Refresh (if materialized)                │
│    • vw_Fact_Parts_Open_Tickets (V2)                   │
│    • vw_Fact_Parts_Open_Tickets_Details                │
│    • Views query source tables:                        │
│      - Insalord (orders)                               │
│      - Insalpar (parts)                                │
│      - RepairOrderDetail (work orders)                 │
│      - Customer, Salesperson (lookups)                 │
└──────────────────┬─────────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────┐
│ 3. Semantic Model Refresh                             │
│    • Import Mode: Full data load                       │
│    • Incremental Refresh (if enabled):                │
│      - Last 30 days of Order_Date                      │
│      - Historical data cached                          │
│    • Dimension tables refresh (full)                   │
└──────────────────┬─────────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────┐
│ 4. Report Cache Clear                                  │
│    • Visual caches invalidated                         │
│    • Users see refreshed data on next load             │
└────────────────────────────────────────────────────────┘
```

### Refresh Configuration

**Current Mode**: Import (full refresh each time)

**Recommended Enhancement**: Incremental Refresh

```
Partition Strategy:
  • Partition by: Order_Date
  • Incremental range: Last 30 days
  • Historical range: All prior data
  • Full refresh frequency: Quarterly
```

**Benefits of Incremental Refresh**:
- Reduces refresh time by ~70%
- Minimizes CU consumption on F4 capacity
- Enables more frequent updates without performance impact

**To Enable Incremental Refresh**:
1. Open Power BI Desktop
2. Select Fact_Parts_Open_Tickets table
3. Right-click → Incremental Refresh
4. Configure:
   - Archive data starting: 2 years ago
   - Incrementally refresh data starting: 30 days ago
   - Detect data changes: No (use append-only mode)
5. Publish to Fabric
6. Configure refresh schedule in workspace

---

## Performance Optimization

### Current Optimizations

**1. Star Schema Design**
- Clear separation of facts and dimensions
- Optimized join paths
- Minimized relationship complexity

**2. Import Mode Benefits**
- All data cached in memory (VertiPaq compression)
- No query latency to source database
- Fast aggregation engine

**3. Measure-Based Calculations**
- No calculated columns (avoid row context overhead)
- All calculations in DAX measures (evaluated at query time)
- Uses aggregation engine for optimal performance

**4. Proper Data Types**
- Currency columns as Double (not Decimal for VertiPaq compression)
- Date columns as Date (not DateTime when time not needed)
- Integer IDs where appropriate

**5. Sort By Column Configuration**
- `Aging` sorted by `Aging_Sort_Order` (numeric sort)
- `TopN Selector[Label]` sorted by `SortOrder`

### Performance Targets (F4 Capacity)

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Refresh Time | < 5 minutes | TBD | ⏳ Monitor after deployment |
| Report Load Time | < 3 seconds | TBD | ⏳ Monitor after deployment |
| Visual Render Time | < 1 second | TBD | ⏳ Monitor after deployment |
| Visual Count per Page | ≤ 10 visuals | Compliant | ✅ |
| Detail Table Row Limit | 1000 rows (with "See more") | Configurable | ✅ |

### Optimization Recommendations

**If Refresh Time > 5 minutes**:
1. Enable incremental refresh (partition by Order_Date)
2. Consider aggregation tables for frequently-used summaries
3. Review SQL view performance (check execution plans)
4. Ensure source tables have proper indexes

**If Report Load Time > 3 seconds**:
1. Reduce visual count per page
2. Use page-level or report-level filters instead of visual-level
3. Implement bookmarks for common filter states
4. Consider DirectQuery for very large datasets (trade-off: slower queries)

**If Visual Render Time > 1 second**:
1. Limit detail tables to 1000 rows initially (use "See more")
2. Simplify complex DAX measures
3. Use Top N filters on ranking tables
4. Avoid overly complex SVG measures if performance issues

---

## Security & Access

### Row-Level Security (RLS)

**Current State**: No RLS implemented

**Recommended RLS Strategy** (if needed):

```dax
-- Role: Branch Users
-- Filter: dim_BranchLocation[BranchID]
[BranchID] = USERPRINCIPALNAME()
-- OR using security table lookup
[BranchID] IN
  VALUES(UserBranchAccess[BranchID])
  WHERE UserBranchAccess[UserEmail] = USERPRINCIPALNAME()
```

**RLS Considerations**:
- Impacts on performance (additional filter context)
- Testing required for each role
- May need separate security dimension table

### Workspace Permissions

**Fabric Workspace Roles**:
- **Admin**: Full control (refresh, publish, share)
- **Member**: Can refresh and publish
- **Contributor**: Can view and create content
- **Viewer**: Read-only access to reports

**Recommendation**:
- Report viewers: Viewer role
- Report developers: Member or Contributor
- Data team: Admin role

---

## Dependencies

### External Dependencies

**Data Sources**:
- `LH_Master_Data` Lakehouse (Fabric)
  - `Insalord` table (orders)
  - `Insalpar` table (parts)
  - `RepairOrderDetail` table (work order details)
  - `Customer` table (customer lookup)
  - `Salesperson` table (salesperson lookup)
  - `Branch` table (branch lookup)

**SQL Views** (must exist and be maintained):
- `vw_Fact_Parts_Open_Tickets` (V2 - critical fix applied Jan 7, 2026)
- `vw_Fact_Parts_Open_Tickets_Details`
- `dim_BranchLocation`
- `dim_DateTable`

**Fabric Services**:
- Data Warehouse (for SQL views)
- Semantic Model (for caching and serving data)
- Report Service (for visualization)
- Scheduling Service (for automated refresh)

### Internal Dependencies

**Measure Dependencies** (see Measure Dependencies diagram above):
- Percentage measures depend on Core Metrics
- Customer/Salesman Analysis measures depend on Order Count and Order Total
- Filtered measures depend on TopN Selector table

**Column Dependencies**:
- `Aging` column must have `sortByColumn: Aging_Sort_Order`
- `TopN Selector[Label]` must have `sortByColumn: SortOrder`

---

## Change History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Dec 2025 | Initial migration from old Lakehouse structure | B.Fox |
| 1.1 | Jan 6, 2026 | Added Customer/Salesman analysis measures | B.Fox + Claude |
| 2.0 | Jan 7, 2026 | **CRITICAL FIX**: SQL view bugs corrected (V2) | B.Fox + Claude |
| 2.1 | Jan 8, 2026 | Technical documentation created | B.Fox + Claude |

---

## Support & Maintenance

**Primary Contact**: B.Fox (Data Analyst)

**Documentation Files**:
- [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md) - Executive overview
- [MIGRATION-STATUS.md](MIGRATION-STATUS.md) - Current status and next steps
- [DAX-MEASURES-REFERENCE.md](DAX-MEASURES-REFERENCE.md) - Complete DAX library
- [REPORT-PAGES-GUIDE.md](REPORT-PAGES-GUIDE.md) - Page build specifications
- [DATA-FIX-DOCUMENTATION.md](DATA-FIX-DOCUMENTATION.md) - V2 SQL fix details
- **[TECHNICAL-REFERENCE.md](TECHNICAL-REFERENCE.md)** - This document

**SQL Queries**:
- [queries/fact-tables/Create_vw_Fact_Parts_Open_Tickets.sql](queries/fact-tables/Create_vw_Fact_Parts_Open_Tickets.sql) - Current V2 view

---

**Document Version**: 1.0
**Last Updated**: January 8, 2026
**Created By**: Claude Code - Technical Documentation Assistant
