-- ================================================================================
-- INVESTIGATION: PurOrderType Value Distribution
-- Purpose: Confirm 'E' (Emergency/Machine Down) exists and understand all values
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- ================================================================================

SELECT
    PurOrderType,
    COUNT(*) AS RecordCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS PctOfTotal
FROM insalpar
GROUP BY PurOrderType
ORDER BY RecordCount DESC;

-- Expected: Should see 'E' in the results if MD orders exist
-- If PurOrderType is all NULL, the column was added but source data may not
-- use this field for current open orders
