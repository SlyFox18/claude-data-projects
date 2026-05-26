/*
============================================================================
Query: WKCDPART (Raw)
Dataflow: df_WKCDPART_Raw
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

PURPOSE: Job code → part assignments currently configured in the source system.
         This is the "official template" — what the system thinks should be on a
         work order when a given job code is used.

GRAIN: One row per JobCode × PartNumber assignment
SOURCE: WKCDPART table via ODBC (dsn=EquipRDB64)
OUTPUT TABLE: dim_WkcdPart

ROW COUNT: ~1,837 rows (small — full refresh, no incremental needed)

OUTPUT COLUMNS:
  JobCode          TEXT  — full job code (matches WkCodeFl.CODE and wkothsub.JOB_CODE)
  Franchise        TEXT  — franchise code (D = Deere, etc.)
  PartNumber       TEXT  — assigned part number
  Qty              NUM   — recommended quantity
  Value            NUM   — part value/price at time of assignment
  PartFreq         NUM   — usage frequency (largely null in source)
  CreationDate     DATE  — when this assignment was created
  ModifiedDate     DATE  — last modification date

BUSINESS USE:
  Gap analysis baseline — compare against Fact_JobCodePartFrequency to find
  parts that appear frequently in historical work orders but are NOT in this
  table. Those are candidates to add as standard template parts.

REFRESH: Full refresh daily, Phase 3 (Dimensions)
         1,837 rows — completes in seconds.

USED BY:
  Job Code Part Template Advisor report
  Gap analysis calculated table (compares historical frequency vs assigned)

NOTES:
  Part_Freq in source is 1,454/1,837 null — unreliable, ignore for analysis.
  858 unique job codes have at least one part assigned.
  Cross-reference: wkothsub has 719 of these 858 codes in 3-yr history (84%).

============================================================================
*/

let
    SQL =
    "SELECT
        JOB_CODE    AS JobCode,
        FRANCHISE   AS Franchise,
        PART_NUMBER AS PartNumber,
        QTY         AS Qty,
        value       AS Value,
        Part_Freq   AS PartFreq,
        CreationDate AS CreationDate,
        ModifiedDate AS ModifiedDate
    FROM WKCDPART",

    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    TypedTable = Table.TransformColumnTypes(Source, {
        {"JobCode",      type text},
        {"Franchise",    type text},
        {"PartNumber",   type text},
        {"Qty",          type number},
        {"Value",        type number},
        {"PartFreq",     type number},
        {"CreationDate", type datetime},
        {"ModifiedDate", type datetime}
    })

in
    TypedTable
