# Dataflow Refresh Times

Track average refresh times for capacity planning and CU optimization (F4 capacity).

## Raw Tables (01 - Raw Sources)

| Table Name | Dataflow | Approx Rows | Avg Refresh Time | Refresh Schedule | Last Updated | Notes |
|------------|----------|-------------|------------------|------------------|--------------|-------|
| jdis_Part_Information | df_jdis_Part_Information_Raw | 1,081,494 | ~8 minutes | 7:30am, 9:30am, 4:00pm | 12/01/2025 | Most frequently changing - optimization opportunity |
| ArMaster_Contact | df_ArMaster_Contact_Raw | 53,470 | ~6-8 min 🚨 | 7:30am weekdays (pipeline) | 10/21/2025 | WAS 1-2min - Part of ArMaster pipeline issue |
| ArMaster_Customer | df_ArMaster_Customer_Raw | 53,470 | ~6-8 min 🚨 | 7:30am weekdays (pipeline) | 08/11/2025 | WAS 1-2min - Part of ArMaster pipeline issue |
| armaster | df_armaster_Raw | 53,470 | ~6-7 min 🚨 (today 3:30) | 7:30am weekdays (pipeline) | 12/23/2025 | WAS 1-2min - INTERMITTENT! Has ModifiedDate |
| Branch_Name | [No dataflow - on-demand] | 99 | ~1:12 | On-demand (monthly or less) | 12/30/2025 | ✅ OPTIMAL - Foundation for dim_BranchLocation (ALL reports!) |
| BranchOperational | df_BranchOperational_Raw | 99 | ~1:20 | On-demand (monthly or less) | 07/02/2025 | ✅ OPTIMAL - LocationID key for relationships! Refresh with Branch_Name |
| contact | df_CONTACT_Raw | 81,648 | ~6-8 min 🚨 (today 4:23) | 7:30am weekdays (pipeline) | 08/11/2025 | WAS 1:30-2min - Part of 7:30 AM SYSTEMIC ISSUE! Has ModifiedDate |
| GlTrans | df_GlTrans_Raw | 208,637 | ~6-8 min 🚨 (today 4:32) | 7:30am weekdays (pipeline) | 12/22/2025 | WAS 2-3min - Master Orchestrator Pipeline! |
| InHist_PmManage | df_InHist_PmManage_Raw | 721,295 | ~8-9 min 🚨 (today 5:20) | 7:30am weekdays (pipeline) | 09/02/2025 | WAS 3min - 200%+ increase! Has PeriodDate for incremental |
| InMaster | df_InMaster_Raw | 1,081,485 | ~4-5 min ✅ | NOT SCHEDULED YET | 01/09/2026 | ✅ BASELINE! 1M+ rows in 4-5min proves 7:30 AM is the problem! Low Margin Flag |
| insalord | df_INSALORD_Raw | 8,631 | ~6-7 min 🚨🚨 | 7:30am weekdays (pipeline) | 12/30/2025 | WAS 1min - 600% INCREASE! Tiny table proves it's NOT row count! |
| insalpar | df_INSALPAR_Raw | 13,373 | ~6-7 min 🚨🚨 (today 5:21) | 7:30am weekdays (pipeline) | 12/30/2025 | WAS 1-1:30min - 400-600% increase! Another tiny table! |
| Invoice | df_Invoice_Raw | 1,402,683 | ~10-12 min 🚨🚨 (today 7:46) | 7:30am weekdays (pipeline) | 08/28/2025 | WAS 4-5min - 200-250% increase! 9th affected table! Has InvoiceDate for incremental |
| RepairOrderDetail | df_RepairOrderDetail_Raw | 2,003 | ~6-7 min 🚨🚨🚨 (today 4:35) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1-1:30min - 400-600% INCREASE! TINY TABLE = SMOKING GUN! Has CreationDate |
| Technician | df_Technician_Raw | 1,424 | ~6-7 min 🚨🚨🚨 (today 4:20) | 7:30am weekdays (pipeline) | 07/03/2025 | WAS 1-1:30min - 400-600% INCREASE! 1.4K rows, 3 cols = ABSURD! User says daily refresh probably not needed |
| TechnicianInvoiceDetail | df_TechnicianInvoiceDetail_Raw | 330,096 | ~6-7 min 🚨🚨 (today 7:21) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1:30-2min - 300-400% increase! Has ModifiedDate incremental ALREADY - proves timing is issue! |
| TechnicianPunchedDetail | df_TechnicianPunchedDetail_Raw | 319,043 | ~7-8 min 🚨🚨 (today 5:39) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1:30-3min - 200-400% increase! Has CreationDate incremental - 2nd labor table proving incremental doesn't fix timing! |
| vhstock | df_VHSTOCK_Raw | 24,469 | ~6-7 min 🚨🚨 (today 3:06) | 7:30am weekdays (pipeline) | 08/14/2025 | WAS 1-1:30min - 400-600% increase! Has SaleDate incremental - 4th table with incremental proving timing is root cause! |
| VhStockAccess | df_VhStockAccess_Raw | 683,129 | ~2 min ✅ | NOT SCHEDULED YET | 08/14/2025 | ✅ BASELINE! Large table (683K rows) refreshing in 2 min - not used in reports yet, may be used in future |
| WarClaim | df_WarClaim_Raw | 10,801 | ~1:10 ✅ | NOT SCHEDULED YET | 11/03/2025 | ✅ BASELINE! SAME SIZE as insalord (8.6K) but 5-6x FASTER! Has RepairDate incremental - proves 7:30 AM is the problem! |
| WarsubCl_Labour | df_WARSUBCI_LABOUR_Raw | 65,741 | ~1:30 ✅ | NOT SCHEDULED YET | 07/03/2025 | ✅ BASELINE! MEDIUM size (66K) - SAME as ArMaster (53K) but 4-5x FASTER! Complete baseline coverage! |
| WkInvReg | df_WKINVREG_Raw | 40,582 | ~8-9 min 🚨🚨 (today 4:48) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1-2min - 400-700% increase! Has ModifiedDate incremental (2023+ scope) - 5th table proving incremental doesn't fix timing! 15 TABLES CONFIRMED! |
| wkmechwk | df_WKMECHWK_Raw | 307,819 | ~6-8 min 🚨🚨 (today 4:30) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1-2min - 300-400% increase! Has ModifiedDate incremental - 6th table with incremental proving timing is root cause! 16 TABLES = 405-495 min/week wasted! |
| wkothsub | df_WKOTHSUB_Raw | 350,305 | ~6-7 min 🚨🚨 (today 4:30) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 2min - 300-350% increase! Has ModifiedDate incremental (21 cols optimized) - 7th table proving incremental doesn't fix timing! 17 TABLES = 425-520 min/week! |
| wkrodesc | df_WKRODESC_Raw | 904,014 | ~6-8 min 🚨🚨 (today 5:24) | 7:30am weekdays (pipeline) | 08/27/2025 | WAS 1:30-3min - 200-400% increase! LARGE dataset, SIMPLEST query (6 cols, LINE_NO=1 filter) - proves complexity NOT issue! 18 TABLES = 440-545 min/week! |
| WKROFILE | df_WKROFILE_Raw | 111,650 | ~7-8 min 🚨🚨 (today 5:15) | 7:30am weekdays (pipeline) | 11/03/2025 | WAS 1-2min - 400-700% increase! Has ModifiedDate incremental (20 cols) - 8th table with incremental proving timing is root cause! 19 TABLES = 465-575 min/week! |
| WKVEHFL | df_WKVEHFL_Raw | 48,316 | ~7-8 min 🚨🚨 (today 4:34) | 7:30am weekdays (pipeline) | 08/27/2025 | WAS 1-2min - 400-700% increase! Has ModifiedDate incremental (16 cols) - 9th table with incremental! 20 TABLES = 490-605 min/week = 8-10 HOURS/WEEK! |
| InTrans_Incremental | df_InTrans_Incremental | 10,245,764 | ~2-3 min ✅🏆 | 3x daily (dedicated pipeline) | 01/05/2026 | ✅ **GOLD STANDARD!** 10M+ rows with watermark-based incremental refresh. 2-3 min vs 30+ min full refresh. Powers 9+ fact tables. 6+ years history. TEMPLATE for Fact_WorkOrderParts optimization! |
| [Other] | [Dataflow name] | [X] | [X min/sec] | [Schedule] | [Date] | |

## Dimensions (03 - Dimensions)

| Dimension | Dataflow | Approx Rows | Avg Refresh Time | Refresh Schedule | Last Updated | Dependencies | Notes |
|-----------|----------|-------------|------------------|------------------|--------------|--------------|-------|
| dim_AdjustmentType | df_Dim_AdjustmentType | 7 | ~1 min ✅ | Not scheduled (static) | 12/23/2025 | None (hard-coded) | Type 0 - Static dimension for parts adjustments. Recommend monthly refresh |
| dim_Branch12_Parts | df_Dim_Branch12_Parts | 1,485 | ~1:30 ✅ | Daily weekdays (7:45-7:55 AM) | 10/17/2025 | jdis_Part_Information, Fact_Branch12_Transactions | Type 1 - Branch 12 parts with R12 metrics. Part of dimensional pipeline after raw data refresh. Full description preserved |
| dim_CommodityCode | df_Dim_CommodityCode | 780 | ~1:30 ✅ | Not scheduled (recommend monthly) | 06/23/2025 | jdis_Part_Information, UnknownCommodityCode | Type 1 - Distinct commodity codes from parts. Self-updating, recommend monthly refresh with reference data pipeline |
| dim_DateTable | df_Dim_Date | 4,018 | <15 sec ✅ | Daily weekdays (7:45-7:55 AM) | 11/25/2025 | None (mathematically generated) | Type 0 - Comprehensive time intelligence dimension. 76 columns including rolling periods, YTD/QTD/MTD flags, agricultural seasonality. 2020-2030 date range. Daily refresh required for dynamic flags |
| dim_DealerGroupCode | df_Dim_DealerGroupCode | 1,813 | ~1:40 ⚠️ | Not scheduled (recommend monthly) | 06/23/2025 | jdis_Part_Information, UnknownDealerGroupCode | Type 1 - Distinct dealer group codes from parts. Self-updating, UPPERCASE normalized. ⚠️ OPTIMIZATION OPPORTUNITY: Redundant operations (4 distinct, 3 appends, 3 sorts) - can reduce to ~1:00 |
| dim_Franchise | df_Dim_Franchise | 43 | ~1:30 ✅ | Not scheduled (recommend monthly) | 08/20/2025 | jdis_Part_Information | Type 1 - Comprehensive manufacturer dimension. 15 columns of business intelligence: classification, market position, service complexity, priority scoring. Pattern-based John Deere/Case IH/Caterpillar/Kubota/New Holland categorization |
| Dim_JobType | df_Dim_JobType | 7 | ~2 min ⚠️ | Not scheduled (recommend monthly) | 10/07/2025 | Raw_WorkOrderDesc | Type 1 - Work order type classification. 7 columns: billing type (Insurance Claim, Customer Pay, Fleet Account, etc.), category grouping. 7 job types: A/F/I/P/R/S/W. ⚠️ 2 min for 7 rows seems high (not urgent) |
| dim_BranchLocation | df_Dim_Location | 69 | ~1:30 ✅ | Not scheduled (recommend monthly) | 08/20/2025 | Raw_BranchOperational | Type 1 - Branch/location dimension. 16 columns: branch type (Main/IS Shop/Set-Up/CP), service capacity, market presence, regional classification, operational priority (1-10). **CRITICAL FIX**: Smart filtering (not Table.Skip) - all 69 operational branches included (Seminole restored). Used in ALL reports |
| dim_ModuleType | df_Dim_ModuleType | 11 | ~1:30 ⚠️ | Not scheduled (recommend monthly) | 09/25/2025 | Invoice | Type 1 - Invoice module type classification. 5 columns: explicit keys (1-11), business grouping (Counter/Work Order/Internal/Warranty/Tag/Other), sort order. Internal customers (71-87, 9001-9007) and Warranty customers (41-57, 9051-9057) override logic. ⚠️ 1:30 for 11 rows (large Invoice source) |
| dim_Parts | df_Dim_Part | 308,709 | ~5-6 min ⚠️ | Daily weekdays (~7:45 AM pipeline) | 01/12/2026 | jdis_Part_Information | Type 1 - Master parts dimension with inventory, pricing, sales intelligence. **OPTIMIZED VERSION**: Early blank removal/dedup (saves 20s), Text.Upper instead of Text.Proper on Description (saves 30-60s), strategic column selection. Target: <5 min (15-25% improvement). **CRITICAL FIX**: Final deduplication prevents duplicate PartNumber relationship errors. 22 columns: surrogate key, business filters, inventory status, pricing, activity flags. ⚠️ Future optimization opportunity revisit |
| dim_PaymentMethod | df_Dim_PaymentMethod | 5 | ~1:30 ✅ | Not scheduled (recommend monthly) | 10/15/2025 | Invoice | Type 1 - Payment method classification dimension. Self-updating from Invoice distinct values. 5 columns: surrogate key, PaymentMethod, PaymentMethodDescription, PaymentCategory (Cash/Electronic/Check/Account/Finance), SortOrder (business-logical order, Cash first). Enables payment pattern analysis, cash flow management, branch comparison. Rarely changes - monthly refresh adequate or even quarterly |
| dim_SLC | df_Dim_SLC | 123 | ~1:30 ✅ | Not scheduled (recommend monthly) | 06/23/2025 | jdis_Part_Information | Type 1 - Stock Location Code/Stock Line Code classification. Self-updating from jdis_Part_Information distinct values. 2 columns: SLCKey, SLC. Unknown record pattern (SLCKey=-1) for missing values. Text trim/clean for data quality. Standard parts classification dimension. 1:30 reasonable for extracting 123 distinct from 1M+ parts |
| dim_Source | df_Dim_Source | 267 | ~1:30 ✅ | Not scheduled (recommend monthly) | 06/23/2025 | jdis_Part_Information | Type 1 - Source classification for parts. Self-updating from jdis_Part_Information distinct values. 2 columns: SourceKey, Source. Unknown record pattern (SourceKey=-1). Text cleaning AFTER Unknown append for consistency. 267 codes suggests detailed source classification. Similar pattern to dim_SLC but with late-stage text cleaning |
| dim_Technician_Code_Names | df_Dim_Technicans | 1,417 | ~1:30 ✅ | Not scheduled (recommend monthly) | 08/18/2025 | Raw_Technician | Type 1 - Comprehensive technician master dimension. 16 columns: surrogate key, code, name components, MULTIPLE display formats (DisplayName, FullName, ShortName, PreferredDisplayName, SearchableName), status/type classification, BI flags (IsActive, HasFullName, HasValidCode, HasLongName, DataQualityScore 0-100). Unknown record pattern (TechnicianKey=-1). Intelligent name fallbacks, pre-calculated display names eliminate DAX complexity. Labor analysis, performance tracking, resource planning |
| dim_UniqueCustomers | df_Dim_UniqueCustomers | 11 | ~1:30 ✅ | Daily weekdays (~7:45 AM pipeline) | 11/04/2025 | In-memory table (manual) | Type 1 with soft deletes - High-value customer tracking dimension. 7 columns: CustomerKey, CustomerName, DataSource (InTrans/Invoice), IdentificationMethod (5 types), IdentificationRule, IsActive, CreatedDate. **DUAL-FACT ARCHITECTURE**: Serves both Fact_InTrans_UniqueCustomers (location-based) and Fact_Invoice_UniqueCustomers (text-pattern). 5 identification methods: TradeType, TradeType+Branch, CustomerOrderNumber, CustomerOrderNumber+Branch, CustomerNo. 11 customers: 3 locations (Pearsall/Dell City/Tornillo), 5 Invoice (Manuel/Jim/David/Danny/Oscar), 3 InTrans (Dallyn/Benny/Owen). **DAILY REFRESH REQUIRED** - must stay in sync with fact tables |
| dim_Vehicle | df_Dim_Vehicle | 71,640 | ~2 min ✅ | **NOT SCHEDULED - Awaiting deployment** | 08/15/2025 | Raw_VehicleFleet, Raw_VehicleStock | Type 1 - **FUTURE POTENTIAL** Comprehensive vehicle/equipment master dimension. 26 columns: VehicleKey, PrimaryLookup (CRITICAL for work orders), dual-source integration (Fleet+Stock), identification (Registration/StockNumber/VIN), specifications (Make/Model/Year/Engine), age analysis (VehicleAge/AgeCategory), service intelligence (ServiceComplexity/WarrantyLikelihood/PartsAvailability/MaintenancePriority 1-10), equipment categorization (Heavy Equipment/Commercial Truck/Domestic/Import), multiple display formats, DataQualityScore 0-100. **POWERFUL FOR SERVICE REPORTS** when deployed. Ready for incremental refresh. Determine schedule when use cases defined (daily for service ops, weekly for analytics, monthly for planning) |
| dim_VendorCode | df_Dim_VendorCode | 1,311 | ~1:30 ✅ | Not scheduled (recommend monthly) | 05/29/2025 | jdis_Part_Information | Type 1 - Vendor code classification for supplier analysis. Self-updating from jdis_Part_Information distinct values. 2 columns: VendorCodeKey, VendorCode. Simple structure, alphabetically sorted. **PARTS DIMENSION FAMILY** (SLC/Source/Commodity/Dealer/Vendor). 1,311 vendors suggests substantial supplier base. Procurement analytics, vendor performance, sourcing strategy. ⚠️ **NO Unknown record** (unlike other parts dimensions) - consider adding for consistency if NULL vendors exist in facts |
| dim_CustomerList | df_Dim_CustomerList | [X] | [X min/sec] | [Schedule] | [Date] | [Raw tables used] | |
| dim_Parts_LowMargin | df_Dim_Parts_LowMargin | [X] | [X min/sec] | [Schedule] | [Date] | Multiple sources | Report-specific |

## Fact Tables (04 - Fact)

| Fact Table | Dataflow | Approx Rows | Avg Refresh Time | Last Updated | Dependencies | Report |
|------------|----------|-------------|------------------|--------------|--------------|--------|
| Fact_PartsAdjustment | df_Fact_PartsAdjustment | [X] | [X min/sec] | [Date] | [Raw tables] | Parts Adjustment |
| Fact_LaborJobs | df_Fact_LaborJobs | [X] | [X min/sec] | [Date] | [Raw tables] | Labor Jobs |
| [Other] | [Dataflow name] | [X] | [X min/sec] | [Date] | [Raw tables] | [Report name] |

## Snapshots (05 - Snapshots)

| Snapshot | Dataflow | Approx Rows | Avg Refresh Time | Schedule | Notes |
|----------|----------|-------------|------------------|----------|-------|
| jdis_Part_Information (Daily) | df_Snapshot_Parts_Daily | [X] | [X min/sec] | Daily | |
| jdis_Part_Information (Weekly) | df_Snapshot_Parts_Weekly | [X] | [X min/sec] | Weekly | |

---

## CU Optimization Notes

### Longest Running Dataflows:
1. [Table name] - [X minutes]
2. [Table name] - [X minutes]
3. [Table name] - [X minutes]

### Optimization Opportunities:
- [ ] [Potential optimization 1]
- [ ] [Potential optimization 2]
- [ ] [Potential optimization 3]

### Refresh Schedule Strategy:
- **Raw tables:** [When they run]
- **Dimensions:** [When they run] (after raw tables complete)
- **Facts:** [When they run] (after dimensions complete)
- **Stagger times to avoid capacity spikes**

### Total Daily CU Consumption:
- Estimated: [X CU per day]
- Target: [Stay under Y CU to avoid throttling]

---

## How to Update This Document

1. **After making query changes** - Test refresh time and update
2. **Monthly review** - Check if patterns have changed
3. **When adding new tables** - Add row to appropriate section
4. **When optimizing** - Document before/after times

---

**Last Updated:** [Date]
**F4 Capacity Limit:** [Check Fabric capacity metrics]
**Current Daily Usage:** [Check actual usage]
