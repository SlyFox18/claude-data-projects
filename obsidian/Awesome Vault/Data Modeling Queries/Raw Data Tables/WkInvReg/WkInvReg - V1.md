let

    // Incremental refresh range

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

  

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

  

    SQL =

    "SELECT #(lf)

        DOCUMENT_NO AS InvoiceNumber, #(lf)

        BRANCH AS Branch, #(lf)

        RO_NUMBER AS WorkOrder, #(lf)

        RO_TYPE AS ROType, #(lf)

        CHARGE_ACCT AS AccountNumber, #(lf)

        FRANCHISE AS Franchise, #(lf)

        LABOUR_COST AS LabourCost, #(lf)

        LABOUR_CHARGED AS LabourCharged, #(lf)

        INVOICE_VALUE AS InvoiceTotal, #(lf)

        WORK_DATE AS WorkDate, #(lf)

        ModifiedDate AS ModifiedDate #(lf)

    FROM WkInvReg #(lf)

    WHERE ModifiedDate >= " & StartStr & " #(lf)

      AND ModifiedDate < " & EndStr,

  

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in

    Source