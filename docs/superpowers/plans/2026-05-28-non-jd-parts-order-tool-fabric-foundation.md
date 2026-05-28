# Non-JD Parts Order Tool — Plan 1: Fabric Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Fabric data layer — raw tables, parameter/config tables, and pre-computed fact tables — that both the Power Apps and Web App front-ends will read from.

**Architecture:** Two new purpose-built ODBC dataflows pull from the source system without modifying the existing `jdis_Part_Information` pipeline. Admin-managed CSV tables provide the ROP calculation matrix and franchise scope. A SharePoint list stores user-managed per-part overrides (Phase 1 storage; Lakehouse table in Phase 2 when Power Apps Premium is confirmed). Two fact tables join all inputs daily to produce a reorder recommendation list and an unpivoted 60-month sales history.

**Tech Stack:** Microsoft Fabric Dataflow Gen2, Power Query M, SQL Anywhere ODBC (`dsn=EquipRDB64`), SharePoint Online, Fabric Lakehouse Delta tables, Fabric Pipeline orchestration

**This is Plan 1 of 2:**
- **Plan 1 (this plan):** Fabric Foundation — all data work
- **Plan 2 (write after Plan 1 ships):** Power Apps V1 — 4-screen Canvas App

**Design spec:** `docs/superpowers/specs/2026-05-28-non-jd-parts-order-tool-design.md`

---

## File Map

**Files to create in `data-projects` (query library — track in git):**

| File | Purpose |
|---|---|
| `projects/part order tool - app/README.md` | Project overview and status |
| `projects/part order tool - app/ARCHITECTURE.md` | Fabric table relationships and refresh order |
| `projects/part order tool - app/DATA-INVESTIGATION.md` | Results from Task 1 discovery queries (fill in as you go) |
| `.claude/queries/raw-tables/NonJD_Parts_Ordering_Raw.pq` | ODBC query for non-JD parts extended data |
| `.claude/queries/raw-tables/InMaster_Raw.pq` | ODBC incremental query for InMaster |
| `.claude/queries/facts/NonJD_SalesHistory.pq` | Unpivot fact — 60-month history |
| `.claude/queries/facts/NonJD_Reorder.pq` | Calculation fact — reorder recommendations |

**Artifacts created in Fabric (not git-tracked — document in ARCHITECTURE.md):**

| Artifact | Location in Fabric |
|---|---|
| `df_NonJD_Parts_Ordering_Raw` (Dataflow Gen2) | LH_Master_Data → 01 - Raw Sources |
| `df_InMaster_Raw` (Dataflow Gen2) | LH_Master_Data → 01 - Raw Sources |
| `df_Param_FranchiseScope` (Dataflow Gen2) | LH_Master_Data → 03 - Dimensions |
| `df_Param_ROP_Matrix` (Dataflow Gen2) | LH_Master_Data → 03 - Dimensions |
| `df_Fact_NonJD_SalesHistory` (Dataflow Gen2) | LH_Master_Data → 04 - Fact |
| `df_Fact_NonJD_Reorder` (Dataflow Gen2) | LH_Master_Data → 04 - Fact |
| `config_PartSettings` (SharePoint list) | Existing SharePoint site |
| Lakehouse tables | LH_Master_Data (one per dataflow above) |

---

## Task 1: Discovery Queries

> **⚠️ CRITICAL — complete this task before building anything else.** The results determine whether Tasks 6–8 are simple or complex. Document all findings in `DATA-INVESTIGATION.md`.

**Files:**
- Create: `projects/part order tool - app/DATA-INVESTIGATION.md`

Run each query below using **Power BI Desktop → Get Data → ODBC → `dsn=EquipRDB64` → Advanced Options → paste native SQL query**. Record results in the investigation doc.

---

- [ ] **Step 1.1 — Discover all distinct values of `user_field_3`**

```sql
SELECT 
    user_field_3,
    COUNT(*) AS PartCount
FROM InMaster
WHERE user_field_3 IS NOT NULL 
  AND TRIM(user_field_3) != ''
GROUP BY user_field_3
ORDER BY PartCount DESC
```

Expected: A short list. "Low" is the known value for low-margin parts. Document every value and look up what it means in the source system.

---

- [ ] **Step 1.2 — Investigate `pi_suggested_order_qty` for non-JD parts**

```sql
SELECT TOP 50
    pi_Branch AS Branch,
    pi_Franchise AS Franchise,
    pi_Part_No AS PartNumber,
    pi_Description AS Description,
    pi_On_Hand_Qty AS OnHand,
    pi_Minimum_Qty AS MinQty,
    pi_Maximum_Qty AS MaxQty,
    pi_suggested_order_qty AS SystemSuggestedQty,
    pi_current_12_mo_sales AS Last12MoSales,
    pi_current_12_mo_requests AS Last12MoRequests,
    pi_Reorder_Code AS ReorderCode
FROM jdis_Part_Information
WHERE pi_Franchise NOT IN ('D', 'DA', 'ZP')
  AND pi_suggested_order_qty > 0
  AND pi_On_Hand_Qty < pi_suggested_order_qty
ORDER BY pi_suggested_order_qty DESC
```

**Decision gate:** Compare `SystemSuggestedQty` against what you'd expect given `OnHand`, `MinQty`, and sales history. If the source system is already calculating a sensible reorder quantity:
- **If yes → `SystemSuggestedQty` can be used directly.** Tasks 7 and 8 (fact tables) become much simpler — no need to implement the ROP matrix lookup from scratch.
- **If no / unclear → full ROP calculation must be built** using `param_ROP_Matrix`. Document which path you're taking.

---

- [ ] **Step 1.3 — Check whether `InMaster.PROD_GROUP` is populated for non-JD parts**

```sql
SELECT 
    FRANCHISE,
    PROD_GROUP,
    COUNT(*) AS PartCount
FROM InMaster
WHERE FRANCHISE NOT IN ('D', 'DA', 'ZP')
  AND PROD_GROUP IS NOT NULL
  AND TRIM(PROD_GROUP) != ''
GROUP BY FRANCHISE, PROD_GROUP
ORDER BY FRANCHISE, PartCount DESC
```

**Decision gate:**
- **If PROD_GROUP is populated for most non-JD parts → use it as the Group field** for the ROP matrix lookup. The `config_PartSettings.GroupOverride` column in the SharePoint list becomes a true override (only needed when PROD_GROUP is wrong/missing), not the primary input.
- **If PROD_GROUP is mostly null → users must assign groups manually** via `config_PartSettings`. This makes Group assignment a critical app feature.

---

- [ ] **Step 1.4 — Confirm the franchise exclusion list**

```sql
SELECT DISTINCT 
    pi_Franchise AS Franchise,
    COUNT(*) AS PartCount
FROM jdis_Part_Information
GROUP BY pi_Franchise
ORDER BY PartCount DESC
```

Cross-reference with the known dim_Franchise table. Mark each franchise as Include or Exclude (Exclude = "D", "ZP", and any others identified here). This list becomes the `param_FranchiseScope` table.

---

- [ ] **Step 1.5 — Verify the 60-month history column structure**

```sql
SELECT TOP 5
    pi_Branch,
    pi_Part_No,
    pi_current_mo_sales AS SalesMonth01,
    pi_sales_history_02 AS SalesMonth02,
    pi_sales_history_03 AS SalesMonth03,
    pi_current_mo_requests AS RequestsMonth01,
    pi_sales_request_02 AS RequestsMonth02,
    pi_sales_request_03 AS RequestsMonth03
FROM jdis_Part_Information
WHERE pi_Franchise NOT IN ('D', 'DA', 'ZP')
  AND pi_current_12_mo_sales > 0
ORDER BY pi_current_12_mo_sales DESC
```

Confirm: is `pi_current_mo_sales` the most recent month (offset 1) with `pi_sales_history_02` being one month prior, and so on? Verify the direction of the time series. Document in `DATA-INVESTIGATION.md`.

---

- [ ] **Step 1.6 — Create `DATA-INVESTIGATION.md`**

Create `projects/part order tool - app/DATA-INVESTIGATION.md` and fill in findings from each query above. Template:

```markdown
# Data Investigation Results
Date: 2026-05-28

## user_field_3 Values
| Value | Count | Meaning |
|---|---|---|
| Low | X | Low margin part (confirmed — used in Part Sales Low Margin report) |
| [others] | X | [investigate] |

## pi_suggested_order_qty Assessment
Decision: [ ] Use system value directly  [ ] Build ROP formula from matrix
Reason: [explain]

## InMaster.PROD_GROUP Assessment  
Decision: [ ] Populated — use as primary Group source  [ ] Mostly null — users must assign
Top PROD_GROUP values for non-JD parts: [list]

## Franchise Exclusion List
Exclude: D, ZP, [others]
Include: [all others]

## History Column Direction
pi_current_mo_sales = Month Offset 1 (most recent) — confirmed: [yes/no]
```

- [ ] **Step 1.7 — Commit investigation doc**

```bash
git add "projects/part order tool - app/DATA-INVESTIGATION.md"
git commit -m "Non-JD Order Tool: add data investigation results"
```

---

## Task 2: Project Folder Setup

**Files:**
- Create: `projects/part order tool - app/README.md`
- Create: `projects/part order tool - app/ARCHITECTURE.md`

- [ ] **Step 2.1 — Create README.md**

```markdown
# Non-JD Parts Order Tool

**Status:** In development (Fabric Foundation phase)
**Owner:** Brian Fox
**Stakeholder:** [Parts Manager name]

## Overview
A parts reorder tool for non-John Deere parts. Replicates the core capabilities 
of the JD PRISM ordering system for franchises not covered by that program.

## Parts of the Tool
1. **Recommended Reorder** — automatic daily recommendations driven by sales history
2. **One Time Order** — manual wizard with user-selected months and loading factor
3. **Part Information** — part lookup with 60-month history and per-part settings
4. **Home / Navigation** — wrapper connecting all three tools

## Delivery Plan
- **Plan 1 (current):** Fabric data layer — raw tables, parameters, fact tables
- **Plan 2:** Power Apps V1 — 4-screen Canvas App (production tool)
- **Plan 3:** Web App V2 — React app on same Fabric backend (learning project)

## Key Data Sources
| Source | Table | Purpose |
|---|---|---|
| ODBC (EquipRDB64) | jdis_Part_Information | Part master (existing — not modified) |
| ODBC (EquipRDB64) | jdis_Part_Information | Extended history columns (new raw table) |
| ODBC (EquipRDB64) | InMaster | Stocking group, STK_IN_MTH, margin flag |
| SharePoint | config_PartSettings | User-managed per-part overrides |
| CSV upload | param_ROP_Matrix | ROP calculation parameter matrix |

## Design Spec
`docs/superpowers/specs/2026-05-28-non-jd-parts-order-tool-design.md`
```

- [ ] **Step 2.2 — Create ARCHITECTURE.md**

```markdown
# Architecture — Non-JD Parts Order Tool

## Fabric Table Dependency Order

```
[ODBC: jdis_Part_Information] → df_NonJD_Parts_Ordering_Raw → NonJD_Parts_Ordering_Raw
[ODBC: InMaster]              → df_InMaster_Raw              → InMaster_Raw
[CSV upload]                  → df_Param_ROP_Matrix           → param_ROP_Matrix
[Manual list]                 → df_Param_FranchiseScope       → param_FranchiseScope
[SharePoint list]             →                              → config_PartSettings (read directly)

NonJD_Parts_Ordering_Raw + config_PartSettings → df_Fact_NonJD_SalesHistory → Fact_NonJD_SalesHistory
NonJD_Parts_Ordering_Raw + InMaster_Raw + config_PartSettings + param_ROP_Matrix + param_FranchiseScope
    → df_Fact_NonJD_Reorder → Fact_NonJD_Reorder
```

## Refresh Schedule
| Dataflow | Phase | Frequency | Strategy |
|---|---|---|---|
| df_NonJD_Parts_Ordering_Raw | Phase 1 (Raw) | Daily 4 AM | Full refresh |
| df_InMaster_Raw | Phase 1 (Raw) | Daily 4 AM | Incremental (ModifiedDate) |
| df_Param_FranchiseScope | Phase 3 (Dims) | On demand | Full refresh |
| df_Param_ROP_Matrix | Phase 3 (Dims) | On demand | Full refresh |
| df_Fact_NonJD_SalesHistory | Phase 4 (Facts) | Daily | Full refresh |
| df_Fact_NonJD_Reorder | Phase 4 (Facts) | Daily | Full refresh |

## config_PartSettings Storage
- **Phase 1:** SharePoint list (standard license, no Premium required)
- **Phase 2:** Migrate to Lakehouse table when Power Apps Premium confirmed

## Key Constraints
- Do NOT modify the existing df_jdis_Part_Information_Raw dataflow or its output table
- F4 capacity: add new dataflows to appropriate pipeline wave to stay within 4-5 concurrent limit
```

- [ ] **Step 2.3 — Commit**

```bash
git add "projects/part order tool - app/README.md" "projects/part order tool - app/ARCHITECTURE.md"
git commit -m "Non-JD Order Tool: add project README and architecture docs"
```

---

## Task 3: param_FranchiseScope Table

**Files:**
- No .pq file needed — small manual table created directly in Dataflow Gen2

Using findings from Task 1.4, create the franchise scope table.

- [ ] **Step 3.1 — Create the CSV and upload to Lakehouse Files**

Create a file `param_FranchiseScope.csv` with content based on Task 1.4 results and investigation findings:

```
Franchise,IsIncluded,ExclusionReason
D,FALSE,John Deere — handled by JD PRISM system
ZP,FALSE,Warehouse code — not an orderable part
S,FALSE,Inactive franchise (per Physical Inventory report convention)
TD,FALSE,Test/inactive franchise (T* pattern)
TM,FALSE,Test/inactive franchise (T* pattern)
UD,FALSE,Test/inactive franchise (U* pattern)
UM,FALSE,Test/inactive franchise (U* pattern)
95,FALSE,Data entry error — single part with invalid franchise code
AM,TRUE,
BB,TRUE,
BS,TRUE,
BW,TRUE,
C,TRUE,
DA,TRUE,
GR,TRUE,
HT,TRUE,
HW,TRUE,
KB,TRUE,
KM,TRUE,
KR,TRUE,
L,TRUE,
M,TRUE,
MC,TRUE,
ME,TRUE,
MG,TRUE,
MH,TRUE,
ML,TRUE,
MM,TRUE,
MN,TRUE,
MO,TRUE,
MR,TRUE,
MS,TRUE,
MW,TRUE,
P,TRUE,
RC,TRUE,
RM,TRUE,
SB,TRUE,
SC,TRUE,
SS,TRUE,
W,TRUE,
```

Upload to `LH_Master_Data → Files` in the Fabric workspace.

- [ ] **Step 3.2 — Create Dataflow Gen2: df_Param_FranchiseScope**

In Fabric: `LH_Master_Data → New Dataflow Gen2 → df_Param_FranchiseScope`

Power Query:
```
let
    Source = Csv.Document(
        File.Contents("abfss://[your-lakehouse-path]/Files/param_FranchiseScope.csv"),
        [Delimiter=",", Columns=3, Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    PromoteHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    TypedTable = Table.TransformColumnTypes(PromoteHeaders, {
        {"Franchise", type text},
        {"IsIncluded", type logical},
        {"ExclusionReason", type text}
    })
in
    TypedTable
```

Set output destination: `LH_Master_Data` Lakehouse → table name `param_FranchiseScope`.

- [ ] **Step 3.3 — Run and verify**

Run the dataflow. In the Lakehouse, confirm the table exists and all franchises are present with correct IsIncluded values.

Expected: ~40 rows matching the dim_Franchise list. "D" and "ZP" have `IsIncluded = FALSE`.

---

## Task 4: param_ROP_Matrix Table

**Files:**
- Source file already exists: `projects/part order tool - app/example excel sheet/Version 5 ROP-CSV.csv`

- [ ] **Step 4.1 — Upload CSV to Lakehouse Files**

Upload `Version 5 ROP-CSV.csv` from the example excel sheet folder to `LH_Master_Data → Files` as `param_ROP_Matrix.csv`.

- [ ] **Step 4.2 — Create Dataflow Gen2: df_Param_ROP_Matrix**

In Fabric: `LH_Master_Data → New Dataflow Gen2 → df_Param_ROP_Matrix`

```
let
    Source = Csv.Document(
        File.Contents("abfss://[your-lakehouse-path]/Files/param_ROP_Matrix.csv"),
        [Delimiter=",", Columns=18, Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    PromoteHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    // Remove the HTML <BR> from the last column header
    FixHeader = Table.RenameColumns(PromoteHeaders, {
        {"Spiking Warehouse<BR>Stocking Min", "SpikingWarehouseStockingMin"}
    }),
    TypedTable = Table.TransformColumnTypes(FixHeader, {
        {"Group", type text},
        {"Commodity Code", type text},
        {"SRC", type text},
        {"SLC", type text},
        {"Attachment", type text},
        {"Price L", type number},
        {"Price H", type number},
        {"Month Count", Int64.Type},
        {"Demand L", type number},
        {"Demand H", type number},
        {"Sales L", type number},
        {"Sales H", type number},
        {"Modifier", type number},
        {"Trending Cap", type number},
        {"Warehouse Min", Int64.Type},
        {"Stocking weeks", Int64.Type},
        {"Spiking Modifier", type number},
        {"SpikingWarehouseStockingMin", Int64.Type}
    }),
    // Rename to PascalCase for Lakehouse convention
    Renamed = Table.RenameColumns(TypedTable, {
        {"Group", "Group_"},  // "Group" is reserved in some contexts — use Group_ or StockingGroup
        {"Commodity Code", "CommodityCode"},
        {"Price L", "PriceL"},
        {"Price H", "PriceH"},
        {"Month Count", "MonthCount"},
        {"Demand L", "DemandL"},
        {"Demand H", "DemandH"},
        {"Sales L", "SalesL"},
        {"Sales H", "SalesH"},
        {"Trending Cap", "TrendingCap"},
        {"Warehouse Min", "WarehouseMin"},
        {"Stocking weeks", "StockingWeeks"},
        {"Spiking Modifier", "SpikingModifier"}
    })
in
    Renamed
```

Set output destination: `LH_Master_Data` Lakehouse → table name `param_ROP_Matrix`.

- [ ] **Step 4.3 — Run and verify**

Run the dataflow. Confirm the table has 1,993 rows and all numeric columns parse correctly (no nulls in Modifier, StockingWeeks, WarehouseMin).

```
-- Quick validation query (run via Fabric SQL Analytics Endpoint or notebook):
SELECT COUNT(*) as TotalRows, 
       COUNT(DISTINCT MonthCount) as DistinctMonthCounts,
       MIN(Modifier) as MinModifier, 
       MAX(Modifier) as MaxModifier
FROM param_ROP_Matrix
-- Expected: TotalRows=1993, DistinctMonthCounts~37, Modifier range ~0.4 to 24
```

- [ ] **Step 4.4 — Save .pq to query library and commit**

In Dataflow Gen2, copy the Power Query M code. Save to `.claude/queries/` — there is no subfolder for parameter tables yet; create `.claude/queries/parameters/` and save as `param_ROP_Matrix.pq` with the standard header comment block.

```bash
git add ".claude/queries/parameters/param_ROP_Matrix.pq"
git commit -m "Non-JD Order Tool: add param_ROP_Matrix query"
```

---

## Task 5: config_PartSettings SharePoint List

- [ ] **Step 5.1 — Create SharePoint list**

In your SharePoint site, create a new list named `config_PartSettings`.

Add these columns (type in parentheses):

| Column Name | Type | Notes |
|---|---|---|
| Title | Single line of text | Default — repurpose as PartNumber |
| Branch | Single line of text | |
| GroupOverride | Single line of text | Overrides InMaster.PROD_GROUP if set |
| MinOverride | Number | Override for minimum stock level |
| EOQ | Number | Economic Order Quantity |
| ForceNonSpiking | Yes/No | Default: No |
| PreApprovedOrderRule | Choice | Choices: "Use normal rules", "Force 1 time to proposed" |
| Masking | Yes/No | Default: No |
| MaskingExpiration | Date and Time | |
| Notes | Multiple lines of text | Free text for parts manager |

Rename the "Title" column display name to "PartNumber" (the internal name stays "Title" — this is fine for Power Apps).

- [ ] **Step 5.2 — Add one test row**

Add a test entry for a known non-JD part to verify the list is working:
- PartNumber: `TEST-001`
- Branch: `1`
- GroupOverride: `TEST`
- ForceNonSpiking: No

- [ ] **Step 5.3 — Copy the SharePoint list URL**

Note the SharePoint site URL and list name — you'll need these when connecting from Dataflow Gen2 and Power Apps.

Format: `https://[tenant].sharepoint.com/sites/[site-name]` — list name: `config_PartSettings`

Document this in `ARCHITECTURE.md` under a "SharePoint Resources" section.

---

## Task 6: df_NonJD_Parts_Ordering_Raw

**Files:**
- Create: `.claude/queries/raw-tables/NonJD_Parts_Ordering_Raw.pq`

- [ ] **Step 6.1 — Write the query**

Save the following to `.claude/queries/raw-tables/NonJD_Parts_Ordering_Raw.pq`:

```
/*
============================================================================
Query: NonJD_Parts_Ordering_Raw
Dataflow: df_NonJD_Parts_Ordering_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Extended parts data for non-JD ordering tool. Pulls columns not 
included in the existing df_jdis_Part_Information_Raw to avoid impacting 
that table's refresh performance. Non-JD franchises only.

GRAIN: One row per Branch + PartNumber (non-JD parts only)

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — jdis_Part_Information table

REFRESH: Full refresh, once daily (Phase 1 of pipeline)
ROW COUNT: TBD after first run

DO NOT MODIFY df_jdis_Part_Information_Raw — this is a separate purpose-built table.
============================================================================
*/

let
    SQL = "
        SELECT
            pi_Branch                       AS Branch,
            pi_Part_No                      AS PartNumber,
            pi_Franchise                    AS Franchise,
            pi_Description                  AS Description,
            pi_Source                       AS Source,
            pi_SLC                          AS SLC,
            pi_Commodity_Code               AS CommodityCode,
            pi_Dealer_Group_Code            AS DealerGroupCode,
            pi_Vendor_Code                  AS VendorCode,
            pi_On_Hand_Qty                  AS QuantityOnHand,
            pi_On_Order                     AS OnOrder,
            pi_Back_Ord_Qty                 AS BackOrderQty,
            pi_Pending_Qty                  AS PendingQty,
            pi_Bin                          AS Bin,
            pi_Bulk_Bin                     AS BulkBin,
            pi_Package_Qty                  AS PackageQty,
            pi_Return_Indicator             AS Returnable,
            pi_Super_To                     AS SuperTo,
            pi_Super_From                   AS SuperFrom,
            pi_Cost                         AS Cost,
            pi_Sell_Price_1_Master_File     AS SellPrice1,
            pi_List_Price_Master_File       AS ListPrice,
            pi_Date_Created                 AS DateCreated,
            pi_Date_Last_Request            AS DateLastRequested,
            pi_Minimum_Qty                  AS MinimumQty,
            pi_Maximum_Qty                  AS MaximumQty,
            pi_Reorder_Code                 AS ReorderCode,
            pi_Activity_Code                AS ActivityCode,
            pi_suggested_order_qty          AS SystemSuggestedOrderQty,
            pi_current_12_mo_sales          AS Current12MoSales,
            pi_previous_12_mo_sales         AS Previous12MoSales,
            pi_current_12_mo_requests       AS Current12MoRequests,
            pi_previous_12_mo_requests      AS Previous12MoRequests,
            pi_current_12_Lost_Sales_Qty    AS Current12LostSalesQty,
            pi_current_12_Lost_Sales_Value  AS Current12LostSalesValue,
            -- 60 months of sales quantity (01 = most recent month)
            pi_current_mo_sales             AS SalesMonth01,
            pi_sales_history_02             AS SalesMonth02,
            pi_sales_history_03             AS SalesMonth03,
            pi_sales_history_04             AS SalesMonth04,
            pi_sales_history_05             AS SalesMonth05,
            pi_sales_history_06             AS SalesMonth06,
            pi_sales_history_07             AS SalesMonth07,
            pi_sales_history_08             AS SalesMonth08,
            pi_sales_history_09             AS SalesMonth09,
            pi_sales_history_10             AS SalesMonth10,
            pi_sales_history_11             AS SalesMonth11,
            pi_sales_history_12             AS SalesMonth12,
            pi_sales_history_13             AS SalesMonth13,
            pi_sales_history_14             AS SalesMonth14,
            pi_sales_history_15             AS SalesMonth15,
            pi_sales_history_16             AS SalesMonth16,
            pi_sales_history_17             AS SalesMonth17,
            pi_sales_history_18             AS SalesMonth18,
            pi_sales_history_19             AS SalesMonth19,
            pi_sales_history_20             AS SalesMonth20,
            pi_sales_history_21             AS SalesMonth21,
            pi_sales_history_22             AS SalesMonth22,
            pi_sales_history_23             AS SalesMonth23,
            pi_sales_history_24             AS SalesMonth24,
            pi_sales_history_25             AS SalesMonth25,
            pi_sales_history_26             AS SalesMonth26,
            pi_sales_history_27             AS SalesMonth27,
            pi_sales_history_28             AS SalesMonth28,
            pi_sales_history_29             AS SalesMonth29,
            pi_sales_history_30             AS SalesMonth30,
            pi_sales_history_31             AS SalesMonth31,
            pi_sales_history_32             AS SalesMonth32,
            pi_sales_history_33             AS SalesMonth33,
            pi_sales_history_34             AS SalesMonth34,
            pi_sales_history_35             AS SalesMonth35,
            pi_sales_history_36             AS SalesMonth36,
            pi_sales_history_37             AS SalesMonth37,
            pi_sales_history_38             AS SalesMonth38,
            pi_sales_history_39             AS SalesMonth39,
            pi_sales_history_40             AS SalesMonth40,
            pi_sales_history_41             AS SalesMonth41,
            pi_sales_history_42             AS SalesMonth42,
            pi_sales_history_43             AS SalesMonth43,
            pi_sales_history_44             AS SalesMonth44,
            pi_sales_history_45             AS SalesMonth45,
            pi_sales_history_46             AS SalesMonth46,
            pi_sales_history_47             AS SalesMonth47,
            pi_sales_history_48             AS SalesMonth48,
            pi_sales_history_49             AS SalesMonth49,
            pi_sales_history_50             AS SalesMonth50,
            pi_sales_history_51             AS SalesMonth51,
            pi_sales_history_52             AS SalesMonth52,
            pi_sales_history_53             AS SalesMonth53,
            pi_sales_history_54             AS SalesMonth54,
            pi_sales_history_55             AS SalesMonth55,
            pi_sales_history_56             AS SalesMonth56,
            pi_sales_history_57             AS SalesMonth57,
            pi_sales_history_58             AS SalesMonth58,
            pi_sales_history_59             AS SalesMonth59,
            pi_sales_history_60             AS SalesMonth60,
            -- 60 months of demand/request count (01 = most recent month)
            pi_current_mo_requests          AS RequestsMonth01,
            pi_sales_request_02             AS RequestsMonth02,
            pi_sales_request_03             AS RequestsMonth03,
            pi_sales_request_04             AS RequestsMonth04,
            pi_sales_request_05             AS RequestsMonth05,
            pi_sales_request_06             AS RequestsMonth06,
            pi_sales_request_07             AS RequestsMonth07,
            pi_sales_request_08             AS RequestsMonth08,
            pi_sales_request_09             AS RequestsMonth09,
            pi_sales_request_10             AS RequestsMonth10,
            pi_sales_request_11             AS RequestsMonth11,
            pi_sales_request_12             AS RequestsMonth12,
            pi_sales_request_13             AS RequestsMonth13,
            pi_sales_request_14             AS RequestsMonth14,
            pi_sales_request_15             AS RequestsMonth15,
            pi_sales_request_16             AS RequestsMonth16,
            pi_sales_request_17             AS RequestsMonth17,
            pi_sales_request_18             AS RequestsMonth18,
            pi_sales_request_19             AS RequestsMonth19,
            pi_sales_request_20             AS RequestsMonth20,
            pi_sales_request_21             AS RequestsMonth21,
            pi_sales_request_22             AS RequestsMonth22,
            pi_sales_request_23             AS RequestsMonth23,
            pi_sales_request_24             AS RequestsMonth24,
            pi_sales_request_25             AS RequestsMonth25,
            pi_sales_request_26             AS RequestsMonth26,
            pi_sales_request_27             AS RequestsMonth27,
            pi_sales_request_28             AS RequestsMonth28,
            pi_sales_request_29             AS RequestsMonth29,
            pi_sales_request_30             AS RequestsMonth30,
            pi_sales_request_31             AS RequestsMonth31,
            pi_sales_request_32             AS RequestsMonth32,
            pi_sales_request_33             AS RequestsMonth33,
            pi_sales_request_34             AS RequestsMonth34,
            pi_sales_request_35             AS RequestsMonth35,
            pi_sales_request_36             AS RequestsMonth36,
            pi_sales_request_37             AS RequestsMonth37,
            pi_sales_request_38             AS RequestsMonth38,
            pi_sales_request_39             AS RequestsMonth39,
            pi_sales_request_40             AS RequestsMonth40,
            pi_sales_request_41             AS RequestsMonth41,
            pi_sales_request_42             AS RequestsMonth42,
            pi_sales_request_43             AS RequestsMonth43,
            pi_sales_request_44             AS RequestsMonth44,
            pi_sales_request_45             AS RequestsMonth45,
            pi_sales_request_46             AS RequestsMonth46,
            pi_sales_request_47             AS RequestsMonth47,
            pi_sales_request_48             AS RequestsMonth48,
            pi_sales_request_49             AS RequestsMonth49,
            pi_sales_request_50             AS RequestsMonth50,
            pi_sales_request_51             AS RequestsMonth51,
            pi_sales_request_52             AS RequestsMonth52,
            pi_sales_request_53             AS RequestsMonth53,
            pi_sales_request_54             AS RequestsMonth54,
            pi_sales_request_55             AS RequestsMonth55,
            pi_sales_request_56             AS RequestsMonth56,
            pi_sales_request_57             AS RequestsMonth57,
            pi_sales_request_58             AS RequestsMonth58,
            pi_sales_request_59             AS RequestsMonth59,
            pi_sales_request_60             AS RequestsMonth60
        FROM jdis_Part_Information
        WHERE pi_Franchise NOT IN ('D', 'DA', 'ZP')
    ",
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to jdis_Part_Information for NonJD ordering data. Verify ODBC connection and non-JD filter."
in
    Source
```

> **Note:** Update the `WHERE pi_Franchise NOT IN (...)` clause to include all franchises identified as excluded in Task 1.4 before publishing.

- [ ] **Step 6.2 — Create Dataflow Gen2 in Fabric**

Open Fabric → `LH_Master_Data` workspace → New item → Dataflow Gen2.
Name it `df_NonJD_Parts_Ordering_Raw`.
Paste the Power Query M from the .pq file (Advanced Editor).
Set output destination: `LH_Master_Data` Lakehouse → table `NonJD_Parts_Ordering_Raw`.

- [ ] **Step 6.3 — Preview and verify**

Click "Refresh Preview". Confirm:
- Rows are returned (non-JD parts only — no Franchise "D" rows)
- SalesMonth01 through SalesMonth60 columns are present
- RequestsMonth01 through RequestsMonth60 columns are present
- No column names contain spaces (Delta compatibility)

- [ ] **Step 6.4 — Publish and run**

Publish the dataflow. Run it manually. Check the Lakehouse for table `NonJD_Parts_Ordering_Raw`. Spot-check 5 parts against the ODBC source to confirm row counts and column values match.

- [ ] **Step 6.5 — Commit the .pq file**

```bash
git add ".claude/queries/raw-tables/NonJD_Parts_Ordering_Raw.pq"
git commit -m "Non-JD Order Tool: add NonJD_Parts_Ordering_Raw query (60-month history)"
```

---

## Task 7: df_InMaster_Raw

**Files:**
- Create: `.claude/queries/raw-tables/InMaster_Raw.pq`

- [ ] **Step 7.1 — Create RangeStart and RangeEnd parameters in Dataflow Gen2**

Before writing the query, create two parameters in the Dataflow Gen2:
- `RangeStart` — type: `DateTime`, default: `2020-01-01 00:00:00`
- `RangeEnd` — type: `DateTime`, default: `2026-12-31 23:59:59`

These are referenced in the query below. Fabric's incremental refresh overrides these at runtime.

- [ ] **Step 7.2 — Write the query**

Save to `.claude/queries/raw-tables/InMaster_Raw.pq`:

```
/*
============================================================================
Query: InMaster_Raw
Dataflow: df_InMaster_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parts master data from InMaster table — provides stocking group,
stocking months, sales class, category, and margin flag (user_field_3) for 
non-JD parts ordering tool.

GRAIN: One row per Branch + PartNumber (all franchises — filtered downstream)

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — InMaster table

REFRESH: Incremental via ModifiedDate — very low CU
============================================================================
*/

let
    RangeStartText = DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss"),
    RangeEndText   = DateTime.ToText(RangeEnd,   "yyyy-MM-dd HH:mm:ss"),

    SQL = "
        SELECT
            BRANCH          AS Branch,
            FRANCHISE       AS Franchise,
            PART_NO         AS PartNumber,
            PART_DESC       AS Description,
            PROD_GROUP      AS ProdGroup,
            SALES_CLASS     AS SalesClass,
            CATEGORY        AS Category,
            VENDOR_CODE     AS VendorCode,
            MINIMUM_QTY     AS MinimumQty,
            MAXIMUM_QTY     AS MaximumQty,
            REORDER_CODE    AS ReorderCode,
            ACTIVITY_CODE   AS ActivityCode,
            STK_IN_MTH      AS StockingMonths,
            user_field_3    AS MarginFlag,
            CREATION_DATE   AS DateCreated,
            LAST_DEM_DATE   AS DateLastDemand,
            ModifiedDate    AS ModifiedDate
        FROM InMaster
        WHERE ModifiedDate >= '" & RangeStartText & "'
          AND ModifiedDate < '"  & RangeEndText   & "'
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InMaster. Verify ODBC connection and ModifiedDate field."
in
    Source
```

- [ ] **Step 7.3 — Create Dataflow Gen2 in Fabric**

New Dataflow Gen2 → `df_InMaster_Raw`. Paste the query. Set output: `LH_Master_Data` Lakehouse → table `InMaster_Raw`.

Configure incremental refresh on this dataflow:
- Incremental refresh column: `ModifiedDate`
- Store rows from: last 3 years
- Only refresh rows from: last 1 day

- [ ] **Step 7.4 — First run (full load)**

For the first run, set RangeStart to a date well in the past (e.g., `2015-01-01`) to load the full table. Publish and run. Confirm the `InMaster_Raw` table is populated in the Lakehouse.

- [ ] **Step 7.5 — Verify PROD_GROUP**

After the first run, cross-check findings from Task 1.3. Query the Lakehouse table:

```sql
SELECT Franchise, ProdGroup, COUNT(*) as PartCount
FROM InMaster_Raw
WHERE Franchise NOT IN ('D', 'DA', 'ZP')
  AND ProdGroup IS NOT NULL
GROUP BY Franchise, ProdGroup
ORDER BY PartCount DESC
```

Results should match what you found in Task 1.3.

- [ ] **Step 7.6 — Commit the .pq file**

```bash
git add ".claude/queries/raw-tables/InMaster_Raw.pq"
git commit -m "Non-JD Order Tool: add InMaster_Raw incremental query"
```

---

## Task 8: Fact_NonJD_SalesHistory

**Files:**
- Create: `.claude/queries/facts/NonJD_SalesHistory.pq`

This dataflow reads `NonJD_Parts_Ordering_Raw` from the Lakehouse, unpivots the 120 monthly columns (60 sales + 60 requests) into rows, and outputs one row per part per month per metric type.

- [ ] **Step 8.1 — Write the query**

Save to `.claude/queries/facts/NonJD_SalesHistory.pq`:

```
/*
============================================================================
Query: NonJD_SalesHistory (Fact)
Dataflow: df_Fact_NonJD_SalesHistory
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Unpivots the 60-month wide sales and demand history from 
NonJD_Parts_Ordering_Raw into a row-per-month format for the 
Part Information history grid in the ordering tool.

GRAIN: One row per Branch + PartNumber + MonthOffset (1=most recent, 60=oldest)

DEPENDENCIES: NonJD_Parts_Ordering_Raw (must refresh first)
============================================================================
*/

let
    Source = LH_Master_Data{[Schema="dbo", Item="NonJD_Parts_Ordering_Raw"]}[Data],

    // Keep only identity columns + the 120 monthly history columns
    IdentityCols = {"Branch", "PartNumber", "Franchise"},
    SalesCols    = List.Select(Table.ColumnNames(Source), each Text.StartsWith(_, "SalesMonth")),
    RequestsCols = List.Select(Table.ColumnNames(Source), each Text.StartsWith(_, "RequestsMonth")),

    // --- Unpivot Sales ---
    SalesSelected   = Table.SelectColumns(Source, IdentityCols & SalesCols),
    SalesUnpivoted  = Table.UnpivotOtherColumns(SalesSelected, IdentityCols, "MonthKey", "SalesQty"),
    // Extract numeric offset: "SalesMonth01" → 1, "SalesMonth60" → 60
    SalesWithOffset = Table.TransformColumns(SalesUnpivoted, {
        {"MonthKey", each Number.From(Text.End(_, 2)), Int64.Type}
    }),
    SalesRenamed = Table.RenameColumns(SalesWithOffset, {{"MonthKey", "MonthOffset"}}),

    // --- Unpivot Requests (Demand Count) ---
    RequestsSelected   = Table.SelectColumns(Source, IdentityCols & RequestsCols),
    RequestsUnpivoted  = Table.UnpivotOtherColumns(RequestsSelected, IdentityCols, "MonthKey", "DemandCount"),
    RequestsWithOffset = Table.TransformColumns(RequestsUnpivoted, {
        {"MonthKey", each Number.From(Text.End(_, 2)), Int64.Type}
    }),
    RequestsRenamed = Table.RenameColumns(RequestsWithOffset, {{"MonthKey", "MonthOffset"}}),

    // --- Join Sales and Requests on identity + offset ---
    // Pre-select to avoid duplicate Franchise column in join result
    RequestsForJoin = Table.SelectColumns(RequestsRenamed, {"Branch", "PartNumber", "MonthOffset", "DemandCount"}),
    Joined = Table.Join(
        SalesRenamed,    {"Branch", "PartNumber", "MonthOffset"},
        RequestsForJoin, {"Branch", "PartNumber", "MonthOffset"},
        JoinKind.LeftOuter
    ),

    // Set final types
    TypedResult = Table.TransformColumnTypes(Joined, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"Franchise", type text},
        {"MonthOffset", Int64.Type},
        {"SalesQty", Int64.Type},
        {"DemandCount", Int64.Type}
    })
in
    TypedResult
```

- [ ] **Step 8.2 — Create Dataflow Gen2 in Fabric**

New Dataflow Gen2 → `df_Fact_NonJD_SalesHistory`. Add a Lakehouse data source (connect to `LH_Master_Data`, select `NonJD_Parts_Ordering_Raw`). Paste the query. Set output: `LH_Master_Data` Lakehouse → table `Fact_NonJD_SalesHistory`.

- [ ] **Step 8.3 — Preview and verify**

Preview the output. For a part with known sales history:
- Confirm it has 60 rows (one per MonthOffset 1–60)
- Confirm MonthOffset=1 SalesQty matches `SalesMonth01` in the raw table
- Confirm MonthOffset=12 SalesQty matches `SalesMonth12` in the raw table

Spot-check 3 parts to confirm the unpivot is correct.

- [ ] **Step 8.4 — Publish, run, and verify row count**

Run the dataflow. Expected row count ≈ (number of non-JD parts × number of branches × 60). Verify no duplicate MonthOffset rows per part/branch.

- [ ] **Step 8.5 — Commit the .pq file**

```bash
git add ".claude/queries/facts/NonJD_SalesHistory.pq"
git commit -m "Non-JD Order Tool: add NonJD_SalesHistory unpivot fact"
```

---

## Task 9: Fact_NonJD_Reorder

**Files:**
- Create: `.claude/queries/facts/NonJD_Reorder.pq`

> **⚠️ Read Task 1.2 findings before implementing this task.** If `SystemSuggestedOrderQty` is already calculating a sensible ROP, use the simplified path (Step 9.1A). If not, use the full ROP matrix path (Step 9.1B).

- [ ] **Step 9.1A — SIMPLIFIED PATH (if SystemSuggestedOrderQty is usable)**

If Task 1.2 showed the source system already calculates a sensible reorder quantity, this fact table is a simpler join:

```
/*
============================================================================
Query: NonJD_Reorder (Fact) — Simplified path
Uses SystemSuggestedOrderQty from source instead of ROP matrix calculation.
============================================================================
*/
let
    Parts   = LH_Master_Data{[Schema="dbo", Item="NonJD_Parts_Ordering_Raw"]}[Data],
    InMast  = LH_Master_Data{[Schema="dbo", Item="InMaster_Raw"]}[Data],
    FrScope = LH_Master_Data{[Schema="dbo", Item="param_FranchiseScope"]}[Data],
    // Read config_PartSettings from SharePoint
    SPSite  = SharePoint.Tables("https://[your-tenant].sharepoint.com/sites/[site]", 
                                [ApiVersion=15]),
    Config  = SPSite{[Title="config_PartSettings"]}[Items],
    ConfigClean = Table.SelectColumns(Config, {
        "Title", "Branch", "GroupOverride", "MinOverride", "EOQ", "ForceNonSpiking"
    }),
    ConfigRenamed = Table.RenameColumns(ConfigClean, {{"Title", "PartNumber"}}),

    // Filter to in-scope franchises only
    // Pre-select only the join key to avoid adding IsIncluded/ExclusionReason columns to Parts
    InScope = Table.SelectRows(FrScope, each [IsIncluded] = true),
    InScopeKeys = Table.SelectColumns(InScope, {"Franchise"}),
    PartsFiltered = Table.Join(Parts, "Franchise", InScopeKeys, "Franchise", JoinKind.Inner),

    // Join InMaster for ProdGroup and MarginFlag
    // Pre-select only columns unique to InMaster to avoid duplicate Branch/PartNumber/Description/etc.
    InMastSelected = Table.SelectColumns(InMast, {"Branch", "PartNumber", "ProdGroup", "StockingMonths", "MarginFlag", "SalesClass", "Category"}),
    WithInMaster = Table.Join(PartsFiltered, {"Branch", "PartNumber"},
                              InMastSelected, {"Branch", "PartNumber"}, JoinKind.LeftOuter),

    // Join config overrides
    WithConfig = Table.Join(WithInMaster, {"Branch", "PartNumber"},
                            ConfigRenamed, {"Branch", "PartNumber"}, JoinKind.LeftOuter),

    // Calculate effective group (override takes priority over PROD_GROUP)
    WithGroup = Table.AddColumn(WithConfig, "EffectiveGroup", each
        if [GroupOverride] <> null and [GroupOverride] <> "" 
        then [GroupOverride] 
        else [ProdGroup]),

    // Calculate recommended qty using system suggested value
    WithRecommendedQty = Table.AddColumn(WithGroup, "RecommendedOrderQty", each
        let
            effectiveMin = if [MinOverride] <> null then [MinOverride] else [MinimumQty],
            stTarget = Number.Max(effectiveMin, [SystemSuggestedOrderQty])
        in
            Number.Max(0, stTarget - [QuantityOnHand] - [OnOrder])
    ),

    // Estimated order value
    WithOrderValue = Table.AddColumn(WithRecommendedQty, "EstOrderValue", each
        [RecommendedOrderQty] * [Cost]
    ),

    // Select final output columns
    FinalCols = Table.SelectColumns(WithOrderValue, {
        "Branch", "PartNumber", "Franchise", "Description", "VendorCode",
        "SLC", "Source", "CommodityCode", "EffectiveGroup",
        "QuantityOnHand", "OnOrder", "BackOrderQty", "MinimumQty", "MaximumQty",
        "Cost", "SellPrice1", "Bin", "BulkBin",
        "SuperTo", "SuperFrom", "DateCreated", "DateLastRequested",
        "ReorderCode", "ActivityCode",
        "Current12MoSales", "Previous12MoSales", "Current12MoRequests",
        "Current12LostSalesQty", "Current12LostSalesValue",
        "SystemSuggestedOrderQty", "RecommendedOrderQty", "EstOrderValue",
        "ProdGroup", "StockingMonths", "MarginFlag"
    })
in
    FinalCols
```

- [ ] **Step 9.1B — FULL ROP PATH (if SystemSuggestedOrderQty is not usable)**

If the source system's suggested quantity is not reliable, implement the full parameter matrix lookup:

```
/*
============================================================================
Query: NonJD_Reorder (Fact) — Full ROP matrix path
Implements ROP calculation from param_ROP_Matrix parameter table.

⚠️ VALIDATION REQUIRED: Compare CalcROP against JD PRISM outputs for 
   the same parts (if any JD parts exist with known correct values) 
   to confirm the formula before relying on it for ordering decisions.
============================================================================
*/
let
    Parts     = LH_Master_Data{[Schema="dbo", Item="NonJD_Parts_Ordering_Raw"]}[Data],
    InMast    = LH_Master_Data{[Schema="dbo", Item="InMaster_Raw"]}[Data],
    ROPMatrix = LH_Master_Data{[Schema="dbo", Item="param_ROP_Matrix"]}[Data],
    FrScope   = LH_Master_Data{[Schema="dbo", Item="param_FranchiseScope"]}[Data],
    SPSite    = SharePoint.Tables("https://[your-tenant].sharepoint.com/sites/[site]",
                                  [ApiVersion=15]),
    Config    = SPSite{[Title="config_PartSettings"]}[Items],
    ConfigClean   = Table.SelectColumns(Config, {"Title", "Branch", "GroupOverride", "MinOverride", "EOQ", "ForceNonSpiking"}),
    ConfigRenamed = Table.RenameColumns(ConfigClean, {{"Title", "PartNumber"}}),

    // Filter to in-scope franchises
    // Pre-select only the join key to avoid adding IsIncluded/ExclusionReason columns to Parts
    InScope       = Table.SelectRows(FrScope, each [IsIncluded] = true),
    InScopeKeys   = Table.SelectColumns(InScope, {"Franchise"}),
    PartsFiltered = Table.Join(Parts, "Franchise", InScopeKeys, "Franchise", JoinKind.Inner),

    // Join InMaster and config
    // Pre-select only columns unique to InMaster to avoid duplicates (Description, VendorCode, etc.)
    InMastSelected = Table.SelectColumns(InMast, {"Branch", "PartNumber", "ProdGroup", "StockingMonths", "MarginFlag", "SalesClass", "Category"}),
    WithInMaster = Table.Join(PartsFiltered, {"Branch", "PartNumber"}, InMastSelected, {"Branch", "PartNumber"}, JoinKind.LeftOuter),
    WithConfig   = Table.Join(WithInMaster,  {"Branch", "PartNumber"}, ConfigRenamed, {"Branch", "PartNumber"}, JoinKind.LeftOuter),

    // Effective group and min
    WithGroup = Table.AddColumn(WithConfig, "EffectiveGroup", each
        if [GroupOverride] <> null and [GroupOverride] <> "" then [GroupOverride] else [ProdGroup]
    ),
    WithEffectiveMin = Table.AddColumn(WithGroup, "EffectiveMin", each
        if [MinOverride] <> null then [MinOverride] else [MinimumQty]
    ),

    // Calculate stocking month count and average monthly demand from 60-month history
    // MonthCount = number of months (out of 60) where demand or sales > 0
    // AvgMonthlyDemand = total demand across stocking months / MonthCount
    SalesCols = List.Select(Table.ColumnNames(WithEffectiveMin), each Text.StartsWith(_, "SalesMonth")),
    RequestsCols = List.Select(Table.ColumnNames(WithEffectiveMin), each Text.StartsWith(_, "RequestsMonth")),

    WithDemandCalc = Table.AddColumn(WithEffectiveMin, "DemandCalc", each
        let
            salesVals    = Record.ToList(Record.SelectFields(_, SalesCols)),
            requestVals  = Record.ToList(Record.SelectFields(_, RequestsCols)),
            // A month is a "stocking month" if it had sales or requests
            activeMonths = List.Count(List.Select(
                List.Zip({salesVals, requestVals}),
                each _{0} > 0 or _{1} > 0
            )),
            totalDemand  = List.Sum(requestVals),
            monthCount   = if activeMonths = 0 then 0 else activeMonths,
            avgDemand    = if monthCount = 0 then 0 else totalDemand / monthCount,
            totalSales   = List.Sum(salesVals),
            avgSales     = if monthCount = 0 then 0 else totalSales / monthCount
        in
            [MonthCount = monthCount, AvgMonthlyDemand = avgDemand, AvgMonthlySales = avgSales]
    ),
    WithMonthCount  = Table.AddColumn(WithDemandCalc, "MonthCount",       each [DemandCalc][MonthCount]),
    WithAvgDemand   = Table.AddColumn(WithMonthCount, "AvgMonthlyDemand", each [DemandCalc][AvgMonthlyDemand]),
    WithAvgSales    = Table.AddColumn(WithAvgDemand,  "AvgMonthlySales",  each [DemandCalc][AvgMonthlySales]),

    // Look up matching row in param_ROP_Matrix
    // The entire matrix uses "Default" for Group, CommodityCode, SRC, SLC, and Attachment.
    // Lookup is purely: MonthCount match + demand falls in [DemandL, DemandH) + sales falls in [SalesL, SalesH)
    // Cap MonthCount at 19 (matrix max); treat 0 as 1.
    ROPMatrixList = Table.ToRecords(ROPMatrix),

    WithROPLookup = Table.AddColumn(WithAvgSales, "ROPRow", each
        let
            mcount = if [MonthCount] = 0 then 1 else if [MonthCount] > 19 then 19 else [MonthCount],
            demand = [AvgMonthlyDemand],
            sales  = [AvgMonthlySales]
        in
            List.First(List.Select(ROPMatrixList, each
                ([MonthCount] = mcount) and
                (demand >= [DemandL] and demand < [DemandH]) and
                (sales  >= [SalesL]  and sales  < [SalesH])
            ), null)
    ),

    // Extract Modifier and other values from matched row (null-safe)
    WithModifier    = Table.AddColumn(WithROPLookup, "Modifier",      each if [ROPRow] = null then 1 else [ROPRow][Modifier]),
    WithStkWeeks    = Table.AddColumn(WithModifier,  "StockingWeeks", each if [ROPRow] = null then 4 else [ROPRow][StockingWeeks]),
    WithWHMin       = Table.AddColumn(WithStkWeeks,  "WarehouseMin",  each if [ROPRow] = null then 1 else [ROPRow][WarehouseMin]),

    // Calculate ROP and Stocking Target
    // ROP = AvgMonthlyDemand × Modifier
    // StockingTarget = MAX(WarehouseMin, EffectiveMin, ROUND(ROP))
    // ⚠️ Validate this formula against JD PRISM known outputs before relying on it
    WithCalcROP     = Table.AddColumn(WithWHMin, "CalcROP", each [AvgMonthlyDemand] * [Modifier]),
    WithStockTarget = Table.AddColumn(WithCalcROP, "StockingTarget", each
        Number.RoundUp(Number.Max(Number.Max([WarehouseMin], [EffectiveMin]), [CalcROP]))
    ),
    WithOrderQty    = Table.AddColumn(WithStockTarget, "RecommendedOrderQty", each
        Number.Max(0, [StockingTarget] - [QuantityOnHand] - [OnOrder])
    ),
    WithOrderValue  = Table.AddColumn(WithOrderQty, "EstOrderValue", each
        [RecommendedOrderQty] * [Cost]
    ),

    // Drop working columns, keep output columns
    FinalCols = Table.SelectColumns(WithOrderValue, {
        "Branch", "PartNumber", "Franchise", "Description", "VendorCode",
        "SLC", "Source", "CommodityCode", "EffectiveGroup",
        "QuantityOnHand", "OnOrder", "BackOrderQty", "EffectiveMin", "MaximumQty",
        "Cost", "SellPrice1", "Bin", "BulkBin",
        "SuperTo", "SuperFrom", "DateCreated", "DateLastRequested",
        "ReorderCode", "ActivityCode",
        "Current12MoSales", "Previous12MoSales", "Current12MoRequests",
        "Current12LostSalesQty", "Current12LostSalesValue",
        "MonthCount", "AvgMonthlyDemand", "AvgMonthlySales",
        "CalcROP", "StockingTarget", "RecommendedOrderQty", "EstOrderValue",
        "SystemSuggestedOrderQty", "ProdGroup", "StockingMonths", "MarginFlag"
    })
in
    FinalCols
```

- [ ] **Step 9.2 — Create Dataflow Gen2 in Fabric**

New Dataflow Gen2 → `df_Fact_NonJD_Reorder`. Connect to Lakehouse sources. Paste the chosen query path. Add the SharePoint connection for `config_PartSettings`. Set output: `LH_Master_Data` Lakehouse → table `Fact_NonJD_Reorder`.

- [ ] **Step 9.3 — Preview and spot-check**

Preview 10–20 parts. For each, manually verify:
- `RecommendedOrderQty` makes intuitive sense given OnHand, sales history, and stocking target
- Parts with zero sales history have low/zero recommended quantities
- Parts with high consistent demand have quantities that would cover ~1 month of sales
- `EstOrderValue` = `RecommendedOrderQty` × `Cost` ✓

If using the full ROP path (9.1B): compare `CalcROP` against `SystemSuggestedOrderQty` for parts where the system value is non-zero. They should be in the same ballpark. Large discrepancies mean the formula needs adjustment — note findings in `DATA-INVESTIGATION.md`.

- [ ] **Step 9.4 — Publish and run**

Publish and run the dataflow. Verify the `Fact_NonJD_Reorder` table is populated. Check total row count matches `NonJD_Parts_Ordering_Raw` (after franchise filtering).

- [ ] **Step 9.5 — Commit the .pq file**

```bash
git add ".claude/queries/facts/NonJD_Reorder.pq"
git commit -m "Non-JD Order Tool: add NonJD_Reorder calculation fact"
```

---

## Task 10: Pipeline Integration

- [ ] **Step 10.1 — Add raw dataflows to Phase 1 pipeline**

Open `Pipeline_Master_Orchestrator` in Fabric. In the Phase 1 (Raw Data) section, add:
- `df_NonJD_Parts_Ordering_Raw` — add to an existing Phase 1 wave (check current wave sizes; target ≤5 concurrent)
- `df_InMaster_Raw` — add to Phase 1 (incremental, very low CU — can share a wave)

These have no dependencies on each other, so they can run in the same wave.

- [ ] **Step 10.2 — Add fact dataflows to Phase 4 pipeline**

In Phase 4 (Facts), add a new wave (or append to the last wave if capacity allows):
- `df_Fact_NonJD_SalesHistory` — depends on `df_NonJD_Parts_Ordering_Raw` completing (Phase 1)
- `df_Fact_NonJD_Reorder` — depends on both raw tables and config being available

These can run in parallel with each other. Add them to the same Phase 4 wave.

- [ ] **Step 10.3 — Verify pipeline schedule**

Confirm the new dataflows will run automatically in the 4 AM Mon-Fri schedule. Check `projects/refresh-pipeline/pipeline-schedule.md` and update if needed.

- [ ] **Step 10.4 — Commit pipeline schedule update**

```bash
git add "projects/refresh-pipeline/pipeline-schedule.md"
git commit -m "Non-JD Order Tool: add new dataflows to pipeline schedule"
```

---

## Task 11: End-to-End Validation

- [ ] **Step 11.1 — Run the full sequence manually**

Trigger in order (respecting dependencies):
1. `df_NonJD_Parts_Ordering_Raw` (wait for completion)
2. `df_InMaster_Raw` (can run in parallel with above)
3. `df_Fact_NonJD_SalesHistory` (after step 1)
4. `df_Fact_NonJD_Reorder` (after steps 1 + 2)

- [ ] **Step 11.2 — Validate Fact_NonJD_Reorder output**

Run these validation checks against the Lakehouse SQL Analytics Endpoint:

```sql
-- 1. Row count and franchise coverage
SELECT Franchise, COUNT(*) as PartCount, 
       SUM(RecommendedOrderQty) as TotalRecommendedQty,
       SUM(EstOrderValue) as TotalEstValue
FROM Fact_NonJD_Reorder
GROUP BY Franchise
ORDER BY TotalEstValue DESC

-- 2. Parts that need ordering (RecommendedOrderQty > 0)
SELECT COUNT(*) as PartsNeedingOrder,
       SUM(EstOrderValue) as TotalOrderValue
FROM Fact_NonJD_Reorder
WHERE RecommendedOrderQty > 0

-- 3. Confirm no JD parts leaked through
SELECT COUNT(*) as ShouldBeZero
FROM Fact_NonJD_Reorder
WHERE Franchise = 'D'

-- 4. Sanity check: RecommendedOrderQty never negative
SELECT COUNT(*) as ShouldBeZero
FROM Fact_NonJD_Reorder
WHERE RecommendedOrderQty < 0
```

Expected: Query 3 = 0 (no JD parts), Query 4 = 0 (no negative quantities).

- [ ] **Step 11.3 — Validate Fact_NonJD_SalesHistory output**

```sql
-- Each part should have exactly 60 month-offset rows
SELECT Branch, PartNumber, COUNT(*) as MonthRows
FROM Fact_NonJD_SalesHistory
GROUP BY Branch, PartNumber
HAVING COUNT(*) != 60
-- Expected: 0 rows returned (every part has exactly 60)

-- Spot-check one known part
SELECT MonthOffset, SalesQty, DemandCount
FROM Fact_NonJD_SalesHistory
WHERE PartNumber = '[known active non-JD part]'
  AND Branch = '1'
ORDER BY MonthOffset
-- Verify MonthOffset=1 sales match what you see in the source system
```

- [ ] **Step 11.4 — Final commit**

```bash
git add -A
git commit -m "Non-JD Order Tool: Plan 1 (Fabric Foundation) complete — all tables validated"
```

---

## What Comes Next

Once this plan is complete and all fact tables are validated, the next step is **Plan 2: Power Apps V1**, which builds the 4-screen Canvas App on top of this data layer.

Before starting Plan 2, update `DATA-INVESTIGATION.md` with all findings and confirm:
- [ ] Which ROP path was taken (simplified vs full matrix)
- [ ] Whether PROD_GROUP is populated (affects Group assignment UX in the app)
- [ ] Full franchise exclusion list finalized
- [ ] All distinct `user_field_3` values documented and their display treatment decided
- [ ] Power Apps Premium license status confirmed (affects config_PartSettings connector in app)
