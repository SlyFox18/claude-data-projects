"""
JDIS_PART_INFORMATION REBUILD - COLUMN MAPPING VERIFICATION
============================================================================
Independently computes Current12MoSales/Previous12MoSales (via a join to
INHIST_MONTH_4_PI) and Current12MoDollars/Previous12MoDollars (via a rolling
12-month SUM over InHistMQT) for 5 real, already-known parts, and compares
against those same parts' real current values in Silver_PartInformation
(which is still sourced from the live view via the old ODBC dataflows today,
so its current values are a trustworthy real-world baseline).

This is NOT testing the future notebook's code - it's independently proving
the mapping itself (which tables/columns/join logic) is correct BEFORE that
mapping goes into the notebook (plan Task 5). Run after Task 2 passes.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

SAMPLE_PARTS = [
    ("13", "PK11", "M"),
    ("15", "341-645", "SC"),
    ("3", "VAK1", "M"),
    ("3", "221228", "RM"),
    ("8", "9RNJA", "M"),
]

EXPECTED = {
    ("13", "PK11", "M"): (1, 1491.31, 4, 5544.40),
    ("15", "341-645", "SC"): (1, 185.23, 1, 170.88),
    ("3", "VAK1", "M"): (2, 174.90, 1, 79.76),
    ("3", "221228", "RM"): (2, 66.50, 1, 28.59),
    ("8", "9RNJA", "M"): (18, 1219.44, 9, 441.70),
}

print("=== Current12MoSales / Previous12MoSales (via INHIST_MONTH_4_PI join) ===")
for branch, part_no, franchise in SAMPLE_PARTS:
    row = con.execute(f"""
        SELECT PI_CURRENT_12_MO_SALES, PI_PREVIOUS_12_MO_SALES
        FROM delta_scan('{base}/INHIST_MONTH_4_PI')
        WHERE BRANCH = '{branch}' AND PART_NO = '{part_no}' AND FRANCHISE = '{franchise}'
    """).fetchone()
    exp_sales, exp_dollars, exp_prev_sales, exp_prev_dollars = EXPECTED[(branch, part_no, franchise)]
    print(f"{branch}/{part_no}/{franchise}: got Current={row[0] if row else None}, "
          f"Previous={row[1] if row else None}  (expected Current={exp_sales}, Previous={exp_prev_sales})")

print("\n=== Current12MoDollars / Previous12MoDollars (via InHistMQT rolling sum) ===")
print("First, check what date range InHistMQT actually covers, to build the right window:")
date_range = con.execute(f"""
    SELECT MIN(DATEHIST), MAX(DATEHIST) FROM delta_scan('{base}/InHistMQT')
""").fetchone()
print(f"InHistMQT DATEHIST range: {date_range[0]} to {date_range[1]}")

# NOTE: A naive rolling "MAX(DATEHIST) - INTERVAL 12 MONTH" window was tried first
# and got 3 of 5 sample parts exactly right, but was off for 2 (VAK1, 221228) whose
# most recent InHistMQT row sits right at a month boundary. DATEHIST is a per-row
# MONTH bucket (identical to MM_YYYY), not a transaction timestamp, and the table's
# globally most recent bucket (Aug 2026, per the range above) is the current,
# still-in-progress month for at least some parts (e.g. 221228 has an Aug-2026 row)
# even though other parts' own last-populated bucket is earlier (e.g. VAK1's last
# populated month is Jul-2026, simply because it had no Aug-2026 activity).
# The real source view instead anchors the window to a *global* current-month
# pointer (matching the plan's note about calendar-month boundaries anchored to
# "now") and EXCLUDES that in-progress month entirely:
#   Current12MoDollars  = SUM(SAL_VAL) over the 12 complete calendar months
#                          immediately before the global current month
#   Previous12MoDollars = SUM(SAL_VAL) over the 12 complete calendar months
#                          immediately before that
# Verified exactly against all 5 sample parts using integer year*12+month
# arithmetic (avoids any DST/offset ambiguity from the TIMESTAMP WITH TIME ZONE
# column - DATEHIST's stored offset flips between -05:00/-06:00 by season, so
# EXTRACT(YEAR/MONTH) is used directly on the timestamptz rather than doing any
# manual UTC conversion).
anchor_monthnum = con.execute(f"""
    SELECT MAX(EXTRACT(YEAR FROM DATEHIST)*12 + EXTRACT(MONTH FROM DATEHIST))
    FROM delta_scan('{base}/InHistMQT')
""").fetchone()[0]
print(f"Global anchor month number (current, in-progress month - excluded from both windows): {anchor_monthnum}")

for branch, part_no, franchise in SAMPLE_PARTS:
    row = con.execute(f"""
        WITH src AS (
            SELECT SAL_VAL, EXTRACT(YEAR FROM DATEHIST)*12 + EXTRACT(MONTH FROM DATEHIST) AS monthnum
            FROM delta_scan('{base}/InHistMQT')
            WHERE BRANCH = '{branch}' AND PART_NO = '{part_no}' AND FRANCHISE = '{franchise}'
        )
        SELECT
            SUM(CASE WHEN monthnum >= {anchor_monthnum} - 12 AND monthnum < {anchor_monthnum}
                     THEN SAL_VAL ELSE 0 END) AS current_12mo_dollars,
            SUM(CASE WHEN monthnum >= {anchor_monthnum} - 24 AND monthnum < {anchor_monthnum} - 12
                     THEN SAL_VAL ELSE 0 END) AS previous_12mo_dollars
        FROM src
    """).fetchone()
    exp_sales, exp_dollars, exp_prev_sales, exp_prev_dollars = EXPECTED[(branch, part_no, franchise)]
    print(f"{branch}/{part_no}/{franchise}: got Current$={row[0]}, Previous$={row[1]}  "
          f"(expected Current$={exp_dollars}, Previous$={exp_prev_dollars})")
