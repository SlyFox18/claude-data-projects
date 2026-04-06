let
    // SQL query - ALL HISTORICAL DATA (no date filters)
    SQL = 
    "SELECT 
        FILE_NO AS FileNumber,
        Line_No AS LineNumber,
        BRANCH AS Branch,
        FRANCHISE AS Franchise,
        PART_NO AS PartNumber,
        ORDER_QTY AS OrderQty,
        SUPPLIED_QTY AS SuppliedQty,
        COMM_PART_QTY AS BackorderQty,
        UNIT_PRICE AS UnitPrice,
        UNIT_COST AS UnitCost,
        JOB_CODE AS JobCode,
        SALESMAN AS Salesperson,
        PURORDER_TYPE AS PurOrderType,
        Creation_Datetime AS CreationDate
    FROM InSalPar",

    // Execute it
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source