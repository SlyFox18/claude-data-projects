/*
============================================================================
Query: SPI Corparate Stocking — SPI Corparate Stocking.xlsx
Type: Excel Power Query (Advanced Editor) — Corp Parts Excel Reports library
Source: SharePoint file "Source Data/Franchise D - Zero Stock Company-Wide
        Demand.xlsx", written by build_report.py (this folder)
============================================================================

PURPOSE:
Loads the company-wide zero-stock reorder-candidate list (Franchise D parts
with zero on-hand and zero on-order at every branch, but demand at 3+
branches). This query does NOT compute anything — the logic lives in
build_report.py, which reads Fabric via DuckDB and writes the source file.
See README.md in this folder for why it can't be a live ODBC query.

IMPORTANT — WHAT "REFRESH" DOES:
Refreshing this workbook only re-reads the source file. The data is only as
fresh as the last time build_report.py was run. (Source file sat unchanged
from 2026-09-15 to 2026-10-07 because nobody re-ran the script after the
workbooks were split — that was the "not refreshing" problem.)

NOTES:
  - Finds the file by exact name + a Text.Contains on "Corp Parts Excel
    Reports" in the folder path (deliberately not an exact folder match, so
    moving it into the Source Data subfolder needed no query change).
  - Each user's refresh authenticates to SharePoint as themselves — don't
    restrict the Source Data folder's permissions or their refresh breaks.
  - Recorded from the live workbook 2026-10-07.
============================================================================
*/

let
    Source = SharePoint.Files("https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite", [ApiVersion = 15]),
    Filtered = Table.SelectRows(Source, each [Name] = "Franchise D - Zero Stock Company-Wide Demand.xlsx" and Text.Contains([Folder Path], "Corp Parts Excel Reports")),
    Workbook = Excel.Workbook(Filtered{0}[Content], null, true),
    Data = Workbook{[Item="Zero Stock Company-Wide",Kind="Sheet"]}[Data],
    PromotedHeaders = Table.PromoteHeaders(Data, [PromoteAllScalars=true]),
    ChangedType = Table.TransformColumnTypes(PromotedHeaders,{
        {"PartNumber", type text}, {"Description", type text}, {"Cost", type number},
        {"Source", type text}, {"SLC", type text}, {"CommodityCode", type text},
        {"DealerGroupCode", type text}, {"OnOrder", Int64.Type}, {"OnHandQty", Int64.Type},
        {"TotalDemand", Int64.Type}, {"LocationCount", Int64.Type}})
in
    ChangedType
