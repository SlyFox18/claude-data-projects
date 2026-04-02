-- ================================================================================
-- INVESTIGATION 09: Part 3750 — Freight Line Item Summary
-- Purpose: Confirm 3750 is the freight part. Count how many MD orders have
--          a 3750 line vs no 3750 line. Understand multi-line freight orders.
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- ================================================================================

-- Block 1: How many distinct MD orders (FileNumbers with PurOrderType='E')
--          have vs don't have a 3750 freight line?
SELECT
    FreightStatus,
    COUNT(DISTINCT FileNumber)          AS OrderCount
FROM (
    SELECT
        e.FileNumber,
        CASE
            WHEN f.FileNumber IS NOT NULL AND SUM(f.FreightAmt) > 0
                THEN 'Has Freight'
            WHEN f.FileNumber IS NOT NULL AND SUM(f.FreightAmt) = 0
                THEN 'Freight Line Exists (Amount = 0)'
            ELSE 'No Freight'
        END                             AS FreightStatus
    FROM (
        SELECT DISTINCT FileNumber FROM insalpar WHERE PurOrderType = 'E'
    ) e
    LEFT JOIN (
        SELECT FileNumber, UnitPrice AS FreightAmt
        FROM insalpar WHERE PartNumber = '3750'
    ) f ON e.FileNumber = f.FileNumber
    GROUP BY e.FileNumber, f.FileNumber
) x
GROUP BY FreightStatus;

-- ================================================================================

-- Block 2: For orders with multiple 3750 lines — how common is this?
SELECT
    LineCount,
    COUNT(*)        AS OrdersWithThisMany
FROM (
    SELECT FileNumber, COUNT(*) AS LineCount
    FROM insalpar
    WHERE PartNumber = '3750'
      AND FileNumber IN (SELECT DISTINCT FileNumber FROM insalpar WHERE PurOrderType = 'E')
    GROUP BY FileNumber
) x
GROUP BY LineCount
ORDER BY LineCount;

-- ================================================================================

-- Block 3: Total freight per MD order (sum of all 3750 lines)
-- Shows the actual freight amounts being charged
SELECT TOP 50
    e.FileNumber,
    o.Branch,
    o.OrderDate,
    COUNT(DISTINCT ep.LineNumber)               AS PartLineCount,
    SUM(ep.UnitPrice * ep.OrderQty)             AS TotalPartsValue,
    ISNULL(SUM(f.UnitPrice), 0)                 AS TotalFreightCharged,
    COUNT(f.LineNumber)                         AS FreightLineCount
FROM (SELECT DISTINCT FileNumber FROM insalpar WHERE PurOrderType = 'E') e
JOIN Insalord o ON e.FileNumber = o.FileNumber
JOIN insalpar ep ON e.FileNumber = ep.FileNumber AND ep.PurOrderType = 'E'
LEFT JOIN insalpar f ON e.FileNumber = f.FileNumber AND f.PartNumber = '3750'
GROUP BY e.FileNumber, o.Branch, o.OrderDate
ORDER BY o.OrderDate DESC;
