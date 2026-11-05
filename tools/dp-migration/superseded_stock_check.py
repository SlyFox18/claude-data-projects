"""Stock on superseded parts (Plan P): the reference for the SPI Parts Hub's two built-ins, from Prod or Dev Gold.

JD: Fact_CorpParts_JD (active rows; the idle table carries no on hand, its records have none) where OnHand > 0 and
SuperTo is not blank. Non-JD: Fact_NonJD_Reorder (the publish's source) where QuantityOnHand > 0 and SuperTo is not
blank. Rows in branch order (numbers numerically, then the others), then part number.

Usage: python superseded_stock_check.py --tier prod [--jd-out jd.csv] [--nonjd-out nonjd.csv]
"""
import argparse
import csv

import corp_parts_check as c

OUT_COLUMNS = ["Branch", "PartNumber", "OnHand", "SuperTo"]


def superseded_rows(con, source: str, on_hand: str) -> list[dict]:
    """The records of `source` (a table or delta_scan) with `on_hand` > 0 and a Super To that isn't blank."""
    cur = con.execute(f"""
        SELECT trim(Branch) AS Branch, trim(PartNumber) AS PartNumber, {on_hand} AS OnHand, trim(SuperTo) AS SuperTo
        FROM {source} WHERE {on_hand} > 0 AND trim(coalesce(SuperTo, '')) <> ''
        ORDER BY TRY_CAST(trim(Branch) AS INT) NULLS LAST, trim(Branch), trim(PartNumber)""")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def _write(rows: list[dict], path: str) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=OUT_COLUMNS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tier", choices=["dev", "prod"], required=True)
    ap.add_argument("--jd-out", help="write the JD records to CSV")
    ap.add_argument("--nonjd-out", help="write the non-JD records to CSV")
    a = ap.parse_args()
    con = c._connect()

    def scan(table: str) -> str:
        return f"delta_scan('{c._path(a.tier, 'presentation', table)}')"

    jd = superseded_rows(con, scan("Fact_CorpParts_JD"), "OnHand")
    nonjd = superseded_rows(con, scan("Fact_NonJD_Reorder"), "QuantityOnHand")
    print(f"JD: {len(jd):,} records at {len({r['Branch'] for r in jd})} branches; "
          f"non-JD: {len(nonjd):,} records at {len({r['Branch'] for r in nonjd})} branches")
    if a.jd_out:
        _write(jd, a.jd_out)
    if a.nonjd_out:
        _write(nonjd, a.nonjd_out)


if __name__ == "__main__":
    main()
