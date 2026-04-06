-- ================================================================================
-- INVESTIGATION 07: MD Orders — Find Freight Part Number
-- Purpose: Look at actual 'E' (Emergency/MD) orders in insalpar to identify
--          what part numbers appear — specifically looking for a freight part
--          (suspected: 3750 or 4750) that represents freight as a line item
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- ================================================================================

-- Block 1: Sample of MD orders — show ALL line items so we can see the pattern
-- Look for a part number that looks like a freight/shipping charge
SELECT TOP 200
    p.FileNumber,
    p.Branch,
    p.LineNumber,
    p.PartNumber,
    p.OrderQty,
    p.UnitPrice,
    p.UnitPrice * p.OrderQty   AS LineTotal,
    p.UnitCost,
    p.PurOrderType,
    o.CustomerNumber,
    o.OrderDate
FROM insalpar p
JOIN Insalord o ON p.FileNumber = o.FileNumber
WHERE p.PurOrderType = 'E'
ORDER BY p.FileNumber, p.LineNumber;

-- ================================================================================

-- Block 2: What part numbers appear on MD orders?
-- Frequency breakdown — the freight part will likely have qty=1 and a dollar amount
SELECT
    p.PartNumber,
    COUNT(*)                        AS TimesOrdered,
    AVG(p.UnitPrice)                AS AvgUnitPrice,
    MIN(p.UnitPrice)                AS MinUnitPrice,
    MAX(p.UnitPrice)                AS MaxUnitPrice,
    AVG(p.OrderQty)                 AS AvgQty
FROM insalpar p
WHERE p.PurOrderType = 'E'
GROUP BY p.PartNumber
ORDER BY TimesOrdered DESC;

-- ================================================================================

-- Block 3: Specifically check for part 3750 and 4750
SELECT
    p.FileNumber,
    p.PartNumber,
    p.OrderQty,
    p.UnitPrice,
    p.PurOrderType,
    o.OrderDate,
    o.Branch
FROM insalpar p
JOIN Insalord o ON p.FileNumber = o.FileNumber
WHERE p.PartNumber IN ('3750', '4750', '3750.0', '4750.0')
ORDER BY p.FileNumber;

-- ================================================================================
-- INTERPRETATION:
-- If a part number (3750, 4750, or other) appears on many MD orders with varying
-- unit prices and qty=1, it is almost certainly the freight line item.
-- The UnitPrice on that line IS the freight charge for that order.
--
-- This changes the fact table design:
--   Freight = UnitPrice WHERE PartNumber = [freight part number]
--   rather than Insalord.Freight
-- ================================================================================
