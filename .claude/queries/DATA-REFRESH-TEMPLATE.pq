// Data Refresh Table — Canonical Template
// Converts UTC (Fabric service always runs UTC) to US Central Time with automatic DST.
//
// Root cause: DateTime.LocalNow() returns UTC in Fabric/Power BI Service, not local time.
// Fix: Use DateTimeZone.UtcNow() + DateTimeZone.SwitchZone() to convert correctly.
//
// DST Rules (US Central):
//   DST Start: 2nd Sunday in March  @ 2:00 AM CST = 8:00 AM UTC  → UTC-5 (CDT)
//   DST End:   1st Sunday in November @ 2:00 AM CDT = 7:00 AM UTC → UTC-6 (CST)
//
// Applied to all reports: 2026-02-27 (see MEMORY.md for update tracking)

let
    UtcNow    = DateTimeZone.UtcNow(),
    UtcDT     = DateTimeZone.RemoveZone(UtcNow),
    CurYear   = Date.Year(DateTime.Date(UtcDT)),

    // DST Start: 2nd Sunday in March @ 8:00 AM UTC
    Mar1      = #date(CurYear, 3, 1),
    Sun1Mar   = Date.AddDays(Mar1, Number.Mod(7 - Date.DayOfWeek(Mar1, Day.Sunday), 7)),
    DstStart  = #datetime(CurYear, 3, Date.Day(Date.AddDays(Sun1Mar, 7)), 8, 0, 0),

    // DST End: 1st Sunday in November @ 7:00 AM UTC
    Nov1      = #date(CurYear, 11, 1),
    Sun1Nov   = Date.AddDays(Nov1, Number.Mod(7 - Date.DayOfWeek(Nov1, Day.Sunday), 7)),
    DstEnd    = #datetime(CurYear, 11, Date.Day(Sun1Nov), 7, 0, 0),

    // CDT = UTC-5 (DST active), CST = UTC-6 (standard)
    OffsetHrs = if UtcDT >= DstStart and UtcDT < DstEnd then -5 else -6,
    LocalDT   = DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNow, OffsetHrs, 0)),

    Source    = #table({"CurrentDateTime"}, {{LocalDT}}),
    AddDate   = Table.DuplicateColumn(Source, "CurrentDateTime", "Date"),
    AddTime   = Table.DuplicateColumn(AddDate, "Date", "Time"),
    ChgTypes  = Table.TransformColumnTypes(AddTime, {{"Date", type date}, {"Time", type time}})
in
    ChgTypes
