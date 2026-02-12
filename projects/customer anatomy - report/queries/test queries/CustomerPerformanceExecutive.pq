let
  Source = Odbc.Query("dsn=EquipRDB64", "
-- Customer Performance - All Business Lines with YTD vs PYTD
-- Based on your proven Service_Data, Parts_Data, Sales_Data patterns

-- SERVICE SALES
SELECT 
    ACC_NO AS Account,
    CASE 
        WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name 
        ELSE contact.surname + ', ' + contact.name 
    END AS Customer,
    ISNULL(ARMaster_Customer.Territory, '') AS Branch,
    ISNULL(contact.Account_Class, '') AS Class,
    'Service' AS BusinessLine,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    COUNT(DISTINCT Invoice.document_no) AS InvoiceCount,
    SUM(ISNULL(parts_sale_val, 0) + ISNULL(labour_sale_val, 0) + ISNULL(sublet_sal_val, 0) + ISNULL(other_sale_val, 0)) AS TotalSales,
    SUM(ISNULL(parts_sale_val, 0)) AS PartsSales,
    SUM(ISNULL(labour_sale_val, 0)) AS LaborSales,
    SUM(ISNULL(parts_cost_val, 0) + ISNULL(labour_cost_val, 0) + ISNULL(sublet_cost_val, 0)) AS TotalCost
FROM ArMaster
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'W'
WHERE Invoice.invo_datetime BETWEEN '2024-01-01' AND GETDATE()
GROUP BY 
    ACC_NO, contact.company_name, contact.surname, contact.name, 
    ARMaster_Customer.Territory, contact.Account_Class, 
    MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime)

UNION ALL

-- PARTS SALES
SELECT 
    ACC_NO AS Account, 
    CASE WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name ELSE contact.surname + ', ' + contact.name END AS Customer,
    ISNULL(ARMaster_Customer.Territory, '') AS Branch,
    ISNULL(contact.Account_Class, '') AS Class,
    'Parts' AS BusinessLine,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    COUNT(DISTINCT Invoice.document_no) AS InvoiceCount,
    SUM(ISNULL(parts_sale_val, 0)) AS TotalSales,
    SUM(ISNULL(parts_sale_val, 0)) AS PartsSales,
    0 AS LaborSales,
    SUM(ISNULL(parts_cost_val, 0)) AS TotalCost
FROM ArMaster 
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code 
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'I'
WHERE Invoice.invo_datetime BETWEEN '2024-01-01' AND GETDATE()
GROUP BY 
    ACC_NO, contact.company_name, contact.surname, contact.name, 
    ARMaster_Customer.Territory, contact.Account_Class, 
    MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime)

UNION ALL

-- EQUIPMENT SALES
SELECT 
    ACC_NO AS Account, 
    CASE WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name ELSE contact.surname + ', ' + contact.name END AS Customer,
    ISNULL(ARMaster_Customer.Territory, '') AS Branch,
    ISNULL(contact.Account_Class, '') AS Class,
    'Sales' AS BusinessLine,
    MONTH(VhStock.SALESDATE) AS InvoiceMonth,
    YEAR(VhStock.SALESDATE) AS InvoiceYear,
    COUNT(VhStock.no) AS InvoiceCount,
    SUM(ISNULL(SALES_VALUE, 0)) AS TotalSales,
    0 AS PartsSales,
    0 AS LaborSales,
    SUM(ISNULL(retail, 0) + ISNULL(wholesale, 0) + ISNULL(predel_cost, 0) + 
        ISNULL(repair_cost, 0) + ISNULL(access_cost, 0) + ISNULL(other_cost, 0) + 
        ISNULL(rego_fees, 0) + ISNULL(lot_fees, 0) + ISNULL(stamp_duty, 0) + 
        ISNULL(transfer_fees, 0) + ISNULL(option_cost, 0) + ISNULL(paint_cost, 0) + 
        ISNULL(trim_cost, 0) + ISNULL(charge_cost, 0) + ISNULL(after_market_cost, 0) + 
        ISNULL(ovrallow, 0) + ISNULL(pre_trade_ovrallow, 0)) AS TotalCost
FROM ArMaster 
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code 
INNER JOIN VhStock ON VhStock.Owner = contact.contact_code 
INNER JOIN ARMaster_Customer ON ARMaster_Customer.contact_code = ARMaster.contact_code
WHERE VhStock.SALESDATE BETWEEN '2024-01-01' AND GETDATE()
GROUP BY 
    ACC_NO, contact.company_name, contact.surname, contact.name, 
    ARMaster_Customer.Territory, contact.Account_Class, 
    MONTH(VhStock.SALESDATE), YEAR(VhStock.SALESDATE)

ORDER BY Account, BusinessLine, InvoiceYear, InvoiceMonth
")
in
  Source