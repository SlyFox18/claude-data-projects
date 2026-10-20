# projects/part order tool - app/publish/publish_logic.py
"""
NON-JD ORDER TOOL PUBLISH - PURE HELPERS (no network, no config; tested in test_publish_logic.py)

- latest_item_run / decide_publish / built_in_run: publish only a successful DP run, once, and only the table
  that run wrote. The data date shown in the app is the run's end time, never the publish time.
- month_labels / history_arrays: 60-month arrays per part, index 0 = current month (MonthOffset 1).
- clean_value: JSON-safe values (Decimal -> int/float, datetimes -> ISO UTC, NaN -> None).
- upload_order: _meta.json goes last so the app never sees a date ahead of its files.
- changed_files: only upload files whose content hash changed.
"""
import math
import os
from datetime import date, datetime, timezone
from decimal import Decimal

ITEM = "Build_Gold_NonJD_Reorder"
META_FILE = "_meta.json"


def iso_utc(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def _naive_utc(value: datetime) -> datetime:
    return value if value.tzinfo is None else value.astimezone(timezone.utc).replace(tzinfo=None)


def latest_item_run(rows: list, item: str = ITEM):
    mine = [r for r in rows if r.get("name") == item and r.get("row_type") == "item" and r.get("end_utc")]
    return max(mine, key=lambda r: _naive_utc(r["end_utc"]), default=None)


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
    return _naive_utc(start) <= _naive_utc(built) <= _naive_utc(end)


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
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, float):
        if math.isnan(v):
            return None
        return int(v) if v.is_integer() else v
    if isinstance(v, datetime):
        return iso_utc(v)
    if isinstance(v, date):
        return v.isoformat()
    if hasattr(v, "item"):  # numpy scalars from pandas
        return clean_value(v.item())
    return v


def history_arrays(rows: list, months: int = 60) -> list:
    parts = {}
    for r in rows:
        key = (r["franchise"], r["partNumber"])
        p = parts.setdefault(key, {"franchise": key[0], "partNumber": key[1],
                                   "sales": [0] * months, "requests": [0] * months})
        i = int(r["monthOffset"]) - 1
        if 0 <= i < months:
            p["sales"][i] = clean_value(r["salesQty"]) or 0
            p["requests"][i] = clean_value(r["requestCount"]) or 0
    return [parts[k] for k in sorted(parts)]


def upload_order(paths: list) -> list:
    return sorted(paths, key=lambda p: (os.path.basename(p) == META_FILE, p))


def changed_files(current: dict, previous: dict) -> list:
    return sorted(name for name, digest in current.items() if previous.get(name) != digest)
