# Data Dictionary - Parts on Open Orders Report

**Report Name**: Parts on Open Orders
**Version**: 2.0
**Last Updated**: January 8, 2026
**Platform**: Microsoft Fabric

---

## Table of Contents

1. [Introduction](#introduction)
2. [Fact Tables](#fact-tables)
   - [Fact_Parts_Open_Tickets](#fact_parts_open_tickets)
   - [Fact_Parts_Open_Tickets_Details](#fact_parts_open_tickets_details)
3. [Dimension Tables](#dimension-tables)
   - [dim_BranchLocation](#dim_branchlocation)
   - [dim_DateTable](#dim_datetable)
   - [TopN Selector](#topn-selector)
4. [DAX Measures](#dax-measures)
5. [Business Glossary](#business-glossary)
6. [Data Lineage](#data-lineage)

---

## Introduction

This data dictionary provides comprehensive documentation of all data elements in the Parts on Open Orders report. It includes field-level definitions, data types, business rules, source mappings, and example values.

**Audience**: Report users, developers, analysts, and data stewards

**Purpose**:
- Understand what each field means
- Know where data comes from
- Learn business rules and calculations
- Find example values and ranges

---

## Fact Tables

## Fact_Parts_Open_Tickets

**Description**: Order summary table containing one row per unique order with aggregated metrics

**Granularity**: One row per order (Order_No)

**Row Count**: ~1,121 orders (as of January 2026)

**Source**: `LH_Master_Data.dbo.vw_Fact_Parts_Open_Tickets` (SQL view)

**Refresh Frequency**: Twice daily (6:00 AM, 1:00 PM)

**Business Owner**: Parts Department

---

### Columns

#### Location

| Attribute | Value |
|-----------|-------|
| **Column Name** | Location |
| **Data Type** | String (Text) |
| **Description** | Branch identifier code |
| **Business Definition** | Unique code identifying which branch location owns this order |
| **Format** | 2-3 character alphanumeric code |
| **Example Values** | "HQ", "BR1", "BR2", "NYC", "LA" |
| **Source Column** | `Insalord.Branch` |
| **Null Allowed** | No |
| **Unique Values** | ~10-15 branches |
| **Usage** | Filtering by branch, grouping orders by location |
| **Related Dimension** | `dim_BranchLocation[BranchID]` (FK relationship) |
| **Business Rules** | Must match valid branch code in dim_BranchLocation |

---

#### Location_Name

| Attribute | Value |
|-----------|-------|
| **Column Name** | Location_Name |
| **Data Type** | String (Text) |
| **Description** | Human-readable branch name |
| **Business Definition** | Full display name of the branch location |
| **Format** | Free text, typically city or location descriptor |
| **Example Values** | "Headquarters", "New York Branch", "Los Angeles Service Center" |
| **Source Column** | Lookup from `Branch` table via `Location` |
| **Null Allowed** | No |
| **Usage** | Display in reports, tooltips, headers |
| **Related Dimension** | Denormalized from `dim_BranchLocation[Location_Name]` |
| **Business Rules** | Derived from Location FK; used for display only |

---

#### Order_No

| Attribute | Value |
|-----------|-------|
| **Column Name** | Order_No |
| **Data Type** | Integer (Whole Number) |
| **Description** | Unique order identifier |
| **Business Definition** | Primary key for the order; unique across all orders |
| **Format** | Numeric (typically 5-6 digits) |
| **Example Values** | 682410, 123456, 789012 |
| **Source Column** | `CASE WHEN RONumber = 0 THEN FileNumber ELSE RONumber END` |
| **Null Allowed** | No (Primary Key) |
| **Unique Values** | Yes (Primary Key) |
| **Usage** | Joining to detail table, drill-through, order lookup |
| **Related Tables** | FK from `Fact_Parts_Open_Tickets_Details[Order_No]` |
| **Business Rules** | Use RONumber when available; fallback to FileNumber |
| **Index** | Clustered index (Primary Key) |

---

#### Invoice_Type

| Attribute | Value |
|-----------|-------|
| **Column Name** | Invoice_Type |
| **Data Type** | String (Text) |
| **Description** | Type of order or invoice |
| **Business Definition** | Classification of the order type (Work Order, Pending Ticket, Quote, etc.) |
| **Format** | Free text |
| **Example Values** | "Work Order", "Pending Ticket", "Quote", "Picking Slip", "Invoice" |
| **Source Column** | `Insalord.OrderType` (mapped to descriptive text) |
| **Null Allowed** | No |
| **Unique Values** | ~5-10 distinct types |
| **Usage** | Filtering orders by type, conditional aging logic |
| **Business Rules** | "Work Order" uses special aging logic (RepairOrderDetail date) |
| **Slicer** | Multi-select dropdown slicer on Overview page |

---

#### Order_Date

| Attribute | Value |
|-----------|-------|
| **Column Name** | Order_Date |
| **Data Type** | Date |
| **Description** | Date the order was placed |
| **Business Definition** | Official date customer placed the parts order |
| **Format** | Short Date (MM/DD/YYYY) |
| **Example Values** | 01/06/2026, 12/15/2025, 11/01/2025 |
| **Source Column** | `Insalord.OrderDate` |
| **Null Allowed** | No |
| **Date Range** | Typically last 2-3 years |
| **Usage** | Time-based filtering, aging fallback, trend analysis |
| **Related Dimension** | FK to `dim_DateTable[Date]` |
| **Business Rules** | Used as final fallback for aging if Created_On is NULL |
| **Slicer** | Date range picker (between slicer) |

---

#### Created_On

| Attribute | Value |
|-----------|-------|
| **Column Name** | Created_On |
| **Data Type** | Date |
| **Description** | Date order was entered into the system |
| **Business Definition** | System timestamp when order record was created |
| **Format** | Short Date (MM/DD/YYYY) |
| **Example Values** | 01/06/2026, 12/16/2025, 11/02/2025 |
| **Source Column** | `Insalord.CreatedDate` |
| **Null Allowed** | Yes (rare) |
| **Date Range** | Same as Order_Date or slightly later |
| **Usage** | Primary aging date for most order types, audit trail |
| **Business Rules** | Primary aging date for non-Work Orders; fallback for Work Orders |
| **Relationship to Order_Date** | Typically same day or 1-2 days after Order_Date |

---

#### WO_Creation_Date

| Attribute | Value |
|-----------|-------|
| **Column Name** | WO_Creation_Date |
| **Data Type** | Date |
| **Description** | Work Order creation date from repair system |
| **Business Definition** | Date the Work Order was created in RepairOrderDetail table |
| **Format** | Short Date (MM/DD/YYYY) |
| **Example Values** | 01/06/2026, NULL (if not a Work Order or no repair detail) |
| **Source Column** | `MIN(RepairOrderDetail.CreationDate)` for matching Work Order |
| **Null Allowed** | Yes (NULL for non-Work Orders or Work Orders without repair details) |
| **Usage** | Primary aging date for Work Orders |
| **Business Rules** | Only populated for Invoice_Type = 'Work Order' with repair records |
| **Aging Priority** | 1st choice for Work Order aging (see Aging_Date_Source) |

---

#### Days_Open

| Attribute | Value |
|-----------|-------|
| **Column Name** | Days_Open |
| **Data Type** | Integer (Whole Number) |
| **Description** | Number of days the order has been open |
| **Business Definition** | Calendar days between aging base date and today |
| **Format** | Whole number (0 to ~1000+) |
| **Example Values** | 1, 15, 47, 125, 365 |
| **Source Column** | Calculated: `DATEDIFF(day, [Aging_Base_Date], GETDATE())` |
| **Null Allowed** | No (always calculated) |
| **Typical Range** | 0-365 days (most orders); outliers can be 1000+ days |
| **Usage** | Sorting by age, filtering old orders, aging bucket assignment |
| **Business Rules** | Recalculated daily; based on Aging_Base_Date logic |
| **Conditional Formatting** | Color scale (white → yellow → orange → red) |

---

#### Aging

| Attribute | Value |
|-----------|-------|
| **Column Name** | Aging |
| **Data Type** | String (Text) |
| **Description** | Aging bucket classification |
| **Business Definition** | Categorical grouping of orders by how long they've been open |
| **Format** | Text range (e.g., "0-7 days", "31-60 days") |
| **Example Values** | "0-7 days", "8-14 days", "15-30 days", "31-60 days", "61-90 days", "90+ days" |
| **Source Column** | Calculated based on Days_Open |
| **Null Allowed** | No |
| **Unique Values** | 6 distinct buckets |
| **Usage** | Primary grouping dimension on Overview page, aging matrix rows |
| **Sort Order** | Sorted by `Aging_Sort_Order` (not alphabetically) |
| **Business Rules** | Bucket assignment:<br>• 0-7 days<br>• 8-14 days<br>• 15-30 days<br>• 31-60 days<br>• 61-90 days<br>• 90+ days |
| **Slicer** | Multi-select list slicer |
| **Conditional Formatting** | Each bucket has associated color (green → yellow → red) |

---

#### Aging_Sort_Order

| Attribute | Value |
|-----------|-------|
| **Column Name** | Aging_Sort_Order |
| **Data Type** | Integer (Whole Number) |
| **Description** | Numeric sort order for aging buckets |
| **Business Definition** | Ensures aging buckets sort chronologically (newest to oldest) |
| **Format** | Integer 1-6 |
| **Example Values** | 1 = "0-7 days", 2 = "8-14 days", ..., 6 = "90+ days" |
| **Source Column** | Calculated based on Days_Open |
| **Null Allowed** | No |
| **Unique Values** | 6 values (1-6) |
| **Usage** | **CRITICAL**: `Aging` column must have `sortByColumn: Aging_Sort_Order` |
| **Business Rules** | Mapping:<br>1 → "0-7 days"<br>2 → "8-14 days"<br>3 → "15-30 days"<br>4 → "31-60 days"<br>5 → "61-90 days"<br>6 → "90+ days" |
| **Note** | Without this, Aging would sort alphabetically ("0-7", "15-30", "31-60"...) |

---

#### Aging_Date_Source 🆕

| Attribute | Value |
|-----------|-------|
| **Column Name** | Aging_Date_Source |
| **Data Type** | String (Text) |
| **Description** | Indicator of which date field was used for aging calculation |
| **Business Definition** | Shows the source date that determined Days_Open and Aging |
| **Format** | Text (enum-like) |
| **Example Values** | "WO_Creation_Date", "Created_On", "Order_Date" |
| **Source Column** | Calculated in SQL view (V2) |
| **Null Allowed** | No |
| **Unique Values** | 3 possible values |
| **Usage** | Diagnostic/audit column; helps validate aging logic |
| **Business Rules** | Priority order:<br>1. 'WO_Creation_Date' (Work Orders with repair details)<br>2. 'Created_On' (most orders; Work Orders without repair details)<br>3. 'Order_Date' (final fallback) |
| **Typical Distribution** | ~40% WO_Creation_Date, ~55% Created_On, ~5% Order_Date |
| **New in V2** | Added January 7, 2026 as part of aging logic fix |

---

#### Aging_Base_Date 🆕

| Attribute | Value |
|-----------|-------|
| **Column Name** | Aging_Base_Date |
| **Data Type** | Date |
| **Description** | Actual date used for aging calculation |
| **Business Definition** | The specific date that Days_Open was calculated from |
| **Format** | Short Date (MM/DD/YYYY) |
| **Example Values** | 01/06/2026, 12/15/2025, 11/01/2025 |
| **Source Column** | Calculated in SQL view based on aging logic |
| **Null Allowed** | No |
| **Usage** | Transparency into aging calculation; audit and troubleshooting |
| **Business Rules** | Value equals:<br>• WO_Creation_Date (if Work Order with repair details)<br>• Created_On (if no WO_Creation_Date)<br>• Order_Date (if Created_On is NULL) |
| **Validation** | `Days_Open = DATEDIFF(day, Aging_Base_Date, GETDATE())` |
| **New in V2** | Added January 7, 2026 as diagnostic column |

---

#### #_Parts_On_Order

| Attribute | Value |
|-----------|-------|
| **Column Name** | #_Parts_On_Order |
| **Data Type** | Number (Double) |
| **Description** | Total quantity of parts on this order |
| **Business Definition** | Sum of all part quantities ordered (including backordered items) |
| **Format** | Whole number (typically) |
| **Example Values** | 5, 12, 3, 25, 100 |
| **Source Column** | `SUM(Insalpar.Quantity)` grouped by order |
| **Null Allowed** | No (defaults to 0) |
| **Typical Range** | 1-200 parts per order |
| **Usage** | KPI cards, parts quantity analysis, percentage calculations |
| **Business Rules** | Includes both available and backordered quantities |
| **Measure** | `# Parts On Order = SUM(Fact_Parts_Open_Tickets[#_Parts_On_Order])` |

---

#### #_On_Back_Order

| Attribute | Value |
|-----------|-------|
| **Column Name** | #_On_Back_Order |
| **Data Type** | Number (Double) |
| **Description** | Quantity of parts on backorder for this order |
| **Business Definition** | Sum of backordered quantities; 0 if all parts available |
| **Format** | Whole number |
| **Example Values** | 0, 2, 5, 10 |
| **Source Column** | `SUM(ISNULL(Insalpar.BackorderQty, 0))` grouped by order |
| **Null Allowed** | No (NULLs converted to 0) |
| **Typical Range** | 0-100 (most orders have 0) |
| **Usage** | Backorder analysis, KPI cards, conditional filtering |
| **Business Rules** | 0 means all parts available; >0 means some or all parts backordered |
| **Measure** | `# on Back Order = SUM(Fact_Parts_Open_Tickets[#_On_Back_Order])` |
| **Conditional Logic** | Used to identify orders with backorder issues |

---

#### Order_Total_$$

| Attribute | Value |
|-----------|-------|
| **Column Name** | Order_Total_$$ |
| **Data Type** | Number (Double) |
| **Description** | Total dollar amount of the order |
| **Business Definition** | Sum of all line item totals (quantity × unit price) |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $125.50, $1,234.99, $45.00, $3,567.85 |
| **Source Column** | `SUM(Insalpar.Quantity * Insalpar.Unit_Price)` |
| **Null Allowed** | No |
| **Typical Range** | $10 - $10,000+ per order |
| **Usage** | Primary financial metric, ranking, trending |
| **Business Rules** | Includes both available and backordered dollar amounts |
| **Measure** | `Order Total = SUM(Fact_Parts_Open_Tickets[Order_Total_$$])` |
| **Aggregation** | Sum across all orders for total business value |

---

#### $$_Available

| Attribute | Value |
|-----------|-------|
| **Column Name** | $$_Available |
| **Data Type** | Number (Double) |
| **Description** | Dollar value of parts NOT on backorder |
| **Business Definition** | Order_Total_$$ - $$_BackOrdered |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $125.50, $1,000.00, $0.00 (if fully backordered) |
| **Source Column** | Calculated: `Order_Total - Backordered_Amount` |
| **Null Allowed** | No |
| **Typical Range** | $0 - Order_Total_$$ |
| **Usage** | Cash flow analysis, availability metrics |
| **Business Rules** | Can be 0 if entire order is on backorder |
| **Measure** | `$$ not BO = SUM(Fact_Parts_Open_Tickets[$$_Available])` |

---

#### $$_BackOrdered

| Attribute | Value |
|-----------|-------|
| **Column Name** | $$_BackOrdered |
| **Data Type** | Number (Double) |
| **Description** | Dollar value of parts on backorder |
| **Business Definition** | Sum of (backordered quantity × unit price) for all backordered items |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $0.00, $125.50, $500.00 |
| **Source Column** | `SUM(Insalpar.BackorderQty * Insalpar.Unit_Price)` |
| **Null Allowed** | No |
| **Typical Range** | $0 - Order_Total_$$ |
| **Usage** | Financial impact of backorders, KPI tracking |
| **Business Rules** | 0 means no financial impact from backorders |
| **Measure** | `Backordered $$ = SUM(Fact_Parts_Open_Tickets[$$_BackOrdered])` |
| **Alert Threshold** | Flag if > 10% of Order_Total_$$ |

---

#### Backorder_Pct

| Attribute | Value |
|-----------|-------|
| **Column Name** | Backorder_Pct |
| **Data Type** | Number (Double) |
| **Description** | Percentage of order value on backorder |
| **Business Definition** | ($$_BackOrdered / Order_Total_$$) × 100% |
| **Format** | Percentage (0.00%) |
| **Example Values** | 0%, 15.5%, 100% |
| **Source Column** | Calculated: `$$_BackOrdered / Order_Total_$$` |
| **Null Allowed** | Yes (if Order_Total_$$ = 0) |
| **Typical Range** | 0% - 100% |
| **Usage** | Quick assessment of backorder severity |
| **Business Rules** | >50% considered high-impact backorder |
| **Measure** | Calculated in visual or using DAX DIVIDE |

---

#### Deposit

| Attribute | Value |
|-----------|-------|
| **Column Name** | Deposit |
| **Data Type** | Number (Double) |
| **Description** | Deposit amount collected for this order |
| **Business Definition** | Pre-payment or deposit collected from customer |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $0.00, $50.00, $100.00, $250.00 |
| **Source Column** | `Insalord.Deposit` |
| **Null Allowed** | No (defaults to 0) |
| **Typical Range** | $0 - $500 |
| **Usage** | Financial tracking, deposit reconciliation |
| **Business Rules** | **CRITICAL**: Must be in GROUP BY clause (V2 fix) |
| **Impact** | Orders with different deposits are separate rows (V2 fix) |
| **Measure** | `Deposit = SUM(Fact_Parts_Open_Tickets[Deposit])` |
| **Data Quality Issue (V1)** | V1 had bug where Deposit not in GROUP BY, causing merged rows |

---

#### Salesman

| Attribute | Value |
|-----------|-------|
| **Column Name** | Salesman |
| **Data Type** | String (Text) |
| **Description** | Salesperson assigned to this order |
| **Business Definition** | Employee responsible for the customer relationship and order |
| **Format** | Full name (Last, First or First Last) |
| **Example Values** | "Smith, John", "Jane Doe", "Rodriguez, Maria" |
| **Source Column** | Lookup from `Salesperson` table via `Insalord.Salesperson` ID |
| **Null Allowed** | Yes (some orders may not have assigned salesperson) |
| **Unique Values** | ~20-50 distinct salespeople |
| **Usage** | Salesman rankings, commission tracking, performance analysis |
| **Business Rules** | Used for Salesman Analysis measures and rankings |
| **Slicer** | Available as filter dimension |

---

#### Contact_Code

| Attribute | Value |
|-----------|-------|
| **Column Name** | Contact_Code |
| **Data Type** | String (Text) |
| **Description** | Contact code for the order |
| **Business Definition** | Additional customer or contact classification |
| **Format** | Alphanumeric code |
| **Example Values** | "CONT001", "WALK-IN", "PHONE" |
| **Source Column** | `Insalord.ContactCode` |
| **Null Allowed** | Yes |
| **Usage** | Additional filtering dimension, contact type analysis |
| **Slicer** | Available as filter |

---

#### AR_Acct

| Attribute | Value |
|-----------|-------|
| **Column Name** | AR_Acct |
| **Data Type** | Integer (Whole Number) |
| **Description** | Accounts Receivable account number |
| **Business Definition** | Financial system account reference for receivables |
| **Format** | Integer (typically 5-7 digits) |
| **Example Values** | 12345, 67890, 11111 |
| **Source Column** | `Insalord.AR_Acct` or customer lookup |
| **Null Allowed** | Yes |
| **Usage** | Financial reconciliation, accounting integration |

---

#### Customer

| Attribute | Value |
|-----------|-------|
| **Column Name** | Customer |
| **Data Type** | String (Text) |
| **Description** | Customer name |
| **Business Definition** | Company or individual who placed the order |
| **Format** | Free text (company or person name) |
| **Example Values** | "ABC Corporation", "John Smith", "XYZ Industries" |
| **Source Column** | Lookup from `Customer` table via `Insalord.CustomerNumber` |
| **Null Allowed** | No |
| **Unique Values** | ~500-2000 distinct customers |
| **Usage** | Customer rankings, customer filtering, relationship analysis |
| **Business Rules** | Used for Customer Analysis measures and Top N rankings |
| **Slicer** | Search/select slicer |

---

## Fact_Parts_Open_Tickets_Details

**Description**: Line item detail table containing one row per part on each order

**Granularity**: One row per Part_No within each Order_No

**Row Count**: ~5,000-15,000 line items (as of January 2026)

**Source**: `LH_Master_Data.dbo.vw_Fact_Parts_Open_Tickets_Details` (SQL view)

**Refresh Frequency**: Twice daily (6:00 AM, 1:00 PM)

**Business Owner**: Parts Department

---

### Columns

**Note**: Many columns are duplicated from Fact_Parts_Open_Tickets for convenience (denormalized)

#### Part_No

| Attribute | Value |
|-----------|-------|
| **Column Name** | Part_No |
| **Data Type** | String (Text) |
| **Description** | Part number or SKU |
| **Business Definition** | Unique identifier for the part being ordered |
| **Format** | Alphanumeric (varies by manufacturer) |
| **Example Values** | "PART-12345", "ABC-789", "XYZ-001-B" |
| **Source Column** | `Insalpar.Part_No` |
| **Null Allowed** | No |
| **Unique Values** | ~1,000-5,000 distinct parts |
| **Usage** | Part-level analysis, inventory tracking, drill-through |
| **Business Rules** | Primary attribute at detail level |
| **Conditional Formatting** | None |

---

#### Part_Description

| Attribute | Value |
|-----------|-------|
| **Column Name** | Part_Description (if available) |
| **Data Type** | String (Text) |
| **Description** | Human-readable part description |
| **Business Definition** | Descriptive text explaining what the part is |
| **Format** | Free text |
| **Example Values** | "Oil Filter - Standard", "Brake Pad Set - Front", "Spark Plug - NGK" |
| **Source Column** | Part master table lookup |
| **Null Allowed** | Yes (some parts may not have descriptions) |
| **Usage** | Part identification, tooltips, user clarity |

---

#### Quantity_Ordered

| Attribute | Value |
|-----------|-------|
| **Column Name** | Quantity_Ordered |
| **Data Type** | Number (Double) |
| **Description** | Quantity of this part ordered on this line |
| **Business Definition** | Total quantity ordered (includes available + backordered) |
| **Format** | Whole number (typically) or decimal (for fractional quantities) |
| **Example Values** | 1, 2, 5, 10, 0.5 (for fractional items) |
| **Source Column** | `Insalpar.Quantity` |
| **Null Allowed** | No |
| **Typical Range** | 1-100 per line |
| **Usage** | Line-level quantity analysis, inventory planning |
| **Business Rules** | Quantity_Ordered = Available_QTY + BackOrdered_QTY |

---

#### BackOrdered_QTY

| Attribute | Value |
|-----------|-------|
| **Column Name** | BackOrdered_QTY |
| **Data Type** | Number (Double) |
| **Description** | Quantity on backorder for this line |
| **Business Definition** | Portion of Quantity_Ordered that is not currently available |
| **Format** | Whole number or decimal |
| **Example Values** | 0, 1, 2, 5 |
| **Source Column** | `ISNULL(Insalpar.BackorderQty, 0)` |
| **Null Allowed** | No (NULLs converted to 0) |
| **Typical Range** | 0 - Quantity_Ordered |
| **Usage** | Identifying backordered lines, conditional formatting |
| **Business Rules** | 0 = fully available; >0 = partially or fully backordered |
| **Conditional Formatting** | Red background if > 0 |
| **Measure** | `Backordered Line Count = CALCULATE(COUNTROWS(...), BackOrdered_QTY > 0)` |

---

#### Available_QTY

| Attribute | Value |
|-----------|-------|
| **Column Name** | Available_QTY |
| **Data Type** | Number (Double) |
| **Description** | Quantity available (not on backorder) |
| **Business Definition** | Quantity_Ordered - BackOrdered_QTY |
| **Format** | Whole number or decimal |
| **Example Values** | 0, 1, 2, 5 |
| **Source Column** | Calculated: `Quantity - BackorderQty` |
| **Null Allowed** | No |
| **Typical Range** | 0 - Quantity_Ordered |
| **Usage** | Fulfillment analysis, available inventory |
| **Business Rules** | Can be 0 if entire line quantity is backordered |

---

#### Unit_Price

| Attribute | Value |
|-----------|-------|
| **Column Name** | Unit_Price |
| **Data Type** | Number (Double) |
| **Description** | Price per unit for this part |
| **Business Definition** | Cost per single item of this part |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $5.99, $125.00, $0.50, $1,234.56 |
| **Source Column** | `Insalpar.Unit_Price` |
| **Null Allowed** | No |
| **Typical Range** | $0.01 - $10,000+ (varies widely by part) |
| **Usage** | Pricing analysis, margin calculations, line total computation |
| **Business Rules** | Line_Total = Quantity_Ordered × Unit_Price |

---

#### Line_Total

| Attribute | Value |
|-----------|-------|
| **Column Name** | Line_Total |
| **Data Type** | Number (Double) |
| **Description** | Total dollar value for this line |
| **Business Definition** | Quantity_Ordered × Unit_Price |
| **Format** | Currency ($#,0.00) |
| **Example Values** | $11.98, $125.00, $5.00, $12,345.60 |
| **Source Column** | Calculated: `Quantity * Unit_Price` |
| **Null Allowed** | No |
| **Typical Range** | $1 - $50,000+ per line |
| **Usage** | Line-level financial analysis, top part lines |
| **Business Rules** | Sum of all Line_Total for an order = Order_Total_$$ |
| **Conditional Formatting** | Data bars to show relative line values |

---

#### Line_Backorder_Pct

| Attribute | Value |
|-----------|-------|
| **Column Name** | Line_Backorder_Pct |
| **Data Type** | Number (Double) |
| **Description** | Percentage of line quantity on backorder |
| **Business Definition** | (BackOrdered_QTY / Quantity_Ordered) × 100% |
| **Format** | Percentage (0.00%) |
| **Example Values** | 0%, 50%, 100% |
| **Source Column** | Calculated: `BackOrdered_QTY / Quantity` |
| **Null Allowed** | Yes (if Quantity_Ordered = 0) |
| **Typical Range** | 0% - 100% |
| **Usage** | Line-level backorder severity assessment |
| **Business Rules** | 100% = entire line on backorder; 0% = fully available |

---

**Other Columns** (Duplicated from Parent Order):
- Order_No (FK to Fact_Parts_Open_Tickets)
- Location, Location_Name
- Invoice_Type
- Order_Date, Created_On, WO_Creation_Date
- Days_Open, Aging, Aging_Sort_Order, Aging_Date_Source
- Customer, Salesman, Contact_Code

---

## Dimension Tables

## dim_BranchLocation

**Description**: Branch master data

**Granularity**: One row per branch

**Row Count**: ~10-15 branches

**Source**: `LH_Master_Data.dbo.dim_BranchLocation`

**Refresh Frequency**: Daily or as-needed (slowly changing)

---

### Key Columns

#### BranchID

| Attribute | Value |
|-----------|-------|
| **Column Name** | BranchID |
| **Data Type** | String (Text) |
| **Description** | Primary key - unique branch identifier |
| **Example Values** | "HQ", "BR1", "NYC", "LA" |
| **Usage** | FK relationship from Fact_Parts_Open_Tickets[Location] |

#### Branch

| Attribute | Value |
|-----------|-------|
| **Column Name** | Branch |
| **Data Type** | String (Text) |
| **Description** | Branch display name |
| **Example Values** | "Headquarters", "Branch 1", "New York" |
| **Usage** | Slicer labels, report grouping |

---

## dim_DateTable

**Description**: Complete date dimension for time-based analysis

**Granularity**: One row per date

**Row Count**: ~3,650+ rows (10 years)

**Source**: Generated (DAX or SQL)

**Refresh Frequency**: As-needed (static once generated)

---

### Key Columns

#### Date

| Attribute | Value |
|-----------|-------|
| **Column Name** | Date |
| **Data Type** | Date |
| **Description** | Primary key - date value |
| **Example Values** | 01/01/2024, 01/08/2026, 12/31/2026 |
| **Usage** | FK relationship from Fact_Parts_Open_Tickets[Order_Date] |

#### Year, Quarter, Month

| Column | Description | Example |
|--------|-------------|---------|
| Year | Calendar year | 2026 |
| Quarter | Quarter (1-4) | 1 (Q1) |
| Month | Month number (1-12) | 1 (January) |
| MonthName | Month name | "January" |

---

## TopN Selector

**Description**: Disconnected table for Top N filtering

**Granularity**: One row per Top N option

**Row Count**: 6 rows

**Source**: DAX calculated table (DATATABLE)

---

### Columns

#### TopN

| Attribute | Value |
|-----------|-------|
| **Column Name** | TopN |
| **Data Type** | Integer |
| **Description** | Number to filter (-1 = all) |
| **Values** | 5, 10, 15, 20, 25, -1 |
| **Usage** | Used by measures to filter customer/salesman rankings |

#### Label

| Attribute | Value |
|-----------|-------|
| **Column Name** | Label |
| **Data Type** | String (Text) |
| **Description** | Display label for slicer |
| **Values** | "Top 5", "Top 10", "Top 15", "Top 20", "Top 25", "Show All" |
| **Usage** | Slicer display |
| **Sort By** | SortOrder column |

#### SortOrder

| Attribute | Value |
|-----------|-------|
| **Column Name** | SortOrder |
| **Data Type** | Integer |
| **Description** | Ensures correct sort order |
| **Values** | 1-6 |
| **Usage** | Sort order for Label column |

---

## DAX Measures

See [DAX-MEASURES-REFERENCE.md](DAX-MEASURES-REFERENCE.md) for complete DAX code for all measures.

### Core Metrics (14 measures)

| Measure Name | Description | Data Type | Example Value |
|-------------|-------------|-----------|---------------|
| `# Parts On Order` | Total parts quantity ordered | Number | 5,234 |
| `Order Total` | Total order dollar value | Currency | $3,813,197.73 |
| `$$ not BO` | Dollar value not backordered | Currency | $3,500,000.00 |
| `Deposit` | Total deposits collected | Currency | $125,500.00 |
| `# on Back Order` | Quantity on backorder | Number | 523 |
| `Backordered $$` | Dollar value on backorder | Currency | $313,197.73 |
| `Backordered Line Count` | Count of backordered lines | Number | 156 |
| `Parts Line Count` | Total part line items | Number | 4,567 |
| `Order Count` | Total number of orders | Number | 1,121 |
| `Orders with Backordered Parts` | Orders with any backorders | Number | 89 |
| `Average Days Open` | Average days orders open | Number | 32.5 |
| `Total Backorder Impact` | Same as Backordered $$ | Currency | $313,197.73 |

### Percentage Calculations (3 measures)

| Measure Name | Description | Format | Example Value |
|-------------|-------------|---------|---------------|
| `% of Parts on Back Order` | Percent of parts backordered | Percentage | 10.0% |
| `% # of Parts by line count` | Parts per line count ratio | Percentage | 87.3% |
| `% # Backordered by Line Count` | Backorder by line count ratio | Percentage | 3.4% |

### Customer Analysis (9 measures)

See [DAX-MEASURES-REFERENCE.md](DAX-MEASURES-REFERENCE.md) for formulas.

### Salesman Analysis (6 measures)

See [DAX-MEASURES-REFERENCE.md](DAX-MEASURES-REFERENCE.md) for formulas.

### Time Intelligence (1 measure)

| Measure Name | Description | Example Usage |
|-------------|-------------|---------------|
| `Order Total Same Period Last Year` | YoY comparison | Compare Jan 2026 to Jan 2025 |

---

## Business Glossary

### Aging

**Definition**: Classification of how long an order has been open, grouped into standard buckets

**Categories**:
- **0-7 days**: New orders (green)
- **8-14 days**: Recent orders (light yellow)
- **15-30 days**: Standard aging (yellow)
- **31-60 days**: Attention needed (orange)
- **61-90 days**: High priority (dark orange)
- **90+ days**: Critical (red)

**Business Importance**: Identifies orders that may need follow-up or intervention

---

### Backorder

**Definition**: Parts that have been ordered but are not currently available in inventory

**Impact**: Delays order fulfillment, affects customer satisfaction, ties up deposits

**Measurement**: Tracked both by quantity (#_On_Back_Order) and dollar value ($$_BackOrdered)

---

### Deposit

**Definition**: Pre-payment collected from customer when order is placed

**Purpose**: Secures customer commitment, covers initial costs

**Business Rule**: Orders can have different deposit amounts, which makes them separate records

---

### Work Order

**Definition**: Special order type related to repair services

**Aging Logic**: Work Orders age from RepairOrderDetail.CreationDate (when repair work started) rather than order entry date

**Identifier**: Invoice_Type = 'Work Order'

---

### Top N Filtering

**Definition**: Dynamic filtering to show only top-ranked customers or salesmen

**Options**: Top 5, 10, 15, 20, 25, or Show All

**Purpose**: Focus analysis on most important business relationships

---

## Data Lineage

### Source Systems

```
┌─────────────────────────────────────────────────────────────────┐
│ Source System: ERP / Order Management System                   │
│                                                                  │
│  Tables:                                                         │
│  • Insalord (orders)                                            │
│  • Insalpar (parts/line items)                                  │
│  • RepairOrderDetail (work order details)                       │
│  • Customer (customer master)                                   │
│  • Salesperson (salesperson master)                             │
│  • Branch (branch master)                                       │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│ Data Warehouse: LH_Master_Data (Fabric Lakehouse)               │
│                                                                  │
│  SQL Views:                                                      │
│  • vw_Fact_Parts_Open_Tickets (V2 - Fixed Jan 7, 2026)         │
│  • vw_Fact_Parts_Open_Tickets_Details                          │
│  • dim_BranchLocation                                           │
│  • dim_DateTable                                                │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│ Semantic Model: Parts on Open Orders.SemanticModel             │
│                                                                  │
│  Tables (Import Mode):                                          │
│  • Fact_Parts_Open_Tickets                                      │
│  • Fact_Parts_Open_Tickets_Details                             │
│  • dim_BranchLocation                                           │
│  • dim_DateTable                                                │
│  • TopN Selector (calculated table)                            │
│                                                                  │
│  DAX Measures: 35 measures                                      │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│ Power BI Report: Parts on Open Orders.Report                   │
│                                                                  │
│  Pages: 4 pages (Overview, Details, Comparison, Score Card)    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Quality Notes

### V2 Data Quality Fixes (January 7, 2026)

1. **Missing Orders Fixed**: 21 orders now included (correct deposit grouping)
2. **Aging Accuracy**: 99%+ alignment with business requirements
3. **NULL Handling**: All NULL backorder quantities treated as 0
4. **Work Order Logic**: Proper fallback chain for aging dates

### Validation Rules

- **Order Count**: Should be ~1,121 orders
- **Total Dollar Variance**: <1% from old report acceptable
- **Aging Bucket Variance**: <2% per bucket acceptable
- **NULL Backorders**: Should be 0 (all converted)

---

**Document Version**: 1.0
**Last Updated**: January 8, 2026
**Created By**: Claude Code - Data Documentation Assistant
**Next Review**: March 2026
