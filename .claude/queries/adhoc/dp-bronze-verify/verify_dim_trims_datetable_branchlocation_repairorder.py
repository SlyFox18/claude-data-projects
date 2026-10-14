"""
DP_PRESENTATION - dim_DateTable / dim_BranchLocation / dim_RepairOrder TRIM VERIFICATION
============================================================================
Confirms the 2026-09-11 column trims landed correctly on 3 dims already
built in DP_Presentation from earlier session work:
- dim_DateTable: 28 -> 13 columns (further trim on top of the already-applied
  2026-09-09 today-relative-bug fix), row count unaffected (pure date
  generation, 2020-01-01 to 2030-12-31).
- dim_BranchLocation: rebuilt off Silver_BranchName instead of
  BranchOperational (retiring the df_BranchOperational_Raw ODBC dependency),
  AND trimmed 16 -> 9 columns. Row count should be unchanged (69) since the
  Hourly/Salary filter logic and BranchID values are unchanged, just sourced
  differently.
- dim_RepairOrder: 15 -> 2 columns (REF_NO, CustomerNo). Row count unaffected
  (same promo-order qualification logic, just fewer computed columns).

Run manually after Brian syncs DP_Presentation and runs all 3 notebooks.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY: dim_DateTable")
print("=" * 80)
dt_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/dim_DateTable')").fetchone()[0]
print(f"Row count: {dt_count:,} (expect 4,018)")
dt_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/dim_DateTable') LIMIT 0").df()
dt_col_set = set(dt_cols["column_name"].tolist())
expected_dt_cols = {
    "DateKey", "Date", "Year", "Quarter", "Month", "Day", "WeekOfYear", "DayOfWeek",
    "MonthName", "MonthNameShort", "MonthYear", "QuarterYear", "IsWeekend",
}
if dt_col_set == expected_dt_cols:
    print("PASS: 13-column contract matches exactly.")
else:
    print(f"Missing: {expected_dt_cols - dt_col_set}")
    print(f"Extra: {dt_col_set - expected_dt_cols}")

print("\n" + "=" * 80)
print("VERIFY: dim_BranchLocation")
print("=" * 80)
bl_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/dim_BranchLocation')").fetchone()[0]
print(f"Row count: {bl_count:,} (expect 69, matching the original 2026-09-09 build)")
bl_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/dim_BranchLocation') LIMIT 0").df()
bl_col_set = set(bl_cols["column_name"].tolist())
expected_bl_cols = {
    "BranchKey", "Branch", "BranchType", "BranchID", "BranchName", "LocationID",
    "State", "City", "DataQualityScore",
}
if bl_col_set == expected_bl_cols:
    print("PASS: 9-column contract matches exactly.")
else:
    print(f"Missing: {expected_bl_cols - bl_col_set}")
    print(f"Extra: {bl_col_set - expected_bl_cols}")

seminole = con.execute(f"""
    SELECT BranchKey, Branch, BranchType, BranchID, DataQualityScore
    FROM delta_scan('{base}/dim_BranchLocation')
    WHERE BranchID = '1'
""").df()
print("\nSeminole (BranchID '1') check - expect exactly 1 row, BranchType='Main Branch':")
print(seminole.to_string())

print("\n" + "=" * 80)
print("VERIFY: dim_RepairOrder")
print("=" * 80)
ro_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/dim_RepairOrder')").fetchone()[0]
print(f"Row count: {ro_count:,} (row count should be unchanged from before the trim - same promo-order logic)")
ro_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/dim_RepairOrder') LIMIT 0").df()
ro_col_set = set(ro_cols["column_name"].tolist())
expected_ro_cols = {"REF_NO", "CustomerNo"}
if ro_col_set == expected_ro_cols:
    print("PASS: 2-column contract matches exactly.")
else:
    print(f"Missing: {expected_ro_cols - ro_col_set}")
    print(f"Extra: {ro_col_set - expected_ro_cols}")

known_bad_ros = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]
ro_check = con.execute(f"""
    SELECT REF_NO, CustomerNo
    FROM delta_scan('{base}/dim_RepairOrder')
    WHERE REF_NO IN ({",".join(f"'{r}'" for r in known_bad_ros)})
    ORDER BY REF_NO
""").df()
print(f"\nKnown-important orders found: {len(ro_check)} (expect 11)")
print(ro_check.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
