/*
============================================================================
Investigation 12: Phase 2 — InTrans as Historical MD Invoice Source
Purpose: Confirm InTrans is the right source for Phase 2 historical closed
         MD invoice line detail. InTrans.File_No = InvoiceInformationDetail.invoicenumber
         Join confirmed in investigation 11 Block 6.
Source:  dsn=EquipRDB64 (direct source system queries)
Date:    2026-03-31
============================================================================

KEY QUESTIONS:
1. What TYPE values exist on MD invoices in InTrans? Which to include?
2. What columns from InTrans do we actually need?
3. How many MD invoices exist in InTrans and how far back does it go?
4. Freight (3750) summary — how many closed MD invoices have/don't have freight?
5. Can we get weight from InTrans, or do we still need jdis join?

Run each block independently in Power Query editor.
============================================================================
*/


// ============================================================================
// BLOCK 1: InTrans TYPE values on MD invoices
// Understand what TYPE = 'I', 'P', etc. mean before filtering
// ============================================================================

let
    SQL = "SELECT t.TYPE, COUNT(*) AS RecordCount FROM InTrans t INNER JOIN InvoiceInformationDetail i ON CAST(t.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR) WHERE i.invoicetype = 'E' GROUP BY t.TYPE ORDER BY RecordCount DESC",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source


// ============================================================================
// BLOCK 2: InTrans column list — what is available?
// ============================================================================

/*
let
    SQL = "SELECT TOP 1 * FROM InTrans WHERE 1=0",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    ColumnNames = Table.ColumnNames(Source),
    Result = Table.FromList(ColumnNames, Splitter.SplitByNothing(), {"ColumnName"})
in
    Result
*/


// ============================================================================
// BLOCK 3: InTrans — Volume and date range for MD invoices
// How many line rows, distinct invoices, and how far back?
// ============================================================================

/*
let
    SQL = "SELECT COUNT(*) AS LineCount, COUNT(DISTINCT t.File_No) AS InvoiceCount, MIN(i.invoicedate) AS EarliestDate, MAX(i.invoicedate) AS LatestDate FROM InTrans t INNER JOIN InvoiceInformationDetail i ON CAST(t.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR) WHERE i.invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 4: Freight summary on closed MD invoices
// How many invoices have part 3750 vs no part 3750?
// Phase 2 equivalent of investigation 09 Block 1.
// ============================================================================

/*
let
    SQL = "
        SELECT
            CASE WHEN FreightExists = 1 THEN 'Has Freight' ELSE 'No Freight' END AS FreightStatus,
            COUNT(*) AS InvoiceCount
        FROM (
            SELECT
                t.File_No,
                MAX(CASE WHEN t.PART_NO = '3750' THEN 1 ELSE 0 END) AS FreightExists
            FROM InTrans t
            INNER JOIN InvoiceInformationDetail i ON CAST(t.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR)
            WHERE i.invoicetype = 'E'
            GROUP BY t.File_No
        ) AS sub
        GROUP BY FreightExists
        ORDER BY FreightExists DESC
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 5: Sample MD invoice — all lines including freight
// See a complete picture of one order with parts + 3750 freight line
// ============================================================================

/*
let
    SQL = "
        SELECT t.File_No, t.PART_NO, t.QTY, t.SALE_VAL, t.COST_VAL, t.TYPE, t.FRANCHISE, t.BRANCH, t.Trans_Datetime
        FROM InTrans t
        WHERE t.File_No = (
            SELECT TOP 1 t2.File_No
            FROM InTrans t2
            INNER JOIN InvoiceInformationDetail i ON CAST(t2.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR)
            WHERE i.invoicetype = 'E' AND t2.PART_NO = '3750'
        )
        ORDER BY t.PART_NO
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 6: Does InTrans already exist in Lakehouse with enough history?
// The Lakehouse InTrans_Incremental table uses a watermark — check if it
// goes back far enough, or if we need a separate historical pull.
// Compare date range here vs what is in the Lakehouse.
// ============================================================================

/*
let
    SQL = "SELECT MIN(Trans_Datetime) AS EarliestTrans, MAX(Trans_Datetime) AS LatestTrans, COUNT(*) AS TotalRows FROM InTrans",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/
