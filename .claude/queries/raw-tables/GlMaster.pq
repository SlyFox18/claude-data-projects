/*
============================================================================
Query: GlMaster (Raw)
Dataflow: df_GlMaster_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

📋 METADATA:
Source: SQL Anywhere Database (ODBC connection: EquipRDB64)
Purpose: GL account master / chart of accounts — defines every GL account,
         its type, classification, groupings, and related accounts.
         Used to resolve ACCT/SUB_ACCT codes to descriptions in GL reporting.
Created: 2026-04-13
Last Modified: 2026-04-13
Output: Lakehouse table "GlMaster"

⏱️ REFRESH CHARACTERISTICS:
Refresh Schedule: Standalone pipeline (with df_GlTrans_Full_Raw — see Pipeline notes)
Average Refresh Time: < 1 minute expected (chart of accounts, small table)
Refresh Strategy: Full refresh — master/reference data changes infrequently.
                  No incremental refresh needed or warranted for a table this small.
Row Count: Small — chart of accounts typically hundreds to low thousands of rows
Query Folding: ✅ YES (full table select, no transformations at source)

🎯 BUSINESS USE CASES:
• Account Description Lookup: Resolve ACCT/SUB_ACCT codes to human-readable names
• Account Classification: AccType and Category for income statement / balance sheet
• Financial Report Hierarchies: AccountGroup1-5 for rollup structures
• Related Account Mapping: RelSalesAccount/RelCosAccount for sales-to-cost tracing
• Balance Sheet Logic: BalanceType (B = balance sheet, I = income statement)
• Debit/Credit Presentation: DrCrSwitchInd controls normal balance display

📊 DATA STRUCTURE (26 COLUMNS — COY excluded, always = 1, verified 2026-04-10)
============================================================================

Composite Primary Key:
• Branch + Department + Account + SubAccount
  (COY always = 1 across all records — excluded from extract)

Account Identity:
• Branch: Branch code ("00" = company-wide)
• Department: GL department code
• Account: GL account number
• SubAccount: GL sub-account number
• Description: Primary account description (e.g., "CASH ON HAND")
• AltDescription: Alternate description (often "Conversion Generated" for migrated records)
• ShortCode: Short reference code

Account Classification:
• AccType: Account type code (numeric in sample — may have alpha variants)
• Category: Account category code
• BalanceType: B = Balance Sheet, I = Income Statement
• Control: Control account flag (Y/N)

Account Groupings (financial report rollup hierarchy):
• AccountGroup1: Primary grouping code (sample: "101000000" — numeric-style code)
• AccountGroup2-5: Additional grouping levels (often empty — used for custom hierarchies)

Related Accounts:
• ClearSubAccount: Sub-account for clearing entries
• RelSalesAccount: Related sales GL account
• RelSalesSub: Related sales GL sub-account
• RelCosAccount: Related cost-of-sales GL account
• RelCosSub: Related cost-of-sales GL sub-account

Financial Reporting Flags:
• CashFlowCode: Cash flow statement classification (e.g., "CA" = cash activities)
• GstCategory: GST/tax category
• DrCrSwitchInd: Debit/credit switch indicator (N = normal presentation)
• RetainDocDate: Retain document date flag (Y/N)

Supplemental:
• Notes: Free-text notes on the account

============================================================================
⚠️ TYPING NOTES (based on sample data inspection 2026-04-13)
============================================================================
• All columns typed as Text — reasoning:
  - Account/SubAccount: May contain leading zeros or alpha codes in other rows
  - AccType: Sample shows "9" but may have alpha variants elsewhere
  - AccountGroup1-5: Sample shows "101000000" — large numeric-looking code,
    but typed as text to avoid precision issues and handle any alpha variants
  - RelSalesAccount/RelCosAccount/RelSalesSub/RelCosSub: Sample shows "0" —
    typed as text to match Account/SubAccount convention
  - All flag columns (Control, DrCrSwitchInd, RetainDocDate): Y/N text flags

============================================================================
*/

let
    // ========================================================================
    // SQL QUERY — GL ACCOUNT MASTER (CHART OF ACCOUNTS)
    // ========================================================================
    /*
    STRATEGY: Full table extract — GlMaster is a small reference/master table.
    No date filter or incremental refresh needed.
    COY excluded (always = 1, verified 2026-04-10).
    Composite key: BRANCH + DEPT + ACCT + SUB_ACCT
    */

    SQL =
    "SELECT
        -- ===== COMPOSITE PRIMARY KEY =====
        BRANCH              AS Branch,
        DEPT                AS Department,
        ACCT                AS Account,
        SUB_ACCT            AS SubAccount,

        -- ===== ACCOUNT IDENTITY =====
        DESCRIPTION         AS Description,
        ALT_DESC            AS AltDescription,
        SHORT_CODE          AS ShortCode,

        -- ===== ACCOUNT CLASSIFICATION =====
        ACC_TYPE            AS AccType,
        CATEGORY            AS Category,
        balance_type        AS BalanceType,
        CONTROL             AS Control,

        -- ===== ACCOUNT GROUPINGS =====
        ACCT_GROUP1         AS AccountGroup1,
        ACCT_GROUP2         AS AccountGroup2,
        ACCT_GROUP3         AS AccountGroup3,
        ACCT_GROUP4         AS AccountGroup4,
        ACCT_GROUP5         AS AccountGroup5,

        -- ===== RELATED ACCOUNTS =====
        CLEAR_SUB_ACCT      AS ClearSubAccount,
        REL_Sales_ACCT      AS RelSalesAccount,
        REL_Sales_SUB       AS RelSalesSub,
        REL_COS_ACCT        AS RelCosAccount,
        REL_COS_SUB         AS RelCosSub,

        -- ===== FINANCIAL REPORTING FLAGS =====
        Cash_Flow_Code      AS CashFlowCode,
        GST_CATEGORY        AS GstCategory,
        DrCrSwitch_Ind      AS DrCrSwitchInd,
        Retain_Doc_Date     AS RetainDocDate,

        -- ===== SUPPLEMENTAL =====
        Notes               AS Notes

    FROM GLMASTER
    ORDER BY BRANCH, DEPT, ACCT, SUB_ACCT",

    // ========================================================================
    // EXECUTE QUERY
    // ========================================================================

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to GLMASTER. Verify database connection and table availability.",

    // ========================================================================
    // TYPE TRANSFORMATIONS
    // ========================================================================
    /*
    All columns typed as Text — see typing notes in header above.
    Small table, so performance impact of text typing is negligible.
    */

    TypedColumns = Table.TransformColumnTypes(
        Source,
        {
            {"Branch",          type text},
            {"Department",      type text},
            {"Account",         type text},
            {"SubAccount",      type text},
            {"Description",     type text},
            {"AltDescription",  type text},
            {"ShortCode",       type text},
            {"AccType",         type text},
            {"Category",        type text},
            {"BalanceType",     type text},
            {"Control",         type text},
            {"AccountGroup1",   type text},
            {"AccountGroup2",   type text},
            {"AccountGroup3",   type text},
            {"AccountGroup4",   type text},
            {"AccountGroup5",   type text},
            {"ClearSubAccount", type text},
            {"RelSalesAccount", type text},
            {"RelSalesSub",     type text},
            {"RelCosAccount",   type text},
            {"RelCosSub",       type text},
            {"CashFlowCode",    type text},
            {"GstCategory",     type text},
            {"DrCrSwitchInd",   type text},
            {"RetainDocDate",   type text},
            {"Notes",           type text}
        }
    )

in
    TypedColumns

/*
============================================================================
🚀 DEPLOYMENT GUIDE — FABRIC DATAFLOW GEN2 SETUP
============================================================================

────────────────────────────────────────────────────────────────────────────
STEP 1: Create the Dataflow
────────────────────────────────────────────────────────────────────────────
1. Open LH_Master_Data workspace in Fabric
2. New → Dataflow Gen2
3. Name it: df_GlMaster_Raw

────────────────────────────────────────────────────────────────────────────
STEP 2: Add the Query
────────────────────────────────────────────────────────────────────────────
1. Blank query → Advanced Editor
2. Paste the full Power Query code from above (let block through TypedColumns)
3. Verify the query runs and returns rows
4. Rename the query to: GlMaster

⚠️ No RangeStart/RangeEnd parameters needed — this is full refresh only.

────────────────────────────────────────────────────────────────────────────
STEP 3: Set the Data Destination
────────────────────────────────────────────────────────────────────────────
1. Add data destination → Lakehouse → LH_Master_Data
2. New table, name: GlMaster
3. Toggle OFF "Use automatic settings"
4. Update method: Replace (correct for full refresh — wipes and reloads each time)
5. Schema: Fixed schema
6. Verify all 26 columns map correctly, all as Text destination type
7. Save settings

────────────────────────────────────────────────────────────────────────────
STEP 4: No Incremental Refresh — Skip That Step
────────────────────────────────────────────────────────────────────────────
• This table is small (hundreds to low thousands of rows)
• Full refresh completes in < 1 minute
• Incremental refresh adds complexity with zero benefit here
• Replace update method handles this correctly on every run

────────────────────────────────────────────────────────────────────────────
STEP 5: Add to Standalone Pipeline
────────────────────────────────────────────────────────────────────────────
• Add to the same standalone pipeline as df_GlTrans_Full_Raw
• Pipeline: Pipeline_GlTrans_Full_Refresh (to be renamed Pipeline_GL_Refresh)
• Run GlMaster FIRST — it is a dependency for any future GL reporting
  that joins GlTrans_Full to GlMaster for account descriptions
• Execution order: df_GlMaster_Raw → df_GlTrans_Full_Raw

────────────────────────────────────────────────────────────────────────────
STEP 6: Validate
────────────────────────────────────────────────────────────────────────────
After first refresh, verify in Lakehouse SQL endpoint:

  SELECT COUNT(*) AS TotalRows FROM GlMaster

  SELECT BalanceType, COUNT(*) AS RecordCount
  FROM GlMaster
  GROUP BY BalanceType
  ORDER BY RecordCount DESC
  -- Expected: "B" (balance sheet) and "I" (income statement) as main values

  SELECT TOP 10 Branch, Department, Account, SubAccount, Description, BalanceType
  FROM GlMaster
  ORDER BY Branch, Department, Account, SubAccount
  -- Spot check: descriptions should be human-readable account names

============================================================================
✅ PRODUCTION STATUS: NEW — PENDING DEPLOYMENT
============================================================================

Dependencies: None (source system master table)

Related Tables:
• GlTrans_Full — joins to GlMaster via Branch + Department + Account + SubAccount
  to resolve account codes to descriptions and classifications

Pipeline:
• Standalone GL pipeline (alongside df_GlTrans_Full_Raw)
• GlMaster refreshes first as upstream dependency
• Pipeline name TBD — suggest renaming to Pipeline_GL_Refresh once both
  dataflows are confirmed stable

============================================================================
*/
