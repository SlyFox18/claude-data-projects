"""
PARTS LOOKUP REFRESH PIPELINE - PURE HELPERS
============================================================================
No network, no config import: unit-tested in test_refresh_logic.py.
Added 2026-10 for the move from LH_Master_Data to DP (spec:
docs/superpowers/specs/2026-10-14-parts-availability-dp-feed-design.md).

- SOURCES: the tables extract.py can read. "lh" is the old LH_Master_Data
  table; "dp" is DP_Staging's PartsAvailability in Prod (loaded hourly by
  Pipeline_PartsAvailability, weekdays 06:50-16:50); "dp-dev" is the Dev
  copy, for tests. Only the DP tables carry ExtractedAtUtc (the load time).
- validate_extract(): the guards that stop a partial or broken table from
  ever being published.
- should_skip(): run_refresh.py publishes a load only once; runs that find
  the same ExtractedAtUtc as the last publish (no new load, or a failed
  load) skip the 18-minute partition + upload.
- build_meta(): _meta.json's generatedAt is the DATA's load time, so the
  app's "Data as of" and its stale banner (and check_staleness.py) measure
  how old the data really is.
- upload_order(): _meta.json goes last, so "Data as of" never moves ahead
  of the files it describes.
============================================================================
"""

import os
from datetime import timezone

ONELAKE = "abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"
SOURCES = {
    # name: (workspace ID, lakehouse ID, table, has ExtractedAtUtc)
    "lh": ("b48cdb35-7ce3-46de-96df-d70db77649cb", "3e74497b-8c51-4a1a-91a1-888c59118f48",
           "InMaster_PartsLookup_Raw", False),
    "dp": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784",
           "PartsAvailability", True),
    "dp-dev": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101",
               "PartsAvailability", True),
}
MIN_ROWS = 1_000_000  # ~1,069,000 rows in 2026-10; far fewer means a partial or broken load
META_FILE = "_meta.json"


def source_path(name: str) -> str:
    if name not in SOURCES:
        raise ValueError(f"unknown source {name!r}; expected one of {sorted(SOURCES)}")
    ws, lh, table, _ = SOURCES[name]
    return ONELAKE.format(ws=ws, lh=lh, table=table)


def has_extracted_at(name: str) -> bool:
    return SOURCES[name][3]


def to_utc_iso(value) -> str:
    """A datetime (naive = UTC, as the dataflow writes it) as ISO 8601 with +00:00."""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def validate_extract(row_count: int, extracted_values: list, duplicate_keys: int,
                     require_extracted_at: bool) -> list:
    """Reasons not to publish this extract (empty list = OK)."""
    errors = []
    if row_count < MIN_ROWS:
        errors.append(f"only {row_count:,} rows (expected at least {MIN_ROWS:,}) - refusing to publish a "
                      "partial table")
    if duplicate_keys:
        errors.append(f"{duplicate_keys:,} duplicate Branch+Franchise+PartNumber keys")
    if require_extracted_at and (len(extracted_values) != 1 or extracted_values[0] is None):
        errors.append(f"ExtractedAtUtc should hold exactly one non-null value, found {extracted_values!r}")
    return errors


SKIP_KEYS = ("extractedAtUtc", "source", "driveId")


def should_skip(current: dict, last) -> bool:
    """True only if this exact load was already published from the same source into the same library
    (so a test publish to the staging library can never make a production run skip)."""
    if not isinstance(last, dict):
        return False
    return all(current.get(k) is not None and current.get(k) == last.get(k) for k in SKIP_KEYS)


def build_meta(extracted_at: str, published_at: str) -> dict:
    return {"generatedAt": extracted_at, "publishedAt": published_at}


def upload_order(paths: list) -> list:
    """Sorted, with _meta.json last."""
    return sorted(paths, key=lambda p: (os.path.basename(p) == META_FILE, p))
