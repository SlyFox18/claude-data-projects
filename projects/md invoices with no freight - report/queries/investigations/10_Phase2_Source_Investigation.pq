/*
============================================================================
Investigation 10: Phase 2 Source System Investigation
Purpose: Explore InvoiceInformationDetail and related source tables to
         determine feasibility of historical closed MD invoice data for
         Phase 2 of the MD Invoices With No Freight report.
Source:  dsn=EquipRDB64 (direct source system queries)
Date:    2026-03-31
============================================================================

KEY QUESTIONS:
1. What does InvoiceInformationDetail look like? What columns does it have?
2. Does invoicetype = 'E' correspond to Machine Down / Emergency orders?
3. How far back does the data go?
4. What column joins InvoiceInformationDetail to InTrans (for parts detail)?
5. Are there other source tables worth investigating?

Run each block independently in Power Query editor.
============================================================================
*/


// ============================================================================
// BLOCK 1: InvoiceInformationDetail — Column Discovery
// What columns does this view have?
// ============================================================================

let
    SQL = "SELECT TOP 1 * FROM InvoiceInformationDetail WHERE 1=0",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    ColumnNames = Table.ColumnNames(Source),
    Result = Table.FromList(ColumnNames, Splitter.SplitByNothing(), {"ColumnName"})
in
    Result


// ============================================================================
// BLOCK 2: InvoiceInformationDetail — Sample rows where invoicetype = 'E'
// Confirm E = Emergency/Machine Down and see what data is available
// ============================================================================

/*
let
    SQL = "SELECT TOP 20 * FROM InvoiceInformationDetail WHERE invoicetype = 'E' ORDER BY invoicedate DESC",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 3: InvoiceInformationDetail — Volume and date range for E orders
// How many historical MD invoices exist and how far back does data go?
// ============================================================================

/*
let
    SQL = "SELECT COUNT(*) AS RecordCount, MIN(invoicedate) AS EarliestDate, MAX(invoicedate) AS LatestDate FROM InvoiceInformationDetail WHERE invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 4: InvoiceInformationDetail — All distinct invoicetype values
// Make sure we understand all types before assuming E = MD
// ============================================================================

/*
let
    SQL = "SELECT invoicetype, COUNT(*) AS RecordCount FROM InvoiceInformationDetail GROUP BY invoicetype ORDER BY RecordCount DESC",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 5: InTrans — Check if FileNo joins to InvoiceInformationDetail
// InTrans has FileNo column — does it match the invoice number in the view?
// This is the critical join path for getting parts detail on closed invoices.
// ============================================================================

/*
let
    SQL = "SELECT TOP 5 t.FileNo, t.PART_NO, t.QTY, t.SALE_VAL, i.invoicenumber, i.invoicetype FROM InTrans t INNER JOIN InvoiceInformationDetail i ON CAST(t.File_No AS VARCHAR) = CAST(i.invoicenumber AS VARCHAR) WHERE i.invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 6: Source system table discovery — other potential candidates
// Search SYSTABLE for any invoice history or audit tables we might have missed
// ============================================================================

/*
let
    SQL = "SELECT table_name FROM SYSTABLE WHERE table_name LIKE '%invoice%' OR table_name LIKE '%insal%' OR table_name LIKE '%audit%' OR table_name LIKE '%history%' OR table_name LIKE '%hist%' ORDER BY table_name",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source
*/


// ============================================================================
// BLOCK 7: InvoiceInformationDetail — Check for freight-related columns
// Does this view already have freight information, or do we still need InTrans?
// ============================================================================

/*
let
    SQL = "SELECT TOP 5 * FROM InvoiceInformationDetail WHERE invoicetype = 'E'",
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    FreightCols = List.Select(Table.ColumnNames(Source), each Text.Contains(Text.Lower(_), "freight") or Text.Contains(Text.Lower(_), "ship")),
    FreightResult = if List.Count(FreightCols) > 0
                    then "Freight columns found: " & Text.Combine(FreightCols, ", ")
                    else "No freight columns found",
    Output = #table({"Result"}, {{FreightResult}})
in
    Output
*/
