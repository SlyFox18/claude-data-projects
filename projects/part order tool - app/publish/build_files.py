"""Write the app's data files: deterministic gzipped JSON (same content -> same bytes -> same hash)."""
import gzip
import hashlib
import json
import os
from collections import defaultdict
from datetime import date

import publish_logic as pl

OUT_DIR = "output"


def _bytes(obj, compress: bool = True) -> bytes:
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
                     allow_nan=False).encode("utf-8")
    return gzip.compress(raw, compresslevel=9, mtime=0) if compress else raw


def _write(name: str, data: bytes, hashes: dict) -> None:
    with open(os.path.join(OUT_DIR, name), "wb") as f:
        f.write(data)
    hashes[name] = hashlib.sha256(data).hexdigest()


def _clean(row: dict) -> dict:
    return {k: pl.clean_value(v) for k, v in row.items()}


def build(reorder: list, history: list, transfers: list, names: dict, data_as_of: str,
          current_month: date) -> tuple:
    """Write all data files into OUT_DIR (not _meta.json; see write_meta).
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json)."""
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        os.remove(os.path.join(OUT_DIR, f))
    hashes = {}

    by_branch = defaultdict(list)
    for r in reorder:
        by_branch[r["branch"]].append(_clean({k: v for k, v in r.items() if k != "branch"}))
    hist_by_branch = defaultdict(list)
    for h in history:
        hist_by_branch[h["branch"]].append(h)

    labels = pl.month_labels(current_month, 60)
    for branch in sorted(by_branch):
        _write(f"reorder_{branch.strip()}.json.gz",
               _bytes({"branch": branch, "dataAsOf": data_as_of, "parts": by_branch[branch]}), hashes)
        _write(f"history_{branch.strip()}.json.gz",
               _bytes({"branch": branch, "months": labels,
                       "parts": pl.history_arrays(hist_by_branch.get(branch, []), 60)}), hashes)

    surplus = [_clean({"branch": r["branch"], "franchise": r["franchise"], "partNumber": r["partNumber"],
                       "onHand": r["onHand"], "target": r["target"], "surplusQty": r["surplusQty"],
                       "status": r["status"]})
               for r in reorder if (r["surplusQty"] or 0) > 0]
    _write("surplus.json.gz", _bytes({"dataAsOf": data_as_of, "parts": surplus}), hashes)
    _write("transfers.json.gz", _bytes({"dataAsOf": data_as_of, "lines": [_clean(t) for t in transfers]}), hashes)

    branches = [{"branch": b, "name": names.get(b.strip(), b.strip()), "parts": len(by_branch[b])}
                for b in sorted(by_branch, key=lambda x: (len(x.strip()), x.strip()))]
    return hashes, branches


def write_meta(data_as_of: str, published_at: str, source: str, branches: list, counts: dict) -> str:
    path = os.path.join(OUT_DIR, pl.META_FILE)
    with open(path, "wb") as f:
        f.write(_bytes({"dataAsOf": data_as_of, "publishedAt": published_at, "source": source,
                        "branches": branches, "counts": counts, "schemaVersion": 1}, compress=False))
    return path
