# projects/part order tool - app/publish/publish_logic.py
"""
NON-JD ORDER TOOL PUBLISH - PURE HELPERS (no network, no config; tested in test_publish_logic.py)

- latest_item_run / decide_publish / built_in_run / run_start: publish only a successful DP run, once, and only
  the table that run wrote (item rows carry no start_utc; run_start reads it from the run-level rows). The data date shown in the app is the run's end time, never the publish time.
- central_month_start: first day of the Central-time month of the build (matches Gold's current_month).
- month_labels / history_arrays: 60-month arrays per part, index 0 = current month (MonthOffset 1).
- clean_value: JSON-safe values (Decimal -> int/float, datetimes -> ISO UTC, NaN -> None).
- upload_order: _meta.json goes last so the app never sees a date ahead of its files.
- changed_files: only upload files whose content hash changed (plus ALWAYS_UPLOAD, sent every run).
- central_date / is_committed / committed_lines: the committed app transfer lines Gold counts (round 2 step 8b),
  published in transfer_suggestions.json.gz for the app's per-group parity check.
- CONTRACT_VERSION / require_columns: the field contract the files follow, and a clear failure when Gold and the
  publish code are out of step (a Gold column the publish needs is missing).
- EXCLUDED_BRANCHES / is_excluded_branch: branches left out of every output (Plan C D6; same list as Gold).
"""
import math
import os
import unicodedata
from datetime import date, datetime, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

ITEM = "Build_Gold_NonJD_Reorder"
META_FILE = "_meta.json"
CENTRAL = ZoneInfo("America/Chicago")
# The field contract of the files (README "File contract"). 1 = Plan A/B fields (no contractVersion in _meta.json);
# 2 = round 1 (Plan C); 3 = round 2 (Plan E: phase-in, transfer rules and suggestions). The app refuses a version
# it doesn't know.
CONTRACT_VERSION = 3
# Uploaded every run, changed or not (round 2 spec "The publish": the suggestions file embeds dataAsOf).
ALWAYS_UPLOAD = ("transfer_suggestions.json.gz",)
# Committed transfer statuses (spec step 8b, exact spelling); Placed counts only while recent.
OPEN_TRANSFER_STATUSES = ("Draft", "Exported")
# Same list as Build_Gold_NonJD_Reorder's EXCLUDED_BRANCHES; compared trimmed and upper-cased.
EXCLUDED_BRANCHES = ("12", "5", "97", "4B", "93C")


class MissingColumnsError(RuntimeError):
    """A table lacks columns the publish needs: Gold and the publish code are out of step."""


def require_columns(table: str, available, required) -> None:
    have = set(available)
    missing = [c for c in required if c not in have]
    if missing:
        raise MissingColumnsError(
            f"{table} is missing column(s) {', '.join(missing)} that the publish (contract version "
            f"{CONTRACT_VERSION}) needs; Gold and the publish code are out of step. Deploy the matching "
            f"Build_Gold_NonJD_Reorder / dataflow, or update the publish, before publishing")


def is_excluded_branch(raw) -> bool:
    return raw is not None and str(raw).strip().upper() in EXCLUDED_BRANCHES


def iso_utc(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def naive_utc(value: datetime) -> datetime:
    return value if value.tzinfo is None else value.astimezone(timezone.utc).replace(tzinfo=None)


def latest_item_run(rows: list, item: str = ITEM):
    mine = [r for r in rows if r.get("name") == item and r.get("row_type") == "item" and r.get("end_utc")
            and r.get("status") != "Skipped"]
    # tie on end_utc: a Failed row wins over Succeeded (cautious)
    return max(mine, key=lambda r: (naive_utc(r["end_utc"]), r.get("status") != "Succeeded"), default=None)


def run_start(rows: list, run_id: str):
    """Earliest start_utc of the run-level rows of run_id (item rows carry no start_utc)."""
    starts = [r["start_utc"] for r in rows
              if r.get("run_id") == run_id and r.get("row_type") == "run" and r.get("start_utc")]
    return min(starts, key=naive_utc, default=None)


def decide_publish(latest, state: dict, source: str, force: bool = False):
    if latest is None:
        return False, f"no run of {ITEM} in the log"
    if latest.get("status") != "Succeeded":
        return False, f"latest {ITEM} run {latest.get('run_id')} ended {latest.get('status')}; keeping the old files"
    if force:
        return True, "forced"
    if state.get("source") == source and state.get("dataAsOf") == iso_utc(latest["end_utc"]):
        return False, "already published"
    return True, "new data"


def built_in_run(built: datetime, start: datetime, end: datetime) -> bool:
    if built is None or start is None or end is None:
        return False
    return naive_utc(start) <= naive_utc(built) <= naive_utc(end)


def central_month_start(built: datetime) -> date:
    """First day of the Central-time month containing `built` (naive = UTC); matches Gold's current_month."""
    d = naive_utc(built).replace(tzinfo=timezone.utc).astimezone(CENTRAL).date()
    return date(d.year, d.month, 1)


def month_labels(current_month: date, months: int = 60) -> list:
    out, y, m = [], current_month.year, current_month.month
    for _ in range(months):
        out.append(f"{y:04d}-{m:02d}")
        m -= 1
        if m == 0:
            y, m = y - 1, 12
    return out


def clean_value(v):
    if v is None:
        return None
    if isinstance(v, Decimal):
        if not v.is_finite():
            return None
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, float):
        if not math.isfinite(v):
            return None
        return int(v) if v.is_integer() else v
    if isinstance(v, datetime):
        return iso_utc(v)
    if isinstance(v, date):
        return v.isoformat()
    if hasattr(v, "item"):  # numpy scalars (if a DataFrame path is ever used)
        return clean_value(v.item())
    return v


def history_arrays(rows: list, months: int = 60) -> list:
    parts, seen = {}, set()
    for r in rows:
        key = (r["franchise"], r["partNumber"])
        p = parts.setdefault(key, {"franchise": key[0], "partNumber": key[1],
                                   "sales": [0] * months, "requests": [0] * months})
        i = int(r["monthOffset"]) - 1
        if 0 <= i < months:
            if (key, i) in seen:
                raise ValueError(f"duplicate history row for {key} monthOffset {i + 1}")
            seen.add((key, i))
            p["sales"][i] = clean_value(r["salesQty"]) or 0
            p["requests"][i] = clean_value(r["requestCount"]) or 0
    return [parts[k] for k in sorted(parts)]


def upload_order(paths: list) -> list:
    return sorted(paths, key=lambda p: (os.path.basename(p) == META_FILE, p))


def changed_files(current: dict, previous: dict) -> list:
    return sorted(name for name, digest in current.items()
                  if previous.get(name) != digest or name in ALWAYS_UPLOAD)


def central_date(value: datetime) -> date:
    """The Central-time date of an instant (naive = UTC)."""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(CENTRAL).date()


def zs_trim(value) -> str:
    """Strip Unicode space separators (Zs, incl. NBSP) from both ends, as Gold's ztrim; None -> ""."""
    s = "" if value is None else str(value)
    a, b = 0, len(s)
    while a < b and unicodedata.category(s[a]) == "Zs":
        a += 1
    while b > a and unicodedata.category(s[b - 1]) == "Zs":
        b -= 1
    return s[a:b]


def is_committed(line: dict, build_date: date) -> bool:
    """A NonJD_Transfers line Gold counts in AppInboundQty / AppOutboundQty (spec step 8b + Part 1 clarifications):
    Draft or Exported, or Placed with the Central date of PlacedAt on or after the build's Central date (no PlacedAt
    never counts); both branches non-blank and not excluded (D6)."""
    status = line.get("status")
    if status not in OPEN_TRANSFER_STATUSES:
        if status != "Placed" or line.get("placedAt") is None or central_date(line["placedAt"]) < build_date:
            return False
    for k in ("fromBranch", "toBranch"):
        b = zs_trim(line.get(k))
        if b == "" or b.upper() in EXCLUDED_BRANCHES:
            return False
    return True


def committed_lines(rows: list, build_date: date) -> list:
    """The committed lines, ordered by transferId, lineId."""
    keep = [r for r in rows if is_committed(r, build_date)]
    return sorted(keep, key=lambda r: (r.get("transferId") is None, r.get("transferId") or 0,
                                       r.get("lineId") is None, r.get("lineId") or 0))
