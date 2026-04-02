/*
============================================================================
Investigation 13: Phase 2 — InTrans Lakehouse Coverage Gap
Purpose: Determine how much InTrans history exists in the Lakehouse vs
         the source system, to understand the backfill requirement for
         Phase 2 of MD Invoices With No Freight.
Date:    2026-03-31
============================================================================

KEY QUESTIONS:
1. How far back does InTrans_Incremental in the Lakehouse go?
2. How many MD invoice lines (TYPE='I', File_No in E-type invoices) are in
   the Lakehouse vs the source system?
3. What is the backfill gap in rows and years?

Run at: Lakehouse SQL endpoint (LH_Master_Data)
============================================================================
*/


-- ============================================================================
-- BLOCK 1: InTrans_Incremental date range and row count in Lakehouse
-- Compare to source system: 20M rows, 6/1/2010 to today
-- ============================================================================

SELECT
    MIN(TransDatetime)  AS EarliestTrans,
    MAX(TransDatetime)  AS LatestTrans,
    COUNT(*)            AS TotalRows
FROM InTrans_Incremental;


-- ============================================================================
-- BLOCK 2: MD invoice lines in Lakehouse InTrans_Incremental
-- Join to InvoiceInformationDetail via FileNo to find E-type invoices
-- This shows us how much Phase 2 data already exists in the Lakehouse
-- ============================================================================

/*
SELECT
    COUNT(*)                    AS LineCount,
    COUNT(DISTINCT t.FileNo)    AS InvoiceCount,
    MIN(t.TransDatetime)        AS EarliestDate,
    MAX(t.TransDatetime)        AS LatestDate
FROM InTrans_Incremental t
WHERE t.Type = 'I'
  AND EXISTS (
      SELECT 1
      FROM Fact_MDInvoices_NoFreight f
      WHERE f.FileNumber = TRY_CAST(t.FileNo AS BIGINT)
  );
*/


-- ============================================================================
-- BLOCK 3: Freight split on Lakehouse MD invoices
-- Of the MD invoices already in the Lakehouse, how many have/don't have 3750?
-- ============================================================================

/*
SELECT
    CASE WHEN FreightExists = 1 THEN 'Has Freight' ELSE 'No Freight' END AS FreightStatus,
    COUNT(*) AS InvoiceCount
FROM (
    SELECT
        FileNo,
        MAX(CASE WHEN PartNumber = '3750' THEN 1 ELSE 0 END) AS FreightExists
    FROM InTrans_Incremental
    WHERE Type = 'I'
      AND FileNo IN (
          SELECT CAST(FileNumber AS VARCHAR) FROM Fact_MDInvoices_NoFreight
      )
    GROUP BY FileNo
) sub
GROUP BY FreightExists
ORDER BY FreightExists DESC;
*/


-- ============================================================================
-- BLOCK 4: Column names check — confirm Lakehouse InTrans_Incremental
-- columns match what we expect from the source system investigation
-- (Lakehouse uses PascalCase renames — FileNo, PartNumber, etc.)
-- ============================================================================

/*
SELECT TOP 1 * FROM InTrans_Incremental WHERE 1=0;
*/
