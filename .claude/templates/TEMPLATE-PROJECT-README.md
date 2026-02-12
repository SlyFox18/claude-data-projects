# [Project Name]

**Report Name:** [Display name in Power BI]
**Department:** [Parts | Service | Financial | Sales | Operations]
**Business Owner:** [Name/Department]
**Created:** [MM/DD/YYYY] | **Last Modified:** [MM/DD/YYYY]

---

## 📋 Project Overview

**Purpose:**
[1-2 sentence description of what this report does and why it exists]

**Key Business Questions:**
- [What business question does this answer?]
- [What decisions does this enable?]
- [Who are the primary users?]

**Success Metrics:**
- [How do you measure if this report is successful?]
- [What KPIs or metrics are most important?]

---

## 🗂️ Project Structure

```
project-name/
├── queries/
│   ├── fact-tables/          # Fact table Power Query files
│   │   ├── Fact_TableName.pq
│   │   └── ...
│   ├── dimensions/           # Project-specific dimensions (if any)
│   │   └── dim_Custom.pq
│   └── raw-tables/           # Project-specific raw tables (if any)
├── docs/                     # Additional documentation
│   ├── business-requirements.md
│   ├── data-model-diagram.png
│   └── testing-validation.md
└── README.md                 # This file
```

---

## 📊 Data Model

### **Fact Tables**

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_[Name] | df_Fact_[Name] | [X] | [X min] | [Daily/Weekly] | [Brief purpose] |

### **Dimensions Used**

| Dimension | Source | Relationship | Purpose |
|-----------|--------|--------------|---------|
| dim_DateTable | Shared | Fact[DateKey] → dim_DateTable[DateKey] | Time intelligence |
| dim_BranchLocation | Shared | Fact[BranchKey] → dim_BranchLocation[BranchKey] | Location filtering |
| [Other dims] | [Shared/Project] | [Relationship] | [Purpose] |

### **Raw Tables Used**

- **[RawTableName]** - [Purpose in this report]
- **[RawTableName]** - [Purpose in this report]

### **Relationships**

```
dim_DateTable ──────┐
                    ├──> Fact_[Name]
dim_BranchLocation ─┘

[Add diagram or text description of key relationships]
```

---

## 🔄 Refresh Strategy

### **Current Schedule:**
- **Frequency:** [Daily | Twice-daily | Weekly | Monthly | On-demand]
- **Time:** [7:30 AM | Custom time]
- **Pipeline:** [Standalone | Part of XXX pipeline]

### **Dependencies:**
1. **Raw Tables** → Must refresh first
2. **Dimensions** → Must refresh after raw tables
3. **Fact Tables** → Must refresh after dimensions
4. **Semantic Model** → Refreshes after fact tables complete

### **Refresh Times:**
- Total pipeline time: [X minutes]
- Breakdown:
  - Raw tables: [X min]
  - Dimensions: [X min]
  - Facts: [X min]
  - Semantic model: [X min]

---

## 🎯 Business Logic & Calculations

### **Key Measures (DAX):**

**[Measure Name]**
```dax
[Measure Name] =
    [DAX code here]
```
**Purpose:** [What this calculates]
**Business Rule:** [Any special business logic]

### **Important Filters/Business Rules:**

1. **[Rule Name]**
   - Logic: [Description]
   - Implemented: [Where - DAX measure, Power Query, etc.]
   - Example: [Example of rule in action]

---

## 🧪 Testing & Validation

### **Data Quality Checks:**

- [ ] **Row Count Validation**: Expected range [X-Y rows]
- [ ] **Date Range Validation**: Should include [date range logic]
- [ ] **Key Totals Match**: [Revenue/Cost/Qty] matches source system
- [ ] **No Duplicate Keys**: Fact table grain validated
- [ ] **Null Handling**: Critical fields checked for nulls

### **Business Validation:**

- [ ] **KPI Accuracy**: Key metrics verified against [source/expectation]
- [ ] **User Acceptance**: Report meets business requirements
- [ ] **Performance**: Report loads in < [X seconds]

### **Test Queries:**

```sql
-- Example validation query
SELECT
    [Key validation logic]
FROM [Source]
WHERE [Conditions]
```

---

## ⚠️ Known Issues & Limitations

**Current Issues:**
- [Issue description] - **Status:** [Open | In Progress | Resolved]
- [Issue description] - **Status:** [Open | In Progress | Resolved]

**Limitations:**
- [Data limitation - e.g., "Historical data only goes back to 2020"]
- [Business limitation - e.g., "Branch 12 excluded from calculations"]

**Future Enhancements:**
- [Planned improvement]
- [Planned improvement]

---

## 📈 Performance Optimization

### **Current Performance:**
- Refresh time: [X minutes]
- Report load time: [X seconds]
- Dataset size: [X MB/GB]

### **Optimization History:**
- [Date]: [Change made] - Result: [X% improvement]
- [Date]: [Change made] - Result: [X% improvement]

### **Future Optimization Opportunities:**
- [ ] [Potential optimization - e.g., "Implement incremental refresh"]
- [ ] [Potential optimization - e.g., "Add aggregations"]

---

## 👥 Users & Access

**Primary Users:**
- [User/Department] - Use case: [How they use it]
- [User/Department] - Use case: [How they use it]

**Access Level:**
- Workspace: [Workspace name]
- Security: [Row-level security rules if any]
- Sharing: [How report is shared]

---

## 📚 Related Documentation

- **Fact Table Queries:** `queries/fact-tables/`
- **Dimension Documentation:** `.claude/queries/dimensions/`
- **Raw Table Documentation:** `.claude/queries/raw-tables/`
- **Fact Tables Registry:** `.claude/queries/facts/FACT-TABLES-SUMMARY.md`

---

## 🔧 Troubleshooting

**Common Issues:**

**Issue:** [Description]
**Cause:** [Root cause]
**Solution:** [How to fix]

**Issue:** [Description]
**Cause:** [Root cause]
**Solution:** [How to fix]

---

## 📝 Change Log

| Date | Change | Impact | Modified By |
|------|--------|--------|-------------|
| [MM/DD/YYYY] | [Description of change] | [High/Medium/Low] | [Name] |
| [MM/DD/YYYY] | [Description of change] | [High/Medium/Low] | [Name] |

---

## 💡 Tips for AI Assistance

**When asking AI for help with this report:**

1. Reference this README for context
2. Check `.claude/queries/facts/FACT-TABLES-SUMMARY.md` for fact table metadata
3. Review dimension documentation in `.claude/queries/dimensions/`
4. Check raw table documentation for source details
5. Mention specific business rules or calculations that need attention

**Common AI Tasks:**
- "Optimize the [fact table name] refresh time"
- "Add a new measure for [business requirement]"
- "Investigate why [specific calculation] doesn't match [source]"
- "Document the [specific component]"
