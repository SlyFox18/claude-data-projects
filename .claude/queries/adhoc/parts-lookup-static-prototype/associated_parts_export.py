"""
ASSOCIATED PARTS COUNTER EXPORT
============================================================================
Collapses Fact_PartAssociation (Franchise x PartA x PartB grain, built
weekly by projects/associated parts - report/notebooks/Fact_PartAssociation_Build.ipynb)
down to a single (PartA, PartB) grain, computes ConfidencePercent/Lift as
plain numbers (there is no live DAX engine on the client), joins in
PartB's Description from dim_Parts, and writes a single gzip-compressed
JSON file plus a small freshness-metadata file.

Unlike partition.py (which splits PartLocations across 300+ prefix-bucket
files because that dataset is 1M+ rows), this export is small enough for
one file: confirmed via a real run during planning at 44,258 rows / 718 KB
gzipped for the entire dataset. No partitioning.

The franchise dimension is deliberately collapsed away here -- the counter
app has no use for a franchise breakdown (that's an internal Power BI
modeling detail), so counts are summed across franchise before computing
ratios. AnchorInvoiceCount/AssociatedInvoiceCount/TotalInvoiceCount are
repeated values across multiple rows in the source table (same trap as the
Power BI measures) -- de-duplicated via DISTINCT before summing, exactly
matching the SUMX(SUMMARIZE(...)) pattern already proven correct in the
semantic model's own measures.

See docs/superpowers/specs/2026-08-27-associated-parts-design.md and
docs/superpowers/specs/2026-08-31-associated-parts-counter-lookup-design.md
for full design rationale.

Run standalone: python associated_parts_export.py
============================================================================
"""
import datetime
import gzip
import json
import os
import time

import duckdb

import config
import upload  # same folder -- reuses get_access_token()/upload_file(), no duplicated retry/chunking logic

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"
OUT_DIR = "output_associated_parts"
DATA_FILE = "associated_parts.json.gz"
META_FILE = "_meta_associated_parts.json"


def build_export() -> list[dict]:
    """Runs the collapse query against live Fact_PartAssociation/dim_Parts
    and returns the result as a list of row dicts, ready for JSON export."""
    base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
    con = duckdb.connect()
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
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

    result = con.execute(f"""
        WITH per_franchise AS (
            SELECT Franchise, PartA, PartB, CoOccurrenceCount, AnchorInvoiceCount,
                   AssociatedInvoiceCount, TotalInvoiceCount
            FROM delta_scan('{base}/Fact_PartAssociation')
        ),
        coocc_summed AS (
            SELECT PartA, PartB, SUM(CoOccurrenceCount) AS CoOccurrenceCount
            FROM per_franchise GROUP BY PartA, PartB
        ),
        anchor_totals AS (
            SELECT PartA, SUM(AnchorInvoiceCount) AS AnchorInvoiceCount
            FROM (SELECT DISTINCT Franchise, PartA, AnchorInvoiceCount FROM per_franchise)
            GROUP BY PartA
        ),
        associated_totals AS (
            SELECT PartB, SUM(AssociatedInvoiceCount) AS AssociatedInvoiceCount
            FROM (SELECT DISTINCT Franchise, PartB, AssociatedInvoiceCount FROM per_franchise)
            GROUP BY PartB
        ),
        total_invoices AS (
            SELECT SUM(TotalInvoiceCount) AS TotalInvoiceCount
            FROM (SELECT DISTINCT Franchise, TotalInvoiceCount FROM per_franchise)
        )
        SELECT
            c.PartA, c.PartB, p.Description,
            CAST(c.CoOccurrenceCount AS BIGINT) AS CoOccurrenceCount,
            ROUND(CAST(c.CoOccurrenceCount AS DOUBLE) / a.AnchorInvoiceCount * 100, 2) AS ConfidencePercent,
            ROUND((CAST(c.CoOccurrenceCount AS DOUBLE) / a.AnchorInvoiceCount)
                  / (CAST(b.AssociatedInvoiceCount AS DOUBLE) / t.TotalInvoiceCount), 2) AS Lift
        FROM coocc_summed c
        INNER JOIN anchor_totals a ON a.PartA = c.PartA
        INNER JOIN associated_totals b ON b.PartB = c.PartB
        CROSS JOIN total_invoices t
        LEFT JOIN delta_scan('{base}/dim_Parts') p ON p.PartNumber = c.PartB
        ORDER BY c.PartA, c.CoOccurrenceCount DESC
    """).df()

    result = result.astype(object).where(result.notna(), None)
    return result.to_dict(orient="records")


def write_gzip_json(rows: list, out_dir: str = OUT_DIR) -> int:
    """Writes rows as gzip-compressed JSON, matching partition.py's
    write_gzip_json() convention (compact separators, no ensure_ascii).
    Returns the resulting file size in bytes."""
    os.makedirs(out_dir, exist_ok=True)
    file_path = os.path.join(out_dir, DATA_FILE)
    with gzip.open(file_path, "wt", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
    return os.path.getsize(file_path)


def write_meta_file(out_dir: str = OUT_DIR) -> None:
    """Writes _meta_associated_parts.json with the current UTC generation
    timestamp -- a separate file from the existing pipeline's _meta.json,
    since this export runs on its own weekly schedule, independent of the
    hourly PartLocations refresh that owns that file."""
    meta_path = os.path.join(out_dir, META_FILE)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(
            {"generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()},
            f,
        )


def upload_export(out_dir: str = OUT_DIR) -> None:
    """Uploads the data file and meta file to the same SharePoint
    site/drive the Parts Availability app reads from, reusing upload.py's
    existing get_access_token()/upload_file() (retry/chunking logic already
    proven by the PartLocations pipeline)."""
    access_token = upload.get_access_token()
    for file_name in (DATA_FILE, META_FILE):
        local_path = os.path.join(out_dir, file_name)
        print(f"  uploading {file_name}...")
        upload.upload_file(local_path, file_name, access_token)
    print(f"Uploaded {DATA_FILE} and {META_FILE}")


def main() -> None:
    start = time.time()
    rows = build_export()
    print(f"Query returned {len(rows):,} rows in {time.time() - start:.1f}s")

    size_bytes = write_gzip_json(rows)
    print(f"Wrote {DATA_FILE}: {size_bytes / 1024:.1f} KB")

    write_meta_file()
    print(f"Wrote {META_FILE}")

    upload_export()


if __name__ == "__main__":
    # Guarded the same way as partition.py -- importing this module (e.g.
    # from a test) must never have the side effect of running the real
    # export against real output paths.
    main()
