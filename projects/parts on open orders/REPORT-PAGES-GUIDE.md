# Parts on Open Orders - Report Pages Guide

**Purpose**: Detailed specifications for rebuilding all 4 report pages in Power BI Desktop
**Version**: 2.0 (Modernized with Star Schema)
**Last Updated**: January 6, 2026

---

## TABLE OF CONTENTS

1. [Page 1: Overview](#page-1-overview)
2. [Page 2: On Order Details](#page-2-on-order-details)
3. [Page 3: Comparison](#page-3-comparison)
4. [Page 4: Charts](#page-4-charts)
5. [Global Settings](#global-settings)
6. [Color Palette](#color-palette)
7. [Best Practices](#best-practices)

---

## PAGE 1: OVERVIEW

**Purpose**: Executive dashboard showing aging buckets and key performance indicators

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  [Home - Header]                                    SVG Header  │
├─────────────────────────────────────────────────────────────────┤
│  [Show Filter 1]                             Active Filters     │
├───────────────────┬─────────────────────────────────────────────┤
│                   │                                             │
│  SLICERS          │  AGING MATRIX (Main Visual)                 │
│                   │                                             │
│  • Aging          │  Rows: Aging (sorted by Aging_Sort_Order)   │
│  • Branch         │  Values:                                    │
│  • Invoice Type   │    - Order Total                            │
│  • Order Date     │    - # Parts On Order                       │
│                   │    - Parts Line Count                       │
│                   │    - Total # of Orders                      │
│                   │                                             │
├───────────────────┴─────────────────────────────────────────────┤
│                                                                 │
│  KPI CARDS (4 Cards in Row)                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ Card 1   │ │ Card 2   │ │ Card 3   │ │ Card 4   │          │
│  │ Not BO   │ │ Parts    │ │ Line     │ │ Orders   │          │
│  │ vs BO    │ │ On Order │ │ Count    │ │ with BO  │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### Visual 1: Header (HTML Content)

**Visual Type**: HTML Content (or Text box if HTML not available)
**Measure**: `[Home - Header]`

**Configuration**:
- Height: 85px
- Width: Full page width
- Background: Gradient (handled in measure HTML)
- Font: Segoe UI

**What it shows**:
- Dashboard title: "Overview - Parts on Open Orders"
- Dynamic greeting based on time of day
- Current user name (formatted)
- Current date

### Visual 2: Active Filters Display

**Visual Type**: Card
**Measure**: `[Show Filter 1]`

**Configuration**:
- Height: ~60px
- Width: Full page width
- Background: Light gray (#F5F5F5)
- Border: 1px solid #E0E0E0
- Font size: 11pt
- Font color: #333333

**What it shows**:
Displays currently applied filters for:
- Aging
- Branch
- Invoice Type
- Order Date
- Customer
- Contact Code

### Visual 3: Slicers Panel

**Location**: Left sidebar (20% of page width)

#### Slicer 1: Aging
- **Field**: `Fact_Parts_Open_Tickets[Aging]`
- **Style**: Vertical list
- **Multi-select**: Yes
- **Sort**: By `Aging_Sort_Order`
- **Height**: 150px

#### Slicer 2: Branch
- **Field**: `dim_BranchLocation[Branch]`
- **Style**: Vertical list
- **Multi-select**: Yes
- **Height**: 200px

#### Slicer 3: Invoice Type
- **Field**: `Fact_Parts_Open_Tickets[Invoice_Type]`
- **Style**: Dropdown
- **Multi-select**: Yes

#### Slicer 4: Order Date
- **Field**: `Fact_Parts_Open_Tickets[Order_Date]`
- **Style**: Between (date range)
- **Show**: Calendar picker

### Visual 4: Aging Matrix (Main Visual)

**Visual Type**: Matrix

**Configuration**:
- **Rows**: `Fact_Parts_Open_Tickets[Aging]`
  - Sort by: `Aging_Sort_Order`
  - Show totals: Yes (at bottom)

- **Values** (in order):
  1. `[Order Total]` - Format: Currency
  2. `[# Parts On Order]` - Format: Whole number
  3. `[Parts Line Count]` - Format: Whole number
  4. `[Total # of Orders]` - Format: Whole number

**Conditional Formatting**:

1. **Order Total** - Data bars
   - Minimum: $0 (white)
   - Maximum: Auto (#3A7CA5 - blue)
   - Show bar only: No

2. **# Parts On Order** - Data bars
   - Minimum: 0 (white)
   - Maximum: Auto (#5CB85C - green)
   - Show bar only: No

3. **Parts Line Count** - Background color
   - Rules:
     - 0-100: White
     - 101-500: Light yellow (#FFF8DC)
     - 501+: Light orange (#FFE4B5)

4. **Total # of Orders** - Font color
   - Rules:
     - < 10: Black
     - 10-50: Dark blue (#1D3C4E)
     - 51+: Bold + Dark blue

**Matrix Styling**:
- Row headers: Bold, 11pt, #333333
- Column headers: Bold, 10pt, white text on #1D3C4E background
- Grid lines: Light gray (#E0E0E0)
- Totals row: Bold, larger font (12pt), light blue background (#E8F4F8)

### Visual 5-8: KPI Cards (SVG Measures)

**Visual Type**: Card (showing SVG measure)
**Layout**: 4 cards in a row, equal width

#### Card 1: Not Backordered vs Backordered
- **Measure**: `[KPI SVG - Not Backordered vs Backordered (Conditional Color)]`
- **Shows**:
  - Top: $$ not BO
  - Bottom: Backordered $$
  - Visual bar chart comparison
  - Percentage of backorder

#### Card 2: Parts On Order vs Back Order
- **Measure**: `[KPI SVG - Parts On Order vs Back Order (Conditional Color)]`
- **Shows**:
  - Top: # Parts On Order
  - Bottom: # on Back Order
  - Visual bar chart comparison
  - Percentage on backorder

#### Card 3: Line Count vs Backordered Line
- **Measure**: `[KPI SVG - Line Count vs Backordered Line (Conditional Color)]`
- **Shows**:
  - Top: Parts Line Count
  - Bottom: Backordered Line Count
  - Visual bar chart comparison

#### Card 4: Orders vs Orders with BO Parts
- **Measure**: `[KPI SVG - Orders vs Orders with BO Parts (Conditional Color)]`
- **Shows**:
  - Top: Total # of Orders
  - Bottom: Orders with Backordered Parts
  - Visual bar chart comparison
  - Percentage with backorders

**Card Styling**:
- Height: 180px
- Width: Equal distribution across page
- Background: White
- Border: 1px solid #E0E0E0
- Shadow: 0 2px 4px rgba(0,0,0,0.1)
- Border radius: 8px

---

## PAGE 2: ON ORDER DETAILS

**Purpose**: Detailed line-item view with drill-through capability

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Page Title: "Parts On Order - Detailed Line Items"            │
├─────────────────────────────────────────────────────────────────┤
│  [Show Filter 1]                             Active Filters     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DETAILED TABLE (Full width)                                    │
│  All columns from Fact_Parts_Open_Tickets_Details               │
│                                                                 │
│  Conditional formatting applied                                 │
│  Row-level highlighting for backorders                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Visual 1: Page Title
**Visual Type**: Text box
**Content**: "Parts On Order - Detailed Line Items"
**Styling**:
- Font: Segoe UI, 20pt, Bold
- Color: #1D3C4E
- Background: Light gradient (#F0F8FF to white)
- Height: 50px

### Visual 2: Active Filters
**Visual Type**: Card
**Measure**: `[Show Filter 1]`
(Same configuration as Page 1)

### Visual 3: Detail Table

**Visual Type**: Table

**Columns** (in order):

1. **Location_Name**
   - Width: 100px
   - Alignment: Left

2. **Order_No**
   - Width: 80px
   - Alignment: Center
   - Format: Whole number

3. **Customer**
   - Width: 150px
   - Alignment: Left

4. **Salesman**
   - Width: 100px
   - Alignment: Left

5. **Invoice_Type**
   - Width: 80px
   - Alignment: Center

6. **Order_Date**
   - Width: 90px
   - Alignment: Center
   - Format: MM/DD/YYYY

7. **Created_On**
   - Width: 90px
   - Alignment: Center
   - Format: MM/DD/YYYY

8. **WO_Creation_Date**
   - Width: 90px
   - Alignment: Center
   - Format: MM/DD/YYYY

9. **Days_Open**
   - Width: 70px
   - Alignment: Right
   - Format: Whole number

10. **Aging**
    - Width: 80px
    - Alignment: Center

11. **Part_No**
    - Width: 120px
    - Alignment: Left

12. **Part_Description**
    - Width: 200px
    - Alignment: Left

13. **Quantity_Ordered**
    - Width: 70px
    - Alignment: Right
    - Format: Whole number

14. **BackOrdered_QTY**
    - Width: 80px
    - Alignment: Right
    - Format: Whole number

15. **Unit_Price**
    - Width: 80px
    - Alignment: Right
    - Format: $#,0.00

16. **Line_Total**
    - Width: 90px
    - Alignment: Right
    - Format: $#,0.00

**Conditional Formatting**:

1. **BackOrdered_QTY** - Background color
   - Rule: If > 0
   - Color: Light red (#FFE6E6)
   - Font: Bold, dark red (#CC0000)

2. **Days_Open** - Background color gradient
   - 0-7 days: White
   - 8-14 days: Light yellow (#FFFACD)
   - 15-30 days: Light orange (#FFE4B5)
   - 31-60 days: Orange (#FFD700)
   - 61-90 days: Dark orange (#FFA500)
   - 90+ days: Red (#FF6B6B)

3. **Aging** - Background color (matches Days_Open color scheme)
   - 0-7 days: White
   - 8-14 days: Light yellow
   - 15-30 days: Light orange
   - 31-60 days: Orange
   - 61-90 days: Dark orange
   - 90+ days: Red

4. **Line_Total** - Data bars
   - Color: #3A7CA5 (blue)
   - Show bar only: No

**Table Styling**:
- Header row: Bold, white text, #1D3C4E background
- Alternating rows: White / #F9F9F9
- Grid lines: Light gray (#E0E0E0)
- Font size: 9pt
- Row height: 25px

**Interactions**:
- Enable drill-through from Overview page
- Allow sorting by any column
- Limit to 1000 rows with "See more" option
- Enable export to Excel

---

## PAGE 3: COMPARISON

**Purpose**: Branch performance comparison and customer/salesman rankings

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Page Title: "Branch & Customer Comparison"                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  BRANCH PERFORMANCE MATRIX                                │ │
│  │  Shows all branches with conditional highlighting         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐ │
│  │  CUSTOMER RANKINGS      │  │  SALESMAN RANKINGS          │ │
│  │  With TopN selector     │  │  With TopN selector         │ │
│  └─────────────────────────┘  └─────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Visual 1: Branch Performance Matrix

**Visual Type**: Matrix

**Configuration**:
- **Rows**: `dim_BranchLocation[Branch]`
- **Values**:
  1. `[Order Count]`
  2. `[Order Total]`
  3. `[# on Back Order]`
  4. `[$$ not BO]`

**Conditional Formatting**:

1. **Order Count** - Background color
   - Use measure: `[Bar Color Order Count]`
   - 0 (grey): #B3B3B3
   - 1 (highlight): #446FA7

2. **Order Total** - Background color
   - Use measure: `[Bar Color Hex Order Total]`
   - 0 (grey): #B3B3B3
   - 1 (highlight): #3A7CA5

3. **# on Back Order** - Background color
   - Use measure: `[Bar Color Hex Back Order]`
   - 0 (grey): #B3B3B3
   - 1 (highlight): #FF6B6B (red for highest)

4. **$$ not BO** - Background color
   - Use measure: `[Bar Color Hex $$ not BO]`
   - 0 (grey): #B3B3B3
   - 1 (highlight): #5CB85C (green)

**Matrix Styling**:
- Show totals at bottom
- Sort by Order Total (descending)
- Font size: 11pt
- Row height: 30px

### Visual 2: Customer Rankings

**Visual Type**: Table

**Slicers**:
- **TopN Selector**: Disconnected slicer
  - Options: Top 5, Top 10, Top 15, Top 20, All
  - Default: Top 10

**Columns**:
1. `Fact_Parts_Open_Tickets[Customer]`
2. `[Customer Rank - Order Count]`
3. `[Filtered Order Count]`
4. `[Customer Rank - Order Total]`
5. `[Filtered Order Total]`

**Conditional Formatting**:
- **Customer** column:
  - Use measure: `[Bar Color Hex - Customer Count]`
  - Highlight top/bottom performers

- **Filtered Order Total** column:
  - Use measure: `[Bar Color Hex - Customer Total]`
  - Data bars with conditional colors

**Table Styling**:
- Width: 50% of page (left side)
- Show only customers where `[Is In Top N] = TRUE`
- Sort by `[Customer Rank - Order Total]`

### Visual 3: Salesman Rankings

**Visual Type**: Table

**Slicers**:
- **TopN Selector**: Same disconnected slicer as Customer Rankings

**Columns**:
1. `Fact_Parts_Open_Tickets[Salesman]`
2. `[Salesman Rank - Order Count]`
3. `[Filtered Order Count - Salesman]`
4. `[Salesman Rank - Order Total]`
5. `[Filtered Order Total - Salesman]`

**Conditional Formatting**:
- **Salesman** column:
  - Use measure: `[Bar Color Hex - Salesman Count]`
  - Highlight top/bottom performers

- **Filtered Order Total - Salesman** column:
  - Use measure: `[Bar Color Hex - Salesman Total]`
  - Data bars with conditional colors

**Table Styling**:
- Width: 50% of page (right side)
- Sort by `[Salesman Rank - Order Total]`

---

## PAGE 4: CHARTS

**Purpose**: Visual trend analysis and distribution charts

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Page Title: "Trends & Analysis"                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐ │
│  │  AGING DISTRIBUTION     │  │  ORDERS OVER TIME           │ │
│  │  (Donut Chart)          │  │  (Line Chart)               │ │
│  └─────────────────────────┘  └─────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐ │
│  │  TOP CUSTOMERS          │  │  BRANCH COMPARISON          │ │
│  │  (Bar Chart)            │  │  (Clustered Column)         │ │
│  └─────────────────────────┘  └─────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Chart 1: Aging Distribution (Top Left)

**Visual Type**: Donut Chart

**Configuration**:
- **Legend**: `Fact_Parts_Open_Tickets[Aging]`
  - Sort by: `Aging_Sort_Order`
- **Values**: `[Order Count]`

**Styling**:
- Colors:
  - 0-7 days: #5CB85C (green)
  - 8-14 days: #9ACD32 (yellow-green)
  - 15-30 days: #FFD700 (gold)
  - 31-60 days: #FFA500 (orange)
  - 61-90 days: #FF8C00 (dark orange)
  - 90+ days: #FF6B6B (red)
- Detail labels: Show percentage
- Legend position: Right
- Donut hole: 40%

### Chart 2: Orders Over Time (Top Right)

**Visual Type**: Line Chart

**Configuration**:
- **X-axis**: `dim_DateTable[Date]`
  - Hierarchy: Year > Quarter > Month
  - Default: Month view
- **Y-axis**:
  - Line 1: `[Order Total]` (primary axis)
  - Line 2: `[Order Count]` (secondary axis)

**Styling**:
- Order Total line: #3A7CA5 (blue), 3px width
- Order Count line: #5CB85C (green), 2px width, dashed
- Show data labels: No
- Show markers: Yes
- X-axis label format: MMM YYYY
- Y-axis (primary): Currency format
- Y-axis (secondary): Whole number

### Chart 3: Top Customers (Bottom Left)

**Visual Type**: Horizontal Bar Chart

**Configuration**:
- **Y-axis**: `Fact_Parts_Open_Tickets[Customer]`
- **X-axis**: `[Order Total]`
- **Filter**: Top 10 by Order Total

**Styling**:
- Bars color: #446FA7 (blue)
- Sort: Descending by Order Total
- Show data labels: Yes (inside end, white text)
- Show gridlines: Yes (light gray)

### Chart 4: Branch Comparison (Bottom Right)

**Visual Type**: Clustered Column Chart

**Configuration**:
- **X-axis**: `dim_BranchLocation[Branch]`
- **Y-axis**:
  - Series 1: `[Order Total]` (primary axis)
  - Series 2: `[# on Back Order]` (secondary axis)

**Styling**:
- Order Total columns: #3A7CA5 (blue)
- # on Back Order columns: #FF6B6B (red)
- Show data labels: Yes (above columns)
- Sort: By Order Total descending
- X-axis label angle: 45 degrees

---

## GLOBAL SETTINGS

### Page Size
- **Format**: 16:9 (Widescreen)
- **Width**: 1280px
- **Height**: 720px

### Page Background
- **Color**: White (#FFFFFF)
- **Or**: Very light gray (#F8F8F8)

### Font Defaults
- **Primary Font**: Segoe UI
- **Fallback**: Arial, sans-serif
- **Title Size**: 16-20pt
- **Body Size**: 10-11pt
- **Small Text**: 9pt

### Filters Pane
- **Show Filters Pane**: No (use on-page slicers)
- **Sync slicers**: Yes (across all pages where applicable)

### Mobile Layout
- **Enable mobile layout**: Yes
- **Priority order**:
  1. Key metrics (KPI cards)
  2. Main visual (matrix/table)
  3. Slicers
  4. Charts

---

## COLOR PALETTE

### Primary Colors
- **Dark Blue**: #1D3C4E (headers, titles)
- **Medium Blue**: #3A7CA5 (primary data)
- **Light Blue**: #446FA7 (highlights)
- **Accent Blue**: #E8F4F8 (backgrounds)

### Secondary Colors
- **Green**: #5CB85C (positive indicators)
- **Red**: #FF6B6B (alerts, backordered items)
- **Orange**: #FFA500 (warnings, aging)
- **Gray**: #B3B3B3 (neutral, inactive)

### Aging Gradient
1. **0-7 days**: #5CB85C (green)
2. **8-14 days**: #9ACD32 (yellow-green)
3. **15-30 days**: #FFD700 (gold)
4. **31-60 days**: #FFA500 (orange)
5. **61-90 days**: #FF8C00 (dark orange)
6. **90+ days**: #FF6B6B (red)

### Text Colors
- **Primary text**: #333333
- **Secondary text**: #666666
- **Light text**: #999999
- **White text**: #FFFFFF (on dark backgrounds)

---

## BEST PRACTICES

### Performance Optimization

1. **Limit Visual Complexity**
   - Max 10 visuals per page
   - Use TopN filters where appropriate
   - Limit detail tables to 1000 rows initially

2. **Use Aggregated Measures**
   - Avoid calculated columns where possible
   - Use measures for all calculations
   - Pre-aggregate in fact tables when possible

3. **Optimize Refresh**
   - Use incremental refresh for fact tables
   - Cache static dimensions
   - Refresh only during off-hours

### User Experience

1. **Consistent Navigation**
   - Use bookmarks for common filter states
   - Provide "Reset Filters" button on each page
   - Show active filters on every page

2. **Tooltips**
   - Add custom tooltips to explain metrics
   - Show additional context on hover
   - Include trend information

3. **Accessibility**
   - Use high contrast colors
   - Provide alt text for all visuals
   - Ensure keyboard navigation works
   - Test with screen readers

### Maintenance

1. **Documentation**
   - Comment complex DAX measures
   - Document data source connections
   - Keep measure descriptions up to date

2. **Version Control**
   - Use Git for TMDL files
   - Tag releases
   - Document breaking changes

3. **Testing**
   - Validate totals against source system
   - Test all interactive features
   - Verify scheduled refresh works
   - Check mobile layout

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Setup
- [ ] Open Power BI Desktop
- [ ] Open semantic model: `Parts on Open Orders.SemanticModel`
- [ ] Verify all measures are loaded (39 total)
- [ ] Verify all relationships are active

### Phase 2: Page 1 - Overview
- [ ] Create new report page "Overview"
- [ ] Add header (HTML content or text box)
- [ ] Add filter display card
- [ ] Add slicers (Aging, Branch, Invoice Type, Order Date)
- [ ] Create aging matrix with conditional formatting
- [ ] Add 4 KPI cards (SVG measures)
- [ ] Test all interactions
- [ ] Set as default page

### Phase 3: Page 2 - Details
- [ ] Create new report page "On Order Details"
- [ ] Add page title
- [ ] Add filter display
- [ ] Create detail table with all columns
- [ ] Apply conditional formatting
- [ ] Configure drill-through from Overview
- [ ] Test sorting and filtering

### Phase 4: Page 3 - Comparison
- [ ] Create new report page "Comparison"
- [ ] Add branch performance matrix
- [ ] Create TopN Selector table (disconnected)
- [ ] Add TopN slicer
- [ ] Create customer rankings table
- [ ] Create salesman rankings table
- [ ] Apply conditional formatting to all
- [ ] Test TopN filtering

### Phase 5: Page 4 - Charts
- [ ] Create new report page "Charts"
- [ ] Add aging distribution donut chart
- [ ] Add orders over time line chart
- [ ] Add top customers bar chart
- [ ] Add branch comparison column chart
- [ ] Apply color scheme consistently
- [ ] Test date hierarchies

### Phase 6: Finalization
- [ ] Sync slicers across pages
- [ ] Create mobile layout for all pages
- [ ] Add page navigation buttons
- [ ] Test all bookmarks
- [ ] Verify performance (load time < 3 seconds)
- [ ] Export to Fabric workspace
- [ ] Configure scheduled refresh
- [ ] Share with stakeholders

---

## TROUBLESHOOTING

### Common Issues

**Issue**: Aging not sorting correctly
**Fix**: Ensure `Aging` column has `sortByColumn: Aging_Sort_Order` in TMDL

**Issue**: SVG measures not displaying
**Fix**: Use Card visual, not HTML content visual; ensure measure returns string

**Issue**: Conditional formatting not applying
**Fix**: Verify measure returns 0 or 1 (not TRUE/FALSE); check field names match exactly

**Issue**: Filters not syncing
**Fix**: Go to View > Sync slicers; enable sync for desired pages

**Issue**: Slow refresh
**Fix**: Check for unnecessary calculated columns; use Direct Query for large datasets; optimize SQL views

---

## SUPPORT RESOURCES

**Documentation Files**:
- `MIGRATION-STATUS.md` - Project status and completion tracking
- `DAX-MEASURES-REFERENCE.md` - Complete measure library
- Old report exports: `info-exports/old report/*.csv`
- Screenshots: `screenshots/old report/*.jpg`

**Similar Projects**:
- `projects/inspections-report/` - Reference for documentation structure

**External Resources**:
- [Power BI Documentation](https://docs.microsoft.com/en-us/power-bi/)
- [DAX Guide](https://dax.guide/)
- [SQLBI](https://www.sqlbi.com/) - DAX patterns and best practices

---

**Last Updated**: January 6, 2026
**Created By**: Claude Code Modernization Assistant
**Version**: 2.0
