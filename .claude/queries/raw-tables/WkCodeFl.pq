/*
============================================================================
Query: WkCodeFl (Raw)
Dataflow: df_WkCodeFl_Raw
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

PURPOSE: Job code master file — defines every job code in the system, links
         branch/model-specific variants back to a canonical factory code, and
         provides human-readable descriptions.

GRAIN: One row per full job code variant (CODE)
       Multiple rows share the same FACTORY_CODE (one canonical → many variants)
SOURCE: WkCodeFl table via ODBC (dsn=EquipRDB64)
OUTPUT TABLE: dim_JobCodes

ROW COUNT: ~558,300 rows
           Use FACTORY_CODE for canonical grouping (deduplication in DAX/reports)

OUTPUT COLUMNS:
  JobCode          TEXT  — full branch/model-specific code (e.g. /10-020030-F-0000101)
                           joins to: wkothsub.JOB_CODE, WKCDPART.JOB_CODE
  FactoryCode      TEXT  — canonical base code (e.g. /10-020030)
                           use this to GROUP variants and eliminate "duplicates"
  Description      TEXT  — human-readable job description
  Branch           TEXT  — branch identifier this variant applies to (can be alphanumeric, e.g. "93C")
  EstHours         NUM   — estimated labor hours for this job
  SaleMTDQty       NUM   — month-to-date usage count
  SaleYTDQty       NUM   — year-to-date usage count
  Make             TEXT  — equipment make (e.g. JOHN DEERE)
  Model            TEXT  — equipment model (e.g. 8330)
  WorkCategory     TEXT  — job work category
  ServiceType      TEXT  — service type indicator
  CreationDate     DATE  — record creation date
  ModifiedDate     DATE  — last modification (used for incremental refresh)

BUSINESS USE:
  1. Bridges full job codes to their canonical FactoryCode for grouping
  2. Provides Description for display in reports
  3. Enables deduplication — /10-020030-F-0000101 through -0000121 are all
     "ENGINE ROCKER ARM COVER GASKET REPLACE" (same FactoryCode = /10-020030)
  4. Used in gap analysis to group historical frequency data by canonical code

REFRESH: Incremental via ModifiedDate (2023+ scope), Phase 3 (Dimensions)
         Estimated: 2-4 min

USED BY:
  Job Code Part Template Advisor report
  Gap analysis (bridge between Fact_JobCodePartFrequency and dim_WkcdPart)

NOTES:
  FACTORY_CODE can be null for custom/legacy job codes not in the structured
  format — these are typically generic codes (GEN REPAIR 1, /FIELD SERVICE)
  that won't benefit from part templates. Filter WHERE FactoryCode IS NOT NULL
  to focus on structured, templateable job codes.

  The 558K rows reflect one row per branch × model variant. The number of
  distinct FactoryCode values (canonical job types) is much smaller.

============================================================================
*/

let
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd   = DateTime.LocalNow(),

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr   = "'" & DateTime.ToText(RangeEnd,   "yyyy-MM-dd HH:mm:ss") & "'",

    SQL =
    "SELECT
        CODE         AS JobCode,
        FACTORY_CODE AS FactoryCode,
        DESCRIPTION  AS Description,
        PART_BRANCH  AS Branch,
        EST_HOURS    AS EstHours,
        SALE_MTD_QTY AS SaleMTDQty,
        SALE_YTD_QTY AS SaleYTDQty,
        Make         AS Make,
        Model        AS Model,
        Work_Cat     AS WorkCategory,
        SERVICE_TYPE AS ServiceType,
        CreationDate AS CreationDate,
        ModifiedDate AS ModifiedDate
    FROM WkCodeFl
    WHERE ModifiedDate >= " & StartStr & "
      AND ModifiedDate < " & EndStr,

    Source = Odbc.Query("dsn=EquipRDB64", SQL),

    TypedTable = Table.TransformColumnTypes(Source, {
        {"JobCode",      type text},
        {"FactoryCode",  type text},
        {"Description",  type text},
        {"Branch",       type text},
        {"EstHours",     type number},
        {"SaleMTDQty",   type number},
        {"SaleYTDQty",   type number},
        {"Make",         type text},
        {"Model",        type text},
        {"WorkCategory", type text},
        {"ServiceType",  type text},
        {"CreationDate", type datetime},
        {"ModifiedDate", type datetime}
    })

in
    TypedTable
