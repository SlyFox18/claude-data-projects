"""
PARTS LOOKUP REFRESH PIPELINE - EXTRACT
============================================================================
Reads the Parts Availability table chosen by config.SOURCE (see
refresh_logic.SOURCES) from OneLake via DuckDB, as the pipeline's own
service principal (see config.py / .env), so it runs unattended.

Before saving anything it runs refresh_logic.validate_extract(): at least
1,000,000 rows, no duplicate Branch+Franchise+PartNumber (raw values, no
trimming: trailing-space twin part numbers are real rows), and for the DP
sources exactly one ExtractedAtUtc. A failed guard exits non-zero, so
run_refresh.py logs and alerts and publishes nothing.

Writes partslookup_extract.parquet (the 12 columns partition.py publishes)
and extract_meta.json: {"source", "extractedAtUtc", "rows"}. extractedAtUtc
is the DP load's own ExtractedAtUtc; the LH table has none, so for "lh" it
is the time of this extract (the old behaviour, kept for rollback).
============================================================================
"""

import json
import time
from datetime import datetime, timezone

import duckdb

import config
from refresh_logic import has_extracted_at, source_path, to_utc_iso, validate_extract

OUT_PATH = "partslookup_extract.parquet"
META_OUT = "extract_meta.json"
COLUMNS = ("PartNumber, Branch, Franchise, Description, VendorCode, Bin, BinQty, OnOrder, SellPrice1, "
           "SuperTo, SuperFrom, Comments")


def main() -> None:
    path = source_path(config.SOURCE)
    con = duckdb.connect()
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.execute("SET TimeZone = 'UTC';")
    con.execute(
        f"""
        CREATE SECRET (
            TYPE azure,
            PROVIDER service_principal,
            TENANT_ID '{config.TENANT_ID}',
            CLIENT_ID '{config.CLIENT_ID}',
            CLIENT_SECRET '{config.CLIENT_SECRET}'
        );
        """
    )

    start = time.time()
    con.execute(f"CREATE TABLE src AS SELECT * FROM delta_scan('{path}')")
    row_count = con.execute("SELECT count(*) FROM src").fetchone()[0]
    duplicate_keys = con.execute(
        "SELECT count(*) FROM (SELECT Branch, Franchise, PartNumber FROM src GROUP BY ALL HAVING count(*) > 1)"
    ).fetchone()[0]
    needs_extracted_at = has_extracted_at(config.SOURCE)
    values = ([r[0] for r in con.execute("SELECT DISTINCT ExtractedAtUtc FROM src").fetchall()]
              if needs_extracted_at else [])
    errors = validate_extract(row_count, values, duplicate_keys, needs_extracted_at)
    if errors:
        raise SystemExit(f"Extract guard failed for source {config.SOURCE!r}: " + "; ".join(errors))

    extracted_at = to_utc_iso(values[0]) if needs_extracted_at else datetime.now(timezone.utc).isoformat()
    df = con.execute(f"SELECT {COLUMNS} FROM src").df()
    df.to_parquet(OUT_PATH, index=False)
    with open(META_OUT, "w", encoding="utf-8") as f:
        json.dump({"source": config.SOURCE, "extractedAtUtc": extracted_at, "rows": row_count}, f)

    print(f"Extracted {row_count:,} rows from {config.SOURCE} in {time.time() - start:.1f} sec; "
          f"data as of {extracted_at}")


if __name__ == "__main__":
    main()
