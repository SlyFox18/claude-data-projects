# Fact Tables Summary

**Purpose:** Central registry of all fact tables across projects with metadata and cross-references.

**Last Updated:** January 15, 2026

**Note:** Actual query files (.pq) are located in their respective project folders. This document provides metadata, location, and cross-references for quick navigation and context.

---

## 📊 Quick Stats Overview

| Category | Count | Total Rows | Notes |
|----------|-------|------------|-------|
| **Total Fact Tables** | 24 | ~16.5 million | Across 15 projects |
| **Total Reports** | 15 | - | Parts (9), Service (1), Financial (1), Utility (1) |
| **Daily Refresh Facts** | 2 | ~355K | Critical operational reports |
| **Twice-Daily Refresh** | 1 | ~8K | Parts ordering monitoring |
| **Need Scheduling** | 14 | ~15M+ | Awaiting refresh schedule definition |
| **On-Demand / No Dataflow** | 7 | ~3M | Built in Power Query at report level |
| **Incremental Refresh Implemented** | 2+ | 10M+ | Performance optimization |

---

## 🚨 Critical Findings & Action Items

### **High Priority:**
- ⚠️ **Fact_WorkOrderParts**: 18-19 minute refresh time (longest fact) - **NEEDS INCREMENTAL REFRESH**
- ⚠️ **14 facts need scheduling** - Most reports currently unscheduled
- ⚠️ **Missing raw table docs**: InTrans_Incremental (heavily used), InHist_PmManage

### **Refresh Strategy Needed:**
- Daily pipeline: 2 facts scheduled, ~12 more should be daily
- Weekly pipeline: Candidates for less frequent refresh
- Twice-daily: Parts Not Re-Ordered (already scheduled)

### **Documentation Status:**
- ✅ **1 project** has extensive documentation (Inspections)
- ✅ **2 projects** have some documentation (Parts Low Margin, Open Parts Tickets)
- ⚠️ **12 projects** have NO documentation (high priority)

---

## 📈 Facts by Department

### **Parts Department** (9 Reports, 18 Fact Tables)
Most active department with inventory, sales, and operations tracking

### **Service Department** (1 Report, 3 Fact Tables)
Inspections tracking - complex but well-documented

### **Financial Department** (1 Report, 1 Fact Table)
Past due accounts tracking

### **Utility** (1 Report, 0 Fact Tables)
Table/column search tool (metadata queries)

---

## 🗂️ Fact Tables by Project

### **Project: 60 Days Past Due**
**Location:** `projects/60-days-past-due/queries/fact-tables/`
**Department:** Financial
**Created:** 12/23/2025 | **Modified:** 01/15/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_InSalOrd_InSalPar | df_Fact_InSalOrd_InSalPar | 1,386 | ~1:30 | ⚠️ Not scheduled | Identify past due accounts |

**Raw Tables:** Insalord, insalpar, armaster, ArMaster_Customer

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_CustomerList

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (critical for A/R management)

---

### **Project: Bin Location Report**
**Location:** `projects/bin-location-report/queries/`
**Department:** Parts
**Created:** 12/30/2025

| Table Used | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| jdis_Part_Information (Raw) | None - uses raw table | 1,081,622 | ~1 min (semantic model) | ⚠️ Not scheduled | Find bin locations |

**Raw Tables:** jdis_Part_Information (direct use, no fact table)

**Dimensions:** dim_BranchLocation, dim_Franchise, dim_Parts, dim_DealerGroupCode

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Weekly or Monthly (reference data, changes infrequently)

**Note:** No dataflow - report uses raw table directly

---

### **Project: Combine Vault Sales (Branch 12)**
**Location:** `projects/combine-vault-sales/queries/fact-tables/`
**Department:** Parts
**Created:** 10/14/2025 | **Modified:** 11/25/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Branch12_Transactions | df_Fact_Branch12_Transactions | 4,660 | 2-4 min | ✅ Daily (post-dims) | Track Branch 12 combine parts transfers |

**Raw Tables:** InTrans_Incremental ⚠️ **(needs documentation)**

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_Branch12_Parts, dim_Parts

**Business Context:** Branch 12 = combine parts storage (not physical storefront). Transfers out = "sales"

**Status:** ⚠️ No documentation done to this project folder

**Notes:** See fact table query for detailed business logic on how transfers work

---

### **Project: First Pass Fill**
**Location:** `projects/first-pass-fill/queries/fact-tables/`
**Department:** Parts
**Created:** 09/02/2025 | **Modified:** 09/02/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_FirstPassFill | df_Fact_First_Pass_Fill | 734,408 | ~5 min | ⚠️ Not scheduled | Track parts available on first customer request |

**Raw Tables:** InHist_PmManage ⚠️ **(needs documentation)**

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_JobCode, dim_Parts

**Business Context:** First Pass Fill = part in stock when customer comes in. Critical inventory KPI during busy seasons.

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (critical inventory KPI)

---

### **Project: Inspections**
**Location:** `projects/inspections-report/queries/fact-tables/`
**Department:** Service
**Created:** 11/05/2025 | **Modified:** 01/12/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_LaborJobSummary | df_Fact_LaborJobSummary | 350,502 | ~5 min | ✅ Daily (weekdays) | Labor job summary for inspections |
| Fact_PendingInspections | df_Fact_PendingInspections | 118 | 2-3 min | ✅ Daily (weekdays) | Track pending inspections |
| Fact_WorkOrderParts | df_Fact_WorkOrderParts | [Unknown] | ⚠️ **18-19 min** | ✅ Daily (weekdays) | Parts used in work orders |

**Raw Tables:** InTrans_Incremental, Raw_wkothsub, RepairOrderDetail, TechnicianPunchedDetail, wkothsub, wkmechwk, WKROFILE, wkrodesc

**Dimensions:** dim_BranchLocation, dim_CustomerList, dim_DateTable, dim_Parts

**Business Context:** Comprehensive inspection tracking - completed, pending, goals, parts sales

**Status:** ✅ **Extensive documentation exists** in this project folder

**Critical Issue:** ⚠️ **Fact_WorkOrderParts refresh time is 18-19 minutes** - candidate for incremental refresh

**Refresh Pipeline:** Raw → Dims → Facts → Semantic Model (weekdays)

---

### **Project: Inventory Analysis**
**Location:** `projects/inventory-analysis/queries/fact-tables/`
**Department:** Parts
**Created:** 09/23/2025 | **Modified:** 10/15/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Invoice_InventoryAnalysis | df_Fact_Invoice_InventoryAnalysis | 469,279 | ~2:30 | ⚠️ Not scheduled | Invoice-based inventory analysis |
| Fact_Inventory | df_Fact_Inventory | 138,047 | ~6 min | ⚠️ Not scheduled | Current inventory snapshot |
| Fact_Part_Transactions | df_FactPartTransactions_Incremental | 10,131,874 | 2-3 min | ⚠️ Not scheduled | **✅ INCREMENTAL** Parts transaction history |

**Raw Tables:** Invoice, jdis_Part_Information, InTrans_Incremental

**Dimensions:** dim_VendorCode, dim_Source, dim_SLC, dim_Parts, dim_Franchise, dim_DealerGroupCode, dim_Date (older simple date table), dim_CommodityCode, dim_BranchLocation, dim_ModuleType, dim_PaymentMethod

**Business Context:** Major inventory analysis report with extensive historical data (10M+ transaction rows)

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (critical inventory operations)

**Performance Note:** ✅ Fact_Part_Transactions already has incremental refresh implemented - **needs documentation**

---

### **Project: JD Price Updates (Sub-project 3)**
**Location:** `projects/jd-price-updates/queries/fact-tables/`
**Department:** Parts
**Created:** 08/10/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PriceUpdate_Enriched | df_Fact_PriceUpdate_Enriched | ~5.1M (unchanged grain from raw -- see note below) | TBD | Daily | dim_Parts-enriched price change history for parts sold locally |
| Fact_JDNationalChangeReport_Enriched | df_Fact_JDNationalChangeReport_Enriched | ~48K+ (unchanged grain from raw) | TBD | Weekly | dim_Parts-enriched national Deere price change history (all parts, not just ones carried locally) |

**Raw Tables:** Raw_PriceUpdate_History, Raw_JDNationalChangeReport_History

**Dimensions:** dim_Parts

**Business Context:** Foundational fact layer for JD parts pricing analysis (sub-project 3, phase 1). Both facts keep their raw source's grain unchanged and add `dim_Parts` classification columns (Source, SLC, DealerGroupCode, CommodityCode, VendorCode) and an `IsCarriedLocally` flag -- pure enrichment, no aggregation. `Fact_PriceUpdate_Enriched` originally collapsed branch-level rows to PartNumber+EffectiveDate with a computed `AffectedBranchCount` column, but that Table.Group ran 45+ minutes live in Fabric without completing (severe M-engine anti-pattern at 5.1M-row scale, same root cause as a separate dim_Parts.pq performance issue found the same night -- see project memory `project_dim_parts_perf_followup.md`). Redesigned 2026-08-11 to do the branch-collapse NOT AT ALL in this dataflow: the fact stays at raw (branch-level) grain, and `AffectedBranchCount` is planned as a DAX measure (`DISTINCTCOUNT(Branch)`) at the semantic-model layer instead -- faster, simpler, and more correct (a measure recalculates properly under report-level branch filters; a frozen ETL column couldn't). What specific margin/KPI analysis gets built on top of these facts is deferred to a later phase -- see `docs/superpowers/specs/2026-08-10-jd-pricing-fact-tables-design.md`.

**Status:** 🚧 In Development

**Recommended Schedule:** Daily for Fact_PriceUpdate_Enriched (matches Raw_PriceUpdate_History's daily harvest), Weekly for Fact_JDNationalChangeReport_Enriched (matches its source's weekly cadence)

**Note:** building this fact layer also surfaced and fixed a real, separate deduplication bug in `dim_Parts` itself (majority-vote fix, PR #28, 2026-08-10) -- see `.claude/queries/dimensions/dim_Parts.pq`'s header comment.

---

### **Project: Negative On Hand - On Hand No Bin**
**Location:** `projects/negative-onhand-nobin/queries/fact-tables/`
**Department:** Parts
**Created:** 10/27/2025 | **Modified:** 10/27/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_NegativeOnHand_OnHandNoBin | df_Fact_NegativeOnHand_OnHandNoBin | 1,398 | ~1:30 | ⚠️ Not scheduled | Identify negative quantities or missing bin locations |

**Raw Tables:** jdis_Part_Information

**Dimensions:** dim_BranchLocation, dim_DateTable

**Business Context:** Data quality report - flags inventory anomalies

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (data quality monitoring)

---

### **Project: Part Sales with Low Margin**
**Location:** `projects/part-sales-low-margin/queries/`
**Department:** Parts
**Created:** 01/13/2026

| Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|-------|----------|------|--------------|----------|---------|
| Fact_Intrans | None (Power Query in report) | 1,374,704 | ~1 min (semantic model) | ⚠️ Not scheduled | Transaction history |
| dim_Parts_LowMargin | None (Power Query in report) | 151,122 | ~1 min (semantic model) | ⚠️ Not scheduled | Hybrid fact/dim for low margin parts |

**Raw Tables:** InTrans_Incremental, InMaster, jdis_Part_Information

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_CustomerList

**Business Context:** Identify parts selling below target margin

**Status:** ✅ **Extensive documentation exists** in this project folder

**Recommended Schedule:** Weekly (pricing strategy review)

**Note:** No Fabric dataflow - built in Power Query at report level

---

### **Project: Parts Adjustments**
**Location:** `projects/parts-adjustments/queries/fact-tables/`
**Department:** Parts
**Created:** 12/22/2025 | **Modified:** 12/29/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PartsAdjustments | df_Fact_PartsAdjustments | 239,171 | 2-3 min | ⚠️ Not scheduled | Track inventory adjustments |

**Raw Tables:** GlTrans, InTrans_Incremental, jdis_Part_Information

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_AdjustmentType, dim_Parts

**Business Context:** Identify and analyze inventory adjustments for audit and analysis

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (audit trail maintenance)

---

### **Project: Parts Not Re-Ordered 24 Hours**
**Location:** `projects/parts-not-reordered-24hrs/queries/fact-tables/`
**Department:** Parts
**Created:** 10/23/2025 | **Modified:** 11/28/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PartsNotReordered | df_Fact_PartSales_24Hours | 7,965 | 3-3:30 min | ✅ **Twice Daily** (9:30 AM, 4:00 PM) | Parts not reordered within 24 hours |

**Raw Tables:** InTrans_Incremental, jdis_Part_Information

**Dimensions:** dim_BranchLocation, dim_DateTable

**Business Context:** Stock orders happen twice daily - critical during busy seasons to catch missed orders

**Status:** ⚠️ No documentation done to this project folder (but has supporting queries documented)

**Refresh Pipeline:** ✅ Has own dedicated twice-daily pipeline

**Note:** Supporting queries exist in same dataflow, should document

---

### **Project: Open Parts Tickets**
**Location:** `projects/parts-open-orders/queries/fact-tables/`
**Department:** Parts
**Created:** 12/30/2025 | **Modified:** 01/07/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Parts_Open_Tickets | df_Fact_Parts_With_Open_Orders | ~1,245 | 2-3 min | ⚠️ Not scheduled | Parts on open work orders (summary) |
| Fact_Parts_Open_Tickets_Details | df_Fact_Parts_With_Open_Orders | ~1,245 | 2-3 min | ⚠️ Not scheduled | Parts on open work orders (details) |

**Raw Tables:** [Not specified - see project folder]

**Dimensions:** dim_BranchLocation, dim_DateTable

**Business Context:** Track parts allocated to open work orders

**Status:** ✅ Notes exist in this project folder - refer to notes

**Recommended Schedule:** Daily (operational tracking)

---

### **Project: Physical Inventory**
**Location:** `projects/physical-inventory/queries/`
**Department:** Parts
**Created:** 10/30/2025

| Table Used | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Physical Inventory | None (Power Query in report) | 185,489 | ~1 min (semantic model) | ✅ Daily (weekdays) | Physical inventory count tracking |

**Raw Tables:** jdis_Part_Information

**Dimensions:** dim_BranchLocation, dim_DateTable

**Status:** ⚠️ No documentation done to this project folder

**Refresh Pipeline:** ✅ Part of Raw → Dims → Facts → Semantic Model pipeline

**Note:** No Fabric dataflow - built in Power Query at report level

---

### **Project: Pin Capture**
**Location:** `projects/pin-capture/queries/`
**Department:** Parts
**Created:** 01/12/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PinTransactions | None (Power Query in report) | 1,398,091 | 1-2 min (semantic model) | ⚠️ Not scheduled | Track transactions with PIN (serial number) capture |

**Raw Tables:** InTrans_Incremental, wkothsub

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_CustomerList, dim_Parts

**Business Context:** PIN = machine serial number. Tracks when serial numbers captured at sale.

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (operational tracking)

**Note:** No Fabric dataflow - built in Power Query at report level

---

### **Project: Price Matrix**
**Location:** `projects/price-matrix/queries/`
**Department:** Parts
**Created:** 07/14/2025 | **Modified:** 01/12/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Inventory | *See Inventory Analysis* | 138,047 | ~6 min | ⚠️ Not scheduled | Reused from Inventory Analysis |
| Fact_Part_Transactions | *See Inventory Analysis* | 10,131,874 | 2-3 min | ⚠️ Not scheduled | Reused from Inventory Analysis |

**Raw Tables:** *See Inventory Analysis project*

**Dimensions:** dim_BranchLocation, dim_Parts, dim_Franchise, dim_DealerGroupCode, dim_Source, dim_SLC, dim_VendorCode, dim_DateTable

**Business Context:** Track sales gains from price matrix implementation. Uses shared fact tables from Inventory Analysis.

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Weekly (pricing strategy less time-sensitive than operations)

**External Dependency:** ⚠️ Uses CSV from SharePoint location - needs documentation

**Future Work:** Needs updates documented for next iteration

---

### **Project: Table-Column-Names-Search**
**Location:** `projects/table-column-search/queries/`
**Department:** Utility
**Created:** [Unknown]

| Query Type | Dataflow | Purpose |
|------------|----------|---------|
| Metadata Queries | None | Search tables/columns in source system |

**Source:** Uses metadata queries from `.claude/queries/metadata-queries/`

**Dimensions:** None

**Refresh Schedule:** On-demand only (utility tool)

**Status:** ⚠️ No documentation done to this project folder

**Note:** Utility report for data discovery - not operational reporting

---

### **Project: Unique Parts Customers**
**Location:** `projects/unique-parts-customers/queries/fact-tables/`
**Department:** Parts
**Created:** 07/07/2025 | **Modified:** 11/04/2025

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Invoice_UniqueCustomers | df_Fact_Invoice_UniqueCustomers | 5,826 | 2-3 min | ⚠️ Not scheduled | Invoice transactions for unique customers |
| Fact_InTrans_UniqueCustomers | df_Fact_InTrans_UniqueCustomers | 53,665 | 2-3 min | ⚠️ Not scheduled | InTrans transactions for unique customers |

**Raw Tables:** Invoice, InTrans_Incremental

**Dimensions:** dim_BranchLocation, dim_DateTable, dim_CustomerList, dim_UniqueCustomers

**Business Context:** Track transactions for specific high-value customers identified in dim_UniqueCustomers (11 customers with 5 identification methods)

**Status:** ⚠️ No documentation done to this project folder

**Recommended Schedule:** Daily (aligns with dim_UniqueCustomers daily refresh)

**Note:** Supports dim_UniqueCustomers dual-fact architecture documented in dimensions

---

## 📊 Fact Tables by Refresh Schedule

### **✅ Currently Scheduled - Daily Weekdays**

| Fact Table | Project | Refresh Time | Pipeline | Rows |
|------------|---------|--------------|----------|------|
| Fact_Branch12_Transactions | Combine Vault Sales | 2-4 min | Post-dims | 4,660 |
| Fact_LaborJobSummary | Inspections | ~5 min | Post-dims | 350,502 |
| Fact_PendingInspections | Inspections | 2-3 min | Post-dims | 118 |
| Fact_WorkOrderParts | Inspections | ⚠️ **18-19 min** | Post-dims | Unknown |
| Physical Inventory | Physical Inventory | ~1 min | Post-facts (semantic) | 185,489 |

**Total Daily Refresh Time:** ~28-34 minutes (⚠️ **Fact_WorkOrderParts needs optimization**)

---

### **✅ Currently Scheduled - Twice Daily**

| Fact Table | Project | Refresh Time | Schedule | Rows |
|------------|---------|--------------|----------|------|
| Fact_PartsNotReordered | Parts Not Re-Ordered 24 Hours | 3-3:30 min | 9:30 AM, 4:00 PM | 7,965 |

**Business Justification:** Aligns with twice-daily stock ordering process

---

### **⚠️ Not Scheduled - Should Be Daily** (High Priority)

| Fact Table | Project | Refresh Time | Rows | Rationale |
|------------|---------|--------------|------|-----------|
| Fact_InSalOrd_InSalPar | 60 Days Past Due | ~1:30 | 1,386 | A/R management critical |
| Fact_FirstPassFill | First Pass Fill | ~5 min | 734,408 | Critical inventory KPI |
| Fact_Invoice_InventoryAnalysis | Inventory Analysis | ~2:30 | 469,279 | Daily operations |
| Fact_Inventory | Inventory Analysis | ~6 min | 138,047 | Daily operations |
| Fact_Part_Transactions | Inventory Analysis | 2-3 min | 10,131,874 | Daily operations (incremental) |
| Fact_NegativeOnHand_OnHandNoBin | Negative On Hand | ~1:30 | 1,398 | Data quality monitoring |
| Fact_PartsAdjustments | Parts Adjustments | 2-3 min | 239,171 | Audit trail |
| Fact_Parts_Open_Tickets | Open Parts Tickets | 2-3 min | ~1,245 | Operational tracking |
| Fact_Parts_Open_Tickets_Details | Open Parts Tickets | 2-3 min | ~1,245 | Operational tracking |
| Fact_PinTransactions | Pin Capture | 1-2 min | 1,398,091 | Operational tracking |
| Fact_Invoice_UniqueCustomers | Unique Parts Customers | 2-3 min | 5,826 | Aligns with dim refresh |
| Fact_InTrans_UniqueCustomers | Unique Parts Customers | 2-3 min | 53,665 | Aligns with dim refresh |

**Subtotal:** ~12 fact tables, ~30-40 minutes combined

---

### **⚠️ Not Scheduled - Weekly Candidates**

| Fact Table | Project | Refresh Time | Rows | Rationale |
|------------|---------|--------------|------|-----------|
| jdis_Part_Information (raw) | Bin Location | ~1 min | 1,081,622 | Reference data, infrequent changes |
| Fact_Intrans | Part Sales Low Margin | ~1 min | 1,374,704 | Pricing strategy review |
| dim_Parts_LowMargin | Part Sales Low Margin | ~1 min | 151,122 | Pricing strategy review |
| Fact_Inventory | Price Matrix | ~6 min | 138,047 | Pricing strategy, not daily ops |
| Fact_Part_Transactions | Price Matrix | 2-3 min | 10,131,874 | Pricing strategy, not daily ops |

**Note:** Price Matrix shares facts with Inventory Analysis - coordinate schedules

---

### **On-Demand Only**

| Table | Project | Purpose |
|-------|---------|---------|
| Metadata Queries | Table-Column-Names-Search | Utility tool for data discovery |

---

## 🔗 Dimension Usage Matrix

Understanding which dimensions are used by which facts helps with impact analysis.

| Dimension | Used by # of Projects | Used by # of Facts | Example Projects |
|-----------|----------------------|-------------------|------------------|
| **dim_DateTable** | 14 | ~21 | Nearly all reports (universal time dimension) |
| **dim_BranchLocation** | 14 | ~21 | Nearly all reports (location-based analysis) |
| **dim_Parts** | 10 | ~15 | All parts-focused reports, JD Price Updates |
| **dim_CustomerList** | 5 | ~7 | Customer-facing reports |
| **dim_UniqueCustomers** | 1 | 2 | Unique Parts Customers (dual-fact) |
| **dim_AdjustmentType** | 1 | 1 | Parts Adjustments |
| **dim_Branch12_Parts** | 1 | 1 | Combine Vault Sales |
| **dim_JobCode** | 1 | 1 | First Pass Fill |
| **dim_VendorCode** | 1 | ~2 | Inventory Analysis, Price Matrix |
| **dim_Source** | 1 | ~2 | Inventory Analysis, Price Matrix |
| **dim_SLC** | 1 | ~2 | Inventory Analysis, Price Matrix |
| **dim_Franchise** | 2 | ~3 | Bin Location, Inventory Analysis, Price Matrix |
| **dim_DealerGroupCode** | 2 | ~3 | Bin Location, Inventory Analysis, Price Matrix |
| **dim_CommodityCode** | 1 | ~2 | Inventory Analysis |
| **dim_ModuleType** | 1 | ~2 | Inventory Analysis |
| **dim_PaymentMethod** | 1 | ~2 | Inventory Analysis |
| **dim_Date** (old) | 1 | ~2 | Inventory Analysis (older simple date table) |

**Impact Analysis:**
- Modifying **dim_DateTable** or **dim_BranchLocation** → Affects nearly ALL reports (14 projects)
- Modifying **dim_Parts** → Affects 10 parts-focused reports
- Modifying **dim_UniqueCustomers** → Only affects 1 report (2 facts in dual-fact architecture)

---

## ⚡ Performance Overview & Optimization

### **Performance by Refresh Time:**

**Fast (<2 minutes):**
- Semantic model refreshes (Power Query in report): 5 tables, ~1-2 min each
- Fact_InSalOrd_InSalPar: ~1:30
- Fact_NegativeOnHand_OnHandNoBin: ~1:30

**Standard (2-5 minutes):**
- Fact_Branch12_Transactions: 2-4 min
- Fact_Invoice_InventoryAnalysis: ~2:30
- Fact_PartsAdjustments: 2-3 min
- Fact_Parts_Open_Tickets: 2-3 min
- Fact_PendingInspections: 2-3 min
- Fact_PartsNotReordered: 3-3:30 min
- Fact_Invoice_UniqueCustomers: 2-3 min
- Fact_InTrans_UniqueCustomers: 2-3 min
- Fact_Part_Transactions: 2-3 min ✅ **(incremental)**

**Long (5-10 minutes):**
- Fact_FirstPassFill: ~5 min
- Fact_LaborJobSummary: ~5 min
- Fact_Inventory: ~6 min

**Very Long (>10 minutes):**
- ⚠️ **Fact_WorkOrderParts: 18-19 min** - **CRITICAL OPTIMIZATION NEEDED**

---

### **🚨 Critical Optimization Priority: Fact_WorkOrderParts**

**Current State:**
- Refresh Time: 18-19 minutes (longest fact by far)
- Project: Inspections
- Status: Daily scheduled

**Impact:**
- Blocks daily refresh pipeline completion
- Single longest-running fact in entire system
- 3-4x longer than next slowest fact

**Recommended Actions:**
1. **HIGH PRIORITY:** Implement incremental refresh (like Fact_Part_Transactions)
2. Analyze query performance (joins, filters, aggregations)
3. Consider partitioning strategy
4. Review source table indexing
5. Evaluate if full historical load needed daily

**Success Example:**
- Fact_Part_Transactions: 10M+ rows, 2-3 min with incremental refresh
- Proves incremental refresh pattern works for large datasets

---

### **✅ Incremental Refresh Successes**

| Fact Table | Rows | Refresh Time | Implementation Date | Notes |
|------------|------|--------------|---------------------|-------|
| Fact_Part_Transactions | 10,131,874 | 2-3 min | [Unknown] | ✅ Needs documentation on process |
| [Others?] | | | | Check for undocumented incremental |

**Pattern Documentation Needed:**
- How incremental refresh implemented in Fabric
- RangeStart/RangeEnd parameter usage
- Incremental column selection (date field)
- Full refresh frequency (monthly?)
- Archive/partition strategy

---

## 📋 Raw Table Documentation Status

✅ **COMPLETED - Both critical raw tables now documented:**

**InTrans_Incremental** ✅
- Used by: 9+ fact tables across 8 projects
- Critical for: Parts transactions, sales analysis, inventory tracking
- **10.2M+ rows**, 2-3 min refresh time with watermark-based incremental refresh
- **GOLD STANDARD** pattern - 90%+ time savings vs full refresh (2-3 min vs 30+ min)
- **Documentation:** [Raw_InTrans_Incremental.pq](.claude/queries/raw-tables/Raw_InTrans_Incremental.pq)
- 3x daily refresh with dedicated pipeline (morning/midday/evening)
- Template for optimizing Fact_WorkOrderParts (18-19 min → target 3-5 min)
- Powers 9+ critical fact tables with 6+ years of transaction history

**InHist_PmManage** ✅
- Used by: First Pass Fill report
- Critical for: First Pass Fill KPI and inventory availability metrics
- **722,579 rows**, 7-9 min refresh (increased from original 3-4 min)
- **Documentation:** [Raw_InHist_PmManage.pq](.claude/queries/raw-tables/Raw_InHist_PmManage.pq)
- Part of 7:30 AM bottleneck pipeline (needs optimization)
- Strategic column selection (22 of 62 columns, 65% reduction)
- 2-year rolling window with incremental refresh ready

---

## 🎯 Fact Table Patterns

### **Pattern 1: Incremental Refresh** (2+ implementations)

✅ **Fact_Part_Transactions** - 10M+ rows, 2-3 min refresh
- Source: InTrans_Incremental
- Incremental column: [Unknown - needs documentation]
- Success story for large dataset performance

⚠️ **Recommended for:**
- Fact_WorkOrderParts (18-19 min → target 3-5 min)
- Other large history tables

---

### **Pattern 2: Power Query in Report** (7 implementations)

No Fabric dataflow - built in Power Query at report level:
- Bin Location Report
- Part Sales with Low Margin (Fact_Intrans, dim_Parts_LowMargin)
- Physical Inventory
- Pin Capture (Fact_PinTransactions)

**Pros:**
- Simpler architecture
- No dataflow management
- Fast for smaller datasets

**Cons:**
- Refresh at semantic model level
- Limited to single report
- Can't share across reports

**When to Use:**
- Report-specific transformations
- Smaller datasets (<500K rows)
- Single-report use case

---

### **Pattern 3: Shared Fact Tables** (1 example)

**Fact_Inventory + Fact_Part_Transactions:**
- Created in: Inventory Analysis
- Reused in: Price Matrix
- **Benefit:** Single source of truth
- **Challenge:** Coordinate refresh schedules

**Recommendation:** Document shared facts clearly to avoid duplication

---

### **Pattern 4: Dual-Fact Architecture** (1 example)

**Unique Parts Customers:**
- Fact_Invoice_UniqueCustomers (Invoice source)
- Fact_InTrans_UniqueCustomers (InTrans source)
- Both serve dim_UniqueCustomers (11 high-value customers)
- **Pattern documented in:** dim_UniqueCustomers.pq

---

## 📅 Recommended Refresh Pipeline Architecture

### **Pipeline 1: Raw Tables** (~7:30 AM)
⚠️ Current systemic performance issues documented in raw tables
- 20 raw tables
- 15+ tables experiencing 200-600% slowdown
- **Action needed:** Investigate 7:30 AM time slot performance

---

### **Pipeline 2: Dimensions** (~7:45 AM)
✅ Already documented and running
- Daily: dim_DateTable, dim_Branch12_Parts, dim_UniqueCustomers, dim_Parts
- Total time: ~6-8 minutes
- Depends on: Raw tables completion

---

### **Pipeline 3: Daily Facts** (~8:00 AM)

**Currently Scheduled (5 facts):**
- Fact_Branch12_Transactions: 2-4 min
- Fact_LaborJobSummary: ~5 min
- Fact_PendingInspections: 2-3 min
- Fact_WorkOrderParts: ⚠️ **18-19 min**
- Physical Inventory: ~1 min (semantic model)
- **Current Total:** ~28-34 minutes

**Recommended to Add (12 facts):**
- Fact_InSalOrd_InSalPar: ~1:30
- Fact_FirstPassFill: ~5 min
- Fact_Invoice_InventoryAnalysis: ~2:30
- Fact_Inventory: ~6 min
- Fact_Part_Transactions: 2-3 min
- Fact_NegativeOnHand_OnHandNoBin: ~1:30
- Fact_PartsAdjustments: 2-3 min
- Fact_Parts_Open_Tickets: 2-3 min (both tables)
- Fact_PinTransactions: 1-2 min
- Fact_Invoice_UniqueCustomers: 2-3 min
- Fact_InTrans_UniqueCustomers: 2-3 min
- **Additional Total:** ~30-40 minutes

**Proposed Daily Pipeline Total:** ~60-75 minutes (1 hour - 1 hour 15 min)

**With Fact_WorkOrderParts optimization:** ~45-60 minutes target

---

### **Pipeline 4: Twice-Daily Facts** (9:30 AM, 4:00 PM)
✅ Already scheduled
- Fact_PartsNotReordered: 3-3:30 min
- Aligns with stock ordering process

---

### **Pipeline 5: Weekly Facts** (Monday 8:00 AM - Proposed)
- Bin Location (semantic): ~1 min
- Part Sales Low Margin (semantic): ~1 min each (2 tables)
- Price Matrix facts: ~6-9 min (shared with Inventory Analysis)
- **Total:** ~10-15 minutes

---

### **Pipeline 6: Semantic Model Refreshes** (Post-Facts)
After fact tables complete:
- Physical Inventory: ~1 min
- Any other direct Power Query reports

---

## 🚨 Action Items Summary

### **Immediate (This Week):**
1. ⚠️ **Document InTrans_Incremental raw table** (used by 9+ facts)
2. ⚠️ **Investigate Fact_WorkOrderParts performance** (18-19 min → target 3-5 min)
3. ⚠️ **Document incremental refresh pattern** (Fact_Part_Transactions success story)
4. ✅ **Schedule daily facts pipeline** (12 unscheduled facts)

### **Short-term (Next 2 Weeks):**
5. 📝 **Document InHist_PmManage raw table**
6. 📝 **Create project folder documentation** (12 projects have none)
7. 📝 **Document Price Matrix SharePoint CSV dependency**
8. ⚡ **Implement incremental refresh on Fact_WorkOrderParts**

### **Medium-term (Next Month):**
9. 📋 **Create weekly refresh pipeline** (5 facts)
10. 📋 **Document incremental refresh implementation guide**
11. 🔍 **Review all semantic model refresh times** (7 reports)
12. 🔍 **Identify other incremental refresh candidates**

---

## 📞 Quick Reference

### **Find a Fact Table:**

**By Business Question:**
- "What are past due accounts?" → Fact_InSalOrd_InSalPar (60 Days Past Due)
- "Where are bin locations?" → jdis_Part_Information raw (Bin Location)
- "How are Branch 12 parts moving?" → Fact_Branch12_Transactions (Combine Vault Sales)
- "What's first pass fill rate?" → Fact_FirstPassFill (First Pass Fill)
- "How many inspections completed?" → Fact_LaborJobSummary, Fact_PendingInspections (Inspections)
- "What parts used in work orders?" → Fact_WorkOrderParts (Inspections)
- "What's inventory value?" → Fact_Inventory, Fact_Part_Transactions (Inventory Analysis)
- "Any negative quantities?" → Fact_NegativeOnHand_OnHandNoBin
- "Which parts have low margin?" → Fact_Intrans, dim_Parts_LowMargin (Parts Low Margin)
- "What adjustments made?" → Fact_PartsAdjustments (Parts Adjustments)
- "Parts not reordered?" → Fact_PartsNotReordered (Parts Not Re-Ordered)
- "Parts on open orders?" → Fact_Parts_Open_Tickets (Open Parts Tickets)
- "What's physical inventory?" → Physical Inventory table
- "Transactions with PINs?" → Fact_PinTransactions (Pin Capture)
- "Price matrix effectiveness?" → Fact_Inventory, Fact_Part_Transactions (Price Matrix)
- "Unique customer transactions?" → Fact_Invoice_UniqueCustomers, Fact_InTrans_UniqueCustomers

**By Project Folder:**
See "Fact Tables by Project" section above

**By Refresh Schedule:**
- Daily: See "Pipeline 3" section
- Twice-Daily: Fact_PartsNotReordered
- Weekly candidates: See "Pipeline 5" section
- Not scheduled: 14 facts need scheduling

**By Performance:**
- Fastest: <2 min (see Performance Overview)
- Longest: Fact_WorkOrderParts (18-19 min - needs optimization)

---

## 📚 Documentation Status by Project

| Project | Status | Priority |
|---------|--------|----------|
| Inspections | ✅ Extensive docs | Maintain |
| Parts Low Margin | ✅ Some docs | Review/enhance |
| Open Parts Tickets | ✅ Notes exist | Review/enhance |
| 60 Days Past Due | ⚠️ None | High (financial) |
| First Pass Fill | ⚠️ None | High (critical KPI) |
| Inventory Analysis | ⚠️ None | High (10M+ rows) |
| Unique Parts Customers | ⚠️ None | Medium |
| Parts Adjustments | ⚠️ None | Medium |
| Parts Not Re-Ordered | ⚠️ None | Medium |
| Negative On Hand | ⚠️ None | Medium |
| Physical Inventory | ⚠️ None | Medium |
| Pin Capture | ⚠️ None | Low |
| Bin Location | ⚠️ None | Low (reference) |
| Combine Vault Sales | ⚠️ None | Low |
| Price Matrix | ⚠️ None | Low |

---

**For detailed query code, see: `projects/{project-name}/queries/fact-tables/{fact-name}.pq`**

---

### **Project: Transfers**
**Location:** `projects/transfers - report/queries/fact-tables/`
**Department:** Parts | Operations
**Created:** 02/25/2026 | **Modified:** 02/25/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Transfers | df_Fact_Transfers | TBD | TBD | Daily | Inter-branch transfer transaction history |
| Fact_InterbranchTransfers_Outstanding | TBD | TBD | TBD | Daily | Open/outstanding transfers (Phase 2) |

**Raw Tables:** InTrans_Incremental, jdis_Part_Information, Parts_InterbranchTransfers *(new — not yet in Lakehouse)*
**Dimensions:** dim_DateTable, dim_BranchLocation, dim_Parts
**Business Context:** Daily parts runs between locations. Tracks transfer qty/cost/lines by branch and type (WO, Counter, Stock). Answers whether branches have stocking issues or over-reliance on transfers vs. supplier orders.
**Status:** 🚧 In Development

---

### **Project: Associated Parts - Report**
**Location:** `projects/associated parts - report/queries/fact-tables/`
**Department:** Parts
**Created:** 08/27/2026

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_PartAssociation | (Fabric Notebook / DuckDB+Spark) | 44,326 | TBD | Weekly | Market-basket analysis: Part×Part co-occurrence across all sales invoices |

**Raw Tables:** InTrans_Incremental (24-month window, Type='I', Qty>0, basket-size capped at 25 distinct parts per invoice)
**Dimensions:** dim_Parts (referenced for enrichment; facts table stores PartA/PartB as text keys)
**Business Context:** For each Franchise × PartA × PartB, tracks how often invoices containing PartA also contain PartB — across all sales activity (counter sales and service work order parts). Identifies recommended parts for upsells and cross-sell opportunities. Raw counts stored (not pre-computed percentages) to enable both franchise-specific and company-wide rollup views from one table. See `.claude/queries/facts/Fact_PartAssociation.md` for full specification, `docs/superpowers/specs/2026-08-27-associated-parts-design.md` for design, and `docs/superpowers/plans/2026-08-27-associated-parts-recommended-parts.md` for validation and threshold profiling.
**Status:** 🚧 In Development — Notebook built and committed at `projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb`; weekly refresh cadence not yet wired into pipeline (scheduled per Task 9).

---

*Last Updated: August 27, 2026*
*Maintained by: Brian Fox / Claude Code Assistant*
*Next Review: Weekly (as facts are documented)*
