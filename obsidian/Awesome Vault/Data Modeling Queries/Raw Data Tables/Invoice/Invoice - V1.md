let

    // Define 3-year lookback period

    RangeStart = #datetime(2022, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

  

    // Convert to SQL string format

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

  

    // Build SQL query with module_type added

    SQL =

    "SELECT #(lf)

        invo_type AS InvoiceType, #(lf)

        module_type AS ModuleType, #(lf)

        document_no AS InvoiceNumber, #(lf)

        ro_number AS WorkOrderNumber, #(lf)

        Branch AS Branch, #(lf)

        invo_datetime AS InvoiceDate, #(lf)

        customer_no AS CustomerNumber, #(lf)

        cust_ord_no AS CustomerOrderNumber, #(lf)

        bill_to_acc AS BillToAccount, #(lf)

        stock_no AS StockNumber, #(lf)

        vehicle_no AS VehicleNumber, #(lf)

        company_name AS CompanyName, #(lf)

        surname AS LastName, #(lf)

        name AS FirstName, #(lf)

        parts_sale_val AS PartsSaleValue, #(lf)

        parts_cost_val AS PartsCostValue, #(lf)

        labour_sale_val AS LabourSaleValue, #(lf)

        labour_cost_val AS LabourCostValue, #(lf)

        sublet_sal_val AS SubletSaleValue, #(lf)

        sublet_cost_val AS SubletCostValue, #(lf)

        other_sale_val AS OtherSaleValue, #(lf)

        gst AS GST, #(lf)

        cancel_date AS CancelDate, #(lf)

        paid_cash AS PaidCash, #(lf)

        paid_credit_card AS PaidCreditCard, #(lf)

        paid_cheque AS PaidCheque, #(lf)

        Payment_Method AS PaymentMethod, #(lf)

        Last_Update_TS AS ModifiedDate #(lf)

    FROM Invoice #(lf)

    WHERE invo_datetime >= " & StartStr & " #(lf)

      AND invo_datetime < " & EndStr & " #(lf)

      AND document_no IS NOT NULL #(lf)

      AND document_no <> ''",

  

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in

    Source