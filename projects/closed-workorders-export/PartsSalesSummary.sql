-- PartsSalesSummary.sql
-- Purpose:  Monthly parts sales per customer, selling store, channel and sale type, Aug 2024 to
--           today, for Casey's parts-vs-inspections analysis. The small companion to the
--           PartsSales_* line files: answers "who bought how much where, each month" without
--           reading 1.5M lines.
-- Grain:    one row per Month + CustomerAccount + InvoiceName (generic accounts only) + Branch +
--           Channel + SaleType. ~127k rows in Oct 2026.
-- Output:   PartsSalesSummary.csv, rebuilt whole by the flow "Parts Sales Export - Biweekly".
--           Returns ONE row (RowTotal, Csv); the flow writes Csv.
-- Source:   same lines and matching as PartsSalesLines.sql (see its header), plus customer
--           attributes as in PartsCustomers.sql.
-- Columns:  Customer is the line's bill-to account (warranty parts sit under WARRANTIES-<store>
--           accounts; the line files carry WOCustomerAccount to re-credit them).
--           InvoiceName (upper-cased) splits Cash/Web/Sundry accounts by the name typed on the
--           invoice; blank for real customer accounts. HomeBranch = the customer's home store
--           (CustomerLookup.Territory); Branch/StoreName = the store that sold the part.
--           NetSales = sales minus credits, before tax. JDPartsSales = franchise 'D' (John Deere
--           parts); OtherSales = everything else (other brands, fees, freight, discounts).

DECLARE @Start date = '2024-08-01';

WITH lines AS (
    SELECT CONVERT(varchar(7), t.TransDatetime, 120) AS SaleMonth, t.Branch, t.RONumber AS InvoiceNumber,
           CASE h.ModuleType WHEN 'W' THEN 'Service' WHEN 'I' THEN 'Counter' WHEN 'S' THEN 'Equipment'
                ELSE COALESCE(h.ModuleType, '') END AS Channel,
           TRIM(t.CustomerNo) AS CustomerAccount, c.DisplayName,
           UPPER(TRIM(CONCAT_WS(' ', NULLIF(TRIM(h.CompanyName), ''), NULLIF(TRIM(h.FirstName), ''),
                                NULLIF(TRIM(h.LastName), '')))) AS HeaderName,
           COALESCE(t.TradeType, '') AS SaleType, t.Franchise, t.SaleValue
    FROM dbo.Silver_InTrans t
    JOIN dbo.Silver_Invoice h
      ON h.InvoiceNumber = t.RONumber
     AND h.InvoiceType IN ('I', 'C', 'S')
     AND CAST(h.InvoiceDate AS date) = CAST(t.TransDatetime AS date)
    LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(t.CustomerNo))
    WHERE t.TransDatetime >= @Start
      AND t.Type IN ('I', 'C')
),
kinds AS (
    SELECT *,
           CASE WHEN CustomerAccount = 'SUNDRY' THEN 'Sundry'
                WHEN UPPER(DisplayName) LIKE 'CASH%' THEN 'Cash'
                WHEN UPPER(DisplayName) LIKE '%ECOMMERCE%' THEN 'Web'
                WHEN UPPER(DisplayName) LIKE 'WARRANT%' THEN 'Warranty'
                WHEN UPPER(DisplayName) LIKE 'SOUTH PLAINS IMP%' OR UPPER(DisplayName) LIKE '%INTERNAL' THEN 'Internal'
                ELSE 'Customer' END AS AccountKind
    FROM lines
),
grp AS (
    SELECT SaleMonth, CustomerAccount, AccountKind,
           CASE WHEN AccountKind IN ('Cash', 'Web', 'Sundry') THEN COALESCE(HeaderName, '') ELSE '' END AS InvoiceName,
           Branch, Channel, SaleType,
           COUNT(DISTINCT InvoiceNumber) AS Invoices,
           COUNT(*) AS Lines,
           SUM(SaleValue) AS NetSales,
           SUM(CASE WHEN Franchise = 'D' THEN SaleValue ELSE 0 END) AS JDPartsSales
    FROM kinds
    GROUP BY SaleMonth, CustomerAccount, AccountKind,
             CASE WHEN AccountKind IN ('Cash', 'Web', 'Sundry') THEN COALESCE(HeaderName, '') ELSE '' END,
             Branch, Channel, SaleType
),
contact AS (
    SELECT * FROM dbo.Silver_Contact
    WHERE ContactID IN (SELECT ContactID FROM dbo.Silver_Contact GROUP BY ContactID HAVING COUNT(*) = 1)
),
cust AS (
    SELECT a.Account, c.DisplayName, c.Territory,
           TRIM(CONCAT_WS(' ', NULLIF(TRIM(ct.CompanyName), ''), NULLIF(TRIM(ct.FirstName), ''),
                          NULLIF(TRIM(ct.LastName), ''))) AS ContactName,
           UPPER(TRIM(ct.City)) AS City, UPPER(TRIM(ct.State)) AS State, TRIM(ct.PostalCode) AS Zip
    FROM (SELECT DISTINCT CustomerAccount AS Account FROM grp) a
    LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(a.Account)
    LEFT JOIN dbo.Silver_ArMaster m ON TRIM(m.AccountNumber) = a.Account
    LEFT JOIN contact ct ON ct.ContactID = m.ContactID
),
csv_rows AS (
    SELECT g.SaleMonth, g.CustomerAccount, g.InvoiceName, g.Branch, g.Channel, g.SaleType,
           CONCAT(
               g.SaleMonth, ',',
               '"', REPLACE(g.CustomerAccount, '"', '""'), '",',
               '"', REPLACE(COALESCE(cu.DisplayName, NULLIF(cu.ContactName, ''), ''), '"', '""'), '",',
               g.AccountKind, ',',
               '"', REPLACE(g.InvoiceName, '"', '""'), '",',
               '"', REPLACE(COALESCE(cu.City, ''), '"', '""'), '",',
               '"', COALESCE(cu.State, ''), '",',
               '"', COALESCE(cu.Zip, ''), '",',
               '"', COALESCE(cu.Territory, ''), '",',
               '"', g.Branch, '",',
               '"', REPLACE(COALESCE(b.City, ''), '"', '""'), '",',
               g.Channel, ',',
               '"', g.SaleType, '",',
               CAST(g.Invoices AS varchar(12)), ',',
               CAST(g.Lines AS varchar(12)), ',',
               CAST(CAST(g.NetSales AS decimal(14, 2)) AS varchar(20)), ',',
               CAST(CAST(g.JDPartsSales AS decimal(14, 2)) AS varchar(20)), ',',
               CAST(CAST(g.NetSales - g.JDPartsSales AS decimal(14, 2)) AS varchar(20))
           ) AS Line
    FROM grp g
    LEFT JOIN cust cu ON cu.Account = g.CustomerAccount
    LEFT JOIN dbo.dim_BranchLocation b ON b.BranchID = g.Branch
)
SELECT
    COUNT(*) AS RowTotal,
    CONCAT(
        'Month,CustomerAccount,CustomerName,AccountKind,InvoiceName,CustomerCity,CustomerState,CustomerZip,HomeBranch,Branch,StoreName,Channel,SaleType,Invoices,Lines,NetSales,JDPartsSales,OtherSales',
        CHAR(13), CHAR(10),
        STRING_AGG(CAST(Line AS varchar(max)), CHAR(13) + CHAR(10))
            WITHIN GROUP (ORDER BY SaleMonth, CustomerAccount, InvoiceName, Branch, Channel, SaleType),
        CHAR(13), CHAR(10)
    ) AS Csv
FROM csv_rows;
