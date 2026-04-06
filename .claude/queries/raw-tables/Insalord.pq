let
    // SQL query - ALL HISTORICAL DATA (no date filters)
    SQL = 
    "SELECT 
        FILE_NO AS FileNumber,
        BRANCH AS Branch,
        CUST_ORD_NO AS CustomerOrderNumber,
        TAX_NO AS TaxNumber,
        TYPE AS OrderType,
        FREIGHT AS Freight,
        SALESMAN AS Salesperson,
        ORD_DATE AS OrderDate,
        Created_On AS CreatedDate,
        deposit AS Deposit,
        CUSTOMER_NO AS CustomerNumber,
        VEHICLE_NO AS VehicleNumber,
        SPECIAL_INST AS SpecialInstructions,
        RO_BRANCH AS ROBranch,
        RO_NUMBER AS RONumber,
        NOTE AS Note,
        auth_id AS AuthID,
        auth_value AS AuthValue,
        REC_CONTROL AS RecControl
    FROM insalord",

    // Load query
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source