-- ================================================================================
-- INVESTIGATION: Where is freight data actually stored?
-- Purpose: insalord.Freight is all nulls/zeros — find the real freight column
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- NOTE: Lakehouse table is Insalord (capital I)
-- ================================================================================

-- Part 1: Confirm Insalord.Freight is really empty
SELECT
    COUNT(*)                                                        AS TotalRows,
    SUM(CASE WHEN Freight IS NULL THEN 1 ELSE 0 END)                AS NullFreight,
    SUM(CASE WHEN TRY_CAST(Freight AS FLOAT) = 0 THEN 1 ELSE 0 END) AS ZeroFreight,
    SUM(CASE WHEN TRY_CAST(Freight AS FLOAT) > 0 THEN 1 ELSE 0 END) AS HasFreight,
    MAX(TRY_CAST(Freight AS FLOAT))                                 AS MaxFreight
FROM Insalord;

-- Part 2: Search all Lakehouse tables for columns containing "freight"
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(COLUMN_NAME) LIKE '%freight%'
   OR LOWER(COLUMN_NAME) LIKE '%ship_chg%'
   OR LOWER(COLUMN_NAME) LIKE '%shipping%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Part 3: All columns on insalord-related and invoice-related Lakehouse tables
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(TABLE_NAME) LIKE '%insal%'
   OR LOWER(TABLE_NAME) LIKE '%invoice%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Part 4: All columns on insalpar specifically (confirm PurOrderType was added)
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insalpar'
ORDER BY COLUMN_NAME;
