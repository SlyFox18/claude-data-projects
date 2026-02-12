# Data Dictionary - Inspections Report

**Report Name:** South Plains Implement - Inspections Report  
**Last Updated:** November 2025  
**Data Model:** Star Schema with 3 Fact Tables, 4 Dimension Tables, 1 Calculated Table, 1 External Table

---

## 📋 Table of Contents

1. [Fact Tables](#fact-tables)
   - [Fact_LaborJobSummary](#fact_laborjobsummary)
   - [Fact_PendingInspections](#fact_pendinginspections)
   - [Fact_WorkOrderParts](#fact_workorderparts)

2. [Dimension Tables](#dimension-tables)
   - [dim_BranchLocation](#dim_branchlocation)
   - [dim_CustomerList](#dim_customerlist)
   - [dim_DateTable](#dim_datetable)
   - [dim_Parts](#dim_parts)

3. [Calculated Tables](#calculated-tables)
   - [ServiceRecommendations](#servicerecommendations)

4. [External Tables](#external-tables)
   - [Inspection Goals](#inspection-goals)

5. [Relationships](#relationships)

---

# Fact Tables

## Fact_LaborJobSummary

**Purpose:** Complete job-level inspection analytics with labor hours and work order context  
**Grain:** One row per job code per work order  
**Refresh Time:** ~3 minutes  
**Source Tables:** Raw_wkothsub, Raw_wkmechwk, Raw_WKROFILE  
**Row Count:** ~500,000+ rows (6 years of history, 2023+)

### Business Use Cases
- Inspection tracking with complete financial analysis
- Labor analytics with Est/Act/Inv cycle tracking
- Parts financial analysis parallel to labor
- Work order intelligence and status tracking
- Operational efficiency through hours variance analysis
- Revenue classification and non-revenue identification
- Warranty integration with claim tracking
- Goals performance foundation

### Column Definitions

#### Core Identification
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **BranchCode** | Text | Work order branch/location identifier | Territory analysis, branch filtering |
| **WorkOrderNumber** | Text | Work order number | Work order tracking, drill-through |
| **JobCode** | Text | Service job code classification | Job type analysis, inspection identification |
| **JobType** | Text | Job type indicator (Retail/Internal/Warranty/etc.) | Revenue classification, business type analysis |
| **InvoiceNumber** | Text | Invoice number for billing integration | Invoice tracking, payment analysis |
| **InvoiceDate** | DateTime | Invoice date | Billing cycle analysis, revenue timing |
| **ClaimNumber** | Text | Warranty/claim number | Warranty analysis, claim tracking |

#### Financial - Labor
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **EstimatedLaborAmount** | Currency | Estimated labor value | Estimate accuracy, variance analysis |
| **ActualLaborAmount** | Currency | Actual labor cost | Cost tracking, margin analysis |
| **InvoicedLaborAmount** | Currency | Invoiced labor amount | Revenue recognition, financial reporting |

#### Financial - Parts
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **EstimatedPartsAmount** | Currency | Estimated parts value | Parts estimate accuracy |
| **ActualPartsAmount** | Currency | Actual parts cost | Parts cost tracking |
| **InvoicedPartsAmount** | Currency | Invoiced parts amount | Parts revenue tracking |

#### Hours Tracking
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **EstimatedHours** | Decimal | Estimated labor hours | Efficiency planning, estimate accuracy |
| **ActualHoursWorked** | Decimal | SUM of all technician hours worked (aggregated from Raw_wkmechwk) | True time tracking, productivity analysis |
| **InvoicedHours** | Decimal | SUM of all invoiced hours | Billing hour analysis |
| **HoursVariance** | Decimal | Actual hours - Estimated hours | Efficiency metric, estimate accuracy |

#### Work Order Context
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **WorkOrderStatus** | Text | Work order progress status | Status tracking, workflow analysis |
| **WorkOrderCreationDate** | DateTime | Work order creation date | Aging analysis, timeline tracking |
| **WorkOrderClosedDate** | DateTime | Work order closure date | Cycle time analysis |

#### Calculated Fields
| Column | Data Type | Description | Business Logic |
|--------|-----------|-------------|----------------|
| **IsInspection** | Boolean | Inspection job flag | TRUE if JobCode in 111 inspection codes list |
| **TotalInvoicedAmount** | Currency | Labor + Parts total | InvoicedLaborAmount + InvoicedPartsAmount |
| **TotalEstimatedAmount** | Currency | Labor + Parts estimate | EstimatedLaborAmount + EstimatedPartsAmount |
| **IsPending** | Boolean | Pending work order flag | TRUE if WorkOrderStatus IN ('wip', 'bi', 'va') |

#### Additional Business Flags
| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **IsMachineDown** | Boolean | Machine downtime indicator | Priority tracking, urgency analysis |
| **WorkCategory** | Text | Work categorization | Service type classification |
| **JobStatus** | Text | Current job status | Job tracking, completion analysis |
| **IsNonRevenue** | Boolean | Non-revenue job flag | Revenue vs non-revenue analysis |
| **IsFieldRepair** | Boolean | Field service indicator | Field vs shop analysis |
| **IsStandardLabor** | Boolean | Standard labor rate indicator | Rate type analysis |
| **ModifiedDate** | DateTime | Last modification date | Audit trail, incremental refresh key |

### Architectural Notes
- **Grain:** Job-level (one row per job code per work order)
- **Aggregation:** wkmechwk aggregated from punch-level to job-level before join
- **Join Strategy:** LEFT OUTER joins preserve all jobs (not all have labor/status)
- **Inspection Codes:** Embedded list of 111 inspection codes for IsInspection flag
- **Incremental Refresh:** Uses ModifiedDate field (2023+ scope)

---

## Fact_PendingInspections

**Purpose:** Track work orders with inspection job codes that are not yet invoiced  
**Grain:** One row per pending inspection work order  
**Refresh Time:** ~1.5 minutes  
**Source Tables:** Raw_RepairOrderDetail, Raw_TechnicianPunchedDetail  
**Row Count:** ~50-200 rows (typically small dataset)

### Business Use Cases
- Pending queue management and prioritization
- Workload forecasting and capacity planning
- Timeline monitoring and aging analysis
- Resource planning and shop capacity
- Performance analysis (predicted vs actual outcomes)

### Column Definitions

| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **BranchCode** | Text | Work order branch location | Branch filtering, territory analysis |
| **WorkOrderNumber** | Text | Work order number | Work order tracking, identification |
| **JobCode** | Text | Inspection job code | Job type analysis, inspection categorization |
| **JobType** | Text | Job type indicator | Service type classification |
| **StatusDisplay** | Text | Business status | "In Process" or "WIP Finished Not Invoiced" |
| **ROProgressStatus** | Text | System progress status code | Technical status tracking |
| **CreationDate** | DateTime | When work order was created | Aging analysis, queue management |
| **FirstLaborPunch** | DateTime | When work started (if started) | Work start tracking |
| **LastLaborPunch** | DateTime | Most recent labor activity | Activity recency, stale work detection |
| **DaysSinceCreation** | Number | Age in days | Aging analysis, priority calculation |
| **HoursWorked** | Decimal | Total hours worked so far (aggregated from TechnicianPunchedDetail) | Progress tracking, capacity analysis |
| **IsInspection** | Boolean | Always TRUE (table only contains inspections) | Simplifies DAX measures |

### Architectural Notes
- **Grain:** Work order level (simpler than Fact_LaborJobSummary)
- **Status Filter:** Excludes "Invoiced" (those are in Fact_LaborJobSummary)
- **Hours Aggregation:** Pre-aggregated from TechnicianPunchedDetail
- **Join Type:** Left outer join for hours (some WOs may have no hours yet)
- **Inspection Codes:** Same 111 codes as Fact_LaborJobSummary for consistency

### Key Insights
- **Red-highlighted rows** (LastLaborPunch = 1/1/1900): No recent activity - stale work orders requiring attention
- **Orange-highlighted rows**: Older creation dates - aging work orders
- **Capacity Metric:** Total hours worked shows shop capacity utilization

---

## Fact_WorkOrderParts

**Purpose:** Parts sold on inspection work orders with complete financial detail  
**Grain:** One row per part per invoice  
**Refresh Time:** ~10 minutes  
**Source Tables:** Raw_InTrans, Raw_wkothsub  
**Row Count:** ~100,000-500,000 rows (6 years of parts transactions)

### Business Use Cases
- Parts revenue analysis by inspection type
- Parts inventory intelligence for inspections
- Pricing and margin analysis
- Parts recommendation patterns
- Cross-sell opportunity identification

### Column Definitions

| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **BranchCode** | Text | Branch location | Territory analysis, branch filtering |
| **InvoiceNumber** | Text | Invoice number (joins to InTrans.RONumber) | Invoice tracking, parts grouping |
| **TransactionDate** | DateTime | Parts transaction date | Time series analysis, trend tracking |
| **PartNumber** | Text | Part number identifier | Part identification, joins to dim_Parts |
| **Description** | Text | Part description (often "Inv No. 1234567" - not useful) | Use dim_Parts.Description instead |
| **Franchise** | Text | Manufacturer/brand | Franchise analysis, vendor tracking |
| **Quantity** | Number | Parts quantity | Volume analysis, inventory tracking |
| **SaleValue** | Currency | Parts sale value | Revenue tracking, pricing analysis |
| **CostValue** | Currency | Parts cost value | Margin analysis, profitability |
| **SellPrice** | Currency | Unit selling price | Pricing analysis |
| **ListPrice** | Currency | Manufacturer list price | Discount analysis, pricing strategy |
| **CustomerNumber** | Text | Customer identifier | Customer analysis |
| **TradeType** | Text | Trade type classification | Business type segmentation |
| **ModifiedDate** | DateTime | Last modification date | Audit trail |

### Architectural Notes
- **Critical Join Fix:** InTrans joins on INVOICE NUMBER (not work order number)
- **Franchise Filter:** Excludes "ZP" franchise (per business rules)
- **Join Strategy:** Inner join to inspection invoice numbers from Raw_wkothsub
- **Description Field:** Not useful in InTrans - use dim_Parts for actual part descriptions
- **Performance:** 10-minute refresh due to large dataset and complex joins

### Known Issues & Solutions
- **Description Problem:** InTrans.Description contains "Inv No. 1234567" (useless)
- **Solution:** Join to dim_Parts using PartNumber to get actual part descriptions
- **Validation:** Row count should be 100k-500k, not 186 (indicates correct join)

---

# Dimension Tables

## dim_BranchLocation

**Purpose:** Branch location master with geographic and operational intelligence  
**Grain:** One row per operational branch  
**Refresh Time:** <1 minute  
**Source Table:** Raw_BranchOperational  
**Row Count:** ~15-20 branches

### Usage in Inspections Report
**Simple Usage:** Primarily used for branch filtering and territory analysis  
**Future Potential:** Rich classification fields available for advanced analytics

### Column Definitions

#### Primary Keys & Identification
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **BranchKey** | Integer | Surrogate key for fact table joins | Primary key for relationships |
| **Branch** | Text | Professional display name (e.g., "1 - Seminole") | Report filtering, visual display |
| **BranchType** | Text | Operational classification (Main Branch/IS Shop/Set-Up Shop/CP Shop) | Branch categorization |
| **BranchID** | Text | System branch identifier | Technical identifier |
| **BranchName** | Text | Operational branch name | Alternative display name |
| **LocationID** | Text | Location system identifier | Location tracking |

#### Geographic Information
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **State** | Text | State (TX/NM) | Territory filtering |
| **City** | Text | City name | Geographic analysis |

#### Operational Intelligence (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **ServiceCapacity** | Text | Service capability (Full Service/Inspection Specialist/Setup Specialist/Pickup Specialist) | Service type analysis |
| **MarketPresence** | Text | Market classification (Texas Primary/New Mexico Primary/Secondary/Extended) | Market analysis |
| **TerritoryCoverage** | Text | Coverage scope (Regional Hub/Service Extension/Local Service) | Territory planning |
| **OperationalPriority** | Number | Priority score (1-10, higher = more critical) | Resource allocation |
| **RegionalClassification** | Text | Regional market (West Texas/Central Texas/Southern New Mexico/Border Region) | Regional analysis |
| **ServiceHours** | Text | Operating hours (Extended Hours/Business Hours/Limited Hours) | Scheduling analysis |
| **DistanceFromHub** | Text | Distance classification (Hub Location/Near Hub/Remote Location) | Logistics planning |
| **DataQualityScore** | Number | Data completeness score (0-100) | Data quality monitoring |

### Architectural Notes
- **Smart Filtering:** Excludes Hourly (H-prefix) and Salary (S-prefix) branches
- **Includes:** All numbered branches (1, 2, 3, etc.) and specialized shops (1I, 1S, 1C, etc.)
- **Seminole Fix:** Previous version incorrectly excluded branch "1" - now included
- **Professional Naming:** Leading zeros removed ("1 - Seminole" vs "01 - Seminole")

---

## dim_CustomerList

**Purpose:** Central customer dimension with financial and marketing intelligence  
**Grain:** One row per customer account  
**Refresh Time:** <2 minutes  
**Source Tables:** Raw_ARMaster, Raw_Contact, Raw_ArMaster_Customer, Raw_ArMaster_Contact  
**Row Count:** ~5,000-10,000 customers + 8 special system customers

### Usage in Inspections Report
**Simple Usage:** Primarily used for customer name display  
**Future Potential:** Rich segmentation, financial health, and marketing intelligence available

### Column Definitions

#### Primary Keys & Identification
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **CustomerKey** | Integer | Surrogate key for fact table joins | Primary key for relationships |
| **AccountNumber** | Text | Primary business account identifier | Customer identification |
| **AccountNumberText** | Text | Text version for string-based lookups | Fact table joins |
| **CustomerNumber** | Text | Secondary customer identifier | Alternative identification |
| **CustomerNumberText** | Text | Text version of customer number | Alternative lookups |
| **ContactID** | Text | Contact system identifier | System integration |

#### Customer Names & Display
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **DisplayName** | Text | Primary display name for reports | **Main field used in Inspections Report** |
| **CustomerName** | Text | Core customer name | Report display |
| **PrimaryName** | Text | Business primary name | Alternative display |
| **CompanyName** | Text | Company name for corporate accounts | Company identification |
| **FirstName** | Text | Individual first name | Personal accounts |
| **LastName** | Text | Individual last name | Personal accounts |
| **FullName** | Text | Complete individual name | Personal account display |

#### Business Classification (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **TradeType** | Text | Business relationship code (R=Retail, F=Fleet, I=Internal, W=Warranty, etc.) | Customer segmentation |
| **CustomerTypeDescription** | Text | Trade type description | Business type analysis |
| **StatusCode** | Text | Account status code | Status tracking |
| **AccountStatus** | Text | Account status description (Active/Inactive/Hold/Closed) | Status filtering |
| **AccountType** | Text | Account type classification | Account categorization |
| **Territory** | Text | Sales territory assignment | Territory analysis |

#### Financial Information (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **CreditLimit** | Currency | Credit limit amount | Financial analysis |
| **AccountBalance** | Currency | Current account balance | AR tracking |
| **Aging30** | Currency | 30-day aging amount | AR aging analysis |
| **Aging60** | Currency | 60-day aging amount | AR aging analysis |
| **Aging90** | Currency | 90+ day aging amount | AR aging analysis |
| **CreditTerm** | Text | Payment terms | Terms analysis |
| **PaymentMethod** | Text | Preferred payment method | Payment analysis |
| **PriceLevel** | Text | Pricing level assignment | Pricing strategy |

#### Contact Information (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **Street** | Text | Primary address line 1 | Mailing, logistics |
| **Street2** | Text | Secondary address line | Address completion |
| **City** | Text | City | Geographic analysis |
| **State** | Text | State/province | Territory analysis |
| **PostalCode** | Text | ZIP/postal code | Geographic segmentation |
| **Country** | Text | Country | International accounts |
| **Email** | Text | Email address | Digital communication |
| **PrimaryPhone** | Text | Primary phone number | Contact management |
| **BusinessPhone** | Text | Business phone number | Business contact |
| **MobilePhone** | Text | Mobile phone number | Mobile contact |
| **HomePhone** | Text | Home phone number | Personal contact |

#### Business Intelligence Flags (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **IsCompany** | Boolean | Company vs individual flag | Business type filtering |
| **HasCreditLimit** | Boolean | Credit limit availability flag | Credit analysis |
| **Account_Class** | Text | Account classification | Classification analysis |
| **ContactClass** | Text | Contact classification | Contact categorization |
| **IsKeyCustomer** | Boolean | Key customer designation | VIP identification |
| **CreditUtilization** | Decimal | Credit utilization ratio (0-1) | Financial health |
| **FinancialRiskLevel** | Text | Risk assessment (Minimal/Low/Medium/High) | Risk management |
| **HasOverdueBalance** | Boolean | Overdue balance indicator | Collections |
| **CustomerTier** | Text | Tier classification (Key Account/Premium/Standard/Basic) | Segmentation |
| **IsHighValue** | Boolean | High-value customer flag | Prioritization |
| **IsMarketingEligible** | Boolean | Marketing campaign eligibility | Marketing targeting |
| **PreferredContactMethod** | Text | Optimal communication method (Email/Mobile/Business Phone/Mail) | Communication strategy |
| **DiscountType** | Text | Discount classification | Pricing analysis |
| **TaxExemptNumber** | Text | Tax exemption number | Tax handling |
| **CustomerNotes** | Text | Customer service notes | Service notes |
| **DataQualityScore** | Number | Data completeness score (0-100) | Data quality monitoring |

### Special System Customers
**Purpose:** Handle work order fallback scenarios  
**CustomerKey Range:** -1 to -8 (negative keys for system customers)

| CustomerKey | AccountNumber | DisplayName | TradeType | Purpose |
|-------------|---------------|-------------|-----------|---------|
| -1 | UNKNOWN | Unknown Customer | U | Unknown customer fallback |
| -2 | INTERNAL | Internal Work | I | Internal work orders |
| -3 | WARRANTY | Warranty Work | W | Warranty claim work |
| -4 | FLEET | Fleet Account | F | Fleet account work |
| -5 | EXCESS | Excess Work | E | Excess inventory sales |
| -6 | POLICY | Policy Work | P | Policy-related work |
| -7 | BILLING | Billing Account | B | Billing adjustments |
| -8 | MISC | Miscellaneous | S | Miscellaneous work |

### Architectural Notes
- **Join Strategy:** INNER JOINs for data completeness (monitor for missing customers)
- **Naming Priority:** Company name takes precedence, falls back to "LastName, FirstName"
- **System Integration:** AccountNumberText field critical for work order customer assignment
- **Special Records:** Negative CustomerKey values handle system scenarios

---

## dim_DateTable

**Purpose:** Standard calendar dimension for time-based filtering and analysis  
**Grain:** One row per date  
**Refresh Time:** <1 minute  
**Source:** Generated date dimension  
**Date Range:** Typically 2020-2030 (10-year span)

### Usage in Inspections Report
**Simple Usage:** Used for basic date filtering and time-based relationships  
**Future Potential:** Rich calendar attributes available for advanced time intelligence

### Column Definitions

#### Primary Date Fields
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **Date** | Date | Calendar date (primary key) | **Main field used for filtering** |
| **Year** | Integer | Calendar year (e.g., 2025) | Year filtering |
| **Quarter** | Integer | Calendar quarter (1-4) | Quarter analysis |
| **Month** | Integer | Calendar month (1-12) | Month filtering |
| **MonthName** | Text | Month name (e.g., "January") | Month display |
| **Day** | Integer | Day of month (1-31) | Day analysis |
| **DayOfWeek** | Integer | Day of week (1=Sunday, 7=Saturday) | Weekday analysis |
| **DayName** | Text | Day name (e.g., "Monday") | Weekday display |

#### Standard Calendar Attributes (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **WeekOfYear** | Integer | ISO week number (1-53) | Weekly analysis |
| **QuarterName** | Text | Quarter display (e.g., "Q1 2025") | Quarter labeling |
| **MonthYear** | Text | Month-year display (e.g., "Jan 2025") | Time series labels |
| **IsWeekend** | Boolean | Weekend flag (Saturday/Sunday) | Weekend analysis |
| **IsHoliday** | Boolean | Holiday indicator | Holiday analysis |
| **FiscalYear** | Integer | Fiscal year (if different from calendar) | Fiscal reporting |
| **FiscalQuarter** | Integer | Fiscal quarter | Fiscal analysis |
| **FiscalMonth** | Integer | Fiscal month | Fiscal analysis |
| **YearMonth** | Text | YYYY-MM format for sorting | Time series sorting |
| **IsCurrentMonth** | Boolean | Current month flag | Current period highlighting |
| **IsCurrentYear** | Boolean | Current year flag | Current period highlighting |

### Architectural Notes
- **Primary Key:** Date field
- **Relationships:** Links to all date fields in fact tables (CreationDate, InvoiceDate, TransactionDate, etc.)
- **Simple Design:** Standard calendar dimension following best practices
- **Performance:** Pre-calculated fields enable fast time intelligence
- **Extensible:** Additional attributes can be added without breaking existing relationships

---

## dim_Parts

**Purpose:** Master parts dimension with inventory, pricing, and sales intelligence  
**Grain:** One row per unique part number  
**Refresh Time:** <2 minutes  
**Source Table:** jdis_Part_Information  
**Row Count:** ~50,000-100,000 parts + 1 special record

### Usage in Inspections Report
**Simple Usage:** Primarily used for part description lookup (Description field)  
**Future Potential:** Rich inventory, pricing, and business classification available

### Column Definitions

#### Primary Keys & Identification
| Column | Data Type | Description | Inspections Report Use |
|--------|-----------|-------------|------------------------|
| **PartNumberKey** | Integer | Surrogate key for fact table joins | Primary key for relationships |
| **PartNumber** | Text | Business key for lookups | Part identification |
| **Description** | Text | Part description | **Main field used - replaces useless InTrans.Description** |
| **Franchise** | Text | Manufacturer/brand | Brand identification |

#### Business Filter Columns (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **Source** | Text | Source classification | Source filtering |
| **SLC** | Text | SLC classification | SLC filtering |
| **DealerGroupCode** | Text | Dealer group identifier | Dealer group analysis |
| **CommodityCode** | Text | Commodity classification | Commodity filtering |
| **VendorCode** | Text | Vendor identifier | Vendor analysis |

#### Inventory Intelligence (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **QuantityOnHand** | Number | Current stock level | Stock availability |
| **BackOrderQty** | Number | Backorder quantity | Backorder tracking |
| **StockStatus** | Text | Calculated status (In Stock/Out of Stock/Backordered) | Availability filtering |
| **IsAvailable** | Boolean | Availability flag (QuantityOnHand > 0) | Quick availability check |

#### Pricing Information (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **InventoryCost** | Currency | Inventory cost value | Cost analysis |
| **SellPrice1** | Currency | Primary selling price | Price analysis |
| **ListPrice** | Currency | Manufacturer list price | MSRP comparison |

#### Sales & Activity (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **Current12MoSales** | Number | 12-month sales quantity | Sales activity indicator |
| **HasRecentSales** | Boolean | Sales activity flag | Obsolescence detection |
| **ActivityStatus** | Text | Activity description (Active/No Recent Sales) | Activity filtering |

#### Operational Flags (Available but Not Currently Used)
| Column | Data Type | Description | Future Use Potential |
|--------|-----------|-------------|---------------------|
| **Returnable** | Text | Returnable indicator (Y/N) | Returns processing |
| **IsReturnable** | Boolean | Boolean conversion of Returnable | Easier filtering |
| **IsHighValue** | Boolean | High-value flag (InventoryCost >= $500) | Value-based filtering |

### Special System Record
**Purpose:** Handle missing or unknown parts  
**PartNumberKey:** -1 (negative key for system record)

| Field | Value | Purpose |
|-------|-------|---------|
| PartNumberKey | -1 | System record identifier |
| PartNumber | "UNKNOWN" | Unknown part fallback |
| Description | "Unknown Part" | Display for unknown parts |
| All other fields | Default/zero values | Ensures no NULL issues |

### Architectural Notes
- **Critical Use Case:** Fact_WorkOrderParts.Description is useless ("Inv No. 1234567")
- **Solution:** Join Fact_WorkOrderParts to dim_Parts to get actual part descriptions
- **Deduplication:** Distinct by PartNumber ensures one row per part
- **Data Quality:** Blank/invalid records removed
- **Performance:** Strategic column selection for essential business value

---

# Calculated Tables

## ServiceRecommendations

**Purpose:** Predictive analytics - suggest services commonly performed with inspections  
**Grain:** One row per inspection type + recommended service combination  
**Refresh:** Calculated at model refresh time (not runtime)  
**Source:** Fact_LaborJobSummary (DAX calculated table)  
**Row Count:** ~100-500 recommendations (varies by data)

### Business Use Cases
- **Proactive Selling:** Recommend services when customer comes for inspection
- **Advisor Training:** Teach service advisors what to look for
- **Revenue Optimization:** Don't miss common repair opportunities
- **Parts Pre-staging:** Stock commonly needed parts
- **Technician Training:** Pattern recognition for inspection-related issues

### Column Definitions

| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **JobCode** | Text | Pending inspection job code | Which inspection type |
| **JobType** | Text | Job type of the recommendation | Type of recommended service |
| **CompletedInspections** | Integer | Total inspections of this type historically completed | Baseline count |
| **TimesAdded** | Integer | How many times this service was added to that inspection type | Frequency count |
| **TotalLabor** | Currency | Total revenue from this service historically | Revenue potential |

### Calculated Metrics (in DAX)

```dax
// Frequency percentage
Frequency % = 
[TimesAdded] / [CompletedInspections]

// Average labor per occurrence
Avg Labor = 
[TotalLabor] / [TimesAdded]
```

### Algorithm Logic

**For each pending inspection code:**
1. Find all completed work orders with this inspection
2. Identify other services performed on those work orders
3. Calculate:
   - **TimesAdded:** How many work orders had this service
   - **CompletedInspections:** Total inspections of this type
   - **Frequency %:** (TimesAdded / CompletedInspections) × 100
   - **TotalLabor:** Sum of revenue from this service
4. Return recommendations with frequency > threshold (typically >10%)

### Example Record

```
Inspection: IS-TRACTOR INSPECT
Recommended Service: LUBRICATE IMPLEMENT
CompletedInspections: 100
TimesAdded: 73
Frequency %: 73%
TotalLabor: $2,850
Avg Labor: $39
```

**Business Interpretation:** When a customer comes in for a tractor inspection, there's a 73% chance they also need implement lubrication, which historically generates $39 per occurrence.

### Architectural Notes
- **Calculated at Refresh:** Table is generated when model refreshes (not live)
- **Performance:** Pre-calculated for fast dashboard rendering
- **Historical Analysis:** Based on Fact_LaborJobSummary completed inspections
- **Filtering:** Only services with meaningful frequency included
- **Validation:** Cross-check recommendations with service advisors for accuracy

---

# External Tables

## Inspection Goals

**Purpose:** Monthly inspection targets by branch location  
**Source:** Excel file "Inspection Goals"  
**Refresh:** Manual update (monthly or quarterly)  
**Grain:** One row per branch per period  

### Column Definitions

| Column | Data Type | Description | Business Use |
|--------|-----------|-------------|--------------|
| **LOCATION** | Text | Branch location identifier | Joins to dim_BranchLocation.LocationID |
| **Goal** | Integer | Target number of inspections for the period | Performance target |
| **Period** | Text/Date | Goal period (e.g., "Q1 2025", "January 2025") | Time period for goal |

### Usage in Inspections Report

**Goals Page (Page 3):**
- Compare actual inspections vs goals
- Calculate Performance % = (Actual / Goal) × 100
- Color-coding: Green ≥100%, Yellow 90-99%, Red <90%
- Branch manager accountability tracking

**Home Page (Page 1):**
- Goal line overlay on performance bar chart
- Quick visual identification of branches above/below target

### Relationship

```
Inspection Goals[LOCATION] → dim_BranchLocation[LocationID]
```

### Data Management

**Update Frequency:** Monthly or quarterly (per management)  
**Ownership:** Branch managers or operations management  
**Format:** Excel file uploaded to Power BI  
**Validation:** Ensure all active branches have goals defined  

### Architectural Notes
- **Simple Structure:** Intentionally simple for easy management updates
- **Excel Source:** Allows non-technical users to update goals
- **No History:** Current goals only (historical analysis uses Fact_LaborJobSummary)
- **Flexible Periods:** Can accommodate monthly, quarterly, or annual goals

---

# Relationships

## Star Schema Design

```
                    dim_DateTable
                         |
                    [Date relationships]
                         |
        +----------------+----------------+
        |                |                |
  InvoiceDate    CreationDate     TransactionDate
        |                |                |
        |                |                |
   Fact_Labor      Fact_Pending    Fact_WorkOrder
   JobSummary      Inspections         Parts
        |                |                |
        +--------+-------+-------+--------+
                 |               |
            BranchCode      PartNumber
                 |               |
        dim_BranchLocation  dim_Parts
                 
        
   CustomerNumber/AccountNumber
                 |
        dim_CustomerList
        
        
   Inspection Goals[LOCATION]
                 |
   dim_BranchLocation[LocationID]
```

## Relationship Details

### Fact_LaborJobSummary Relationships

| From Table | From Column | To Table | To Column | Cardinality | Cross Filter |
|------------|-------------|----------|-----------|-------------|--------------|
| Fact_LaborJobSummary | BranchCode | dim_BranchLocation | LocationID | Many-to-One | Single |
| Fact_LaborJobSummary | InvoiceDate | dim_DateTable | Date | Many-to-One | Single |
| Fact_LaborJobSummary | WorkOrderCreationDate | dim_DateTable | Date | Many-to-One | Single (Inactive) |
| Fact_LaborJobSummary | WorkOrderClosedDate | dim_DateTable | Date | Many-to-One | Single (Inactive) |

**Note:** Multiple date relationships exist but only InvoiceDate is active by default. Use USERELATIONSHIP() in DAX for other date contexts.

### Fact_PendingInspections Relationships

| From Table | From Column | To Table | To Column | Cardinality | Cross Filter |
|------------|-------------|----------|-----------|-------------|--------------|
| Fact_PendingInspections | BranchCode | dim_BranchLocation | LocationID | Many-to-One | Single |
| Fact_PendingInspections | CreationDate | dim_DateTable | Date | Many-to-One | Single |
| Fact_PendingInspections | FirstLaborPunch | dim_DateTable | Date | Many-to-One | Single (Inactive) |
| Fact_PendingInspections | LastLaborPunch | dim_DateTable | Date | Many-to-One | Single (Inactive) |

### Fact_WorkOrderParts Relationships

| From Table | From Column | To Table | To Column | Cardinality | Cross Filter |
|------------|-------------|----------|-----------|-------------|--------------|
| Fact_WorkOrderParts | BranchCode | dim_BranchLocation | LocationID | Many-to-One | Single |
| Fact_WorkOrderParts | PartNumber | dim_Parts | PartNumber | Many-to-One | Single |
| Fact_WorkOrderParts | TransactionDate | dim_DateTable | Date | Many-to-One | Single |

**Critical:** Fact_WorkOrderParts.PartNumber joins to dim_Parts.PartNumber to get actual part descriptions (InTrans.Description is useless).

### External Table Relationships

| From Table | From Column | To Table | To Column | Cardinality | Cross Filter |
|------------|-------------|----------|-----------|-------------|--------------|
| Inspection Goals | LOCATION | dim_BranchLocation | LocationID | Many-to-One | Single |

---

## Data Model Best Practices

### Grain Consistency
- **Fact_LaborJobSummary:** Job-level (one row per job code per work order)
- **Fact_PendingInspections:** Work order-level (one row per pending inspection)
- **Fact_WorkOrderParts:** Part transaction-level (one row per part per invoice)

### Key Join Strategies
- **BranchCode/LocationID:** Consistent branch filtering across all facts
- **PartNumber:** Critical for part description lookup (InTrans description is useless)
- **Date Relationships:** Multiple date contexts available via USERELATIONSHIP()
- **Special Records:** Negative keys (-1, -2, etc.) handle unknown/system scenarios

### Performance Optimizations
- **Pre-Aggregation:** Hours aggregated at source (not in DAX)
- **Surrogate Keys:** Integer keys (BranchKey, CustomerKey, PartNumberKey) optimize joins
- **Star Schema:** Simple, efficient relationships for fast queries
- **Incremental Refresh:** Fact_LaborJobSummary uses ModifiedDate (2023+)

### Data Quality Considerations
- **NULL Handling:** LEFT OUTER joins preserve records with missing dimensions
- **Unknown Records:** Special records with negative keys handle missing data gracefully
- **Validation:** Monitor for missing joins (e.g., unmatched BranchCode, PartNumber)
- **Data Completeness Scores:** Available in dimensions but not currently used

---

## Usage Notes for Report Developers

### Dimension Simplicity vs. Feature Richness
**Current Inspections Report Usage:**
- **dim_Parts:** Only Description field used (part descriptions)
- **dim_CustomerList:** Only DisplayName/CustomerName used (customer names)
- **dim_BranchLocation:** Only Branch field used (branch filtering)
- **dim_DateTable:** Only Date, Year, Month, Quarter used (time filtering)

**Future Opportunity:**
All dimensions contain rich business intelligence fields (classifications, scores, analytics) that are NOT currently used but are available for future enhancements without model changes.

### Adding New Measures
When creating DAX measures:
- **Inspection Filtering:** Use `[IsInspection] = TRUE` for inspection-only metrics
- **Date Context:** Use `USERELATIONSHIP()` for non-active date relationships
- **Part Descriptions:** Always join to dim_Parts for descriptions (don't use Fact_WorkOrderParts.Description)
- **Branch Display:** Use dim_BranchLocation[Branch] for professional branch names

### Common DAX Patterns

```dax
// Count inspections
Total Inspections = 
CALCULATE(
    COUNTROWS(Fact_LaborJobSummary),
    Fact_LaborJobSummary[IsInspection] = TRUE
)

// Inspection revenue
Inspection Revenue = 
CALCULATE(
    SUM(Fact_LaborJobSummary[TotalInvoicedAmount]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)

// Performance vs goal
Performance % = 
DIVIDE(
    [Total Inspections],
    SUM('Inspection Goals'[Goal]),
    0
)

// Use alternate date context
Inspections by Creation Date = 
CALCULATE(
    [Total Inspections],
    USERELATIONSHIP(
        Fact_LaborJobSummary[WorkOrderCreationDate],
        dim_DateTable[Date]
    )
)
```

---

## Maintenance & Monitoring

### Regular Checks
- **Row Counts:** Validate expected row counts after refresh
- **Relationship Integrity:** Check for unmatched dimension keys
- **Performance:** Monitor refresh times (targets: Labor 3min, Pending 1.5min, Parts 10min)
- **Data Quality Scores:** Review dimension data quality metrics

### Update Procedures
- **Inspection Codes:** Update all 3 fact tables when new codes added (maintain consistency)
- **Goals:** Update Excel file monthly/quarterly
- **Dimensions:** Add new branches, customers, parts as needed
- **Date Table:** Extend range when approaching end date

### Known Issues to Monitor
1. **Parts Description:** InTrans.Description is useless - always use dim_Parts
2. **Fact_WorkOrderParts Performance:** 10-minute refresh - monitor for CU usage impact
3. **Pending Inspections Aging:** Watch for stale work orders (LastLaborPunch = 1/1/1900)
4. **Branch Filtering:** Ensure new branches get added to dim_BranchLocation

---

**End of Data Dictionary**