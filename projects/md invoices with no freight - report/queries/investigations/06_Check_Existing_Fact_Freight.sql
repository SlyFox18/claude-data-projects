-- ================================================================================
-- INVESTIGATION 06: Does Fact_InSalOrd_InSalPar.Freight have any data?
-- Purpose: The 60+ Days Past Due fact already joins insalord+insalpar and
--          has a Freight column. Check if it has real data — if yes, confirms
--          Insalord.Freight IS populated for some order types (just not MD open orders).
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- ================================================================================

SELECT
    COUNT(*)                                                            AS TotalRows,
    SUM(CASE WHEN Freight IS NULL THEN 1 ELSE 0 END)                    AS NullFreight,
    SUM(CASE WHEN Freight = 0 THEN 1 ELSE 0 END)                        AS ZeroFreight,
    SUM(CASE WHEN Freight > 0 THEN 1 ELSE 0 END)                        AS HasFreight,
    MIN(Freight)                                                        AS MinFreight,
    MAX(Freight)                                                        AS MaxFreight,
    AVG(Freight)                                                        AS AvgFreight
FROM Fact_InSalOrd_InSalPar;

-- Also break down by OrderType to see which order types have freight set
SELECT
    OrderType,
    COUNT(*)                                                            AS RecordCount,
    SUM(CASE WHEN Freight > 0 THEN 1 ELSE 0 END)                        AS WithFreight,
    MAX(Freight)                                                        AS MaxFreight
FROM Fact_InSalOrd_InSalPar
GROUP BY OrderType
ORDER BY RecordCount DESC;

-- ================================================================================
-- INTERPRETATION:
-- If HasFreight > 0: Freight field IS used in the source system — it's just 0 for
--   open/current orders. Once an MD order gets freight assigned in the source
--   system, it will appear here. Insalord.Freight IS the correct field.
-- If HasFreight = 0: Freight may be on a different table or calculated elsewhere.
-- ================================================================================
