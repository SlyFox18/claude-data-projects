-- ================================================================================
-- INVESTIGATION: Weight Column - Population & Distribution
-- Purpose: Confirm pi_Weight was added, check NULL rate, value ranges
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- NOTE: Weight and PackageQty are stored as varchar - TRY_CAST to numeric
-- ================================================================================

-- Part 1: Overall population check
SELECT
    COUNT(*)                                                                AS TotalRows,
    SUM(CASE WHEN Weight IS NULL THEN 1 ELSE 0 END)                         AS NullWeight,
    SUM(CASE WHEN TRY_CAST(Weight AS FLOAT) = 0 THEN 1 ELSE 0 END)         AS ZeroWeight,
    SUM(CASE WHEN TRY_CAST(Weight AS FLOAT) > 0 THEN 1 ELSE 0 END)         AS HasWeight,
    CAST(
        SUM(CASE WHEN TRY_CAST(Weight AS FLOAT) > 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    AS DECIMAL(5,2))                                                        AS PctWithWeight,
    MIN(TRY_CAST(Weight AS FLOAT))                                          AS MinWeight,
    MAX(TRY_CAST(Weight AS FLOAT))                                          AS MaxWeight,
    AVG(TRY_CAST(Weight AS FLOAT))                                          AS AvgWeight
FROM jdis_Part_Information
WHERE Weight IS NOT NULL;

-- Part 2: Weight variation by branch for the same part number
-- If this returns rows, weight is NOT consistent across branches
SELECT
    PartNumber,
    COUNT(DISTINCT Branch)                                                  AS BranchCount,
    COUNT(DISTINCT Weight)                                                  AS UniqueWeightValues,
    MIN(TRY_CAST(Weight AS FLOAT))                                          AS MinWeight,
    MAX(TRY_CAST(Weight AS FLOAT))                                          AS MaxWeight,
    MAX(TRY_CAST(Weight AS FLOAT)) - MIN(TRY_CAST(Weight AS FLOAT))        AS WeightVariance
FROM jdis_Part_Information
WHERE Weight IS NOT NULL
  AND TRY_CAST(Weight AS FLOAT) > 0
GROUP BY PartNumber
HAVING COUNT(DISTINCT Weight) > 1
ORDER BY COUNT(DISTINCT Weight) DESC,
         MAX(TRY_CAST(Weight AS FLOAT)) - MIN(TRY_CAST(Weight AS FLOAT)) DESC;

-- If Part 2 returns 0 rows: weight is consistent across branches
--   → safe to add Weight to dim_Parts (deduplicated on PartNumber only)
-- If Part 2 returns rows: must join on Branch+PartNumber in the fact table
