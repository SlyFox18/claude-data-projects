/*
============================================================================
Query: SPI - Pieces In Set - Filtered — SPI-Pieces In Set.xlsx
Type: Excel Power Query (Advanced Editor) — Corp Parts Excel Reports library
Source: the workbook's own "SPI___Pieces_In_Set" table (output of the
        "SPI - Pieces In Set" query), via Excel.CurrentWorkbook()
============================================================================

PURPOSE:
A second tab showing only the SPI Pieces In Set rows with 3 months of
supply or less. "Months of Supply" is NOT produced by the main query — it's
an Excel formula column added to the SPI___Pieces_In_Set table in the
workbook, which is why this reads the table back from the workbook rather
than from ODBC. (Confirmed 2026-10-07 from the workbook's table definition:
Months of Supply = IFERROR(Stock Position / (Sales Qty / 'Coverage &
Stock'!B5), ""), where Stock Position = Bin Qty + On Order Qty.)

NOTES:
  - Refresh order matters: refresh "SPI - Pieces In Set" first, then this
    (Data > Refresh All handles both, in dependency order).
  - Rows where Months of Supply isn't a number (the IFERROR returns "" when
    Sales Qty is 0) are dropped by the "is number" check.
  - If the Months of Supply formula column is renamed or removed in the
    workbook, this query breaks.
  - Recorded from the live workbook 2026-10-07.
============================================================================
*/

let
    Source = Excel.CurrentWorkbook(){[Name="SPI___Pieces_In_Set"]}[Content],
    Filtered = Table.SelectRows(Source, each ([Months of Supply] is number) and [Months of Supply] <= 3)
in
    Filtered
