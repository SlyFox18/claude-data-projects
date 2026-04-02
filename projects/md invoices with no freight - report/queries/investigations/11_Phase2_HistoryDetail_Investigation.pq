/*
============================================================================
Investigation 11: Phase 2 — InvoiceHistoryDetail & InvoiceSalesDetail
Purpose: Explore the two most promising source tables for historical closed
         MD invoice line detail (Phase 2 of MD Invoices With No Freight).
Source:  dsn=EquipRDB64 (direct source system queries)
Date:    2026-03-31
============================================================================

KEY QUESTIONS:
1. What columns does InvoiceHistoryDetail have?
2. Does it have part numbers, quantities, prices? Does it have part 3750?
3. Does invoicenumber join to InvoiceInformationDetail.invoicenumber?
4. What does InvoiceSalesDetail look like?
5. Fix Block 5 from investigation 10 — InTrans join using File_No (with underscore)

Run each block independently in Power Query editor.
============================================================================
*/


// ============================================================================
// BLOCK 1: InvoiceHistoryDetail — Column Discovery
// ============================================================================

let
    SQL = "SELECT TOP 1 * FROM InvoiceHistoryDetail WHERE 1=0",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    ColumnNames = Table.ColumnNames(Source),
    Result = Table.FromList(ColumnNames, Splitter.SplitByNothing(), {"ColumnName"})
in
    Result


// ============================================================================
// BLOCK 2: InvoiceHistoryDetail — Sample rows for E-type invoices
// Join to InvoiceInformationDetail to filter to MD orders only
// ============================================================================

/*
let
    SQL = "SELECT TOP 20 h.* FROM InvoiceHistoryDetail h INNER JOIN InvoiceInformationDetail i ON h.invoicenumber = i.invoicenumber WHERE i.invoicetype = 'E' ORDER BY i.invoicedate DESC",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 3: InvoiceHistoryDetail — Does part 3750 appear?
// This is the key question — if 3750 is in here, Phase 2 has a clean data path
// ============================================================================

/*
let
    SQL = "SELECT TOP 20 h.* FROM InvoiceHistoryDetail h INNER JOIN InvoiceInformationDetail i ON h.invoicenumber = i.invoicenumber WHERE i.invoicetype = 'E' AND h.partnumber = '3750' ORDER BY i.invoicedate DESC",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 4: InvoiceHistoryDetail — Volume for E-type invoices
// How many line item rows exist for historical MD invoices?
// ============================================================================

/*
let
    SQL = "SELECT COUNT(*) AS LineCount, COUNT(DISTINCT h.invoicenumber) AS InvoiceCount, MIN(i.invoicedate) AS EarliestDate, MAX(i.invoicedate) AS LatestDate FROM InvoiceHistoryDetail h INNER JOIN InvoiceInformationDetail i ON h.invoicenumber = i.invoicenumber WHERE i.invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 5: InvoiceSalesDetail — Column Discovery
// Compare to InvoiceHistoryDetail — which is better for our purpose?
// ============================================================================

/*
let
    SQL = "SELECT TOP 1 * FROM InvoiceSalesDetail WHERE 1=0",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    ColumnNames = Table.ColumnNames(Source),
    Result = Table.FromList(ColumnNames, Splitter.SplitByNothing(), {"ColumnName"})
in
    Result
*/


// ============================================================================
// BLOCK 6: InTrans join fix — use File_No (underscore) not FileNo
// Retry the join from investigation 10 Block 5 with correct column name
// ============================================================================

/*
let
    SQL = "SELECT TOP 5 t.File_No, t.PART_NO, t.QTY, t.SALE_VAL, t.TYPE, i.invoicenumber, i.invoicetype FROM InTrans t INNER JOIN InvoiceInformationDetail i ON CAST(t.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR) WHERE i.invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 7: Freight summary on historical MD invoices via InvoiceHistoryDetail
// How many closed MD invoices have part 3750? How many don't?
// This is the Phase 2 version of investigation 09 Block 1.
// ============================================================================

/*
let
    SQL = "
        SELECT
            FreightExists,
            COUNT(*) AS InvoiceCount
        FROM (
            SELECT
                i.invoicenumber,
                MAX(CASE WHEN h.partnumber = '3750' THEN 1 ELSE 0 END) AS FreightExists
            FROM InvoiceInformationDetail i
            INNER JOIN InvoiceHistoryDetail h ON h.invoicenumber = i.invoicenumber
            WHERE i.invoicetype = 'E'
            GROUP BY i.invoicenumber
        ) AS sub
        GROUP BY FreightExists
        ORDER BY FreightExists
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/
