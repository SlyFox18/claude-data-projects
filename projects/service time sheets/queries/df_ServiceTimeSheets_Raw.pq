// ============================================================================
// df_ServiceTimeSheets_Raw
// Purpose : Read all submitted service time sheet .xlsx workbooks from
//           SharePoint, expand every technician tab, and normalize each
//           RO entry row into a single flat table.
// Grain   : One row per technician per RO per pay period
// Source  : SharePoint – SouthPlainsImplement-ServicePayroll / Service Time Sheets /
// Output  : LH_Master_Data.service_time_sheets
// Notes   : Column layout varies by tech (mileage and shop/field flags).
//           Layout is auto-detected from the column 13 header in row 7.
//           Standard (no mileage, no shop/field) : 14 cols
//           Mileage only                          : 15 cols  (col 15 = Mileage)
//           Shop/Field only                       : 15 cols  (cols 13-14 = Shop/Field, 15 = After)
//           Shop/Field + Mileage                  : 16 cols
// ============================================================================

let
    // ── 1. Connect to SharePoint ──────────────────────────────────────────────
    Source = SharePoint.Files(
        "https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ServicePayroll",
        [ApiVersion = 15]
    ),

    // ── 2. Filter to submitted .xlsx files only ───────────────────────────────
    //   Exclude: _Template subfolders, Excel temp lock files (~$...)
    SubmittedFiles = Table.SelectRows(Source, each
        Text.Contains([Folder Path], "Service Time Sheets") and
        Text.EndsWith([Name], ".xlsx") and
        not Text.StartsWith([Name], "~$") and
        not Text.Contains([Folder Path], "_Template")
    ),

    // ── 3. Extract location from the folder name ──────────────────────────────
    //   Folder Path: .../Service Time Sheets/Lorenzo/  →  "Lorenzo"
    WithLocation = Table.AddColumn(SubmittedFiles, "Location", each
        let
            parts = List.Select(Text.Split([Folder Path], "/"), each _ <> "")
        in
            List.Last(parts),
        type text
    ),

    // ── 4. Open each workbook (raw — no header promotion) ────────────────────
    //   Headers live at row 7; we handle them manually per-sheet below.
    WithWorkbook = Table.AddColumn(WithLocation, "Workbook", each
        Excel.Workbook([Content], null, true)
    ),

    // ── 5. Expand sheet list ──────────────────────────────────────────────────
    ExpandedSheets = Table.ExpandTableColumn(
        WithWorkbook, "Workbook",
        {"Name", "Data", "Hidden", "Kind"},
        {"SheetName", "SheetData", "IsHidden", "SheetKind"}
    ),

    // ── 6. Keep only visible technician sheets ────────────────────────────────
    //   Drop: _PayrollDates, _TechLookup (hidden system sheets)
    //         TEMPLATE tab (not a submitted tech)
    TechSheets = Table.SelectRows(ExpandedSheets, each
        [SheetKind] = "Sheet" and
        ([IsHidden] = false or [IsHidden] = null) and
        not Text.StartsWith([SheetName], "_") and
        not Text.StartsWith(Text.Upper([SheetName]), "TEMPLATE")
    ),

    // ── 7. Process each tech sheet into a normalized row set ──────────────────
    //
    //   Template cell layout (Excel row → Power Query 0-based index):
    //     Row 2 (idx 1): Col B = TechName,  Col M (13) = Location
    //     Row 3 (idx 2): Col B = TechNum,   Col M (13) = PayPeriod label
    //     Row 4 (idx 3): Col B = TechLevel, Col M (13) = PayStart date
    //     Row 5 (idx 4):                    Col M (13) = PayEnd date
    //     Row 7 (idx 6): column headers
    //     Rows 8-41 (idx 7-40): RO entry data (34 rows)
    //
    ProcessedSheets = Table.AddColumn(TechSheets, "Processed", each
        let
            d = [SheetData],

            // Helper: safely read a single cell value
            getCell = (rowIdx as number, colKey as text) =>
                let
                    row = try d{rowIdx} otherwise null
                in
                    if row = null then null
                    else try Record.Field(row, colKey) otherwise null,

            // — Extract tech and pay period metadata ———————————————————————————
            // Excel.Workbook used range starts at row 2 (row 1 is empty),
            // so index 0 = Excel row 2, index 1 = row 3, etc.
            metaTechName  = getCell(0, "Column2"),
            metaTechNum   = getCell(1, "Column2"),
            metaTechLevel = getCell(2, "Column2"),
            metaPayPeriod = getCell(1, "Column13"),
            metaPayStart  = getCell(2, "Column13"),
            metaPayEnd    = getCell(3, "Column13"),

            // — Detect column layout from the row-7 column header ——————————————
            //   Col 13 header values:
            //     Shop/Field layout → "SHOP" & LF & "HRS"        → starts with "shop"
            //     Standard layout   → "CURRENT DRAW/..." text     → starts with "current"
            col13Value  = getCell(5, "Column13"),
            col13Header = Text.Lower(Text.Replace(
                if col13Value = null then "" else Text.From(col13Value),
                "#(lf)", " "
            )),
            isShopField = Text.StartsWith(col13Header, "shop"),
            totalCols   = List.Count(Table.ColumnNames(d)),
            hasMileage  = if isShopField then totalCols >= 16 else totalCols >= 15,

            // — Column rename map: fixed columns (always present) —————————————
            fixedRenames = {
                {"Column1",  "CustomerName"},
                {"Column2",  "Model"},
                {"Column3",  "RONumber"},
                {"Column4",  "PctComplete"},
                {"Column5",  "Draw1Date"},
                {"Column6",  "Draw1Hrs"},
                {"Column7",  "Draw2Date"},
                {"Column8",  "Draw2Hrs"},
                {"Column9",  "Draw3Date"},
                {"Column10", "Draw3Hrs"},
                {"Column11", "FinalDrawDate"},
                {"Column12", "FinalDrawHrs"}
            },

            // — Column rename map: variable columns (layout-dependent) ————————
            varRenames =
                if   isShopField and hasMileage then {{"Column13","ShopHrs"},{"Column14","FieldHrs"},{"Column15","AfterHours"},{"Column16","Mileage"}}
                else if isShopField             then {{"Column13","ShopHrs"},{"Column14","FieldHrs"},{"Column15","AfterHours"}}
                else if hasMileage              then {{"Column13","CurrentDrawHrs"},{"Column14","AfterHours"},{"Column15","Mileage"}}
                else                                 {{"Column13","CurrentDrawHrs"},{"Column14","AfterHours"}},

            allRenames = fixedRenames & varRenames,

            // — Extract data rows: skip header block (rows 1-7 = PQ indices 0-5) ——
            //   No fixed row count — managers may insert rows beyond the original 34.
            //   The RONumber filter below drops the totals/signature rows at the bottom.
            rawData  = Table.Skip(d, 6),
            renamed  = Table.RenameColumns(rawData, allRenames, MissingField.Ignore),

            // — Normalize to a fixed schema across all layouts ————————————————
            //   MissingField.UseNull adds a null column for any column in the
            //   list that the current layout does not have.
            normalized = Table.SelectColumns(renamed, {
                "CustomerName", "Model", "RONumber", "PctComplete",
                "Draw1Date", "Draw1Hrs", "Draw2Date", "Draw2Hrs",
                "Draw3Date", "Draw3Hrs", "FinalDrawDate", "FinalDrawHrs",
                "CurrentDrawHrs", "ShopHrs", "FieldHrs", "AfterHours", "Mileage"
            }, MissingField.UseNull),

            // — Attach tech + pay period metadata to every row ————————————————
            withMeta = Table.AddColumn(
                Table.AddColumn(
                    Table.AddColumn(
                        Table.AddColumn(
                            Table.AddColumn(
                                Table.AddColumn(normalized,
                                    "TechName",  each metaTechName),
                                "TechNum",   each metaTechNum),
                            "TechLevel", each metaTechLevel),
                        "PayPeriod", each metaPayPeriod),
                    "PayStart",  each metaPayStart),
                "PayEnd", each metaPayEnd),

            // — Drop blank rows (RO# not entered) —————————————————————————————
            filtered = Table.SelectRows(withMeta, each
                [RONumber] <> null and [RONumber] <> "" and [RONumber] <> 0
            )
        in
            filtered
    ),

    // ── 8. Drop sheets that produced zero data rows ───────────────────────────
    NonEmpty = Table.SelectRows(ProcessedSheets, each
        [Processed] <> null and Table.RowCount([Processed]) > 0
    ),

    // ── 9. Expand all processed rows into the flat table ─────────────────────
    Expanded = Table.ExpandTableColumn(NonEmpty, "Processed", {
        "CustomerName", "Model", "RONumber", "PctComplete",
        "Draw1Date", "Draw1Hrs", "Draw2Date", "Draw2Hrs",
        "Draw3Date", "Draw3Hrs", "FinalDrawDate", "FinalDrawHrs",
        "CurrentDrawHrs", "ShopHrs", "FieldHrs", "AfterHours", "Mileage",
        "TechName", "TechNum", "TechLevel",
        "PayPeriod", "PayStart", "PayEnd"
    }),

    // ── 10. Select and rename final output columns ────────────────────────────
    Selected = Table.SelectColumns(Expanded, {
        "Name", "Location", "SheetName",
        "TechName", "TechNum", "TechLevel",
        "PayPeriod", "PayStart", "PayEnd",
        "CustomerName", "Model", "RONumber", "PctComplete",
        "Draw1Date", "Draw1Hrs", "Draw2Date", "Draw2Hrs",
        "Draw3Date", "Draw3Hrs", "FinalDrawDate", "FinalDrawHrs",
        "CurrentDrawHrs", "ShopHrs", "FieldHrs", "AfterHours", "Mileage"
    }),

    FinalColumns = Table.RenameColumns(Selected, {
        {"Name",      "SourceFile"},
        {"SheetName", "TechNameFromTab"}
    }),

    // ── 11. Add load timestamp ────────────────────────────────────────────────
    WithTimestamp = Table.AddColumn(FinalColumns, "LoadTimestamp",
        each DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), type datetime),

    // ── 12. Set final column types ────────────────────────────────────────────
    //   Text columns use hard type casts (no ambiguity).
    //   Numeric and date columns use try/otherwise null — real submissions
    //   may contain typos ("1..85"), blanks, or Excel errors in those cells.
    TypedText = Table.TransformColumnTypes(WithTimestamp, {
        {"SourceFile",      type text},
        {"Location",        type text},
        {"TechNameFromTab", type text},
        {"TechName",        type text},
        {"TechNum",         type text},
        {"TechLevel",       type text},
        {"PayPeriod",       type text},
        {"CustomerName",    type text},
        {"Model",           type text}
    }),

    TypedNumbers = Table.TransformColumns(TypedText, {
        {"PctComplete",   each try Number.From(_) otherwise null, type number},
        {"RONumber",      each try Number.From(_) otherwise null, type number},
        {"Draw1Hrs",      each try Number.From(_) otherwise null, type number},
        {"Draw2Hrs",      each try Number.From(_) otherwise null, type number},
        {"Draw3Hrs",      each try Number.From(_) otherwise null, type number},
        {"FinalDrawHrs",  each try Number.From(_) otherwise null, type number},
        {"CurrentDrawHrs",each try Number.From(_) otherwise null, type number},
        {"ShopHrs",       each try Number.From(_) otherwise null, type number},
        {"FieldHrs",      each try Number.From(_) otherwise null, type number},
        {"AfterHours",    each try Number.From(_) otherwise null, type number},
        {"Mileage",       each try Number.From(_) otherwise null, type number}
    }),

    Typed = Table.TransformColumns(TypedNumbers, {
        {"PayStart",      each try Date.From(_) otherwise null, type date},
        {"PayEnd",        each try Date.From(_) otherwise null, type date},
        {"Draw1Date",     each try Date.From(_) otherwise null, type date},
        {"Draw2Date",     each try Date.From(_) otherwise null, type date},
        {"Draw3Date",     each try Date.From(_) otherwise null, type date},
        {"FinalDrawDate", each try Date.From(_) otherwise null, type date}
    })

in
    Typed
