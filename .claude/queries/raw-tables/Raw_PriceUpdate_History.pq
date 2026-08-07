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

BRANCH CODES -- confirmed with Brian 2026-08-07: filenames (and the in-file
`branch` column itself) sometimes carry a sub-branch/department letter
suffix (e.g. "11S", "93C", "4B" -- a physical branch's Service/Bulk/Inside-
sales/etc. sub-location). ~6% of all files across all 10 years of history
use this shape. Per Brian, the sub-branch distinction is not meaningful for
this data and should always be rolled up to the main branch number for
analysis. Accordingly: `Branch` (the final Int64 column) is the rolled-up
main branch (e.g. 11), while `SourceFileBranch` preserves the full raw code
exactly as it appeared in the filename (e.g. "11S") for traceability.

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
requires an exact match against all 20 expected column names before a file
reaches New/, so this path is currently a belt-and-suspenders safeguard
rather than a reachable one -- kept anyway because it directly implements
what this spec's Error Handling section asks for at the parsing layer, and
because it's what protects a future backfill of older files (2018+, header
stability unconfirmed) if the harvest-side check is ever loosened to admit
a subset-of-columns header.

DEFENSE-IN-DEPTH NOTE (malformed filenames): FilterToPriceUpdateFiles only
checks the name's prefix/suffix, not its internal shape, so a bypass file
that still matches "PRICEUPDATE_*.TXT" but doesn't split into exactly 5
"_"-delimited tokens (e.g. PRICEUPDATE_TEST.TXT) would otherwise crash the
fixed-index NameParts{4}/{3}/{1}/{2} lookups below with a hard "not enough
elements in the list" error and fail the whole batch. FilterToWellFormedNames
guards against that. As with the missing-column case above, this should be
unreachable in practice -- Harvest-PriceUpdateFiles.ps1 already rejects any
filename that doesn't match its own MM_DD_YYYY_BRANCH regex before copying
it into New/ -- but it's the same bypass scenario (manual copy into New/, or
a future loosening of the harvest-side check) and costs nothing to close
here too. Rows that fail this guard are silently excluded from this table
rather than surfaced anywhere else in this query (this dataflow has no
Quarantine-writing capability of its own -- that's the harvest script's
job); if this filter ever actually drops a row, that's a signal worth
investigating directly (visible only as a refresh row count lower than the
number of files in New/, since there is no separate log sink from inside
this M query).

UNMITIGATED RISK (not addressed by this file): a zero-byte or genuinely
non-CSV file that still matches the PRICEUPDATE_*.TXT name/header shape
checks (e.g. truncated by a mid-write race, see Harvest-PriceUpdateFiles.ps1's
own docstring caveat about this) could still make Csv.Document error or
return an unexpected shape at the AddParsedContent step below; nothing in
this query currently isolates that failure per-file, so it's a known,
currently-unmitigated residual risk to watch for during the live Fabric
preview.

UNMITIGATED RISK (value-level type conversion, not addressed by this file):
ChangedTypes converts Branch and all price/quantity columns to numeric types
with no try/otherwise wrapping. This is a distinct failure surface from the
file-level risk above -- here the file parses fine as CSV, but a single
stray non-numeric value in any one file in that day's New/ batch (a blank
string, "N/A", a thousands separator, or anything else JD's export might
emit in a numeric-looking column) risks becoming an error cell that could
fail the Lakehouse write for the entire batch, not just quarantine the one
bad row or file. The one previously-known instance of this for Branch
specifically (a sub-branch letter suffix, e.g. "11S") is now handled by
NormalizeBranchToMain below, which strips non-digit characters before this
step runs -- but NormalizeBranchToMain would itself produce an empty string
(and therefore still fail Int64.Type conversion) if a branch value were
ever ALL non-digit characters. No such value has been observed in any real
file to date (2016-2026); every confirmed sub-branch code is digits
followed by exactly one letter. Fixing the general case properly -- e.g.
try/otherwise per column, or using a Fabric Dataflow Gen2 "keep errors"
destination setting -- is a decision best made once real files are visible
during the live Fabric preview (a separate, later manual task), not here.
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
        Text.StartsWith(Text.Upper([Name]), "PRICEUPDATE_") and Text.EndsWith(Text.Upper([Name]), ".TXT")
    ),

    // ------------------------------------------------------------------
    // Parse Branch + Date out of the filename: PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT
    // {0, RelativePosition.FromEnd} = text before the LAST "." in the name,
    // i.e. strips the ".TXT" extension regardless of case.
    // ------------------------------------------------------------------
    AddNameParts = Table.AddColumn(FilterToPriceUpdateFiles, "NameParts", each
        Text.Split(Text.BeforeDelimiter([Name], ".", {0, RelativePosition.FromEnd}), "_")),

    // Guard against fixed-index access below -- see DEFENSE-IN-DEPTH NOTE
    // (malformed filenames) above. Only PRICEUPDATE_MM_DD_YYYY_BRANCH.TXT
    // shapes (exactly 5 "_"-delimited tokens) proceed past this point.
    FilterToWellFormedNames = Table.SelectRows(AddNameParts, each List.Count([NameParts]) = 5),

    AddSourceFileBranch = Table.AddColumn(FilterToWellFormedNames, "SourceFileBranch", each
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
            // Encoding = 1252 (Windows-1252) is an assumption, not confirmed
            // against real files -- verify at live Fabric preview time; if
            // PartDescription/Category show mojibake, the source encoding
            // is different than assumed here.
            Csv.Document([Content], [Delimiter = "#(tab)", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
            [PromoteAllScalars = true]
        )),

    // Full set of expected source (pre-rename) column names. Shared by the
    // missing-column normalization below and the ExpandTableColumn call
    // that follows it, so those two stay in sync with each other -- but
    // note RenameColumns/ChangedTypes/FinalColumnOrder further down each
    // independently hardcode this same 20-column schema by their renamed
    // (PascalCase) names, so a future added/removed JD column still needs
    // updating in more than just this one list.
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
    // raw strings straight out of Csv.Document -- BEFORE NormalizeBranchToMain
    // strips any sub-branch letter and BEFORE ChangedTypes converts Branch
    // to Int64.Type (both happen later, below). This is deliberate: the
    // comparison should validate the filename and in-file values agree on
    // the FULL raw code (e.g. "11S" vs "11S"), not just the rolled-up main
    // branch -- confirmed against a real file (PRICEUPDATE_08_28_2022_11S.TXT)
    // that the in-file `branch` column carries the same sub-branch letter as
    // the filename. No leading-zero normalization is applied. Per the design
    // spec's observed filenames (PRICEUPDATE_08_02_2026_97.TXT, _..._1.TXT)
    // and Task 3's filename regex, branch numbers are not expected to be
    // zero-padded in either the filename or the in-file column, so "097" vs
    // "97" is not expected in practice -- but this has not been confirmed
    // against every historical file, so treat any BranchMismatchFlag = true
    // rows as worth a manual look during Fabric preview rather than assuming
    // they're all genuine JD data-quality issues.
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
    // Roll a sub-branch code (e.g. "11S") up to its main branch number
    // (11) by stripping any trailing non-digit character(s) -- confirmed
    // with Brian 2026-08-07 this is the correct, expected behavior (sub-
    // branch distinction is not meaningful for this data). Must happen
    // BEFORE ChangedTypes converts Branch to Int64.Type below: the raw
    // in-file branch value can be "11S", which Int64.Type conversion
    // would otherwise throw a hard, batch-failing error on. This does not
    // touch SourceFileBranch, which intentionally keeps the full raw code
    // (including the letter) for traceability.
    // ------------------------------------------------------------------
    NormalizeBranchToMain = Table.TransformColumns(AddIngestedAt, {
        {"Branch", each Text.Select(_, {"0".."9"}), type text}
    }),

    // ------------------------------------------------------------------
    // Types + final column order
    // ------------------------------------------------------------------
    ChangedTypes = Table.TransformColumnTypes(NormalizeBranchToMain, {
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
