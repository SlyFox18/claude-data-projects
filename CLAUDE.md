# Data Projects - Claude Code Context

## Project Overview

This repository contains Power BI reports built on Microsoft Fabric. Each project folder in `projects/` represents a separate Power BI report with its own semantic model, queries, and documentation.

**Owner:** Brian Fox
**Lakehouse:** `LH_Master_Data` in Fabric workspace
**ODBC Connection:** `dsn=EquipRDB64` (source system)

## Repository Structure

```
data-projects/
├── .claude/
│   ├── queries/              # Shared query library (gold-standard reference)
│   │   ├── raw-tables/       # Raw data ingestion queries (.pq files)
│   │   ├── dimensions/       # Dimension building queries (.pq files)
│   │   ├── facts/            # Fact table metadata (FACT-TABLES-SUMMARY.md)
│   │   └── README.md         # Query library conventions
│   ├── plans/                # Implementation plans from plan mode
│   └── projects/.../memory/  # Auto-memory files
├── projects/
│   ├── customer anatomy - report/      # Customer analysis (flagship report)
│   ├── inspections - report/           # Service inspections (well-documented)
│   ├── inventory analysis - report/    # Inventory analysis (10M+ rows)
│   ├── first pass fill - report/       # Inventory KPI
│   ├── unique parts customers - report/ # Special customer tracking
│   ├── parts adjustments - report/     # Inventory adjustments
│   ├── bin location - report/          # Part bin locations
│   ├── combine vault sales - reports/  # Branch 12 transfers
│   └── ... (20+ total projects)
└── CLAUDE.md                 # This file
```

## Fabric Architecture

### Data Flow
```
Source System (ODBC) → Raw Tables (Lakehouse) → Dimensions → Fact Tables → Semantic Models → Reports
```

### Dataflow Organization (in LH_Master_Data)
- `01 - Raw Sources` - Raw data ingestion from ODBC
- `03 - Dimensions` - Dimension tables and lookup tables
- `04 - Fact` - Fact table transformations

### Key Tables

**Dimensions (shared across reports):**
- `dim_CustomerList` - Primary customer dimension (has calculated columns: CSM, Route Day, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer)
- `dim_BranchLocation` - Branch/location dimension (used by 14+ projects)
- `dim_DateTable` - Universal date dimension (used by 14+ projects)
- `dim_Parts` - Parts dimension (used by 9+ projects)
- `dim_EngagedAcres` - Engagement data from external CSV
- `lookup_UniqueCustomers_Invoice` - 11 unique customer groups (no relationship, uses LOOKUPVALUE)

**Common Raw Tables:**
- `Invoice` - Sales invoices (columns: CustomerNumber, CustomerOrderNumber, InvoiceDate, InvoiceNumber, Branch, ModuleType)
- `InTrans_Incremental` - Parts transactions (10M+ rows, incremental refresh)
- `ArMaster_Customer` - Customer master data (has TradeType column)
- `jdis_Part_Information` - Parts master data (1M+ rows)

## Conventions

### Power Query
- All queries have comprehensive header comments (purpose, grain, source, business use)
- Lakehouse column names use **PascalCase** (normalized from raw source)
- Delta tables reject column names with spaces - always rename in dataflows
- Incremental refresh uses `RangeStart`/`RangeEnd` datetime parameters

### DAX Patterns
- **Dimension flagging via lookup tables:** Use `LOOKUPVALUE` on calculated columns (no model relationship needed). Used for: EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer
- **HTML visuals:** Inline CSS for KPI cards and badges (purple #818cf8 for Unique, gold #fbbf24 for Key Customer)
- **Multi-level fact tables:** Level 1 (aggregated), Level 2 (invoice detail), Level 3 (line items)

### Semantic Model Files (.tmdl)
- Located in `reports/current/{ReportName}.SemanticModel/definition/`
- Tables in `tables/` subfolder
- Measures typically in `_Measures.tmdl`
- Cultures in `cultures/` subfolder

### CSV Imports to Fabric
1. Upload CSV to Lakehouse Files section
2. Create Dataflow Gen2 to read from Files, transform, and output to Lakehouse table
3. Always rename columns to remove spaces in the dataflow (Delta compatibility)

## Related Repositories & Knowledge Bases

### Fabric Workspace (Production)
**Path:** `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`
- Fabric Git Integration mirror - the actual deployed artifacts
- 220+ items across 9 workspaces (LH_Master_Data, RP - Parts Reports, RP - Service Reports, etc.)
- 83 dataflows in LH_Master_Data, 531 .tmdl files, 122 mashup.pq files
- Contains the production Power Query (mashup.pq) for every dataflow
- Use this to verify what's actually deployed vs what's in development here

### Obsidian Knowledge Base
**Path:** `C:\Users\bfox\Documents\Obsidian Vault`
- **Awesome Vault** - 131 files: query library with versioned dimensions, facts, raw tables
- **Inspections Report Knowledge Base** - 20 files: project-level architecture, pipeline, data model docs
- When documenting completed features, update Obsidian vault too if asked

## Working With This Repo

### Before modifying any report:
1. Read the project's documentation (README.md, ARCHITECTURE.md, etc.) if it exists
2. Check `.claude/queries/` for existing query patterns
3. Check `FACT-TABLES-SUMMARY.md` for table metadata and relationships

### When creating new queries:
1. Follow the header comment convention from existing `.pq` files
2. Save a copy to `.claude/queries/` in the appropriate subfolder
3. Use PascalCase for Lakehouse column names

### When modifying DAX:
1. Read the relevant `.tmdl` file first
2. For cross-table flags, prefer LOOKUPVALUE on calculated columns over model relationships
3. Test with existing slicers and filters

### Documentation expectations:
- Update project-level docs when making significant changes
- Keep `.claude/queries/` files in sync with actual dataflow queries
- Update FACT-TABLES-SUMMARY.md when adding/modifying fact tables
