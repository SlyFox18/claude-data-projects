let

    // Parameters

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

  

    // Convert to SQL-safe strings

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

  

    // SQL query with folding, aliasing, and filtering

    SQL =

    "SELECT #(lf)

        RO_BRANCH AS Branch, #(lf)

        RO_NUMBER AS WorkOrder, #(lf)

        JOB_CODE AS JobCode, #(lf)

        TYPE AS JobType, #(lf)

        Field_Repair AS FieldRepair, #(lf)

        INVOICE_NO AS InvoiceNumber, #(lf)

        INVOICE_DATE AS InvoiceDate, #(lf)

        EST_LAB_VAL AS EstLabor, #(lf)

        Act_Lab_Val AS ActLabor, #(lf)

        Inv_Lab_Val AS InvLabor, #(lf)

        est_hours AS EstHours, #(lf)

        Std_Lab_Ind AS IsStandardLabor, #(lf)

        ModifiedDate AS ModifiedDate #(lf)

    FROM wkothsub #(lf)

    WHERE ModifiedDate >= " & StartStr & " #(lf)

      AND ModifiedDate < " & EndStr,

  

    // Execute query

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in

    Source