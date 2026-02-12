# Investigation Plan: Unknown Customers in Service Invoices

## Problem Statement
- **Issue**: $1,669,280 in Unknown Customer service revenue (CustomerKey = -1)
- **Scope**: Service invoices ONLY - Parts invoices show zero unknown customers
- **Business Logic**: Service work ALWAYS has customer information (unlike walk-in parts sales)
- **Root Cause Hypothesis**: BillToAccount field in Invoice table may not contain the matching key for service invoices

## Investigation Strategy
Run these queries directly in Microsoft Fabric Lakehouse to diagnose the matching issue WITHOUT modifying any fact tables first.

---

## Query 1: Sample Unknown Customer Invoices
**Purpose**: See what BillToAccount values exist for invoices that aren't matching

```sql
-- Find service invoices that would result in Unknown Customer
SELECT TOP 100
    i.InvoiceNumber,
    i.BillToAccount,
    i.CustomerNumber,
    i.CompanyName,
    i.ModuleType,
    i.InvoiceDate,
    i.LabourSaleValue
FROM Invoice i
WHERE i.ModuleType = 'W'
  AND i.InvoiceDate >= '2022-01-01'
  AND i.LabourSaleValue > 0
  AND NOT EXISTS (
      SELECT 1 FROM dim_CustomerList c
      WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.AccountNumber AS VARCHAR)))
  )
  AND NOT EXISTS (
      SELECT 1 FROM dim_CustomerList c
      WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.CustomerNumber AS VARCHAR)))
  )
  AND NOT EXISTS (
      SELECT 1 FROM dim_CustomerList c
      WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(c.ContactID))
  )
ORDER BY i.LabourSaleValue DESC
```

---

## Query 2: BillToAccount Value Distribution
**Purpose**: Understand what format/pattern BillToAccount contains for service invoices

```sql
-- Analyze BillToAccount patterns for Service invoices
SELECT
    CASE
        WHEN TRY_CAST(BillToAccount AS INT) IS NOT NULL THEN 'Numeric'
        WHEN BillToAccount LIKE '%[A-Za-z]%' THEN 'Contains Letters'
        WHEN BillToAccount IS NULL OR BillToAccount = '' THEN 'NULL/Empty'
        ELSE 'Other'
    END AS BillToAccountType,
    COUNT(*) as InvoiceCount,
    SUM(LabourSaleValue) as TotalLabourSales
FROM Invoice
WHERE ModuleType = 'W'
  AND InvoiceDate >= '2022-01-01'
GROUP BY CASE
    WHEN TRY_CAST(BillToAccount AS INT) IS NOT NULL THEN 'Numeric'
    WHEN BillToAccount LIKE '%[A-Za-z]%' THEN 'Contains Letters'
    WHEN BillToAccount IS NULL OR BillToAccount = '' THEN 'NULL/Empty'
    ELSE 'Other'
END
ORDER BY TotalLabourSales DESC
```

---

## Query 3: Check Invoice.CustomerNumber vs BillToAccount
**Purpose**: See if CustomerNumber field has different values than BillToAccount

```sql
-- Compare BillToAccount vs CustomerNumber for service invoices
SELECT TOP 200
    InvoiceNumber,
    BillToAccount,
    CustomerNumber,
    CompanyName,
    LabourSaleValue,
    CASE WHEN BillToAccount = CustomerNumber THEN 'Same' ELSE 'Different' END as Comparison
FROM Invoice
WHERE ModuleType = 'W'
  AND InvoiceDate >= '2022-01-01'
  AND LabourSaleValue > 0
ORDER BY LabourSaleValue DESC
```

---

## Query 4: Match Rate Analysis - All Three Key Types
**Purpose**: Compare match rates using AccountNumber vs CustomerNumber vs ContactID

```sql
-- Match rate analysis for service invoices
SELECT
    'Total Service Invoices' as Category,
    COUNT(*) as InvoiceCount,
    SUM(LabourSaleValue) as TotalSales
FROM Invoice
WHERE ModuleType = 'W' AND InvoiceDate >= '2022-01-01'

UNION ALL

SELECT
    'Matched via AccountNumber' as Category,
    COUNT(*) as InvoiceCount,
    SUM(i.LabourSaleValue) as TotalSales
FROM Invoice i
INNER JOIN dim_CustomerList c ON UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.AccountNumber AS VARCHAR)))
WHERE i.ModuleType = 'W' AND i.InvoiceDate >= '2022-01-01'

UNION ALL

SELECT
    'Matched via CustomerNumber' as Category,
    COUNT(*) as InvoiceCount,
    SUM(i.LabourSaleValue) as TotalSales
FROM Invoice i
INNER JOIN dim_CustomerList c ON UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.CustomerNumber AS VARCHAR)))
WHERE i.ModuleType = 'W' AND i.InvoiceDate >= '2022-01-01'

UNION ALL

SELECT
    'Matched via ContactID' as Category,
    COUNT(*) as InvoiceCount,
    SUM(i.LabourSaleValue) as TotalSales
FROM Invoice i
INNER JOIN dim_CustomerList c ON UPPER(TRIM(i.BillToAccount)) = UPPER(TRIM(c.ContactID))
WHERE i.ModuleType = 'W' AND i.InvoiceDate >= '2022-01-01'
```

---

## Query 5: Check wkothsub/InTrans CustomerNumber
**Purpose**: See if the work order tables have better customer identifiers

```sql
-- Check if wkothsub (service work order detail) has CustomerNumber that matches better
-- NOTE: Need to verify if wkothsub or a related table has CustomerNumber field
SELECT TOP 100
    wo.Branch,
    wo.WorkOrder,
    wo.InvoiceNumber,
    i.BillToAccount as Invoice_BillToAccount,
    i.CustomerNumber as Invoice_CustomerNumber,
    i.CompanyName,
    i.LabourSaleValue
FROM Raw_wkothsub wo
INNER JOIN Invoice i ON wo.InvoiceNumber = i.InvoiceNumber AND wo.Branch = i.Branch
WHERE i.ModuleType = 'W'
  AND i.InvoiceDate >= '2024-01-01'
  AND i.LabourSaleValue > 500
ORDER BY i.LabourSaleValue DESC
```

---

## Query 6: Check InTrans_Incremental for Service Invoice Parts
**Purpose**: See if InTrans (parts transactions) has CustomerNo that matches where Invoice.BillToAccount doesn't

```sql
-- Check InTrans CustomerNo for service invoices
-- InTrans.RONumber = Invoice.InvoiceNumber for parts sold on service invoices
SELECT TOP 100
    it.RONumber as InvoiceNumber,
    it.CustomerNo as InTrans_CustomerNo,
    i.BillToAccount as Invoice_BillToAccount,
    i.CustomerNumber as Invoice_CustomerNumber,
    i.CompanyName,
    i.LabourSaleValue
FROM InTrans_Incremental it
INNER JOIN Invoice i ON it.RONumber = i.InvoiceNumber AND it.Branch = i.Branch
WHERE i.ModuleType = 'W'
  AND i.InvoiceDate >= '2024-01-01'
  AND i.LabourSaleValue > 0
ORDER BY i.LabourSaleValue DESC
```

---

## Query 7: Unmatched Invoices - Check What WOULD Match
**Purpose**: For unmatched service invoices, check if CustomerNumber from Invoice would match dim_CustomerList

```sql
-- For invoices that DON'T match via BillToAccount, would they match via Invoice.CustomerNumber?
WITH UnmatchedInvoices AS (
    SELECT
        i.InvoiceNumber,
        i.Branch,
        i.BillToAccount,
        i.CustomerNumber,
        i.CompanyName,
        i.LabourSaleValue
    FROM Invoice i
    WHERE i.ModuleType = 'W'
      AND i.InvoiceDate >= '2022-01-01'
      AND i.LabourSaleValue > 0
      -- Not matched via any current method
      AND NOT EXISTS (
          SELECT 1 FROM dim_CustomerList c
          WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.AccountNumber AS VARCHAR)))
      )
      AND NOT EXISTS (
          SELECT 1 FROM dim_CustomerList c
          WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.CustomerNumber AS VARCHAR)))
      )
      AND NOT EXISTS (
          SELECT 1 FROM dim_CustomerList c
          WHERE UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(c.ContactID))
      )
)
SELECT
    u.InvoiceNumber,
    u.BillToAccount,
    u.CustomerNumber,
    u.CompanyName,
    u.LabourSaleValue,
    c.CustomerKey,
    c.DisplayName as MatchedCustomerName,
    c.AccountNumber as MatchedAccountNumber
FROM UnmatchedInvoices u
LEFT JOIN dim_CustomerList c ON UPPER(TRIM(CAST(u.CustomerNumber AS VARCHAR))) = UPPER(TRIM(CAST(c.CustomerNumber AS VARCHAR)))
ORDER BY u.LabourSaleValue DESC
```

---

## Query 8: Compare Parts vs Service Match Rates
**Purpose**: Understand why Parts works but Service doesn't

```sql
-- Side-by-side comparison: Parts (P) vs Service (W) match rates
SELECT
    ModuleType,
    COUNT(*) as TotalInvoices,
    SUM(CASE WHEN match_found = 1 THEN 1 ELSE 0 END) as MatchedInvoices,
    SUM(CASE WHEN match_found = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as MatchRate_Pct,
    SUM(CASE WHEN match_found = 0 THEN TotalSales ELSE 0 END) as UnmatchedSales
FROM (
    SELECT
        i.InvoiceNumber,
        i.ModuleType,
        COALESCE(i.PartsSaleValue, 0) + COALESCE(i.LabourSaleValue, 0) as TotalSales,
        CASE WHEN c.CustomerKey IS NOT NULL THEN 1 ELSE 0 END as match_found
    FROM Invoice i
    LEFT JOIN dim_CustomerList c ON UPPER(TRIM(CAST(i.BillToAccount AS VARCHAR))) = UPPER(TRIM(CAST(c.AccountNumber AS VARCHAR)))
    WHERE i.InvoiceDate >= '2022-01-01'
      AND i.ModuleType IN ('P', 'W')
) sub
GROUP BY ModuleType
```

---

## Expected Findings

Based on the Inspections report pattern, I expect to find:

1. **BillToAccount for Service invoices may contain WorkOrder numbers or other identifiers** rather than customer account numbers
2. **Invoice.CustomerNumber may have the actual customer identifier** that would match dim_CustomerList.CustomerNumber
3. **InTrans_Incremental.CustomerNo** (used in Inspections report) may have the matching customer number for parts sold on service invoices

## Next Steps Based on Findings

| Finding | Action |
|---------|--------|
| BillToAccount is empty/null for service | Use Invoice.CustomerNumber as primary match key for service |
| BillToAccount contains WorkOrder# | Change matching logic for ModuleType='W' invoices |
| Invoice.CustomerNumber matches | Add Invoice.CustomerNumber to CustomerLookup or match directly |
| InTrans.CustomerNo matches | Build parts detail table from InTrans for customer identification |

---

## How to Run These Queries

1. Open Microsoft Fabric workspace
2. Navigate to the Lakehouse
3. Open SQL analytics endpoint
4. Run each query individually and analyze results
5. Document findings for each query

---

*Created: 2026-02-09*
*Purpose: Diagnose Unknown Customer issue in Customer Anatomy V2 Service data*
