# Table Column Names Search — Claude Context

## Report Overview
- **Business purpose:** Internal developer/admin tool for exploring the Lakehouse database schema — search tables, browse columns with data types, view relationships, indexes, views, and table statistics. NOT a business-facing report.
- **Primary users:** Developers, data engineers (Brian / Claude) working in the Lakehouse
- **Workspace:** Unknown (likely RP - Sandbox or developer workspace)
- **Refresh tier:** Unknown — not part of the standard pipeline
- **Status:** Production (developer utility)

## Semantic Model

### Tables
| Table | Purpose |
|-------|---------|
| `Tables` | All table names in the Lakehouse/database |
| `TableColumns` | Column metadata: table_name, column_name, data_type, column_length, decimal_scale, is_nullable, default_value |
| `TableRelationships` | Foreign key / referential relationships between tables |
| `AllTableRelationships` | Expanded/denormalized relationship view |
| `TableDescriptions` | Table-level documentation/descriptions |
| `TableStats` | Row counts, size statistics per table |
| `Views` | Database views defined in the Lakehouse |
| `Indexes` | Index definitions on tables |
| `Timestamp Columns` | Columns with datetime/timestamp data types (for identifying date fields) |
| `Unique Constraints` | Unique key constraints |

### Dimensions / Reference
No shared dimensions — this is a standalone schema exploration tool.

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Search & Explore | Main search interface — find tables/columns by name or type | Visible |
| 67b25760e0ca120bb527 | Table Details | Drillthrough — full column list for a selected table | Hidden (drillthrough) |
| 6a9ecbdf9951094d94ea | Relationship Map | Visual map of table relationships | Hidden in view mode |

## Data Flow
```
LH_Master_Data (Lakehouse)
  └─ Information schema / system catalog tables
       (table names, columns, types, relationships, statistics)
                │
                ▼
            Table Column Names Search Report
```

## Known Issues & Gotchas

### Developer Tool — Not Business Facing
This report is for internal use. It queries the Lakehouse information schema to help developers understand the data model. It should not appear in the production report workspace or be shared with end users.

### Schema Drift
The schema metadata in this report reflects the state at the last refresh. If tables are added, dropped, or columns renamed, the report will be stale until refreshed. Use this as a reference, not as a definitive real-time schema.

## Refresh Pipeline Position
- Not in the standard pipeline — refresh manually or on an ad-hoc schedule
- No dependencies on business data tables

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: N/A (developer tool — no stakeholder note needed)
