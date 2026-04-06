/*
============================================================================
Fact Table: Fact_MDInvoices_Closed
Dataflow:   df_Fact_MDInvoices_Closed
Location:   LH_Master_Data → Dataflows → 04 - Fact
============================================================================

📋 METADATA:
Purpose:  Line-item detail for closed/invoiced Machine Down (emergency) parts
          orders from 2024-01-01 forward. Supports Phase 2 of the MD Invoices
          With No Freight report — historical freight analysis on closed orders.
Grain:    One row per invoiced part line on a closed MD order
Created:  2026-04-01
Output:   Lakehouse table "Fact_MDInvoices_Closed"

🔑 PERFORMANCE APPROACH:
Uses the LH_Master_Data SQL Analytics Endpoint (T-SQL) instead of the Power
Query execution engine. All joins, filters, and aggregations run server-side
on Fabric compute. This avoids loading InTrans_Incremental (10M+ rows) into
the Power Query Mashup engine.

To find SqlEndpoint: Fabric Portal → LH_Master_Data → SQL Analytics Endpoint
→ copy the server string (format: xxxxx.datawarehouse.fabric.microsoft.com)

🔑 KEY DESIGN DECISIONS:
- InvoiceType = 'E' in Invoice = Emergency/Machine Down invoices
- Type = 'I' in InTrans = closed/invoiced lines only
- Date scope: InvoiceDate >= 2024-01-01
- Freight (PartNumber = '3750') aggregated by FileNo for TotalFreightCharged
- Weight from jdis_Part_Information, deduplicated on Branch + PartNumber
- TRY_CAST handles varchar Weight column in jdis
- TransId is the row grain (InTrans has no LineNumber equivalent)

============================================================================
*/

let
    // ========================================================================
    // CONNECTION
    // Update SqlEndpoint with your LH_Master_Data SQL Analytics Endpoint URL
    // Fabric Portal → LH_Master_Data → SQL Analytics Endpoint → connection string
    // ========================================================================

    SqlEndpoint = "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com",

    SQL = "
        WITH MDOrders AS (
            SELECT DISTINCT FileNo
            FROM Insalpar_Audit
            WHERE PurOrderType = 'E'
        ),

        AllMDLines AS (
            SELECT
                t.FileNo,
                t.TransId,
                t.Branch,
                t.Franchise,
                t.PartNumber,
                t.Qty,
                t.SellPrice1,
                t.CostValue,
                t.SaleValue,
                t.Salesman,
                t.JobCode,
                t.TransDatetime  AS InvoiceDate,
                t.CustomerNo     AS CustomerNumber
            FROM InTrans_Incremental t
            INNER JOIN MDOrders m
                ON t.FileNo = m.FileNo
            WHERE t.Type = 'I'
              AND t.TransDatetime >= '2024-01-01'
        ),

        FreightAgg AS (
            SELECT
                FileNo,
                SUM(COALESCE(SaleValue, 0))  AS TotalFreightCharged,
                COUNT(*)                      AS FreightLineCount
            FROM AllMDLines
            WHERE PartNumber = '3750'
            GROUP BY FileNo
        ),

        JdisUnique AS (
            SELECT Branch, PartNumber, TRY_CAST(Weight AS FLOAT) AS Weight
            FROM (
                SELECT
                    Branch,
                    PartNumber,
                    Weight,
                    ROW_NUMBER() OVER (
                        PARTITION BY Branch, PartNumber
                        ORDER BY (SELECT NULL)
                    ) AS rn
                FROM jdis_Part_Information
            ) x
            WHERE rn = 1
        )

        SELECT
            CAST(p.FileNo   AS BIGINT)  AS FileNumber,
            CAST(p.TransId  AS BIGINT)  AS TransId,
            p.Branch,
            p.Franchise,
            p.CustomerNumber,
            p.InvoiceDate,
            p.PartNumber,
            CAST(p.Qty       AS FLOAT)  AS OrderQty,
            CAST(p.SellPrice1 AS FLOAT) AS UnitPrice,
            CAST(p.CostValue  AS FLOAT) AS UnitCost,
            CAST(p.SaleValue  AS FLOAT) AS LineTotal,
            COALESCE(j.Weight, 0)                                       AS Weight,
            COALESCE(j.Weight, 0) * COALESCE(CAST(p.Qty AS FLOAT), 0)  AS TotalLineWeight,
            COALESCE(f.TotalFreightCharged, 0)                          AS TotalFreightCharged,
            COALESCE(f.FreightLineCount, 0)                             AS FreightLineCount,
            CASE
                WHEN COALESCE(f.FreightLineCount, 0) = 0     THEN 'No Freight'
                WHEN COALESCE(f.TotalFreightCharged, 0) <= 0 THEN 'No Freight Charged'
                ELSE 'Has Freight'
            END                                                         AS FreightStatus,
            p.Salesman  AS Salesperson,
            p.JobCode
        FROM AllMDLines p
        LEFT JOIN FreightAgg f
            ON p.FileNo = f.FileNo
        LEFT JOIN JdisUnique j
            ON p.Branch = j.Branch
            AND p.PartNumber = j.PartNumber
        WHERE p.PartNumber <> '3750'
    ",

    Source = Sql.Database(SqlEndpoint, "LH_Master_Data", [Query = SQL])

in
    Source

/*
============================================================================
✅ VALIDATION CHECKLIST (run after first dataflow refresh)
============================================================================

-- 1. Row count and date range
SELECT COUNT(*) AS RowCount, MIN(InvoiceDate) AS Earliest, MAX(InvoiceDate) AS Latest
FROM Fact_MDInvoices_Closed;

-- 2. Freight status breakdown
SELECT FreightStatus, COUNT(DISTINCT FileNumber) AS InvoiceCount
FROM Fact_MDInvoices_Closed
GROUP BY FreightStatus;

-- 3. No duplicate TransId values (grain check)
SELECT TransId, COUNT(*) AS Cnt
FROM Fact_MDInvoices_Closed
GROUP BY TransId
HAVING COUNT(*) > 1;

-- 4. Weight coverage
SELECT
    SUM(CASE WHEN Weight > 0 THEN 1 ELSE 0 END) AS HasWeight,
    COUNT(*) AS Total
FROM Fact_MDInvoices_Closed;

============================================================================
*/
