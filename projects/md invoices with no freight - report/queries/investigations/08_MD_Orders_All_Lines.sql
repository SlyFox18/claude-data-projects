-- ================================================================================
-- INVESTIGATION 08: MD Orders — ALL line items (not just PurOrderType = 'E')
-- Purpose: The PurOrderType='E' filter in query 07 showed line number gaps,
--          meaning some lines on MD orders have a DIFFERENT PurOrderType.
--          The freight line item may be on those missing lines (NULL or other type).
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- ================================================================================

-- Block 1: ALL lines for a sample of known MD orders — no PurOrderType filter
-- Using orders from Block 1 results that had visible line number gaps
SELECT
    p.FileNumber,
    p.Branch,
    p.LineNumber,
    p.PartNumber,
    p.OrderQty,
    p.UnitPrice,
    p.UnitPrice * p.OrderQty    AS LineTotal,
    p.UnitCost,
    p.PurOrderType,
    p.JobCode
FROM insalpar p
WHERE p.FileNumber IN (1324174, 1362395, 1432662, 1407466, 1429459)
ORDER BY p.FileNumber, p.LineNumber;

-- ================================================================================

-- Block 2: On orders that have at least one 'E' line, show the NON-'E' lines
-- These are the lines the first query missed — look for a freight part here
SELECT
    p.FileNumber,
    p.LineNumber,
    p.PartNumber,
    p.OrderQty,
    p.UnitPrice,
    p.UnitCost,
    p.PurOrderType,
    p.JobCode
FROM insalpar p
WHERE p.FileNumber IN (
    SELECT DISTINCT FileNumber
    FROM insalpar
    WHERE PurOrderType = 'E'
)
AND (p.PurOrderType <> 'E' OR p.PurOrderType IS NULL)
ORDER BY p.FileNumber, p.LineNumber;

-- ================================================================================

-- Block 3: Frequency of part numbers on the non-'E' lines of MD orders
-- The freight part number will stand out — appears often, qty=1, variable price
SELECT
    p.PartNumber,
    p.PurOrderType,
    COUNT(*)                    AS TimesOrdered,
    AVG(p.UnitPrice)            AS AvgUnitPrice,
    MIN(p.UnitPrice)            AS MinUnitPrice,
    MAX(p.UnitPrice)            AS MaxUnitPrice,
    AVG(p.OrderQty)             AS AvgQty
FROM insalpar p
WHERE p.FileNumber IN (
    SELECT DISTINCT FileNumber
    FROM insalpar
    WHERE PurOrderType = 'E'
)
AND (p.PurOrderType <> 'E' OR p.PurOrderType IS NULL)
GROUP BY p.PartNumber, p.PurOrderType
ORDER BY TimesOrdered DESC;
