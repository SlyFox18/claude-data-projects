"""
DP GOLD DATETABLE VERIFICATION
============================================================================
Independent check of dim_DateTable (built by Build_Gold_DateTable.Notebook)
- pure calendar math, so this verifies against hand-computed expected
values for known dates rather than a source system (there is no source -
this table has none, same as production).

Also confirms none of the deliberately-dropped "today"-relative columns
leaked back in - a negative check, not just a positive one.

Run manually after Task 1 confirms the notebook ran successfully.
============================================================================
"""

import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

print("=== Check 1: row count and column count ===")
row_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/dim_DateTable')").fetchone()[0]
col_count = len(con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/dim_DateTable') LIMIT 1").df())
print(f"Row count: {row_count:,} (expect 4,018)")
print(f"Column count: {col_count} (expect 28)")

print("\n=== Check 2: hand-computed spot checks ===")
checks = con.execute(f"""
    SELECT Date, DateKey, Year, Quarter, Month, DayOfWeek, DayOfWeekName, Season,
           IsPeakSeason, IsWeekend, IsBusinessDay, FiscalYear, FiscalQuarter
    FROM delta_scan('{dp_base}/dim_DateTable')
    WHERE Date IN ('2025-12-25', '2025-07-04', '2025-01-01')
    ORDER BY Date
""").df()
print(checks.to_string())

print("\n=== Check 3: confirm no dropped 'today'-relative columns leaked back in ===")
columns_df = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/dim_DateTable') LIMIT 1").df()
actual_columns = set(columns_df["column_name"].tolist())
dropped_columns = {
    "YearOffset", "IsCurrentYear", "IsCurrentMonth", "IsPreviousYear", "IsPreviousMonth",
    "IsPreviousQuarter", "IsYearToDate", "IsQuarterToDate", "IsMonthToDate",
    "IsRolling6Months", "IsRolling12Months", "IsRolling24Months", "IsRolling36Months",
    "IsRolling48Months", "IsRolling4Quarters", "IsRolling8Quarters", "IsRolling52Weeks",
    "IsRolling365Days", "IsRolling730Days", "IsRolling1095Days", "IsRolling1460Days",
    "IsRolling180Days", "IsRolling545Days", "IsRolling45Days", "IsRolling120Days",
    "IsRolling270Days", "IsRolling450Days", "IsRolling13Weeks", "IsRolling26Weeks",
    "IsRolling104Weeks", "IsRolling156Weeks", "IsLast30Days", "IsLast60Days", "IsLast90Days",
    "IsNext30Days", "IsSameMonthLastYear", "IsSameQuarterLastYear", "RollingPeriodCategory",
    "DaysFromToday",
}
leaked = dropped_columns & actual_columns
print(f"Dropped columns found in table (expect none): {leaked if leaked else 'none - clean'}")
