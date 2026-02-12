# Dimensions Summary

**Purpose:** Quick reference guide for all dimension tables in the Fabric Lakehouse data model.

**Last Updated:** January 15, 2026

**Total Dimensions Documented:** 16 (plus 1 awaiting deployment)

---

## 📊 Quick Stats Overview

| Category | Count | Total Rows | Avg Refresh Time |
|----------|-------|------------|------------------|
| **Daily Refresh Dims** | 4 | 314,269 | ~5-6 min avg |
| **Monthly Refresh Dims** | 12 | 5,756 | ~1:30 avg |
| **Awaiting Deployment** | 1 | 71,640 | ~2 min |
| **TOTAL** | 17 | 391,665 | - |

---

## 🔄 Dimensions by Refresh Schedule

### **Daily Refresh (7:45 AM Pipeline)**

These dimensions refresh daily as part of the post-raw-data pipeline:

| Dimension | Rows | Refresh Time | Last Updated | Critical Notes |
|-----------|------|--------------|--------------|----------------|
| **dim_DateTable** | 4,018 | <15 sec ✅ | 11/25/2025 | Type 0 - Time intelligence, 76 columns, 2020-2030 range, YTD/QTD/MTD flags |
| **dim_Branch12_Parts** | 1,485 | ~1:30 ✅ | 10/17/2025 | Type 1 - Branch 12 specific parts with R12 metrics from fact table |
| **dim_UniqueCustomers** | 11 | ~1:30 ✅ | 11/04/2025 | Type 1 - In-memory table, DUAL-FACT architecture, 5 identification methods |
| **dim_Parts** | 308,709 | ~5-6 min ⚠️ | 01/12/2026 | Type 1 - **OPTIMIZED**, 22 columns, critical deduplication fix |

**Total Daily:** 314,223 rows in ~6-8 minutes combined

---

### **Monthly Refresh (Recommended: 1st Monday 8:00 AM)**

#### **Parts Dimension Family** (All from jdis_Part_Information)

These 5 dimensions extract distinct classification codes from the parts master:

| Dimension | Rows | Refresh Time | Last Updated | Pattern Notes |
|-----------|------|--------------|--------------|---------------|
| **dim_SLC** | 123 | ~1:30 ✅ | 06/23/2025 | Unknown record (SLCKey=-1) |
| **dim_Source** | 267 | ~1:30 ✅ | 06/23/2025 | Unknown record (SourceKey=-1), late-stage text cleaning |
| **dim_CommodityCode** | 780 | ~1:30 ✅ | 06/23/2025 | Unknown record pattern |
| **dim_DealerGroupCode** | 1,813 | ~1:40 ⚠️ | 06/23/2025 | Unknown record, ⚠️ optimization opportunity (redundant operations) |
| **dim_VendorCode** | 1,311 | ~1:30 ✅ | 05/29/2025 | ⚠️ **NO Unknown record** (consider adding for consistency) |

**Subtotal:** 4,294 parts classification codes in ~7-8 minutes

---

#### **Other Monthly Dimensions**

| Dimension | Rows | Refresh Time | Last Updated | Key Features |
|-----------|------|--------------|--------------|--------------|
| **dim_AdjustmentType** | 7 | ~1 min ✅ | 12/23/2025 | Type 0 - Static, hard-coded adjustment types |
| **dim_Franchise** | 43 | ~1:30 ✅ | 08/20/2025 | Type 1 - 15 columns BI, manufacturer classification |
| **Dim_JobType** | 7 | ~2 min ⚠️ | 10/07/2025 | Type 1 - Work order billing types, ⚠️ 2 min for 7 rows |
| **dim_BranchLocation** | 69 | ~1:30 ✅ | 08/20/2025 | Type 1 - **CRITICAL FIX**: Smart filtering (Seminole restored) |
| **dim_ModuleType** | 11 | ~1:30 ⚠️ | 09/25/2025 | Type 1 - Complex customer override logic (Internal/Warranty) |
| **dim_PaymentMethod** | 5 | ~1:30 ✅ | 10/15/2025 | Type 1 - 5 payment methods with category grouping |
| **dim_Technician_Code_Names** | 1,417 | ~1:30 ✅ | 08/18/2025 | Type 1 - 16 columns, 5 name formats, DataQualityScore |

**Subtotal:** 1,559 rows in ~11-12 minutes

**Total Monthly:** 5,853 rows in ~18-20 minutes combined

---

### **Not Yet Scheduled (Awaiting Deployment)**

| Dimension | Rows | Refresh Time | Last Updated | Status |
|-----------|------|--------------|--------------|--------|
| **dim_Vehicle** | 71,640 | ~2 min ✅ | 08/15/2025 | **FUTURE POTENTIAL** - 26 columns, service intelligence, dual-source |

**Note:** Determine schedule when use cases defined (daily for service ops, weekly for analytics, monthly for planning)

---

## 📋 Dimensions by Business Domain

### **Parts & Inventory** (7 dimensions)

1. **dim_Parts** (308,709) - Master parts dimension with inventory, pricing, sales intelligence
2. **dim_Branch12_Parts** (1,485) - Branch 12 specific parts with R12 metrics
3. **dim_SLC** (123) - Stock Location Code classification
4. **dim_Source** (267) - Source classification
5. **dim_CommodityCode** (780) - Commodity classification
6. **dim_DealerGroupCode** (1,813) - Dealer group classification
7. **dim_VendorCode** (1,311) - Vendor/supplier classification

**Business Value:** Parts analysis, inventory management, supplier analytics, procurement optimization

---

### **Customers & Sales** (3 dimensions)

1. **dim_UniqueCustomers** (11) - High-value customer tracking with dual-fact architecture
2. **dim_PaymentMethod** (5) - Payment method classification with category grouping
3. **dim_ModuleType** (11) - Invoice module type with customer override logic

**Business Value:** Customer analytics, payment analysis, sales tracking, YTD vs PYTD comparisons

---

### **Operations & Service** (4 dimensions)

1. **dim_BranchLocation** (69) - Branch/location dimension with operational priority
2. **dim_Technician_Code_Names** (1,417) - Technician master with multiple name formats
3. **dim_Vehicle** (71,640) - Vehicle/equipment master with service intelligence (awaiting deployment)
4. **Dim_JobType** (7) - Work order type classification

**Business Value:** Service operations, labor tracking, fleet management, resource planning

---

### **Reference & Classification** (3 dimensions)

1. **dim_DateTable** (4,018) - Comprehensive time intelligence dimension
2. **dim_AdjustmentType** (7) - Parts adjustment type classification (static)
3. **dim_Franchise** (43) - Manufacturer classification with BI enrichment

**Business Value:** Time intelligence, data quality, business classification

---

## 🎯 Dimension Types Summary

### **Type 0 - Static Dimensions** (2)
- **dim_AdjustmentType** - Hard-coded reference data
- **dim_DateTable** - Mathematically generated (but refreshed daily for dynamic flags)

**Characteristic:** Data doesn't change or changes very rarely

---

### **Type 1 - Overwrite Dimensions** (14)
All other dimensions follow Type 1 pattern - current state only, no history tracking:
- Parts dimensions (7)
- Customer dimensions (2) - dim_UniqueCustomers has soft deletes via IsActive
- Operations dimensions (3)
- Reference dimensions (2)

**Characteristic:** Updates overwrite existing records, preserve current state only

---

### **Type 1 with Soft Deletes** (1)
- **dim_UniqueCustomers** - Uses IsActive flag for hiding customers without breaking history

**Characteristic:** Never delete rows, use flag to hide instead

---

## 🔍 Special Patterns & Features

### **Unknown Record Pattern** (Used by 8 dimensions)

Dimensions implementing "Unknown" record for missing values (negative keys):
- ✅ dim_SLC (SLCKey = -1)
- ✅ dim_Source (SourceKey = -1)
- ✅ dim_CommodityCode (CommodityCodeKey = -1)
- ✅ dim_DealerGroupCode (DealerGroupCodeKey = -1)
- ✅ dim_AdjustmentType (AdjustmentTypeKey = -1)
- ✅ dim_Branch12_Parts (PartNumberKey = -1)
- ✅ dim_BranchLocation (LocationKey = -1)
- ✅ dim_Technician_Code_Names (TechnicianKey = -1)

**Missing Unknown Pattern:**
- ⚠️ dim_VendorCode - Should consider adding for consistency
- dim_Parts - Has special handling (PrimaryKey = -1 "UNKNOWN")
- dim_PaymentMethod - Self-updating from Invoice, assumes valid values
- dim_ModuleType - Self-updating from Invoice, assumes valid values
- dim_UniqueCustomers - In-memory table, manually maintained
- dim_DateTable - Time-based, no "unknown" needed
- Dim_JobType - Self-updating, assumes valid values
- dim_Franchise - Self-updating, assumes valid values

---

### **Self-Updating Pattern** (Used by 12 dimensions)

Dimensions that automatically discover new values from source:
- **Parts Family (5):** dim_SLC, dim_Source, dim_CommodityCode, dim_DealerGroupCode, dim_VendorCode
- **Parts Master (1):** dim_Parts
- **Invoice-Based (2):** dim_PaymentMethod, dim_ModuleType
- **Technician (1):** dim_Technician_Code_Names
- **Job Classification (2):** Dim_JobType, dim_Franchise
- **Branch (1):** dim_Branch12_Parts

**Manual/Static:**
- dim_AdjustmentType (hard-coded)
- dim_DateTable (mathematically generated)
- dim_UniqueCustomers (in-memory, manually maintained)
- dim_BranchLocation (self-updating but with critical filtering logic)
- dim_Vehicle (dual-source integration)

---

### **Dual-Source Integration** (2 dimensions)

- **dim_Vehicle** - Combines Raw_VehicleFleet + Raw_VehicleStock
- **dim_UniqueCustomers** - Serves both Fact_InTrans_UniqueCustomers and Fact_Invoice_UniqueCustomers

---

### **Multiple Display Name Formats** (2 dimensions)

**dim_Technician_Code_Names** (5 formats):
- TechnicianDisplayName: "CODE - Full Name"
- TechnicianFullName: "FirstName LastName"
- TechnicianShortName: "F. LastName"
- PreferredDisplayName: Auto-selects based on length
- SearchableName: UPPERCASE combined text

**dim_Vehicle** (3 formats):
- VehicleDisplayName: "YYYY Make Model (Registration)"
- VehicleShortName: Registration or "S" + StockNumber
- MakeModel: "Make Model"

---

### **Data Quality Scoring** (3 dimensions)

Dimensions with built-in data quality assessment (0-100 scale):
- **dim_Parts** - Based on identification, specifications, service readiness
- **dim_Technician_Code_Names** - Based on code validity (25), name completeness (50), status (25)
- **dim_Vehicle** - Based on identification (40), details (30), service readiness (30)

---

### **Complex Business Logic** (4 dimensions)

**dim_ModuleType** - Customer override logic:
- Internal customers (71-87, 9001-9007) → Special module type mapping
- Warranty customers (41-57, 9051-9057) → Special module type mapping
- 11 explicit categories with manual key assignment

**dim_UniqueCustomers** - 5 identification methods:
1. TradeType (location-based)
2. TradeType + Branch (location split)
3. CustomerOrderNumber (text pattern)
4. CustomerOrderNumber + Branch (text + location)
5. CustomerNo (direct match)

**dim_BranchLocation** - Critical filtering logic:
- Remove Hourly (H*) and Salary (S*) branches
- Keep all operational branches (69 total)
- **Fixed:** Table.Skip(30) was removing valid branches including Seminole

**dim_Vehicle** - Service intelligence (pre-calculated):
- ServiceComplexity (High/Medium/Standard)
- WarrantyLikelihood (Very High/High/Medium/Low/Unlikely)
- PartsAvailability (Excellent/Good/Fair/Limited)
- MaintenancePriority (1-10 scale)
- Equipment categorization (Heavy Equipment/Commercial Truck/Domestic/Import/Other)

---

## ⚡ Performance & Optimization Notes

### **Optimized Dimensions**

**dim_Parts** - Recent optimization work (01/12/2026):
- ✅ Early blank removal/deduplication (saves ~20 seconds)
- ✅ Text.Upper instead of Text.Proper on Description (saves 30-60 seconds)
- ✅ Strategic column selection early
- ✅ **CRITICAL FIX:** Final deduplication prevents duplicate PartNumber relationship errors
- Target: <5 minutes (15-25% improvement from ~6 minutes)

---

### **Optimization Opportunities Documented**

**dim_DealerGroupCode** (1,813 rows, ~1:40):
- ⚠️ Redundant operations: 4 distinct, 3 appends, 3 sorts
- Potential: Reduce to ~1:00 minute with optimization

**Dim_JobType** (7 rows, ~2 min):
- ⚠️ 2 minutes for 7 rows seems high
- Not urgent but could investigate

**dim_ModuleType** (11 rows, ~1:30):
- ⚠️ 1:30 for 11 rows due to large Invoice source table
- Acceptable but noted

---

### **Performance Baselines**

**Excellent Performance** (Processing speed relative to row count):
- dim_DateTable: <15 seconds for 4,018 rows (time-based generation)
- dim_Parts: ~5-6 minutes for 308,709 rows (optimized)
- dim_Vehicle: ~2 minutes for 71,640 rows (dual-source)
- dim_Technician: ~1:30 for 1,417 rows (16 columns with transformations)

**Acceptable Performance:**
- Parts dimension family: ~1:30 each for distinct extraction from 1M+ parts
- Most monthly dimensions: ~1-2 minutes for <100 rows

---

## 🔗 Relationship Patterns

### **Standard Many-to-One Relationships**

All dimensions follow standard star schema pattern:
- **Cardinality:** Many-to-One (many fact records to one dimension record)
- **Cross-filter Direction:** Single (dimension filters facts)
- **Join Column:** Surrogate key (e.g., PartNumberKey, TechnicianKey)

---

### **Critical Integration Points**

**dim_Vehicle.PrimaryLookup**:
- CRITICAL for work order assignment
- Must match Fact_WorkOrderHeader VehicleLookupKey logic exactly
- Logic: Registration → "Stk# " + StockNumber → VehicleIdentifier (priority order)

**dim_UniqueCustomers**:
- Serves TWO fact tables (dual-fact architecture)
- Fact_InTrans_UniqueCustomers (location-based customers 1-3, individual customers 7-9)
- Fact_Invoice_UniqueCustomers (text-pattern customers 4-6, 10-11)

**dim_Parts**:
- Central to all parts/inventory analysis
- Most relationships in the model
- Performance-critical due to size (308K rows)

---

## 📊 Dimension Size Distribution

### **By Row Count:**

**Tiny (< 50 rows):**
- dim_PaymentMethod (5)
- dim_AdjustmentType (7)
- Dim_JobType (7)
- dim_UniqueCustomers (11)
- dim_ModuleType (11)
- dim_Franchise (43)

**Small (50-500 rows):**
- dim_BranchLocation (69)
- dim_SLC (123)
- dim_Source (267)

**Medium (500-5,000 rows):**
- dim_CommodityCode (780)
- dim_VendorCode (1,311)
- dim_Technician_Code_Names (1,417)
- dim_Branch12_Parts (1,485)
- dim_DealerGroupCode (1,813)
- dim_DateTable (4,018)

**Large (> 5,000 rows):**
- dim_Vehicle (71,640) - awaiting deployment
- dim_Parts (308,709) - largest dimension

---

## 🎯 Recommended Refresh Pipeline Structure

### **Pipeline 1: Daily Dimensional Refresh (7:45 AM)**

**Sequence:**
1. dim_DateTable (<15 sec) - No dependencies
2. dim_Parts (~5-6 min) - Depends on jdis_Part_Information
3. dim_Branch12_Parts (~1:30) - Depends on dim_Parts + Fact table
4. dim_UniqueCustomers (~1:30) - In-memory, no dependencies

**Total Time:** ~8-9 minutes
**Dependencies:** Must run after raw data pipeline completes (~7:30 AM)

---

### **Pipeline 2: Monthly Reference Data (1st Monday 8:00 AM)**

**Group A - Parts Dimension Family** (can run in parallel):
- dim_SLC (~1:30)
- dim_Source (~1:30)
- dim_CommodityCode (~1:30)
- dim_DealerGroupCode (~1:40)
- dim_VendorCode (~1:30)

**Group B - Other Reference Dimensions** (can run in parallel with Group A):
- dim_AdjustmentType (~1 min)
- dim_Franchise (~1:30)
- Dim_JobType (~2 min)
- dim_BranchLocation (~1:30)
- dim_ModuleType (~1:30)
- dim_PaymentMethod (~1:30)
- dim_Technician_Code_Names (~1:30)

**Total Time:** ~2-3 minutes (if parallel), ~18-20 minutes (if sequential)
**Dependencies:** All depend on jdis_Part_Information or other raw tables being current

---

### **Pipeline 3: Service Dimensions (When Deployed)**

**dim_Vehicle:**
- Schedule: TBD based on use case
  - Daily (8:00 AM) if used for real-time service operations
  - Weekly (Monday 8:00 AM) if used for analytics
  - Monthly (1st Monday 8:00 AM) if used for strategic planning
- Dependencies: Raw_VehicleFleet, Raw_VehicleStock

---

## 🚨 Critical Fixes & Business Rules

### **Critical Fixes Documented**

**dim_Parts - Duplicate Prevention (01/12/2026):**
- **Issue:** Duplicate PartNumber values caused relationship errors
- **Fix:** Final deduplication step after all transformations
- **Impact:** CRITICAL - Prevents "column contains duplicate value" errors
- **Code Location:** dim_Parts.pq, Step 10

**dim_BranchLocation - Smart Filtering (08/20/2025):**
- **Issue:** Table.Skip(30) was removing valid operational branches including Seminole
- **Fix:** Smart filtering based on BranchID patterns (remove H* and S* only)
- **Impact:** CRITICAL - Restored 69 operational branches, used in ALL reports
- **Code Location:** dim_BranchLocation.pq, filtering step

---

### **Critical Business Rules**

**dim_ModuleType - Customer Override Logic:**
- Internal customers (71-87, 9001-9007) have special module type mapping
- Warranty customers (41-57, 9051-9057) have special module type mapping
- 11 explicit categories with predictable key assignments (1-11)
- Changes require updating both dimension AND fact table logic

**dim_UniqueCustomers - Identification Methods:**
- 5 different methods for identifying customers across 2 fact tables
- Changes require updating corresponding fact table logic
- Never reuse CustomerKey values (breaks historical data)
- Use IsActive=false to hide, never delete rows

**dim_Vehicle - PrimaryLookup Field:**
- MUST match Fact_WorkOrderHeader VehicleLookupKey logic exactly
- Priority: Registration → "Stk# " + StockNumber → VehicleIdentifier
- Changes break work order vehicle assignment functionality

**dim_BranchLocation - Filtering Logic:**
- Remove H* (Hourly) and S* (Salary) branches only
- Keep all operational branches (69 total)
- Changing filtering logic affects ALL reports

---

## 📝 Data Quality Notes

### **Dimensions with Validation Queries**

All dimensions include post-refresh validation queries for:
- Row count verification
- Duplicate key checks
- Blank/null value checks
- Business logic validation
- Relationship integrity checks

---

### **Dimensions Requiring Special Monitoring**

**dim_Parts:**
- Monitor for duplicates (critical for relationships)
- Track optimization effectiveness (target <5 minutes)
- Validate deduplication step

**dim_UniqueCustomers:**
- Monitor customer identification accuracy
- Validate fact table matching logic
- Track transaction counts per customer

**dim_Vehicle (when deployed):**
- Monitor PrimaryLookup uniqueness
- Validate work order matching accuracy
- Track data quality scores distribution

**dim_BranchLocation:**
- Ensure 69 operational branches remain
- Validate Seminole branch exists (BranchID "1")
- Monitor for accidental filtering changes

---

## 🔍 Quick Reference: Find a Dimension

### **By Business Need:**

**I need to analyze...**
- **Parts inventory** → dim_Parts (master), dim_Branch12_Parts (Branch 12 specific)
- **Parts sourcing** → dim_VendorCode, dim_Source, dim_CommodityCode
- **Customers** → dim_UniqueCustomers (high-value), dim_CustomerList (full list, TBD)
- **Time periods** → dim_DateTable (comprehensive time intelligence)
- **Branches/Locations** → dim_BranchLocation (69 operational locations)
- **Technicians** → dim_Technician_Code_Names (1,417 technicians, 5 name formats)
- **Vehicles/Equipment** → dim_Vehicle (71,640 units, awaiting deployment)
- **Sales/Invoices** → dim_PaymentMethod, dim_ModuleType
- **Work orders** → Dim_JobType, dim_Technician_Code_Names, dim_Vehicle
- **Manufacturers** → dim_Franchise (43 manufacturers with BI)
- **Parts adjustments** → dim_AdjustmentType (7 types)

---

### **By Source Table:**

**jdis_Part_Information sources:**
- dim_Parts (master dimension)
- dim_SLC (123 codes)
- dim_Source (267 codes)
- dim_CommodityCode (780 codes)
- dim_DealerGroupCode (1,813 codes)
- dim_VendorCode (1,311 codes)
- dim_Franchise (43 manufacturers)

**Invoice sources:**
- dim_PaymentMethod (5 methods)
- dim_ModuleType (11 types)

**Raw_Technician source:**
- dim_Technician_Code_Names (1,417 technicians)

**Raw_BranchOperational source:**
- dim_BranchLocation (69 branches)

**Dual-source:**
- dim_Vehicle (Raw_VehicleFleet + Raw_VehicleStock)

**In-memory/Manual:**
- dim_UniqueCustomers (11 customers)
- dim_AdjustmentType (7 types)

**Generated:**
- dim_DateTable (2020-2030 mathematical generation)

---

## 📚 Documentation Files

All dimension queries stored in: `.claude/queries/dimensions/`

**Individual Dimension Files:**
- dim_AdjustmentType.pq
- dim_Branch12_Parts.pq
- dim_BranchLocation.pq
- dim_CommodityCode.pq
- dim_DateTable.pq
- dim_DealerGroupCode.pq
- dim_Franchise.pq
- Dim_JobType.pq
- dim_ModuleType.pq
- dim_Parts.pq
- dim_PaymentMethod.pq
- dim_SLC.pq
- dim_Source.pq
- dim_Technician_Code_Names.pq
- dim_UniqueCustomers.pq
- dim_Vehicle.pq
- dim_VendorCode.pq

**Summary Files:**
- DIMENSIONS-SUMMARY.md (this file)
- REFRESH-TIMES.md (comprehensive refresh tracking)

---

## 🎯 Next Steps & Future Work

### **Immediate:**
- [ ] Document remaining dimensions (dim_CustomerList, dim_Parts_LowMargin if in use)
- [ ] Begin fact table documentation (start with top 3 core facts)

### **Short-term:**
- [ ] Create model relationships document (star schema mapping)
- [ ] Document pipeline architecture (refresh sequences and dependencies)
- [ ] Deploy dim_Vehicle when service reporting requirements defined

### **Medium-term:**
- [ ] Optimize dim_DealerGroupCode (reduce redundant operations)
- [ ] Consider adding Unknown record pattern to dim_VendorCode
- [ ] Investigate dim_Parts further optimization opportunities
- [ ] Address 7:30 AM performance bottleneck (raw tables)

### **Long-term:**
- [ ] DAX measures library documentation
- [ ] Report inventory and dependencies
- [ ] Data quality monitoring framework
- [ ] Optimization roadmap execution

---

## 📞 Quick Help

**Common Questions:**

**Q: Which dimensions refresh daily?**
A: dim_DateTable, dim_Branch12_Parts, dim_UniqueCustomers, dim_Parts

**Q: Which dimensions should refresh together monthly?**
A: Parts dimension family (SLC, Source, Commodity, Dealer, Vendor) + other reference dims

**Q: Which dimension has the critical deduplication fix?**
A: dim_Parts - prevents duplicate PartNumber relationship errors

**Q: Which dimension was missing Seminole branch?**
A: dim_BranchLocation - fixed with smart filtering instead of Table.Skip(30)

**Q: Which dimensions have Unknown records?**
A: Most do (8 dimensions) - see "Unknown Record Pattern" section. VendorCode doesn't (consider adding).

**Q: Which dimension isn't deployed yet?**
A: dim_Vehicle (71,640 rows) - awaiting service reporting requirements

**Q: Which dimensions have complex business logic?**
A: dim_ModuleType (customer overrides), dim_UniqueCustomers (5 identification methods), dim_BranchLocation (filtering), dim_Vehicle (service intelligence)

---

**For detailed information on any dimension, see the individual .pq file in `.claude/queries/dimensions/`**

---

*Last Updated: January 15, 2026*
*Maintained by: Brian Fox / Claude Code Assistant*
