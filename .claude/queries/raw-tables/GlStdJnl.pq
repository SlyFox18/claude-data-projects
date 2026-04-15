/*
============================================================================
Query: GlStdJnl (Raw)
Dataflow: df_GlStdJnl_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anyway Database (ODBC connection: EquipRDB64)
Purpose: GL journal entry lines — manual and settlement journal entries that
         post to the general ledger. Discovered during GlMaster investigation
         on 2026-04-13 as a related table reference on GlMaster.
Created: 2026-04-13 (documentation only — NOT YET DEPLOYED)
Last Modified: 2026-04-13
Output: Lakehouse table "GlStdJnl" (future)

⚠️ STATUS: PLANNED — NOT DEPLOYED
    No active project requires this table yet.
    Documented for future financial reporting use cases.
    See "Before Building" section below before deploying.

⏱️ REFRESH CHARACTERISTICS (estimated — not yet confirmed):
Refresh Schedule: TBD — likely standalone GL pipeline with GlMaster/GlTrans_Full
Refresh Strategy: TBD — depends on table size and ModifiedDate investigation
Row Count: Unknown — run investigation queries before building
Query Folding: TBD

============================================================================
🔍 DISCOVERY CONTEXT — 2026-04-13
============================================================================

Discovered as a related table reference visible in Power BI Desktop when
connecting to the GlMaster Lakehouse table. Sample data reviewed:

Sample rows (SELECT TOP 5 FROM GLSTDJNL):
REC_NO      COY  JOURNAL  BRANCH  DEPT  ACCT  SUB_ACCT  REF        VALUE         QTY  DESCRIPTION                        ENTRY_TYPE
923976      1    9866     00      00    200   1         C2224479   -17293.39     0    SETT# C2224479 /JDC MONTHLY        G
923977      1    9866     00      00    255   1         C2224479    754.42       0    SETT# C2224479 /JDC MONTHLY INT    G
923978      1    9866     00      00    200   2         082827      1160.91      null  5090E TRACTOR /JDC MONTHLY        G
923979      1    9866     00      00    200   2         082830      1319.22      null  5090E TRACTOR /JDC MONTHLY        G
829379      1    2003     00      00    200   1         C2123952   -2001760.5   null  SETT# C2123952/JDC MONTHLY SHOP   G

🎯 WHAT THIS TABLE APPEARS TO BE:
• Manual and settlement journal entries posted to GL
• Same GL account structure as GlTrans_Full (BRANCH, DEPT, ACCT, SUB_ACCT)
• Large dollar values — these are real financial transactions (not templates)
• ENTRY_TYPE = G (General journal entries)
• Descriptions suggest settlement/intercompany/floor plan entries ("SETT#", "JDC MONTHLY")
• Reversing_Journal flag indicates month-end reversing entry support
• JOURNAL number groups related journal entry lines together

📊 COLUMNS IN SOURCE (16 columns):
• REC_NO: Record number (likely unique key)
• COY: Company code (always = 1 — exclude from extract)
• JOURNAL: Journal number (groups related lines)
• BRANCH: Branch code
• DEPT: GL department
• ACCT: GL account
• SUB_ACCT: GL sub-account
• REF: Reference number/identifier
• VALUE: Dollar value of the journal line
• QTY: Quantity (0 or null for most financial entries)
• DESCRIPTION: Journal line description
• distribute_journal: Distribution flag (Y/N)
• distribute_acct: Distribution account flag (Y/N)
• Reversing_Journal: Whether this is a reversing entry (null in sample)
• ENTRY_TYPE: Entry type code (G = General)
• ACC_NO: Account number (purpose unclear from sample — null in some rows)

============================================================================
⚠️ CRITICAL — VERIFY BEFORE BUILDING
============================================================================

🔴 MOST IMPORTANT: Check for overlap with GlTrans_Full FIRST.

If GLSTDJNL entries already appear in GlTrans as posted GL transactions,
pulling this table separately would create DUPLICATE records in any financial
report that joins both. Run this investigation query before building:

-- Check if GLSTDJNL journal entries exist in GlTrans
SELECT
    COUNT(*) AS GlStdJnlRows,
    SUM(CASE WHEN g.trans_id IS NOT NULL THEN 1 ELSE 0 END) AS FoundInGlTrans,
    SUM(CASE WHEN g.trans_id IS NULL THEN 1 ELSE 0 END) AS NotInGlTrans
FROM GLSTDJNL j
LEFT JOIN GlTrans g ON j.REC_NO = g.trans_id
WHERE j.COY = 1

-- If FoundInGlTrans is high: these records ARE in GlTrans_Full already
-- If NotInGlTrans is high: these are SEPARATE transactions not in GlTrans_Full

NOTE: The join key above is a guess (REC_NO → trans_id). Verify the correct
join between these two tables before drawing conclusions.

============================================================================
🔬 INVESTIGATION QUERIES — RUN BEFORE DEPLOYMENT
============================================================================

-- 1. Table scale and date range
SELECT
    COUNT(*) AS TotalRows,
    MIN(JOURNAL) AS MinJournal,
    MAX(JOURNAL) AS MaxJournal,
    MIN(REC_NO) AS MinRecNo,
    MAX(REC_NO) AS MaxRecNo
FROM GLSTDJNL

-- 2. Entry type breakdown
SELECT
    ENTRY_TYPE,
    COUNT(*) AS RecordCount,
    SUM(VALUE) AS TotalValue
FROM GLSTDJNL
GROUP BY ENTRY_TYPE
ORDER BY RecordCount DESC

-- 3. Check for a date column (not visible in sample — may exist)
-- If no date column exists, incremental refresh is not possible
-- Full refresh would be required regardless of table size
SELECT TOP 1 * FROM GLSTDJNL

-- 4. Reversing journal breakdown
SELECT
    Reversing_Journal,
    COUNT(*) AS RecordCount
FROM GLSTDJNL
GROUP BY Reversing_Journal

============================================================================
🚀 DEPLOYMENT GUIDE (when ready)
============================================================================

Prerequisites:
  □ Overlap investigation completed (see above)
  □ Date column confirmed or ruled out
  □ Table size confirmed
  □ Active project requiring this data identified

If no date column exists → Full refresh only (similar to GlMaster)
If date column exists → Run same incremental investigation as GlTrans_Full

Suggested dataflow name: df_GlStdJnl_Raw
Suggested table name: GlStdJnl
Pipeline: Add to Pipeline_GL_Refresh after GlMaster, before GlTrans_Full
COY: Exclude (always = 1, verified in sample)

============================================================================
✅ PRODUCTION STATUS: PLANNED — NOT DEPLOYED
============================================================================

Dependencies: None (source system table)

Related Tables:
• GlTrans_Full — potential overlap — MUST verify before building
• GlMaster — joins via Branch + Department + Account + SubAccount
              for account descriptions

============================================================================
*/

// ============================================================================
// QUERY NOT YET WRITTEN — PENDING INVESTIGATION
// ============================================================================
// Complete the investigation steps above before writing the production query.
// Template structure will follow the same pattern as GlTrans_Full.pq and
// GlMaster.pq once the overlap and date column questions are resolved.
// ============================================================================
