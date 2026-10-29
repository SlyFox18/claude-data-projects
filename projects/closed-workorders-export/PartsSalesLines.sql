-- PartsSalesLines.sql
-- Purpose:  Every parts sale/credit line for ONE calendar month, for Casey's parts-vs-inspections
--           analysis (asked 2026-10-27): customers inspected one year and not the next, whether
--           inspections drive parts sales, customers who buy parts but don't get inspections, and
--           where customers buy vs where they get service.
-- Grain:    one row per InTrans sale (Type I) or credit (Type C) line, all brands, all channels.
--           ~35k-65k lines a month.
-- Output:   PartsSales_yyyy-MM.csv. The flow "Parts Sales Export - Biweekly" runs this once per month
--           of the current year (plus last December in January), filling in the month placeholder, and
--           writes the returned Csv. The query builds the CSV text and returns ONE row
--           (LineCount, Csv) to stay far below Power Automate's 100 MB message limit.
--           The frozen years (Aug-Dec 2024, 2025) were built once by build_parts_sales_history.py,
--           the DuckDB port of this query, checked line for line against this query's 2026 output.
-- Source:   DP_Presentation SQL endpoint (Prod):
--             Silver_InTrans      (part lines; RONumber = invoice number)
--             Silver_Invoice      (invoice header: channel/ModuleType, typed customer name)
--             Silver_WkInvReg, Silver_WkRoFile  (service invoice -> work order -> WO customer)
--             CustomerLookup      (account -> display name), dim_Parts (description),
--             dim_BranchLocation  (branch -> store name)
-- Matching (checked 2026-10-27 on Aug 2024-Oct 2026, 1,516,876 lines):
--           Header = Silver_Invoice row with the same invoice number, InvoiceType I/C/S, and the
--           same date as the line: exactly one per line. Invoice numbers alone repeat across types
--           (type E records carry the same numbers ~190 days apart, with no branch).
--           Work order comes from WkInvReg by invoice number (unique there) for service invoices.
-- Columns:  Channel = invoice ModuleType: Service (work order), Counter (parts counter), Equipment.
--           CustomerAccount = the line's bill-to account (warranty parts bill to WARRANTIES-<store>).
--           WOCustomerAccount = the work order's own customer, on service lines, so warranty and
--           internal parts can be credited to the machine owner.
--           AccountKind (from the account name): Customer, Cash, Web (ECOMMERCE01), Warranty,
--           Internal, Sundry. InvoiceName = the name typed on the invoice, filled only for
--           Cash/Web/Sundry accounts (the way to tell walk-in buyers apart).
--           SaleType = InTrans TradeType code (R retail, W warranty, I internal; C, T, D as Equip
--           codes them). Quantity/LineTotal are negative on credits. UnitPrice = LineTotal / Quantity.
--           Description is the part master's (InTrans.Description is an "Inv No." note).
-- Notes:    Collation is binary (BIN2), the same ordering as the DuckDB port.

DECLARE @Start date = '{{MonthStart}}';
DECLARE @End date = DATEADD(month, 1, @Start);

WITH wir AS (
    SELECT i.InvoiceNumber, i.WorkOrder, r.AccountNumber AS WOAccount
    FROM dbo.Silver_WkInvReg i
    LEFT JOIN dbo.Silver_WkRoFile r ON r.Branch = i.Branch AND r.WorkOrder = i.WorkOrder
),
lines AS (
    SELECT CAST(t.TransDatetime AS date) AS TransDate, t.TransDatetime, t.TransId, t.Branch,
           b.City AS StoreName, t.RONumber AS InvoiceNumber,
           CASE h.ModuleType WHEN 'W' THEN 'Service' WHEN 'I' THEN 'Counter' WHEN 'S' THEN 'Equipment'
                ELSE COALESCE(h.ModuleType, '') END AS Channel,
           w.WorkOrder, TRIM(t.CustomerNo) AS CustomerAccount, c.DisplayName,
           TRIM(CONCAT_WS(' ', NULLIF(TRIM(h.CompanyName), ''), NULLIF(TRIM(h.FirstName), ''),
                          NULLIF(TRIM(h.LastName), ''))) AS HeaderName,
           w.WOAccount, t.TradeType AS SaleType, TRIM(t.JobCode) AS JobCode, t.PartNumber,
           COALESCE(p.Description, t.Description) AS Description, t.Franchise, t.Qty, t.SaleValue
    FROM dbo.Silver_InTrans t
    JOIN dbo.Silver_Invoice h
      ON h.InvoiceNumber = t.RONumber
     AND h.InvoiceType IN ('I', 'C', 'S')
     AND CAST(h.InvoiceDate AS date) = CAST(t.TransDatetime AS date)
    LEFT JOIN wir w ON h.ModuleType = 'W' AND w.InvoiceNumber = t.RONumber
    LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(t.CustomerNo))
    LEFT JOIN dbo.dim_Parts p ON p.PartNumber = t.PartNumber
    LEFT JOIN dbo.dim_BranchLocation b ON b.BranchID = t.Branch
    WHERE t.TransDatetime >= @Start AND t.TransDatetime < @End
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
csv_lines AS (
    SELECT TransDate, Branch, InvoiceNumber, TransDatetime, TransId, PartNumber,
           CONCAT(
               CONVERT(varchar(10), TransDate, 23), ',',
               '"', Branch, '",',
               '"', REPLACE(COALESCE(StoreName, ''), '"', '""'), '",',
               '"', InvoiceNumber, '",',
               Channel, ',',
               COALESCE(CAST(WorkOrder AS varchar(12)), ''), ',',
               '"', REPLACE(COALESCE(CustomerAccount, ''), '"', '""'), '",',
               AccountKind, ',',
               '"', CASE WHEN AccountKind IN ('Cash', 'Web', 'Sundry') THEN REPLACE(COALESCE(HeaderName, ''), '"', '""') ELSE '' END, '",',
               '"', COALESCE(TRIM(CAST(WOAccount AS varchar(20))), ''), '",',
               '"', COALESCE(SaleType, ''), '",',
               '"', REPLACE(COALESCE(JobCode, ''), '"', '""'), '",',
               '"', REPLACE(COALESCE(PartNumber, ''), '"', '""'), '",',
               '"', REPLACE(REPLACE(REPLACE(COALESCE(Description, ''), '"', '""'), CHAR(13), ' '), CHAR(10), ' '), '",',
               '"', COALESCE(Franchise, ''), '",',
               CAST(Qty AS varchar(20)), ',',
               CASE WHEN Qty <> 0 THEN CAST(CAST(ROUND(SaleValue / Qty, 2) AS decimal(12, 2)) AS varchar(20)) ELSE '' END, ',',
               CAST(SaleValue AS varchar(20))
           ) AS Line
    FROM kinds
)
SELECT
    COUNT(*) AS LineCount,
    CONCAT(
        'TransDate,Branch,StoreName,InvoiceNumber,Channel,WorkOrder,CustomerAccount,AccountKind,InvoiceName,WOCustomerAccount,SaleType,JobCode,PartNumber,Description,Franchise,Quantity,UnitPrice,LineTotal',
        CHAR(13), CHAR(10),
        STRING_AGG(CAST(Line AS varchar(max)), CHAR(13) + CHAR(10))
            WITHIN GROUP (ORDER BY TransDate, Branch, InvoiceNumber, TransDatetime, TransId, PartNumber),
        CHAR(13), CHAR(10)
    ) AS Csv
FROM csv_lines;
