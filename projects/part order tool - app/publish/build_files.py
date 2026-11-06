"""Write the app's data files: deterministic gzipped JSON (same content -> same bytes -> same hash)."""
import gzip
import hashlib
import json
import math
import os
import re
from collections import defaultdict
from datetime import date, datetime
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
# The round 2 fields a jdorder part has (contract v9, Plan S): the reorder file's without the transfer ones (S-P3).
JD_ORDER_ROUND2_FIELDS = ("pendingQty", "slc", "source", "commodityCode", "phaseInQty", "phaseInEnds", "phaseInOn",
                          "phaseInActive", "phaseInEndReason")
# purchases.json.gz row fields (extract.PURCHASES_COLUMNS); purchases12 is never null and is rounded to cents.
PURCHASES_KEYS = ("branch", "franchise", "purchases12")
# jd_<branch>.json.gz part fields (contract v6, v8's Pieces In Set fields; extract.JD_COLUMNS without branch), by how
# they are written: text trimmed (null -> "", except description, which stays null); money rounded to cents; quantities
# and sales to 2 decimals (the JD_NULLABLE ones may be null); the JD_COUNTS whole numbers.
JD_TEXT = ("partNumber", "description", "returnIndicator", "source", "slc", "superTo", "commodityCode",
           "commodityGroup", "dealerGroupCode")
JD_NUMBERS = ("cost", "onHand", "onOrder", "packageQty", "minimumQty", "maximumQty", "sales12", "salesPrev12",
              "binQty", "piecesInSet", "pisSalesQty", "pisQty")
JD_NULLABLE = frozenset(("description", "packageQty", "minimumQty", "maximumQty", "piecesInSet"))
JD_COUNTS = ("corpDemands", "pisInvoices", "pisQtyInvoices", "pisMultipleInvoices")
JD_KEYS = JD_TEXT + JD_NUMBERS + JD_COUNTS
# jd_idle_<branch>.json.gz part fields (contract v7, extract.JD_IDLE_COLUMNS without branch): the jd fields without
# the ones that are 0 by definition for an idle record (onHand, sales12, salesPrev12, corpDemands), written by the
# same rules. onOrder is never null and never positive (a positive on order makes a record active, L-D14).
JD_IDLE_NUMBERS = ("cost", "onOrder", "packageQty", "minimumQty", "maximumQty")
JD_IDLE_KEYS = JD_TEXT + JD_IDLE_NUMBERS
# A jd or jd_idle file must fit the simple upload (upload.SIMPLE_LIMIT, compressed bytes); the largest active
# branch is ~0.5 MB, the largest idle branch ~1 MB.
JD_FILE_LIMIT = 4 * 1024 * 1024
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


def _round2(r: dict, fields: tuple = ROUND2_FIELDS) -> dict:
    """The row with contract v3's never-null rules applied to the round 2 fields (`fields` of them)."""
    missing = [k for k in fields if k not in r]
    if missing:
        raise ValueError(f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r} is missing "
                         f"field(s) {', '.join(missing)}")
    out = dict(r)
    for k in fields:
        if out[k] is None and k not in ROUND2_NULLABLE:
            if k in ROUND2_TEXT:
                out[k] = ""
            elif k == "pendingQty":
                out[k] = 0
            else:
                raise ValueError(f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r}: "
                                 f"{k} is null; Gold should always set it (Gold and the publish are out of step)")
    return out


def _last_received(r: dict) -> dict:
    """The row with contract v4's lastReceived as a 'YYYY-MM-DD' string or null (Gold stores a DATE)."""
    if "lastReceived" not in r:
        raise ValueError(f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r} is missing "
                         f"field lastReceived")
    v = r["lastReceived"]
    if isinstance(v, datetime):
        v = v.date()
    return {**r, "lastReceived": v.isoformat() if isinstance(v, date) else v}


def _equip_stock_value(r: dict) -> dict:
    """The row with contract v5's equipStockValue as a finite number rounded to cents (negative allowed, -0 -> 0).
    Gold always sets it (Silver coalesces to 0), so missing, null or non-finite fails the publish."""
    where = f"reorder row {r.get('branch')!r} {r.get('franchise')!r} {r.get('partNumber')!r}"
    if "equipStockValue" not in r:
        raise ValueError(f"{where} is missing field equipStockValue")
    v = r["equipStockValue"]
    is_number = isinstance(v, (int, float, Decimal)) and not isinstance(v, bool)
    finite = is_number and (v.is_finite() if isinstance(v, Decimal) else math.isfinite(v))
    if not finite:
        raise ValueError(f"{where}: equipStockValue is {v!r}, not a finite number; Gold should always set it "
                         f"(Gold and the publish are out of step)")
    return {**r, "equipStockValue": round(float(v), 2) + 0.0}


def _purchases_rows(rows: list) -> list:
    """purchases.json.gz rows: every key present, purchases12 a finite number (rounded to cents), no excluded
    branch, one row per branch + franchise; sorted by branch (numeric codes first, as the branch list) then
    franchise, so the bytes don't depend on the extract's order."""
    out, seen = [], set()
    for r in rows:
        missing = [k for k in PURCHASES_KEYS if k not in r]
        if missing:
            raise ValueError(f"purchases row {r!r} is missing key(s) {', '.join(missing)}")
        v = r["purchases12"]
        if v is None or (isinstance(v, float) and not math.isfinite(v)) or \
                (isinstance(v, Decimal) and not v.is_finite()):
            raise ValueError(f"purchases row {r['branch']!r} {r['franchise']!r}: purchases12 is {v}, not a finite "
                             f"number; Gold should always set it (Gold and the publish are out of step)")
        if pl.is_excluded_branch(r["branch"]):
            raise ValueError(f"purchases row at excluded branch {r['branch']!r}; Gold should have left it out")
        key = (r["branch"], r["franchise"])
        if key in seen:
            raise ValueError(f"duplicate purchases row for branch {key[0]!r} franchise {key[1]!r}")
        seen.add(key)
        out.append(_clean({"branch": r["branch"], "franchise": r["franchise"],
                           "purchases12": round(float(v), 2)}))

    def order(row):
        b = str(row["branch"])
        return ((0, int(b), "") if b.isdigit() else (1, 0, b)), _none_last(row["franchise"])
    return sorted(out, key=order)


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
          purchases: list, out_dir: str = None) -> tuple:
    """Write all data files into out_dir (default OUT_DIR; not _meta.json, see write_meta).
    history_for(branch_key) -> that branch's history rows (called once per branch).
    rules: NonJD_OrderRules rows (camelCase keys), written as rules.json.gz for the app's engine check.
    transfer_rules: NonJD_TransferRules rows -> transfer_rules.json.gz. suggestions: Gold's suggestion lines and
    committed: the committed app transfer lines Gold used -> transfer_suggestions.json.gz.
    purchases: Fact_NonJD_Purchases rows (branch, franchise, purchases12) -> purchases.json.gz (contract v4).
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
        by_branch[key].append(_clean({k: v for k, v in _equip_stock_value(_last_received(_round2(r))).items() if k != "branch"}))

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

    _write("purchases.json.gz", _bytes({"dataAsOf": data_as_of, "rows": _purchases_rows(purchases)}), hashes)

    branches = [{"branch": b, "name": names.get(b, b), "parts": len(by_branch[b])} for b in keys]
    return hashes, branches


def _branch_order(b: str):
    return (0, int(b), "") if b.isdigit() else (1, 0, b)


def _is_finite_number(v) -> bool:
    if isinstance(v, bool) or not isinstance(v, (int, float, Decimal)):
        return False
    return v.is_finite() if isinstance(v, Decimal) else math.isfinite(v)


def _jd_fields(r: dict, where: str, keys: tuple, numbers: tuple) -> dict:
    """The text and number fields of a jd / jd_idle part: every key present; text trimmed; numbers finite, rounded
    to 2 decimals (whole values as integers, -0 as 0); only JD_NULLABLE fields may be null. Gold coalesces the
    others, so a null there means Gold and the publish are out of step."""
    missing = [k for k in keys if k not in r]
    if missing:
        raise ValueError(f"{where} is missing field(s) {', '.join(missing)}")
    out = {}
    for k in JD_TEXT:
        v = r[k]
        out[k] = (None if k in JD_NULLABLE else "") if v is None else str(v).strip()
    for k in numbers:
        v = r[k]
        if v is None and k in JD_NULLABLE:
            out[k] = None
        elif not _is_finite_number(v):
            raise ValueError(f"{where}: {k} is {v!r}, not a finite number; Gold should always set it "
                             f"(Gold and the publish are out of step)")
        else:
            out[k] = pl.clean_value(round(float(v), 2) + 0.0)
    return out


def _jd_part(r: dict) -> dict:
    """One jd file part (contract v6, v8): _jd_fields over JD_KEYS, plus the JD_COUNTS, whole numbers."""
    where = f"JD row {r.get('branch')!r} {r.get('partNumber')!r}"
    out = _jd_fields(r, where, JD_KEYS, JD_NUMBERS)
    for k in JD_COUNTS:
        v = r[k]
        if not _is_finite_number(v) or v != int(v):
            raise ValueError(f"{where}: {k} is {v!r}, not a whole number (Gold and the publish are out of step)")
        out[k] = int(v)
    return out


def _jd_idle_part(r: dict) -> dict:
    """One jd_idle file part (contract v7): _jd_fields over JD_IDLE_KEYS (fields outside them, e.g. an onHand,
    are not published). onOrder must be <= 0 as read (before rounding): a positive on order makes the record active
    (L-D14), so Gold's active / idle split is wrong."""
    where = f"JD idle row {r.get('branch')!r} {r.get('partNumber')!r}"
    out = _jd_fields(r, where, JD_IDLE_KEYS, JD_IDLE_NUMBERS)
    if r["onOrder"] > 0:
        raise ValueError(f"{where}: onOrder is {r['onOrder']!r}; an idle record's on order is 0 or negative (a "
                         f"positive one makes it active), so Gold's active / idle split is wrong")
    return out


def _branch_files(rows: list, names: dict, data_as_of: str, out_dir: str, prefix: str, part, what: str) -> tuple:
    """build_jd / build_jd_idle: one <prefix><branch>.json.gz per branch, part(row) per row."""
    out_dir = out_dir or OUT_DIR
    by_branch, raw_of = defaultdict(list), {}
    for r in rows:
        raw = r.get("branch")
        if raw is None:
            raise ValueError(f"{what} row {r.get('partNumber')!r} has no branch")
        key = branch_key(raw)
        if raw_of.setdefault(key, raw) != raw:
            raise ValueError(f"branch codes {raw_of[key]!r} and {raw!r} both map to file key {key!r}")
        raw_pn = r.get("partNumber")
        by_branch[key].append((part(r), "" if raw_pn is None else str(raw_pn)))

    # Every row is checked before any file is written.
    os.makedirs(out_dir, exist_ok=True)
    hashes, keys = {}, sorted(by_branch, key=_branch_order)
    for key in keys:
        parts = [p for p, _ in sorted(by_branch[key], key=lambda t: (t[0]["partNumber"], t[1]))]
        name = f"{prefix}{key}.json.gz"
        data = _bytes({"branch": key, "dataAsOf": data_as_of, "parts": parts})
        if len(data) > JD_FILE_LIMIT:
            raise ValueError(f"{name} would be {len(data):,} bytes, over the {JD_FILE_LIMIT:,}-byte upload limit "
                             f"(branch {key}, {len(parts):,} parts); add a chunked upload or split the file")
        with open(os.path.join(out_dir, name), "wb") as f:
            f.write(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    return hashes, [{"branch": b, "name": names.get(b, b), "parts": len(by_branch[b])} for b in keys]


def build_jd(rows: list, names: dict, data_as_of: str, out_dir: str = None) -> tuple:
    """Write one jd_<branch>.json.gz per branch with Fact_CorpParts_JD rows (contract v6) into out_dir (default
    OUT_DIR), after build() (which clears the folder's old outputs, jd files included; this adds to them).
    Branch keys follow branch_key (trimmed, file-name safe, two raw codes that trim to one key = error), but with
    no excluded-branch check: the Corp Parts reports cover every JD branch, 12 included (Plan L decision L-D5).
    Part numbers are trimmed and need not be unique (trailing-space twins stay two rows, L-D12); parts are
    sorted by trimmed partNumber, then the raw value, so the bytes don't depend on the extract's order. A file
    over JD_FILE_LIMIT compressed bytes fails the build, naming the branch.
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json jdBranches, sorted like branches)."""
    return _branch_files(rows, names, data_as_of, out_dir, "jd_", _jd_part, "JD")


def build_jd_idle(rows: list, names: dict, data_as_of: str, out_dir: str = None) -> tuple:
    """Write one jd_idle_<branch>.json.gz per branch with Fact_CorpParts_JD_Idle rows (contract v7, Plan M) into
    out_dir, after build(), by build_jd's rules (every branch, no D6 check; twins kept; sorted; the same limit).
    A positive onOrder fails the build, naming the part (Gold's active / idle split is wrong).
    Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json jdIdleBranches)."""
    return _branch_files(rows, names, data_as_of, out_dir, "jd_idle_", _jd_idle_part, "JD idle")


def _jd_order_part(r: dict) -> dict:
    """One jdorder file part (contract v9): written as a reorder file part, without the transfer fields (S-P3)."""
    out = _clean(_equip_stock_value(_last_received(_round2(r, JD_ORDER_ROUND2_FIELDS))))
    del out["branch"]
    return out


def build_jd_order(rows: list, names: dict, data_as_of: str, out_dir: str = None) -> tuple:
    """jdorder_<branch>.json.gz (contract v9, Plan S): every branch, no D6 check (S-D5). Same limit as the JD files.
    Into out_dir, after build(). Returns ({file name: sha256}, [{"branch", "name", "parts"}] for _meta.json
    jdOrderBranches)."""
    return _branch_files(rows, names, data_as_of, out_dir, "jdorder_", _jd_order_part, "JD order")


def _write_jd_file(name: str, obj: dict, out_dir: str) -> str:
    """Write one JD file, refusing one over JD_FILE_LIMIT; returns its sha256."""
    data = _bytes(obj)
    if len(data) > JD_FILE_LIMIT:
        raise ValueError(f"{name} would be {len(data):,} bytes, over the {JD_FILE_LIMIT:,}-byte upload limit; add a "
                         f"chunked upload or split the file")
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, name), "wb") as f:
        f.write(data)
    return hashlib.sha256(data).hexdigest()


def build_jd_history(history_for, branches: list, current_month: date, out_dir: str = None) -> dict:
    """jdhistory_<branch>.json.gz (contract v9, Plan S), written as build() writes history_<branch>.json.gz, for the
    branch keys given; history_for(branch_key) is called once per branch. Returns {file name: sha256}."""
    out_dir = out_dir or OUT_DIR
    labels = pl.month_labels(current_month, 60)
    hashes = {}
    for key in branches:
        name = f"jdhistory_{key}.json.gz"
        hist = history_for(key)
        hashes[name] = _write_jd_file(name, {"branch": key, "months": labels, "parts": pl.history_arrays(hist, 60)}, out_dir)
        del hist
    return hashes


def build_jd_rules(rules: list, data_as_of: str, out_dir: str = None) -> dict:
    """jd_rules.json.gz (contract v9, Plan S), JD_OrderRules rows written as rules.json.gz. Returns {file name: sha256}."""
    _check_list_rows(rules, RULE_KEYS, "JD_OrderRules")
    name = "jd_rules.json.gz"
    return {name: _write_jd_file(name, {"dataAsOf": data_as_of, "rules": _list_file(rules, RULE_KEYS)}, out_dir or OUT_DIR)}


def write_meta(data_as_of: str, published_at: str, source: str, branches: list, counts: dict,
               out_dir: str = None, *, jd_branches: list, jd_idle_branches: list, jd_order_branches: list = None,
               jd_order_as_of: str = None) -> str:
    """_meta.json (plain JSON). jd_branches = build_jd's list (contract v6 jdBranches; counts carries jdParts);
    jd_idle_branches = build_jd_idle's list (contract v7 jdIdleBranches; counts carries jdIdleParts);
    jd_order_branches, jd_order_as_of = the JD order files' branches and data date (contract v9; [] and None until the
    JD build has published; counts carries jdOrderParts and jdHistoryRows)."""
    path = os.path.join(out_dir or OUT_DIR, pl.META_FILE)
    with open(path, "wb") as f:
        f.write(_bytes({"dataAsOf": data_as_of, "publishedAt": published_at, "source": source,
                        "branches": branches, "counts": counts, "schemaVersion": 1,
                        "contractVersion": pl.CONTRACT_VERSION, "jdBranches": jd_branches,
                        "jdIdleBranches": jd_idle_branches, "jdOrderBranches": jd_order_branches or [],
                        "jdOrderAsOf": jd_order_as_of}, compress=False))
    return path
