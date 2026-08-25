"""
PARTS LOOKUP STATIC-FILE PROTOTYPE - PARTITION
============================================================================
Reads the local extract from extract.py and partitions it into one JSON
file per PartNumber-prefix bucket, at both 1-char and 2-char prefix length,
so the two can be compared before picking one (design spec Section 4.2).

Output is gzip-compressed (.json.gz) - added 2026-08-25 after a real
production incident: the "RE" 2-char prefix (an extremely common John
Deere part prefix) produces a ~20 MB uncompressed file, and Microsoft
Graph's driveItem content endpoint does not compress responses in
transit (confirmed - no Content-Encoding header even when the request
sends Accept-Encoding: gzip), so that full 20 MB was hitting browsers
directly. That produced multi-minute loads, "Failed to fetch" errors,
and truncated-JSON parse errors on real, otherwise-healthy connections.
JSON compresses very well (typically 80-90%+), so compressing here and
decompressing client-side (see parts-lookup-app's dataService.ts,
DecompressionStream) turns a ~20 MB transfer into a few MB.

Run extract.py first.
============================================================================
"""

import gzip
import json
import os
import re
import time

import pandas as pd

IN_PATH = "partslookup_extract.parquet"
PREFIX_LENGTHS = [1, 2]

SAFE_CHARS = re.compile(r"[^A-Z0-9]")


def safe_prefix(part_number: str, length: int) -> str:
    prefix = str(part_number).upper()[:length]
    return SAFE_CHARS.sub("_", prefix) or "_EMPTY_"


def partition(df: pd.DataFrame, prefix_len: int, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    df = df.copy()
    df["_prefix"] = df["PartNumber"].apply(lambda p: safe_prefix(p, prefix_len))

    sizes_kb = []
    for prefix, group in df.groupby("_prefix"):
        group = group.drop(columns="_prefix")
        group = group.astype(object).where(group.notna(), None)
        rows = group.to_dict(orient="records")
        file_path = os.path.join(out_dir, f"{prefix}.json.gz")
        with gzip.open(file_path, "wt", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
        sizes_kb.append(os.path.getsize(file_path) / 1024)

    print(f"\nPrefix length {prefix_len}: {len(sizes_kb)} files")
    print(f"  smallest: {min(sizes_kb):.1f} KB")
    print(f"  largest:  {max(sizes_kb):.1f} KB")
    print(f"  average:  {sum(sizes_kb) / len(sizes_kb):.1f} KB")
    print(f"  total:    {sum(sizes_kb):.1f} KB")


df = pd.read_parquet(IN_PATH)

for length in PREFIX_LENGTHS:
    start = time.time()
    partition(df, length, out_dir=f"output/{length}char")
    print(f"  generation time: {time.time() - start:.1f} sec")
