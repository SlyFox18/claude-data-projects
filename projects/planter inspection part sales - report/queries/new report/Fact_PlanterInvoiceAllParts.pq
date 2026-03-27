/*
============================================================================
FACT_PLANTER_INVOICE_ALL_PARTS — ALL PARTS ON PLANTER-INVOICE INVOICES
============================================================================

Purpose:     All part transactions on invoices that included at least one
             planter-classified part. Powers the "Planter Part Sales" page
             (Page 2) and supports the stakeholder's desired view: total of
             all parts sold alongside planter parts.
Grain:       One row per part transaction line
Refresh:     Full refresh
Sources:     dbo.InTrans_Incremental, dbo.dim_Parts (LH_Master_Data SQL endpoint)

Business Use:
- Total revenue from ALL parts on invoices that contained a planter part
- Dual breakdown via IsPlanterPart flag:
    IsPlanterPart = TRUE  → planter-classified parts
    IsPlanterPart = FALSE → add-on (non-planter) parts sold on the same invoice
- DAX computes:
    [Total Invoice Parts $] = planter + add-on
    [Planter Parts $]       = IsPlanterPart = TRUE
    [Add-On Parts $]        = IsPlanterPart = FALSE

Planter Part Identification:
  1. CommodityCode IN ('310'-'318') — planter equipment commodity codes
  2. PartNumber LIKE '%PLANTER%' — catches promo and specialty planter parts

Design Decisions:
- ZP franchise items INCLUDED — needed to compute full invoice totals.
- Date filter: TransDatetime >= 2025-01-01 (consistent with other fact tables).
- NATIVE SQL QUERY via Sql.Database [Query=...] — bypasses Power Query's
  folding engine entirely. The three-join pattern required for this table
  (InTrans → planter invoice keys → all parts → IsPlanterPart flag) causes
  Power Query to fall back to in-memory evaluation on the second InTrans scan
  (10M+ rows), resulting in 15+ minute timeouts. Pushing native SQL to the
  Lakehouse T-SQL endpoint handles the double-scan with a single optimized
  query plan.
============================================================================
*/

let
    Source = Sql.Database(
        "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com",
        "LH_Master_Data",
        [
            Query =
            "
            WITH planter_parts AS (
                -- Parts classified as planter: commodity codes 310-318 OR name contains PLANTER
                SELECT DISTINCT PartNumber
                FROM   dbo.dim_Parts
                WHERE  CommodityCode IN ('310','311','312','313','314','315','316','317','318')
                    OR PartNumber LIKE '%PLANTER%'
            ),
            planter_invoice_keys AS (
                -- Invoice keys (Branch + RONumber) that had at least one planter part
                SELECT DISTINCT Branch, RONumber
                FROM   dbo.InTrans_Incremental
                WHERE  TransDatetime >= '2025-01-01'
                  AND  Type = 'I'
                  AND  PartNumber IN (SELECT PartNumber FROM planter_parts)
            )
            SELECT
                it.Branch                                                 AS BranchCode,
                it.RONumber                                               AS InvoiceNumber,
                it.CustomerNo                                             AS CustomerNumber,
                it.PartNumber,
                it.Description,
                it.Franchise,
                CAST(it.Qty           AS float)                           AS Quantity,
                CAST(it.SaleValue     AS float)                           AS SaleValue,
                CAST(it.CostValue     AS float)                           AS CostValue,
                CAST(it.TransDatetime AS date)                            AS TransactionDate,
                CAST(
                    CASE WHEN pp.PartNumber IS NOT NULL THEN 1 ELSE 0 END
                AS bit)                                                   AS IsPlanterPart
            FROM   dbo.InTrans_Incremental it
            INNER JOIN planter_invoice_keys pik
                ON  it.Branch    = pik.Branch
                AND it.RONumber  = pik.RONumber
            LEFT  JOIN planter_parts pp
                ON  it.PartNumber = pp.PartNumber
            WHERE  it.TransDatetime >= '2025-01-01'
              AND  it.Type = 'I'
            "
        ]
    ),

    SetDataTypes = Table.TransformColumnTypes(
        Source,
        {
            {"BranchCode",      type text},
            {"InvoiceNumber",   type text},
            {"CustomerNumber",  type text},
            {"PartNumber",      type text},
            {"Description",     type text},
            {"Franchise",       type text},
            {"Quantity",        type number},
            {"SaleValue",       type number},
            {"CostValue",       type number},
            {"TransactionDate", type date},
            {"IsPlanterPart",   type logical}
        }
    )

in
    SetDataTypes
