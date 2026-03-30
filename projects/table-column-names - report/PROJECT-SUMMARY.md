# Table Column Names Search — Project Summary

## Overview
An internal developer tool for exploring the Lakehouse database schema. Allows developers to search for tables and columns, browse data types, view relationships between tables, and check table statistics. Not intended for business users.

**Status:** Production (developer utility)
**Workspace:** Developer workspace
**Refreshed:** Ad-hoc / manual

## Report Pages

| Page | Purpose |
|------|---------|
| Search & Explore | Search tables and columns by name or type |
| Table Details | Drillthrough — full column definition list for a selected table |
| Relationship Map | Visual relationship map between tables |

## Data Model

### Tables (all schema metadata, no business data)
| Table | Description |
|-------|-------------|
| Tables | All table names in the database |
| TableColumns | Column definitions: name, type, length, nullable, default |
| TableRelationships | Foreign key relationships |
| AllTableRelationships | Expanded relationship view |
| TableDescriptions | Table-level descriptions/documentation |
| TableStats | Row counts and size statistics |
| Views | Database view definitions |
| Indexes | Index definitions |
| Timestamp Columns | All datetime/timestamp columns |
| Unique Constraints | Unique key constraints |

## Notes
- This is a developer utility — no stakeholder Obsidian note is needed.
- Schema metadata reflects the state at last refresh. Tables/columns added after the last refresh will not appear.
- Refresh manually as needed when exploring a new area of the Lakehouse.
