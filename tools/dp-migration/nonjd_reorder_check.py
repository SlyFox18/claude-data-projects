# tools/dp-migration/nonjd_reorder_check.py
"""
Non-JD Parts Order Tool: independent check of Fact_NonJD_Reorder.

Re-implements the reorder rules (spec 2026-10-20-non-jd-parts-order-tool-redesign-design.md, section 5.5: the
NonJD_OrderRules list Ben tunes) in DuckDB SQL over the same inputs, then compares row by row with the Gold table
Build_Gold_NonJD_Reorder wrote. Also prints a fingerprint of the Gold table (excluding BuiltAtUtc) for run-twice
determinism checks, and lists the rules that are skipped as invalid.

Usage:
    python nonjd_reorder_check.py --tier dev            # compare, exit 1 on any mismatch
    python nonjd_reorder_check.py --tier dev --fingerprint-only

Run straight after the DP refresh: Silver inputs are read live, so an intraday refresh between the Gold build
and this check causes false mismatches.

Auth: Azure CLI (az login as Brian), read-only.
"""
import argparse
import os
import sys
import tempfile
from datetime import date, timezone
from zoneinfo import ZoneInfo

import duckdb

TIERS = {
    "dev": {"staging": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"),
            "presentation": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")},
    "prod": {"staging": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
             "presentation": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f")},
}
# Applies when no valid active rule matches a part (spec 5.5 step 1).
BUILTIN_DEFAULT = {"RuleName": "Built-in default", "HistoryMonths": 12, "MinActiveMonths": 3, "WeeksOfCover": 6,
                   "DemandBasis": "UnitsSold"}
HIST_MONTHS = 60          # Silver_PartSalesHistory depth; HistoryMonths is at most 59
# Compared exactly (null-safe); the float columns are compared with a tolerance (see _diff_where).
COMPARE_COLS = ["RuleName", "ActiveMonths", "CalcTarget", "StockingTarget", "RecommendedOrderQty", "SurplusQty",
                "Status"]
TOLERANCE_COLS = ["WindowDemand", "MonthlyRate", "InboundTransferQty"]
TOLERANCE = 1e-6
OUTPUT_COLS = ["Branch", "Franchise", "PartNumber", "RuleId", "RuleName", "DemandBasis", "HistoryMonths",
               "MinActiveMonths", "WeeksOfCover", "WindowDemand", "ActiveMonths", "MonthlyRate", "CalcTarget",
               "EffectiveMin", "StockingTarget", "RecommendedOrderQty", "SurplusQty", "InboundTransferQty", "Status"]


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


def _whole_between(col: str, lo: int, hi: int) -> str:
    return f"({col} = floor({col}) AND {col} BETWEEN {lo} AND {hi})"


# Active rules of NonJD_OrderRules with their problems ('' = valid). SharePoint numbers arrive as doubles, so
# "whole number" is checked explicitly. Inactive rules (Active false or NULL) are ignored entirely: neither matched
# nor reported. concat_ws skips NULLs, so every problem of a rule is listed.
RULE_CHECK_CTE = f"""
    rule_check AS (
        SELECT *,
               concat_ws('; ',
                 CASE WHEN Priority IS NULL THEN 'Priority is missing' END,
                 CASE WHEN HistoryMonths IS NULL THEN 'HistoryMonths is missing'
                      WHEN NOT {_whole_between('HistoryMonths', 1, 59)}
                      THEN 'HistoryMonths must be a whole number 1-59' END,
                 CASE WHEN MinActiveMonths IS NULL THEN 'MinActiveMonths is missing'
                      WHEN NOT {_whole_between('MinActiveMonths', 0, 59)}
                      THEN 'MinActiveMonths must be a whole number 0-59' END,
                 CASE WHEN WeeksOfCover IS NULL THEN 'WeeksOfCover is missing'
                      WHEN WeeksOfCover < 0 THEN 'WeeksOfCover must not be negative' END,
                 CASE WHEN (StartMonth IS NULL) <> (EndMonth IS NULL)
                      THEN 'StartMonth and EndMonth must both be set or both blank' END,
                 CASE WHEN StartMonth IS NOT NULL AND NOT {_whole_between('StartMonth', 1, 12)}
                      THEN 'StartMonth must be a whole number 1-12' END,
                 CASE WHEN EndMonth IS NOT NULL AND NOT {_whole_between('EndMonth', 1, 12)}
                      THEN 'EndMonth must be a whole number 1-12' END,
                 CASE WHEN coalesce(upper(trim(DemandBasis)), '') NOT IN ('UNITSSOLD', 'REQUESTS')
                      THEN 'DemandBasis must be UnitsSold or Requests' END
               ) AS problems
        FROM order_rules
        WHERE coalesce(Active, false)
    )"""

INVALID_RULES_SQL = f"""
    WITH {RULE_CHECK_CTE}
    SELECT Id, RuleName, problems FROM rule_check WHERE problems <> '' ORDER BY Id
"""

# Parameters: $cur = first day of the run's Central-time month, $m = its month number, $today = the run's date.
# Rule pick: highest Priority, then more non-blank criteria (Franchise / DealerGroupCode / Branch; the season does
# not count), then lowest Id. Window: the rule's HistoryMonths full months before $cur.
# CalcTarget: MonthlyRate * WeeksOfCover * 12 / 52 is rounded to 9 decimals before ceil, so double noise such as
# (5 / 3) * 5.2 * 12 / 52 = 2.0000000000000004 gives 2, not 3. Build_Gold_NonJD_Reorder does the same.
EXPECTED_SQL = f"""
    WITH {RULE_CHECK_CTE},
    scope AS (
        SELECT * FROM parts
        WHERE Cost > 0
          AND upper(trim(Franchise)) NOT IN ('D', 'ZP', 'S', '95')
          AND NOT starts_with(upper(trim(Franchise)), 'T')
          AND NOT starts_with(upper(trim(Franchise)), 'U')
    ),
    valid AS (
        SELECT Id, RuleName, Priority,
               nullif(upper(trim(Franchise)), '') AS c_franchise,
               nullif(upper(trim(DealerGroupCode)), '') AS c_dgc,
               nullif(upper(trim(Branch)), '') AS c_branch,
               CAST(HistoryMonths AS INTEGER) AS hm, CAST(MinActiveMonths AS INTEGER) AS mam,
               WeeksOfCover AS woc,
               CASE upper(trim(DemandBasis)) WHEN 'UNITSSOLD' THEN 'UnitsSold' ELSE 'Requests' END AS basis
        FROM rule_check
        WHERE problems = ''
          AND (StartMonth IS NULL
               OR (StartMonth <= EndMonth AND $m BETWEEN StartMonth AND EndMonth)
               OR (StartMonth > EndMonth AND ($m >= StartMonth OR $m <= EndMonth)))
    ),
    pick AS (
        SELECT * EXCLUDE (rn) FROM (
            SELECT sc.Branch, sc.Franchise, sc.PartNumber, v.*,
                   row_number() OVER (PARTITION BY sc.Branch, sc.Franchise, sc.PartNumber
                                      ORDER BY v.Priority DESC,
                                               CAST(v.c_franchise IS NOT NULL AS INTEGER)
                                                 + CAST(v.c_dgc IS NOT NULL AS INTEGER)
                                                 + CAST(v.c_branch IS NOT NULL AS INTEGER) DESC,
                                               v.Id ASC) AS rn
            FROM scope sc JOIN valid v
              ON (v.c_franchise IS NULL OR v.c_franchise = upper(trim(sc.Franchise)))
             AND (v.c_dgc IS NULL OR v.c_dgc = upper(trim(sc.DealerGroupCode)))
             AND (v.c_branch IS NULL OR v.c_branch = upper(trim(sc.Branch))))
        WHERE rn = 1
    ),
    s AS (
        SELECT * EXCLUDE (rn) FROM (
            SELECT *, row_number() OVER (PARTITION BY Branch, Franchise, PartNumber
                                         ORDER BY Modified DESC, Id DESC) AS rn
            FROM settings) WHERE rn = 1
    ),
    t AS (
        SELECT trim(RequestingBranch) AS b, PartNumber AS pn, sum(coalesce(OpenQty, 0)) AS q
        FROM transfers GROUP BY ALL
    ),
    base AS (
        SELECT sc.Branch, sc.Franchise, sc.PartNumber, sc.QuantityOnHand,
               CAST(trunc(coalesce(sc.QuantityOnHand, 0)) AS INTEGER) AS oh,
               CAST(trunc(coalesce(sc.OnOrder, 0)) AS INTEGER) AS oo,
               p.Id AS RuleId,
               CASE WHEN p.Id IS NULL THEN '{BUILTIN_DEFAULT["RuleName"]}' ELSE p.RuleName END AS RuleName,
               coalesce(p.basis, '{BUILTIN_DEFAULT["DemandBasis"]}') AS DemandBasis,
               coalesce(p.hm, {BUILTIN_DEFAULT["HistoryMonths"]}) AS HistoryMonths,
               coalesce(p.mam, {BUILTIN_DEFAULT["MinActiveMonths"]}) AS MinActiveMonths,
               coalesce(p.woc, CAST({BUILTIN_DEFAULT["WeeksOfCover"]} AS DOUBLE)) AS WeeksOfCover,
               CAST(coalesce(s.MinOverride, r.MinimumQty, 0) AS DOUBLE) AS EffectiveMin,
               coalesce(s.Masked, false) AND (s.MaskExpires IS NULL OR s.MaskExpires >= $today) AS masked,
               CAST(coalesce(t.q, 0.0) AS DOUBLE) AS InboundTransferQty
        FROM scope sc
        LEFT JOIN pick p USING (Branch, Franchise, PartNumber)
        LEFT JOIN rules r USING (Branch, Franchise, PartNumber)
        LEFT JOIN s USING (Branch, Franchise, PartNumber)
        LEFT JOIN t ON t.b = trim(sc.Branch) AND t.pn = upper(trim(sc.PartNumber))
    ),
    monthly AS (
        SELECT Branch, Franchise, PartNumber, MonthStart,
               sum(coalesce(SalesQty, 0)) AS units, sum(coalesce(RequestCount, 0)) AS requests
        FROM hist WHERE MonthStart < $cur
        GROUP BY ALL
    ),
    win AS (
        SELECT b.Branch, b.Franchise, b.PartNumber,
               sum(CASE b.DemandBasis WHEN 'UnitsSold' THEN m.units ELSE m.requests END) AS raw_demand,
               count(*) FILTER (WHERE (CASE b.DemandBasis WHEN 'UnitsSold' THEN m.units ELSE m.requests END) > 0)
                 AS active
        FROM (SELECT DISTINCT Branch, Franchise, PartNumber, DemandBasis, HistoryMonths FROM base) b
        JOIN monthly m USING (Branch, Franchise, PartNumber)
        WHERE m.MonthStart >= CAST($cur - to_months(b.HistoryMonths) AS DATE)
        GROUP BY ALL
    ),
    demand AS (
        SELECT b.*,
               greatest(0.0, CAST(coalesce(w.raw_demand, 0) AS DOUBLE)) AS WindowDemand,
               CAST(coalesce(w.active, 0) AS INTEGER) AS ActiveMonths
        FROM base b LEFT JOIN win w USING (Branch, Franchise, PartNumber)
    ),
    calc AS (
        SELECT *, CASE WHEN ActiveMonths >= MinActiveMonths
                       THEN CAST(ceil(round(MonthlyRate * WeeksOfCover * 12 / 52, 9)) AS INTEGER)
                       ELSE 0 END AS CalcTarget
        FROM (SELECT *, WindowDemand / HistoryMonths AS MonthlyRate FROM demand)
    ),
    tgt AS (
        SELECT *, CAST(greatest(CalcTarget, ceil(EffectiveMin)) AS INTEGER) AS StockingTarget FROM calc
    ),
    rec AS (
        SELECT *, CASE WHEN masked THEN 0 ELSE greatest(0, StockingTarget - oh - oo) END AS RecommendedOrderQty
        FROM tgt
    ),
    final AS (
        SELECT *, greatest(0, oh - StockingTarget) AS SurplusQty,
               CASE WHEN masked THEN 'Masked'
                    WHEN StockingTarget = 0
                    THEN CASE WHEN ActiveMonths = 0 THEN 'NoRecentActivity' ELSE 'NotStocked' END
                    WHEN RecommendedOrderQty > 0 AND coalesce(QuantityOnHand, 0) <= 0 THEN 'OutOfStock'
                    WHEN RecommendedOrderQty > 0 THEN 'Reorder' ELSE 'OK' END AS Status
        FROM rec
    )
    SELECT {", ".join(OUTPUT_COLS)} FROM final
"""


def _params(current_month: date, today: date) -> dict:
    return {"cur": current_month, "m": current_month.month, "today": today}


def expected_reorder(con, current_month: date, today: date):
    """Run the reference rules over tables parts, rules, hist, order_rules, settings, transfers.
    current_month = first day of the run's Central-time month; today = the run's Central date."""
    return con.execute(EXPECTED_SQL, _params(current_month, today))


def invalid_rules(con) -> list:
    """Active rows of order_rules that are skipped as invalid, as (Id, RuleName, reason), by Id."""
    return con.execute(INVALID_RULES_SQL).fetchall()


def _diff_where() -> str:
    exact = [f"g.{c} IS DISTINCT FROM e.{c}" for c in COMPARE_COLS]
    approx = [f"((g.{c} IS NULL) <> (e.{c} IS NULL) OR abs(g.{c} - e.{c}) > {TOLERANCE})" for c in TOLERANCE_COLS]
    return " OR ".join(exact + approx)


def compare(con, gold: str, expected: str) -> dict:
    keys = "Branch, Franchise, PartNumber"
    only_gold = con.execute(f"SELECT count(*) FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})").fetchone()[0]
    only_exp = con.execute(f"SELECT count(*) FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})").fetchone()[0]
    different = con.execute(f"""
        SELECT count(*) FROM {gold} g JOIN {expected} e USING ({keys})
        WHERE {_diff_where()}
    """).fetchone()[0]
    dup_gold = con.execute(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {gold}").fetchone()[0]
    dup_exp = con.execute(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {expected}").fetchone()[0]
    return {"only_gold": only_gold, "only_expected": only_exp, "different": different,
            "dup_gold": dup_gold, "dup_expected": dup_exp}


def _path(tier: str, layer: str, table: str) -> str:
    ws, lh = TIERS[tier][layer]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"


def _connect():
    con = duckdb.connect()
    spill = os.path.join(tempfile.gettempdir(), 'nonjd_check_spill').replace("\\", "/")
    con.execute(f"SET memory_limit='3GB'; SET temp_directory='{spill}'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def fingerprint(con, tier: str) -> tuple:
    p = _path(tier, "presentation", "Fact_NonJD_Reorder")
    return con.execute(f"""SELECT count(*), sum(hash(t)::HUGEINT)
                           FROM (SELECT * EXCLUDE (BuiltAtUtc) FROM delta_scan('{p}')) t""").fetchone()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", choices=sorted(TIERS), required=True)
    ap.add_argument("--fingerprint-only", action="store_true")
    a = ap.parse_args()
    con = _connect()
    rows, fp = fingerprint(con, a.tier)
    print(f"Fact_NonJD_Reorder ({a.tier}): {rows:,} rows, fingerprint {fp}")
    if a.fingerprint_only:
        return 0

    gold_p = _path(a.tier, "presentation", "Fact_NonJD_Reorder")
    built = con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{gold_p}')").fetchone()[0]
    if built is None:
        sys.exit("Fact_NonJD_Reorder is empty; nothing to check")
    if built.tzinfo is None:
        built = built.replace(tzinfo=timezone.utc)
    today = built.astimezone(ZoneInfo("America/Chicago")).date()
    current_month = date(today.year, today.month, 1)
    print(f"Gold built {built}; checking as of {today} (month {current_month})")

    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, QuantityOnHand, OnOrder, Cost,
                    DealerGroupCode FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartInformation')}')""")
    con.execute(f"""CREATE TABLE rules AS SELECT Branch, Franchise, PartNumber, MinimumQty
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartStockingRules')}')""")
    hist_start = add_months(current_month, -HIST_MONTHS)
    con.execute(f"""CREATE TABLE hist AS SELECT Branch, Franchise, PartNumber, MonthStart, SalesQty, RequestCount
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartSalesHistory')}')
                    -- only speeds the read; each rule's window is applied in EXPECTED_SQL
                    WHERE MonthStart >= DATE '{hist_start}'""")
    con.execute(f"""CREATE TABLE order_rules AS SELECT Id, RuleName, Priority, Active, Franchise, DealerGroupCode,
                    Branch, StartMonth, EndMonth, HistoryMonths, MinActiveMonths, WeeksOfCover, DemandBasis, Modified
                    FROM delta_scan('{_path(a.tier, 'staging', 'NonJD_OrderRules')}')""")
    con.execute(f"""CREATE TABLE settings AS SELECT Id, Branch, Franchise, PartNumber, MinOverride, Masked,
                    MaskExpires, Modified FROM delta_scan('{_path(a.tier, 'staging', 'NonJD_PartSettings')}')""")
    con.execute(f"""CREATE TABLE transfers AS SELECT RequestingBranch, PartNumber, OpenQty
                    FROM delta_scan('{_path(a.tier, 'presentation', 'Fact_OutstandingTransfers')}')""")

    bad = invalid_rules(con)
    if bad:
        print(f"WARN: {len(bad)} rule(s) skipped as invalid:")
        for rid, name, reason in bad:
            print(f"  {rid} {name!r}: {reason}")
    else:
        print("All active rules are valid")

    con.execute("CREATE TABLE expected AS " + EXPECTED_SQL, _params(current_month, today))
    cmp_cols = ", ".join(COMPARE_COLS + TOLERANCE_COLS)
    con.execute(f"""CREATE TABLE gold AS SELECT Branch, Franchise, PartNumber, {cmp_cols}
                    FROM delta_scan('{gold_p}')""")
    result = compare(con, "gold", "expected")
    print(result)
    if any(result.values()):
        e_cols = ", ".join(f"e.{c} AS e_{c}" for c in OUTPUT_COLS[3:])
        print(con.execute(f"""SELECT g.*, {e_cols}
                              FROM gold g JOIN expected e USING (Branch, Franchise, PartNumber)
                              WHERE {_diff_where()} LIMIT 10""").fetchall())
        keys = "Branch, Franchise, PartNumber"
        print("only in gold:", con.execute(f"SELECT {keys} FROM gold EXCEPT SELECT {keys} FROM expected LIMIT 10").fetchall())
        print("only in expected:", con.execute(f"SELECT {keys} FROM expected EXCEPT SELECT {keys} FROM gold LIMIT 10").fetchall())
        return 1
    print("PASS: Gold matches the reference rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
