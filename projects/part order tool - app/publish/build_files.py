"""Write the app's data files: deterministic gzipped JSON (same content -> same bytes -> same hash)."""
import gzip
import hashlib
import json
import math
import os
import re
from collections import defaultdict
from datetime import date
from decimal import Decimal

import publish_logic as pl

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
# rules.json fields: the NonJD_OrderRules columns Gold reads (extract.RULE_COLUMNS), raw as the list holds them.
RULE_KEYS = ("id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode", "branch",
             "slc", "source", "vendorCode", "productGroup", "commodityCode",
             "startMonth", "endMonth", "historyMonths", "minDemands", "weeksOfCover", "supplyUnit", "minLineValue",
             "maxLineValue", "demandBasis")
# transfer_rules.json fields: the NonJD_TransferRules columns Gold reads (extract.TRANSFER_RULE_COLUMNS), raw.
TRANSFER_RULE_KEYS = ("id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode", "branch",
                      "slc", "source", "vendorCode", "productGroup", "commodityCode", "startMonth", "endMonth",
                      "excessSupply", "excessUnit", "allowSend", "allowReceive", "redistMax", "redistUnit",
                      "redistMinValue")
SUGGESTION_KEYS = ("kind", "franchise", "partNumber", "fromBranch", "toBranch", "seq", "qty", "fromCost", "toCost",
                   "value", "description", "fromBin", "toBin")
COMMITTED_KEYS = ("transferId", "lineId", "status", "placedAt", "fromBranch", "toBranch", "franchise", "partNumber",
                  "qty")
# Contract v3 reorder fields (round 2). Only these may be null (transferRuleId = the built-in default rule, X6);
# blank text in the never-null text fields is written as "", a null PendingQty as 0 (Part 2 reads it as 0), and any
# other null fails the build (Gold coalesces them, so a null means Gold and the publish are out of step).
ROUND2_FIELDS = ("pendingQty", "slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn",
                 "phaseInActive", "phaseInEndReason", "appInboundQty", "appOutboundQty", "transferRuleId",
                 "transferRuleName", "excessSupply", "excessUnit", "allowSend", "allowReceive", "redistMax",
                 "redistUnit", "redistMinValue", "excessKeep", "freeExcess", "convNeed", "redistCap", "redistEligible",
                 "suggestedInQty", "suggestedConvInQty", "suggestedOutQty")
ROUND2_NULLABLE = frozenset(("slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn",
                             "phaseInEndReason", "transferRuleId"))
ROUND2_TEXT = frozenset(("transferRuleName", "excessUnit", "redistUnit"))
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


def _is_output(name: str) -> bool:
    return name.endswith(".json.gz") or name == pl.META_FILE


def _clean(row: dict) -> dict:
    return {k: pl.clean_value(v) for k, v in row.items()}


def _round2(r: dict) -> dict:
    """The row with contract v3's never-null rules applied to the round 2 fields."""
    missing = [k for k in ROUND2_FIELDS if k not in r]
    if missing:
        raise ValueError(f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r} is missing "
                         f"field(s) {', '.join(missing)}")
    out = dict(r)
    for k in ROUND2_FIELDS:
        if out[k] is None and k not in ROUND2_NULLABLE:
            if k in ROUND2_TEXT:
                out[k] = ""
            elif k == "pendingQty":
                out[k] = 0
            else:
                raise ValueError(f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r}: "
                                 f"{k} is null; Gold should always set it (Gold and the publish are out of step)")
    return out


def _check_list_rows(rows: list, keys: tuple, list_name: str) -> None:
    """Every key present, and no NaN / infinite number: one would be written as null, which reads as "blank"
    (a different rule); fail instead."""
    for r in rows:
        missing = [k for k in keys if k not in r]
        if missing:
            raise ValueError(f"{list_name} row {r.get('id')!r} is missing key(s) {', '.join(missing)}")
        for k in keys:
            v = r[k]
            if (isinstance(v, float) and not math.isfinite(v)) or (isinstance(v, Decimal) and not v.is_finite()):
                raise ValueError(f"{list_name} rule {r.get('id')!r}: {k} is {v}, not a finite number; "
                                 f"fix the rule in the list before publishing")


def _list_file(rows: list, keys: tuple) -> list:
    return [_clean({k: r[k] for k in keys}) for r in sorted(rows, key=lambda r: r["id"])]


def _none_last(v):
    return (v is None, "" if v is None else v)


def _keyed(rows: list, keys: tuple, what: str) -> list:
    for r in rows:
        missing = [k for k in keys if k not in r]
        if missing:
            raise ValueError(f"{what} row {r!r} is missing key(s) {', '.join(missing)}")
    return [_clean({k: r[k] for k in keys}) for r in rows]


def build(reorder: list, history_for, transfers: list, names: dict, data_as_of: str,
          current_month: date, rules: list, *, transfer_rules: list, suggestions: list, committed: list,
          out_dir: str = None) -> tuple:
    """Write all data files into out_dir (default OUT_DIR; not _meta.json, see write_meta).
    history_for(branch_key) -> that branch's history rows (called once per branch).
    rules: NonJD_OrderRules rows (camelCase keys), written as rules.json.gz for the app's engine check.
    transfer_rules: NonJD_TransferRules rows -> transfer_rules.json.gz. suggestions: Gold's suggestion lines and
    committed: the committed app transfer lines Gold used -> transfer_suggestions.json.gz.
    Excluded branches (D6): a reorder row at one is an error (Gold leaves them out, so it means Gold and the publish
    are out of step); transfer lines to or from one are dropped (Fact_OutstandingTransfers still has them).
    Only the folder's previous output files (*.json.gz, _meta.json) are removed first.
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json)."""
    out_dir = out_dir or OUT_DIR
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if _is_output(f) and os.path.isfile(os.path.join(out_dir, f)):
            os.remove(os.path.join(out_dir, f))
    hashes = {}

    def _write(name: str, data: bytes, hashes: dict) -> None:
        with open(os.path.join(out_dir, name), "wb") as f:
            f.write(data)
        hashes[name] = hashlib.sha256(data).hexdigest()

    surplus = []
    by_branch, raw_of = defaultdict(list), {}
    for r in reorder:
        if pl.is_excluded_branch(r["branch"]):
            raise ValueError(f"reorder row at excluded branch {r['branch']!r} ({r.get('franchise')!r} "
                             f"{r.get('partNumber')!r}); Gold should have left it out")
        key = branch_key(r["branch"])
        if raw_of.setdefault(key, r["branch"]) != r["branch"]:
            raise ValueError(f"branch codes {raw_of[key]!r} and {r['branch']!r} both map to file key {key!r}")
        if (r["surplusQty"] or 0) > 0:
            surplus.append(_clean({"branch": key, "franchise": r["franchise"], "partNumber": r["partNumber"],
                                   "onHand": r["onHand"], "target": r["target"], "surplusQty": r["surplusQty"],
                                   "status": r["status"]}))
        by_branch[key].append(_clean({k: v for k, v in _round2(r).items() if k != "branch"}))

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
    lines = [_clean(t) for t in transfers
             if not pl.is_excluded_branch(t.get("toBranch")) and not pl.is_excluded_branch(t.get("fromBranch"))]
    _write("transfers.json.gz", _bytes({"dataAsOf": data_as_of, "lines": lines}), hashes)

    _check_list_rows(rules, RULE_KEYS, "NonJD_OrderRules")
    _write("rules.json.gz", _bytes({"dataAsOf": data_as_of, "rules": _list_file(rules, RULE_KEYS)}), hashes)
    _check_list_rows(transfer_rules, TRANSFER_RULE_KEYS, "NonJD_TransferRules")
    _write("transfer_rules.json.gz", _bytes({"dataAsOf": data_as_of,
                                             "rules": _list_file(transfer_rules, TRANSFER_RULE_KEYS)}), hashes)

    # Sorted here too, so the bytes don't depend on the extract's order: group, then emission order.
    lines = sorted(_keyed(suggestions, SUGGESTION_KEYS, "transfer suggestion"),
                   key=lambda l: tuple(_none_last(l[k]) for k in ("franchise", "partNumber", "seq", "kind",
                                                                  "fromBranch", "toBranch")))
    done = sorted(_keyed(committed, COMMITTED_KEYS, "committed transfer"),
                  key=lambda l: (_none_last(l["transferId"]), _none_last(l["lineId"])))
    _write("transfer_suggestions.json.gz", _bytes({"dataAsOf": data_as_of, "lines": lines, "committed": done}),
           hashes)

    branches = [{"branch": b, "name": names.get(b, b), "parts": len(by_branch[b])} for b in keys]
    return hashes, branches


def write_meta(data_as_of: str, published_at: str, source: str, branches: list, counts: dict,
               out_dir: str = None) -> str:
    path = os.path.join(out_dir or OUT_DIR, pl.META_FILE)
    with open(path, "wb") as f:
        f.write(_bytes({"dataAsOf": data_as_of, "publishedAt": published_at, "source": source,
                        "branches": branches, "counts": counts, "schemaVersion": 1,
                        "contractVersion": pl.CONTRACT_VERSION}, compress=False))
    return path
