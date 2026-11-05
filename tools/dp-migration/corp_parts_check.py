# tools/dp-migration/corp_parts_check.py
"""
SPI Parts Hub Inventory reports: independent check of Fact_CorpParts_JD and Fact_CorpParts_JD_Idle, the MLPF Gaps,
Border Stores and 2 & 4 Cotton lists and the workbook compare.

Re-implements Fact_CorpParts_JD in DuckDB SQL over the same inputs (Silver_PartInformation, Silver_InTrans,
Silver_PartStockingRules, CommodityCodeGroups) and compares row by row with the Gold table Build_Gold_NonJD_Reorder
(Part 5) wrote. The rules are Plan L (docs/superpowers/plans/2026-11-03-spi-parts-hub-inventory-reports.md,
decisions L-D10..L-D14), taken from the workbook query projects/corp parts excel reports/MLPF Gaps/MLPF Gaps.pq:

- Corp demand = one invoice for the Branch + part, net of its credits. Franchise D InTrans only (trimmed, upper).
  Invoices (Type 'I', Qty > 0) dated [now - 18 months, now - 7 days]; credits (Type 'C', Qty < 0) dated
  [now - 18 months, now]. Grouped by upper(trim(Branch)), upper(trim(PartNumber)) (SQL Anywhere compares
  case-insensitively; a few part records are stored lower-case) and the invoice key (trim(RONumber) for
  'I', trim(OriginalInvoiceNo) for 'C'); an invoice counts when its net qty > 0 and it has an 'I' line.
  "now - 18 months" keeps the time of day; a day past the month's end becomes its last day (SQL Anywhere DATEADD).
- "now" is Central wall clock, the way Equip stores TransDatetime: Silver holds that wall clock in a TIMESTAMPTZ
  labelled UTC, so the session is UTC and TransDatetime is cast to a naive TIMESTAMP (= the wall clock) before the
  window is applied. By default "now" is Gold's DemandAsOf (exactly one value); --as-of overrides it.
- Part rows: Silver_PartInformation franchise D at Silver's grain (trailing-space twins stay two rows, each with
  the trimmed part's demand); PackageQty = TRY_CAST(trim(PackageQty) AS DECIMAL(12,2)); ReturnIndicator =
  trim(Returnable); CommodityGroup from CommodityCodeGroups on upper(trim(code)), 'Other' when unmapped; Min/Max from
  Silver_PartStockingRules on the full key as stored; CorpDemands 0 when none; active = OnHand <> 0 or OnOrder > 0
  or Sales12 + SalesPrev12 <> 0 or CorpDemands > 0 (NULL = 0).
- MLPF Gaps (L-D19, the app's semantics): Branch is not 12, CorpDemands = 2, OnHand < 1, OnOrder = 0,
  PackageQty = 1, ReturnIndicator is R, Source is not AN (a blank Source passes), SLC doesn't start with
  21/90/91/99 (a blank SLC passes), SuperTo blank. Text trimmed, case-insensitive. Workbook columns, sorted by
  PartNumber then Branch.

Plan M (docs/superpowers/plans/2026-11-03-spi-parts-hub-cross-branch-reports.md, M-D8 / M-D9):
- Idle rows (Fact_CorpParts_JD_Idle) = every Silver franchise D record the active filter leaves out, IDLE_COLS.
  Active and idle must be disjoint and together cover Silver franchise D (checked on the reference); Gold idle is
  compared with the reference when the table exists.
- Border Stores and 2 & 4 Cotton, from the workbook code (projects/corp parts excel reports/Border Stores/ and
  2 & 4 Cotton & Stripper Parts/), over the reference's active + idle rows (jd_all). The six part filters =
  COALESCE(OnOrder, 0) = 0, PackageQty = 1, ReturnIndicator R, Source not AN, SLC not 21/90/91/99..., SuperTo
  blank. Pool = one entry per (upper(trim(PartNumber)), upper(trim(Branch))) at branches other than 2 and 4 where
  any of its rows passes the six filters (2 & 4 Cotton: and the cotton rule), demand = MAX(CorpDemands) over the
  passing rows, so trailing-space twins at one branch count once (M-D8; Gold gives twins the trimmed part's demand,
  and the workbook's SQL Anywhere GROUP BY sees one row per branch). A candidate's OtherBranchDemands = the sum of
  those demands over the part's other branches; OtherLocationCount = how many of those branches have demand >= 1.
  Border Stores candidates: branch 95, 91 or 96, CorpDemands >= 1,
  OnHand < 1, the six filters. 2 & 4 Cotton: branch 2 or 4, CorpDemands = 0, OnHand < 1, the six filters, the
  cotton rule. Both: OtherBranchDemands >= 10 and OtherLocationCount >= 5. Cotton rule = own DealerGroupCode
  (trimmed, upper) COTTON / STRIPPER / PICKER, or any franchise D record of the part (active or idle, any branch)
  coded 690 / 770 / CS690 / JDCS690.
  Workbook behaviour not reproduced (the app can't either): its jdis join has no franchise (a non-D record at the
  branch can add or change a row), its model-code list reads every franchise, and its part numbers match exactly
  where the reference trims.

Plan O (docs/superpowers/plans/2026-11-04-spi-parts-hub-corporate-stocking.md, O-D4 / O-D8 / O-D9):
- Corporate Stocking (--report stocking, projects/corp parts excel reports/SPI Corparate Stocking/), one row per part
  (upper(trim(PartNumber))) over jd_all: see stocking_rows. --compare-xlsx keys it on the trimmed, upper-case
  PartNumber and compares Description ignoring case (SQL Anywhere's MAX picks any case variant).

Plan R (docs/superpowers/plans/2026-11-05-spi-parts-hub-pieces-in-set.md, R-D2 / R-D3 / R-D6 / R-D7):
- Pieces In Set (--report pis, pis3, pisreview; projects/corp parts excel reports/SPI-Pieces In Set/): the queries'
  InvoiceQty .. Ranked over the same 18 months through "now" (no 7-day lag), computed at every branch, the reports
  leaving out 2 and 4: see build_pis_stats. The record per Branch + upper(trim(part)) is franchise D's (R-D6), longest
  description, then the smallest, then the smallest part number as stored (R-D7), and Super To is that record's: the
  app's semantics. The workbook's joins read any franchise; pis_franchise_rows lists the rows that changes (R-D6).
- Gold's seven columns are compared with the reference over every active record when Gold has them (--check-pis-gold
  makes their absence a failure), and no idle record may qualify for a list, i.e. hold 3+ invoices. An idle record CAN
  hold fewer (about 500 at any time, Prod 2026-11-05): a first sale inside Corp demands' 7-day lag, on a part with no
  stock and sales counters at 0. They carry no stats and no report needs them, so they're only counted.
- Sheets: pis = Data, pis3 = 'SPI - Pieces In Set ' (trailing space; the first tab only catches up with Data on the
  second Refresh All), pisreview = 'SPI -Pieces In Set Review'. Numbers tolerate 0.05 (Match % is rounded to 1 dp,
  Excel's Months of Supply isn't).

Usage:
    python corp_parts_check.py --tier dev                      # compare with Gold, exit 1 on any mismatch
    python corp_parts_check.py --tier dev --mlpf-out mlpf.csv
    python corp_parts_check.py --tier prod --groups-tier dev --as-of "2026-11-03 09:41:00" \\
        --compare-xlsx "MLPF Gaps.xlsx" [--sheet "MLPF Gaps"] --diff-out diff.csv --mlpf-out mlpf.csv
    python corp_parts_check.py --tier prod --report border --as-of "2026-11-03 14:34:00" \\
        --compare-xlsx "Border Stores.xlsx" --diff-out diff.csv --report-out border.csv
    python corp_parts_check.py --tier prod --report stocking --as-of "2026-11-04 15:03:00" \\
        --compare-xlsx "SPI Corparate Stocking.xlsx" --diff-out diff.csv --report-out stocking.csv
    python corp_parts_check.py --tier prod --groups-tier prod --report pis --as-of "2026-11-05 15:15:00" \\
        --compare-xlsx "SPI - Pieces In Set.xlsx" --diff-out diff.csv --report-out pis.csv

--groups-tier reads CommodityCodeGroups from another tier (Prod doesn't have it until L1 is released). Without
Gold (a tier the Part 5 build hasn't run on) give --as-of: the Gold compare is skipped and the MLPF list comes
from the reference table. Run straight after the DP refresh: Silver is read live.

Auth: Azure CLI (az login as Brian), read-only.
"""
import argparse
import csv
import os
import sys
import tempfile
from datetime import datetime, timedelta
from decimal import Decimal

import duckdb

TIERS = {
    "dev": {"staging": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"),
            "presentation": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")},
    "prod": {"staging": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
             "presentation": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f")},
}
GOLD_TABLE = "Fact_CorpParts_JD"
KEYS = ["Branch", "Franchise", "PartNumber"]
TEXT_COLS = ["Description", "ReturnIndicator", "Source", "SLC", "SuperTo", "CommodityCode", "CommodityGroup",
             "DealerGroupCode"]
NUM_COLS = ["Cost", "OnHand", "OnOrder", "PackageQty", "MinimumQty", "MaximumQty", "Sales12", "SalesPrev12",
            "CorpDemands"]
OUTPUT_COLS = ["Branch", "Franchise", "PartNumber", "Description", "Cost", "OnHand", "OnOrder", "PackageQty",
               "ReturnIndicator", "Source", "SLC", "SuperTo", "CommodityCode", "CommodityGroup", "DealerGroupCode",
               "MinimumQty", "MaximumQty", "Sales12", "SalesPrev12", "CorpDemands"]
TOLERANCE = 0.005
MLPF_COLUMNS = ["Branch", "PartNumber", "Description", "Cost", "Source", "SLC", "CommodityCode", "CommodityGroup",
                "DealerGroupCode", "OnOrder", "OnHandQty", "Demands"]
MLPF_NUM = ["Cost", "OnOrder", "OnHandQty", "Demands"]
IDLE_TABLE = "Fact_CorpParts_JD_Idle"
IDLE_COLS = ["Branch", "Franchise", "PartNumber", "Description", "Cost", "PackageQty", "ReturnIndicator", "Source",
             "SLC", "SuperTo", "CommodityCode", "CommodityGroup", "DealerGroupCode", "MinimumQty", "MaximumQty"]
IDLE_TEXT = [c for c in TEXT_COLS if c in IDLE_COLS]
IDLE_NUM = [c for c in NUM_COLS if c in IDLE_COLS]
REPORT_COLUMNS = MLPF_COLUMNS + ["OtherBranchDemands", "OtherLocationCount"]
REPORT_NUM = MLPF_NUM + ["OtherBranchDemands", "OtherLocationCount"]
POOL_EXCLUDED_BRANCHES = ("2", "4")
OTHER_DEMANDS_MIN = 10
OTHER_BRANCHES_MIN = 5
COTTON_GROUPS = ("COTTON", "STRIPPER", "PICKER")
COTTON_MODEL_CODES = ("690", "770", "CS690", "JDCS690")
STOCKING_COLUMNS = ["PartNumber", "Description", "Cost", "Source", "SLC", "CommodityCode", "DealerGroupCode",
                    "OnOrder", "OnHandQty", "R18 Demands", "Count of Locations with Demands",
                    "Locations with Demands"]
STOCKING_NUM = ["Cost", "OnOrder", "OnHandQty", "R18 Demands", "Count of Locations with Demands"]
STOCKING_BRANCHES_MIN = 3
BRANCH_KEY = ("Branch", "PartNumber")
PIS_COLUMNS = ["Branch", "Part #", "Description", "Source", "SLC", "Commodity Code", "Dealer Group Code", "SPI PIS",
               "Match %", "Invoices", "Demands", "Sales Qty", "Bin Qty", "On Order Qty", "Cost", "Round Up",
               "Recommended Qty", "Recommended Cost", "Tier", "PIS Class", "Stock Position", "Months of Supply",
               "Coverage Flag"]
PIS_NUM = ["SPI PIS", "Match %", "Invoices", "Demands", "Sales Qty", "Bin Qty", "On Order Qty", "Cost", "Round Up",
           "Recommended Qty", "Recommended Cost", "Stock Position", "Months of Supply"]
PIS_REVIEW_COLUMNS = ["Branch", "Part #", "Description", "Source", "SLC", "Commodity Code", "Dealer Group Code",
                      "InMaster PIS", "Most Common Qty", "Match %", "PIS Multiple %", "Invoices", "Demands",
                      "Sales Qty"]
PIS_REVIEW_NUM = ["InMaster PIS", "Most Common Qty", "Match %", "PIS Multiple %", "Invoices", "Demands", "Sales Qty"]
PIS_GOLD_COLS = ["BinQty", "PiecesInSet", "PisInvoices", "PisSalesQty", "PisQty", "PisQtyInvoices",
                 "PisMultipleInvoices"]
PIS_MONTHS = 18
PIS_MIN_INVOICES = 3
PIS_MATCH_MIN = 75
PIS_TOLERANCE = 0.05
_PIS_REPORT = {"key": ("Branch", "Part #"), "upper_key": True, "nocase": ("Description",), "tolerance": PIS_TOLERANCE}
REPORTS = {
    "mlpf": {"sheet": "MLPF Gaps", "columns": MLPF_COLUMNS, "num": MLPF_NUM},
    "border": {"sheet": "Border Stores", "columns": REPORT_COLUMNS, "num": REPORT_NUM,
               "branches": ("95", "91", "96"), "demand": "CorpDemands >= 1", "cotton": False},
    "cotton": {"sheet": "2 & 4 Cotton & Stripper Parts", "columns": REPORT_COLUMNS, "num": REPORT_NUM,
               "branches": ("2", "4"), "demand": "CorpDemands = 0", "cotton": True},
    # one row per part (Plan O): keyed on the part alone, upper case for matching; case-blind description (O-D4)
    "stocking": {"sheet": "SPI Corparate Stocking", "columns": STOCKING_COLUMNS, "num": STOCKING_NUM,
                 "key": ("PartNumber",), "upper_key": True, "nocase": ("Description",)},
    # Plan R: the workbook's three lists
    "pis": {"sheet": "Data", "columns": PIS_COLUMNS, "num": PIS_NUM, **_PIS_REPORT},
    "pis3": {"sheet": "SPI - Pieces In Set ", "columns": PIS_COLUMNS, "num": PIS_NUM, **_PIS_REPORT},
    "pisreview": {"sheet": "SPI -Pieces In Set Review", "columns": PIS_REVIEW_COLUMNS, "num": PIS_REVIEW_NUM,
                  **_PIS_REPORT},
}
DEMAND_MONTHS = 18
INVOICE_LAG_DAYS = 7


def add_months_dt(dt: datetime, n: int) -> datetime:
    """dt plus n months, keeping the day and time of day; a day past the target month's end becomes its last day."""
    y, m = divmod(dt.year * 12 + (dt.month - 1) + n, 12)
    m += 1
    nxt = datetime(y + (m == 12), m % 12 + 1, 1)
    last = (nxt - timedelta(days=1)).day
    return dt.replace(year=y, month=m, day=min(dt.day, last))


def window(now: datetime) -> tuple:
    """(window start, last invoice time, last credit time), all Central wall clock."""
    return add_months_dt(now, -DEMAND_MONTHS), now - timedelta(days=INVOICE_LAG_DAYS), now


def _ts(dt: datetime) -> str:
    return f"TIMESTAMP '{dt.strftime('%Y-%m-%d %H:%M:%S')}'"


ACTIVE_SQL = """(coalesce(p.QuantityOnHand, 0) <> 0 OR coalesce(p.OnOrder, 0) > 0
                 OR coalesce(p.Current12MoSales, 0) + coalesce(p.Previous12MoSales, 0) <> 0
                 OR coalesce(cd.CorpDemands, 0) > 0)"""


def build_expected(con, now: datetime) -> None:
    """Create corp_demands (b, p, CorpDemands), jd_all (every franchise D record: OUTPUT_COLS + Active), expected
    (the active rows, OUTPUT_COLS) and expected_idle (the rest, IDLE_COLS) from the tables parts, intrans, rules and
    groups. intrans.TransDatetime is a naive TIMESTAMP holding Equip's Central wall clock."""
    ws, ie, ce = window(now)
    dup = con.execute("""SELECT upper(trim(CommodityCode)) AS cc, count(*) AS n FROM groups
                         WHERE coalesce(upper(trim(CommodityCode)), '') <> ''
                         GROUP BY 1 HAVING count(*) > 1 ORDER BY 1 LIMIT 5""").fetchall()
    if dup:
        raise ValueError("CommodityCodeGroups has codes with more than one row (trimmed, upper-case): "
                         + ", ".join(f"{c!r} x{n}" for c, n in dup))
    fan = con.execute("""SELECT count(*) FROM parts p JOIN rules r
                         ON r.Branch = p.Branch AND r.Franchise = p.Franchise AND r.PartNumber = p.PartNumber
                         WHERE upper(trim(p.Franchise)) = 'D'""").fetchone()[0]
    keys = con.execute("""SELECT count(DISTINCT (p.Branch, p.Franchise, p.PartNumber)) FROM parts p JOIN rules r
                          ON r.Branch = p.Branch AND r.Franchise = p.Franchise AND r.PartNumber = p.PartNumber
                          WHERE upper(trim(p.Franchise)) = 'D'""").fetchone()[0]
    if fan != keys:
        raise ValueError(f"Silver_PartStockingRules has more than one row for some JD part keys ({fan:,} joined "
                         f"rows for {keys:,} keys)")
    con.execute(f"""
        CREATE OR REPLACE TABLE corp_demands AS
        WITH tx AS (
            SELECT upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS p,
                   CASE WHEN upper(trim(Type)) = 'I' THEN trim(RONumber) ELSE trim(OriginalInvoiceNo) END AS inv,
                   Qty, upper(trim(Type)) = 'I' AS is_inv
            FROM intrans
            WHERE upper(trim(Franchise)) = 'D'
              AND TransDatetime >= {_ts(ws)}
              AND ((upper(trim(Type)) = 'I' AND Qty > 0 AND TransDatetime <= {_ts(ie)})
                OR (upper(trim(Type)) = 'C' AND Qty < 0 AND TransDatetime <= {_ts(ce)}))
        ), invoices AS (
            SELECT b, p, inv FROM tx GROUP BY b, p, inv HAVING sum(Qty) > 0 AND bool_or(is_inv)
        )
        SELECT b, p, CAST(count(*) AS INTEGER) AS CorpDemands FROM invoices GROUP BY b, p
    """)
    con.execute(f"""
        CREATE OR REPLACE TABLE jd_all AS
        WITH g AS (
            SELECT upper(trim(CommodityCode)) AS cc, CommodityGroup AS cg FROM groups
            WHERE coalesce(upper(trim(CommodityCode)), '') <> ''
        )
        SELECT p.Branch, p.Franchise, p.PartNumber, p.Description, p.Cost,
               p.QuantityOnHand AS OnHand, p.OnOrder,
               TRY_CAST(trim(p.PackageQty) AS DECIMAL(12,2)) AS PackageQty,
               trim(p.Returnable) AS ReturnIndicator, p.Source, p.SLC, p.SuperTo, p.CommodityCode,
               coalesce(g.cg, 'Other') AS CommodityGroup, p.DealerGroupCode, r.MinimumQty, r.MaximumQty,
               p.Current12MoSales AS Sales12, p.Previous12MoSales AS SalesPrev12,
               CAST(coalesce(cd.CorpDemands, 0) AS INTEGER) AS CorpDemands, {ACTIVE_SQL} AS Active
        FROM parts p
        LEFT JOIN rules r ON r.Branch = p.Branch AND r.Franchise = p.Franchise AND r.PartNumber = p.PartNumber
        LEFT JOIN corp_demands cd ON cd.b = upper(trim(p.Branch)) AND cd.p = upper(trim(p.PartNumber))
        LEFT JOIN g ON g.cc = upper(trim(p.CommodityCode))
        WHERE upper(trim(p.Franchise)) = 'D'
    """)
    con.execute(f"CREATE OR REPLACE TABLE expected AS SELECT {', '.join(OUTPUT_COLS)} FROM jd_all WHERE Active")
    con.execute(f"CREATE OR REPLACE TABLE expected_idle AS SELECT {', '.join(IDLE_COLS)} FROM jd_all WHERE NOT Active")


def idle_checks(con, active: str = "expected", idle: str = "expected_idle") -> dict:
    """Counts for the active / idle split: Silver franchise D records, active rows, idle rows, keys in both, and
    duplicate idle keys."""
    keys = ", ".join(KEYS)
    q = lambda sql: con.execute(sql).fetchone()[0]
    return {
        "silver_d": q("SELECT count(*) FROM parts WHERE upper(trim(Franchise)) = 'D'"),
        "active": q(f"SELECT count(*) FROM {active}"),
        "idle": q(f"SELECT count(*) FROM {idle}"),
        "overlap": q(f"SELECT count(*) FROM (SELECT {keys} FROM {active} INTERSECT SELECT {keys} FROM {idle})"),
        "dup_idle": q(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {idle}"),
    }


def idle_problems(res: dict) -> list:
    out = []
    if res["overlap"]:
        out.append(f"{res['overlap']:,} keys are in both the active and the idle table")
    if res["dup_idle"]:
        out.append(f"the idle table has {res['dup_idle']:,} duplicate keys")
    if res["active"] + res["idle"] != res["silver_d"]:
        out.append(f"active {res['active']:,} + idle {res['idle']:,} = {res['active'] + res['idle']:,} rows don't "
                   f"cover Silver's {res['silver_d']:,} franchise D records exactly")
    return out


MLPF_WHERE = """upper(trim(Branch)) <> '12' AND CorpDemands = 2 AND OnHand < 1 AND OnOrder = 0 AND PackageQty = 1
    AND upper(trim(ReturnIndicator)) = 'R' AND coalesce(upper(trim(Source)), '') <> 'AN'
    AND NOT (coalesce(trim(SLC), '') LIKE '21%' OR coalesce(trim(SLC), '') LIKE '90%'
             OR coalesce(trim(SLC), '') LIKE '91%' OR coalesce(trim(SLC), '') LIKE '99%')
    AND coalesce(trim(SuperTo), '') = ''"""


PART_FILTERS = """coalesce(OnOrder, 0) = 0 AND PackageQty = 1 AND upper(trim(ReturnIndicator)) = 'R'
    AND coalesce(upper(trim(Source)), '') <> 'AN'
    AND NOT (coalesce(trim(SLC), '') LIKE '21%' OR coalesce(trim(SLC), '') LIKE '90%'
             OR coalesce(trim(SLC), '') LIKE '91%' OR coalesce(trim(SLC), '') LIKE '99%')
    AND coalesce(trim(SuperTo), '') = ''"""


def _in_list(vals) -> str:
    return ", ".join("'" + v.replace("'", "''") + "'" for v in vals)


def report_rows(con, name: str, source: str = "jd_all") -> list:
    """The named report's rows (REPORTS[name]["columns"], text trimmed, sorted by PartNumber then Branch). 'mlpf' is
    mlpf_rows over `expected`; Border Stores and 2 & 4 Cotton are computed over `source` (active + idle rows with
    OUTPUT_COLS) per the workbook code (module docstring)."""
    if name == "mlpf":
        return mlpf_rows(con, "expected" if source == "jd_all" else source)
    if name == "stocking":
        return stocking_rows(con, source)
    if name == "pis":
        return pis_rows(con)
    if name == "pis3":
        return pis3_rows(con)
    if name == "pisreview":
        return pis_review_rows(con)
    rep = REPORTS[name]
    cotton = " AND cotton" if rep["cotton"] else ""
    cur = con.execute(f"""
        WITH r AS (
            SELECT *, upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS k,
                   coalesce(upper(trim(DealerGroupCode)), '') AS dg, row_number() OVER () AS rid
            FROM {source}
        ), model AS (
            SELECT DISTINCT k FROM r WHERE dg IN ({_in_list(COTTON_MODEL_CODES)})
        ), f AS (
            SELECT r.*, coalesce({PART_FILTERS}, false) AS ok,
                   (dg IN ({_in_list(COTTON_GROUPS)}) OR k IN (SELECT k FROM model)) AS cotton
            FROM r
        ), pool AS (
            SELECT b, k, max(CorpDemands) AS CorpDemands FROM f
            WHERE ok AND b NOT IN ({_in_list(POOL_EXCLUDED_BRANCHES)}){cotton}
            GROUP BY b, k
        ), cand AS (
            SELECT * FROM f
            WHERE ok AND b IN ({_in_list(rep['branches'])}) AND {rep['demand']} AND OnHand < 1{cotton}
        ), fig AS (
            SELECT c.rid, CAST(coalesce(sum(p.CorpDemands), 0) AS INTEGER) AS od,
                   CAST(count(p.k) FILTER (WHERE p.CorpDemands >= 1) AS INTEGER) AS ol
            FROM cand c LEFT JOIN pool p ON p.k = c.k AND p.b <> c.b
            GROUP BY c.rid
        )
        SELECT trim(c.Branch) AS Branch, trim(c.PartNumber) AS PartNumber, trim(c.Description) AS Description,
               c.Cost, trim(c.Source) AS Source, trim(c.SLC) AS SLC, trim(c.CommodityCode) AS CommodityCode,
               trim(c.CommodityGroup) AS CommodityGroup, trim(c.DealerGroupCode) AS DealerGroupCode, c.OnOrder,
               c.OnHand AS OnHandQty, c.CorpDemands AS Demands, fig.od AS OtherBranchDemands,
               fig.ol AS OtherLocationCount
        FROM cand c JOIN fig USING (rid)
        WHERE fig.od >= {OTHER_DEMANDS_MIN} AND fig.ol >= {OTHER_BRANCHES_MIN}""")
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    rows.sort(key=lambda r: (r["PartNumber"] or "", r["Branch"] or ""))
    return rows


STOCKING_FILTERS = """PackageQty = 1 AND upper(trim(ReturnIndicator)) = 'R'
    AND coalesce(upper(trim(Source)), '') <> 'AN'
    AND NOT (coalesce(trim(SLC), '') LIKE '21%' OR coalesce(trim(SLC), '') LIKE '90%'
             OR coalesce(trim(SLC), '') LIKE '91%' OR coalesce(trim(SLC), '') LIKE '99%')"""


def _branch_order(col: str) -> str:
    """ORDER BY terms for O-D9 branch order: numeric codes by number, then the others by code (ordinal)."""
    return f"TRY_CAST({col} AS BIGINT) IS NULL, TRY_CAST({col} AS BIGINT), {col}"


def stocking_rows(con, source: str = "jd_all") -> list:
    """Corporate Stocking (Plan O, the workbook SPI Corparate Stocking.pq): one row per part (upper(trim(PartNumber)))
    with STOCKING_COLUMNS, sorted by location count desc, R18 Demands desc, PartNumber.

    Counted records = `source` records at branches other than 2 and 4 that pass STOCKING_FILTERS; the part needs at
    least one, and every one must have on hand = 0, on order = 0 and a blank Super To. Text columns = the largest
    trimmed value over the counted records, Cost = the largest (O-D8); Description = the largest ignoring case, among
    case variants the one at the lowest branch (O-D4, O-D9); PartNumber = trimmed, from the first counted record in
    branch order. Demand comes from corp_demands at any branch other than 2 and 4, whatever its record looks like:
    R18 Demands = the sum, at least STOCKING_BRANCHES_MIN branches, listed in branch order."""
    excluded = _in_list(POOL_EXCLUDED_BRANCHES)
    cur = con.execute(f"""
        WITH c AS (
            SELECT *, upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS k, trim(Description) AS d,
                   trim(PartNumber) AS pn
            FROM {source}
            WHERE upper(trim(Branch)) NOT IN ({excluded}) AND coalesce({STOCKING_FILTERS}, false)
        ), eligible AS (
            SELECT k, max(Cost) AS "Cost", max(trim(Source)) AS "Source", max(trim(SLC)) AS "SLC",
                   max(trim(CommodityCode)) AS "CommodityCode", max(trim(DealerGroupCode)) AS "DealerGroupCode"
            FROM c
            GROUP BY k
            HAVING count(*) FILTER (WHERE coalesce(OnHand, 0) <> 0) = 0
               AND count(*) FILTER (WHERE coalesce(OnOrder, 0) <> 0) = 0
               AND count(*) FILTER (WHERE coalesce(trim(SuperTo), '') <> '') = 0
        ), ranked AS (
            SELECT k, d, pn,
                   row_number() OVER (PARTITION BY k ORDER BY upper(d) DESC NULLS LAST, {_branch_order('b')}, d)
                       AS desc_rank,
                   row_number() OVER (PARTITION BY k ORDER BY {_branch_order('b')}, pn) AS part_rank
            FROM c
        ), names AS (
            SELECT k, max(d) FILTER (WHERE desc_rank = 1) AS "Description",
                   max(pn) FILTER (WHERE part_rank = 1) AS "PartNumber"
            FROM ranked GROUP BY k
        ), demand AS (
            SELECT p AS k, CAST(sum(CorpDemands) AS INTEGER) AS dm, CAST(count(*) AS INTEGER) AS n,
                   string_agg(b, ', ' ORDER BY {_branch_order('b')}) AS locs
            FROM corp_demands
            WHERE b NOT IN ({excluded}) AND CorpDemands >= 1
            GROUP BY p
            HAVING count(*) >= {STOCKING_BRANCHES_MIN}
        )
        SELECT n."PartNumber", n."Description", e."Cost", e."Source", e."SLC", e."CommodityCode",
               e."DealerGroupCode", 0 AS "OnOrder", 0 AS "OnHandQty", dm.dm AS "R18 Demands",
               dm.n AS "Count of Locations with Demands", dm.locs AS "Locations with Demands"
        FROM eligible e JOIN names n USING (k) JOIN demand dm USING (k)
        ORDER BY dm.n DESC, dm.dm DESC, n."PartNumber", k""")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def build_pis_stats(con, now: datetime) -> None:
    """Pieces In Set (Plan R), from parts, intrans and inmaster. Creates:
    pis_invoices (b, p, inv, q): one row per invoice net of its credits, 18 months through now, every branch;
    inmaster_pis (b, p, pieces): MAX(PiecesInSet) over franchise D's rows of the Branch + part;
    pis_stats (b, p, PisQty, PisQtyInvoices, PisInvoices, PisSalesQty, PisMultipleInvoices): the queries' QtyCounts,
      PartTotals and Ranked: the most common net quantity, ties to the smaller;
    pis_records: every franchise D part record with b, k and pick (1 = the record that carries the stats, R-D7)."""
    ws = add_months_dt(now, -PIS_MONTHS)
    con.execute(f"""
        CREATE OR REPLACE TABLE pis_invoices AS
        WITH tx AS (
            SELECT upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS p,
                   CASE WHEN upper(trim(Type)) = 'I' THEN trim(RONumber) ELSE trim(OriginalInvoiceNo) END AS inv,
                   Qty, upper(trim(Type)) = 'I' AS is_inv
            FROM intrans
            WHERE upper(trim(Franchise)) = 'D' AND TransDatetime >= {_ts(ws)} AND TransDatetime <= {_ts(now)}
              AND ((upper(trim(Type)) = 'I' AND Qty > 0) OR (upper(trim(Type)) = 'C' AND Qty < 0))
        )
        SELECT b, p, inv, sum(Qty) AS q FROM tx GROUP BY b, p, inv HAVING sum(Qty) > 0 AND bool_or(is_inv)
    """)
    con.execute("""
        CREATE OR REPLACE TABLE inmaster_pis AS
        SELECT upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS p, max(PiecesInSet) AS pieces
        FROM inmaster WHERE upper(trim(Franchise)) = 'D' GROUP BY 1, 2
    """)
    # The modulo in whole hundredths: DuckDB's % on decimals goes through DOUBLE.
    con.execute("""
        CREATE OR REPLACE TABLE pis_stats AS
        WITH qc AS (
            SELECT b, p, q, count(*) AS n FROM pis_invoices GROUP BY b, p, q
        ), totals AS (
            SELECT i.b, i.p, count(*) AS tot, sum(i.q) AS sales,
                   count(*) FILTER (WHERE m.pieces > 1 AND CAST(round(i.q * 100) AS BIGINT)
                                          % CAST(round(m.pieces * 100) AS BIGINT) = 0) AS mult
            FROM pis_invoices i LEFT JOIN inmaster_pis m ON m.b = i.b AND m.p = i.p
            GROUP BY i.b, i.p
        ), ranked AS (
            SELECT *, row_number() OVER (PARTITION BY b, p ORDER BY n DESC, q ASC) AS rn FROM qc
        )
        SELECT r.b, r.p, r.q AS PisQty, CAST(r.n AS INTEGER) AS PisQtyInvoices, CAST(t.tot AS INTEGER) AS PisInvoices,
               t.sales AS PisSalesQty, CAST(t.mult AS INTEGER) AS PisMultipleInvoices
        FROM ranked r JOIN totals t ON t.b = r.b AND t.p = r.p
        WHERE r.rn = 1
    """)
    con.execute("""
        CREATE OR REPLACE TABLE pis_records AS
        SELECT x.*, upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS k,
               row_number() OVER (PARTITION BY upper(trim(Branch)), upper(trim(PartNumber))
                                  ORDER BY length(Description) DESC NULLS LAST, Description ASC, PartNumber ASC,
                                           Branch ASC, Franchise ASC) AS pick
        FROM parts x WHERE upper(trim(Franchise)) = 'D'
    """)


def _pis_fetch(con, sql: str) -> list:
    """Rows as dicts, sorted by Branch then Part # (the workbook's Table.Sort)."""
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    rows.sort(key=lambda r: (r["Branch"] or "", r["Part #"] or ""))
    return rows


_PIS_TEXT = """trim(x.Branch) AS "Branch", trim(x.PartNumber) AS "Part #", trim(x.Description) AS "Description",
               trim(x.Source) AS "Source", trim(x.SLC) AS "SLC", trim(x.CommodityCode) AS "Commodity Code",
               trim(x.DealerGroupCode) AS "Dealer Group Code\""""
_PIS_MATCH = "round(CAST(s.PisQtyInvoices AS DOUBLE) / s.PisInvoices * 100, 1)"
_PIS_RECORD = f"""x.pick = 1 AND x.b NOT IN ({_in_list(POOL_EXCLUDED_BRANCHES)})
              AND s.PisInvoices >= {PIS_MIN_INVOICES}"""


def pis_rows(con) -> list:
    """The main list (PIS_COLUMNS): SPI PIS > 1, Match % >= 75, 3+ invoices, Super To blank, not branch 2 or 4. The
    calculated columns are the workbook's: Bin Qty, not on hand, is the stock (R-D3); zero stock orders one full set."""
    return _pis_fetch(con, f"""
        WITH a AS (
            SELECT {_PIS_TEXT}, s.PisQty AS "SPI PIS", {_PIS_MATCH} AS "Match %", s.PisInvoices AS "Invoices",
                   s.PisInvoices AS "Demands", s.PisSalesQty AS "Sales Qty", coalesce(x.BinQty, 0) AS "Bin Qty",
                   coalesce(x.OnOrder, 0) AS "On Order Qty", x.Cost AS "Cost",
                   CAST(coalesce(x.BinQty, 0) + coalesce(x.OnOrder, 0) AS DOUBLE) AS sp
            FROM pis_records x JOIN pis_stats s ON s.b = x.b AND s.p = x.k
            WHERE {_PIS_RECORD}
              AND s.PisQty > 1 AND {_PIS_MATCH} >= {PIS_MATCH_MIN} AND coalesce(trim(x.SuperTo), '') = ''
        ), b AS (
            SELECT *, CASE WHEN sp = 0 THEN CAST("SPI PIS" AS DOUBLE)
                           ELSE ceil(sp / CAST("SPI PIS" AS DOUBLE)) * CAST("SPI PIS" AS DOUBLE) END AS ru,
                   CASE WHEN "Sales Qty" <> 0 THEN sp / (CAST("Sales Qty" AS DOUBLE) / {PIS_MONTHS}) END AS mos
            FROM a
        )
        SELECT "Branch", "Part #", "Description", "Source", "SLC", "Commodity Code", "Dealer Group Code", "SPI PIS",
               "Match %", "Invoices", "Demands", "Sales Qty", "Bin Qty", "On Order Qty", "Cost", ru AS "Round Up",
               ru - sp AS "Recommended Qty", CAST("Cost" AS DOUBLE) * (ru - sp) AS "Recommended Cost",
               CASE WHEN "Invoices" <= 3 THEN '4 - Thin'
                    WHEN "Match %" >= 90 AND "Invoices" >= 10 THEN '1 - Act Now'
                    WHEN "Match %" >= 80 AND "Invoices" >= 5 THEN '2 - Likely'
                    ELSE '3 - Review' END AS "Tier",
               CASE WHEN "SPI PIS" >= 50 THEN 'Box / Bulk Qty' WHEN "SPI PIS" <= 12 THEN 'Set'
                    ELSE 'Large Multiple' END AS "PIS Class",
               sp AS "Stock Position", mos AS "Months of Supply",
               CASE WHEN sp = 0 THEN 'Out of Stock' WHEN "Sales Qty" = 0 THEN 'No Sales' WHEN mos < 1 THEN 'Thin'
                    WHEN mos <= 6 THEN 'Healthy' ELSE 'Overstocked' END AS "Coverage Flag"
        FROM b""")


def pis3_rows(con) -> list:
    """3 Months or Less: the main list with Months of Supply <= 3; a blank fails, as the workbook's number test does."""
    return [r for r in pis_rows(con) if r["Months of Supply"] is not None and r["Months of Supply"] <= 3]


def pis_review_rows(con) -> list:
    """Review (PIS_REVIEW_COLUMNS): InMaster PIS > 1, Match % < 75, 3+ invoices, not branch 2 or 4. Super To doesn't
    matter here, as in the query."""
    return _pis_fetch(con, f"""
        SELECT {_PIS_TEXT}, m.pieces AS "InMaster PIS", s.PisQty AS "Most Common Qty", {_PIS_MATCH} AS "Match %",
               round(CAST(s.PisMultipleInvoices AS DOUBLE) / s.PisInvoices * 100, 1) AS "PIS Multiple %",
               s.PisInvoices AS "Invoices", s.PisInvoices AS "Demands", s.PisSalesQty AS "Sales Qty"
        FROM pis_records x JOIN pis_stats s ON s.b = x.b AND s.p = x.k
        JOIN inmaster_pis m ON m.b = x.b AND m.p = x.k
        WHERE {_PIS_RECORD} AND m.pieces > 1 AND {_PIS_MATCH} < {PIS_MATCH_MIN}""")


def pis_franchise_rows(con) -> list:
    """R-D6: the rows that pass the main list's statistics tests where the query's jdis join (any franchise) can read
    a different record from the app (franchise D's): a non-D record ranks first on the query's ORDER BY (LEN then
    description, ignoring case, as SQL Anywhere compares; on an exact tie the query's pick is arbitrary) and differs
    from D's in Bin, On Order or Cost, or has no D record to compare, or a non-D record's Super To drops the row from
    the workbook. "Query" columns are the non-D record, "D" what the app reads."""
    return _pis_fetch(con, f"""
        WITH anyf AS (
            SELECT *, upper(trim(Branch)) AS b, upper(trim(PartNumber)) AS k,
                   max(CASE WHEN coalesce(trim(SuperTo), '') <> '' THEN 1 ELSE 0 END)
                       OVER (PARTITION BY upper(trim(Branch)), upper(trim(PartNumber))) AS sup,
                   rank() OVER (PARTITION BY upper(trim(Branch)), upper(trim(PartNumber))
                                ORDER BY length(Description) DESC NULLS LAST, upper(Description) ASC) AS jrank
            FROM parts
        ), other AS (
            SELECT * FROM anyf WHERE upper(trim(Franchise)) <> 'D' OR sup = 1
            QUALIFY row_number() OVER (PARTITION BY b, k
                                       ORDER BY upper(trim(Franchise)) = 'D', jrank, Franchise, PartNumber) = 1
        )
        SELECT trim(q.Branch) AS "Branch", trim(q.PartNumber) AS "Part #", trim(q.Franchise) AS "Query Franchise",
               q.BinQty AS "Query Bin", q.OnOrder AS "Query OnOrder", q.Cost AS "Query Cost",
               q.sup AS "Query Superseded", d.BinQty AS "D Bin", d.OnOrder AS "D OnOrder", d.Cost AS "D Cost",
               trim(d.SuperTo) AS "D SuperTo"
        FROM pis_stats s
        JOIN other q ON q.b = s.b AND q.k = s.p
        LEFT JOIN pis_records d ON d.b = s.b AND d.k = s.p AND d.pick = 1
        WHERE s.b NOT IN ({_in_list(POOL_EXCLUDED_BRANCHES)}) AND s.PisInvoices >= {PIS_MIN_INVOICES} AND s.PisQty > 1
          AND {_PIS_MATCH} >= {PIS_MATCH_MIN}
          AND ((q.sup = 1 AND coalesce(trim(d.SuperTo), '') = '')
               OR (q.jrank = 1 AND upper(trim(q.Franchise)) <> 'D'
                   AND (d.Branch IS NULL OR q.BinQty IS DISTINCT FROM d.BinQty OR q.OnOrder IS DISTINCT FROM d.OnOrder
                        OR q.Cost IS DISTINCT FROM d.Cost)))""")


def build_pis_expected(con) -> None:
    """pis_all: every franchise D record with KEYS + PIS_GOLD_COLS, the stats on the picked record only (R-D7), 0 on
    the others; expected_pis: its active records (needs build_expected and build_pis_stats)."""
    con.execute("""
        CREATE OR REPLACE TABLE pis_all AS
        SELECT x.Branch, x.Franchise, x.PartNumber, x.BinQty, m.pieces AS PiecesInSet,
               CASE WHEN x.pick = 1 THEN coalesce(s.PisInvoices, 0) ELSE 0 END AS PisInvoices,
               CASE WHEN x.pick = 1 THEN coalesce(s.PisSalesQty, 0) ELSE 0 END AS PisSalesQty,
               CASE WHEN x.pick = 1 THEN coalesce(s.PisQty, 0) ELSE 0 END AS PisQty,
               CASE WHEN x.pick = 1 THEN coalesce(s.PisQtyInvoices, 0) ELSE 0 END AS PisQtyInvoices,
               CASE WHEN x.pick = 1 THEN coalesce(s.PisMultipleInvoices, 0) ELSE 0 END AS PisMultipleInvoices
        FROM pis_records x
        LEFT JOIN pis_stats s ON s.b = x.b AND s.p = x.k
        LEFT JOIN inmaster_pis m ON m.b = x.b AND m.p = x.k
    """)
    con.execute("""
        CREATE OR REPLACE TABLE expected_pis AS
        SELECT a.* FROM pis_all a JOIN jd_all j
          ON a.Branch IS NOT DISTINCT FROM j.Branch AND a.Franchise IS NOT DISTINCT FROM j.Franchise
         AND a.PartNumber IS NOT DISTINCT FROM j.PartNumber
        WHERE j.Active
    """)


def pis_idle_rows(con, min_invoices: int = PIS_MIN_INVOICES) -> list:
    """Idle records holding at least `min_invoices` 18-month invoices. At the default, the 3 every list needs, these
    are R-D7's check: Gold refuses to write them, because the idle table doesn't carry the stats and the row would
    leave a report. Should be none."""
    cur = con.execute(f"""
        SELECT a.Branch, a.Franchise, a.PartNumber, a.PisInvoices, a.PisSalesQty, a.PisQty
        FROM pis_all a JOIN jd_all j
          ON a.Branch IS NOT DISTINCT FROM j.Branch AND a.Franchise IS NOT DISTINCT FROM j.Franchise
         AND a.PartNumber IS NOT DISTINCT FROM j.PartNumber
        WHERE NOT j.Active AND a.PisInvoices >= {min_invoices}
        ORDER BY a.Branch, a.PartNumber""")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def mlpf_rows(con, source: str) -> list:
    """The MLPF Gaps list from `source` (Gold or expected): dicts with MLPF_COLUMNS, text trimmed, sorted by
    PartNumber then Branch (ordinal, as the workbook's Table.Sort)."""
    cur = con.execute(f"""
        SELECT trim(Branch) AS Branch, trim(PartNumber) AS PartNumber, trim(Description) AS Description, Cost,
               trim(Source) AS Source, trim(SLC) AS SLC, trim(CommodityCode) AS CommodityCode,
               trim(CommodityGroup) AS CommodityGroup, trim(DealerGroupCode) AS DealerGroupCode, OnOrder,
               OnHand AS OnHandQty, CorpDemands AS Demands
        FROM {source} WHERE {MLPF_WHERE}""")
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    rows.sort(key=lambda r: (r["PartNumber"] or "", r["Branch"] or ""))
    return rows


# ---------------------------------------------------------------------------------------------------------
# Gold compare
# ---------------------------------------------------------------------------------------------------------
def _key_join() -> str:
    return " AND ".join(f"g.{k} IS NOT DISTINCT FROM e.{k}" for k in KEYS)


def _col_diff(col: str, num_cols=NUM_COLS) -> str:
    if col in num_cols:
        return f"((g.{col} IS NULL) <> (e.{col} IS NULL) OR abs(g.{col} - e.{col}) > {TOLERANCE})"
    return f"g.{col} IS DISTINCT FROM e.{col}"


def compare(con, gold: str, expected: str, text_cols=TEXT_COLS, num_cols=NUM_COLS) -> dict:
    keys = ", ".join(KEYS)
    where = " OR ".join(_col_diff(c, num_cols) for c in text_cols + num_cols)
    q = lambda sql: con.execute(sql).fetchone()[0]
    return {
        "only_gold": q(f"SELECT count(*) FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})"),
        "only_expected": q(f"SELECT count(*) FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})"),
        "different": q(f"SELECT count(*) FROM {gold} g JOIN {expected} e ON {_key_join()} WHERE {where}"),
        "dup_gold": q(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {gold}"),
        "dup_expected": q(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {expected}"),
    }


def differences(con, gold: str, expected: str, limit: int = None, text_cols=TEXT_COLS,
                num_cols=NUM_COLS) -> list:
    """Every difference as a dict (Kind, Branch, Franchise, PartNumber, Column, Gold, Expected); Kind is
    only_gold, only_expected or different (one entry per differing column)."""
    keys = ", ".join(KEYS)
    parts = [f"""SELECT 'only_gold' AS Kind, {keys}, '' AS "Column", NULL AS Gold, NULL AS Expected
                 FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})""",
             f"""SELECT 'only_expected', {keys}, '', NULL, NULL
                 FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})"""]
    for c in text_cols + num_cols:
        parts.append(f"""SELECT 'different', g.Branch, g.Franchise, g.PartNumber, '{c}',
                                CAST(g.{c} AS VARCHAR), CAST(e.{c} AS VARCHAR)
                         FROM {gold} g JOIN {expected} e ON {_key_join()} WHERE {_col_diff(c, num_cols)}""")
    sql = " UNION ALL ".join(f"({p})" for p in parts) + ' ORDER BY Kind, Branch, PartNumber, "Column"'
    if limit:
        sql += f" LIMIT {limit}"
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


# ---------------------------------------------------------------------------------------------------------
# workbook compare
# ---------------------------------------------------------------------------------------------------------
def _cell_text(v):
    if v is None:
        return None
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def read_xlsx(path: str, sheet: str, columns=MLPF_COLUMNS, num=REPORT_NUM) -> list:
    """The workbook's table as dicts with `columns` (default the 12 MLPF ones): header = the first row holding all of
    them. Columns in `num` (default REPORT_NUM) stay numbers, the rest become text."""
    import openpyxl
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        ws = wb[sheet]
        rows = ws.iter_rows(values_only=True)
        idx = None
        for row in rows:
            names = [(_cell_text(v) or "").strip() for v in row]
            if all(c in names for c in columns):
                idx = {c: names.index(c) for c in columns}
                break
        if idx is None:
            raise ValueError(f"no header row with {', '.join(columns)} in sheet {sheet!r}")
        out = []
        for row in rows:
            if row is None or all(v is None for v in row):
                continue
            rec = {}
            for c, i in idx.items():
                v = row[i] if i < len(row) else None
                rec[c] = v if c in num else _cell_text(v)
            out.append(rec)
        return out
    finally:
        wb.close()


def _xkey(r: dict, key=BRANCH_KEY, upper: bool = False) -> tuple:
    """The row's trimmed `key` values (upper case with `upper`)."""
    vals = tuple((r[k] or "").strip() for k in key)
    return tuple(v.upper() for v in vals) if upper else vals


def _num_differs(a, b, tolerance: float = TOLERANCE) -> bool:
    if a is None or b is None:
        return (a is None) != (b is None)
    return abs(float(a) - float(b)) > tolerance


def _text_differs(a, b, nocase: bool = False) -> bool:
    a, b = (a or "").strip(), (b or "").strip()
    return a.upper() != b.upper() if nocase else a != b


def compare_xlsx(con, xl_rows: list, ours: list, columns=MLPF_COLUMNS, num=MLPF_NUM, key=BRANCH_KEY,
                 upper_key: bool = False, nocase=(), tolerance: float = TOLERANCE) -> dict:
    """Match the workbook rows to our rows on the trimmed `key` columns (default Branch + PartNumber; upper case
    with `upper_key`) and compare the other `columns` (`num` numerically within `tolerance`, `nocase` ignoring case).
    A key with several rows on a side (the trailing-space twins) compares each pair."""
    xl_by, our_by = {}, {}
    for r in xl_rows:
        xl_by.setdefault(_xkey(r, key, upper_key), []).append(r)
    for r in ours:
        our_by.setdefault(_xkey(r, key, upper_key), []).append(r)
    only_excel = [r for k in sorted(set(xl_by) - set(our_by)) for r in xl_by[k]]
    only_ours = [r for k in sorted(set(our_by) - set(xl_by)) for r in our_by[k]]
    values = []
    for k in sorted(set(xl_by) & set(our_by)):
        for x in xl_by[k]:
            for o in our_by[k]:
                for c in (c for c in columns if c not in key):
                    differs = (_num_differs(x[c], o[c], tolerance) if c in num
                               else _text_differs(x[c], o[c], c in nocase))
                    if differs:
                        values.append({**dict(zip(key, k)), "Column": c, "Excel": x[c], "Ours": o[c]})
    return {"excel_rows": len(xl_rows), "our_rows": len(ours), "matched_keys": len(set(xl_by) & set(our_by)),
            "dup_excel_keys": sum(1 for v in xl_by.values() if len(v) > 1),
            "dup_our_keys": sum(1 for v in our_by.values() if len(v) > 1),
            "only_excel": only_excel, "only_ours": only_ours, "values": values}


def part_context(con, keys: list, now: datetime, tier: str = None) -> dict:
    """For trimmed (Branch, PartNumber) keys: our part rows (every franchise), CorpDemands, the franchise D I/C lines
    from 10 days before the window start, and (with a tier) the last franchise D InTrans line of any type. A
    (PartNumber,) key covers every branch of the part: rows and lines start with the branch, CorpDemands is
    "branch=n, ..." in branch order (O-D9). Results are keyed by the upper-case key."""
    if not keys:
        return {}
    ws, ie, _ = window(now)
    norm = [(None, k[0].upper()) if len(k) == 1 else (k[0].upper(), k[1].upper()) for k in keys]
    con.execute("CREATE OR REPLACE TEMP TABLE ctx_keys (b VARCHAR, p VARCHAR)")
    con.executemany("INSERT INTO ctx_keys VALUES (?, ?)", [list(k) for k in norm])
    out_key = lambda b, p: (p,) if b is None else (b, p)
    out = {out_key(b, p): {"CorpDemands": 0, "Rows": [], "Lines": [], "LastDTrans": None} for b, p in norm}
    match = lambda t: f"(k.b IS NULL OR upper(trim({t}.Branch)) = k.b) AND upper(trim({t}.PartNumber)) = k.p"
    whole = {}
    for kb, p, b, cd in con.execute(f"""
            SELECT k.b, k.p, c.b, c.CorpDemands FROM corp_demands c JOIN ctx_keys k
            ON (k.b IS NULL OR c.b = k.b) AND c.p = k.p
            ORDER BY {_branch_order('c.b')}""").fetchall():
        if kb is None:
            whole.setdefault(p, []).append(f"{b}={cd}")
        else:
            out[(kb, p)]["CorpDemands"] = cd
    for p, items in whole.items():
        out[(p,)]["CorpDemands"] = ", ".join(items)
    for row in con.execute(f"""
            SELECT k.b, k.p, trim(x.Branch), x.Franchise, x.PartNumber, x.QuantityOnHand, x.BinQty, x.OnOrder,
                   x.PackageQty, x.Returnable, x.Source, x.SLC, x.SuperTo, x.Cost
            FROM parts x JOIN ctx_keys k ON {match('x')}
            ORDER BY k.b, k.p, {_branch_order('upper(trim(x.Branch))')}, x.Franchise, x.PartNumber""").fetchall():
        kb, p, br, fr, pn, oh, bin_qty, oo, pkg, ri, src, slc, sup, cost = row
        out[out_key(kb, p)]["Rows"].append(
            ("" if kb else f"{br}|") + f"{fr!s}|{pn!r}|oh={oh}|bin={bin_qty}|oo={oo}|pkg={pkg!r}|ri={ri!r}|src={src!r}"
            f"|slc={slc!r}|super={sup!r}|cost={cost}")
    for kb, p, br, typ, qty, ts, inv in con.execute(f"""
            SELECT k.b, k.p, trim(t.Branch), upper(trim(t.Type)), t.Qty, t.TransDatetime,
                   CASE WHEN upper(trim(t.Type)) = 'I' THEN trim(t.RONumber) ELSE trim(t.OriginalInvoiceNo) END
            FROM intrans t JOIN ctx_keys k ON {match('t')}
            WHERE upper(trim(t.Franchise)) = 'D'
            ORDER BY k.b, k.p, {_branch_order('upper(trim(t.Branch))')}, t.TransDatetime""").fetchall():
        edge = ""
        if ts < ws:
            edge = "<start"
        elif ts - ws < timedelta(days=2):
            edge = "~start"
        elif typ == "I" and ts > ie:
            edge = ">invEnd"
        elif ts > now:
            edge = ">now"
        out[out_key(kb, p)]["Lines"].append(("" if kb else f"{br} ") + f"{typ} {ts:%Y-%m-%d %H:%M} {inv} q={qty}"
                                            f"{(' ' + edge) if edge else ''}")
    if tier:
        src = f"delta_scan('{_path(tier, 'staging', 'Silver_InTrans')}')"
        for kb, p, last in con.execute(f"""
                SELECT k.b, k.p, max(CAST(t.TransDatetime AS TIMESTAMP))
                FROM {src} t JOIN ctx_keys k ON {match('t')}
                WHERE upper(trim(t.Franchise)) = 'D' GROUP BY ALL""").fetchall():
            out[out_key(kb, p)]["LastDTrans"] = last
    return out


# ---------------------------------------------------------------------------------------------------------
# lakehouse I/O
# ---------------------------------------------------------------------------------------------------------
def _path(tier: str, layer: str, table: str) -> str:
    ws, lh = TIERS[tier][layer]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"


def _connect():
    con = duckdb.connect()
    spill = os.path.join(tempfile.gettempdir(), 'corp_parts_check_spill').replace("\\", "/")
    con.execute(f"SET memory_limit='3GB'; SET temp_directory='{spill}'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def inmaster_select(silver_columns, silver_path: str, bronze_path: str) -> tuple:
    """(SQL, description) for the inmaster table: Silver_InMaster when it has PiecesInSet, else the staging lakehouse's
    Bronze InMaster shortcut (a tier Plan R's Build_Silver_InMaster hasn't reached yet)."""
    if "PiecesInSet" in silver_columns:
        return (f"SELECT Branch, Franchise, PartNumber, PiecesInSet FROM delta_scan('{silver_path}')",
                "Silver_InMaster.PiecesInSet")
    return (f"""SELECT BRANCH AS Branch, FRANCHISE AS Franchise, PART_NO AS PartNumber, Pieces_In_Set AS PiecesInSet
                FROM delta_scan('{bronze_path}')""",
            "the Bronze InMaster shortcut's Pieces_In_Set (Silver_InMaster has no PiecesInSet yet)")


def load_inputs(con, tier: str, groups_tier: str, now: datetime) -> None:
    """parts (every franchise; build_expected keeps D), intrans (franchise D, I and C lines from 10 days before the
    window start; TransDatetime cast to the naive wall clock in the UTC session), rules, groups and inmaster."""
    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, Description, Cost, QuantityOnHand,
                    OnOrder, PackageQty, Returnable, Source, SLC, SuperTo, CommodityCode, DealerGroupCode,
                    Current12MoSales, Previous12MoSales, BinQty
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartInformation')}')""")
    # The Corp demand and Pieces In Set windows start on the same day; both are covered from 10 days before it.
    ws, _, _ = window(now)
    con.execute(f"""CREATE TABLE intrans AS SELECT Branch, Franchise, PartNumber, Type, Qty,
                    CAST(TransDatetime AS TIMESTAMP) AS TransDatetime, RONumber, OriginalInvoiceNo
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_InTrans')}')
                    WHERE upper(trim(Franchise)) = 'D' AND upper(trim(Type)) IN ('I', 'C')
                      AND TransDatetime >= {_ts(ws - timedelta(days=10))}""")
    con.execute(f"""CREATE TABLE rules AS SELECT Branch, Franchise, PartNumber, MinimumQty, MaximumQty
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartStockingRules')}')""")
    try:
        con.execute(f"""CREATE TABLE groups AS SELECT CommodityCode, CommodityGroup
                        FROM delta_scan('{_path(groups_tier, 'staging', 'CommodityCodeGroups')}')""")
    except duckdb.Error as e:
        sys.exit(f"CommodityCodeGroups can't be read on {groups_tier} ({str(e).splitlines()[0][:150]}); "
                 f"run df_CommodityCodeGroups_Raw there or pass --groups-tier dev")
    silver_path = _path(tier, "staging", "Silver_InMaster")
    columns = [r[0] for r in con.execute(f"DESCRIBE SELECT * FROM delta_scan('{silver_path}')").fetchall()]
    sql, source = inmaster_select(columns, silver_path, _path(tier, "staging", "InMaster"))
    con.execute(f"CREATE TABLE inmaster AS {sql}")
    print(f"InMaster Pieces In Set ({tier}) read from {source}")


def gold_as_of(con, tier: str):
    """(exists, DemandAsOf as a naive Central wall clock or None). Fails if Gold has more than one DemandAsOf."""
    try:
        vals = con.execute(f"""SELECT DISTINCT CAST(DemandAsOf AS TIMESTAMP)
                               FROM delta_scan('{_path(tier, 'presentation', GOLD_TABLE)}')""").fetchall()
    except duckdb.Error as e:
        print(f"{GOLD_TABLE} ({tier}) can't be read: {str(e).splitlines()[0][:150]}")
        return False, None
    if len(vals) != 1:
        sys.exit(f"{GOLD_TABLE} ({tier}) has {len(vals)} distinct DemandAsOf values (expected exactly one)")
    return True, vals[0][0]


def _write_csv(path: str, rows: list, cols: list) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({c: (str(v) if isinstance(v, Decimal) else v) for c, v in r.items()})


def _print_rows(title: str, rows: list, limit: int = 20) -> None:
    print(f"{title}: {len(rows):,}" + (f" (first {limit})" if len(rows) > limit else ""))
    for r in rows[:limit]:
        print("  " + ", ".join(f"{k}={v!r}" for k, v in r.items()))


def run_xlsx_compare(con, args, ours: list, now: datetime) -> None:
    rep = REPORTS[args.report]
    key, upper = rep.get("key", BRANCH_KEY), rep.get("upper_key", False)
    xl = read_xlsx(args.compare_xlsx, args.sheet, rep["columns"], rep["num"])
    res = compare_xlsx(con, xl, ours, rep["columns"], rep["num"], key, upper, rep.get("nocase", ()),
                       rep.get("tolerance", TOLERANCE))
    print(f"\nWorkbook compare ({args.compare_xlsx}, sheet {args.sheet!r}): Excel {res['excel_rows']:,} rows, "
          f"ours {res['our_rows']:,} rows, {res['matched_keys']:,} keys on both sides; duplicate keys: Excel "
          f"{res['dup_excel_keys']}, ours {res['dup_our_keys']}")
    print(f"only in Excel {len(res['only_excel']):,}, only in ours {len(res['only_ours']):,}, "
          f"value differences {len(res['values']):,}")
    by_col = {}
    for d in res["values"]:
        by_col[d["Column"]] = by_col.get(d["Column"], 0) + 1
    if by_col:
        print("value differences by column: " + ", ".join(f"{c} {n}" for c, n in sorted(by_col.items())))
    diffs = ([{"Kind": "only_excel", "Column": "", "Excel": "", "Ours": "", **_xkey_dict(r, key, upper)}
              for r in res["only_excel"]]
             + [{"Kind": "only_ours", "Column": "", "Excel": "", "Ours": "", **_xkey_dict(r, key, upper)}
                for r in res["only_ours"]]
             + [{"Kind": "value", **d} for d in res["values"]])
    keys = sorted({tuple(d[k] for k in key) for d in diffs})
    ctx = part_context(con, keys, now, args.tier)
    for d in diffs:
        c = ctx[tuple(d[k].upper() for k in key)]
        d["CorpDemands"] = c["CorpDemands"]
        d["LastDTrans"] = c["LastDTrans"]
        d["PartRows"] = " ; ".join(c["Rows"])
        d["Lines"] = " ; ".join(c["Lines"])
    for kind in ("only_excel", "only_ours", "value"):
        _print_rows(f"\n{kind}", [d for d in diffs if d["Kind"] == kind])
    if args.diff_out:
        _write_csv(args.diff_out, diffs, ["Kind", *key, "Column", "Excel", "Ours", "CorpDemands", "LastDTrans",
                                          "PartRows", "Lines"])
        print(f"wrote {len(diffs):,} differences to {args.diff_out}")


def _xkey_dict(r: dict, key=BRANCH_KEY, upper: bool = False) -> dict:
    return dict(zip(key, _xkey(r, key, upper)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tier", choices=sorted(TIERS), required=True)
    ap.add_argument("--groups-tier", choices=sorted(TIERS), help="tier to read CommodityCodeGroups from")
    ap.add_argument("--as-of", help="Central wall clock 'YYYY-MM-DD HH:MM:SS' (default: Gold's DemandAsOf)")
    ap.add_argument("--mlpf-out", help="write the MLPF Gaps list (Gold if present, else the reference) to CSV")
    ap.add_argument("--report", choices=sorted(REPORTS), default="mlpf",
                    help="the list for --report-out / --compare-xlsx (default mlpf); border, cotton, stocking and the "
                         "Pieces In Set lists (pis, pis3, pisreview) come from the reference")
    ap.add_argument("--report-out", help="write the --report list to CSV")
    ap.add_argument("--compare-xlsx", help="workbook to compare with the --report list")
    ap.add_argument("--sheet", help="workbook sheet (default: the report's: MLPF Gaps, Border Stores, "
                                    "2 & 4 Cotton & Stripper Parts, SPI Corparate Stocking, Data, "
                                    "'SPI - Pieces In Set ', SPI -Pieces In Set Review)")
    ap.add_argument("--check-pis-gold", action="store_true",
                    help="fail when Gold lacks the Pieces In Set columns (compared by default when it has them)")
    ap.add_argument("--diff-out", help="write every workbook difference to CSV (with --compare-xlsx)")
    a = ap.parse_args()
    a.sheet = a.sheet or REPORTS[a.report]["sheet"]
    con = _connect()

    has_gold, gold_now = gold_as_of(con, a.tier)
    if a.as_of:
        now = datetime.strptime(a.as_of, "%Y-%m-%d %H:%M:%S")
        if has_gold and gold_now != now:
            print(f"NOTE: --as-of {now} differs from Gold's DemandAsOf {gold_now}; the Gold compare will show "
                  f"the window difference")
    elif has_gold:
        now = gold_now
    else:
        sys.exit(f"{GOLD_TABLE} isn't on {a.tier}: pass --as-of")
    ws, ie, ce = window(now)
    print(f"As of {now} (Central): invoices {ws} .. {ie}, credits {ws} .. {ce}")

    load_inputs(con, a.tier, a.groups_tier or a.tier, now)
    mx = con.execute("SELECT max(TransDatetime) FROM intrans").fetchone()[0]
    print(f"Silver_InTrans ({a.tier}) last franchise D I/C line: {mx} (wall clock)")
    build_expected(con, now)
    n, nd, dem = con.execute("SELECT count(*), count(*) FILTER (CorpDemands > 0), sum(CorpDemands) "
                             "FROM expected").fetchone()
    print(f"Reference: {n:,} rows, {nd:,} with Corp demands ({dem:,} demands)")

    failed = False
    split = idle_checks(con)
    print(f"Reference idle: {split['idle']:,} rows; active + idle vs Silver franchise D: {split}")
    for prob in idle_problems(split):
        failed = True
        print(f"FAIL: reference {prob}")
    if has_gold:
        cols = ", ".join(OUTPUT_COLS)
        con.execute(f"CREATE TABLE gold AS SELECT {cols} FROM delta_scan('{_path(a.tier, 'presentation', GOLD_TABLE)}')")
        res = compare(con, "gold", "expected")
        print(f"{GOLD_TABLE} ({a.tier}): {res}")
        if any(res.values()):
            failed = True
            _print_rows("differences", differences(con, "gold", "expected", limit=20))
            print("FAIL: Gold doesn't match the reference")
        else:
            gn = con.execute("SELECT count(*), sum(CorpDemands) FROM gold").fetchone()
            print(f"PASS: {GOLD_TABLE} matches the reference ({gn[0]:,} rows, {gn[1]:,} demands, 0 differences)")
    else:
        print(f"Gold compare skipped: {GOLD_TABLE} isn't on {a.tier}")
    if not check_gold_idle(con, a.tier, has_gold):
        failed = True
    build_pis_stats(con, now)
    build_pis_expected(con)
    if not check_pis(con, a.tier, has_gold, a.check_pis_gold):
        failed = True

    src = "gold" if has_gold else "expected"
    mlpf = mlpf_rows(con, src)
    print(f"MLPF Gaps from {'Gold' if has_gold else 'the reference'}: {len(mlpf):,} rows")
    if a.mlpf_out:
        _write_csv(a.mlpf_out, mlpf, MLPF_COLUMNS)
        print(f"wrote {a.mlpf_out}")
    if a.report == "mlpf":
        ours = mlpf
    else:
        ours = report_rows(con, a.report)
        print(f"{REPORTS[a.report]['sheet']} from the reference: {len(ours):,} rows")
    if a.report in ("pis", "pis3"):
        _print_rows("\nR-D6: rows where the workbook's join reads another franchise's record", pis_franchise_rows(con),
                    limit=50)
    if a.report_out:
        _write_csv(a.report_out, ours, REPORTS[a.report]["columns"])
        print(f"wrote {a.report_out}")
    if a.compare_xlsx:
        run_xlsx_compare(con, a, ours, now)
    return 1 if failed else 0


def check_pis(con, tier: str, has_gold: bool, required: bool = False) -> bool:
    """R-D7's idle check (no idle record qualifies for a list), then Gold's seven Pieces In Set columns against the reference over every active record, when
    Gold has them (`required`: their absence fails). False on any problem."""
    ok = True
    idle = pis_idle_rows(con)
    if idle:
        ok = False
        _print_rows(f"FAIL: idle records with {PIS_MIN_INVOICES}+ 18-month invoices", idle)
    else:
        below = len(pis_idle_rows(con, 1))
        print(f"PASS: no idle record has {PIS_MIN_INVOICES}+ 18-month invoices ({below:,} have fewer: no list needs them)")
    missing = PIS_GOLD_COLS
    if has_gold:
        path = _path(tier, "presentation", GOLD_TABLE)
        have = {r[0] for r in con.execute(f"DESCRIBE SELECT * FROM delta_scan('{path}')").fetchall()}
        missing = [c for c in PIS_GOLD_COLS if c not in have]
    if missing:
        print(f"Pieces In Set compare skipped: {GOLD_TABLE} ({tier}) has no {', '.join(missing)}")
        return ok and not required
    cols = ", ".join(KEYS + PIS_GOLD_COLS)
    con.execute(f"CREATE TABLE gold_pis AS SELECT {cols} FROM delta_scan('{path}')")
    res = compare(con, "gold_pis", "expected_pis", [], PIS_GOLD_COLS)
    print(f"{GOLD_TABLE} Pieces In Set ({tier}): {res}")
    if any(res.values()):
        ok = False
        _print_rows("differences", differences(con, "gold_pis", "expected_pis", limit=20, text_cols=[],
                                               num_cols=PIS_GOLD_COLS))
        print("FAIL: Gold's Pieces In Set columns don't match the reference")
    else:
        n = con.execute("SELECT count(*) FILTER (PisInvoices > 0), sum(PisInvoices) FROM gold_pis").fetchone()
        print(f"PASS: Gold's Pieces In Set columns match the reference ({n[0]:,} records with invoices, {n[1]:,} "
              f"invoices, 0 differences)")
    return ok


def check_gold_idle(con, tier: str, has_gold: bool) -> bool:
    """Compare Gold Fact_CorpParts_JD_Idle with the reference idle rows when the table exists (and, with Gold active,
    check the two Gold tables are disjoint and cover Silver franchise D). False on any difference."""
    try:
        con.execute(f"CREATE TABLE gold_idle AS SELECT {', '.join(IDLE_COLS)} "
                    f"FROM delta_scan('{_path(tier, 'presentation', IDLE_TABLE)}')")
    except duckdb.Error as e:
        print(f"Idle compare skipped: {IDLE_TABLE} isn't on {tier} ({str(e).splitlines()[0][:120]})")
        return True
    ok = True
    res = compare(con, "gold_idle", "expected_idle", IDLE_TEXT, IDLE_NUM)
    print(f"{IDLE_TABLE} ({tier}): {res}")
    if any(res.values()):
        ok = False
        _print_rows("differences", differences(con, "gold_idle", "expected_idle", limit=20, text_cols=IDLE_TEXT,
                                               num_cols=IDLE_NUM))
        print(f"FAIL: {IDLE_TABLE} doesn't match the reference")
    if has_gold:
        split = idle_checks(con, "gold", "gold_idle")
        print(f"Gold active + idle vs Silver franchise D: {split}")
        for prob in idle_problems(split):
            ok = False
            print(f"FAIL: Gold {prob}")
    if ok:
        n = con.execute("SELECT count(*) FROM gold_idle").fetchone()[0]
        print(f"PASS: {IDLE_TABLE} matches the reference ({n:,} rows, 0 differences)")
    return ok


if __name__ == "__main__":
    sys.exit(main())
