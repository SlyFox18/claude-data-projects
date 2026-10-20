# tools/dp-migration/nonjd_reorder_check.py
"""
Non-JD Parts Order Tool: independent check of Fact_NonJD_Reorder.

Re-implements the reorder rules (plan 2026-10-20-non-jd-parts-order-tool-data-feed.md, Task 3) in DuckDB SQL
over the same Silver inputs, then compares row by row with the Gold table Build_Gold_NonJD_Reorder wrote.
Also prints a fingerprint of the Gold table (excluding BuiltAtUtc) for run-twice determinism checks.

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
from pathlib import Path
from zoneinfo import ZoneInfo

import duckdb

TIERS = {
    "dev": {"staging": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"),
            "presentation": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")},
    "prod": {"staging": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
             "presentation": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f")},
}
MATRIX_CSV = (Path(__file__).resolve().parents[2] / "projects" / "part order tool - app" / "params"
              / "rop_matrix.csv")
WINDOW_MONTHS = 12
# InboundTransferQty is compared separately, with a tolerance (see _diff_where).
COMPARE_COLS = ["MonthCount", "StockingTarget", "RecommendedOrderQty", "SurplusQty", "Status"]


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


EXPECTED_SQL = """
    WITH scope AS (
        SELECT * FROM parts
        WHERE Cost > 0
          AND upper(trim(Franchise)) NOT IN ('D', 'ZP', 'S', '95')
          AND NOT starts_with(upper(trim(Franchise)), 'T')
          AND NOT starts_with(upper(trim(Franchise)), 'U')
    ),
    win AS (
        SELECT Branch, Franchise, PartNumber,
               sum(CASE WHEN SalesQty > 0 OR RequestCount > 0 THEN 1 ELSE 0 END) AS MonthCount,
               CAST(sum(coalesce(SalesQty, 0)) AS DOUBLE) AS WindowSales,
               CAST(sum(coalesce(RequestCount, 0)) AS DOUBLE) AS WindowRequests
        FROM hist WHERE MonthStart >= ? AND MonthStart <= ?
        GROUP BY ALL
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
        SELECT sc.Branch, sc.Franchise, sc.PartNumber,
               CAST(trunc(coalesce(sc.QuantityOnHand, 0)) AS INTEGER) AS oh,
               CAST(trunc(coalesce(sc.OnOrder, 0)) AS INTEGER) AS oo,
               sc.QuantityOnHand,
               coalesce(w.MonthCount, 0) AS mc,
               CASE WHEN coalesce(w.MonthCount, 0) > 0 THEN w.WindowRequests / w.MonthCount ELSE 0.0 END AS avg_d,
               CASE WHEN coalesce(w.MonthCount, 0) > 0 THEN w.WindowSales / w.MonthCount ELSE 0.0 END AS avg_s,
               -- the cap only mirrors plan rule 3; with a 12-month window MonthCount never exceeds 12
               CASE WHEN coalesce(w.MonthCount, 0) = 0 THEN 1
                    WHEN w.MonthCount > 19 THEN 19 ELSE w.MonthCount END AS mcc,
               CAST(coalesce(s.MinOverride, r.MinimumQty, 0) AS DOUBLE) AS eff_min,
               coalesce(s.Masked, false) AND (s.MaskExpires IS NULL OR s.MaskExpires >= ?) AS masked,
               coalesce(t.q, 0.0) AS inbound
        FROM scope sc
        LEFT JOIN win w USING (Branch, Franchise, PartNumber)
        LEFT JOIN rules r USING (Branch, Franchise, PartNumber)
        LEFT JOIN s USING (Branch, Franchise, PartNumber)
        LEFT JOIN t ON t.b = trim(sc.Branch) AND t.pn = upper(trim(sc.PartNumber))
    ),
    rop AS (
        SELECT base.*, coalesce(m.Modifier, 1.0) AS modifier, coalesce(m.WarehouseMin, 1) AS wmin
        FROM base LEFT JOIN matrix m
          ON m.MonthCount = base.mcc AND base.avg_d >= m.DemandL AND base.avg_d < m.DemandH
         AND base.avg_s >= m.SalesL AND base.avg_s < m.SalesH
    ),
    calc AS (
        SELECT *, CASE WHEN mc = 0 THEN NULL
                       ELSE CAST(ceil(greatest(CAST(wmin AS DOUBLE), eff_min, avg_d * modifier)) AS INTEGER)
                  END AS target
        FROM rop
    ),
    rec AS (
        SELECT *, CASE WHEN masked OR mc = 0 THEN 0 ELSE greatest(0, target - oh - oo) END AS rec_qty FROM calc
    )
    SELECT Branch, Franchise, PartNumber, mc AS MonthCount, target AS StockingTarget,
           rec_qty AS RecommendedOrderQty,
           CASE WHEN mc = 0 THEN greatest(0, oh) ELSE greatest(0, oh - target) END AS SurplusQty,
           inbound AS InboundTransferQty,
           CASE WHEN masked THEN 'Masked' WHEN mc = 0 THEN 'NoRecentActivity'
                WHEN rec_qty > 0 AND coalesce(QuantityOnHand, 0) <= 0 THEN 'OutOfStock'
                WHEN rec_qty > 0 THEN 'Reorder' ELSE 'OK' END AS Status
    FROM rec
"""


def _params(current_month: date, today: date) -> list:
    return [add_months(current_month, -(WINDOW_MONTHS - 1)), current_month, today]


def expected_reorder(con, current_month: date, today: date):
    """Run the reference rules over tables parts, rules, hist, matrix, settings, transfers."""
    return con.execute(EXPECTED_SQL, _params(current_month, today))


def _diff_where() -> str:
    cond = " OR ".join(f"g.{c} IS DISTINCT FROM e.{c}" for c in COMPARE_COLS)
    return f"{cond} OR abs(coalesce(g.InboundTransferQty, 0) - coalesce(e.InboundTransferQty, 0)) > 1e-6"


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

    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, QuantityOnHand, OnOrder, Cost
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartInformation')}')""")
    con.execute(f"""CREATE TABLE rules AS SELECT Branch, Franchise, PartNumber, MinimumQty
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartStockingRules')}')""")
    window_start = add_months(current_month, -(WINDOW_MONTHS - 1))
    con.execute(f"""CREATE TABLE hist AS SELECT Branch, Franchise, PartNumber, MonthStart, SalesQty, RequestCount
                    FROM delta_scan('{_path(a.tier, 'staging', 'Silver_PartSalesHistory')}')
                    -- only speeds the read; the rule's window is applied in EXPECTED_SQL
                    WHERE MonthStart >= DATE '{window_start}'""")
    con.execute(f"""CREATE TABLE matrix AS SELECT CAST(MonthCount AS INTEGER) MonthCount, CAST(DemandL AS DOUBLE) DemandL,
                    CAST(DemandH AS DOUBLE) DemandH, CAST(SalesL AS DOUBLE) SalesL, CAST(SalesH AS DOUBLE) SalesH,
                    CAST(Modifier AS DOUBLE) Modifier, CAST(WarehouseMin AS INTEGER) WarehouseMin
                    FROM read_csv('{MATRIX_CSV.as_posix()}', header=true, all_varchar=true)""")
    con.execute(f"""CREATE TABLE settings AS SELECT Id, Branch, Franchise, PartNumber, MinOverride, Masked,
                    MaskExpires, Modified FROM delta_scan('{_path(a.tier, 'staging', 'NonJD_PartSettings')}')""")
    con.execute(f"""CREATE TABLE transfers AS SELECT RequestingBranch, PartNumber, OpenQty
                    FROM delta_scan('{_path(a.tier, 'presentation', 'Fact_OutstandingTransfers')}')""")
    con.execute("CREATE TABLE expected AS " + EXPECTED_SQL, _params(current_month, today))
    con.execute(f"""CREATE TABLE gold AS SELECT Branch, Franchise, PartNumber, MonthCount, StockingTarget,
                    RecommendedOrderQty, SurplusQty, InboundTransferQty, Status FROM delta_scan('{gold_p}')""")
    result = compare(con, "gold", "expected")
    print(result)
    if any(result.values()):
        print(con.execute(f"""SELECT g.*, e.MonthCount e_mc, e.StockingTarget e_target, e.RecommendedOrderQty e_rec,
                                     e.SurplusQty e_surplus, e.InboundTransferQty e_inbound, e.Status e_status
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
