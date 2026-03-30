# Bin Location Report — Claude Context

## Report Overview
- **Business purpose:** Parts bin location lookup tool — lets parts staff find where a specific part is physically located in a branch's bin system, including bin qty, bulk bin, on-hand qty, pricing, and inventory cost.
- **Primary users:** Parts staff, branch managers (daily operational lookup)
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 3 — Weekly (Monday)
- **Status:** Production

## Semantic Model

### Primary Table
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `jdis_Part_Information` | One row per part-branch | Branch, PartNumber, Bin, BulkBin, BinQty, QuantityOnHand, PackageQty, InventoryCost, Cost, SellPrice1, ListPrice, DealerGroupCode, Franchise | Core bin/location data. Raw table from Lakehouse (`dbo.jdis_Part_Information` or similar) — note the `jdis_` prefix indicates a JDIS (John Deere Information System) source. Covers 1M+ parts. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_Parts` | Shared Lakehouse dimension | `PartNumber` → `PartNumber` |
| `dim_BranchLocation` | Shared Lakehouse dimension | `Branch` → `BranchID` |
| `dim_Franchise` | Dedicated dimension | `Franchise` → franchise lookup |
| `dim_DealerGroupCode` | Dedicated dimension | `DealerGroupCode` → dealer group lookup |
| `MeasuresTable` | Local measures table | Holds report measures |
| `Data Refresh` | Calculated table | Refresh timestamp display |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| a50364535b314353c75c | Bin Location report | Single-page lookup with search/filter by part number, branch, franchise | Visible |

## Data Flow
```
EquipRDB (ODBC) / JDIS Source
  └─ jdis_Part_Information (parts inventory + bin assignments, 1M+ parts)
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ jdis_Part_Information table
  └─ dim_Parts, dim_BranchLocation (shared dims)
  └─ dim_Franchise, dim_DealerGroupCode (dedicated dims)
                │
                ▼
            Bin Location Report
```

## Known Issues & Gotchas

### Weekly Refresh Cadence
This report refreshes weekly (Monday — Tier 3) rather than daily. Bin location data is relatively stable but will be up to 7 days stale during the week. If a part was moved to a new bin Monday–Sunday, it won't reflect until the next Monday refresh.

### `jdis_` Prefix — JDIS Source
The `jdis_Part_Information` table comes from the JDIS (John Deere Information System) data feed. This is a different source from the standard ODBC `dsn=EquipRDB64` connection. If this table ever shows stale data, check the JDIS ingestion pipeline, not the standard ODBC pipeline.

### Large Table (~1M+ Parts)
`jdis_Part_Information` contains 1M+ parts across all branches and franchises. Filters (branch, franchise, dealer group) should be applied early when querying this table. Cross-join or unfiltered visual behavior may be slow.

### `dim_Parts` Relationship
`dim_Parts` is also a large table (50K+ parts from the JDIS catalog). The relationship between `dim_Parts` and `jdis_Part_Information` via `PartNumber` enables filtering by part attributes available in the shared dimension.

## Refresh Pipeline Position
- **Phase:** Tier 3 — Weekly Monday 5 AM
- **Dependencies:** `jdis_Part_Information` data ingestion; `dim_Parts`, `dim_BranchLocation` (shared dims, Phase 3)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Bin Location.md`
