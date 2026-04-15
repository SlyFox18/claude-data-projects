/*
============================================================================
Query: BankList (Raw)
Dataflow: df_BankList_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: Bank receipts and payments register — records all cash receipts,
         deposits, and payments processed through branch banking locations.
         Discovered during GlMaster investigation on 2026-04-13 as a related
         table reference on GlMaster.
Created: 2026-04-13 (documentation only — NOT YET DEPLOYED)
Last Modified: 2026-04-13
Output: Lakehouse table "BankList" (future)

⚠️ STATUS: PLANNED — NOT DEPLOYED
    No active project requires this table yet.
    Documented for future financial/cash reporting use cases.
    Run investigation queries before deploying.

⏱️ REFRESH CHARACTERISTICS (estimated — not yet confirmed):
Refresh Schedule: TBD — likely standalone GL pipeline
Refresh Strategy: TBD — table appears transactional, likely large.
                  Incremental refresh probable — run investigation first.
Row Count: Unknown — run investigation queries before building
Query Folding: TBD

============================================================================
🔍 DISCOVERY CONTEXT — 2026-04-13
============================================================================

Discovered as a related table reference visible in Power BI Desktop when
connecting to the GlMaster Lakehouse table. Sample data reviewed:

Sample rows (SELECT TOP 5 FROM BankList):
Trans_ref  TYPE  PAYER                    BRANCH  AMOUNT   BANK_LOCATION  BANK_ACCT  BANK_SUB_ACCT  trans_date
1910236    C     CASH BIG SPRING CUSTOMER  null    20.02    CASH8          102        10             4/8/2026
1909953    C     CRUZ MENDOZA              null    8.28     P4             102        10             4/7/2026
1911255    D     SMITH & SONS CONSRT       null    663.55   P11            102        10             4/10/2026
1911336    Q     LARRY WILSON FARMS        null    132.21   P95            102        10             4/10/2026
1908920    C     CASH, LORENZO             null    114.36   CASH91         102        10             4/6/2026

🎯 WHAT THIS TABLE APPEARS TO BE:
• Bank receipts and payments register
• Captures all cash transactions processed at branch banking locations
• TYPE codes: C = Cash receipt, D = Deposit/payment, Q = Check
• BANK_LOCATION identifies the physical drawer/bank (CASH8, P4, P11, P95, CASH91)
  — these appear to be branch-level cash drawer identifiers
• Full GL coding on the bank side (BANK_COY, BANK_DEPT, BANK_BRANCH, BANK_ACCT, BANK_SUB_ACCT)
• PAYER = customer name making the payment
• trans_date is a datetime column — good candidate for incremental refresh partition key

📊 COLUMNS IN SOURCE (21 columns):
• Trans_ref: Transaction reference number (likely unique key)
• TYPE: Transaction type (C=Cash, D=Deposit/Debit, Q=Check)
• PAYER: Customer/payer name
• Doc_ref: Document reference
• BRANCH: Branch code (null in sample — may be encoded in BANK_LOCATION)
• BANK: Bank identifier (null in sample)
• AMOUNT: Payment/receipt amount
• BANK_LOCATION: Physical bank drawer or location code (CASH8, P4, P95, etc.)
• BANK_COY: Bank GL company code
• BANK_DEPT: Bank GL department
• BANK_BRANCH: Bank GL branch
• BANK_ACCT: Bank GL account number
• BANK_SUB_ACCT: Bank GL sub-account
• transfer_no: Transfer number
• acc_no: Account number (customer account reference)
• receipt_type: Receipt type code
• trans_date: Transaction date (DATETIME — candidate for incremental refresh)
• seq_no: Sequence number
• cheque_type: Check type (null in sample)
• receipt_no: Receipt number
• DOC_DATE: Document date (null in sample)

============================================================================
🔬 INVESTIGATION QUERIES — RUN BEFORE DEPLOYMENT
============================================================================

-- 1. Table scale and date range
SELECT
    COUNT(*) AS TotalRows,
    MIN(trans_date) AS EarliestDate,
    MAX(trans_date) AS LatestDate
FROM BankList

-- 2. Transaction type breakdown
SELECT
    TYPE,
    COUNT(*) AS RecordCount,
    SUM(AMOUNT) AS TotalAmount
FROM BankList
GROUP BY TYPE
ORDER BY RecordCount DESC

-- 3. Date column reliability (for incremental refresh decision)
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN trans_date IS NULL THEN 1 ELSE 0 END) AS NullTransDate,
    SUM(CASE WHEN DOC_DATE IS NULL THEN 1 ELSE 0 END) AS NullDocDate
FROM BankList

-- 4. Rows per year (to understand growth rate and history depth)
SELECT
    YEAR(trans_date) AS TransYear,
    COUNT(*) AS RecordCount,
    SUM(AMOUNT) AS TotalAmount
FROM BankList
WHERE trans_date IS NOT NULL
GROUP BY YEAR(trans_date)
ORDER BY TransYear

-- 5. Branch/location breakdown (understand geographic coverage)
SELECT
    BANK_LOCATION,
    COUNT(*) AS RecordCount
FROM BankList
GROUP BY BANK_LOCATION
ORDER BY RecordCount DESC

============================================================================
🚀 DEPLOYMENT GUIDE (when ready)
============================================================================

Prerequisites:
  □ Table size confirmed (investigation query 1)
  □ Date column reliability confirmed (investigation query 3)
  □ History depth and growth rate understood (investigation query 4)
  □ Active project requiring this data identified

If table is small (< 500K rows) → Full refresh, no incremental needed
If table is large (> 500K rows) → Follow same incremental refresh process
  as GlTrans_Full (RangeStart/RangeEnd parameters, partition by trans_date,
  determine hot window based on modification lag investigation)

Suggested dataflow name: df_BankList_Raw
Suggested table name: BankList
Pipeline: Add to Pipeline_GL_Refresh
COY-equivalent: BANK_COY (always = 1 expected — verify before excluding)

============================================================================
✅ PRODUCTION STATUS: PLANNED — NOT DEPLOYED
============================================================================

Dependencies: None (source system table)

Related Tables:
• GlMaster — joins via BANK_DEPT + BANK_ACCT + BANK_SUB_ACCT
              for account descriptions on the bank GL side
• GlTrans_Full — bank receipts likely post GL entries that appear in GlTrans_Full

============================================================================
*/

// ============================================================================
// QUERY NOT YET WRITTEN — PENDING INVESTIGATION
// ============================================================================
// Complete the investigation steps above before writing the production query.
// Template structure will follow the same pattern as GlTrans_Full.pq once
// table size and date column questions are resolved.
// ============================================================================
