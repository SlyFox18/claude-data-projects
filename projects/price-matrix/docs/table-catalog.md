# Complete Table Catalog

**Generated:** 2025-07-18 15:29

Comprehensive reference for all 21 tables in the data model.

## MeasuresTable

**Category:** Calculated Table
**Purpose:** Container table for DAX measures (Power BI calculated table)
**Total Columns:** 3

**Business Attributes:**
- Value (Integer) - Business data attribute
- DummyColumn (Integer) - Business data attribute

---

## Data Refresh

**Category:** Data Table
**Purpose:** System table tracking data refresh timestamps
**Total Columns:** 4

**Date Columns:**
- Date (Date)
- Time (Date)

**Business Attributes:**
- CurrentDateTime (Text) - Business data attribute
- Date (Date) - Business data attribute
- Time (Date) - Business data attribute

---

## Price_Matrix

**Category:** Configuration Table
**Purpose:** Price range configuration with target margin percentages
**Total Columns:** 24

**Numeric Columns:**
- value_from (Number) - Business data attribute
- value_to (Number) - Business data attribute
- Range Sort (Number) - Business data attribute
- price_percent (Number) - Business data attribute
- Markup (Number) - Business data attribute

**Business Attributes:**
- branch (Text) - Branch identifier or name
- franchise (Text) - Franchise or brand identifier
- vendor_code (Text) - Business data attribute
- vendor_name (Text) - Business data attribute
- price_admin_code_type (Text) - Business data attribute
- price_admin_code (Text) - Business data attribute
- price_type (Text) - Business data attribute
- include_exchange_part (Text) - Business data attribute
- ...and 10 more attributes

---

## dim_BranchLocation

**Category:** Dimension Table
**Purpose:** Branch and location master data for geographic analysis
**Total Columns:** 9

**Business Attributes:**
- BranchType (Text) - Branch identifier or name
- BranchID (Text) - Branch identifier or name
- BranchName (Text) - Branch identifier or name
- LocationID (Text) - Business data attribute
- State (Text) - Geographic state
- City (Text) - Geographic city
- branch (Text) - Branch identifier or name

---

## dim_Parts

**Category:** Dimension Table
**Purpose:** Part master data with descriptions and franchise assignments
**Total Columns:** 5

**Business Attributes:**
- PartNumber (Text) - Unique part identifier
- Description (Text) - Descriptive text
- franchise (Text) - Franchise or brand identifier

---

## Fact_Inventory

**Category:** Fact Table
**Purpose:** Core inventory and sales data with 12-month rolling metrics
**Total Columns:** 23

**Key Columns:**
- BranchKey (Integer)
- PartNumberKey (Integer)
- FranchiseKey (Integer)
- VendorCodeKey (Integer)
- SourceKey (Integer)
- SLCKey (Integer)
- DealerGroupKey (Integer)
- CommodityCodeKey (Integer)

**Numeric Columns:**
- InventoryCost (Number) - Business data attribute
- BinQty (Number) - Business data attribute
- QuantityOnHand (Number) - Transaction quantity
- BackOrderQty (Number) - Business data attribute
- SellPrice1 (Number) - Business data attribute
- Cost (Number) - Business data attribute
- Current12MoSales (Number) - Rolling 12-month sales quantity
- Current12MoDollars (Number) - Rolling 12-month sales revenue
- ListPrice (Number) - Manufacturer list price

**Date Columns:**
- DateCreated (Date)
- DateLastRequested (Date)

**Business Attributes:**
- PartNumber (Text) - Unique part identifier
- Description (Text) - Descriptive text
- Returnable (Text) - Business data attribute
- DateCreated (Date) - Business data attribute
- DateLastRequested (Date) - Business data attribute

---

## dim_Franchise

**Category:** Dimension Table
**Purpose:** Franchise master data for organizational reporting
**Total Columns:** 3

---

## Fact_Part_Transactions

**Category:** Fact Table
**Purpose:** Individual sales transactions with customer and margin details
**Total Columns:** 32

**Key Columns:**
- CustomerKey (Integer)
- FranchiseKey (Integer)
- PartNumberKey (Integer)
- BranchKey (Integer)

**Numeric Columns:**
- Quantity (Number) - Transaction quantity
- SaleAmount (Number) - Transaction sales value
- CostAmount (Number) - Business data attribute
- Margin (Number) - Transaction profit margin dollars
- MarginPercent (Number) - Transaction profit margin dollars
- Year (Number) - Business data attribute
- MonthNumber (Number) - Business data attribute
- SellPrice1 (Number) - Business data attribute
- ListPrice (Number) - Manufacturer list price
- ListSaleVal (Number) - Business data attribute
- ...and 7 more numeric columns

**Business Attributes:**
- CustomerNo (Text) - Customer identifier
- Territory (Text) - Business data attribute
- PrimaryName (Text) - Business data attribute
- PartNumber (Text) - Unique part identifier
- Type (Text) - Business data attribute
- RONumber (Text) - Business data attribute
- TransactionDescription (Text) - Descriptive text
- CustomerTradeType (Text) - Business data attribute
- ...and 2 more attributes

---

## current-tables

**Category:** Metadata Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 14

**Business Attributes:**
- Name (Text) - Business data attribute
- Model (Text) - Business data attribute
- DataCategory (Text) - Business data attribute
- Description (Text) - Descriptive text
- StorageMode (Text) - Business data attribute
- TableStorage (Text) - Business data attribute
- Expression (Text) - Business data attribute
- LineageTag (Text) - Business data attribute
- ...and 5 more attributes

---

## current-columns

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 25

**Business Attributes:**
- Name (Text) - Business data attribute
- Table (Text) - Business data attribute
- DataType (Text) - Business data attribute
- DataCategory (Text) - Business data attribute
- Description (Text) - Descriptive text
- Alignment (Text) - Business data attribute
- SummarizeBy (Text) - Business data attribute
- ColumnStorage (Text) - Business data attribute
- ...and 15 more attributes

---

## current-relationships

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 16

**Business Attributes:**
- Name (Text) - Business data attribute
- Relationship (Text) - Business data attribute
- Model (Text) - Business data attribute
- CrossFilteringBehavior (Text) - Business data attribute
- FromTable (Text) - Business data attribute
- FromColumn (Text) - Business data attribute
- FromCardinality (Text) - Business data attribute
- ToTable (Text) - Business data attribute
- ...and 7 more attributes

---

## New Markup %

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 2

---

## Calculator Measures

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

**Business Attributes:**
- Value (Integer) - Business data attribute
- DummyColumn (Integer) - Business data attribute

---

## dim_DealerGroupCode

**Category:** Dimension Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

---

## dim_Source

**Category:** Dimension Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

---

## dim_SLC

**Category:** Dimension Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

---

## dim_VendorCode

**Category:** Dimension Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

---

## dim_DateTable

**Category:** Dimension Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 21

**Business Attributes:**
- MonthName (Text) - Business data attribute
- DayOfWeekName (Text) - Business data attribute
- DayOfWeekNameShort (Text) - Business data attribute
- QuarterYear (Text) - Business data attribute
- DateDisplayName (Text) - Business data attribute
- MonthNameShort (Text) - Business data attribute
- MonthYear (Text) - Business data attribute
- Date (Date) - Business data attribute
- ...and 11 more attributes

---

## Range Selection

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 3

---

## Range $0.01 - $0.99 New Markup

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 2

---

## current-measures

**Category:** Data Table
**Purpose:** Supporting table for specialized analysis or system functions
**Total Columns:** 17

**Business Attributes:**
- Name (Text) - Business data attribute
- Table (Text) - Business data attribute
- Description (Text) - Descriptive text
- DataType (Text) - Business data attribute
- Expression (Text) - Business data attribute
- FormatString (Text) - Business data attribute
- State (Text) - Geographic state
- DisplayFolder (Text) - Business data attribute
- ...and 8 more attributes

---


