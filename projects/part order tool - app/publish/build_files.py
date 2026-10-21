"""Write the app's data files: deterministic gzipped JSON (same content -> same bytes -> same hash)."""
import gzip
import hashlib
import json
import os
import re
from collections import defaultdict
from datetime import date

import publish_logic as pl

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
RULE_KEYS = ("id", "ruleName", "priority", "active", "franchise", "dealerGroupCode", "branch", "startMonth",
             "endMonth", "historyMonths", "minActiveMonths", "weeksOfCover", "demandBasis")
_SAFE = re.compile(r"^[A-Za-z0-9_-]+$")


def branch_key(raw) -> str:
    b = str(raw).strip()
    if not _SAFE.match(b):
        raise ValueError(f"unsafe branch code {raw!r} for a file name")
    return b


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


def build(reorder: list, history_for, transfers: list, names: dict, data_as_of: str,
          current_month: date, rules: list) -> tuple:
    """Write all data files into OUT_DIR (not _meta.json; see write_meta).
    history_for(branch_key) -> that branch's history rows (called once per branch).
    rules: NonJD_OrderRules rows (camelCase keys), written as rules.json.gz for the app's engine check.
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json)."""
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        os.remove(os.path.join(OUT_DIR, f))
    hashes = {}

    surplus = []
    by_branch, raw_of = defaultdict(list), {}
    for r in reorder:
        key = branch_key(r["branch"])
        if raw_of.setdefault(key, r["branch"]) != r["branch"]:
            raise ValueError(f"branch codes {raw_of[key]!r} and {r['branch']!r} both map to file key {key!r}")
        if (r["surplusQty"] or 0) > 0:
            surplus.append(_clean({"branch": key, "franchise": r["franchise"], "partNumber": r["partNumber"],
                                   "onHand": r["onHand"], "target": r["target"], "surplusQty": r["surplusQty"],
                                   "status": r["status"]}))
        by_branch[key].append(_clean({k: v for k, v in r.items() if k != "branch"}))

    labels = pl.month_labels(current_month, 60)
    keys = sorted(by_branch, key=lambda b: (0, int(b), "") if b.isdigit() else (1, 0, b))
    for key in keys:
        _write(f"reorder_{key}.json.gz",
               _bytes({"branch": key, "dataAsOf": data_as_of, "parts": by_branch[key]}), hashes)
        hist = history_for(key)
        _write(f"history_{key}.json.gz",
               _bytes({"branch": key, "months": labels, "parts": pl.history_arrays(hist, 60)}), hashes)
        del hist

    _write("surplus.json.gz", _bytes({"dataAsOf": data_as_of, "parts": surplus}), hashes)
    _write("transfers.json.gz", _bytes({"dataAsOf": data_as_of, "lines": [_clean(t) for t in transfers]}), hashes)

    for r in rules:
        missing = [k for k in RULE_KEYS if k not in r]
        if missing:
            raise ValueError(f"rules row {r.get('id')!r} is missing key(s) {', '.join(missing)}")
    _write("rules.json.gz", _bytes({"dataAsOf": data_as_of,
                                    "rules": [_clean({k: r[k] for k in RULE_KEYS})
                                              for r in sorted(rules, key=lambda r: r["id"])]}), hashes)

    branches = [{"branch": b, "name": names.get(b, b), "parts": len(by_branch[b])} for b in keys]
    return hashes, branches


def write_meta(data_as_of: str, published_at: str, source: str, branches: list, counts: dict) -> str:
    path = os.path.join(OUT_DIR, pl.META_FILE)
    with open(path, "wb") as f:
        f.write(_bytes({"dataAsOf": data_as_of, "publishedAt": published_at, "source": source,
                        "branches": branches, "counts": counts, "schemaVersion": 1}, compress=False))
    return path
