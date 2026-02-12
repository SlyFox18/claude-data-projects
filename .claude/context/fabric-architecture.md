# Microsoft Fabric Lakehouse Architecture

## Overview

All Power BI reports in this repository use a centralized data architecture built on Microsoft Fabric with an F4 capacity.

**Primary Workspace:** LH_Master_Data
**Primary Lakehouse:** LH_Master_Data
**Capacity:** F4 (CU optimization is critical)
**Source System:** SQL Anywhere database (ODBC connection)

## Lakehouse Organization

The LH_Master_Data workspace contains the following folder structure:

```
LH_Master_Data/
├── Lakehouse: LH_Master_Data
├── Dataflows/
│   ├── 01 - Raw Sources/
│   ├── 02 - Analysis/
│   ├── 03 - Dimensions/
│   ├── 04 - Fact/
│   │   ├── Inspection Report Queries/
│   │   └── [Other report-specific folders]
│   ├── 05 - Snapshots/
│   └── 99 - Utilities/
├── Notebooks/
├── Pipelines/
└── Semantic Models/
```

---

## Folder Descriptions

### 01 - Raw Sources

**Purpose:** Ingest raw data from source system and save to Lakehouse

**Pattern:**
- One dataflow per source table
- Each table is normalized separately
- Tables saved to Lakehouse with original source system names
- ODBC connection to SQL Anywhere database

**Example:**
- Source table: `jdis_Part_Information`
- Dataflow name: `df_jdis_Part_Information_Raw`
- Lakehouse table: `jdis_Part_Information` (same as source)

**Other common raw tables:**
- `InMaster`
- `vhstock`
- `Fact_InTrans`
- `jdis_Part_Movement`
- `jdis_Part_Cost`
- And others as needed

### 02 - Analysis

**Purpose:** Troubleshooting and ad-hoc analysis

**Pattern:**
- Dataflows NOT saved to Lakehouse
- Used for investigating specific problems
- Temporary queries for validation

**Usage:**
- When debugging data issues
- When validating transformations
- When exploring new data sources

### 03 - Dimensions

**Purpose:** Build reusable dimension tables for all reports

**Pattern:**
- Dataflows read from Lakehouse raw tables
- Create standardized dimensions
- Saved back to Lakehouse with `dim_` prefix
- Designed for reuse across multiple reports

**Example:**
- Dataflow: `df_Dim_Location`
- Output: `dim_BranchLocation` (used in every report)

**Common Dimensions:**
- `dim_BranchLocation` - Used in ALL reports
- `dim_DateTable` - Used in ALL reports
- `dim_Parts` - Master parts dimension
- `dim_CustomerList` - Customer dimension
- Others as needed per report

**Important Notes:**
- Dimensions should be built to be reusable
- Avoid report-specific logic in shared dimensions
- Consider granularity carefully (composite keys may be needed)

### 04 - Fact

**Purpose:** Build fact tables for specific reports

**Organization:**
- Subfolder per report (e.g., "Inspection Report Queries")
- Dataflows read from Lakehouse raw tables and dimensions
- Saved to Lakehouse with `Fact_` prefix

**Example Structure:**
```
04 - Fact/
├── Inspection Report Queries/
│   ├── df_Fact_Inspection1
│   ├── df_Fact_Inspection2
│   └── df_Fact_Inspection3
└── Parts Adjustment Queries/
    └── df_Fact_PartsAdjustment
```

**Pattern:**
- Dataflow: `df_Fact_PartsAdjustment`
- Output: `Fact_PartsAdjustment`

### 05 - Snapshots

**Purpose:** Capture point-in-time snapshots of frequently changing data

**Current Snapshots:**
- Daily snapshot of `jdis_Part_Information` (master price list)
- Weekly snapshot of `jdis_Part_Information`

**Reason:**
- `jdis_Part_Information` table changes frequently
- No timestamp field for tracking changes
- Snapshots enable historical trend analysis
- Future use for pattern detection and price change analysis

**Status:** Infrastructure in place, not yet used in reports

### 99 - Utilities

**Purpose:** Helper dataflows and utilities

**Status:** Minimal use so far

**Intended Use:**
- Data quality checks
- Transformation utilities
- Automation helpers

---

## Data Flow Pattern

```
[SQL Anywhere DB]
       ↓ (ODBC)
[01 - Raw Sources] → Dataflows → [Lakehouse Raw Tables]
       ↓
[03 - Dimensions] → Dataflows → [Lakehouse Dimension Tables]
       ↓
[04 - Fact] → Dataflows → [Lakehouse Fact Tables]
       ↓
[Semantic Model] → Power BI Desktop → [Report]
       ↓
[Published to Department Workspace]
```

---

## Microsoft Fabric Workspaces

### Master Data Workspace
**Workspace:** `LH_Master_Data`
**Purpose:** Centralized data ingestion, transformation, and dimension/fact table creation
**Contains:** Lakehouse, Dataflows, Notebooks, Pipelines, Semantic Models

### Production Report Workspaces
**Reports published to department-specific workspaces:**

- **RP - Parts Reports** - Parts department daily reports
- **RP - Service Reports** - Service department daily reports
- **RP - Finacial Report** - Financial department daily reports

### Testing and Validation Workspaces
**For development and testing before production:**

- **RP - Sandbox** - General testing workspace
- **RP - Service Sandbox** - Service report testing

### Legacy Workspaces (Being Deprecated)
**Old Lakehouse structure - migrating away from these:**

- **LH - Finacial_Data_Prep** - Old financial Lakehouse (migrate to LH_Master_Data)
- **LH - Parts_Data_Prep** - Old parts Lakehouse (migrate to LH_Master_Data)
- **LH - Service_Data_Prep** - Old service Lakehouse (migrate to LH_Master_Data)

**Migration Strategy:**
- Move all reports to use centralized `LH_Master_Data` Lakehouse
- Benefits: Better refresh control, optimization, standardization, CU management
- Example: "Part Sales with Low Margin" report successfully migrated

---

## Key Architectural Principles

### 1. Separation of Concerns
- Raw data ingestion (01)
- Dimension building (03)
- Fact table creation (04)
- Each layer has clear responsibility

### 2. Reusability
- Dimensions built for cross-report use
- Avoid duplicating dimension logic
- Standardized naming enables discovery

### 3. CU Optimization (F4 Capacity)
- Minimize redundant refreshes
- Consolidate data ingestion
- Optimize query folding where possible
- Monitor capacity usage carefully

### 4. Maintainability
- Consistent naming conventions
- Clear folder organization
- One dataflow per logical unit
- Documentation for all components

### 5. Version Control
- Track changes to dataflows (when possible)
- Version semantic models
- Document breaking changes

---

## Source System Details

**Database Type:** SQL Anywhere
**Connection Method:** ODBC
**Key Tables:**
- `jdis_Part_Information` - Master parts/price list (changes frequently)
- `InMaster` - Inventory master
- `vhstock` - Vehicle stock
- `Fact_InTrans` - Transaction history
- Others as needed

**Data Characteristics:**
- Transactional data from dealership management system
- No built-in change tracking
- Updates happen throughout the day
- Historical data available

---

## Common Data Challenges

### 1. No Timestamp Fields
Many source tables lack updated_at or modified_at fields, making change tracking difficult.

**Solution:** Use snapshot tables (05 - Snapshots)

### 2. Composite Keys Required
Many entities require multi-column keys:
- PartNumber + Branch + Franchise
- AccountNumber + Branch

**Solution:** Always verify granularity in dimensions

### 3. Cartesian Products
INNER JOINs between source tables can create unexpected row multiplication.

**Solution:** Deduplicate and validate row counts

### 4. Price Changes
`jdis_Part_Information` changes constantly, affecting historical calculations.

**Solution:** Snapshot tables or include price/cost in fact tables

---

## CU Optimization Strategy (F4 Capacity)

### Priority Actions:
1. **Consolidate Refreshes** - Minimize separate dataflow executions
2. **Query Folding** - Ensure operations push down to source
3. **Incremental Refresh** - Where applicable for large fact tables
4. **Remove Redundancy** - Don't duplicate dimension logic
5. **Monitor Usage** - Track CU consumption patterns
6. **Schedule Wisely** - Stagger refreshes during off-peak hours

### Best Practices:
- Don't create dimension-specific dataflows for every report
- Reuse existing dimensions from Lakehouse
- Avoid complex M transformations that prevent folding
- Filter early, aggregate when needed
- Test query folding with diagnostics

---

## Next Steps for Architecture

### Future Enhancements:
- [ ] Standardize measure libraries (explore UDFs)
- [ ] Implement version control for dataflows
- [ ] Expand snapshot strategy
- [ ] Build utility dataflows (99)
- [ ] Create data quality monitoring
- [ ] Document relationships between dimensions and facts

### Migration Projects:
- Migrate old reports from legacy Lakehouse to this structure
- Standardize report branding and layout
- Optimize for CU consumption
- Identify and fix errors in old reports

---

**Last Updated:** January 2026
**Maintained By:** User + Claude
**Version:** 1.0
