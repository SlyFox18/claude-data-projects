# tools/dp-migration/corp_parts_check.py
"""
SPI Parts Hub Inventory reports: independent check of Fact_CorpParts_JD, the MLPF Gaps list and the workbook compare.

Re-implements Fact_CorpParts_JD in DuckDB SQL over the same inputs (Silver_PartInformation, Silver_InTrans,
Silver_PartStockingRules, CommodityCodeGroups) and compares row by row with the Gold table Build_Gold_NonJD_Reorder
(Part 5) wrote. The rules are Plan L (docs/superpowers/plans/2026-11-03-spi-parts-hub-inventory-reports.md,
decisions L-D10..L-D14), taken from the workbook query projects/corp parts excel reports/MLPF Gaps/MLPF Gaps.pq:

- Corp demand = one invoice for the Branch + part, net of its credits. Franchise D InTrans only (trimmed, upper).
  Invoices (Type 'I', Qty > 0) dated [now - 18 months, now - 7 days]; credits (Type 'C', Qty < 0) dated
  [now - 18 months, now]. Grouped by upper(trim(Branch)), trim(PartNumber) and the invoice key (trim(RONumber) for
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

Usage:
    python corp_parts_check.py --tier dev                      # compare with Gold, exit 1 on any mismatch
    python corp_parts_check.py --tier dev --mlpf-out mlpf.csv
    python corp_parts_check.py --tier prod --groups-tier dev --as-of "2026-11-03 09:41:00" \\
        --compare-xlsx "MLPF Gaps.xlsx" [--sheet "MLPF Gaps"] --diff-out diff.csv --mlpf-out mlpf.csv

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
    """Create corp_demands (b, p, CorpDemands) and expected (OUTPUT_COLS) from the tables parts, intrans, rules and
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
            SELECT upper(trim(Branch)) AS b, trim(PartNumber) AS p,
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
        CREATE OR REPLACE TABLE expected AS
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
               CAST(coalesce(cd.CorpDemands, 0) AS INTEGER) AS CorpDemands
        FROM parts p
        LEFT JOIN rules r ON r.Branch = p.Branch AND r.Franchise = p.Franchise AND r.PartNumber = p.PartNumber
        LEFT JOIN corp_demands cd ON cd.b = upper(trim(p.Branch)) AND cd.p = trim(p.PartNumber)
        LEFT JOIN g ON g.cc = upper(trim(p.CommodityCode))
        WHERE upper(trim(p.Franchise)) = 'D' AND {ACTIVE_SQL}
    """)


MLPF_WHERE = """upper(trim(Branch)) <> '12' AND CorpDemands = 2 AND OnHand < 1 AND OnOrder = 0 AND PackageQty = 1
    AND upper(trim(ReturnIndicator)) = 'R' AND coalesce(upper(trim(Source)), '') <> 'AN'
    AND NOT (coalesce(trim(SLC), '') LIKE '21%' OR coalesce(trim(SLC), '') LIKE '90%'
             OR coalesce(trim(SLC), '') LIKE '91%' OR coalesce(trim(SLC), '') LIKE '99%')
    AND coalesce(trim(SuperTo), '') = ''"""


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


def _col_diff(col: str) -> str:
    if col in NUM_COLS:
        return f"((g.{col} IS NULL) <> (e.{col} IS NULL) OR abs(g.{col} - e.{col}) > {TOLERANCE})"
    return f"g.{col} IS DISTINCT FROM e.{col}"


def compare(con, gold: str, expected: str) -> dict:
    keys = ", ".join(KEYS)
    where = " OR ".join(_col_diff(c) for c in TEXT_COLS + NUM_COLS)
    q = lambda sql: con.execute(sql).fetchone()[0]
    return {
        "only_gold": q(f"SELECT count(*) FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})"),
        "only_expected": q(f"SELECT count(*) FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})"),
        "different": q(f"SELECT count(*) FROM {gold} g JOIN {expected} e ON {_key_join()} WHERE {where}"),
        "dup_gold": q(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {gold}"),
        "dup_expected": q(f"SELECT count(*) - count(DISTINCT ({keys})) FROM {expected}"),
    }


def differences(con, gold: str, expected: str, limit: int = None) -> list:
    """Every difference as a dict (Kind, Branch, Franchise, PartNumber, Column, Gold, Expected); Kind is
    only_gold, only_expected or different (one entry per differing column)."""
    keys = ", ".join(KEYS)
    parts = [f"""SELECT 'only_gold' AS Kind, {keys}, '' AS "Column", NULL AS Gold, NULL AS Expected
                 FROM (SELECT {keys} FROM {gold} EXCEPT SELECT {keys} FROM {expected})""",
             f"""SELECT 'only_expected', {keys}, '', NULL, NULL
                 FROM (SELECT {keys} FROM {expected} EXCEPT SELECT {keys} FROM {gold})"""]
    for c in TEXT_COLS + NUM_COLS:
        parts.append(f"""SELECT 'different', g.Branch, g.Franchise, g.PartNumber, '{c}',
                                CAST(g.{c} AS VARCHAR), CAST(e.{c} AS VARCHAR)
                         FROM {gold} g JOIN {expected} e ON {_key_join()} WHERE {_col_diff(c)}""")
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


def read_xlsx(path: str, sheet: str) -> list:
    """The workbook's MLPF table as dicts with MLPF_COLUMNS: header = the first row holding all 12 column names."""
    import openpyxl
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        ws = wb[sheet]
        rows = ws.iter_rows(values_only=True)
        idx = None
        for row in rows:
            names = [(_cell_text(v) or "").strip() for v in row]
            if all(c in names for c in MLPF_COLUMNS):
                idx = {c: names.index(c) for c in MLPF_COLUMNS}
                break
        if idx is None:
            raise ValueError(f"no header row with {', '.join(MLPF_COLUMNS)} in sheet {sheet!r}")
        out = []
        for row in rows:
            if row is None or all(v is None for v in row):
                continue
            rec = {}
            for c, i in idx.items():
                v = row[i] if i < len(row) else None
                rec[c] = v if c in MLPF_NUM else _cell_text(v)
            out.append(rec)
        return out
    finally:
        wb.close()


def _xkey(r: dict) -> tuple:
    return ((r["Branch"] or "").strip(), (r["PartNumber"] or "").strip())


def _num_differs(a, b) -> bool:
    if a is None or b is None:
        return (a is None) != (b is None)
    return abs(float(a) - float(b)) > TOLERANCE


def _text_differs(a, b) -> bool:
    return ((a or "").strip()) != ((b or "").strip())


def compare_xlsx(con, xl_rows: list, ours: list) -> dict:
    """Match the workbook rows to our MLPF rows on trimmed Branch + trimmed PartNumber. A key with several rows on a
    side (the trailing-space twins) compares each pair."""
    xl_by, our_by = {}, {}
    for r in xl_rows:
        xl_by.setdefault(_xkey(r), []).append(r)
    for r in ours:
        our_by.setdefault(_xkey(r), []).append(r)
    only_excel = [r for k in sorted(set(xl_by) - set(our_by)) for r in xl_by[k]]
    only_ours = [r for k in sorted(set(our_by) - set(xl_by)) for r in our_by[k]]
    values = []
    for k in sorted(set(xl_by) & set(our_by)):
        for x in xl_by[k]:
            for o in our_by[k]:
                for c in MLPF_COLUMNS[2:]:
                    differs = _num_differs(x[c], o[c]) if c in MLPF_NUM else _text_differs(x[c], o[c])
                    if differs:
                        values.append({"Branch": k[0], "PartNumber": k[1], "Column": c, "Excel": x[c],
                                       "Ours": o[c]})
    return {"excel_rows": len(xl_rows), "our_rows": len(ours), "matched_keys": len(set(xl_by) & set(our_by)),
            "dup_excel_keys": sum(1 for v in xl_by.values() if len(v) > 1),
            "dup_our_keys": sum(1 for v in our_by.values() if len(v) > 1),
            "only_excel": only_excel, "only_ours": only_ours, "values": values}


def part_context(con, keys: list, now: datetime, tier: str = None) -> dict:
    """For (Branch, PartNumber) trimmed keys: our part rows (every franchise), CorpDemands, the franchise D I/C lines
    from 10 days before the window start, and (with a tier) the last franchise D InTrans line of any type."""
    if not keys:
        return {}
    ws, ie, _ = window(now)
    con.execute("CREATE OR REPLACE TEMP TABLE ctx_keys (b VARCHAR, p VARCHAR)")
    con.executemany("INSERT INTO ctx_keys VALUES (?, ?)", [[b.upper(), p] for b, p in keys])
    out = {(b.upper(), p): {"CorpDemands": 0, "Rows": [], "Lines": [], "LastDTrans": None} for b, p in keys}
    for b, p, cd in con.execute("SELECT b, p, CorpDemands FROM corp_demands JOIN ctx_keys USING (b, p)").fetchall():
        out[(b, p)]["CorpDemands"] = cd
    for row in con.execute("""
            SELECT k.b, k.p, x.Franchise, x.PartNumber, x.QuantityOnHand, x.OnOrder, x.PackageQty, x.Returnable,
                   x.Source, x.SLC, x.SuperTo, x.Cost
            FROM parts x JOIN ctx_keys k ON upper(trim(x.Branch)) = k.b AND trim(x.PartNumber) = k.p
            ORDER BY k.b, k.p, x.Franchise, x.PartNumber""").fetchall():
        b, p, fr, pn, oh, oo, pkg, ri, src, slc, sup, cost = row
        out[(b, p)]["Rows"].append(f"{fr!s}|{pn!r}|oh={oh}|oo={oo}|pkg={pkg!r}|ri={ri!r}|src={src!r}|slc={slc!r}"
                                   f"|super={sup!r}|cost={cost}")
    for b, p, typ, qty, ts, inv in con.execute("""
            SELECT k.b, k.p, upper(trim(t.Type)), t.Qty, t.TransDatetime,
                   CASE WHEN upper(trim(t.Type)) = 'I' THEN trim(t.RONumber) ELSE trim(t.OriginalInvoiceNo) END
            FROM intrans t JOIN ctx_keys k ON upper(trim(t.Branch)) = k.b AND trim(t.PartNumber) = k.p
            WHERE upper(trim(t.Franchise)) = 'D' ORDER BY k.b, k.p, t.TransDatetime""").fetchall():
        edge = ""
        if ts < ws:
            edge = "<start"
        elif ts - ws < timedelta(days=2):
            edge = "~start"
        elif typ == "I" and ts > ie:
            edge = ">invEnd"
        elif ts > now:
            edge = ">now"
        out[(b, p)]["Lines"].append(f"{typ} {ts:%Y-%m-%d %H:%M} {inv} q={qty}{(' ' + edge) if edge else ''}")
    if tier:
        src = f"delta_scan('{_path(tier, 'staging', 'Silver_InTrans')}')"
        for b, p, last in con.execute(f"""
                SELECT k.b, k.p, max(CAST(t.TransDatetime AS TIMESTAMP))
                FROM {src} t JOIN ctx_keys k ON upper(trim(t.Branch)) = k.b AND trim(t.PartNumber) = k.p
                WHERE upper(trim(t.Franchise)) = 'D' GROUP BY ALL""").fetchall():
            out[(b, p)]["LastDTrans"] = last
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


def load_inputs(con, tier: str, groups_tier: str, now: datetime) -> None:
    """parts (every franchise; build_expected keeps D), intrans (franchise D, I and C lines from 10 days before the
    window start; TransDatetime cast to the naive wall clock in the UTC session), rules and groups."""
    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, Description, Cost, QuantityOnHand,
                    OnOrder, PackageQty, Returnable, Source, SLC, SuperTo, CommodityCode, DealerGroupCode,
                    Current12MoSales, Previous12MoSales
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartInformation')}')""")
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
    xl = read_xlsx(args.compare_xlsx, args.sheet)
    res = compare_xlsx(con, xl, ours)
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
    diffs = ([{"Kind": "only_excel", "Column": "", "Excel": "", "Ours": "", **_xkey_dict(r)}
              for r in res["only_excel"]]
             + [{"Kind": "only_ours", "Column": "", "Excel": "", "Ours": "", **_xkey_dict(r)}
                for r in res["only_ours"]]
             + [{"Kind": "value", **d} for d in res["values"]])
    keys = sorted({(d["Branch"], d["PartNumber"]) for d in diffs})
    ctx = part_context(con, keys, now, args.tier)
    for d in diffs:
        c = ctx[(d["Branch"].upper(), d["PartNumber"])]
        d["CorpDemands"] = c["CorpDemands"]
        d["LastDTrans"] = c["LastDTrans"]
        d["PartRows"] = " ; ".join(c["Rows"])
        d["Lines"] = " ; ".join(c["Lines"])
    for kind in ("only_excel", "only_ours", "value"):
        _print_rows(f"\n{kind}", [d for d in diffs if d["Kind"] == kind])
    if args.diff_out:
        _write_csv(args.diff_out, diffs, ["Kind", "Branch", "PartNumber", "Column", "Excel", "Ours", "CorpDemands",
                                          "LastDTrans", "PartRows", "Lines"])
        print(f"wrote {len(diffs):,} differences to {args.diff_out}")


def _xkey_dict(r: dict) -> dict:
    b, p = _xkey(r)
    return {"Branch": b, "PartNumber": p}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tier", choices=sorted(TIERS), required=True)
    ap.add_argument("--groups-tier", choices=sorted(TIERS), help="tier to read CommodityCodeGroups from")
    ap.add_argument("--as-of", help="Central wall clock 'YYYY-MM-DD HH:MM:SS' (default: Gold's DemandAsOf)")
    ap.add_argument("--mlpf-out", help="write the MLPF Gaps list (Gold if present, else the reference) to CSV")
    ap.add_argument("--compare-xlsx", help="MLPF Gaps workbook to compare with the MLPF list")
    ap.add_argument("--sheet", default="MLPF Gaps")
    ap.add_argument("--diff-out", help="write every workbook difference to CSV (with --compare-xlsx)")
    a = ap.parse_args()
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

    src = "gold" if has_gold else "expected"
    ours = mlpf_rows(con, src)
    print(f"MLPF Gaps from {'Gold' if has_gold else 'the reference'}: {len(ours):,} rows")
    if a.mlpf_out:
        _write_csv(a.mlpf_out, ours, MLPF_COLUMNS)
        print(f"wrote {a.mlpf_out}")
    if a.compare_xlsx:
        run_xlsx_compare(con, a, ours, now)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
