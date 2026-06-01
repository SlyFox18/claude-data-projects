# Architecture — Non-JD Parts Order Tool

## Fabric Table Dependency Order

```
[ODBC: jdis_Part_Information] ──► df_NonJD_Parts_Ordering_Raw ──► NonJD_Parts_Ordering_Raw
[ODBC: InMaster]              ──► df_InMaster_Parts_Ordering_Raw  ──► InMaster_Raw
[CSV upload]                  ──► df_Param_ROP_Matrix             ──► param_ROP_Matrix
[CSV upload]                  ──► df_Param_FranchiseScope         ──► param_FranchiseScope
[SharePoint list]             ──────────────────────────────────► config_PartSettings (read directly by fact DFs)

NonJD_Parts_Ordering_Raw ──────────────────────────────────────────────────────────────────────► df_Fact_NonJD_SalesHistory ──► Fact_NonJD_SalesHistory
NonJD_Parts_Ordering_Raw + InMaster_Raw + param_ROP_Matrix + param_FranchiseScope + config_PartSettings ──► df_Fact_NonJD_Reorder ──► Fact_NonJD_Reorder
```

## Fabric Artifact Inventory

| Artifact | Type | Location in Fabric | Purpose |
|---|---|---|---|
| df_NonJD_Parts_Ordering_Raw | Dataflow Gen2 | LH_Master_Data → 01 - Raw Sources | Non-JD part master + 60-month history |
| df_InMaster_Parts_Ordering_Raw | Dataflow Gen2 | LH_Master_Data → 01 - Raw Sources | Stocking months, margin flag — named differently because df_InMaster_Raw already existed |
| df_Param_FranchiseScope | Dataflow Gen2 | LH_Master_Data → 03 - Dimensions | Franchise include/exclude list |
| df_Param_ROP_Matrix | Dataflow Gen2 | LH_Master_Data → 03 - Dimensions | 1,993-row ROP calculation parameter table |
| nb_Fact_NonJD_SalesHistory | Notebook (PySpark) | LH_Master_Data → Notebooks | Unpivoted 60-month sales history — Notebook because Power Query M cannot efficiently unpivot 120 cols × 200K rows |
| nb_Fact_NonJD_Reorder | Notebook (PySpark) | LH_Master_Data → Notebooks | Pre-calculated daily reorder recommendations — Notebook because per-row ROP matrix lookup is O(200K × 1,993) in M |
| config_PartSettings | SharePoint list | SharePoint site (Phase 1) | User-managed per-part overrides |

## Refresh Schedule

| Artifact | Pipeline | Frequency | Strategy | Actual Runtime |
|---|---|---|---|---|
| df_NonJD_Parts_Ordering_Raw | Pipeline_NonJD_Order_Tool — Phase 1 | Daily 7 AM | Full refresh | ~4m 41s |
| df_InMaster_Parts_Ordering_Raw | Pipeline_NonJD_Order_Tool — Phase 1 | Daily 7 AM | Full refresh | ~2m 21s (parallel) |
| df_Param_FranchiseScope | Manual | On demand | Full refresh | Only when exclusion list changes |
| df_Param_ROP_Matrix | Manual | On demand | Full refresh | Only when stocking rules change |
| nb_Fact_NonJD_Parts_Order | Pipeline_NonJD_Order_Tool — Phase 2 | Daily 7 AM | Full overwrite | ~10m 50s (includes Spark cold start); writes both Fact_NonJD_SalesHistory and Fact_NonJD_Reorder |
| **Total pipeline** | Pipeline_NonJD_Order_Tool | Daily 7 AM | — | **~15m 50s** (first confirmed run 2026-06-01) |

## Key Design Constraints

- **Do NOT modify `df_jdis_Part_Information_Raw`** — it already consumes significant CUs (3× daily refresh, 1M+ rows) and feeds many downstream reports. All new data needs are in purpose-built tables.
- **F4 Capacity** — add new dataflows to appropriate pipeline waves, targeting ≤5 concurrent per wave.

## config_PartSettings Storage

- **Phase 1 (current):** SharePoint list — works with standard Power Apps license, Dataflow Gen2 reads via SharePoint connector
- **Phase 2 (when Premium confirmed):** Migrate to Fabric Lakehouse table, update Power Apps connector and dataflow source. Architecture unchanged — data source swap only.

## SharePoint Resources

| Resource | Details |
|---|---|
| config_PartSettings list | https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite — list: config_PartSettings |

## ROP Calculation Architecture

The parameter matrix (`param_ROP_Matrix`) is entirely "Default" for Group, CommodityCode,
SRC, SLC, and Attachment. The lookup is based solely on:

1. **MonthCount** — number of months (out of 60) with any sales or demand activity. Capped at 19 (matrix max); 0 treated as 1.
2. **AvgMonthlyDemand** — average demand count across stocking months (from RequestsMonth columns)
3. **AvgMonthlySales** — average sales units across stocking months (from SalesMonth columns)

Output fields from matrix: Modifier, TrendingCap, WarehouseMin, StockingWeeks, SpikingModifier, SpikingWarehouseStockingMin

ROP formula:
- CalcROP = AvgMonthlyDemand × Modifier
- StockingTarget = MAX(WarehouseMin, EffectiveMin, ROUND_UP(CalcROP))
- RecommendedOrderQty = MAX(0, StockingTarget − QuantityOnHand − OnOrder)
- EstOrderValue = RecommendedOrderQty × Cost

## App Layers (built in Plans 2 and 3)

| Layer | Technology | Status | Reads From |
|---|---|---|---|
| Power Apps V1 | Canvas App | Plan 2 (not started) | Fact_NonJD_Reorder, Fact_NonJD_SalesHistory, config_PartSettings |
| Web App V2 | React + Azure Static Web App | Plan 3 (future) | Fabric SQL Analytics Endpoint (same Lakehouse tables) |
