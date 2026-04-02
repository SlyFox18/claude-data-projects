-- ================================================================================
-- INVESTIGATION: Is pi_Weight per-unit or per-package?
-- Purpose: Determine correct TotalLineWeight formula
-- Run at: Lakehouse SQL Endpoint (LH_Master_Data)
-- NOTE: Weight and PackageQty are stored as varchar - TRY_CAST to numeric
-- ================================================================================

SELECT TOP 100
    PartNumber,
    Description,
    TRY_CAST(PackageQty AS INT)                         AS PackageQty,
    TRY_CAST(Weight AS FLOAT)                           AS Weight,
    CASE
        WHEN TRY_CAST(PackageQty AS INT) > 0
        THEN TRY_CAST(Weight AS FLOAT) / TRY_CAST(PackageQty AS INT)
        ELSE TRY_CAST(Weight AS FLOAT)
    END                                                 AS WeightIfPerPackage,
    TRY_CAST(Weight AS FLOAT)                           AS WeightIfPerUnit
FROM jdis_Part_Information
WHERE TRY_CAST(PackageQty AS INT) > 1
  AND Weight IS NOT NULL
  AND TRY_CAST(Weight AS FLOAT) > 0
ORDER BY TRY_CAST(PackageQty AS INT) DESC,
         TRY_CAST(Weight AS FLOAT) DESC;

-- HOW TO INTERPRET:
-- Pick a few known parts (ask stakeholder or check source system)
-- If a single bolt weighs ~0.1 lbs and PackageQty=100, then:
--   Weight = 10 (total box weight)  → Weight is PER PACKAGE → use Weight/PackageQty
--   Weight = 0.1 (per bolt)         → Weight is PER UNIT   → use Weight directly
--
-- FORMULA OPTIONS:
--   Per-unit:    TotalLineWeight = Weight * OrderQty
--   Per-package: TotalLineWeight = (Weight / PackageQty) * OrderQty
