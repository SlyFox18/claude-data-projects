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

Adaptive 3-char splitting - added the same day, same incident: even
compressed, "RE" was still ~1.7 MB (11.6x smaller, but still the single
largest file by a wide margin - next-largest 2-char prefixes are nowhere
close), still a slow first load, and a real parts-department test
specifically hit this exact prefix on a real, commonly-sold part. Any
2-char prefix whose compressed file exceeds SPLIT_THRESHOLD_BYTES is
automatically re-split into finer 3-char sub-buckets instead - adaptive
rather than a hardcoded "RE is special" list, so this self-corrects if a
different prefix grows into the same problem later. Which prefixes got
split is recorded in _manifest.json so the frontend knows which lookup
depth to use for a given part number (see dataService.ts's getManifest).

Run extract.py first.
============================================================================
"""

import glob
import gzip
import json
import os
import re
import time

import pandas as pd

IN_PATH = "partslookup_extract.parquet"
PREFIX_LENGTHS = [1, 2]
SPLIT_THRESHOLD_BYTES = 300 * 1024  # 300 KB compressed

SAFE_CHARS = re.compile(r"[^A-Z0-9]")


def safe_prefix(part_number: str, length: int) -> str:
    prefix = str(part_number).upper()[:length]
    return SAFE_CHARS.sub("_", prefix) or "_EMPTY_"


def write_gzip_json(file_path: str, rows: list) -> int:
    """Writes rows as gzip-compressed JSON, returns the resulting file size
    in bytes."""
    with gzip.open(file_path, "wt", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
    return os.path.getsize(file_path)


def rows_for(df: pd.DataFrame, drop_cols: list) -> list:
    group = df.drop(columns=drop_cols)
    group = group.astype(object).where(group.notna(), None)
    return group.to_dict(orient="records")


def partition(df: pd.DataFrame, prefix_len: int, out_dir: str) -> list:
    """Writes one gzip-compressed JSON file per prefix bucket. Returns the
    list of 2-char prefixes that were oversized enough to be split into
    3-char sub-buckets instead (always empty when prefix_len != 2 - the
    1-char output isn't used in production and isn't a candidate for
    this)."""
    os.makedirs(out_dir, exist_ok=True)
    # Clear stale output from previous runs before writing new files - a
    # prefix's file should never persist once nothing maps to it. This is
    # what caused a real production bug (2026-08-25): migrating to
    # gzip-compressed output left every old *.json file sitting next to
    # the new *.json.gz ones (nothing had ever deleted them), and
    # upload.py's broadened glob pattern picked up both sets, roughly
    # doubling upload time and reuploading the giant uncompressed files
    # this migration was meant to eliminate. _meta.json/_manifest.json
    # get deleted here too if present, but run_refresh.py/this script
    # always rewrite them fresh each run, so that's harmless.
    for stale_file in glob.glob(os.path.join(out_dir, "*")):
        os.remove(stale_file)
    df = df.copy()
    df["_prefix"] = df["PartNumber"].apply(lambda p: safe_prefix(p, prefix_len))

    split_prefixes = []
    sizes_kb = []
    for prefix, group in df.groupby("_prefix"):
        file_path = os.path.join(out_dir, f"{prefix}.json.gz")
        size_bytes = write_gzip_json(file_path, rows_for(group, ["_prefix"]))

        if prefix_len == 2 and size_bytes > SPLIT_THRESHOLD_BYTES:
            os.remove(file_path)
            split_prefixes.append(prefix)
            sub_df = group.copy()
            sub_df["_subprefix"] = sub_df["PartNumber"].apply(lambda p: safe_prefix(p, 3))
            for subprefix, subgroup in sub_df.groupby("_subprefix"):
                sub_path = os.path.join(out_dir, f"{subprefix}.json.gz")
                sub_size = write_gzip_json(sub_path, rows_for(subgroup, ["_prefix", "_subprefix"]))
                sizes_kb.append(sub_size / 1024)
        else:
            sizes_kb.append(size_bytes / 1024)

    print(f"\nPrefix length {prefix_len}: {len(sizes_kb)} files")
    print(f"  smallest: {min(sizes_kb):.1f} KB")
    print(f"  largest:  {max(sizes_kb):.1f} KB")
    print(f"  average:  {sum(sizes_kb) / len(sizes_kb):.1f} KB")
    print(f"  total:    {sum(sizes_kb):.1f} KB")
    if split_prefixes:
        print(f"  split into 3-char sub-buckets: {', '.join(sorted(split_prefixes))}")

    return split_prefixes


def main() -> None:
    df = pd.read_parquet(IN_PATH)

    for length in PREFIX_LENGTHS:
        out_dir = f"output/{length}char"
        start = time.time()
        split_prefixes = partition(df, length, out_dir=out_dir)
        print(f"  generation time: {time.time() - start:.1f} sec")

        if length == 2:
            manifest_path = os.path.join(out_dir, "_manifest.json")
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump({"splitPrefixes": sorted(split_prefixes)}, f)


if __name__ == "__main__":
    # Guarded so importing this module (e.g. from a test, or another
    # script reusing partition()/safe_prefix()) never has the side effect
    # of running the real pipeline against the real output directories -
    # confirmed the hard way on 2026-08-25, when an import collided with
    # a live scheduled run and left its output directory in an
    # inconsistent state mid-upload.
    main()
