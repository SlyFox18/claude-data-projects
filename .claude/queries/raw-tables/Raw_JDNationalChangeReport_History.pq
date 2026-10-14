/*
============================================================================
Query: Raw_JDNationalChangeReport_History
Dataflow: df_Raw_JDNationalChangeReport_History
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parses JD Global Parts Pricing "Change Report" CSVs
(US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv), manually downloaded weekly by
Brian (2FA-gated JD portal, no automated harvest possible) and placed
into OneLake Files/JDChangeReports_Landing/New, appending parsed rows to
Raw_JDNationalChangeReport_History. Covers ALL Deere parts nationally,
not just parts South Plains carries -- see
docs/superpowers/specs/2026-08-07-jd-change-report-ingestion-design.md.

GRAIN: One row per PartNumber + EffectiveDate + SourceFileName (raw event
log, same "no dedup at this layer" philosophy as Raw_PriceUpdate_History).

SOURCE: OneLake Lakehouse Files -- LH_Master_Data / Files /
JDChangeReports_Landing / New (folder connector, configured via the
Dataflow Gen2 "Get Data > Lakehouse > Files" wizard -- the wizard-
generated step becomes `Source` below; replace the placeholder name with
whatever the wizard actually names it).

REFRESH: Append-only, driven by a Fabric Pipeline (dataflow refresh, then
on success only, a pipeline activity clears New/). No automated harvest
script exists for this source -- Brian places each week's file into both
New/ and Archive/ manually, since there's no network share to poll (JD's
portal requires interactive login + SMS 2FA).

DESTINATION LOAD SETTING: APPEND, not Replace. Same reasoning as
Raw_PriceUpdate_History: New/ only ever contains files not yet
successfully ingested.

FILE FORMAT: comma-delimited (NOT tab-delimited like Raw_PriceUpdate_History).
Confirmed byte-identical header across all 4 files available as of
2026-08-07: PART NUMBER,CURRENT DNP,CURRENT SLP,NEW DNP,NEW SLP,EFFECTIVE DATE.
Every line is padded with trailing spaces to a fixed record length (a
legacy-export quirk) -- every parsed value must be Text.Trim'd, not just
the last column.

FILENAME DATE: US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv -- mostly matches every
row's own EFFECTIVE DATE column, since this file specifically lists that
week's changes (unlike Raw_PriceUpdate_History, where effective_date can
be years older than the file for slow-moving parts), but NOT always: a
full-backfill check against 48,453 real rows (2026-08-10) found 21 rows
(~0.04%) where EffectiveDate was 1-9 days BEFORE the filename's date,
spread proportionally across all 5 files checked, never the reverse
direction, never off by more than 9 days. Read as JD's weekly report
occasionally listing a change that took effect a few days before the
report itself was published -- not a parsing defect. FileNameDateMismatchFlag
below is a tripwire for exactly this: expect it to fire occasionally, at
low volume, always with a small (single-digit-day) gap; a mismatch of
weeks/months/years, or a spike in volume, would indicate a real parsing
problem instead and is worth investigating on its own terms.

DEFENSE-IN-DEPTH (carried over from Raw_PriceUpdate_History, same
reasoning): missing-column tolerance via MissingField.UseNull, a
malformed-filename guard before fixed-index NameParts access, a
try/otherwise guard around filename-date construction (see
FilterToValidFileDates below), and try/otherwise on every numeric/date
conversion with a HasTypeConversionIssue flag. No known defect in this
file family yet (unlike Raw_PriceUpdate_History's confirmed row-shift
issue) -- this is precautionary, not reactive, cheap insurance given the
sibling table needed exactly this the hard way. UNLIKE the sibling query,
none of these defenses are currently redundant/unreachable here: the
sibling's equivalents are a belt-and-suspenders backstop behind
Harvest-PriceUpdateFiles.ps1's own filename/header validation, but this
file has no harvest script at all (Brian copies files into New/ by hand,
per the design spec) -- so every guard below is the ONLY protection
against a hard, batch-aborting error, not a backstop behind one.
============================================================================
*/

let
    // Placeholder name -- replace with whatever the Dataflow Gen2 "Get Data
    // > Lakehouse > Files" wizard actually names this step when pointed at
    // JDChangeReports_Landing/New.
    Source = LakehouseFilesFolder_JDChangeReportsLandingNew,

    // Defensive filter -- only files matching the expected naming pattern.
    FilterToChangeReportFiles = Table.SelectRows(Source, each
        Text.StartsWith(Text.Upper([Name]), "US.UPDCOMP.UPDATE.V2-") and Text.EndsWith(Text.Upper([Name]), ".CSV")
    ),

    // ------------------------------------------------------------------
    // Parse the date out of the filename: US.UPDCOMP.UPDATE.V2-YYYY-MM-DD.csv
    // {0, RelativePosition.FromEnd} = text before the LAST "." in the name,
    // i.e. strips the ".csv" extension regardless of case.
    // ------------------------------------------------------------------
    AddNameParts = Table.AddColumn(FilterToChangeReportFiles, "NameParts", each
        Text.Split(Text.BeforeDelimiter([Name], ".", {0, RelativePosition.FromEnd}), "-")),

    // Guard against fixed-index access below -- only the expected 4-token
    // shape (prefix, YYYY, MM, DD) proceeds past this point.
    FilterToWellFormedNames = Table.SelectRows(AddNameParts, each List.Count([NameParts]) = 4),

    // try/otherwise wraps BOTH Number.FromText (throws hard on a non-numeric
    // token) and #date() (throws hard on a shape-valid-but-calendar-impossible
    // date, e.g. day 30 in February) -- unlike Raw_PriceUpdate_History, no
    // harvest script validates this filename's date before the file reaches
    // New/ (Brian copies files in by hand), so this is the ONLY guard against
    // that failure mode. A hard error here would abort the ENTIRE table
    // write, not just one row -- exactly the class of incident that already
    // happened for real in the sibling query (see its header comment).
    AddSourceFileDate = Table.AddColumn(FilterToWellFormedNames, "SourceFileDate", each
        try #date(Number.FromText([NameParts]{1}), Number.FromText([NameParts]{2}), Number.FromText([NameParts]{3})) otherwise null,
        type nullable date),

    // Rows whose filename date failed to construct are excluded here rather
    // than surfaced elsewhere (this dataflow has no Quarantine-writing
    // capability of its own -- same reasoning as FilterToWellFormedNames
    // above). A dropped row here is visible only as a refresh row count
    // lower than expected, since there is no separate log sink from inside
    // this M query.
    FilterToValidFileDates = Table.SelectRows(AddSourceFileDate, each [SourceFileDate] <> null),

    // ------------------------------------------------------------------
    // Parse file content: comma-delimited, header row promoted (parses by
    // column NAME downstream via ExpandTableColumn, not position).
    // ------------------------------------------------------------------
    AddParsedContent = Table.AddColumn(FilterToValidFileDates, "ParsedContent", each
        Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = ",", Encoding = 1252, QuoteStyle = QuoteStyle.None]),
            [PromoteAllScalars = true]
        )),

    ExpectedSourceColumns = {
        "PART NUMBER", "CURRENT DNP", "CURRENT SLP", "NEW DNP", "NEW SLP", "EFFECTIVE DATE"
    },

    // Normalize each row's parsed table to exactly ExpectedSourceColumns
    // before expanding. MissingField.UseNull fills any absent source
    // column with null instead of erroring.
    NormalizeParsedContent = Table.TransformColumns(AddParsedContent, {
        {"ParsedContent", each Table.SelectColumns(_, ExpectedSourceColumns, MissingField.UseNull), type table}
    }),

    SelectForExpand = Table.SelectColumns(NormalizeParsedContent,
        {"Name", "SourceFileDate", "ParsedContent"}),

    ExpandedRows = Table.ExpandTableColumn(SelectForExpand, "ParsedContent", ExpectedSourceColumns),

    // ------------------------------------------------------------------
    // Rename to PascalCase per repo convention
    // ------------------------------------------------------------------
    RenameColumns = Table.RenameColumns(ExpandedRows, {
        {"Name", "SourceFileName"},
        {"PART NUMBER", "PartNumber"},
        {"CURRENT DNP", "CurrentDNP"},
        {"CURRENT SLP", "CurrentSLP"},
        {"NEW DNP", "NewDNP"},
        {"NEW SLP", "NewSLP"},
        {"EFFECTIVE DATE", "EffectiveDate"}
    }),

    // ------------------------------------------------------------------
    // Data-quality tripwire: filename date vs each row's own EffectiveDate.
    // Computed on the raw text EffectiveDate (before SafeConvertRiskyColumns
    // below converts it to a real date), so a row whose EffectiveDate fails
    // to parse doesn't get double-counted here -- that's HasTypeConversionIssue's
    // job, not this flag's.
    // ------------------------------------------------------------------
    AddDateMismatchFlag = Table.AddColumn(RenameColumns, "FileNameDateMismatchFlag", each
        let
            rowDateText = Text.Trim(Text.From([EffectiveDate] ?? "")),
            rowDate = try Date.From(rowDateText) otherwise null
        in
            rowDate <> null and rowDate <> [SourceFileDate], type logical),

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

    AddIngestedAt = Table.AddColumn(AddDateMismatchFlag, "IngestedAt", each LocalNow, type datetime),

    // ------------------------------------------------------------------
    // Data-quality tripwire: flags any row where a numeric/date field has
    // a non-blank value that fails to convert cleanly. Same defensive
    // pattern already proven necessary in Raw_PriceUpdate_History.pq --
    // precautionary here, no known defect in this file family yet.
    // Computed BEFORE SafeConvertRiskyColumns so it inspects RAW text.
    // ------------------------------------------------------------------
    AddConversionIssueFlag = Table.AddColumn(AddIngestedAt, "HasTypeConversionIssue", each
        let
            NumericValues = {[CurrentDNP], [CurrentSLP], [NewDNP], [NewSLP]},
            IsNumericIssue = (v) =>
                let t = Text.Trim(Text.From(v ?? "")) in
                t <> "" and (try Number.From(t) otherwise null) = null,
            DateText = Text.Trim(Text.From([EffectiveDate] ?? "")),
            IsDateIssue = DateText <> "" and (try Date.From(DateText) otherwise null) = null
        in
            List.AnyTrue(List.Transform(NumericValues, IsNumericIssue)) or IsDateIssue,
        type logical),

    // ------------------------------------------------------------------
    // Safe numeric/date conversions -- try/otherwise per value, so one
    // row's malformed field degrades just that field to null instead of
    // aborting the write for the entire batch. PartNumber is trimmed here
    // too (not just "risky" per se, but every parsed value needs
    // Text.Trim -- see FILE FORMAT note above about fixed-length trailing-
    // space padding -- and PartNumber is a join key for future analysis
    // against dim_Parts/InMaster, so an untrimmed trailing space here
    // would silently break string-equality joins with no cheap fix later
    // since this table loads in Append mode).
    // ------------------------------------------------------------------
    SafeConvertRiskyColumns = Table.TransformColumns(AddConversionIssueFlag, {
        {"PartNumber", each Text.Trim(Text.From(_ ?? "")), type text},
        {"CurrentDNP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"CurrentSLP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"NewDNP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"NewSLP", each try Number.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable number},
        {"EffectiveDate", each try Date.From(Text.Trim(Text.From(_ ?? ""))) otherwise null, type nullable date}
    }),

    // ------------------------------------------------------------------
    // Remaining type assignments (plain text -- PartNumber was already
    // trimmed and typed in SafeConvertRiskyColumns above, so it does not
    // need to appear here) + final column order
    // ------------------------------------------------------------------
    ChangedTypes = Table.TransformColumnTypes(SafeConvertRiskyColumns, {
        {"SourceFileName", type text}, {"SourceFileDate", type date}
    }),

    FinalColumnOrder = Table.ReorderColumns(ChangedTypes, {
        "PartNumber", "EffectiveDate", "CurrentDNP", "CurrentSLP", "NewDNP", "NewSLP",
        "SourceFileName", "SourceFileDate", "FileNameDateMismatchFlag",
        "HasTypeConversionIssue", "IngestedAt"
    })
in
    FinalColumnOrder
