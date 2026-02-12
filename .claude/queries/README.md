# Power Query (M) Code Repository

This directory stores the Power Query (M) code for dataflows and semantic model queries.

## Purpose

- **Version Control** - Track changes to queries over time
- **Reusability** - Reference patterns for new reports
- **Documentation** - Show exact transformation logic
- **Context for Claude** - Provide quick reference without needing explanations
- **Backup** - Preserve working queries

## Directory Structure

```
queries/
├── raw-tables/          # Raw data ingestion queries (01 - Raw Sources)
│   ├── jdis_Part_Information.pq
│   ├── InMaster.pq
│   ├── vhstock.pq
│   └── ...
│
├── dimensions/          # Dimension building queries (03 - Dimensions)
│   ├── dim_BranchLocation.pq
│   ├── dim_DateTable.pq
│   ├── dim_Parts.pq
│   └── ...
│
└── facts/               # Fact table queries (04 - Fact)
    ├── parts-sales/
    │   └── Fact_PartsSales.pq
    ├── inspection/
    │   └── Fact_Inspection.pq
    └── ...
```

## File Naming Convention

**Pattern:** `[TableName].pq`

**Examples:**
- `jdis_Part_Information.pq` - Raw table query
- `dim_BranchLocation.pq` - Dimension query
- `Fact_PartsAdjustment.pq` - Fact table query

## How to Export .pq Files

### From Power BI Desktop:
1. Open Power Query Editor (Transform Data)
2. Right-click query → Advanced Editor
3. Copy M code
4. Save to appropriate folder

### From Dataflows:
1. Open dataflow in edit mode
2. Select query
3. Copy M code from formula bar or Advanced Editor
4. Save to appropriate folder

## What to Store

### Priority 1: Common/Reusable Queries
- ✅ All raw table ingestion queries
- ✅ All common dimensions (dim_BranchLocation, dim_DateTable, etc.)
- ✅ Frequently referenced fact patterns

### Priority 2: Project-Specific Queries
- Consider storing complex transformations
- Store queries that will be referenced across reports
- Store validated "gold standard" implementations

### Don't Need to Store:
- Simple SELECT * queries with no transformation
- Highly report-specific one-off queries
- Queries still in active development/testing

## Metadata to Include

At the top of each .pq file, include a comment block:

```powerquery
/*
Query: [Query Name]
Source: [Dataflow name or Semantic Model]
Purpose: [Brief description]
Created: [Date]
Last Updated: [Date]
Dependencies: [List of source tables/queries]
Output: [Table name in Lakehouse or Model]
Notes: [Any important information]
*/

let
    // Query code here
in
    FinalStep
```

## Usage

### For Claude:
- Read these files to understand transformations
- Reference patterns when building new queries
- Compare working queries when troubleshooting

### For User (Brian):
- Copy-paste starting points for new queries
- Compare versions when debugging
- Document complex transformation logic

## Maintenance

- Update files when queries change significantly
- Add new files as new tables/dimensions are created
- Remove files if queries are deprecated (move to archive)
- Keep metadata comments up to date

---

**Last Updated:** January 2026
**Maintained By:** Brian Fox
