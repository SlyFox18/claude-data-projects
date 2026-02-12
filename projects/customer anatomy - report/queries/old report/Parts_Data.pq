let
  Source = Odbc.Query("dsn=EquipRDB64", "
-- Define the parameter for including miscellaneous transactions
DECLARE @IncludeMisc INT = 1; -- Set to 1 to include, 0 to exclude

-- Create temporary table for parts sales data
CREATE TABLE #PartsSalesData (
    Account NVARCHAR(50),
    Customer NVARCHAR(255),
    Territory NVARCHAR(50),
    Class NVARCHAR(50),
    InvoiceMonth INT,
    InvoiceYear INT,
    TotalSales DECIMAL(18, 2),
    TotalCost DECIMAL(18, 2),
    InvoiceCount INT
);

-- Insert parts sales data into temporary table
INSERT INTO #PartsSalesData
SELECT 
    ACC_NO AS Account, 
    CASE WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name ELSE contact.surname + ', ' + contact.name END AS Customer,
    ISNULL(ARMaster_Customer.Territory, '') AS Territory,
    ISNULL(contact.Account_Class, '') AS Class,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    SUM(ISNULL(parts_sale_val, 0)) AS TotalSales,
    SUM(ISNULL(parts_cost_val, 0)) AS TotalCost,
    COUNT(DISTINCT Invoice.document_no) AS InvoiceCount
FROM ArMaster 
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code 
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'I'
WHERE Invoice.invo_datetime BETWEEN '2025-01-01' AND GETDATE()
GROUP BY ACC_NO, contact.company_name, contact.surname, contact.name, ARMaster_Customer.Territory, contact.Account_Class, MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Create temporary table for parts sundry data
CREATE TABLE #PartsSundryData (
    Account NVARCHAR(50),
    InvoiceMonth INT,
    InvoiceYear INT,
    SundrySales DECIMAL(18, 2),
    SundryCost DECIMAL(18, 2)
);

-- Insert parts sundry data into temporary table
INSERT INTO #PartsSundryData
SELECT 
    Invoice.bill_to_Acc AS Account,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    SUM(ISNULL(intrans.Sale_val, 0)) AS SundrySales,
    SUM(ISNULL(intrans.Cost_val, 0)) AS SundryCost
FROM Invoice
LEFT OUTER JOIN (
    SELECT type, ref_no, SUM(Sale_val) AS Sale_val, SUM(Cost_val) AS Cost_val
    FROM intrans 
    WHERE intrans.trans_datetime BETWEEN '2025-01-01' AND GETDATE()
    AND franchise IN ('ZP', 'ZS') AND type IN ('I', 'C') 
    GROUP BY type, ref_no
) AS intrans ON intrans.type = Invoice.invo_type AND intrans.ref_no = Invoice.document_no
WHERE Invoice.module_type = 'I'
GROUP BY Invoice.bill_to_Acc, MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Create temporary table for PYTD parts sales data
CREATE TABLE #PYTDPartsSalesData (
    Account NVARCHAR(50),
    Customer NVARCHAR(255),
    Territory NVARCHAR(50),
    Class NVARCHAR(50),
    InvoiceMonth INT,
    InvoiceYear INT,
    TotalSales DECIMAL(18, 2),
    TotalCost DECIMAL(18, 2),
    InvoiceCount INT
);

-- Insert PYTD parts sales data into temporary table
INSERT INTO #PYTDPartsSalesData
SELECT 
    ACC_NO AS Account, 
    CASE WHEN ISNULL(contact.company_name, '') <> '' THEN contact.company_name ELSE contact.surname + ', ' + contact.name END AS Customer,
    ISNULL(ARMaster_Customer.Territory, '') AS Territory,
    ISNULL(contact.Account_Class, '') AS Class,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    SUM(ISNULL(parts_sale_val, 0)) AS TotalSales,
    SUM(ISNULL(parts_cost_val, 0)) AS TotalCost,
    COUNT(DISTINCT Invoice.document_no) AS InvoiceCount
FROM ArMaster 
INNER JOIN contact ON ARMaster.contact_code = contact.contact_code 
INNER JOIN ArMaster_Customer ON ArMaster_Customer.contact_code = ARMaster.contact_code
INNER JOIN Invoice ON Invoice.bill_to_Acc = ARMaster.Acc_No AND Invoice.module_type = 'I'
WHERE Invoice.invo_datetime BETWEEN DATEADD(year, -1, '2025-01-01') AND DATEADD(year, -1, GETDATE())
GROUP BY ACC_NO, contact.company_name, contact.surname, contact.name, ARMaster_Customer.Territory, contact.Account_Class, MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Create temporary table for PYTD parts sundry data
CREATE TABLE #PYTDPartsSundryData (
    Account NVARCHAR(50),
    InvoiceMonth INT,
    InvoiceYear INT,
    SundrySales DECIMAL(18, 2),
    SundryCost DECIMAL(18, 2)
);

-- Insert PYTD parts sundry data into temporary table
INSERT INTO #PYTDPartsSundryData
SELECT 
    Invoice.bill_to_Acc AS Account,
    MONTH(Invoice.invo_datetime) AS InvoiceMonth,
    YEAR(Invoice.invo_datetime) AS InvoiceYear,
    SUM(ISNULL(intrans.Sale_val, 0)) AS SundrySales,
    SUM(ISNULL(intrans.Cost_val, 0)) AS SundryCost
FROM Invoice
LEFT OUTER JOIN (
    SELECT type, ref_no, SUM(Sale_val) AS Sale_val, SUM(Cost_val) AS Cost_val
    FROM intrans 
    WHERE intrans.trans_datetime BETWEEN DATEADD(year, -1, '2025-01-01') AND DATEADD(year, -1, GETDATE())
    AND franchise IN ('ZP', 'ZS') AND type IN ('I', 'C') 
    GROUP BY type, ref_no
) AS intrans ON intrans.type = Invoice.invo_type AND intrans.ref_no = Invoice.document_no
WHERE Invoice.module_type = 'I'
GROUP BY Invoice.bill_to_Acc, MONTH(Invoice.invo_datetime), YEAR(Invoice.invo_datetime);

-- Final query to calculate YTD and PYTD values for parts
SELECT 
    a.Account, 
    a.Customer,
    a.Territory, 
    a.Class,
    a.InvoiceMonth,
    a.InvoiceYear,
    a.InvoiceCount AS [Invoice Counts YTD],
    ISNULL(a.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundrySales, 0) ELSE 0 END, 0) AS [Sales YTD],
    ISNULL(a.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundryCost, 0) ELSE 0 END, 0) AS [Cost YTD],
    ISNULL(a.TotalSales - a.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundrySales, 0) - ISNULL(s.SundryCost, 0) ELSE 0 END, 0) AS [Margin YTD],
    CASE WHEN ISNULL(a.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundrySales, 0) ELSE 0 END, 0) = 0 THEN 0 ELSE ISNULL((a.TotalSales - a.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundrySales, 0) - ISNULL(s.SundryCost, 0) ELSE 0 END) / (a.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(s.SundrySales, 0) ELSE 0 END), 0) END AS [GP % YTD],
    p.InvoiceCount AS [Invoice Counts PYTD],
    ISNULL(p.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundrySales, 0) ELSE 0 END, 0) AS [Sales PYTD],
    ISNULL(p.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundryCost, 0) ELSE 0 END, 0) AS [Cost PYTD],
    ISNULL(p.TotalSales - p.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundrySales, 0) - ISNULL(ps.SundryCost, 0) ELSE 0 END, 0) AS [Margin PYTD],
    CASE WHEN ISNULL(p.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundrySales, 0) ELSE 0 END, 0) = 0 THEN 0 ELSE ISNULL((p.TotalSales - p.TotalCost - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundrySales, 0) - ISNULL(ps.SundryCost, 0) ELSE 0 END) / (p.TotalSales - CASE WHEN @IncludeMisc = 0 THEN ISNULL(ps.SundrySales, 0) ELSE 0 END), 0) END AS [GP % PYTD]
FROM #PartsSalesData a
LEFT JOIN #PartsSundryData s ON a.Account = s.Account AND a.InvoiceMonth = s.InvoiceMonth AND a.InvoiceYear = s.InvoiceYear
LEFT JOIN #PYTDPartsSalesData p ON a.Account = p.Account AND a.InvoiceMonth = p.InvoiceMonth
LEFT JOIN #PYTDPartsSundryData ps ON p.Account = ps.Account AND p.InvoiceMonth = ps.InvoiceMonth AND p.InvoiceYear = ps.InvoiceYear
ORDER BY a.Account, a.InvoiceYear, a.InvoiceMonth;

-- Drop temporary tables
DROP TABLE #PartsSalesData;
DROP TABLE #PartsSundryData;
DROP TABLE #PYTDPartsSalesData;
DROP TABLE #PYTDPartsSundryData;
")
in
  Source