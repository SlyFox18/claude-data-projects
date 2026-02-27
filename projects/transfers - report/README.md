# Transfers

**Report Name:** Transfers
**Department:** Parts | Operations
**Business Owner:** [To be determined]
**Created:** 02/25/2026 | **Last Modified:** 02/25/2026

---

## 📋 Project Overview

**Purpose:**
This report analyzes inter-branch parts transfers — tracking movement of parts between locations, classifying transfer types, and measuring the cost and volume effectiveness of the company's daily parts run program.

**Key Business Questions:**
- Which branches are transferring the most parts (by qty, cost, and lines)?
- Are transfers driven by work orders (service shop), counter demand (customer orders), or stock replenishment?
- How does transfer volume compare to total on-hand inventory at each location?
- Are there branches with chronic supply issues that should be ordering more from the supplier?
- Is the daily parts run program cost-effective?

**Success Metrics:**
- Transfer qty, cost, and lines by branch (to/from)
- Transfer type breakdown (WO, Counter, Stock)
- Transfer qty vs. total inventory qty (by part/branch)
- Transfer cost vs. total inventory cost (by part/branch)
- Outstanding/open transfer visibility

---

## 🗂️ Project Structure

```
transfers - report/
├── queries/
│   ├── fact-tables/          # Fact table Power Query files
│   ├── dimensions/           # Project-specific dimensions (if any)
│   └── raw-tables/           # Raw table queries (if project-specific)
├── reports/                  # .pbip files
└── README.md                 # This file
```

---

## 📊 Data Model

### **Fact Tables**

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_Transfers | df_Fact_Transfers | TBD | TBD | Daily | Transfer transaction history (InTrans-based) |
| Fact_InterbranchTransfers_Outstanding | TBD | TBD | TBD | Daily | Open/outstanding transfers (Parts_InterbranchTransfers) |

### **Dimensions Used**

| Dimension | Source | Relationship | Purpose |
|-----------|--------|--------------|---------|
| dim_DateTable | Shared | Fact[DateKey] → dim_DateTable[DateKey] | Time intelligence |
| dim_BranchLocation | Shared | Fact[BranchKey] → dim_BranchLocation[BranchKey] | Source branch filtering |
| dim_BranchLocation (TransferBranch) | Shared | Fact[TransferBranchKey] → dim_BranchLocation[BranchKey] | Destination branch filtering |
| dim_Parts | Shared | Fact[PartKey] → dim_Parts[PartKey] | Part details |

### **Raw Tables Used**

- **InTrans_Incremental** - Core transfer transaction history (Type column drives classification)
- **jdis_Part_Information** - Current inventory qty/cost by part/branch (for inventory context page)
- **Parts_InterbranchTransfers** - New table — outstanding/open transfer records (Page 3)

### **Relationships**

```
dim_DateTable ───────────────────┐
dim_BranchLocation (Branch) ─────┤──> Fact_Transfers
dim_BranchLocation (TransferBranch)─┘
dim_Parts ───────────────────────┘
```

---

## 🔄 Refresh Strategy

### **Current Schedule:**
- **Frequency:** Daily
- **Time:** Part of morning pipeline (after InTrans_Incremental refreshes)
- **Pipeline:** [To be determined — Phase 4 Facts or standalone]

### **Dependencies:**
1. **Raw_InTrans_Incremental** → Must refresh first (Phase 2 - incremental)
2. **jdis_Part_Information** → Must refresh first (Phase 1 - raw)
3. **Parts_InterbranchTransfers** → Must refresh first (Phase 1 - raw, new table)
4. **Dimensions** → Must refresh after raw tables (Phase 3)
5. **Fact_Transfers** → Refreshes after dimensions (Phase 4)
6. **Semantic Model** → Refreshes after fact tables (Phase 5)

---

## 🎯 Business Logic & Calculations

### **Transfer Type Classification**
The `Type` column in InTrans_Incremental determines the transfer classification:
- **[To be determined]** → Work Order Transfer (service shop demand)
- **[To be determined]** → Counter Transfer (customer-facing demand)
- **[To be determined]** → Stock Transfer (replenishment)

*Type values and business rules to be confirmed with stakeholder.*

### **Key Measures (DAX):**

*(To be developed)*

- Transfer Qty
- Transfer Lines
- Transfer Cost (CostValue)
- Total Inventory Qty (from jdis_Part_Information)
- Total Inventory Cost (from jdis_Part_Information)
- Transfer Qty % of Inventory Qty
- Transfer Cost % of Inventory Cost

---

## 📄 Report Pages

### **Page 1 — Transfer Activity by Branch**
Transfer Qty, Cost ($), and Lines — to and from each location. Slice by transfer type.

### **Page 2 — Transfer vs. Inventory Context**
Transfer qty vs. total inventory qty by part/branch; same comparison for cost and lines.

### **Page 3 — Outstanding Transfers** *(Phase 2)*
Open/in-transit transfers from Parts_InterbranchTransfers table. Lower priority — depends on new table being added to Lakehouse.

### **Page 4 — Profitability Analysis** *(Future)*
Fuel cost, labor cost, vehicle cost, etc. Data sources TBD.

---

## 🧪 Testing & Validation

### **Data Quality Checks:**

- [ ] **Row Count Validation**: Expected range [TBD]
- [ ] **Date Range Validation**: Should include 1/1/2023 - current date
- [ ] **Transfer Type Coverage**: All Type values accounted for and classified
- [ ] **Branch Balance**: Transfers OUT of Branch A should appear as IN to Branch B
- [ ] **Null Handling**: TransferBranch nulls handled (non-transfer transactions filtered)

### **Business Validation:**

- [ ] **KPI Accuracy**: Transfer counts/cost verified against source system
- [ ] **User Acceptance**: Report meets stakeholder requirements
- [ ] **Performance**: Report loads in < 5 seconds

---

## ⚠️ Known Issues & Limitations

**Current Issues:**
- Parts_InterbranchTransfers table does not yet exist in Lakehouse — Page 3 blocked until added

**Limitations:**
- Profitability page (Page 4) requires fuel/labor/vehicle cost data not yet identified
- Historical data starts 1/1/2023

**Future Enhancements:**
- Page 3: Outstanding transfers (Parts_InterbranchTransfers)
- Page 4: Profitability analysis (fuel, labor, vehicle costs)

---

## 📝 Change Log

| Date | Change | Impact | Modified By |
|------|--------|--------|-------------|
| 02/25/2026 | Initial scaffold | Low | Brian Fox |

---

## 📚 Related Documentation

- **Fact Table Queries:** `queries/fact-tables/`
- **Dimension Documentation:** `.claude/queries/dimensions/`
- **Raw Table Documentation:** `.claude/queries/raw-tables/`
- **Fact Tables Registry:** `.claude/queries/facts/FACT-TABLES-SUMMARY.md`
- **InTrans_Incremental Docs:** `.claude/queries/raw-tables/Raw_InTrans_Incremental.pq`
