# Complete Table Catalog

**Generated:** 2025-07-18 15:25

Comprehensive reference for all 21 tables in the data model.

## MeasuresTable

**Category:** 
**Purpose:** 
**Total Columns:** 3

**Business Attributes:**
- Value (Integer) - 
- DummyColumn (Integer) - 

---

## Data Refresh

**Category:** 
**Purpose:** 
**Total Columns:** 4

**Date Columns:**
- Date (Date)
- Time (Date)

**Business Attributes:**
- CurrentDateTime (Text) - 
- Date (Date) - 
- Time (Date) - 

---

## Price_Matrix

**Category:** 
**Purpose:** 
**Total Columns:** 24

**Numeric Columns:**
- value_from (Number) - 
- value_to (Number) - 
- Range Sort (Number) - 
- price_percent (Number) - 
- Markup (Number) - 

**Business Attributes:**
- branch (Text) - 
- franchise (Text) - 
- vendor_code (Text) - 
- vendor_name (Text) - 
- price_admin_code_type (Text) - 
- price_admin_code (Text) - 
- price_type (Text) - 
- include_exchange_part (Text) - 
- ...and 10 more attributes

---

## dim_BranchLocation

**Category:** 
**Purpose:** 
**Total Columns:** 9

**Business Attributes:**
- BranchType (Text) - 
- BranchID (Text) - 
- BranchName (Text) - 
- LocationID (Text) - 
- State (Text) - 
- City (Text) - 
- branch (Text) - 

---

## dim_Parts

**Category:** 
**Purpose:** 
**Total Columns:** 5

**Business Attributes:**
- PartNumber (Text) - 
- Description (Text) - 
- franchise (Text) - 

---

## Fact_Inventory

**Category:** 
**Purpose:** 
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
- InventoryCost (Number) - 
- BinQty (Number) - 
- QuantityOnHand (Number) - 
- BackOrderQty (Number) - 
- SellPrice1 (Number) - 
- Cost (Number) - 
- Current12MoSales (Number) - 
- Current12MoDollars (Number) - 
- ListPrice (Number) - 

**Date Columns:**
- DateCreated (Date)
- DateLastRequested (Date)

**Business Attributes:**
- PartNumber (Text) - 
- Description (Text) - 
- Returnable (Text) - 
- DateCreated (Date) - 
- DateLastRequested (Date) - 

---

## dim_Franchise

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## Fact_Part_Transactions

**Category:** 
**Purpose:** 
**Total Columns:** 32

**Key Columns:**
- CustomerKey (Integer)
- FranchiseKey (Integer)
- PartNumberKey (Integer)
- BranchKey (Integer)

**Numeric Columns:**
- Quantity (Number) - 
- SaleAmount (Number) - 
- CostAmount (Number) - 
- Margin (Number) - 
- MarginPercent (Number) - 
- Year (Number) - 
- MonthNumber (Number) - 
- SellPrice1 (Number) - 
- ListPrice (Number) - 
- ListSaleVal (Number) - 
- ...and 7 more numeric columns

**Business Attributes:**
- CustomerNo (Text) - 
- Territory (Text) - 
- PrimaryName (Text) - 
- PartNumber (Text) - 
- Type (Text) - 
- RONumber (Text) - 
- TransactionDescription (Text) - 
- CustomerTradeType (Text) - 
- ...and 2 more attributes

---

## current-tables

**Category:** 
**Purpose:** 
**Total Columns:** 14

**Business Attributes:**
- Name (Text) - 
- Model (Text) - 
- DataCategory (Text) - 
- Description (Text) - 
- StorageMode (Text) - 
- TableStorage (Text) - 
- Expression (Text) - 
- LineageTag (Text) - 
- ...and 5 more attributes

---

## current-columns

**Category:** 
**Purpose:** 
**Total Columns:** 25

**Business Attributes:**
- Name (Text) - 
- Table (Text) - 
- DataType (Text) - 
- DataCategory (Text) - 
- Description (Text) - 
- Alignment (Text) - 
- SummarizeBy (Text) - 
- ColumnStorage (Text) - 
- ...and 15 more attributes

---

## current-relationships

**Category:** 
**Purpose:** 
**Total Columns:** 16

**Business Attributes:**
- Name (Text) - 
- Relationship (Text) - 
- Model (Text) - 
- CrossFilteringBehavior (Text) - 
- FromTable (Text) - 
- FromColumn (Text) - 
- FromCardinality (Text) - 
- ToTable (Text) - 
- ...and 7 more attributes

---

## New Markup %

**Category:** 
**Purpose:** 
**Total Columns:** 2

---

## Calculator Measures

**Category:** 
**Purpose:** 
**Total Columns:** 3

**Business Attributes:**
- Value (Integer) - 
- DummyColumn (Integer) - 

---

## dim_DealerGroupCode

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## dim_Source

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## dim_SLC

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## dim_VendorCode

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## dim_DateTable

**Category:** 
**Purpose:** 
**Total Columns:** 21

**Business Attributes:**
- MonthName (Text) - 
- DayOfWeekName (Text) - 
- DayOfWeekNameShort (Text) - 
- QuarterYear (Text) - 
- DateDisplayName (Text) - 
- MonthNameShort (Text) - 
- MonthYear (Text) - 
- Date (Date) - 
- ...and 11 more attributes

---

## Range Selection

**Category:** 
**Purpose:** 
**Total Columns:** 3

---

## Range $0.01 - $0.99 New Markup

**Category:** 
**Purpose:** 
**Total Columns:** 2

---

## current-measures

**Category:** 
**Purpose:** 
**Total Columns:** 17

**Business Attributes:**
- Name (Text) - 
- Table (Text) - 
- Description (Text) - 
- DataType (Text) - 
- Expression (Text) - 
- FormatString (Text) - 
- State (Text) - 
- DisplayFolder (Text) - 
- ...and 8 more attributes

---


