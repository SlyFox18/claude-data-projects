-- ================================================================================
-- INVESTIGATION 04b: Search Lakehouse for freight-related columns
-- Purpose: Find any Lakehouse table that already has a freight column
--          Also confirm insalpar has PurOrderType, insalord columns
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data) — run each block separately
-- ================================================================================

-- Block 1: Search for freight/shipping columns across ALL Lakehouse tables
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(COLUMN_NAME) LIKE '%freight%'
   OR LOWER(COLUMN_NAME) LIKE '%ship_chg%'
   OR LOWER(COLUMN_NAME) LIKE '%shipping%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- ================================================================================

-- Block 2: All columns on insalord + insalpar in the Lakehouse
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(TABLE_NAME) LIKE '%insal%'
   OR LOWER(TABLE_NAME) LIKE '%invoice%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- ================================================================================

-- Block 3: Check insalpar for PurOrderType specifically
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insalpar'
ORDER BY COLUMN_NAME;
