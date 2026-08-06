/*
============================================================================
Query: Raw_PriceUpdate_History
Dataflow: df_Raw_PriceUpdate_History
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parses JD PRICEUPDATE_*.TXT files landed by
Harvest-PriceUpdateFiles.ps1 into OneLake Files/PriceUpdate_Landing/New,
and appends parsed rows to Raw_PriceUpdate_History. Source data for future
parts-pricing trend/margin analysis. See
docs/superpowers/specs/2026-08-06-jd-price-update-ingestion-design.md.

GRAIN: One row per Branch + PartNumber + EffectiveDate + SourceFileName
(raw event log -- NOT deduplicated across branches or files. The same
part+date can legitimately appear in multiple branches' files -- that's an
assortment signal, not a duplicate. See design spec for why the natural key
for future price-trend analysis is PartNumber + EffectiveDate, not
Branch + PartNumber + EffectiveDate.)

SOURCE: OneLake Lakehouse Files -- LH_Master_Data / Files /
PriceUpdate_Landing / New (folder connector, configured via the Dataflow
Gen2 "Get Data > Lakehouse > Files" wizard -- the wizard-generated step
becomes `Source` below; replace the placeholder name with whatever the
wizard actually names it).

REFRESH: Append-only, driven by a Fabric Pipeline (dataflow refresh, then
on success only, a pipeline activity clears New/). No hard dependency on
the main daily refresh pipeline's timing -- see design spec Open Items.

DESTINATION LOAD SETTING: APPEND, not Replace. New/ only ever contains
files not yet successfully ingested (a Fabric Pipeline step clears New/
after this dataflow succeeds -- see the implementation plan), so every
refresh's rows are genuinely new rows.

DO NOT filter/dedupe by PartNumber+EffectiveDate here -- that decision
belongs to the future analysis layer, not this raw ingestion layer.

`category` is passed through as-is; mapping it to dim_Parts'
CommodityCode/SLC classifications is an analysis-phase concern.

DEFENSE-IN-DEPTH NOTE (filename date parsing): SourceFileDate below is
built with #date(), which throws a hard, unrecoverable step-level error on
an invalid calendar date (e.g. Feb 30) -- unlike PowerShell's forgiving
Get-Date. This is safe here specifically because
Harvest-PriceUpdateFiles.ps1 already validates the filename's date with
.NET TryParseExact (rejects shape-valid-but-calendar-impossible dates like
PRICEUPDATE_02_30_2026_1.TXT) and quarantines anything that fails, before
a file is ever copied into New/. Do not remove that harvest-side check
without adding an equivalent guard here.

DEFENSE-IN-DEPTH NOTE (missing source columns): the SelectColumns step
below (MissingField.UseNull) makes a file with a genuinely missing source
column produce nulls for that column rather than aborting the whole
refresh. Table.ExpandTableColumn has no missingField parameter of its own,
so without this normalization step a single malformed row would throw a
step-level "column ... wasn't found" error and fail the entire batch --
contradicting the design spec's Error Handling section, which requires a
missing column to degrade to null rather than block the day's whole batch.
In practice Harvest-PriceUpdateFiles.ps1's header check (Task 3) already
requires an exact match against all 19 expected column names before a file
reaches New/, so this path is currently a belt-and-suspenders safeguard
rather than a reachable one -- kept anyway because it directly implements
what this spec's Error Handling section asks for at the parsing layer, and
because it's what protects a future backfill of older files (2018+, header
stability unconfirmed) if the harvest-side check is ever loosened to admit
a subset-of-columns header.
============================================================================
*/

let
    // Placeholder name -- replace with whatever the Dataflow Gen2 "Get Data
    // > Lakehouse > Files" wizard actually names this step when pointed at
    // PriceUpdate_Landing/New. It produces a table with columns including
    // [Content] (binary) and [Name] (text) plus other file-system metadata.
    Source = LakehouseFilesFolder_PriceUpdateLandingNew,

    // Defensive filter -- the harvest script only ever lands valid,
    // header-checked PRICEUPDATE_*.TXT files here, but this costs nothing.
    FilterToPriceUpdateFiles = Table.SelectRows(Source, each
        Text.StartsWith([Name], "PRICEUPDATE_") and Text.EndsWith(Text.Upper([Name]), ".TXT")
    ),

    // ------------------------------------------------------------------
    // Parse Branch + Date out of the filename: PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT
    // {0, RelativePosition.FromEnd} = text before the LAST "." in the name,
    // i.e. strips the ".TXT" extension regardless of case.
    // ------------------------------------------------------------------
    AddNameParts = Table.AddColumn(FilterToPriceUpdateFiles, "NameParts", each
        Text.Split(Text.BeforeDelimiter([Name], ".", {0, RelativePosition.FromEnd}), "_")),

    AddSourceFileBranch = Table.AddColumn(AddNameParts, "SourceFileBranch", each
        Text.From([NameParts]{4}), type text),

    AddSourceFileDate = Table.AddColumn(AddSourceFileBranch, "SourceFileDate", each
        #date(Number.FromText([NameParts]{3}), Number.FromText([NameParts]{1}), Number.FromText([NameParts]{2})),
        type date),

    // ------------------------------------------------------------------
    // Parse file content: tab-delimited, header row promoted (parses by
    // column NAME downstream via ExpandTableColumn, not position, so a
    // reordered-but-same-named header still works).
    // ------------------------------------------------------------------
    AddParsedContent = Table.AddColumn(AddSourceFileDate, "ParsedContent", each
        Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = "#(tab)", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
            [PromoteAllScalars = true]
        )),

    // Full set of expected source (pre-rename) column names, single source
    // of truth for both the missing-column normalization below and the
    // ExpandTableColumn call that follows it.
    ExpectedSourceColumns = {
        "branch", "inmaster_franchise", "part_no", "inmanuf_list_price",
        "inmaster_list_price", "cc_price_decrease", "bin_location", "category",
        "inmaster_on_hand_qty", "inmanuf_replace_price", "inmaster_replace_price",
        "inmanuf_sell_price1", "inmaster_sell_price1", "cost_diff", "list_diff",
        "sel1_diff", "effective_date", "update_code", "part_desc", "sell_price_old"
    },

    // Normalize each row's parsed table to exactly ExpectedSourceColumns
    // before expanding -- see DEFENSE-IN-DEPTH NOTE above. MissingField.UseNull
    // fills any absent source column with null instead of erroring, and also
    // pins column order so a differently-ordered header can't matter.
    NormalizeParsedContent = Table.TransformColumns(AddParsedContent, {
        {"ParsedContent", each Table.SelectColumns(_, ExpectedSourceColumns, MissingField.UseNull), type table}
    }),

    SelectForExpand = Table.SelectColumns(NormalizeParsedContent,
        {"Name", "SourceFileBranch", "SourceFileDate", "ParsedContent"}),

    ExpandedRows = Table.ExpandTableColumn(SelectForExpand, "ParsedContent", ExpectedSourceColumns),

    // ------------------------------------------------------------------
    // Rename to PascalCase per repo convention
    // ------------------------------------------------------------------
    RenameColumns = Table.RenameColumns(ExpandedRows, {
        {"Name", "SourceFileName"},
        {"branch", "Branch"},
        {"inmaster_franchise", "Franchise"},
        {"part_no", "PartNumber"},
        {"inmanuf_list_price", "ManufacturerListPrice"},
        {"inmaster_list_price", "DealerListPrice"},
        {"cc_price_decrease", "ListPriceChangePercent"},
        {"bin_location", "BinLocation"},
        {"category", "Category"},
        {"inmaster_on_hand_qty", "OnHandQty"},
        {"inmanuf_replace_price", "ManufacturerReplacePrice"},
        {"inmaster_replace_price", "DealerReplacePrice"},
        {"inmanuf_sell_price1", "ManufacturerSellPrice1"},
        {"inmaster_sell_price1", "DealerSellPrice1"},
        {"cost_diff", "CostDiff"},
        {"list_diff", "ListDiff"},
        {"sel1_diff", "SellPrice1Diff"},
        {"effective_date", "EffectiveDate"},
        {"update_code", "UpdateCode"},
        {"part_desc", "PartDescription"},
        {"sell_price_old", "SellPriceOld"}
    }),

    // ------------------------------------------------------------------
    // Data-quality tripwire: filename branch vs in-file branch.
    // NOTE: both sides are compared as trimmed text, at this point still
    // raw strings straight out of Csv.Document (Branch is not yet
    // Int64.Type -- that conversion happens later in ChangedTypes). No
    // leading-zero normalization is applied. Per the design spec's
    // observed filenames (PRICEUPDATE_08_02_2026_97.TXT, _..._1.TXT) and
    // Task 3's filename regex (\d{1,3}, no zero-padding requirement),
    // branch numbers are not expected to be zero-padded in either the
    // filename or the in-file column, so "097" vs "97" is not expected in
    // practice -- but this has not been confirmed against real historical
    // files, so treat any BranchMismatchFlag = true rows as worth a manual
    // look during Fabric preview rather than assuming they're all genuine
    // JD data-quality issues.
    // ------------------------------------------------------------------
    AddBranchMismatchFlag = Table.AddColumn(RenameColumns, "BranchMismatchFlag", each
        Text.Trim(Text.From([SourceFileBranch])) <> Text.Trim(Text.From([Branch])), type logical),

    // ------------------------------------------------------------------
    // IngestedAt -- DST-aware UTC -> Central, same pattern as
    // .claude/queries/DATA-REFRESH-TEMPLATE.pq
    // ------------------------------------------------------------------
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalNow  = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    AddIngestedAt = Table.AddColumn(AddBranchMismatchFlag, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Types + final column order
    // ------------------------------------------------------------------
    ChangedTypes = Table.TransformColumnTypes(AddIngestedAt, {
        {"Branch", Int64.Type}, {"Franchise", type text}, {"PartNumber", type text},
        {"ManufacturerListPrice", type number}, {"DealerListPrice", type number},
        {"ListPriceChangePercent", type number}, {"BinLocation", type text}, {"Category", type text},
        {"OnHandQty", type number}, {"ManufacturerReplacePrice", type number},
        {"DealerReplacePrice", type number}, {"ManufacturerSellPrice1", type number},
        {"DealerSellPrice1", type number}, {"CostDiff", type number}, {"ListDiff", type number},
        {"SellPrice1Diff", type number}, {"EffectiveDate", type date}, {"UpdateCode", type text},
        {"PartDescription", type text}, {"SellPriceOld", type number},
        {"SourceFileName", type text}, {"SourceFileBranch", type text}, {"SourceFileDate", type date}
    }),

    FinalColumnOrder = Table.ReorderColumns(ChangedTypes, {
        "Branch", "PartNumber", "EffectiveDate", "Franchise", "PartDescription", "Category",
        "ManufacturerListPrice", "DealerListPrice", "ListPriceChangePercent",
        "ManufacturerReplacePrice", "DealerReplacePrice", "ManufacturerSellPrice1",
        "DealerSellPrice1", "SellPriceOld", "CostDiff", "ListDiff", "SellPrice1Diff",
        "BinLocation", "OnHandQty", "UpdateCode",
        "SourceFileName", "SourceFileBranch", "SourceFileDate", "BranchMismatchFlag", "IngestedAt"
    })
in
    FinalColumnOrder
