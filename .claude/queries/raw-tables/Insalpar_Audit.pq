/*
============================================================================
Raw Table: Insalpar_Audit (MD Orders Only)
Dataflow:  df_Insalpar_Audit_Raw
Location:  LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Purpose:  Audit trail of insalpar (parts order lines). Used exclusively as
          the bridge to identify Machine Down (Emergency) order FILE_NOs for
          historical closed invoice analysis. insalpar only retains open
          orders — once closed, rows are deleted. This audit table is the
          only source that retains PURORDER_TYPE = 'E' history.
Grain:    One row per audit event per part line (Insert/Change Old/Change New)
          — DISTINCT FILE_NO with PURORDER_TYPE = 'E' is the useful output
Created:  2026-04-02
Output:   Lakehouse table "Insalpar_Audit"

🔑 KEY DESIGN DECISIONS:
- Filtered to PURORDER_TYPE = 'E' only — this is the sole purpose of this table
- All audit action types retained (Insert, Change Old, Change New) — the
  fact table downstream uses DISTINCT FILE_NO so duplicates don't matter
- Minimal column set: only what's needed to identify MD orders and join
  to InTrans_Incremental for parts detail
- Full history (no date filter) — 14,123 unique MD orders back to 2012,
  manageable volume (~284K rows after filter)

🔗 DEPENDENCIES:
- InSalPar_Audit (source system table via dsn=EquipRDB64)

🔗 USED BY:
- Fact_MDInvoices_Closed — joins on FileNo to identify closed MD invoices
  in InTrans_Incremental

⏱️ REFRESH:
- Full refresh (audit table only appends, but full refresh is safe at this volume)
- Add to Phase 1 (Raw Sources) in Pipeline_Master_Orchestrator
- Must refresh BEFORE Fact_MDInvoices_Closed dataflow

============================================================================
*/

let
    SQL = "
        SELECT DISTINCT
            FILE_NO         AS FileNo,
            BRANCH          AS Branch,
            FRANCHISE       AS Franchise,
            PURORDER_TYPE   AS PurOrderType,
            PURORDER_NO     AS PurOrderNo,
            SALESMAN        AS Salesman,
            CUSTOMER_NO     AS CustomerNo,
            MACHINE_ID      AS MachineId
        FROM InSalPar_Audit
        WHERE PURORDER_TYPE = 'E'
    ",

    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    SetTypes = Table.TransformColumnTypes(Source, {
        {"FileNo",      type text},
        {"Branch",      type text},
        {"Franchise",   type text},
        {"PurOrderType", type text},
        {"PurOrderNo",  type text},
        {"Salesman",    type text},
        {"CustomerNo",  type text},
        {"MachineId",   type text}
    })

in
    SetTypes

/*
============================================================================
✅ VALIDATION (run at Lakehouse SQL endpoint after first refresh)
============================================================================

-- 1. Row count — should be ~14,000+ unique FILE_NOs
SELECT COUNT(*) AS RowCount FROM Insalpar_Audit;

-- 2. All rows should be PurOrderType = 'E'
SELECT PurOrderType, COUNT(*) AS Count
FROM Insalpar_Audit
GROUP BY PurOrderType;

-- 3. Spot check — compare a known MD order from the open orders report
--    to confirm it exists here
SELECT * FROM Insalpar_Audit WHERE FileNo = '<known MD order number>';

============================================================================
*/
