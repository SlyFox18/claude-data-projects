let

    // Define refresh window

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

  

    // Convert to SQL format

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

  

    // SQL with clean columns and filtering

    SQL =

    "SELECT #(lf)

        REG AS Registration, #(lf)

        ACCOUNT_NO AS AccountNumber, #(lf)

        MAKE AS Make, #(lf)

        MODEL AS Model, #(lf)

        VIN_NO AS VIN, #(lf)

        ENGINE AS Engine, #(lf)

        BUILD_DATE AS BuildDate, #(lf)

        DELIVERY_DATE AS DeliveryDate, #(lf)

        ODOMETER_DATE AS OdometerDate, #(lf)

        LATEST_ODO AS Odometer, #(lf)

        NEW_OR_USED AS Status, #(lf)

        YEAR_MANUF AS Year, #(lf)

        COMPLIANCE_DATE AS ComplianceDate, #(lf)

        First_Reg AS FirstRegDate, #(lf)

        FRANCHISE AS Franchise, #(lf)

        ModifiedDate AS ModifiedDate #(lf)

    FROM wkvehfl #(lf)

    WHERE ModifiedDate >= " & StartStr & " #(lf)

      AND ModifiedDate < " & EndStr,

  

    // Execute

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in

    Source