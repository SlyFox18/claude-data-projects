let
  Source = Odbc.Query("dsn=EquipRDB64", 
"-- Define the parameter for including miscellaneous transactions
DECLARE @IncludeMisc INT = 1; -- Set to 1 to include, 0 to exclude

-- Create temporary table for service sales data
CREATE TABLE #ServiceSalesData (
  Account NVARCHAR(50),
  Customer NVARCHAR(255),
  Territory NVARCHAR(50),
  Class NVARCHAR(50),
  InvoiceMonth INT,
  InvoiceYear INT,
  InvoiceCount INT,
  TotalSales DECIMAL(18, 2),
  PartsSales DECIMAL(18, 2),
  LaborSales DECIMAL(18, 2),
  TotalCost DECIMAL(18, 2)
);

-- Insert service sales data into temporary table
INSERT INTO #ServiceSalesData
SELECT 
  ACC_NO AS Account,
  CASE 
    WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name 
    ELSE contact.surname + ', ' + contact.name 
  END AS Customer,
  ISNULL(ARMaster_Customer.Territory, '') AS Territory,
  ISNULL(contact.Account_Class, '') AS Class,
  MONTH(Invoice.invo_datetime) AS InvoiceMonth,
  YEAR(Invoice.invo_datetime) AS InvoiceYear,
  COUNT(DISTINCT Invoice.document_no) AS InvoiceCount,
  SUM(ISNULL(parts_sale_val, 0) + ISNULL(labour_sale_val, 0) + ISNULL(sublet_sal_val, 0) + ISNULL(other_sale_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.sale_val, 0)) ELSE 0 END AS TotalSales,
  SUM(ISNULL(parts_sale_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.sale_val, 0)) ELSE 0 END AS PartsSales,
  SUM(ISNULL(labour_sale_val, 0)) AS LaborSales,
  SUM(ISNULL(parts_cost_val, 0) + ISNULL(labour_cost_val, 0) + ISNULL(sublet_cost_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.cost_val, 0)) ELSE 0 END AS TotalCost
FROM ArMaster
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'W'
LEFT OUTER JOIN (
  SELECT type, ref_no, SUM(Sale_val) AS Sale_val, SUM(Cost_val) AS Cost_val
  FROM intrans 
  WHERE intrans.trans_datetime BETWEEN '2025-01-01' AND GETDATE()
    AND franchise IN ('ZP', 'ZS') AND type IN ('I', 'C') 
  GROUP BY type, ref_no
) AS intrans ON intrans.type = Invoice.invo_type AND intrans.ref_no = Invoice.document_no
WHERE Invoice.invo_datetime BETWEEN '2025-01-01' AND GETDATE()
GROUP BY 
  ACC_NO, contact.company_name, contact.surname, contact.name, 
  ARMaster_Customer.Territory, contact.Account_Class, 
  MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Create temporary table for PYTD service sales data
CREATE TABLE #PYTDServiceSalesData (
  Account NVARCHAR(50),
  Customer NVARCHAR(255),
  Territory NVARCHAR(50),
  Class NVARCHAR(50),
  InvoiceMonth INT,
  InvoiceYear INT,
  InvoiceCount INT,
  TotalSales DECIMAL(18, 2),
  PartsSales DECIMAL(18, 2),
  LaborSales DECIMAL(18, 2),
  TotalCost DECIMAL(18, 2)
);

-- Insert PYTD service sales data into temporary table
INSERT INTO #PYTDServiceSalesData
SELECT 
  ACC_NO AS Account,
  CASE 
    WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name 
    ELSE contact.surname + ', ' + contact.name 
  END AS Customer,
  ISNULL(ARMaster_Customer.Territory, '') AS Territory,
  ISNULL(contact.Account_Class, '') AS Class,
  MONTH(Invoice.invo_datetime) AS InvoiceMonth,
  YEAR(Invoice.invo_datetime) AS InvoiceYear,
  COUNT(DISTINCT Invoice.document_no) AS InvoiceCount,
  SUM(ISNULL(parts_sale_val, 0) + ISNULL(labour_sale_val, 0) + ISNULL(sublet_sal_val, 0) + ISNULL(other_sale_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.sale_val, 0)) ELSE 0 END AS TotalSales,
  SUM(ISNULL(parts_sale_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.sale_val, 0)) ELSE 0 END AS PartsSales,
  SUM(ISNULL(labour_sale_val, 0)) AS LaborSales,
  SUM(ISNULL(parts_cost_val, 0) + ISNULL(labour_cost_val, 0) + ISNULL(sublet_cost_val, 0)) 
    - CASE WHEN @IncludeMisc = 0 THEN SUM(ISNULL(intrans.cost_val, 0)) ELSE 0 END AS TotalCost
FROM ArMaster
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'W'
LEFT OUTER JOIN (
  SELECT type, ref_no, SUM(Sale_val) AS Sale_val, SUM(Cost_val) AS Cost_val
  FROM intrans 
  WHERE intrans.trans_datetime BETWEEN DATEADD(year, -1, '2025-01-01') AND DATEADD(year, -1, GETDATE())
    AND franchise IN ('ZP', 'ZS') AND type IN ('I', 'C') 
  GROUP BY type, ref_no
) AS intrans ON intrans.type = Invoice.invo_type AND intrans.ref_no = Invoice.document_no
WHERE Invoice.invo_datetime BETWEEN DATEADD(year, -1, '2025-01-01') AND DATEADD(year, -1, GETDATE())
GROUP BY 
  ACC_NO, contact.company_name, contact.surname, contact.name, 
  ARMaster_Customer.Territory, contact.Account_Class, 
  MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Final query to calculate YTD and PYTD values for service
SELECT 
  a.Account,
  a.Customer,
  a.Territory,
  a.Class,
  a.InvoiceMonth,
  a.InvoiceYear,
  a.InvoiceCount AS [Invoice Counts YTD],
  ISNULL(a.TotalSales, 0) AS [Sales YTD],
  ISNULL(a.PartsSales, 0) AS [Parts Sales YTD],
  ISNULL(a.LaborSales, 0) AS [Labor Sales YTD],
  ISNULL(a.TotalCost, 0) AS [Cost YTD],
  ISNULL(a.TotalSales - a.TotalCost, 0) AS [Margin YTD],
  CASE WHEN ISNULL(a.TotalSales, 0) = 0 THEN 0 ELSE ISNULL((a.TotalSales - a.TotalCost) / a.TotalSales, 0) END AS [GP % YTD],
  ISNULL(p.InvoiceCount, 0) AS [Invoice Counts PYTD],
  ISNULL(p.TotalSales, 0) AS [Sales PYTD],
  ISNULL(p.PartsSales, 0) AS [Parts Sales PYTD],
  ISNULL(p.LaborSales, 0) AS [Labor Sales PYTD],
  ISNULL(p.TotalCost, 0) AS [Cost PYTD],
  ISNULL(p.TotalSales - p.TotalCost, 0) AS [Margin PYTD],
  CASE WHEN ISNULL(p.TotalSales, 0) = 0 THEN 0 ELSE ISNULL((p.TotalSales - p.TotalCost) / p.TotalSales, 0) END AS [GP % PYTD]
FROM #ServiceSalesData a
LEFT JOIN #PYTDServiceSalesData p 
  ON a.Account = p.Account AND a.InvoiceMonth = p.InvoiceMonth
ORDER BY a.Account, a.InvoiceYear, a.InvoiceMonth;

-- Drop temporary tables
DROP TABLE #ServiceSalesData;
DROP TABLE #PYTDServiceSalesData;")
in
  Source