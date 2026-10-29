-- PartsCustomers.sql
-- Purpose:  One row per account in the parts sales files, with the customer's name, kind, location
--           and home store, for Casey's analysis. Join the PartsSales_* line files to it on
--           CustomerAccount (or WOCustomerAccount), and ClosedWorkOrders.csv on CustomerAccount.
-- Grain:    one row per account that bought parts since 2024-08-01, or owned a work order whose
--           part lines are in the files (WOCustomerAccount). ~17.5k accounts in Oct 2026.
-- Output:   PartsCustomers.csv, rebuilt whole by the flow "Parts Sales Export - Biweekly".
--           Returns ONE row (RowTotal, Csv); the flow writes Csv.
-- Source:   Silver_InTrans + Silver_Invoice (same matching as PartsSalesLines.sql),
--           Silver_WkInvReg/Silver_WkRoFile (WO customer), CustomerLookup (name, Territory = home
--           store), Silver_ArMaster -> Silver_Contact (city/state/ZIP; contacts whose ContactID
--           repeats are left blank rather than picking one), dim_BranchLocation (store name).
-- Columns:  CustomerName = CustomerLookup name, else the AR contact's name, else blank.
--           AccountKind uses the same rules as the line files. PartsNetSales / PartsInvoices /
--           First/LastPartsSale cover the account's own bill-to lines since 2024-08-01 (blank
--           for an account that only appears as a work order's customer).

DECLARE @Start date = '2024-08-01';

WITH lines AS (
    SELECT TRIM(t.CustomerNo) AS CustomerAccount, t.RONumber AS InvoiceNumber,
           CAST(t.TransDatetime AS date) AS TransDate, t.SaleValue, h.ModuleType
    FROM dbo.Silver_InTrans t
    JOIN dbo.Silver_Invoice h
      ON h.InvoiceNumber = t.RONumber
     AND h.InvoiceType IN ('I', 'C', 'S')
     AND CAST(h.InvoiceDate AS date) = CAST(t.TransDatetime AS date)
    WHERE t.TransDatetime >= @Start
      AND t.Type IN ('I', 'C')
),
own AS (
    SELECT CustomerAccount AS Account, SUM(SaleValue) AS NetSales, COUNT(DISTINCT InvoiceNumber) AS Invoices,
           MIN(TransDate) AS FirstSale, MAX(TransDate) AS LastSale
    FROM lines GROUP BY CustomerAccount
),
wo_accts AS (
    SELECT DISTINCT TRIM(CAST(r.AccountNumber AS varchar(20))) AS Account
    FROM (SELECT DISTINCT InvoiceNumber FROM lines WHERE ModuleType = 'W') l
    JOIN dbo.Silver_WkInvReg i ON i.InvoiceNumber = l.InvoiceNumber
    JOIN dbo.Silver_WkRoFile r ON r.Branch = i.Branch AND r.WorkOrder = i.WorkOrder
    WHERE r.AccountNumber IS NOT NULL
),
accts AS (
    SELECT Account FROM own
    UNION
    SELECT Account FROM wo_accts
),
contact AS (
    SELECT * FROM dbo.Silver_Contact
    WHERE ContactID IN (SELECT ContactID FROM dbo.Silver_Contact GROUP BY ContactID HAVING COUNT(*) = 1)
),
cust AS (
    SELECT a.Account, c.DisplayName, c.Territory,
           TRIM(CONCAT_WS(' ', NULLIF(TRIM(ct.CompanyName), ''), NULLIF(TRIM(ct.FirstName), ''),
                          NULLIF(TRIM(ct.LastName), ''))) AS ContactName,
           UPPER(TRIM(ct.City)) AS City, UPPER(TRIM(ct.State)) AS State, TRIM(ct.PostalCode) AS Zip,
           o.NetSales, o.Invoices, o.FirstSale, o.LastSale
    FROM accts a
    LEFT JOIN own o ON o.Account = a.Account
    LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(a.Account)
    LEFT JOIN dbo.Silver_ArMaster m ON TRIM(m.AccountNumber) = a.Account
    LEFT JOIN contact ct ON ct.ContactID = m.ContactID
),
csv_rows AS (
    SELECT cu.Account,
           CONCAT(
               '"', REPLACE(cu.Account, '"', '""'), '",',
               '"', REPLACE(COALESCE(cu.DisplayName, NULLIF(cu.ContactName, ''), ''), '"', '""'), '",',
               CASE WHEN cu.Account = 'SUNDRY' THEN 'Sundry'
                    WHEN UPPER(cu.DisplayName) LIKE 'CASH%' THEN 'Cash'
                    WHEN UPPER(cu.DisplayName) LIKE '%ECOMMERCE%' THEN 'Web'
                    WHEN UPPER(cu.DisplayName) LIKE 'WARRANT%' THEN 'Warranty'
                    WHEN UPPER(cu.DisplayName) LIKE 'SOUTH PLAINS IMP%' OR UPPER(cu.DisplayName) LIKE '%INTERNAL' THEN 'Internal'
                    ELSE 'Customer' END, ',',
               '"', REPLACE(COALESCE(cu.City, ''), '"', '""'), '",',
               '"', COALESCE(cu.State, ''), '",',
               '"', COALESCE(cu.Zip, ''), '",',
               '"', COALESCE(cu.Territory, ''), '",',
               '"', REPLACE(COALESCE(b.City, ''), '"', '""'), '",',
               COALESCE(CONVERT(varchar(10), cu.FirstSale, 23), ''), ',',
               COALESCE(CONVERT(varchar(10), cu.LastSale, 23), ''), ',',
               COALESCE(CAST(cu.Invoices AS varchar(12)), ''), ',',
               COALESCE(CAST(CAST(cu.NetSales AS decimal(14, 2)) AS varchar(20)), '')
           ) AS Line
    FROM cust cu
    LEFT JOIN dbo.dim_BranchLocation b ON b.BranchID = cu.Territory
)
SELECT
    COUNT(*) AS RowTotal,
    CONCAT(
        'CustomerAccount,CustomerName,AccountKind,CustomerCity,CustomerState,CustomerZip,HomeBranch,HomeStore,FirstPartsSale,LastPartsSale,PartsInvoices,PartsNetSales',
        CHAR(13), CHAR(10),
        STRING_AGG(CAST(Line AS varchar(max)), CHAR(13) + CHAR(10)) WITHIN GROUP (ORDER BY Account),
        CHAR(13), CHAR(10)
    ) AS Csv
FROM csv_rows;
