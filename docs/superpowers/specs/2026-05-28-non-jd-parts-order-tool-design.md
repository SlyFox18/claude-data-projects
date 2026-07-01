# Non-JD Parts Order Tool — Design Spec

**Date:** 2026-05-28
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

John Deere parts ordering is handled by the JD PRISM system, which uses sales history and configurable parameters to recommend reorder quantities. No equivalent tool exists for non-John Deere parts. Currently, non-JD parts ordering is a fully manual process using spreadsheets and manual calculations. This project replicates the core capabilities of the JD PRISM ordering tool for non-JD parts.

---

## 2. Scope

### In Scope
- Non-JD parts only — Franchise ≠ "D"; also exclude "ZP" (not a real orderable part) and others TBD
- 2 users: parts manager and corp parts manager
- Output: view on screen + export to Excel/CSV per vendor
- No integration with vendor ordering platforms — orders are placed manually after the tool generates a recommendation list
- **Power Apps V1** — production tool (built first)
- **Web App V2** — learning project and potential future replacement (built after V1 ships, same Fabric backend)

### Out of Scope
- John Deere parts (handled by existing JD PRISM)
- ERP or vendor system integration
- Multi-user access control beyond the 2 named users
- Mobile-first design (desktop use assumed)
- User editing of the base ROP parameter matrix from within the app (admin-managed only)

---

## 3. Reference Material

- **Example files:** `projects/part order tool - app/example pictures/` — screenshots of JD PRISM system
- **Parameter table:** `projects/part order tool - app/example excel sheet/Version 5 ROP-CSV.csv` — 1,993-row ROP calculation matrix
- **Source queries:** `.claude/queries/raw-tables/jdis_Part_Information.pq`, `.claude/queries/raw-tables/InMaster.pq`

---

## 4. Platform Decision

| Version | Platform | Purpose | Timeline |
|---|---|---|---|
| V1 | Power Apps Canvas App | Production tool for stakeholder | Build first |
| V2 | React web app (Azure Static Web App) | Learning project, richer UX | After V1 ships |

Both versions share the same Fabric backend. No data work is duplicated.

**Why Power Apps first:** Stakeholder's preferred starting point, Microsoft ecosystem fits the environment, no hosting infrastructure needed, native Excel export, and the heavy calculation work lives in Fabric (not in the app).

**Why also build a web app:** Brian needs to expand Power Apps skills (business is moving this direction) and wants to develop web app/UX skills. A web app provides better UI control and could serve as a lower-cost alternative for future projects.

---

## 5. Fabric Data Layer

### Design Constraint
**Do not modify the existing `jdis_Part_Information` raw table.** It already consumes significant CUs across 3 daily refreshes and feeds many downstream reports. All new data needs are served by purpose-built tables.

### 5.1 New Raw Tables

#### `df_NonJD_Parts_Ordering_Raw`
- **Source:** Same ODBC connection (`dsn=EquipRDB64`) as jdis_Part_Information
- **Filter at source:** Non-JD franchises only (reduces row count, reduces CU)
- **Key columns pulled (not in existing jdis table):**
  - `pi_sales_history_01` through `pi_sales_history_60` — 60 months of monthly sales quantity
  - `pi_sales_request_01` through `pi_sales_request_60` — 60 months of demand/request counts
  - `pi_sales_activity_01` through `pi_sales_activity_60` — 60 months of sales activity
  - `pi_Minimum_Qty`, `pi_Maximum_Qty` — source min/max stock levels
  - `pi_Reorder_Code`, `pi_Activity_Code`
  - `pi_suggested_order_qty` — system-calculated suggested order (⚠️ investigate — may already do ROP math)
  - `pi_current_12_Lost_Sales_Qty`, `pi_current_12_Lost_Sales_Value`
  - Core fields already in jdis: Branch, PartNumber, Franchise, SLC, Source, OnHand, OnOrder, Cost, SellPrice1, Bin, VendorCode, SuperTo, SuperFrom
- **Refresh:** Once daily (4 AM pipeline, after raw phase) — full refresh
- **CU impact:** Low — non-JD subset only, once per day

#### `df_InMaster_Raw`
- **Source:** `InMaster` table via ODBC (`dsn=EquipRDB64`)
- **Key columns:**
  - `PROD_GROUP` — stocking group classification (maps to "Group" in ROP parameter table — e.g., R, TRACTOR). ⚠️ Investigate whether this is populated for non-JD parts
  - `STK_IN_MTH` — stocking months (directly relevant to ROP calculation)
  - `SALES_CLASS`, `CATEGORY` — part classification
  - `MINIMUM_QTY`, `MAXIMUM_QTY` — cross-reference with jdis values
  - `REORDER_CODE`, `ACTIVITY_CODE`
  - `user_field_3` — margin flag ("Low" = low margin, used in Part Sales Low Margin report; other values TBD — ⚠️ run `SELECT DISTINCT user_field_3` to discover full value set)
  - `ModifiedDate` — enables incremental refresh
- **Refresh:** Incremental via `ModifiedDate` — very low CU
- **Join key:** Branch + PartNumber

### 5.2 Admin-Managed Config Tables

#### `param_ROP_Matrix`
- Loaded from `Version 5 ROP-CSV.csv` via Dataflow Gen2
- 1,993-row lookup matrix mapping: Group + Commodity + SRC + SLC + Attachment + Price range + Month Count + Demand range + Sales range → Modifier, TrendingCap, WarehouseMin, StockingWeeks, SpikingModifier, SpikingWarehouseStockingMin
- Stored in Lakehouse as a Delta table
- **Managed by:** Admin (Brian) — updated only when stocking rules change
- **Not exposed in app UI**

#### `param_FranchiseScope`
- Simple table defining which franchises are included/excluded for the ordering tool
- Columns: Franchise, IsIncluded, ExclusionReason
- Known exclusions: "D" (John Deere — handled by PRISM), "ZP" (not an orderable part), others TBD
- Managed by admin; app filters against this table

### 5.3 User-Managed Config Table

#### `config_PartSettings`
Per-part overrides set by the parts manager from within the Power Apps interface.

| Column | Description |
|---|---|
| PartNumber | Part identifier |
| Branch | Branch code |
| GroupOverride | Override for PROD_GROUP if source value is missing/wrong |
| MinOverride | Override for minimum stock level |
| EOQ | Economic Order Quantity |
| ForceNonSpiking | Flag to suppress spiking modifier |
| PreApprovedOrderRule | "Use normal rules" / "Force 1 time to proposed" |
| Masking | Mask/phase-out flag |
| MaskingExpiration | Date when masking expires |

**Storage strategy (two-phase):**
- **Phase 1 (initial):** SharePoint list — Power Apps reads/writes with standard license, Dataflow Gen2 reads via SharePoint connector. No Premium license required.
- **Phase 2 (when Premium confirmed):** Migrate to Fabric Lakehouse table, update Power Apps connector and dataflow source. Architecture unchanged — data source swap only.

### 5.4 Computed Fact Tables

#### `Fact_NonJD_Reorder`
Pre-calculated daily. One row per part per branch for all in-scope non-JD parts.

Joins: `df_NonJD_Parts_Ordering_Raw` + `df_InMaster_Raw` + `config_PartSettings` + `param_ROP_Matrix` + `param_FranchiseScope`

Key output columns:
- `MonthCount` — number of months with stocking history
- `AvgMonthlyDemand`, `AvgMonthlySales`
- `CalcROP` — calculated reorder point from parameter matrix
- `StockingTarget` — recommended stock level
- `RecommendedOrderQty` — max(0, StockingTarget - OnHand - OnOrder)
- `EstOrderValue` — RecommendedOrderQty × Cost
- `SystemSuggestedQty` — pi_suggested_order_qty for comparison
- `LowMarginFlag` — from user_field_3

Refresh: After raw tables complete in daily pipeline.

#### `Fact_NonJD_SalesHistory`
Unpivots the 60-month wide columns into row-per-month format.

Columns: Branch, PartNumber, MonthOffset (1=current, 60=oldest), SalesQty, DemandCount, SalesActivity

Used exclusively by the Part Information screen history grid. Refreshes after `df_NonJD_Parts_Ordering_Raw`.

---

## 6. Power Apps V1 — Canvas App

### Screen 1: Home
- Navigation hub with 4 tiles (one per tool section)
- App title/branding
- Last Fabric refresh timestamp
- Minimal design — fast to load

### Screen 2: Recommended Reorder
- **Data source:** `Fact_NonJD_Reorder` (via Power Apps connector)
- **Filters:** Franchise, Branch, Group, Order Code, Low Margin flag
- **Sortable table columns:** Part#, Description, Franchise, Vendor, On Hand, Stocking Target, ROP, Recommended Qty, Est Order Value, Low Margin flag
- **Export:** Native Power Apps Excel export
- **Drill-through:** Click any row → navigate to Screen 4 (Part Information) for that part

### Screen 3: One Time Order (4-step wizard)
Replicates the JD PRISM "Special Term / One-time Order" workflow for non-JD parts.

**Note:** This tool calculates at runtime based on user-selected months and loading factor — it does NOT use the pre-computed `Fact_NonJD_Reorder`. It reads from `Fact_NonJD_SalesHistory` (the unpivoted 60-month history) and applies the formula dynamically in Power Apps.

- **Step 1 — Criteria:** Name the order criteria, select Order Code, Include Phase-In toggle
- **Step 2 — Parts Filter:** Select franchises to include, filter by SLC/Group/Category; define inclusion/exclusion lists
- **Step 3 — Month Selection:** Calendar grid showing 3 years of monthly history; user checks which months to include (matching JD system UX). Loading Factor input (default 1.0). Use Trending toggle.
- **Step 4 — Generate:** Preview the proposed order list (Part#, Description, Anticipated Sales, On Hand, Recommended Qty, Est Value). Export to Excel button.
- **Formula:** Sum of sales in checked months × Loading Factor = Anticipated Sales → RecommendedQty = max(0, AnticipatedSales - OnHand - OnOrder)
- **Performance note:** Power Apps querying `Fact_NonJD_SalesHistory` with runtime filters (franchise + branch + selected month offsets) across potentially thousands of parts may be slow. Delegation limits and data volume should be tested early in the Power Apps build. If performance is a concern, the Web App V2 will handle this more gracefully.

### Screen 4: Part Information
- **Search:** Part number lookup (type-ahead or exact match)
- **Detail tab:** All part attributes — Description, Franchise, Vendor, Source, SLC, Category, Bin, Cost, Sell Price, On Hand, On Order, Min, Max, Reorder Code, System Suggested Qty, Low Margin flag, Supersession (Sub To / Sub From), Date Created, Date Last Requested
- **History tab:** Month-by-month grid — 60 months of Sales Qty and Demand Count (matching JD History tab layout)
- **Settings tab:** Edit per-part overrides → writes to `config_PartSettings`. Fields: Group, Min Override, EOQ, Force Non-Spiking, Pre-Approved Order Rule, Masking

---

## 7. Web App V2 (Future)

Built after Power Apps V1 ships. Goals are dual: (1) richer UX/UI closer to the JD PRISM experience, (2) learning project for React and web development.

- **Stack:** React (or similar), Azure Static Web App (free tier hosting)
- **Data:** Fabric SQL Analytics Endpoint (standard T-SQL queries against the same Lakehouse tables)
- **Auth:** Microsoft Entra (Azure AD) SSO — same users, same access
- **Scope:** Same 4 sections as Power Apps V1
- **No new Fabric work required** — backend is already in place

Could serve as a lower-cost alternative to Power Apps for similar projects across the business if the pattern proves out.

---

## 8. Key Open Questions (Resolve in Early Implementation)

| # | Question | Why It Matters |
|---|---|---|
| 1 | What does `pi_suggested_order_qty` actually calculate? | May eliminate need to rebuild ROP formula from scratch |
| 2 | Is `InMaster.PROD_GROUP` populated for non-JD parts? | May eliminate need for manual group assignment in config_PartSettings |
| 3 | What are all distinct values of `InMaster.user_field_3`? | Defines how to use/display the margin flag in the app |
| 4 | Full franchise exclusion list (beyond "D" and "ZP") | Required before data filter can be built |
| 5 | Power Apps Premium license status for 2 users | Determines Phase 1 vs Phase 2 for config_PartSettings storage |
| 6 | Are the 60 history columns (pi_sales_history_01–60) month-relative or calendar-fixed? | Affects how MonthOffset maps to a calendar date in the history grid |

---

## 9. Pipeline Integration

New dataflows added to the existing `Pipeline_Master_Orchestrator`:

| Phase | Dataflow | Dependencies | Est. Time |
|---|---|---|---|
| Phase 1 (Raw) | df_NonJD_Parts_Ordering_Raw | None | TBD |
| Phase 1 (Raw) | df_InMaster_Raw (incremental) | None | Low |
| Phase 3 (Dims) | param_FranchiseScope | None (admin-loaded) | Negligible |
| Phase 4 (Facts) | Fact_NonJD_Reorder | All raw + config | TBD |
| Phase 4 (Facts) | Fact_NonJD_SalesHistory | df_NonJD_Parts_Ordering_Raw | TBD |

The semantic model for Power Apps reads from these fact tables. Web App V2 queries via SQL Analytics Endpoint directly.

---

## 10. Naming Convention

Following existing project conventions:

| Artifact | Name |
|---|---|
| Project folder | `projects/non-jd-parts-order-tool/` |
| Power Apps app | Non-JD Parts Order Tool |
| Raw dataflow 1 | df_NonJD_Parts_Ordering_Raw |
| Raw dataflow 2 | df_InMaster_Raw |
| Config table | config_PartSettings |
| Franchise scope | param_FranchiseScope |
| ROP matrix | param_ROP_Matrix |
| Reorder fact | Fact_NonJD_Reorder |
| History fact | Fact_NonJD_SalesHistory |
