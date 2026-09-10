# DP InSalPar_Audit + RepairOrderDetail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `InSalPar_Audit` and `RepairOrderDetail` — the last 2 of Category C's original 4 tables genuinely excluded from JD's Bronze mirror (`ArMaster_Contact` and `Parts_InterbranchTransfers` were resolved earlier this session as views, not excluded tables) — onto the `DP` backend.

**Architecture:** Neither table has a JD Bronze mirror, so neither can use the shortcut + Silver notebook pattern every other table this session has used. Both go through a direct ODBC pull via Dataflow Gen2, the same mechanism already proven in this backend by `df_BranchOperational_Raw` and `df_JDIS_PartInformation_*_Raw`. Because the Dataflow Gen2 SQL itself does the column selection/renaming, there's no separate Silver notebook step — the landed table is ready to consume directly (same as `BranchOperational`).

**Tech Stack:** Fabric Dataflow Gen2 (Power Query M, `Odbc.Query` against `dsn=EquipRDB64`), DuckDB + `delta_scan()` for independent post-refresh verification.

---

## Why these two are different from everything else this session

Every other table migrated this session either had a JD Bronze shortcut (zero marginal cost — the source file set doesn't change based on how much of it you read) or was a view resolvable from tables that did. `InSalPar_Audit` and `RepairOrderDetail` have neither — every refresh is a **live ODBC query against the production SQL Anywhere box**. That changes the calculus on filtering and column scope, which is why this plan makes different calls than the usual "bring in everything, unfiltered" default:

### `InSalPar_Audit` — real numbers (queried via SQL Central, 2026-09-10)

- **2,150,130 total rows**, only **299,145 (13.9%) match `PURORDER_TYPE = 'E'`** (Emergency/Machine-Down orders — the old dataflow's filter).
- **76 total real columns**, the old dataflow only ever used 8.
- **Decision (confirmed with Brian):** keep the `PURORDER_TYPE = 'E'` filter. This is a genuine 7.2x reduction in recurring ODBC load on the live production database, not a free Spark-compute difference like every prior filter-drop decision this session (those were all reading from zero-cost OneLake shortcuts). The table's only known consumer (`Fact_MDInvoices_Closed`, matching Machine-Down order `FILE_NO`s) only ever needed the `'E'` rows. If a second real consumer needing other purchase-order types shows up later, revisit.
- **Decision (confirmed with Brian):** stay curated — 9 columns (the old dataflow's 8, plus `Audit_TS`). Most of the other 68 real columns are internal/technical (`GUID_SO`, `Connection_ID`, `Windows_User`, `SourceProgram`, `EPC_DocID`, a 4000-char `COMMENTS` field) with no identified consumer — same discipline as `WKMECHFL` earlier this session, not the "bring in everything" default used for shortcut-sourced tables.
- **New finding, not in the old dataflow:** `Audit_TS` (the audit event's own timestamp) was never selected by the old dataflow, despite this being literally an audit table. Added here — a real, low-cost completeness fix, not scope creep.

### `RepairOrderDetail` — real numbers (queried via SQL Central, 2026-09-10)

- **Only 2,875 total rows** — much smaller than every other repair-order-related table this session (`WKRODESC` 1.6M, `InHist_PmManage` 1.3M). The column list (`CurrentDate`, `DaysSinceCreationDate`, `DaysSinceROFinishDate`, `DaysSinceLastLabor`) strongly suggests this is a **live open-work-orders/WIP snapshot**, not a historical archive — closed ROs most likely age out, the same pattern `InSalPar_Audit`'s own old-dataflow documentation describes for `InSalPar` ("only retains open orders — once closed, rows are deleted").
- **31 real total columns.** The old dataflow curated to 17 "for performance" (its header explicitly targets a "1-minute refresh"), but at 2,875 rows that optimization was solving a problem that doesn't exist at this table's real size.
- **Decision:** bring in all 31 columns, no filter (the old dataflow had none beyond a cosmetic `ORDER BY`). Matches the general "complete at Silver" bias used for every other table this session — the curation reasoning that applied to `InSalPar_Audit` doesn't apply here, since the table is tiny and there's no internal/technical-column bloat.
- **Worth flagging for whenever a Gold-layer fact table reads this:** `DaysSinceLastLabor`, `DaysSinceROFinishDate`, `DaysSinceCreationDate`, and `CurrentDate` are computed by the source system at some point-in-time (not recomputed live by this pull) — same caution as `Parts_InterbranchTransfers`'s `OrderAge`. Whatever staleness existed when the source last recomputed them survives into this table exactly as-is.

---

## Established platform state and conventions this plan builds on

- `DP - Staging - Dev` workspace (`ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`) / `DP_Staging` lakehouse (`876255e0-d462-4697-adc1-4a655f5bb101`).
- Dataflow Gen2 items for direct ODBC pulls live in `Raw Data - Dataflows/` in `DP - Staging - Dev` (git-tracked in `fabric-workspace-docs`), same folder as `df_BranchOperational_Raw` and `df_JDIS_PartInformation_*_Raw`.
- Both new dataflows reuse the **exact same gateway and connection bindings** already proven working for this workspace's 3 existing Dataflow Gen2 items — confirmed identical across all 3 (`gatewayObjectId: d98a8d2c-d0df-4a42-a281-aab18e49dbd7`, ODBC `connectionId` `DatasourceId: 70ea8af2-b529-4843-aee6-28297801fe71`, Lakehouse `connectionId` `DatasourceId: ec4b2ec8-cf80-4ab1-a47d-f018c5be7b6c`). No new gateway/connection setup should be needed.
- `DataDestination` pattern (matching `df_BranchOperational_Raw`/`df_JDIS_PartInformation_*_Raw` exactly): `Lakehouse.Contents(...)` → `workspaceId "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"` → `lakehouseId "876255e0-d462-4697-adc1-4a655f5bb101"` → `Id = "dbo", ItemKind = "Schema"` → `Id = "<TableName>", ItemKind = "Table"`.
- No Silver notebook for either table — the Dataflow Gen2's own SQL does the column selection/renaming, matching `BranchOperational`'s precedent (no separate `Silver_BranchOperational` table exists either).
- This does NOT touch any report, does NOT build Gold-layer business logic, does NOT set up any refresh schedule — Dev tier only, manual trigger only, matching every other piece of this backend.

---

### Task 1: Build `df_InSalPar_Audit_Raw.Dataflow`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_InSalPar_Audit_Raw.Dataflow/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_InSalPar_Audit_Raw.Dataflow/mashup.pq`
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_InSalPar_Audit_Raw.Dataflow/queryMetadata.json`

- [x] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Dataflow",
    "displayName": "df_InSalPar_Audit_Raw"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<generate a new UUID>"
  }
}
```

- [x] **Step 2: Create `mashup.pq`**

```
[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "InSalPar_Audit_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared InSalPar_Audit = /*
============================================================================
Raw Table: InSalPar_Audit (MD Orders Only)
Dataflow:  df_InSalPar_Audit_Raw
Location:  DP - Staging - Dev -> Raw Data - Dataflows
============================================================================

PURPOSE:
Migrates InSalPar_Audit from the legacy LH_Master_Data pipeline's
df_Insalpar_Audit_Raw onto the DP backend. This table has no JD Bronze
mirror (confirmed via direct SQL Anywhere system-catalog query this
session - a genuine base table, not a view) - unlike every other table
migrated this session, there is no OneLake shortcut path, so this stays
on a direct ODBC pull via Dataflow Gen2, same mechanism as
df_BranchOperational_Raw and df_JDIS_PartInformation_*_Raw.

REAL NUMBERS (queried via SQL Central, 2026-09-10):
- 2,150,130 total rows on the source table
- Only 299,145 (13.9%) match PURORDER_TYPE = 'E' (Emergency / Machine-Down
  orders) - the filter kept below
- 76 total real columns on the source table - this pull uses 9

WHY THE FILTER STAYS (unlike every other filter-drop decision this
session): every refresh here is a live ODBC query against the production
SQL Anywhere box, not a zero-cost OneLake shortcut read. Dropping the
filter means a real 7.2x heavier recurring pull against the live source
system. The table's only known consumer, Fact_MDInvoices_Closed (bridges
to identify closed Machine-Down invoices in InTrans_Incremental), only
ever needed PURORDER_TYPE = 'E' rows. Revisit if a real second consumer
needing other purchase-order types shows up.

WHY THE COLUMN SET STAYS CURATED: most of the other 68 real columns are
internal/technical (GUID_SO, Connection_ID, Windows_User, SourceProgram,
EPC_DocID, a 4000-char COMMENTS field) with no identified consumer - same
discipline as WKMECHFL earlier this session, not the "bring in
everything" default used for zero-cost shortcut-sourced tables.

ONE ADDITION beyond the old dataflow's 8 columns: Audit_TS - the audit
event's own timestamp. The old dataflow never selected it, despite this
being literally an audit table - a real completeness gap, not scope
creep.

Grain: one row per audit event per part line (Insert/Change Old/Change
New) for PURORDER_TYPE = 'E' orders - DISTINCT FileNo is the useful
output downstream, matching the old dataflow's own documented usage.

RAW ONLY - no Silver notebook (this Dataflow Gen2's own SQL already does
the column selection/renaming, matching BranchOperational's precedent).
No Gold-layer logic, no report work.
============================================================================
*/
let
    SQL = "
        SELECT DISTINCT
            FILE_NO         AS FileNo,
            BRANCH           AS Branch,
            FRANCHISE        AS Franchise,
            PURORDER_TYPE    AS PurOrderType,
            PURORDER_NO      AS PurOrderNo,
            SALESMAN         AS Salesman,
            CUSTOMER_NO      AS CustomerNo,
            MACHINE_ID       AS MachineId,
            Audit_TS         AS AuditTimestamp
        FROM InSalPar_Audit
        WHERE PURORDER_TYPE = 'E'
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to InSalPar_Audit. Verify database connection and table availability.",

    SetTypes = Table.TransformColumnTypes(Source, {
        {"FileNo",         type text},
        {"Branch",         type text},
        {"Franchise",      type text},
        {"PurOrderType",   type text},
        {"PurOrderNo",     type text},
        {"Salesman",       type text},
        {"CustomerNo",     type text},
        {"MachineId",      type text},
        {"AuditTimestamp", type datetime}
    })
in
    SetTypes;
shared InSalPar_Audit_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "876255e0-d462-4697-adc1-4a655f5bb101"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "InSalPar_Audit", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
```

- [x] **Step 3: Create `queryMetadata.json`**

```json
{
  "formatVersion": "202502",
  "computeEngineSettings": {
    "allowModernEvaluationEngine": true
  },
  "name": "df_InSalPar_Audit_Raw",
  "queryGroups": [],
  "documentLocale": "en-US",
  "gatewayObjectId": "d98a8d2c-d0df-4a42-a281-aab18e49dbd7",
  "queriesMetadata": {
    "InSalPar_Audit": {
      "queryId": "<generate a new UUID>",
      "queryName": "InSalPar_Audit",
      "loadEnabled": false
    },
    "InSalPar_Audit_DataDestination": {
      "queryId": "<generate a new UUID>",
      "queryName": "InSalPar_Audit_DataDestination",
      "isHidden": true,
      "loadEnabled": false
    }
  },
  "connections": [
    {
      "path": "dsn=EquipRDB64",
      "kind": "Odbc",
      "connectionId": "{\"ClusterId\":\"d98a8d2c-d0df-4a42-a281-aab18e49dbd7\",\"DatasourceId\":\"70ea8af2-b529-4843-aee6-28297801fe71\"}"
    },
    {
      "path": "Lakehouse",
      "kind": "Lakehouse",
      "connectionId": "{\"ClusterId\":\"d98a8d2c-d0df-4a42-a281-aab18e49dbd7\",\"DatasourceId\":\"ec4b2ec8-cf80-4ab1-a47d-f018c5be7b6c\"}"
    }
  ]
}
```

---

### Task 2: Build `df_RepairOrderDetail_Raw.Dataflow`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_RepairOrderDetail_Raw.Dataflow/.platform`
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_RepairOrderDetail_Raw.Dataflow/mashup.pq`
- Create: `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_RepairOrderDetail_Raw.Dataflow/queryMetadata.json`

- [x] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Dataflow",
    "displayName": "df_RepairOrderDetail_Raw"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<generate a new UUID>"
  }
}
```

- [x] **Step 2: Create `mashup.pq`**

```
[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "RepairOrderDetail_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared RepairOrderDetail = /*
============================================================================
Raw Table: RepairOrderDetail
Dataflow:  df_RepairOrderDetail_Raw
Location:  DP - Staging - Dev -> Raw Data - Dataflows
============================================================================

PURPOSE:
Migrates RepairOrderDetail from the legacy LH_Master_Data pipeline's
df_RepairOrderDetail_Raw onto the DP backend. Like InSalPar_Audit, this
table has no JD Bronze mirror (confirmed genuine base table via direct
SQL Anywhere system-catalog query this session) - no shortcut path
exists, so this stays on a direct ODBC pull via Dataflow Gen2.

REAL NUMBERS (queried via SQL Central, 2026-09-10):
- Only 2,875 total rows - much smaller than every other repair-order
  table this session (WKRODESC 1.6M rows, InHist_PmManage 1.3M rows).
  The column list (CurrentDate, DaysSinceCreationDate,
  DaysSinceROFinishDate, DaysSinceLastLabor) strongly suggests this is a
  live open-work-orders/WIP snapshot, not a historical archive - closed
  ROs most likely age out, the same pattern InSalPar_Audit's own old
  dataflow documentation describes for InSalPar itself ("only retains
  open orders - once closed, rows are deleted").
- 31 total real columns. The old dataflow curated to 17 "for
  performance" (its header explicitly targeted a 1-minute refresh), but
  at 2,875 rows that optimization was solving a problem that doesn't
  exist at this table's real size.

DECISION: bring in all 31 real columns, no filter (the old dataflow had
none beyond a cosmetic ORDER BY, dropped here as unnecessary for a raw
table). Matches the "complete at Silver" bias used for every other table
this session - the curation reasoning applied to InSalPar_Audit doesn't
apply here, since this table is tiny with no internal/technical-column
bloat.

WORTH KNOWING for whenever a Gold-layer fact table reads this:
DaysSinceLastLabor, DaysSinceROFinishDate, DaysSinceCreationDate, and
CurrentDate are computed by the source system at some point in time, not
recomputed live by this pull - same caution as Parts_InterbranchTransfers's
OrderAge finding from the Category C investigation. Whatever staleness
existed when the source last recomputed them survives into this table
exactly as-is.

Grain: one row per work order (matches the old dataflow's own
documentation).

RAW ONLY - no Silver notebook (this Dataflow Gen2's own SQL already
selects/renames columns, matching BranchOperational's precedent). No
Gold-layer aging/status-mapping/revenue-categorization logic (all of
that was already correctly deferred to the fact-table layer by the old
dataflow's own header - preserved here). No report work.
============================================================================
*/
let
    SQL = "
        SELECT
            Branch                   AS Branch,
            RONumber                 AS RONumber,
            JobCode                  AS JobCode,
            JobType                  AS JobType,
            InvoiceNumber            AS InvoiceNumber,
            StatusDisplay            AS StatusDisplay,
            Status                   AS Status,
            ROProgressStatus         AS ROProgressStatus,
            CreationDate             AS CreationDate,
            ROStartDate              AS ROStartDate,
            ROFinishDate             AS ROFinishDate,
            JobStartDate             AS JobStartDate,
            JobFinishDate            AS JobFinishDate,
            InvoiceDate              AS InvoiceDate,
            AvailablePickupDate      AS AvailablePickupDate,
            ClosedDate               AS ClosedDate,
            QuotationIndicator       AS QuotationIndicator,
            QuotationExpirationDate  AS QuotationExpirationDate,
            FirstLaborPunch          AS FirstLaborPunch,
            LastLaborPunch           AS LastLaborPunch,
            SalespersonCode          AS SalespersonCode,
            NonRevenueIndicator      AS NonRevenueIndicator,
            Year                     AS Year,
            LaborSale                AS LaborSale,
            PartSale                 AS PartSale,
            SubletSale               AS SubletSale,
            OtherSale                AS OtherSale,
            TotalSale                AS TotalSale,
            DaysSinceCreationDate    AS DaysSinceCreationDate,
            DaysSinceROFinishDate    AS DaysSinceROFinishDate,
            DaysSinceLastLabor       AS DaysSinceLastLabor,
            CurrentDate              AS SourceCurrentDate
        FROM RepairOrderDetail
    ",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to RepairOrderDetail. Verify database connection and table availability.",

    ConvertRONumberToText = Table.TransformColumnTypes(Source, {{"RONumber", type text}})
in
    ConvertRONumberToText;
shared RepairOrderDetail_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "876255e0-d462-4697-adc1-4a655f5bb101"]}[Data],
  Navigation_3 = Navigation_2{[Id = "dbo", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "RepairOrderDetail", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
```

Note: `CurrentDate` is renamed to `SourceCurrentDate` to avoid any collision with
Power Query's own `DateTime.LocalNow()`-adjacent semantics and to make its
point-in-time-snapshot nature explicit to anyone reading the landed table later
(see the header comment above).

- [x] **Step 3: Create `queryMetadata.json`**

```json
{
  "formatVersion": "202502",
  "computeEngineSettings": {
    "allowModernEvaluationEngine": true
  },
  "name": "df_RepairOrderDetail_Raw",
  "queryGroups": [],
  "documentLocale": "en-US",
  "gatewayObjectId": "d98a8d2c-d0df-4a42-a281-aab18e49dbd7",
  "queriesMetadata": {
    "RepairOrderDetail": {
      "queryId": "<generate a new UUID>",
      "queryName": "RepairOrderDetail",
      "loadEnabled": false
    },
    "RepairOrderDetail_DataDestination": {
      "queryId": "<generate a new UUID>",
      "queryName": "RepairOrderDetail_DataDestination",
      "isHidden": true,
      "loadEnabled": false
    }
  },
  "connections": [
    {
      "path": "dsn=EquipRDB64",
      "kind": "Odbc",
      "connectionId": "{\"ClusterId\":\"d98a8d2c-d0df-4a42-a281-aab18e49dbd7\",\"DatasourceId\":\"70ea8af2-b529-4843-aee6-28297801fe71\"}"
    },
    {
      "path": "Lakehouse",
      "kind": "Lakehouse",
      "connectionId": "{\"ClusterId\":\"d98a8d2c-d0df-4a42-a281-aab18e49dbd7\",\"DatasourceId\":\"ec4b2ec8-cf80-4ab1-a47d-f018c5be7b6c\"}"
    }
  ]
}
```

---

### Task 3: Commit and push both dataflows

**Files:** none new (commits Task 1 + Task 2 output)

- [x] **Step 1: Check for upstream races, commit, push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_InSalPar_Audit_Raw.Dataflow" "workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_RepairOrderDetail_Raw.Dataflow"
git commit -m "Add df_InSalPar_Audit_Raw and df_RepairOrderDetail_Raw dataflows

Migrates the last 2 genuinely-excluded Category C tables onto the DP
backend via direct ODBC pull (Dataflow Gen2) - neither has a JD Bronze
mirror, so no shortcut path exists.

InSalPar_Audit keeps its PURORDER_TYPE='E' filter (7.2x reduction on a
real recurring ODBC pull against production, not a free shortcut read)
and stays curated to 9 columns (8 proven-needed + Audit_TS, a real
completeness gap). RepairOrderDetail brings in all 31 real columns
unfiltered - the old dataflow's 17-column 'performance optimization'
was solving a problem that doesn't exist at this table's real size
(2,875 rows).

Both reuse this workspace's existing gateway/connection bindings
already proven by df_BranchOperational_Raw and df_JDIS_PartInformation_*_Raw.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Brian syncs Dev and runs both dataflows

**Files:** none (Fabric portal action)

- [ ] **Step 1: Sync the workspace**

`DP - Staging - Dev` → Source control → **Update all**.

- [ ] **Step 2: Run both dataflows**

Open `df_InSalPar_Audit_Raw` (in `Raw Data - Dataflows/`) and **Refresh now**. Then open
`df_RepairOrderDetail_Raw` and **Refresh now**.

If either shows a connection/gateway error on first run despite reusing the existing
bindings, the git-synced connection reference may need to be manually re-pointed to the
same `dsn=EquipRDB64` connection the other 3 dataflows in this workspace already use —
report back the exact error if this happens rather than guessing at a fix.

- [ ] **Step 3: Report back**

Both dataflows' refresh status (success/failure), and if either fails, the full error
text.

---

### Task 5: Independently verify both landed tables

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_insalpar_audit_repairorderdetail.py`

- [x] **Step 1: Write the verification script**

```python
"""
DP INSALPAR_AUDIT + REPAIRORDERDETAIL - VERIFICATION
============================================================================
Both tables landed via direct ODBC pull (Dataflow Gen2), not a shortcut -
there's no JD Bronze mirror to compare against. This script checks the
landed DP_Staging tables directly: row counts against the real numbers
found via SQL Central on 2026-09-10, and the real column contracts.

Row counts WILL drift from the numbers below since the source is live -
investigate only if the gap is large or the PurOrderType filter check
fails outright.

Run manually after Brian runs both dataflows (plan Task 4).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY: InSalPar_Audit")
print("=" * 80)

insalpar_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InSalPar_Audit')").fetchone()[0]
print(f"Row count: {insalpar_count:,} (real source on 2026-09-10: 299,145 rows matching PURORDER_TYPE='E')")

expected_insalpar_cols = {
    "FileNo", "Branch", "Franchise", "PurOrderType", "PurOrderNo",
    "Salesman", "CustomerNo", "MachineId", "AuditTimestamp",
}
insalpar_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/InSalPar_Audit') LIMIT 0").df()
insalpar_col_set = set(insalpar_cols["column_name"].tolist())
if expected_insalpar_cols == insalpar_col_set:
    print("PASS: 9-column contract matches exactly (including the AuditTimestamp addition).")
else:
    print(f"Missing: {expected_insalpar_cols - insalpar_col_set}")
    print(f"Extra: {insalpar_col_set - expected_insalpar_cols}")

purordertype_check = con.execute(f"""
    SELECT PurOrderType, COUNT(*) AS RowCount
    FROM delta_scan('{dp_base}/InSalPar_Audit')
    GROUP BY PurOrderType
""").df()
print("\nPurOrderType breakdown (every row should be 'E' - the filter is applied at the source query):")
print(purordertype_check.to_string())

print("\n" + "=" * 80)
print("VERIFY: RepairOrderDetail")
print("=" * 80)

ro_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/RepairOrderDetail')").fetchone()[0]
print(f"Row count: {ro_count:,} (real source on 2026-09-10: 2,875 rows)")

expected_ro_cols = {
    "Branch", "RONumber", "JobCode", "JobType", "InvoiceNumber", "StatusDisplay",
    "Status", "ROProgressStatus", "CreationDate", "ROStartDate", "ROFinishDate",
    "JobStartDate", "JobFinishDate", "InvoiceDate", "AvailablePickupDate",
    "ClosedDate", "QuotationIndicator", "QuotationExpirationDate",
    "FirstLaborPunch", "LastLaborPunch", "SalespersonCode", "NonRevenueIndicator",
    "Year", "LaborSale", "PartSale", "SubletSale", "OtherSale", "TotalSale",
    "DaysSinceCreationDate", "DaysSinceROFinishDate", "DaysSinceLastLabor",
    "SourceCurrentDate",
}
ro_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/RepairOrderDetail') LIMIT 0").df()
ro_col_set = set(ro_cols["column_name"].tolist())
if expected_ro_cols == ro_col_set:
    print("PASS: 31-column contract matches exactly.")
else:
    print(f"Missing: {expected_ro_cols - ro_col_set}")
    print(f"Extra: {ro_col_set - expected_ro_cols}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_insalpar_audit_repairorderdetail.py
```

- [x] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_insalpar_audit_repairorderdetail.py
git commit -m "Add InSalPar_Audit + RepairOrderDetail verification script

Checks both landed DP_Staging tables directly (no JD Bronze mirror
exists for either, so there's nothing to shortcut-compare against) -
row counts against the real numbers found via SQL Central, the
9-column and 31-column contracts, and confirms the InSalPar_Audit
PurOrderType filter is fully applied at the source query.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Update reference docs and close out the Category C catalog entry

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`
- Modify: `C:\Users\bfox\.claude\projects\c--Users-bfox-Documents-Git-Projects-data-projects\memory\project_category_c_views_resolved.md`

- [ ] **Step 1: Add a new section to `data-platform-workspaces.md`**

Add a `## InSalPar_Audit and RepairOrderDetail (2026-09-10) — the last 2 genuinely-excluded Category C tables` section (after the `InMaster` section) covering: why these two use Dataflow Gen2 instead of a shortcut, the real row-count/column-count findings, the filter-kept decision on `InSalPar_Audit` and why it differs from every prior filter-drop decision this session, the `Audit_TS` addition, the `RepairOrderDetail` WIP-snapshot finding and its point-in-time-computed columns caveat, and the verification results. Also mention in the `DP_Staging` Lakehouses table row that these 2 tables now exist there too.

- [ ] **Step 2: Update the catalog doc's Category C section**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`, update the `InSalPar_Audit`/`RepairOrderDetail` rows to note both are now migrated (direct ODBC pull via Dataflow Gen2, same as `jdis_Part_Information`/`BranchOperational`), closing out every Category C table.

- [ ] **Step 3: Update the project memory file**

Append a short note to `project_category_c_views_resolved.md`'s `InSalPar_Audit` and `RepairOrderDetail` section recording that both are now migrated, with the real numbers (row counts, column counts, the filter/curation decisions and why).

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document InSalPar_Audit + RepairOrderDetail migration

Closes out every Category C table from the raw-sources catalog -
InSalPar_Audit and RepairOrderDetail were the last 2 genuinely
excluded from JD's Bronze mirror (ArMaster_Contact and
Parts_InterbranchTransfers were resolved earlier as views, not
excluded tables).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 7: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean.

**Do not extend this into a Gold-layer fact table for either, or any report repointing** —
that's future work, not implied by completing this plan. This closes out the entire
Category A/B/C raw-sources catalog effort from `jd-bronze-raw-sources-catalog.md`.
